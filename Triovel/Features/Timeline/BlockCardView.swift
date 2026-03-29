import SwiftUI

/// Timeline block card with itinerary-style layout:
///   from time   Title
///   |           Location
///   to time     Local TZ label (if different from trip)
struct BlockCardView: View {
    let block: Block
    var creatorName: String?
    var tripDisplayTimezone: String = ""
    var syncState: SyncState = .synced

    private var hasEndTime: Bool { block.endAt != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: time column with vertical line
            timeColumn
                .frame(width: 56)

            // Right: content
            VStack(alignment: .leading, spacing: 4) {
                // Top row: title + sync indicator
                HStack(alignment: .top) {
                    Text(block.title)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    SyncStateIndicator(state: syncState)
                }

                // Location
                if let location = block.locationText, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Context chip for personal blocks
                if block.context == .personal {
                    ContextChip(context: .personal, userName: creatorName)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 12)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            block.context == .personal
                ? ColorTokens.personalBackground
                : Color(.secondarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    block.context == .personal
                        ? ColorTokens.personalBorder
                        : Color(.systemGray5),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Time Column

    /// True if block starts at midnight (all-day block)
    private var isAllDay: Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: block.startAt)
        let minute = cal.component(.minute, from: block.startAt)
        return hour == 0 && minute == 0 && block.endAt == nil
    }

    private var timeColumn: some View {
        VStack(spacing: 0) {
            if isAllDay {
                Text("block.card.all.day")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            } else {
                // Start time
                Text(block.startAt, format: .dateTime.hour().minute())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 12)

                // Local timezone label (e.g. "JST") — shown if different from trip
                if let localTz = block.localTimezone,
                   !localTz.isEmpty,
                   localTz != tripDisplayTimezone {
                    Text(shortTimezoneLabel(localTz))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 1)
                }

                // Vertical line
                if hasEndTime {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(minHeight: 16)
                        .padding(.vertical, 4)
                }

                // End time
                if let endAt = block.endAt {
                    Text(endAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .padding(.leading, 14)
    }

    private func shortTimezoneLabel(_ identifier: String) -> String {
        let tz = TimeZone(identifier: identifier) ?? .current
        return tz.abbreviation() ?? identifier
    }
}
