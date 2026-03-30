import SwiftUI

/// Timeline block card with itinerary-style layout:
///   10:00 AM        Title
///   (7:00 PM JST)   Location
///   |
///   11:30 AM
struct BlockCardView: View {
    let block: Block
    var creatorName: String?
    var tripDisplayTimezone: String = ""
    var syncState: SyncState = .synced

    private var hasEndTime: Bool { block.endAt != nil }
    private var hasLocalTz: Bool {
        guard let tz = block.localTimezone, !tz.isEmpty else { return false }
        return tz != tripDisplayTimezone
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: time column
            timeColumn
                .frame(width: 72)

            // Right: content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(block.title)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    SyncStateIndicator(state: syncState)
                }

                if let location = block.locationText, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

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

    private var isAllDay: Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: block.startAt)
        let minute = cal.component(.minute, from: block.startAt)
        return hour == 0 && minute == 0 && block.endAt == nil
    }

    private var timeColumn: some View {
        VStack(spacing: 0) {
            if isAllDay {
                Text("block.card.no.time")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            } else {
                // Start time (trip timezone)
                Text(block.startAt, format: .dateTime.hour().minute())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 12)

                // Local time below start — e.g. "7:15 PM JST"
                if hasLocalTz {
                    Text(localTimeLabel(block.startAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                }

                // Vertical line
                if hasEndTime {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(minHeight: 14)
                        .padding(.vertical, 3)
                }

                // End time — same style as start time
                if let endAt = block.endAt {
                    Text(endAt, format: .dateTime.hour().minute())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .padding(.leading, 12)
    }

    // MARK: - Helpers

    /// Format a date in the block's local timezone: "7:15 PM JST"
    private func localTimeLabel(_ date: Date) -> String {
        guard let tzId = block.localTimezone,
              let tz = TimeZone(identifier: tzId) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = tz
        let time = formatter.string(from: date)
        let abbr = tz.abbreviation(for: date) ?? tzId
        return "\(time) \(abbr)"
    }
}
