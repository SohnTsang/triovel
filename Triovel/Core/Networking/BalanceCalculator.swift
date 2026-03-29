import Foundation

/// Calculates per-user balances grouped by currency.
/// Derived from bills, bill_shares, and payments.
/// NEVER combines different currencies into one total.
enum BalanceCalculator {

    /// Per-user balance for a single currency.
    struct UserBalance: Identifiable, Sendable {
        let userId: String
        let amount: Int  // positive = owed money, negative = owes money
        var id: String { userId }
    }

    /// A debt from one user to another in a single currency.
    struct Debt: Identifiable, Sendable {
        let fromUserId: String
        let toUserId: String
        let amount: Int
        let currency: String
        var id: String { "\(fromUserId)-\(toUserId)-\(currency)" }
    }

    /// Balance summary for a single currency.
    struct CurrencyBalance: Identifiable, Sendable {
        let currency: String
        let userBalances: [UserBalance]
        let debts: [Debt]
        var id: String { currency }
    }

    /// Calculate balances grouped by currency.
    /// Returns one CurrencyBalance per currency used in the trip.
    static func calculate(
        bills: [Bill],
        shares: [BillShare],
        payments: [Payment]
    ) -> [CurrencyBalance] {
        // Group bills by currency
        let billsByCurrency = Dictionary(grouping: bills, by: \.currency)
        let paymentsByCurrency = Dictionary(grouping: payments, by: \.currency)

        // All currencies used
        let allCurrencies = Set(billsByCurrency.keys).union(paymentsByCurrency.keys)

        return allCurrencies.sorted().map { currency in
            let currencyBills = billsByCurrency[currency] ?? []
            let currencyPayments = paymentsByCurrency[currency] ?? []

            // Build balance map: userId → net amount
            // Positive = others owe you, Negative = you owe others
            var balances: [String: Int] = [:]

            // Process bills: payer paid, members owe their share
            for bill in currencyBills {
                // Payer gets credit for the full amount
                balances[bill.payerId, default: 0] += bill.amount

                // Each member's share is debited
                let billShares = shares.filter { $0.billId == bill.id }
                for share in billShares {
                    balances[share.userId, default: 0] -= share.shareAmount
                }
            }

            // Process payments: payer paid receiver
            for payment in currencyPayments {
                balances[payment.payerId, default: 0] += payment.amount
                balances[payment.receiverId, default: 0] -= payment.amount
            }

            let userBalances = balances.map { UserBalance(userId: $0.key, amount: $0.value) }
                .sorted { abs($0.amount) > abs($1.amount) }

            // Calculate simplified debts (who owes whom)
            let debts = simplifyDebts(balances: balances, currency: currency)

            return CurrencyBalance(
                currency: currency,
                userBalances: userBalances,
                debts: debts
            )
        }
    }

    /// Simplify debts: people who owe money pay people who are owed.
    private static func simplifyDebts(balances: [String: Int], currency: String) -> [Debt] {
        var debtors: [(String, Int)] = []  // (userId, amount they owe)
        var creditors: [(String, Int)] = [] // (userId, amount they're owed)

        for (userId, balance) in balances {
            if balance < 0 {
                debtors.append((userId, -balance))
            } else if balance > 0 {
                creditors.append((userId, balance))
            }
        }

        // Sort for deterministic output
        debtors.sort { $0.1 > $1.1 }
        creditors.sort { $0.1 > $1.1 }

        var debts: [Debt] = []
        var di = 0, ci = 0

        while di < debtors.count && ci < creditors.count {
            let amount = min(debtors[di].1, creditors[ci].1)
            if amount > 0 {
                debts.append(Debt(
                    fromUserId: debtors[di].0,
                    toUserId: creditors[ci].0,
                    amount: amount,
                    currency: currency
                ))
            }
            debtors[di].1 -= amount
            creditors[ci].1 -= amount
            if debtors[di].1 == 0 { di += 1 }
            if creditors[ci].1 == 0 { ci += 1 }
        }

        return debts
    }
}

// MARK: - Currency Formatting

extension Int {
    /// Format amount (smallest unit) with currency symbol.
    /// e.g. 12000 JPY → "¥12,000", 1500 USD → "$15.00"
    func formattedCurrency(_ currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode

        // JPY, KRW, VND etc. have no decimal places
        let noDecimalCurrencies: Set<String> = ["JPY", "KRW", "VND", "IDR", "CLP"]
        if noDecimalCurrencies.contains(currencyCode.uppercased()) {
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: self)) ?? "\(currencyCode) \(self)"
        } else {
            // Convert from smallest unit (cents) to major unit
            let decimal = Double(self) / 100.0
            return formatter.string(from: NSNumber(value: decimal)) ?? "\(currencyCode) \(decimal)"
        }
    }
}
