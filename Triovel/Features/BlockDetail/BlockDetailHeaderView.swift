import SwiftUI

/// Block header — display only. Shows title, context chip, time, location, description.
/// Tap "Add a description..." opens edit sheet (handled by parent).
struct BlockDetailHeaderView: View {
    let block: Block
    let canEdit: Bool
    let tripDisplayTimezone: String
    var billSummary: String?
    var onEditTap: (() -> Void)?

    private var isTBDBlock: Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: block.startAt)
        let minute = cal.component(.minute, from: block.startAt)
        return hour == 0 && minute == 0 && block.endAt == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Context chip + bill total
            HStack {
                ContextChip(context: block.context)
                Spacer()
                if let summary = billSummary {
                    Label(summary, systemImage: "banknote")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.08), in: Capsule())
                }
            }

            // Time row — trip timezone
            HStack(spacing: 4) {
                Label {
                    if isTBDBlock {
                        Text("block.card.no.time")
                    } else {
                        HStack(spacing: 4) {
                            TimeText(block.startAt, in: block.displayTimezone)
                            if let endAt = block.endAt {
                                Text("–")
                                TimeText(endAt, in: block.displayTimezone)
                            }
                        }
                    }
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.primary)
            }

            /* Local time row — commented out for now, re-enable later
            // Local time row — shown only if local timezone differs from trip
            if !isTBDBlock, let localTz = block.localTimezone,
               !localTz.isEmpty, localTz != tripDisplayTimezone {
                HStack(spacing: 4) {
                    Label {
                        HStack(spacing: 4) {
                            Text(formatInTimezone(block.startAt, tz: localTz))
                            if let endAt = block.endAt {
                                Text("–")
                                Text(formatInTimezone(endAt, tz: localTz))
                            }
                            Text(shortTimezoneLabel(localTz))
                                .fontWeight(.medium)
                        }
                    } icon: {
                        Image(systemName: "globe")
                    }
                    .font(.caption)
                    .foregroundStyle(.primary)
                }
            }
            */

            // Title
            Text(block.title)
                .font(.title2.weight(.semibold))
                .lineLimit(3)

            // Location
            if let location = block.locationText, !location.isEmpty {
                Label(location, systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Description
            if let description = block.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            } else if canEdit {
                Button {
                    onEditTap?()
                } label: {
                    Text("block.detail.description.placeholder")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    // MARK: - Helpers

    private func shortTimezoneLabel(_ identifier: String) -> String {
        TimezoneList.displayLabel(for: identifier)
    }

    private func formatInTimezone(_ date: Date, tz identifier: String) -> String {
        guard let tz = TimeZone(identifier: identifier) else {
            return date.formatted(.dateTime.hour().minute())
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = tz
        return formatter.string(from: date)
    }
}
