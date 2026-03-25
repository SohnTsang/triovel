import SwiftUI

/// A single day's content in the timeline: ghost blocks + time slots with real blocks.
struct DaySectionView: View {
    let day: TimelineDay
    let onGhostTap: (GhostBlock) -> Void
    let onBlockTap: (Block) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack {
                Text("Day \(day.dayNumber)")
                    .font(.headline)
                Text(day.shortDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Interleave ghost blocks and time slots chronologically
            let items = buildTimelineItems()

            ForEach(items) { item in
                switch item.content {
                case .ghost(let ghost):
                    GhostBlockView(ghost: ghost) {
                        onGhostTap(ghost)
                    }
                    .padding(.horizontal)

                case .timeSlot(let slot):
                    TimeSlotView(slot: slot, onBlockTap: onBlockTap)
                        .padding(.horizontal)
                }
            }

            // If no content at all (no blocks, no ghosts), show minimal empty state
            if day.blocks.isEmpty && day.ghostBlocks.isEmpty {
                Text("No moments yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }

    // MARK: - Build Chronological Items

    private func buildTimelineItems() -> [TimelineItem] {
        var items: [TimelineItem] = []

        // Add ghost blocks
        for ghost in day.ghostBlocks {
            items.append(TimelineItem(
                sortTime: ghost.suggestedTime,
                content: .ghost(ghost)
            ))
        }

        // Add time slots (clusters of real blocks)
        for slot in day.timeSlots {
            items.append(TimelineItem(
                sortTime: slot.time,
                content: .timeSlot(slot)
            ))
        }

        // Sort chronologically
        return items.sorted { $0.sortTime < $1.sortTime }
    }
}

// MARK: - Timeline Item

private struct TimelineItem: Identifiable {
    let id = UUID()
    let sortTime: Date
    let content: Content

    enum Content {
        case ghost(GhostBlock)
        case timeSlot(TimeSlot)
    }
}

// MARK: - Time Slot View (handles same-time clustering)

private struct TimeSlotView: View {
    let slot: TimeSlot
    let onBlockTap: (Block) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Shared time label
            Text(slot.time, style: .time)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            // Stacked block cards — full-width, never tiny side-by-side
            ForEach(slot.blocks) { block in
                BlockCardView(block: block)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onBlockTap(block)
                    }
            }
        }
    }
}
