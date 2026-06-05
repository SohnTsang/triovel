import SwiftUI

/// Bill Entry Sheet — amount, currency, payer, member checklist.
/// Equal split across checked members. Amounts in smallest currency unit.
struct BillEntryView: View {
    let blockId: String
    let tripId: String
    let members: [TripMemberDisplay]
    let baseCurrency: String
    let currentUserId: String
    var onBillCreated: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @FocusState private var isAnyFieldFocused: Bool
    @State private var amountText = ""
    @State private var currency: String
    @State private var payerId: String
    @State private var includedMemberIds: Set<String>
    @State private var noteText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let billRepository = BillRepository()

    init(blockId: String, tripId: String, members: [TripMemberDisplay], baseCurrency: String, currentUserId: String, onBillCreated: (() -> Void)? = nil) {
        self.blockId = blockId
        self.tripId = tripId
        self.members = members
        self.baseCurrency = baseCurrency
        self.currentUserId = currentUserId
        self.onBillCreated = onBillCreated
        self._currency = State(initialValue: baseCurrency)
        self._payerId = State(initialValue: currentUserId)
        self._includedMemberIds = State(initialValue: Set(members.map(\.userId)))
    }

    /// Amount in smallest currency unit (cents or yen etc.)
    private var amountInSmallestUnit: Int? {
        guard let value = Double(amountText.replacingOccurrences(of: ",", with: "")) else { return nil }
        let noDecimal: Set<String> = ["JPY", "KRW", "VND", "IDR", "CLP"]
        if noDecimal.contains(currency.uppercased()) {
            return Int(value)
        }
        return Int(value * 100)
    }

    private var canSave: Bool {
        amountInSmallestUnit != nil && (amountInSmallestUnit ?? 0) > 0 && !includedMemberIds.isEmpty
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
                            .focused($isAnyFieldFocused)
                    }
                } header: {
                    Text("bill.amount")
                }

                // Currency
                Section {
                    Picker(String(localized: "bill.currency"), selection: $currency) {
                        ForEach(commonCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                // Payer
                Section {
                    Picker(String(localized: "bill.payer"), selection: $payerId) {
                        ForEach(members) { member in
                            Text(member.displayName).tag(member.userId)
                        }
                    }
                } header: {
                    Text("bill.paid.by")
                }

                // Included members
                Section {
                    ForEach(members) { member in
                        HStack {
                            Text(member.displayName)
                            Spacer()
                            if includedMemberIds.contains(member.userId) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if includedMemberIds.contains(member.userId) {
                                includedMemberIds.remove(member.userId)
                            } else {
                                includedMemberIds.insert(member.userId)
                            }
                        }
                    }
                } header: {
                    Text("bill.split.between")
                } footer: {
                    if let amount = amountInSmallestUnit, !includedMemberIds.isEmpty {
                        let share = amount / includedMemberIds.count
                        Text("bill.split.each \(share.formattedCurrency(currency))")
                    }
                }

                // Note (optional)
                Section {
                    TextField(String(localized: "bill.note.placeholder"), text: $noteText, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($isAnyFieldFocused)
                } header: {
                    Text("bill.note")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "bill.add.title"))
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
                            Button(String(localized: "common.save")) { saveBill() }
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
                            Button(String(localized: "common.save")) { saveBill() }
                                .disabled(!canSave)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .interactiveDismissDisabled(isSaving)
        }
        .presentationDetents(sizeClass == .regular ? [.large] : [.large])
    }

    // MARK: - Save

    private func saveBill() {
        guard let amount = amountInSmallestUnit, amount > 0 else { return }
        guard !includedMemberIds.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        Task {
            let start = ContinuousClock.now
            do {
                let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                _ = try await billRepository.createBill(
                    blockId: blockId,
                    tripId: tripId,
                    amount: amount,
                    currency: currency,
                    payerId: payerId,
                    memberIds: Array(includedMemberIds),
                    note: trimmedNote.isEmpty ? nil : trimmedNote
                )

                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
                dismiss()
                onBillCreated?()
            } catch {
                print("[BillEntry] ❌ Create failed: \(error)")
                errorMessage = String(localized: "bill.error.create")
                isSaving = false
            }
        }
    }

    // MARK: - Helpers

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        // Extract just the symbol from a formatted "¥0" → "¥"
        let formatted = formatter.string(from: 0) ?? currency
        return formatted.replacingOccurrences(of: "0", with: "").trimmingCharacters(in: .whitespaces)
    }

    private let commonCurrencies = [
        "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY",
        "HKD", "KRW", "NZD", "SGD", "TWD", "THB", "MYR", "PHP",
        "IDR", "VND", "INR", "BRL", "MXN", "ZAR"
    ]
}
