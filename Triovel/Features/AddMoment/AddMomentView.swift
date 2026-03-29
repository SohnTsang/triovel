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
    @FocusState private var titleFocused: Bool

    @State private var title: String = ""
    @State private var context: BlockContext = .group
    @State private var isAllDay = false
    @State private var startTime = Date()
    @State private var hasEndTime = false
    @State private var endTime = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let blockRepository = BlockRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Title — large auto-focused input
                TextField(String(localized: "block.add.placeholder"), text: $title)
                    .font(.title3)
                    .focused($titleFocused)
                    .padding(.horizontal)
                    .disabled(isSaving)
                    .onChange(of: title) { _, newValue in
                        if newValue.count > 150 { title = String(newValue.prefix(150)) }
                    }

                // Context toggle — default Group
                Picker("Context", selection: $context) {
                    Text("block.add.context.group").tag(BlockContext.group)
                    Text("block.add.context.personal").tag(BlockContext.personal)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .disabled(isSaving)

                // All day toggle
                Toggle(String(localized: "block.add.all.day"), isOn: $isAllDay)
                    .padding(.horizontal)
                    .disabled(isSaving)
                    .onChange(of: isAllDay) { _, allDay in
                        if allDay { hasEndTime = false }
                    }

                // Time pickers (hidden when All Day)
                if !isAllDay {
                    DatePicker(
                        String(localized: "block.add.start.time"),
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                    .padding(.horizontal)
                    .disabled(isSaving)

                    // End time (optional)
                    VStack(spacing: 8) {
                        if hasEndTime {
                            DatePicker(
                                String(localized: "block.add.end.time"),
                                selection: $endTime,
                                in: startTime...,
                                displayedComponents: .hourAndMinute
                            )
                            .padding(.horizontal)
                            .disabled(isSaving)
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                hasEndTime.toggle()
                                if hasEndTime {
                                    endTime = Calendar.current.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
                                }
                            }
                        } label: {
                            Text(hasEndTime ? "block.add.end.time.remove" : "block.add.end.time.add")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.horizontal)
                        .disabled(isSaving)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("block.add.title")
                            .font(.headline)
                        if let dayDate {
                            Text("Day \(defaultDay) · \(dayDate, format: .dateTime.month(.abbreviated).day())")
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
            .onAppear {
                if let date = dayDate {
                    let cal = Calendar.current
                    if cal.isDateInToday(date) {
                        startTime = Date()
                    } else {
                        startTime = cal.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? Date()
                    }
                }
                titleFocused = true
            }
            .onChange(of: startTime) { _, newStart in
                // Keep end time valid
                if hasEndTime && endTime < newStart {
                    endTime = Calendar.current.date(byAdding: .hour, value: 1, to: newStart) ?? newStart
                }
            }
        }
        .presentationDetents(sizeClass == .regular ? [.medium, .large] : [.medium, .large])
    }

    private func createBlock() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        guard let userId = appState.currentUserId else { return }

        let startAt: Date
        let endAt: Date?
        if isAllDay {
            // All-day: use start of the day
            startAt = Calendar.current.startOfDay(for: dayDate ?? Date())
            endAt = nil
        } else {
            startAt = buildDateTime(from: startTime)
            endAt = hasEndTime ? buildDateTime(from: endTime) : nil
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                let block = try await blockRepository.createBlock(
                    tripId: tripId,
                    title: trimmedTitle,
                    context: context,
                    startAt: startAt,
                    endAt: endAt,
                    displayTimezone: displayTimezone,
                    createdBy: userId
                )

                await MainActor.run { timelineViewModel?.hideBlockUntilReady(block.id) }
                try? await Task.sleep(for: .milliseconds(500))
                await MainActor.run { timelineViewModel?.revealBlock(block.id) }
                dismiss()
                try? await Task.sleep(for: .milliseconds(300))
                onBlockCreated?(block.id)
            } catch {
                print("[AddMoment] ❌ Block creation failed: \(error)")
                errorMessage = String(localized: "block.add.error")
                isSaving = false
            }
        }
    }

    private func buildDateTime(from time: Date) -> Date {
        let cal = Calendar.current
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
