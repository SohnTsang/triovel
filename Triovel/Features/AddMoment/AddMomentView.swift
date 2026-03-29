import SwiftUI

struct AddMomentView: View {
    let tripId: String
    let defaultDay: Int
    var dayDate: Date?
    var displayTimezone: String = TimeZone.current.identifier

    /// Called with the created block ID after successful creation.
    var onBlockCreated: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppState.self) private var appState
    @FocusState private var titleFocused: Bool

    @State private var title: String = ""
    @State private var context: BlockContext = .group
    @State private var time = Date()
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

                // Time picker
                DatePicker(String(localized: "block.add.time"), selection: $time, displayedComponents: .hourAndMinute)
                    .padding(.horizontal)
                    .disabled(isSaving)

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
                        time = Date()
                    } else {
                        time = cal.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? Date()
                    }
                }
                titleFocused = true
            }
        }
        .presentationDetents(sizeClass == .regular ? [.medium, .large] : [.medium])
    }

    private func createBlock() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        guard let userId = appState.currentUserId else { return }

        // Build the full startAt by combining dayDate with selected time
        let startAt = buildStartAt()

        isSaving = true
        errorMessage = nil

        Task {
            do {
                // Write to DB immediately (offline-safe)
                print("[AddMoment] Creating block: tripId=\(tripId), title=\(trimmedTitle), context=\(context.rawValue), startAt=\(startAt), tz=\(displayTimezone), userId=\(userId)")
                let block = try await blockRepository.createBlock(
                    tripId: tripId,
                    title: trimmedTitle,
                    context: context,
                    startAt: startAt,
                    displayTimezone: displayTimezone,
                    createdBy: userId
                )
                print("[AddMoment] Block created: \(block.id)")

                // 500ms minimum spinner, then navigate
                try? await Task.sleep(for: .milliseconds(500))
                dismiss()
                try? await Task.sleep(for: .milliseconds(300))
                onBlockCreated?(block.id)
            } catch {
                print("[AddMoment] ❌ Block creation failed: \(error)")
                print("[AddMoment] ❌ Error type: \(type(of: error))")
                if let localizedError = error as? LocalizedError {
                    print("[AddMoment] ❌ Description: \(localizedError.errorDescription ?? "nil")")
                }
                errorMessage = String(localized: "block.add.error")
                isSaving = false
            }
        }
    }

    /// Combine the day date with the selected time.
    private func buildStartAt() -> Date {
        let cal = Calendar.current
        let timeComponents = cal.dateComponents([.hour, .minute], from: time)

        if let dayDate {
            return cal.date(
                bySettingHour: timeComponents.hour ?? 12,
                minute: timeComponents.minute ?? 0,
                second: 0,
                of: dayDate
            ) ?? time
        }

        return time
    }
}
