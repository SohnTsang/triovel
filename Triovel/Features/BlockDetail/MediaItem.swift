import UIKit

/// Represents a selected media item in the composer before it becomes a PostMedia record.
/// Holds the source data/URL and a pre-generated thumbnail for instant display.
struct MediaItem: Identifiable, Sendable {
    let id: String
    let type: MediaType
    let thumbnail: UIImage
    let sourceData: Data?   // For photos (compressed JPEG)
    let sourceURL: URL?     // For videos (temp file URL)

    init(id: String = UUID().uuidString.lowercased(), type: MediaType, thumbnail: UIImage, sourceData: Data? = nil, sourceURL: URL? = nil) {
        self.id = id
        self.type = type
        self.thumbnail = thumbnail
        self.sourceData = sourceData
        self.sourceURL = sourceURL
    }
}
