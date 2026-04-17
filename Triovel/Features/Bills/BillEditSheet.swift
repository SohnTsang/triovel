import SwiftUI

/// Edit sheet for an existing bill — amount, currency, note, included members.
/// Payer cannot be changed after creation.
struct BillEditSheet: View {
    let bill: Bill
    let members: [TripMemberDisplay]
    var onSave: ((_ amount: Int, _ currency: String, _ note: String?, _ memberIds: [String]) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String
    @State private var currency: String
    @FocusState private var isAnyFieldFocused: Bool
    @State private var noteText: String
    @State private var includedMemberIds: Set<String>
    @State private var isSaving = false

    init(bill: Bill, members: [TripMemberDisplay], onSave: ((_ amount: Int, _ currency: String, _ note: String?, _ memberIds: [String]) -> Void)? = nil) {
        self.bill = bill
        self.members = members
        self.onSave = onSave

        let noDecimal: Set<String> = ["JPY", "KRW", "VND", "IDR", "CLP"]
        let displayAmount: String
        if noDecimal.contains(bill.currency.uppercased()) {
            displayAmount = "\(bill.amount)"
        } else {
            let whole = bill.amount / 100
            let frac = bill.amount % 100
            displayAmount = frac == 0 ? "\(whole)" : String(format: "%d.%02d", whole, frac)
        }

        self._amountText = State(initialValue: displayAmount)
        self._currency = State(initialValue: bill.currency)
        self._noteText = State(initialValue: bill.note ?? "")
        self._includedMemberIds = State(initialValue: Set(members.map(\.userId)))
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
        amountInSmallestUnit != nil && (amountInSmallestUnit ?? 0) > 0 && !includedMemberIds.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
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

                Section {
                    Picker(String(localized: "bill.currency"), selection: $currency) {
                        ForEach(commonCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                Section {
                    TextField(String(localized: "bill.note.placeholder"), text: $noteText, axis: .vertical)
                        .focused($isAnyFieldFocused)
                        .lineLimit(1...3)
                } header: {
                    Text("bill.note")
                }

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
            }
            .navigationTitle(String(localized: "bill.edit"))
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
                        Button(String(localized: "common.save")) { save() }
                            .disabled(!canSave)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isAnyFieldFocused = false }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() {
        guard let amount = amountInSmallestUnit, amount > 0 else { return }
        isSaving = true
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave?(amount, currency, trimmedNote.isEmpty ? nil : trimmedNote, Array(includedMemberIds))
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
