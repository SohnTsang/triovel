import SwiftUI

/// Bill Entry Sheet — full implementation in Phase 4.
struct BillEntryView: View {
    let blockId: String
    let tripId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Text("bill.placeholder")
                .foregroundStyle(.secondary)
                .navigationTitle(String(localized: "bill.add.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if #available(iOS 26, *) {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "common.cancel")) { dismiss() }
                        }
                        .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "common.cancel")) { dismiss() }
                        }
                    }
                }
        }
    }
}
