import SwiftUI

struct AddMomentView: View {
    let tripId: String
    let defaultDay: Int
    var dayDate: Date?
    var ghostLabel: GhostBlockLabel?
    var displayTimezone: String = TimeZone.current.identifier

    var onBlockCreated: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
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
            VStack(spacing: 24) {
                // Title — large auto-focused input
                VStack(alignment: .leading, spacing: 8) {
                    Text("block.add.placeholder")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.secondaryLabel)
                        .padding(.horizontal, 4)

                    TextField(String(localized: "block.add.placeholder"), text: $title)
                        .font(.title3.weight(.medium))
                        .focused($titleFocused)
                        .disabled(isSaving)
                }
                .padding(.horizontal, 20)

                // Context toggle
                Picker("Context", selection: $context) {
                    Text("block.add.context.group").tag(BlockContext.group)
                    Text("block.add.context.personal").tag(BlockContext.personal)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .disabled(isSaving)

                // Time picker
                DatePicker(
                    String(localized: "block.add.time"),
                    selection: $time,
                    displayedComponents: .hourAndMinute
                )
                .padding(.horizontal, 20)
                .disabled(isSaving)

                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle(String(localized: "block.add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                            .tint(ColorTokens.accent)
                    } else {
                        Button(String(localized: "common.save")) {
                            createBlock()
                        }
                        .fontWeight(.semibold)
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
        .presentationDetents(sizeClass == .regular ? [.medium, .large] : [.medium])
        .presentationDragIndicator(.visible)
    }

    private func createBlock() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        guard let userId = appState.currentUserId else { return }

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
                try? await Task.sleep(for: .milliseconds(300))
                onBlockCreated?(block.id)
            } catch {
                errorMessage = String(localized: "block.add.error")
                isSaving = false
            }
        }
    }

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
