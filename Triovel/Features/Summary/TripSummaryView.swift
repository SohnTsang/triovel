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
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .padding(.top, 60)
                } else if viewModel.currencyBalances.isEmpty {
                    emptyState
                } else {
                    balanceSections
                }
            }
            .padding(.top)
            .padding(.bottom, 40)
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
                .font(.title)
                .foregroundStyle(.secondary)
            Text("summary.no.expenses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 60)
    }

    // MARK: - Balance Sections

    private var balanceSections: some View {
        VStack(spacing: 20) {
            ForEach(viewModel.currencyBalances) { balance in
                currencySection(balance)
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
        }
    }

    // MARK: - Currency Section

    private func currencySection(_ balance: BalanceCalculator.CurrencyBalance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Currency header
            Text(balance.currency)
                .font(.headline)
                .padding(.horizontal)

            // My balance
            if let myBalance = balance.userBalances.first(where: { $0.userId == appState.currentUserId }) {
                HStack {
                    Text("summary.my.balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(myBalance.amount.formattedCurrency(balance.currency))
                        .font(.headline)
                        .foregroundStyle(myBalance.amount >= 0 ? .green : .red)
                }
                .padding(.horizontal)
            }

            Divider().padding(.horizontal)

            // Who owes whom
            if balance.debts.isEmpty {
                Text("summary.all.settled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(balance.debts) { debt in
                    HStack {
                        Text(viewModel.memberName(for: debt.fromUserId))
                            .font(.subheadline)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.memberName(for: debt.toUserId))
                            .font(.subheadline)
                        Spacer()
                        Text(debt.amount.formattedCurrency(debt.currency))
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class TripSummaryViewModel {
    private(set) var trip: Trip?
    private(set) var members: [TripMemberDisplay] = []
    private(set) var currencyBalances: [BalanceCalculator.CurrencyBalance] = []
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
                // Fetch trip + members
                let trip = try await self.blockRepository.fetchTrip(tripId: tripId)
                self.trip = trip

                let memberMap = try await self.tripRepository.fetchMembers(tripIds: [tripId])
                self.members = memberMap[tripId] ?? []
                for m in self.members { self.memberNames[m.userId] = m.displayName }

                // Watch bills for reactive updates
                let billStream = try self.billRepository.watchBillsForTrip(tripId: tripId)

                // Ensure 500ms loading
                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
                self.isLoading = false

                for try await bills in billStream {
                    guard !Task.isCancelled else { break }
                    let shares = try await self.billRepository.fetchAllSharesForTrip(tripId: tripId)
                    let payments = try await self.paymentRepository.fetchPaymentsForTrip(tripId: tripId)
                    self.currencyBalances = BalanceCalculator.calculate(
                        bills: bills,
                        shares: shares,
                        payments: payments
                    )
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
