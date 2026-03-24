import SwiftUI

struct TripSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    /// Called with the new trip ID after creation succeeds.
    private let onTripCreated: ((String) -> Void)?

    init(onTripCreated: ((String) -> Void)? = nil) {
        self.onTripCreated = onTripCreated
    }

    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    private let tripRepository = TripRepository()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip title", text: $title)
                        .font(.title3)
                        .focused($titleFocused)
                }

                Section {
                    DatePicker(
                        "Start date",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "End date",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            createTrip()
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(isCreating)
            .onAppear { titleFocused = true }
            .onChange(of: startDate) { _, newStart in
                // Keep end date valid if start moves past it
                if endDate < newStart {
                    endDate = Calendar.current.date(byAdding: .day, value: 1, to: newStart) ?? newStart
                }
            }
        }
    }

    private func createTrip() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        guard let userId = appState.currentUserId else { return }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                let tripId = try await tripRepository.createTrip(
                    title: trimmedTitle,
                    startDate: startDate,
                    endDate: endDate,
                    displayTimezone: TimeZone.current.identifier,
                    baseCurrency: Locale.current.currency?.identifier ?? "USD",
                    createdBy: userId
                )

                dismiss()
                // Small delay to let sheet dismiss animate before navigation
                try? await Task.sleep(for: .milliseconds(300))
                onTripCreated?(tripId)
            } catch {
                errorMessage = "Could not create trip. Please try again."
                isCreating = false
            }
        }
    }
}
