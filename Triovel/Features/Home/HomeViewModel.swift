import Foundation
import Observation

/// Drives the Global Home screen: active trips, archived trips, and trip limit.
@Observable
@MainActor
final class HomeViewModel {
    /// Free user active trip ownership limit (scope-control.md)
    static let activeOwnedTripLimit = 30

    private(set) var activeTrips: [Trip] = []
    private(set) var archivedTrips: [Trip] = []
    private(set) var membersByTrip: [String: [TripMemberDisplay]] = [:]
    private(set) var isLoading = false
    var showingTripLimitAlert = false

    var canCreateTrip: Bool {
        ownedActiveTripCount < Self.activeOwnedTripLimit
    }

    private var currentUserId: String?
    private let tripRepository = TripRepository()
    nonisolated(unsafe) private var loadTask: Task<Void, Never>?

    private var ownedActiveTripCount: Int {
        guard let uid = currentUserId else { return 0 }
        return activeTrips.filter { $0.createdBy == uid }.count
    }

    func load(userId: String) {
        currentUserId = userId
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.fetchTrips(userId: userId)
        }
    }

    func refresh() async {
        guard let userId = currentUserId else { return }
        await fetchTrips(userId: userId)
    }

    deinit {
        loadTask?.cancel()
    }

    /// Called when user taps + New Trip. Returns true if allowed.
    func requestCreateTrip() -> Bool {
        guard canCreateTrip else {
            showingTripLimitAlert = true
            return false
        }
        return true
    }

    // MARK: - Fetch from Supabase

    private func fetchTrips(userId: String) async {
        isLoading = activeTrips.isEmpty
        do {
            let result = try await tripRepository.fetchTrips(userId: userId)
            activeTrips = result.active
            archivedTrips = result.archived
            print("[Home] Loaded \(result.active.count) active, \(result.archived.count) archived trips")

            // Fetch members for all trips
            let allTripIds = (result.active + result.archived).map(\.id)
            if !allTripIds.isEmpty {
                let members = try await tripRepository.fetchMembers(tripIds: allTripIds)
                membersByTrip = members
                print("[Home] Loaded members for \(members.count) trips")
            }
        } catch {
            print("[Home] ❌ fetchTrips failed: \(error)")
            // Keep showing cached data if any
        }
        isLoading = false
    }
}

/// Lightweight display model for member avatars on trip cards and member list.
struct TripMemberDisplay: Identifiable, Hashable, Sendable {
    var id: String { userId }
    let userId: String
    let displayName: String
    let avatarPath: String?
    var role: TripMember.Role = .member

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(displayName.prefix(1)).uppercased()
    }
}
