import Foundation
import SwiftUI

/// Drives the trip timeline: day generation, block grouping, ghost blocks, filtering.
@MainActor
final class TripTimelineViewModel: ObservableObject {
    @Published private(set) var trip: Trip?
    @Published private(set) var days: [TimelineDay] = []
    @Published private(set) var members: [TripMemberDisplay] = []
    @Published var selectedDayIndex: Int = 0
    @Published var activeFilter: TimelineFilter = .all

    /// All blocks for the trip, before filtering.
    private var allBlocks: [Block] = []

    // MARK: - Load

    func load(tripId: String, userId: String) {
        loadMockData(tripId: tripId, userId: userId)
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
        var timeZone = TimeZone(identifier: trip.displayTimezone) ?? .current
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

    // MARK: - Mock Data

    private func loadMockData(tripId: String, userId: String) {
        let cal = Calendar.current
        let now = Date()

        let mockTrip = Trip(
            id: tripId,
            title: "Tokyo Trip 2026",
            startDate: cal.date(byAdding: .day, value: -1, to: now)!,
            endDate: cal.date(byAdding: .day, value: 4, to: now)!,
            coverImagePath: nil,
            inviteLink: "TOKYO2026",
            displayTimezone: "Asia/Tokyo",
            baseCurrency: "JPY",
            archived: false,
            createdBy: userId,
            createdAt: cal.date(byAdding: .day, value: -7, to: now)!
        )

        let tripStart = cal.startOfDay(for: mockTrip.startDate)

        allBlocks = [
            Block(
                id: "block-001",
                tripId: tripId,
                title: "Ramen in Shibuya",
                context: .group,
                createdBy: userId,
                startAt: cal.date(bySettingHour: 12, minute: 30, second: 0, of: cal.date(byAdding: .day, value: 1, to: tripStart)!)!,
                displayTimezone: "Asia/Tokyo",
                createdAt: now
            ),
            Block(
                id: "block-002",
                tripId: tripId,
                title: "My airport transfer",
                context: .personal,
                createdBy: "other-user",
                startAt: cal.date(bySettingHour: 7, minute: 0, second: 0, of: tripStart)!,
                displayTimezone: "Asia/Tokyo",
                createdAt: now
            ),
            Block(
                id: "block-003",
                tripId: tripId,
                title: "Dinner at Gonpachi",
                context: .group,
                createdBy: userId,
                startAt: cal.date(bySettingHour: 19, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: tripStart)!)!,
                displayTimezone: "Asia/Tokyo",
                createdAt: now
            ),
            Block(
                id: "block-004",
                tripId: tripId,
                title: "Karaoke booking",
                context: .group,
                createdBy: "other-user",
                startAt: cal.date(bySettingHour: 19, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: tripStart)!)!,
                displayTimezone: "Asia/Tokyo",
                createdAt: now
            )
        ]

        members = [
            TripMemberDisplay(userId: userId, displayName: "Sohn", avatarPath: nil, role: .owner),
            TripMemberDisplay(userId: "other-user", displayName: "Alex", avatarPath: nil, role: .member),
            TripMemberDisplay(userId: "user-003", displayName: "Kim", avatarPath: nil, role: .member)
        ]

        trip = mockTrip
        days = generateDays(for: mockTrip)
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
