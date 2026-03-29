import SwiftUI

/// Payment Entry Sheet — record a real-world repayment between two people.
/// Tied to trip, not to a specific block.
struct PaymentEntrySheet: View {
    let tripId: String
    let members: [TripMemberDisplay]
    let baseCurrency: String
    let currentUserId: String
    var onPaymentCreated: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var payerId: String
    @State private var receiverId: String
    @State private var amountText = ""
    @State private var currency: String
    @State private var note: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let paymentRepository = PaymentRepository()

    init(tripId: String, members: [TripMemberDisplay], baseCurrency: String, currentUserId: String, onPaymentCreated: (() -> Void)? = nil) {
        self.tripId = tripId
        self.members = members
        self.baseCurrency = baseCurrency
        self.currentUserId = currentUserId
        self.onPaymentCreated = onPaymentCreated
        self._payerId = State(initialValue: currentUserId)
        self._receiverId = State(initialValue: members.first(where: { $0.userId != currentUserId })?.userId ?? "")
        self._currency = State(initialValue: baseCurrency)
    }

    private var amountInSmallestUnit: Int? {
        guard let value = Double(amountText.replacingOccurrences(of: ",", with: "")) else { return nil }
        let noDecimal: Set<String> = ["JPY", "KRW", "VND", "IDR", "CLP"]
        if noDecimal.contains(currency.uppercased()) {
            return Int(value)
        }
        return Int(value * 100)
    }

    private var canSave: Bool {
        let amount = amountInSmallestUnit ?? 0
        return amount > 0 && payerId != receiverId && !payerId.isEmpty && !receiverId.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Amount
                Section {
                    HStack {
                        Text(currencySymbol)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField("0", text: $amountText)
                            .font(.title2.weight(.semibold))
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("payment.amount")
                }

                // Currency
                Section {
                    Picker(String(localized: "bill.currency"), selection: $currency) {
                        ForEach(commonCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                // Payer → Receiver
                Section {
                    Picker(String(localized: "payment.from"), selection: $payerId) {
                        ForEach(members) { member in
                            Text(member.displayName).tag(member.userId)
                        }
                    }
                    Picker(String(localized: "payment.to"), selection: $receiverId) {
                        ForEach(members) { member in
                            Text(member.displayName).tag(member.userId)
                        }
                    }
                }

                // Note (optional)
                Section {
                    TextField(String(localized: "payment.note.placeholder"), text: $note)
                } header: {
                    Text("payment.note")
                }

                if payerId == receiverId && !payerId.isEmpty {
                    Section {
                        Text("payment.error.self")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "payment.add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel")) { dismiss() }
                            .disabled(isSaving)
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .confirmationAction) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Button(String(localized: "common.save")) { savePayment() }
                                .disabled(!canSave)
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel")) { dismiss() }
                            .disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Button(String(localized: "common.save")) { savePayment() }
                                .disabled(!canSave)
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    // MARK: - Save

    private func savePayment() {
        guard let amount = amountInSmallestUnit, amount > 0 else { return }
        guard payerId != receiverId else { return }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                _ = try await paymentRepository.createPayment(
                    tripId: tripId,
                    payerId: payerId,
                    receiverId: receiverId,
                    amount: amount,
                    currency: currency,
                    note: note.isEmpty ? nil : note
                )

                try? await Task.sleep(for: .milliseconds(500))
                dismiss()
                onPaymentCreated?()
            } catch {
                print("[Payment] ❌ Create failed: \(error)")
                errorMessage = String(localized: "payment.error.create")
                isSaving = false
            }
        }
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: 0) ?? currency
        return formatted.replacingOccurrences(of: "0", with: "").trimmingCharacters(in: .whitespaces)
    }

    private let commonCurrencies = [
        "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY",
        "HKD", "KRW", "NZD", "SGD", "TWD", "THB", "MYR", "PHP",
        "IDR", "VND", "INR", "BRL", "MXN", "ZAR"
    ]
}
