import Foundation

struct TripMember: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let tripId: String
    let userId: String
    var role: Role
    let joinedAt: Date

    enum Role: String, Codable, Sendable {
        case owner
        case member
    }
}
