import Foundation
import SwiftUI

/// Drives the Global Home screen: active trips, archived trips, and trip limit.
@MainActor
final class HomeViewModel: ObservableObject {
    /// Free user active trip ownership limit (scope-control.md)
    static let activeOwnedTripLimit = 30

    @Published private(set) var activeTrips: [Trip] = []
    @Published private(set) var archivedTrips: [Trip] = []
    @Published private(set) var membersByTrip: [String: [TripMemberDisplay]] = [:]
    @Published var showingTripLimitAlert = false

    var canCreateTrip: Bool {
        ownedActiveTripCount < Self.activeOwnedTripLimit
    }

    private var currentUserId: String?

    private var ownedActiveTripCount: Int {
        guard let uid = currentUserId else { return 0 }
        return activeTrips.filter { $0.createdBy == uid }.count
    }

    func load(userId: String) {
        currentUserId = userId
        loadMockData(userId: userId)
    }

    /// Called when user taps + New Trip. Returns true if allowed.
    func requestCreateTrip() -> Bool {
        guard canCreateTrip else {
            showingTripLimitAlert = true
            return false
        }
        return true
    }

    // MARK: - Mock Data (replaced by repository in Phase 2)

    private func loadMockData(userId: String) {
        let cal = Calendar.current
        let now = Date()

        let trip1 = Trip(
            id: "trip-001",
            title: "Tokyo Trip 2026",
            startDate: cal.date(byAdding: .day, value: 5, to: now)!,
            endDate: cal.date(byAdding: .day, value: 10, to: now)!,
            coverImagePath: nil,
            inviteLink: nil,
            displayTimezone: "Asia/Tokyo",
            baseCurrency: "JPY",
            archived: false,
            createdBy: userId,
            createdAt: cal.date(byAdding: .day, value: -7, to: now)!
        )

        let trip2 = Trip(
            id: "trip-002",
            title: "Melbourne Weekend",
            startDate: cal.date(byAdding: .day, value: 20, to: now)!,
            endDate: cal.date(byAdding: .day, value: 23, to: now)!,
            coverImagePath: nil,
            inviteLink: nil,
            displayTimezone: "Australia/Melbourne",
            baseCurrency: "AUD",
            archived: false,
            createdBy: "other-user",
            createdAt: cal.date(byAdding: .day, value: -3, to: now)!
        )

        let trip3 = Trip(
            id: "trip-003",
            title: "Osaka 2025",
            startDate: cal.date(byAdding: .month, value: -6, to: now)!,
            endDate: cal.date(byAdding: .month, value: -6, to: cal.date(byAdding: .day, value: 4, to: now)!)!,
            coverImagePath: nil,
            inviteLink: nil,
            displayTimezone: "Asia/Tokyo",
            baseCurrency: "JPY",
            archived: true,
            createdBy: userId,
            createdAt: cal.date(byAdding: .month, value: -7, to: now)!
        )

        activeTrips = [trip1, trip2]
        archivedTrips = [trip3]

        // Mock member display data
        let sohn = TripMemberDisplay(userId: userId, displayName: "Sohn", avatarPath: nil)
        let alex = TripMemberDisplay(userId: "other-user", displayName: "Alex", avatarPath: nil)
        let kim = TripMemberDisplay(userId: "user-003", displayName: "Kim", avatarPath: nil)

        membersByTrip = [
            "trip-001": [sohn, alex, kim],
            "trip-002": [alex, sohn],
            "trip-003": [sohn, alex]
        ]
    }
}

/// Lightweight display model for member avatars on trip cards.
struct TripMemberDisplay: Identifiable, Hashable, Sendable {
    var id: String { userId }
    let userId: String
    let displayName: String
    let avatarPath: String?

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(displayName.prefix(1)).uppercased()
    }
}
