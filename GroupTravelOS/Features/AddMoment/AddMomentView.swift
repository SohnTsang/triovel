import SwiftUI

struct AddMomentView: View {
    let tripId: String
    let defaultDay: Int
    var ghostLabel: GhostBlockLabel?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
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
