import Foundation
import UIKit
import Supabase

/// Actor-based image cache with in-memory (NSCache, 50MB) + disk persistence.
/// Handles local thumbnails, cached remote downloads, and Supabase Storage fetches.
///
/// Loading priority:
///   1. Local thumbnail (own uploads via MediaFileManager)
///   2. Memory cache (NSCache)
///   3. Disk cache ({AppSupport}/image_cache/)
///   4. Remote download from Supabase Storage → generate 200px thumbnail → cache
actor ImageCache {
    static let shared = ImageCache()

    /// Thread-safe in-memory cache. 50MB limit per performance.md.
    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        cache.countLimit = 500
        return cache
    }()

    private let diskCacheDir: URL
    private let fileManager = FileManager.default
    private let storageBucket = "trip-media"

    /// Thumbnail width for stream display. Full-res loaded on tap/zoom.
    private let thumbnailMaxWidth: CGFloat = 400

    /// Track in-flight downloads to avoid duplicate requests for the same image.
    private var activeDownloads: [String: Task<UIImage?, Never>] = [:]

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        diskCacheDir = appSupport.appendingPathComponent("image_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Load a thumbnail for display in the post stream.
    /// Tries local file → memory → disk → remote download in order.
    func loadThumbnail(mediaId: String, storagePath: String?) async -> UIImage? {
        // 1. Local thumbnail from own uploads
        let localURL = MediaFileManager.localThumbnailURL(for: mediaId)
        if fileManager.fileExists(atPath: localURL.path),
           let data = try? Data(contentsOf: localURL),
           let image = UIImage(data: data) {
            let key = cacheKey(mediaId)
            memoryCache.setObject(image, forKey: key as NSString, cost: data.count)
            return image
        }

        let key = cacheKey(mediaId)

        // 2. Memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 3. Disk cache
        if let diskImage = loadFromDisk(key: key) {
            let cost = diskImage.jpegData(compressionQuality: 0.8)?.count ?? 0
            memoryCache.setObject(diskImage, forKey: key as NSString, cost: cost)
            return diskImage
        }

        // 4. Remote download
        guard let storagePath, !storagePath.isEmpty else { return nil }
        return await downloadAndCache(mediaId: mediaId, storagePath: storagePath)
    }

    /// Clear all caches (call on sign-out).
    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheDir)
        try? fileManager.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Download

    /// Download image from Supabase Storage, generate thumbnail, cache it.
    /// Deduplicates concurrent requests for the same image.
    private func downloadAndCache(mediaId: String, storagePath: String) async -> UIImage? {
        let key = cacheKey(mediaId)

        // Deduplicate: if already downloading this image, await the existing task
        if let existing = activeDownloads[key] {
            return await existing.value
        }

        let storageBucket = self.storageBucket
        let task = Task<UIImage?, Never> {
            do {
                let data = try await SupabaseConfig.client.storage
                    .from(storageBucket)
                    .download(path: storagePath)

                guard let fullImage = UIImage(data: data) else { return nil }

                // Generate thumbnail for stream display (runs on background thread)
                let maxWidth = CGFloat(400)
                let thumbnail: UIImage
                if fullImage.size.width > maxWidth {
                    thumbnail = await Task.detached(priority: .utility) {
                        let scale = maxWidth / fullImage.size.width
                        let newSize = CGSize(width: maxWidth, height: fullImage.size.height * scale)
                        let renderer = UIGraphicsImageRenderer(size: newSize)
                        return renderer.image { _ in
                            fullImage.draw(in: CGRect(origin: .zero, size: newSize))
                        }
                    }.value
                } else {
                    thumbnail = fullImage
                }

                return thumbnail
            } catch {
                print("[ImageCache] Download failed for \(storagePath): \(error)")
                return nil
            }
        }

        activeDownloads[key] = task
        let result = await task.value
        activeDownloads[key] = nil

        // Cache the result within actor isolation
        if let thumbnail = result {
            let thumbData = thumbnail.jpegData(compressionQuality: 0.8) ?? Data()
            memoryCache.setObject(thumbnail, forKey: key as NSString, cost: thumbData.count)
            saveToDisk(data: thumbData, key: key)
        }

        return result
    }

    // MARK: - Thumbnail Generation

    /// Generate a thumbnail at thumbnailMaxWidth. Runs on a background thread.
    private func generateThumbnail(from image: UIImage) async -> UIImage {
        let maxWidth = thumbnailMaxWidth
        guard image.size.width > maxWidth else { return image }

        return await Task.detached(priority: .utility) {
            let scale = maxWidth / image.size.width
            let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }.value
    }

    // MARK: - Disk Cache

    private func diskURL(for key: String) -> URL {
        diskCacheDir.appendingPathComponent("\(key).jpg")
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let url = diskURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(data: Data, key: String) {
        let url = diskURL(for: key)
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Key

    private func cacheKey(_ mediaId: String) -> String {
        "thumb_\(mediaId)"
    }
}
