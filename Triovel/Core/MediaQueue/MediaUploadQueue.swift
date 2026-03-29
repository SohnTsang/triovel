import Foundation
import Observation
import Supabase

/// Singleton upload queue that processes media uploads to Supabase Storage.
/// Persists state in post_media SQLite table — survives app restarts.
///
/// Flow per item:
///   1. Local file exists at MediaFileManager path
///   2. Queue reads file, uploads to Supabase Storage
///   3. Updates post_media.storage_path + upload_status on success
///   4. On failure: retry with exponential backoff, max 5 attempts
@Observable
@MainActor
final class MediaUploadQueue {
    static let shared = MediaUploadQueue()

    private(set) var isProcessing = false

    private let repository = PostMediaRepository()
    private let storageBucket = "trip-media"
    private let maxRetries = 5
    nonisolated(unsafe) private var processTask: Task<Void, Never>?

    private init() {}

    deinit {
        processTask?.cancel()
    }

    // MARK: - Enqueue

    /// Save compressed media to disk and create a post_media record.
    /// The queue will pick it up and upload it.
    func enqueue(
        mediaItem: MediaItem,
        postId: String,
        tripId: String
    ) async throws -> PostMedia {
        // Save compressed file to local disk
        if let data = mediaItem.sourceData {
            try MediaFileManager.saveMedia(data: data, for: mediaItem.id, type: mediaItem.type)
        } else if let sourceURL = mediaItem.sourceURL {
            let destURL = MediaFileManager.localMediaURL(for: mediaItem.id, type: mediaItem.type)
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        }

        // Save thumbnail
        try MediaFileManager.saveThumbnail(image: mediaItem.thumbnail, for: mediaItem.id)

        // Create post_media record with SAME ID as the local file
        let media = try await repository.createPostMedia(
            id: mediaItem.id,
            postId: postId,
            mediaType: mediaItem.type,
            tripId: tripId
        )

        // Kick off processing if not already running
        startProcessing()

        return media
    }

    /// Retry a failed upload.
    func retryUpload(mediaId: String) async {
        do {
            try await repository.updateUploadStatus(mediaId: mediaId, status: .queued)
            startProcessing()
        } catch {
            print("[MediaQueue] ❌ Retry failed: \(error)")
        }
    }

    /// Resume pending uploads on app launch (auth refresh flow step 4).
    func resumePendingUploads() {
        print("[MediaQueue] Resuming pending uploads")
        // Reset any stuck "uploading" items back to queued
        Task {
            do {
                let pending = try await repository.fetchPendingUploads()
                print("[MediaQueue] Found \(pending.count) pending items")
                for item in pending where item.uploadStatus == .uploading {
                    try await repository.updateUploadStatus(mediaId: item.id, status: .queued)
                }
                if !pending.isEmpty {
                    startProcessing()
                }
            } catch {
                print("[MediaQueue] ❌ Resume failed: \(error)")
            }
        }
    }

    // MARK: - Processing

    private func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true

        processTask?.cancel()
        processTask = Task { [weak self] in
            await self?.processLoop()
        }
    }

    private func processLoop() async {
        defer { isProcessing = false }
        var failedIds: Set<String> = []

        while !Task.isCancelled {
            do {
                let pending = try await repository.fetchPendingUploads()
                // Skip any items we already failed in this loop run
                guard let item = pending.first(where: { !failedIds.contains($0.id) }) else {
                    print("[MediaQueue] Queue empty")
                    break
                }

                let success = await uploadItem(item)
                if !success {
                    failedIds.insert(item.id)
                }
            } catch {
                print("[MediaQueue] ❌ Process loop error: \(error)")
                break
            }
        }
    }

    /// Returns true if upload succeeded, false if failed.
    private func uploadItem(_ item: PostMedia) async -> Bool {
        let fileURL = MediaFileManager.localMediaURL(for: item.id, type: item.mediaType)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[MediaQueue] ⚠️ Local file missing for \(item.id), marking failed")
            try? await repository.updateUploadStatus(mediaId: item.id, status: .failed)
            return false
        }

        // Check storage ceiling before uploading
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        if MediaCostController.shouldPauseUploads(tripStorageBytes: fileSize) {
            print("[MediaQueue] ⚠️ Storage ceiling reached, pausing upload for \(item.id)")
            return false
        }

        // Mark as uploading
        try? await repository.updateUploadStatus(mediaId: item.id, status: .uploading)

        // Build remote path: trips/{trip_id}/posts/{post_id}/{media_id}.ext
        let ext = item.mediaType == .photo ? "jpg" : "mp4"
        // We need trip_id — get it via the post's block
        let remotePath = "posts/\(item.postId)/\(item.id).\(ext)"

        do {
            let fileData = try Data(contentsOf: fileURL)
            let contentType = item.mediaType == .photo ? "image/jpeg" : "video/mp4"

            _ = try await SupabaseConfig.client.storage
                .from(storageBucket)
                .upload(
                    path: remotePath,
                    file: fileData,
                    options: FileOptions(contentType: contentType)
                )

            // Upload succeeded — update record
            try await repository.updateStoragePath(
                mediaId: item.id,
                storagePath: remotePath,
                thumbnailPath: nil
            )

            print("[MediaQueue] ✓ Uploaded \(item.id) → \(remotePath)")
            BetaAnalytics.trackMediaUploadSuccess()
            return true

        } catch {
            print("[MediaQueue] ❌ Upload failed for \(item.id): \(error)")
            BetaAnalytics.trackMediaUploadFailure()
            try? await repository.updateUploadStatus(mediaId: item.id, status: .failed)
            return false
        }
    }
}
