import SwiftUI

struct AddMomentView: View {
    let tripId: String
    let defaultDay: Int
    var dayDate: Date?
    var ghostLabel: GhostBlockLabel?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    @State private var title: String = ""
    @State private var context: BlockContext = .group
    @State private var time = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Title — large auto-focused input
                TextField("What's happening?", text: $title)
                    .font(.title3)
                    .focused($titleFocused)
                    .padding(.horizontal)

                // Context toggle
                Picker("Context", selection: $context) {
                    Text("Group").tag(BlockContext.group)
                    Text("Personal").tag(BlockContext.personal)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Time picker
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Add Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        createBlock()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let label = ghostLabel {
                    title = label.rawValue
                    // Set time to ghost block's default hour
                    if let date = dayDate {
                        let cal = Calendar.current
                        time = cal.date(bySettingHour: label.defaultHour, minute: 0, second: 0, of: date) ?? Date()
                    }
                } else if let date = dayDate {
                    // Default to midday for future days, now for current day
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
        // Phase 1: write block to local DB
        // Then dismiss and push into BlockDetail
        dismiss()
    }
}
