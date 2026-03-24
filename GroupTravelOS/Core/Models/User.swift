import Foundation

struct AppUser: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var displayName: String
    var avatarPath: String?
    let createdAt: Date
}
