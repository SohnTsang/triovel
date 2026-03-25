import SwiftUI

struct AddMomentView: View {
    let tripId: String
    let defaultDay: Int
    var dayDate: Date?
    var ghostLabel: GhostBlockLabel?
    var displayTimezone: String = TimeZone.current.identifier

    /// Called with the created block ID after successful creation.
    var onBlockCreated: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
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
                TextField("What's happening?", text: $title)
                    .font(.title3)
                    .focused($titleFocused)
                    .padding(.horizontal)
                    .disabled(isSaving)

                // Context toggle — default Group
                Picker("Context", selection: $context) {
                    Text("Group").tag(BlockContext.group)
                    Text("Personal").tag(BlockContext.personal)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .disabled(isSaving)

                // Time picker
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
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
            .navigationTitle("Add Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            createBlock()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onAppear {
                if let label = ghostLabel {
                    title = label.rawValue
                    if let date = dayDate {
                        let cal = Calendar.current
                        time = cal.date(bySettingHour: label.defaultHour, minute: 0, second: 0, of: date) ?? Date()
                    }
                } else if let date = dayDate {
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
        .presentationDetents([.medium])
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
                let block = try await blockRepository.createBlock(
                    tripId: tripId,
                    title: trimmedTitle,
                    context: context,
                    startAt: startAt,
                    displayTimezone: displayTimezone,
                    createdBy: userId
                )

                dismiss()
                // Small delay for sheet dismiss animation
                try? await Task.sleep(for: .milliseconds(300))
                onBlockCreated?(block.id)
            } catch {
                errorMessage = "Could not create block. Please try again."
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
