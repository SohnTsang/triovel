import Foundation

struct Block: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let tripId: String
    var title: String
    var context: BlockContext
    let createdBy: String
    var startAt: Date
    var endAt: Date?
    var locationText: String?
    var displayTimezone: String
    var localTimezone: String?
    var untimedRank: Int?
    var coverMediaId: String?
    let createdAt: Date
}

enum BlockContext: String, Codable, Hashable, Sendable {
    case group
    case personal
}
