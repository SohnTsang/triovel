import Foundation

/// Individual share of a bill. Amount in smallest currency unit.
struct BillShare: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let billId: String
    let userId: String
    var shareAmount: Int
}
