import SwiftUI

struct AddMomentView: View {
    let tripId: String
    let defaultDay: Int
    var dayDate: Date?
    var displayTimezone: String = TimeZone.current.identifier

    /// Called with the created block ID after successful creation.
    var onBlockCreated: ((String) -> Void)?
    /// Timeline ViewModel — used to hide the new block until loading finishes.
    var timelineViewModel: TripTimelineViewModel?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppState.self) private var appState
    @FocusState private var focusedField: Field?

    @State private var title: String = ""
    @State private var context: BlockContext = .group
    @State private var hasTime = true
    @State private var startTime = Date()
    @State private var hasEndTime = false
    @State private var endTime = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false

    private enum Field: Hashable { case title }

    private let blockRepository = BlockRepository()

    var body: some View {
        NavigationStack {
            List {
                // Title
                Section {
                    TextField(String(localized: "block.add.placeholder"), text: $title)
                        .focused($focusedField, equals: .title)
                        .onTapGesture { collapsePickers() }
                        .onChange(of: title) { _, newValue in
                            if newValue.count > 150 { title = String(newValue.prefix(150)) }
                        }
                }

                // Context toggle
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
                    // Time toggle
                    Toggle(String(localized: "block.add.set.time"), isOn: $hasTime)
                        .onChange(of: hasTime) { _, on in
                            if !on {
                                hasEndTime = false
                                showStartTimePicker = false
                                showEndTimePicker = false
                            }
                        }

                    if hasTime {
                        // Start time row
                        Button {
                            focusedField = nil
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showStartTimePicker.toggle()
                                showEndTimePicker = false
                            }
                        } label: {
                            HStack {
                                Label(String(localized: "block.add.start.time"), systemImage: "clock")
                                    .foregroundStyle(.primary)
                                Spacer()
                                TimeText(startTime, in: displayTimezone)
                                    .foregroundStyle(showStartTimePicker ? Color.accentColor : .secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if showStartTimePicker {
                            DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(height: 150)
                                .clipped()
                                .environment(\.timeZone, TimeZone(identifier: displayTimezone) ?? .current)
                        }

                        // End time
                        if hasEndTime {
                            HStack {
                                Button {
                                    focusedField = nil
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showEndTimePicker.toggle()
                                        showStartTimePicker = false
                                    }
                                } label: {
                                    HStack {
                                        Label(String(localized: "block.add.end.time"), systemImage: "clock.badge.checkmark")
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text(endTime.formatted(.dateTime.month(.abbreviated).day()) + " " + endTime.timeString(in: TimeZone(identifier: displayTimezone) ?? .current))
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
                                DatePicker("", selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(height: 150)
                                    .clipped()
                                    .environment(\.timeZone, TimeZone(identifier: displayTimezone) ?? .current)
                            }
                        } else {
                            Button {
                                collapsePickers()
                                let defaultEnd = Calendar.current.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
                                endTime = defaultEnd
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    hasEndTime = true
                                }
                            } label: {
                                Label(String(localized: "block.add.end.time.add"), systemImage: "plus")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .onChange(of: focusedField) { _, field in
                if field != nil { collapsePickers() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("block.add.title")
                            .font(.headline)
                        if let dayDate {
                            (Text("timeline.day \(defaultDay)") + Text(verbatim: " · ") + Text(dayDate, format: .dateTime.month(.abbreviated).day()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel")) { dismiss() }
                            .disabled(isSaving)
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .confirmationAction) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Button(String(localized: "common.save")) { createBlock() }
                                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel")) { dismiss() }
                            .disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Button(String(localized: "common.save")) { createBlock() }
                                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .allowsHitTesting(!isSaving)
            .onAppear {
                if let date = dayDate {
                    let cal = Calendar.current
                    if cal.isDateInToday(date) {
                        startTime = Date()
                    } else {
                        startTime = cal.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? Date()
                    }
                }
                focusedField = .title
            }
        }
        .presentationDetents([.large])
    }

    private func collapsePickers() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showStartTimePicker = false
            showEndTimePicker = false
        }
    }

    private func createBlock() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        guard let userId = appState.currentUserId else { return }

        let startAt: Date
        let endAt: Date?
        if !hasTime {
            var cal = Calendar.current
            cal.timeZone = TimeZone(identifier: displayTimezone) ?? .current
            startAt = cal.startOfDay(for: dayDate ?? Date())
            endAt = nil
        } else {
            startAt = buildDateTime(from: startTime)
            endAt = hasEndTime ? endTime : nil
        }

        isSaving = true
        errorMessage = nil

        let blockId = UUID().uuidString.lowercased()
        timelineViewModel?.hideBlockUntilReady(blockId)

        Task {
            let start = ContinuousClock.now
            do {
                let block = try await blockRepository.createBlock(
                    id: blockId,
                    tripId: tripId,
                    title: trimmedTitle,
                    context: context,
                    startAt: startAt,
                    endAt: endAt,
                    displayTimezone: displayTimezone,
                    createdBy: userId
                )

                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
                timelineViewModel?.revealBlock(block.id)
                dismiss()
                try? await Task.sleep(for: .milliseconds(300))
                onBlockCreated?(block.id)
            } catch {
                print("[AddMoment] ❌ Block creation failed: \(error)")
                timelineViewModel?.revealBlock(blockId)
                errorMessage = String(localized: "block.add.error")
                isSaving = false
            }
        }
    }

    private func buildDateTime(from time: Date) -> Date {
        var cal = Calendar.current
        cal.timeZone = TimeZone(identifier: displayTimezone) ?? .current

        let components = cal.dateComponents([.hour, .minute], from: time)

        if let dayDate {
            return cal.date(
                bySettingHour: components.hour ?? 12,
                minute: components.minute ?? 0,
                second: 0,
                of: dayDate
            ) ?? time
        }
        return time
    }
}
