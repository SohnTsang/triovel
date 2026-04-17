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
    @State private var context: BlockContext
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
        _context = State(initialValue: block.context)
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

                // Context
                Section {
                    Picker("", selection: $context) {
                        Text("block.add.context.group").tag(BlockContext.group)
                        Text("block.add.context.personal").tag(BlockContext.personal)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
                            .environment(\.timeZone, TimeZone(identifier: block.displayTimezone) ?? .current)
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
                            TimeText(startAt, in: block.displayTimezone)
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
                            .environment(\.timeZone, TimeZone(identifier: block.displayTimezone) ?? .current)
                    }

                    // End date + time row
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
                                    Text(endTime.formatted(.dateTime.month(.abbreviated).day()) + " " + endTime.timeString(in: TimeZone(identifier: block.displayTimezone) ?? .current))
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
                            DatePicker("", selection: $endTime, in: startAt..., displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(height: 150)
                                .clipped()
                                .environment(\.timeZone, TimeZone(identifier: block.displayTimezone) ?? .current)
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
        let resolvedEndAt: Date? = hasEndTime ? endTime : nil

        let fields = EditBlockFields(
            title: title.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            context: context,
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
    let context: BlockContext
    let startAt: Date
    let endAt: Date?
    let localTimezone: String?
}
