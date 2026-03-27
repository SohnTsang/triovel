import Foundation
import Observation

/// Drives the trip timeline: day generation, block grouping, ghost blocks, filtering.
@Observable
@MainActor
final class TripTimelineViewModel {
    private(set) var trip: Trip?
    private(set) var days: [TimelineDay] = []
    private(set) var members: [TripMemberDisplay] = []
    private(set) var isLoading = false
    var selectedDayIndex: Int = 0
    var activeFilter: TimelineFilter = .all

    /// All blocks for the trip, before filtering.
    private var allBlocks: [Block] = []

    private let blockRepository = BlockRepository()
    private let tripRepository = TripRepository()
    private var currentTripId: String?
    private var currentUserId: String?
    nonisolated(unsafe) private var loadTask: Task<Void, Never>?

    // MARK: - Load

    func load(tripId: String, userId: String) {
        currentTripId = tripId
        currentUserId = userId
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.fetchTripData(tripId: tripId, userId: userId)
        }
    }

    deinit {
        loadTask?.cancel()
    }

    private func fetchTripData(tripId: String, userId: String) async {
        isLoading = trip == nil
        print("[Timeline] Loading trip: \(tripId)")

        do {
            // Fetch trip details
            let fetchedTrip = try await blockRepository.fetchTrip(tripId: tripId)
            self.trip = fetchedTrip
            print("[Timeline] Trip loaded: \(fetchedTrip.title)")

            // Fetch blocks
            let blocks = try await blockRepository.fetchBlocks(tripId: tripId)
            allBlocks = blocks
            days = generateDays(for: fetchedTrip)
            print("[Timeline] Loaded \(blocks.count) blocks, \(days.count) days")

            // Fetch members
            let memberMap = try await tripRepository.fetchMembers(tripIds: [tripId])
            members = memberMap[tripId] ?? []
            print("[Timeline] Loaded \(members.count) members")
        } catch {
            print("[Timeline] ❌ fetchTripData failed: \(error)")
        }

        isLoading = false
    }

    /// Refresh blocks from Supabase after a new block is created.
    func refreshBlocks() async {
        guard let tripId = currentTripId else { return }
        do {
            let blocks = try await blockRepository.fetchBlocks(tripId: tripId)
            allBlocks = blocks
            print("[Timeline] Refreshed blocks: \(blocks.count)")
            if let trip {
                days = generateDays(for: trip)
            }
        } catch {
            print("[Timeline] ❌ refreshBlocks failed: \(error)")
            // Silently fail — keep showing existing data
        }
    }

    /// Find creator display name for a block.
    func creatorName(for block: Block) -> String? {
        members.first(where: { $0.userId == block.createdBy })?.displayName
    }

    // MARK: - Filtered Days

    /// Days with blocks filtered by current filter.
    var filteredDays: [TimelineDay] {
        days.map { day in
            let filtered = day.blocks.filter { block in
                switch activeFilter {
                case .all: return true
                case .group: return block.context == .group
                case .personal: return block.context == .personal
                }
            }
            return TimelineDay(
                dayNumber: day.dayNumber,
                date: day.date,
                shortDate: day.shortDate,
                blocks: filtered,
                ghostBlocks: activeFilter == .personal ? [] : day.ghostBlocks
            )
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
            let date = cal.date(byAdding: .day, value: offset, to: startDay)!
            let dayNumber = offset + 1
            let shortDate = shortFormatter.string(from: date)

            // Blocks for this day
            let dayStart = cal.startOfDay(for: date)
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
            let dayBlocks = allBlocks.filter { block in
                block.startAt >= dayStart && block.startAt < dayEnd
            }.sorted { $0.startAt < $1.startAt }

            // Ghost blocks for slots not covered by real blocks
            let ghosts = generateGhostBlocks(for: date, existingBlocks: dayBlocks, calendar: cal)

            return TimelineDay(
                dayNumber: dayNumber,
                date: date,
                shortDate: shortDate,
                blocks: dayBlocks,
                ghostBlocks: ghosts
            )
        }
    }

    private func generateGhostBlocks(
        for date: Date,
        existingBlocks: [Block],
        calendar: Calendar
    ) -> [GhostBlock] {
        GhostBlockLabel.allCases.compactMap { label in
            // Check if any real block covers this ghost's time window (±2h)
            let ghostHour = label.defaultHour
            let hasRealBlock = existingBlocks.contains { block in
                let blockHour = calendar.component(.hour, from: block.startAt)
                return abs(blockHour - ghostHour) <= 2
            }

            if hasRealBlock { return nil }

            let suggestedTime = calendar.date(
                bySettingHour: ghostHour,
                minute: 0,
                second: 0,
                of: date
            )!

            return GhostBlock(
                id: "ghost-\(label.rawValue)-\(date.timeIntervalSince1970)",
                dayDate: date,
                label: label,
                suggestedTime: suggestedTime
            )
        }
    }
}

// MARK: - Timeline Day Model

struct TimelineDay: Identifiable {
    let dayNumber: Int
    let date: Date
    let shortDate: String
    let blocks: [Block]
    let ghostBlocks: [GhostBlock]

    var id: Int { dayNumber }

    /// Blocks grouped by start time for same-time clustering.
    var timeSlots: [TimeSlot] {
        var slots: [String: [Block]] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        for block in blocks {
            let key = formatter.string(from: block.startAt)
            slots[key, default: []].append(block)
        }

        return slots.map { key, blocks in
            // Sort within cluster: group first, then personal, then by createdAt
            let sorted = blocks.sorted { a, b in
                if a.context != b.context {
                    return a.context == .group
                }
                return a.createdAt < b.createdAt
            }
            return TimeSlot(timeKey: key, time: sorted.first!.startAt, blocks: sorted)
        }
        .sorted { $0.time < $1.time }
    }
}

/// A group of blocks sharing the same start time.
struct TimeSlot: Identifiable {
    let timeKey: String
    let time: Date
    let blocks: [Block]

    var id: String { timeKey }
    var isCluster: Bool { blocks.count > 1 }
}
