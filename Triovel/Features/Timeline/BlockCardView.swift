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
    var dayDate: Date? = nil
    var syncState: SyncState = .synced
    var postCount: Int = 0
    var billCount: Int = 0
    var docCount: Int = 0

    private var hasEndTime: Bool { block.endAt != nil }
    /* Local timezone display — commented out for now, re-enable later
    private var hasLocalTz: Bool {
        guard let tz = block.localTimezone, !tz.isEmpty else { return false }
        return tz != tripDisplayTimezone
    }
    */

    /// Block started before this day (spans in from previous day)
    private var isSpanningIn: Bool {
        guard let dayDate else { return false }
        return block.startAt < dayDate
    }

    /// Block ends after this day (spans out to next day)
    private var isSpanningOut: Bool {
        guard let dayDate, let endAt = block.endAt else { return false }
        let cal = Calendar.current
        let nextDay = cal.date(byAdding: .day, value: 1, to: dayDate) ?? dayDate
        return endAt > nextDay
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

                if postCount > 0 || docCount > 0 || billCount > 0 {
                    HStack(spacing: 0) {
                        if postCount > 0 {
                            contentBadge("text.bubble", count: postCount)
                        }
                        Spacer(minLength: 0)
                        HStack(spacing: 8) {
                            if docCount > 0 {
                                contentBadge("doc.text", count: docCount)
                            }
                            if billCount > 0 {
                                contentBadge("banknote", count: billCount)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 12)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if block.context == .personal {
                RoundedRectangle(cornerRadius: 12).fill(ColorTokens.personalBackground)
            } else {
                RoundedRectangle(cornerRadius: 12).fill(ColorTokens.cardBackground)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    block.context == .personal
                        ? ColorTokens.personalBorder
                        : Color(.systemGray4),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 2)
    }

    // MARK: - Time Column

    private var isAllDay: Bool {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: block.displayTimezone) ?? .current
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
            } else if isSpanningIn {
                // Continuation from previous day: line → end time
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(.systemGray4))
                    .frame(width: 2)
                    .frame(minHeight: 14)
                    .padding(.top, 12)
                    .padding(.bottom, 3)

                if let endAt = block.endAt {
                    TimeText(endAt, in: block.displayTimezone)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)

                    /* Local timezone display — commented out for now, re-enable later
                    if hasLocalTz {
                        Text(localTimeOnly(endAt))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .padding(.top, 1)
                    }
                    */
                }
            } else {
                // Normal: start time (+ optional line + end time)
                TimeText(block.startAt, in: block.displayTimezone)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 12)

                /* Local timezone display — commented out for now, re-enable later
                if hasLocalTz {
                    Text(localTimeOnly(block.startAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                }
                */

                if hasEndTime {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(minHeight: 14)
                        .padding(.vertical, 3)
                }

                if let endAt = block.endAt {
                    if isSpanningOut {
                        // Spans to next day: show line trailing off, no end time
                        // (end time shows on the next day)
                    } else {
                        TimeText(endAt, in: block.displayTimezone)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)

                        /* Local timezone display — commented out for now, re-enable later
                        if hasLocalTz {
                            Text(localTimeOnly(endAt))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .padding(.top, 1)
                        }
                        */
                    }
                }
            }

            Spacer(minLength: 12)
        }
        .frame(maxHeight: .infinity)
        .padding(.leading, 12)
    }

    // MARK: - Content Badge

    private func contentBadge(_ icon: String, count: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("\(count)")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    /// Format a date in the block's local timezone — just time, no abbreviation.
    private func localTimeOnly(_ date: Date) -> String {
        guard let tzId = block.localTimezone,
              let tz = TimeZone(identifier: tzId) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = tz
        return formatter.string(from: date)
    }
}
