import SwiftUI

struct TripSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

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
                    TextField(String(localized: "trip.setup.name.placeholder"), text: $title)
                        .font(.title3)
                        .focused($titleFocused)
                        .onChange(of: title) { _, newValue in
                            if newValue.count > 100 { title = String(newValue.prefix(100)) }
                        }
                }

                Section {
                    DatePicker(
                        String(localized: "trip.setup.start.date"),
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        String(localized: "trip.setup.end.date"),
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
            .navigationTitle(String(localized: "trip.setup.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel")) { dismiss() }
                            .disabled(isCreating)
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .confirmationAction) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Button(String(localized: "common.create")) { createTrip() }
                                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel")) { dismiss() }
                            .disabled(isCreating)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isCreating {
                            ProgressView()
                        } else {
                            Button(String(localized: "common.create")) { createTrip() }
                                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
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
                print("[TripSetup] Creating trip: \(trimmedTitle), userId=\(userId)")
                let tripId = try await tripRepository.createTrip(
                    title: trimmedTitle,
                    startDate: startDate,
                    endDate: endDate,
                    displayTimezone: TimeZone.current.identifier,
                    baseCurrency: Locale.current.currency?.identifier ?? "USD",
                    createdBy: userId
                )
                print("[TripSetup] Trip created: \(tripId)")

                dismiss()
                // Small delay to let sheet dismiss animate before navigation
                try? await Task.sleep(for: .milliseconds(300))
                onTripCreated?(tripId)
            } catch {
                print("[TripSetup] ❌ Create trip failed: \(error)")
                errorMessage = String(localized: "trip.setup.error")
                isCreating = false
            }
        }
    }
}
