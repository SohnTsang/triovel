import Foundation

struct Trip: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var coverImagePath: String?
    var inviteLink: String?
    var displayTimezone: String
    var baseCurrency: String
    var archived: Bool
    let createdBy: String
    let createdAt: Date

    /// Number of days in the trip, inclusive of start and end.
    var dayCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
    }
}
