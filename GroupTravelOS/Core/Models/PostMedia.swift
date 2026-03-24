import Foundation

struct PostMedia: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let postId: String
    var storagePath: String?
    var mediaType: MediaType
    var uploadStatus: UploadStatus
    var thumbnailPath: String?
    let createdAt: Date
}

enum MediaType: String, Codable, Hashable, Sendable {
    case photo
    case video
}

enum UploadStatus: String, Codable, Hashable, Sendable {
    case queued
    case uploading
    case uploaded
    case failed
}
