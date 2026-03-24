import Foundation

struct Post: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let blockId: String
    let userId: String
    var body: String?
    var visibility: PostVisibility
    let createdAt: Date
}

enum PostVisibility: String, Codable, Hashable, Sendable {
    case shared
    case `private`
}
