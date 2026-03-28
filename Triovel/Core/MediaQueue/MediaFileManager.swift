import Foundation
import UIKit

/// Manages local file paths for media and thumbnails.
/// Uses deterministic paths based on media ID — no database columns needed.
///   Media:      {AppSupport}/media/{mediaId}.jpg|.mp4
///   Thumbnails: {AppSupport}/thumbnails/{mediaId}.jpg
enum MediaFileManager {

    // MARK: - Directories

    private static let mediaDir: URL = {
        let dir = appSupportDir.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let thumbnailDir: URL = {
        let dir = appSupportDir.appendingPathComponent("thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let appSupportDir: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }()

    // MARK: - URLs

    static func localMediaURL(for mediaId: String, type: MediaType) -> URL {
        let ext = type == .photo ? "jpg" : "mp4"
        return mediaDir.appendingPathComponent("\(mediaId).\(ext)")
    }

    static func localThumbnailURL(for mediaId: String) -> URL {
        thumbnailDir.appendingPathComponent("\(mediaId).jpg")
    }

    // MARK: - Save

    @discardableResult
    static func saveMedia(data: Data, for mediaId: String, type: MediaType) throws -> URL {
        let url = localMediaURL(for: mediaId, type: type)
        try data.write(to: url, options: .atomic)
        return url
    }

    @discardableResult
    static func saveThumbnail(image: UIImage, for mediaId: String) throws -> URL {
        let url = localThumbnailURL(for: mediaId)
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw MediaFileError.thumbnailFailed
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Delete

    static func deleteLocalFiles(for mediaId: String, type: MediaType) {
        let fm = FileManager.default
        try? fm.removeItem(at: localMediaURL(for: mediaId, type: type))
        try? fm.removeItem(at: localThumbnailURL(for: mediaId))
    }

    // MARK: - Load

    static func loadThumbnail(for mediaId: String) -> UIImage? {
        let url = localThumbnailURL(for: mediaId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Storage Size

    /// Total bytes of local media files for a trip (for cost control).
    static func tripStorageBytes(mediaIds: [String], types: [MediaType]) -> Int64 {
        var total: Int64 = 0
        let fm = FileManager.default
        for (id, type) in zip(mediaIds, types) {
            let url = localMediaURL(for: id, type: type)
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }
}

// MARK: - Error

enum MediaFileError: LocalizedError {
    case thumbnailFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .thumbnailFailed: return "Failed to generate thumbnail."
        case .saveFailed: return "Failed to save media file."
        }
    }
}
