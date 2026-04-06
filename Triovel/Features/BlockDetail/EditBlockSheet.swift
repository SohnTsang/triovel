import SwiftUI

/// Sheet for editing block header fields: title, location, date, time, timezone, description.
/// Clean form layout matching Apple Calendar / Airbnb edit patterns.
struct EditBlockSheet: View {
    let block: Block
    let tripDisplayTimezone: String
    let tripStartDate: Date
    let tripEndDate: Date
    let onSave: (EditBlockFields) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    @State private var title: String
    @State private var location: String
    @State private var description: String
    @State private var startAt: Date
    @State private var hasEndTime: Bool
    @State private var endTime: Date
    @State private var localTimezone: String?

    @State private var showDatePicker = false
    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false
    @State private var showTimezonePicker = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, location, description
    }

    init(block: Block, tripDisplayTimezone: String, tripStartDate: Date, tripEndDate: Date, onSave: @escaping (EditBlockFields) async -> Void) {
        self.block = block
        self.tripDisplayTimezone = tripDisplayTimezone
        self.tripStartDate = tripStartDate
        self.tripEndDate = tripEndDate
        self.onSave = onSave
        _title = State(initialValue: block.title)
        _location = State(initialValue: block.locationText ?? "")
        _description = State(initialValue: block.description ?? "")
        _startAt = State(initialValue: block.startAt)
        _hasEndTime = State(initialValue: block.endAt != nil)
        _endTime = State(initialValue: block.endAt ?? Calendar.current.date(byAdding: .hour, value: 1, to: block.startAt) ?? block.startAt)
        _localTimezone = State(initialValue: block.localTimezone)
    }

    private var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                // Title & Location
                Section {
                    TextField(String(localized: "block.edit.title.placeholder"), text: $title)
                        .focused($focusedField, equals: .title)
                        .onTapGesture { collapsePickers() }
                        .onChange(of: title) { _, v in
                            if v.count > 150 { title = String(v.prefix(150)) }
                        }

                    TextField(String(localized: "block.edit.location.placeholder"), text: $location)
                        .focused($focusedField, equals: .location)
                        .onTapGesture { collapsePickers() }
                        .onChange(of: location) { _, v in
                            if v.count > 100 { location = String(v.prefix(100)) }
                        }
                }

                // Date & Time
                Section {
                    // Date row
                    Button {
                        focusedField = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDatePicker.toggle()
                            showStartTimePicker = false
                            showEndTimePicker = false
                        }
                    } label: {
                        HStack {
                            Label(String(localized: "block.edit.date"), systemImage: "calendar")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(startAt, format: .dateTime.year().month(.abbreviated).day())
                                .foregroundStyle(showDatePicker ? Color.accentColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showDatePicker {
                        DatePicker("", selection: $startAt, in: tripStartDate...tripEndDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }

                    // Start time row
                    Button {
                        focusedField = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStartTimePicker.toggle()
                            showDatePicker = false
                            showEndTimePicker = false
                        }
                    } label: {
                        HStack {
                            Label(String(localized: "block.edit.start.time"), systemImage: "clock")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(startAt, format: .dateTime.hour().minute())
                                .foregroundStyle(showStartTimePicker ? Color.accentColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showStartTimePicker {
                        DatePicker("", selection: $startAt, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(height: 150)
                            .clipped()
                    }

                    // End time row
                    if hasEndTime {
                        HStack {
                            Button {
                                focusedField = nil
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showEndTimePicker.toggle()
                                    showDatePicker = false
                                    showStartTimePicker = false
                                }
                            } label: {
                                HStack {
                                    Label(String(localized: "block.edit.end.time"), systemImage: "clock.badge.checkmark")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(endTime, format: .dateTime.hour().minute())
                                        .foregroundStyle(showEndTimePicker ? Color.accentColor : .secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    hasEndTime = false
                                    showEndTimePicker = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(Color(.systemGray3))
                            }
                            .buttonStyle(.plain)
                        }

                        if showEndTimePicker {
                            DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(height: 150)
                                .clipped()
                        }
                    } else {
                        Button {
                            collapsePickers()
                            let defaultEnd = Calendar.current.date(byAdding: .hour, value: 1, to: startAt) ?? startAt
                            endTime = defaultEnd
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hasEndTime = true
                            }
                        } label: {
                            Label(String(localized: "block.edit.end.time.add"), systemImage: "plus")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                /* Local timezone section — commented out for now, re-enable later
                // Timezone
                Section {
                    Button {
                        collapsePickers()
                        showTimezonePicker = true
                    } label: {
                        HStack {
                            Label(String(localized: "block.edit.timezone.picker.title"), systemImage: "globe")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(timezoneDisplayText)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                */

                // Description
                Section {
                    TextField(
                        String(localized: "block.detail.description.placeholder"),
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...10)
                    .focused($focusedField, equals: .description)
                    .onTapGesture { collapsePickers() }
                    .onChange(of: description) { _, v in
                        if v.count > 500 { description = String(v.prefix(500)) }
                    }
                }
            }
            .onChange(of: focusedField) { _, field in
                if field != nil { collapsePickers() }
            }
            .navigationTitle(String(localized: "block.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button(String(localized: "common.save")) {
                            save()
                        }
                        .disabled(!isTitleValid)
                    }
                }
            }
            .sheet(isPresented: $showTimezonePicker) {
                NavigationStack {
                    TimezonePickerView(
                        selection: Binding(
                            get: { localTimezone ?? "" },
                            set: { localTimezone = $0.isEmpty ? nil : $0 }
                        ),
                        tripDisplayTimezone: tripDisplayTimezone
                    )
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: startAt) { _, _ in }
            .interactiveDismissDisabled(isSaving)
            .allowsHitTesting(!isSaving)
        }
    }

    private func collapsePickers() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showDatePicker = false
            showStartTimePicker = false
            showEndTimePicker = false
        }
    }

    private var timezoneDisplayText: String {
        if let tz = localTimezone, !tz.isEmpty {
            return TimezoneList.displayLabel(for: tz)
        }
        return String(localized: "block.edit.timezone.same.as.trip")
    }

    private func save() {
        var resolvedEndAt: Date? = nil
        if hasEndTime {
            var end = endTime
            // Cross-midnight: end time before start time means next day
            if end <= startAt {
                end = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
            }
            resolvedEndAt = end
        }

        let fields = EditBlockFields(
            title: title.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            startAt: startAt,
            endAt: resolvedEndAt,
            localTimezone: localTimezone
        )
        isSaving = true
        Task {
            await onSave(fields)
            dismiss()
        }
    }
}

/// Data container for edited block fields.
struct EditBlockFields {
    let title: String
    let location: String
    let description: String
    let startAt: Date
    let endAt: Date?
    let localTimezone: String?
}
