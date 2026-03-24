import Foundation

/// Represents an actual real-world repayment between two people.
/// Amount in smallest currency unit.
struct Payment: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let tripId: String
    let payerId: String
    let receiverId: String
    var amount: Int
    var currency: String
    var note: String?
    let createdAt: Date
}
