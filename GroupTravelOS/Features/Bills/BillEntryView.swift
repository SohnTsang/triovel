import SwiftUI

/// Bill Entry Sheet — full implementation in Phase 4.
struct BillEntryView: View {
    let blockId: String
    let tripId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("Bill entry — Phase 4")
                .foregroundStyle(.secondary)
                .navigationTitle("Add Bill")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}
