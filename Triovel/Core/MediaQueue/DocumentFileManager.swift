import Foundation
import Supabase

/// Handles local file storage and Supabase Storage upload/download for block documents.
/// Documents are copied to a local directory on pick, uploaded when online,
/// and downloaded on-demand for viewing.
///
/// Local path: <appDocuments>/Documents/<docId>/<fileName>
/// Remote path: trips/<tripId>/docs/<docId>/<fileName>
actor DocumentFileManager {
    static let shared = DocumentFileManager()

    private let client = SupabaseConfig.client
    private let repository = BlockDocumentRepository()
    private let maxFileSize = 10 * 1024 * 1024 // 10 MB

    // MARK: - Local Directory

    private func localDir(for docId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Documents/\(docId)", isDirectory: true)
    }

    private func localPath(for docId: String, fileName: String) -> URL {
        localDir(for: docId).appendingPathComponent(fileName)
    }

    // MARK: - Import (copy picked file to local storage)

    /// Copy a file from the picker URL to local app storage.
    /// Returns the file size in bytes. Throws if file is too large.
    func importFile(from sourceURL: URL, docId: String, fileName: String) throws -> Int {
        let dir = localDir(for: docId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let destination = dir.appendingPathComponent(fileName)

        // Access security-scoped resource (file picker URLs require this)
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: sourceURL)

        guard data.count <= maxFileSize else {
            throw DocumentError.fileTooLarge
        }

        try data.write(to: destination)
        return data.count
    }

    // MARK: - Upload

    /// Upload a local document to Supabase Storage.
    /// Updates the DB row with storage_path on success.
    func upload(docId: String, fileName: String, tripId: String) async throws {
        let localFile = localPath(for: docId, fileName: fileName)

        guard FileManager.default.fileExists(atPath: localFile.path) else {
            throw DocumentError.localFileNotFound
        }

        try await repository.updateUploadStatus(docId: docId, status: .uploading)

        let data = try Data(contentsOf: localFile)
        let remotePath = "trips/\(tripId)/docs/\(docId)/\(fileName)"
        let contentType = fileName.lowercased().hasSuffix(".pdf") ? "application/pdf" : "image/jpeg"

        do {
            try await client.storage.from("documents").upload(
                remotePath,
                data: data,
                options: .init(contentType: contentType, upsert: true)
            )
            try await repository.updateStoragePath(docId: docId, storagePath: remotePath)
            print("[DocManager] ✓ Uploaded: \(fileName)")
        } catch {
            try await repository.updateUploadStatus(docId: docId, status: .failed)
            print("[DocManager] ❌ Upload failed: \(error)")
            throw error
        }
    }

    // MARK: - Download (for viewing remote documents)

    /// Download a document from Supabase Storage to local cache.
    /// Returns the local file URL for QuickLook / preview.
    func download(docId: String, fileName: String, storagePath: String) async throws -> URL {
        let localFile = localPath(for: docId, fileName: fileName)

        // Already cached locally
        if FileManager.default.fileExists(atPath: localFile.path) {
            return localFile
        }

        let dir = localDir(for: docId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try await client.storage.from("documents").download(path: storagePath)
        try data.write(to: localFile)
        print("[DocManager] ✓ Downloaded: \(fileName)")
        return localFile
    }

    // MARK: - Delete local files

    func deleteLocalFiles(docId: String) {
        let dir = localDir(for: docId)
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Delete remote + local

    func deleteDocument(docId: String, storagePath: String?) async {
        // Remote
        if let path = storagePath {
            do {
                try await client.storage.from("documents").remove(paths: [path])
            } catch {
                print("[DocManager] ⚠️ Remote delete failed: \(error)")
            }
        }
        // Local
        deleteLocalFiles(docId: docId)
    }

    // MARK: - Retry failed upload

    func retryUpload(docId: String, fileName: String, tripId: String) async {
        do {
            try await repository.updateUploadStatus(docId: docId, status: .queued)
            try await upload(docId: docId, fileName: fileName, tripId: tripId)
        } catch {
            print("[DocManager] ❌ Retry failed: \(error)")
        }
    }

    // MARK: - Resume pending uploads

    func resumePendingUploads(blockId: String, tripId: String) async {
        do {
            let docs = try await repository.fetchDocuments(blockId: blockId)
            let pending = docs.filter { $0.uploadStatus == .queued || $0.uploadStatus == .uploading }
            for doc in pending {
                try await upload(docId: doc.id, fileName: doc.fileName, tripId: tripId)
            }
        } catch {
            print("[DocManager] ⚠️ Resume pending failed: \(error)")
        }
    }
}

// MARK: - Errors

enum DocumentError: LocalizedError {
    case fileTooLarge
    case localFileNotFound
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .fileTooLarge: return String(localized: "document.error.too.large")
        case .localFileNotFound: return String(localized: "document.error.not.found")
        case .unsupportedFormat: return String(localized: "document.error.unsupported")
        }
    }
}
