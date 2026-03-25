import SwiftUI

/// A single day's content in the timeline: ghost blocks + time slots with real blocks.
struct DaySectionView: View {
    let day: TimelineDay
    var creatorNameForBlock: ((Block) -> String?)? = nil
    let onGhostTap: (GhostBlock) -> Void
    let onBlockTap: (Block) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack(spacing: 8) {
                Text("timeline.day \(day.dayNumber)")
                    .font(TypographyTokens.sectionHeader)
                    .foregroundStyle(ColorTokens.label)

                Text(day.shortDate)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.secondaryLabel)
            }
            .padding(.horizontal, 20)

            let items = buildTimelineItems()

            ForEach(items) { item in
                switch item.content {
                case .ghost(let ghost):
                    GhostBlockView(ghost: ghost) {
                        onGhostTap(ghost)
                    }
                    .padding(.horizontal, 20)

                case .timeSlot(let slot):
                    TimeSlotView(
                        slot: slot,
                        creatorNameForBlock: creatorNameForBlock,
                        onBlockTap: onBlockTap
                    )
                    .padding(.horizontal, 20)
                }
            }

            if day.blocks.isEmpty && day.ghostBlocks.isEmpty {
                Text("timeline.no.moments")
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(ColorTokens.tertiaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }

    // MARK: - Build Chronological Items

    private func buildTimelineItems() -> [TimelineItem] {
        var items: [TimelineItem] = []

        for ghost in day.ghostBlocks {
            items.append(TimelineItem(
                sortTime: ghost.suggestedTime,
                content: .ghost(ghost)
            ))
        }

        for slot in day.timeSlots {
            items.append(TimelineItem(
                sortTime: slot.time,
                content: .timeSlot(slot)
            ))
        }

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

// MARK: - Time Slot View

private struct TimeSlotView: View {
    let slot: TimeSlot
    var creatorNameForBlock: ((Block) -> String?)?
    let onBlockTap: (Block) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(slot.time, style: .time)
                .font(TypographyTokens.captionMedium)
                .foregroundStyle(ColorTokens.secondaryLabel)

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
