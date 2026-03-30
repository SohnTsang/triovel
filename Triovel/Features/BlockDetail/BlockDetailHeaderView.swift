import SwiftUI

/// Block header showing title, context chip, time, location, and description.
/// Editable by block creator or trip owner only.
/// Edit mode: grouped card with Title, Location, Start+End time, Local TZ, Description.
struct BlockDetailHeaderView: View {
    let block: Block
    let canEdit: Bool
    let tripDisplayTimezone: String
    var isSaving: Bool = false
    var billSummary: String?
    @Binding var isEditing: Bool
    @Binding var editTitle: String
    @Binding var editLocation: String
    @Binding var editDescription: String
    @Binding var editStartAt: Date
    @Binding var editEndAt: Date?
    @Binding var editLocalTimezone: String?
    let onSave: () -> Void

    @State private var hasEndTime = false
    @State private var editEndTime = Date()
    @FocusState private var focusedField: EditField?

    private var isTBDBlock: Bool {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: block.startAt)
        let minute = cal.component(.minute, from: block.startAt)
        return hour == 0 && minute == 0 && block.endAt == nil
    }

    private enum EditField {
        case title, location, description
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                editingContent
            } else {
                displayContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                hasEndTime = editEndAt != nil
                editEndTime = editEndAt ?? (Calendar.current.date(byAdding: .hour, value: 1, to: editStartAt) ?? editStartAt)
            }
        }
        .onChange(of: editEndTime) { _, newEnd in
            if hasEndTime { editEndAt = newEnd }
        }
    }

    // MARK: - Display Mode

    @ViewBuilder
    private var displayContent: some View {
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

        // Time row
        HStack(spacing: 4) {
            Label {
                if isTBDBlock {
                    Text("block.card.no.time")
                } else {
                    HStack(spacing: 4) {
                        Text(block.startAt, format: .dateTime.hour().minute())
                        if let endAt = block.endAt {
                            Text("–")
                                .foregroundStyle(.tertiary)
                            Text(endAt, format: .dateTime.hour().minute())
                        }
                    }
                }
            } icon: {
                Image(systemName: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            // Local timezone label (e.g. "JST")
            if let localTz = block.localTimezone,
               !localTz.isEmpty,
               localTz != tripDisplayTimezone {
                Text(shortTimezoneLabel(localTz))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5), in: Capsule())
            }
        }

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
                editTitle = block.title
                editLocation = block.locationText ?? ""
                editDescription = ""
                editStartAt = block.startAt
                editEndAt = block.endAt
                editLocalTimezone = block.localTimezone
                isEditing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = .description
                }
            } label: {
                Text("block.detail.description.placeholder")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Editing Mode

    @ViewBuilder
    private var editingContent: some View {
        // Action bar
        HStack {
            Button {
                focusedField = nil
                isEditing = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("block.edit.title")
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button {
                focusedField = nil
                onSave()
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(
                                editTitle.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color(.systemGray3) : Color.accentColor
                            )
                    }
                }
                .frame(width: 28, height: 28)
            }
            .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
        }
        .padding(.bottom, 4)

        // Grouped edit card
        VStack(spacing: 0) {
            // Title
            editRow {
                HStack(spacing: 10) {
                    Image(systemName: "textformat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    TextField(String(localized: "block.edit.title.placeholder"), text: $editTitle)
                        .font(.body)
                        .focused($focusedField, equals: .title)
                        .onChange(of: editTitle) { _, v in
                            if v.count > 150 { editTitle = String(v.prefix(150)) }
                        }
                }
            }

            groupDivider

            // Location
            editRow {
                HStack(spacing: 10) {
                    Image(systemName: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    TextField(String(localized: "block.edit.location.placeholder"), text: $editLocation)
                        .font(.body)
                        .focused($focusedField, equals: .location)
                        .onChange(of: editLocation) { _, v in
                            if v.count > 100 { editLocation = String(v.prefix(100)) }
                        }
                }
            }

            groupDivider

            // Start + End time (same row)
            editRow {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    DatePicker("", selection: $editStartAt, displayedComponents: .hourAndMinute)
                        .labelsHidden()

                    Text("–")
                        .foregroundStyle(.tertiary)

                    if hasEndTime {
                        DatePicker("", selection: $editEndTime, in: editStartAt..., displayedComponents: .hourAndMinute)
                            .labelsHidden()

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hasEndTime = false
                                editEndAt = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Button {
                            let defaultEnd = Calendar.current.date(byAdding: .hour, value: 1, to: editStartAt) ?? editStartAt
                            editEndTime = defaultEnd
                            editEndAt = defaultEnd
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hasEndTime = true
                            }
                        } label: {
                            Text("block.edit.end.time.add")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    Spacer()
                }
            }

            groupDivider

            // Local timezone (optional)
            editRow {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)

                    if let tz = editLocalTimezone, !tz.isEmpty {
                        Text(fullTimezoneLabel(tz))
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            editLocalTimezone = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Picker(String(localized: "block.edit.local.timezone"), selection: Binding(
                            get: { editLocalTimezone ?? "" },
                            set: { editLocalTimezone = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("block.edit.local.timezone.none").tag("")
                            ForEach(commonTimezones, id: \.self) { tz in
                                Text(fullTimezoneLabel(tz)).tag(tz)
                            }
                        }
                        .labelsHidden()
                        Spacer()
                    }
                }
            }

            groupDivider

            // Description
            editRow(minHeight: 80) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.alignleft")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                        .padding(.top, 2)
                    TextField(
                        String(localized: "block.detail.description.placeholder"),
                        text: $editDescription,
                        axis: .vertical
                    )
                    .font(.body)
                    .lineLimit(3...8)
                    .focused($focusedField, equals: .description)
                    .onChange(of: editDescription) { _, v in
                        if v.count > 500 { editDescription = String(v.prefix(500)) }
                    }
                }
            }
        }
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func editRow<Content: View>(minHeight: CGFloat = 44, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight, alignment: .center)
    }

    private var groupDivider: some View {
        Divider()
            .padding(.leading, 44)
    }

    private func shortTimezoneLabel(_ identifier: String) -> String {
        let tz = TimeZone(identifier: identifier) ?? .current
        return tz.abbreviation() ?? identifier
    }

    private func fullTimezoneLabel(_ identifier: String) -> String {
        let tz = TimeZone(identifier: identifier) ?? .current
        let abbr = tz.abbreviation() ?? ""
        let offset = tz.secondsFromGMT()
        let hours = offset / 3600
        let sign = hours >= 0 ? "+" : ""
        let city = identifier.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? identifier
        return "\(abbr) (UTC\(sign)\(hours)) — \(city)"
    }

    private let commonTimezones = [
        "Asia/Tokyo", "Asia/Hong_Kong", "Asia/Shanghai", "Asia/Taipei",
        "Asia/Seoul", "Asia/Singapore", "Asia/Bangkok",
        "Australia/Sydney", "Australia/Melbourne",
        "Pacific/Auckland",
        "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
        "America/Vancouver", "America/Toronto",
        "Europe/London", "Europe/Paris", "Europe/Berlin", "Europe/Rome",
        "Pacific/Honolulu",
    ]
}
