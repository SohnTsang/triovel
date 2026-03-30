import Foundation
import Observation

/// Drives the Global Home screen: active trips, archived trips, and trip limit.
/// Uses reactive watch queries — UI updates automatically when local data changes.
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
    @ObservationIgnored private var watchTask: Task<Void, Never>?

    private var ownedActiveTripCount: Int {
        guard let uid = currentUserId else { return 0 }
        return activeTrips.filter { $0.createdBy == uid }.count
    }

    func load(userId: String) {
        currentUserId = userId
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            await self?.startWatching(userId: userId)
        }
    }

    func refresh() async {
        guard let userId = currentUserId else { return }
        await fetchOnce(userId: userId)
    }

    deinit {
        watchTask?.cancel()
    }

    /// Called when user taps + New Trip. Returns true if allowed.
    func requestCreateTrip() -> Bool {
        guard canCreateTrip else {
            showingTripLimitAlert = true
            return false
        }
        return true
    }

    // MARK: - Reactive Watch

    private func startWatching(userId: String) async {
        let showLoading = activeTrips.isEmpty
        if showLoading { isLoading = true }
        let start = ContinuousClock.now

        do {
            let stream = try tripRepository.watchTrips(userId: userId)
            var isFirst = true

            for try await trips in stream {
                guard !Task.isCancelled else { break }

                self.activeTrips = trips.filter { !$0.archived }
                self.archivedTrips = trips.filter { $0.archived }

                if isFirst {
                    if showLoading {
                        let elapsed = ContinuousClock.now - start
                        if elapsed < .milliseconds(500) {
                            try? await Task.sleep(for: .milliseconds(500) - elapsed)
                        }
                        isLoading = false
                    }
                    isFirst = false
                }

                // Refresh members when trips change
                let allTripIds = trips.map(\.id)
                if !allTripIds.isEmpty {
                    let members = try await tripRepository.fetchMembers(tripIds: allTripIds)
                    guard !Task.isCancelled else { break }
                    membersByTrip = members
                }
            }
        } catch {
            if !(error is CancellationError) {
                print("[Home] ❌ Watch error: \(error)")
            }
        }

        if isLoading { isLoading = false }
    }

    /// One-time fetch for pull-to-refresh.
    private func fetchOnce(userId: String) async {
        do {
            let result = try await tripRepository.fetchTrips(userId: userId)
            activeTrips = result.active
            archivedTrips = result.archived

            let allTripIds = (result.active + result.archived).map(\.id)
            if !allTripIds.isEmpty {
                membersByTrip = try await tripRepository.fetchMembers(tripIds: allTripIds)
            }
        } catch {
            print("[Home] ❌ fetchTrips failed: \(error)")
        }
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
