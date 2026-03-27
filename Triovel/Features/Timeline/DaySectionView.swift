import SwiftUI

/// A single day's content in the timeline: time slots with real blocks.
struct DaySectionView: View {
    let day: TimelineDay
    var creatorNameForBlock: ((Block) -> String?)? = nil
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
                    creatorNameForBlock: creatorNameForBlock,
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
    var creatorNameForBlock: ((Block) -> String?)?
    let onBlockTap: (Block) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Shared time label
            Text(slot.time, style: .time)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            // Stacked block cards — full-width, never tiny side-by-side
            ForEach(slot.blocks) { block in
                BlockCardView(
                    block: block,
                    creatorName: creatorNameForBlock?(block)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onBlockTap(block)
                }
            }
        }
    }
}
