import SwiftUI
import Observation

/// Trip Summary — money/admin dashboard.
/// Balances grouped by currency. NEVER combine mixed currencies.
struct TripSummaryView: View {
    let tripId: String
    @Environment(AppState.self) private var appState
    @State private var viewModel = TripSummaryViewModel()
    @State private var showingPaymentSheet = false

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(.top, 60)
            } else if viewModel.currencyBalances.isEmpty && viewModel.totalBillCount == 0 {
                emptyState
            } else {
                VStack(spacing: 20) {
                    // Total expenses header
                    totalExpensesCard

                    // Per-currency balance sections
                    ForEach(viewModel.currencyBalances) { balance in
                        currencySection(balance)
                    }

                    // Payment history
                    if !viewModel.payments.isEmpty {
                        paymentHistorySection
                    }

                    // Record Payment button
                    Button {
                        showingPaymentSheet = true
                    } label: {
                        Label(String(localized: "summary.record.payment"), systemImage: "plus.circle")
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top, 12)
            }
        }
        .navigationTitle(String(localized: "summary.title"))
        .plainBackButton()
        .sheet(isPresented: $showingPaymentSheet) {
            PaymentEntrySheet(
                tripId: tripId,
                members: viewModel.members,
                baseCurrency: viewModel.trip?.baseCurrency ?? "USD",
                currentUserId: appState.currentUserId ?? "",
                onPaymentCreated: { }
            )
        }
        .task {
            if let userId = appState.currentUserId {
                viewModel.load(tripId: tripId, userId: userId)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "banknote")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("summary.no.expenses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 80)
    }

    // MARK: - Total Expenses Card

    private var totalExpensesCard: some View {
        VStack(spacing: 8) {
            Text("summary.total.expenses")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Show total per currency
            ForEach(viewModel.totalExpensesByCurrency, id: \.currency) { item in
                Text(item.total.formattedCurrency(item.currency))
                    .font(.title.weight(.bold))
            }

            Text("summary.bill.count \(viewModel.totalBillCount)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Currency Section

    private func currencySection(_ balance: BalanceCalculator.CurrencyBalance) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Currency header
            HStack {
                Text(balance.currency)
                    .font(.headline)
                Spacer()
            }

            // My status — clear, human-readable
            if let myBalance = balance.userBalances.first(where: { $0.userId == appState.currentUserId }) {
                myBalanceRow(amount: myBalance.amount, currency: balance.currency)
            }

            Divider()

            // Per-member breakdown
            ForEach(balance.userBalances) { userBalance in
                if userBalance.userId != appState.currentUserId {
                    HStack {
                        Text(viewModel.memberName(for: userBalance.userId))
                            .font(.subheadline)
                        Spacer()
                        Text(balanceDescription(userBalance.amount, currency: balance.currency))
                            .font(.subheadline)
                            .foregroundStyle(userBalance.amount >= 0 ? .green : .red)
                    }
                }
            }

            // Debts: who needs to pay whom
            if !balance.debts.isEmpty {
                Divider()

                Text("summary.settlements")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(balance.debts) { debt in
                    HStack(spacing: 8) {
                        Text(viewModel.memberName(for: debt.fromUserId))
                            .font(.subheadline)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(viewModel.memberName(for: debt.toUserId))
                            .font(.subheadline)
                        Spacer()
                        Text(debt.amount.formattedCurrency(debt.currency))
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - My Balance Row

    private func myBalanceRow(amount: Int, currency: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if amount > 0 {
                    Text("summary.you.are.owed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(amount.formattedCurrency(currency))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.green)
                } else if amount < 0 {
                    Text("summary.you.owe")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text((-amount).formattedCurrency(currency))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.red)
                } else {
                    Text("summary.all.settled")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("summary.no.outstanding")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    // MARK: - Payment History

    private var paymentHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("summary.payment.history")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.payments.enumerated()), id: \.element.id) { index, payment in
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.body)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(viewModel.memberName(for: payment.payerId))
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(viewModel.memberName(for: payment.receiverId))
                                    .font(.subheadline.weight(.medium))
                            }
                            if let note = payment.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(payment.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Text(payment.amount.formattedCurrency(payment.currency))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if index < viewModel.payments.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func balanceDescription(_ amount: Int, currency: String) -> String {
        if amount > 0 {
            return "+\(amount.formattedCurrency(currency))"
        } else if amount < 0 {
            return amount.formattedCurrency(currency)
        }
        return String(localized: "summary.settled")
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class TripSummaryViewModel {
    private(set) var trip: Trip?
    private(set) var members: [TripMemberDisplay] = []
    private(set) var currencyBalances: [BalanceCalculator.CurrencyBalance] = []
    private(set) var totalExpensesByCurrency: [(currency: String, total: Int)] = []
    private(set) var totalBillCount: Int = 0
    private(set) var payments: [Payment] = []
    private(set) var isLoading = false

    private let blockRepository = BlockRepository()
    private let tripRepository = TripRepository()
    private let billRepository = BillRepository()
    private let paymentRepository = PaymentRepository()
    private var memberNames: [String: String] = [:]
    nonisolated(unsafe) private var watchTask: Task<Void, Never>?

    deinit { watchTask?.cancel() }

    func load(tripId: String, userId: String) {
        isLoading = true

        watchTask?.cancel()
        watchTask = Task { [weak self] in
            guard let self else { return }
            let start = ContinuousClock.now

            do {
                let trip = try await self.blockRepository.fetchTrip(tripId: tripId)
                self.trip = trip

                let memberMap = try await self.tripRepository.fetchMembers(tripIds: [tripId])
                self.members = memberMap[tripId] ?? []
                for m in self.members { self.memberNames[m.userId] = m.displayName }

                let billStream = try self.billRepository.watchBillsForTrip(tripId: tripId)

                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
                self.isLoading = false

                for try await bills in billStream {
                    guard !Task.isCancelled else { break }

                    self.totalBillCount = bills.count

                    // Total expenses per currency
                    var totals: [String: Int] = [:]
                    for bill in bills {
                        totals[bill.currency, default: 0] += bill.amount
                    }
                    self.totalExpensesByCurrency = totals.map { (currency: $0.key, total: $0.value) }
                        .sorted { $0.currency < $1.currency }

                    let shares = try await self.billRepository.fetchAllSharesForTrip(tripId: tripId)
                    let payments = try await self.paymentRepository.fetchPaymentsForTrip(tripId: tripId)
                    self.payments = payments

                    self.currencyBalances = BalanceCalculator.calculate(
                        bills: bills,
                        shares: shares,
                        payments: payments
                    )

                    print("[Summary] Bills: \(bills.count), Shares: \(shares.count), Payments: \(payments.count), Currencies: \(self.currencyBalances.count)")
                }
            } catch {
                if !(error is CancellationError) {
                    print("[Summary] ❌ Load error: \(error)")
                }
            }
            if self.isLoading { self.isLoading = false }
        }
    }

    func memberName(for userId: String) -> String {
        memberNames[userId] ?? String(localized: "post.author.unknown")
    }
}
