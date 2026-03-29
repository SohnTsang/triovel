import SwiftUI

/// Sheet for editing trip settings. Only trip owner can access.
/// Pre-filled with current values. Same layout as TripSetupView.
struct EditTripView: View {
    let trip: Trip
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var displayTimezone: String
    @State private var baseCurrency: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    private let tripRepository = TripRepository()

    init(trip: Trip, onSaved: @escaping () -> Void) {
        self.trip = trip
        self.onSaved = onSaved
        _title = State(initialValue: trip.title)
        _startDate = State(initialValue: trip.startDate)
        _endDate = State(initialValue: trip.endDate)
        _displayTimezone = State(initialValue: trip.displayTimezone)
        _baseCurrency = State(initialValue: trip.baseCurrency)
    }

    private var hasChanges: Bool {
        title.trimmingCharacters(in: .whitespaces) != trip.title
        || !Calendar.current.isDate(startDate, inSameDayAs: trip.startDate)
        || !Calendar.current.isDate(endDate, inSameDayAs: trip.endDate)
        || displayTimezone != trip.displayTimezone
        || baseCurrency != trip.baseCurrency
    }

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

                Section {
                    Picker(String(localized: "trip.edit.currency"), selection: $baseCurrency) {
                        ForEach(commonCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "trip.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(String(localized: "common.save")) { saveTrip() }
                            .disabled(
                                title.trimmingCharacters(in: .whitespaces).isEmpty || !hasChanges
                            )
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onChange(of: startDate) { _, newStart in
                if endDate < newStart {
                    endDate = Calendar.current.date(byAdding: .day, value: 1, to: newStart) ?? newStart
                }
            }
        }
    }

    private func saveTrip() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        Task {
            let start = ContinuousClock.now
            do {
                try await tripRepository.updateTrip(
                    tripId: trip.id,
                    title: trimmed != trip.title ? trimmed : nil,
                    startDate: !Calendar.current.isDate(startDate, inSameDayAs: trip.startDate) ? startDate : nil,
                    endDate: !Calendar.current.isDate(endDate, inSameDayAs: trip.endDate) ? endDate : nil,
                    displayTimezone: displayTimezone != trip.displayTimezone ? displayTimezone : nil,
                    baseCurrency: baseCurrency != trip.baseCurrency ? baseCurrency : nil
                )

                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }

                dismiss()
                onSaved()
            } catch {
                print("[EditTrip] ❌ Save failed: \(error)")
                errorMessage = String(localized: "trip.edit.error")
                isSaving = false
            }
        }
    }

    private let commonCurrencies = [
        "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF",
        "CNY", "HKD", "NZD", "SGD", "KRW", "TWD", "THB",
        "MYR", "PHP", "IDR", "VND", "INR", "BRL", "MXN",
    ]
}
