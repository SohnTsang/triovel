import SwiftUI

/// A single day's content in the timeline: time slots with real blocks.
struct DaySectionView: View {
    let day: TimelineDay
    var tripDisplayTimezone: String = ""
    var creatorNameForBlock: ((Block) -> String?)? = nil
    var postCounts: [String: Int] = [:]
    var billCounts: [String: Int] = [:]
    var docCounts: [String: Int] = [:]
    let onBlockTap: (Block) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack {
                Text("timeline.day \(day.dayNumber)")
                    .font(.headline)
                Text(day.shortDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ForEach(day.timeSlots) { slot in
                TimeSlotView(
                    slot: slot,
                    tripDisplayTimezone: tripDisplayTimezone,
                    dayDate: day.date,
                    creatorNameForBlock: creatorNameForBlock,
                    postCounts: postCounts,
                    billCounts: billCounts,
                    docCounts: docCounts,
                    onBlockTap: onBlockTap
                )
                .padding(.horizontal)
            }

            // If no content at all, show minimal empty state
            if day.blocks.isEmpty {
                Text("timeline.no.moments")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }
}

// MARK: - Time Slot View (handles same-time clustering)

private struct TimeSlotView: View {
    let slot: TimeSlot
    var tripDisplayTimezone: String = ""
    var dayDate: Date
    var creatorNameForBlock: ((Block) -> String?)?
    var postCounts: [String: Int] = [:]
    var billCounts: [String: Int] = [:]
    var docCounts: [String: Int] = [:]
    let onBlockTap: (Block) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(slot.blocks) { block in
                BlockCardView(
                    block: block,
                    creatorName: creatorNameForBlock?(block),
                    tripDisplayTimezone: tripDisplayTimezone,
                    dayDate: dayDate,
                    postCount: postCounts[block.id] ?? 0,
                    billCount: billCounts[block.id] ?? 0,
                    docCount: docCounts[block.id] ?? 0
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onBlockTap(block)
                }
            }
        }
    }
}
