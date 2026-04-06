import Foundation

struct BlockDocument: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let blockId: String
    let userId: String
    var fileName: String
    var fileType: DocumentFileType
    var storagePath: String?
    var uploadStatus: UploadStatus
    var fileSize: Int?
    let createdAt: Date

    /// Human-readable file size: "1.2 MB", "856 KB"
    var formattedSize: String? {
        guard let size = fileSize else { return nil }
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return "\(size / 1024) KB"
        } else {
            let mb = Double(size) / (1024 * 1024)
            return String(format: "%.1f MB", mb)
        }
    }
}

enum DocumentFileType: String, Codable, Hashable, Sendable {
    case pdf
    case image
}
