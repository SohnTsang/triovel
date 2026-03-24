import SwiftUI

struct TripSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router

    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip title", text: $title)
                        .font(.title3)
                }

                Section {
                    DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTrip()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func createTrip() {
        // Phase 1: write to local DB and navigate to timeline
        // Auto-filled defaults:
        //   displayTimezone = TimeZone.current.identifier
        //   baseCurrency = Locale.current.currency?.identifier ?? "USD"
        dismiss()
    }
}
