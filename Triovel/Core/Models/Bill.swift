import Foundation

/// Amount is stored as integer in smallest currency unit (e.g. cents).
struct Bill: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let blockId: String
    let tripId: String
    var amount: Int
    var currency: String
    let payerId: String
    var note: String?
    let createdAt: Date
}
