import Foundation
import Observation

/// Drives the trip timeline: day generation, block grouping, filtering.
/// Watches blocks reactively — timeline updates when blocks change locally.
@Observable
@MainActor
final class TripTimelineViewModel {
    private(set) var trip: Trip?
    private(set) var days: [TimelineDay] = []
    private(set) var members: [TripMemberDisplay] = []
    private(set) var isLoading = true
    var selectedDayIndex: Int = 0
    var activeFilter: TimelineFilter = .all
    var selectedPersonId: String?

    /// All blocks for the trip, before filtering.
    private var allBlocks: [Block] = []

    /// Block IDs hidden from UI until loading finishes (write-immediately + hide pattern).
    private var pendingBlockIds: Set<String> = []

    /// Hide a block from the timeline until revealed. Called by AddMomentView.
    func hideBlockUntilReady(_ blockId: String) {
        pendingBlockIds.insert(blockId)
    }

    /// Reveal a previously hidden block. Called after 500ms loading finishes.
    func revealBlock(_ blockId: String) {
        pendingBlockIds.remove(blockId)
    }

    private let blockRepository = BlockRepository()
    private let tripRepository = TripRepository()
    private var currentTripId: String?
    private var currentUserId: String?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var blockWatchTask: Task<Void, Never>?

    // MARK: - Load

    func load(tripId: String, userId: String) {
        currentTripId = tripId
        currentUserId = userId

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.fetchTripData(tripId: tripId)
        }

        blockWatchTask?.cancel()
        blockWatchTask = Task { [weak self] in
            await self?.startWatchingBlocks(tripId: tripId)
        }
    }

    deinit {
        loadTask?.cancel()
        blockWatchTask?.cancel()
    }

    /// Find creator display name for a block.
    func creatorName(for block: Block) -> String? {
        members.first(where: { $0.userId == block.createdBy })?.displayName
    }

    /// Reset all filter state to defaults (session-only behavior).
    func resetFilters() {
        activeFilter = .all
        selectedPersonId = nil
    }

    // MARK: - Person Chips

    /// People who have at least one personal block. Shown as chips when Personal filter is active.
    var personalBlockAuthors: [PersonChipData] {
        let personalCreatorIds = Set(allBlocks.filter { $0.context == .personal }.map(\.createdBy))
        guard personalCreatorIds.count > 1 else { return [] }

        return personalCreatorIds.compactMap { userId in
            guard let name = members.first(where: { $0.userId == userId })?.displayName else { return nil }
            return PersonChipData(userId: userId, displayName: name)
        }
        .sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Filtered Days

    var filteredDays: [TimelineDay] {
        days.map { day in
            let filtered = day.blocks.filter { block in
                switch activeFilter {
                case .all:
                    return true
                case .group:
                    return block.context == .group
                case .personal:
                    if let personId = selectedPersonId {
                        return block.context == .personal && block.createdBy == personId
                    }
                    return block.context == .personal
                }
            }
            return TimelineDay(
                dayNumber: day.dayNumber,
                date: day.date,
                shortDate: day.shortDate,
                blocks: filtered
            )
        }
    }

    // MARK: - Fetch Trip + Members (one-time)

    private func fetchTripData(tripId: String) async {
        let showLoading = trip == nil
        if showLoading { isLoading = true }
        let start = ContinuousClock.now

        do {
            let fetchedTrip = try await blockRepository.fetchTrip(tripId: tripId)
            self.trip = fetchedTrip
            print("[Timeline] Trip loaded: \(fetchedTrip.title)")

            // Always generate days (even with 0 blocks) so day ribbon + FAB work immediately
            days = generateDays(for: fetchedTrip)

            let memberMap = try await tripRepository.fetchMembers(tripIds: [tripId])
            members = memberMap[tripId] ?? []
        } catch {
            print("[Timeline] ❌ fetchTripData failed: \(error)")
        }

        if showLoading {
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }
            isLoading = false
        }
    }

    // MARK: - Reactive Block Watch

    private func startWatchingBlocks(tripId: String) async {
        do {
            let stream = try blockRepository.watchBlocks(tripId: tripId)
            for try await blocks in stream {
                guard !Task.isCancelled else { break }
                allBlocks = blocks
                if let trip {
                    days = generateDays(for: trip)
                }
                print("[Timeline] Blocks updated: \(blocks.count)")
            }
        } catch {
            if !(error is CancellationError) {
                print("[Timeline] ❌ Block watch error: \(error)")
            }
        }
    }

    // MARK: - Day Generation

    private func generateDays(for trip: Trip) -> [TimelineDay] {
        let calendar = Calendar.current
        let timeZone = TimeZone(identifier: trip.displayTimezone) ?? .current
        var cal = calendar
        cal.timeZone = timeZone

        let startDay = cal.startOfDay(for: trip.startDate)
        let dayCount = trip.dayCount

        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MMM d"
        shortFormatter.timeZone = timeZone

        return (0..<dayCount).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: startDay) ?? startDay
            let dayNumber = offset + 1
            let shortDate = shortFormatter.string(from: date)

            let dayStart = cal.startOfDay(for: date)
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            // A block belongs to this day if:
            // - it starts on this day, OR
            // - it spans midnight and its endAt falls into this day
            let dayBlocks = allBlocks.filter { block in
                guard !pendingBlockIds.contains(block.id) else { return false }
                let startsOnDay = block.startAt >= dayStart && block.startAt < dayEnd
                let spansIntoDay = block.startAt < dayStart
                    && block.endAt != nil
                    && block.endAt! > dayStart
                return startsOnDay || spansIntoDay
            }.sorted { a, b in
                let aIsTBD = isMidnight(a.startAt, in: cal) && a.endAt == nil
                let bIsTBD = isMidnight(b.startAt, in: cal) && b.endAt == nil
                // TBD blocks sort after timed blocks
                if aIsTBD != bIsTBD { return !aIsTBD }
                // Blocks sort by startAt. Both on this day = normal compare.
                return a.startAt < b.startAt
            }

            return TimelineDay(
                dayNumber: dayNumber,
                date: date,
                shortDate: shortDate,
                blocks: dayBlocks
            )
        }
    }

    private func isMidnight(_ date: Date, in cal: Calendar) -> Bool {
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        return hour == 0 && minute == 0
    }
}

// MARK: - Timeline Day Model

struct TimelineDay: Identifiable {
    let dayNumber: Int
    let date: Date
    let shortDate: String
    let blocks: [Block]

    var id: Int { dayNumber }

    /// Blocks grouped by start time for same-time clustering.
    /// Sort within cluster: group first, then personal, then by createdAt.
    /// Timestamps are NEVER mutated — clustering is pure UI grouping.
    var timeSlots: [TimeSlot] {
        var slots: [String: [Block]] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        for block in blocks {
            let key: String
            if block.startAt < date, let endAt = block.endAt {
                // Spanning in from previous day — use end time as the sort key
                key = formatter.string(from: endAt)
            } else {
                key = formatter.string(from: block.startAt)
            }
            slots[key, default: []].append(block)
        }

        return slots.compactMap { key, blocks in
            let sorted = blocks.sorted { a, b in
                if a.context != b.context {
                    return a.context == .group
                }
                return a.createdAt < b.createdAt
            }
            guard let firstBlock = sorted.first else { return nil }
            let isTBD = key == "00:00" && sorted.allSatisfy { $0.endAt == nil }
            return TimeSlot(timeKey: key, time: firstBlock.startAt, blocks: sorted, isTBD: isTBD)
        }
        .sorted { a, b in
            // TBD slots sort after timed slots
            if a.isTBD != b.isTBD { return !a.isTBD }
            return a.timeKey < b.timeKey
        }
    }
}

/// A group of blocks sharing the same start time.
struct TimeSlot: Identifiable {
    let timeKey: String
    let time: Date
    let blocks: [Block]
    var isTBD: Bool = false

    var id: String { timeKey }
    var isCluster: Bool { blocks.count > 1 }
}
