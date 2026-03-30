import SwiftUI
import Observation

/// Trip Summary — money/admin dashboard.
/// Balances grouped by currency. NEVER combine mixed currencies.
struct TripSummaryView: View {
    let tripId: String
    @Environment(AppState.self) private var appState
    @State private var viewModel = TripSummaryViewModel()
    @State private var showingPaymentSheet = false
    @State private var showingArchiveConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var isArchiving = false
    @State private var isDeletingTrip = false
    @Environment(Router.self) private var router

    private var isOwner: Bool {
        viewModel.trip?.createdBy == appState.currentUserId
    }

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(.top, 60)
            } else if viewModel.currencyBalances.isEmpty && viewModel.totalBillCount == 0 {
                emptyState
            } else {
                VStack(spacing: 24) {
                    // Trip header
                    tripHeader

                    // My balance overview
                    myBalanceCard

                    // Who owes who — single title, all currencies below
                    if !viewModel.currencyBalances.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("summary.section.balances")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            ForEach(viewModel.currencyBalances) { balance in
                                currencySection(balance)
                            }
                        }
                    }

                    // Payment history — single title, all payments below
                    if !viewModel.payments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("summary.payment.history")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            paymentHistoryCard
                        }
                    }

                    // Record Payment button
                    Button {
                        showingPaymentSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("summary.record.payment")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

                    // Archive section
                    archiveSection
                        .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle(String(localized: "summary.title"))
        .plainBackButton()
        .alert(
            String(localized: "trip.archive.title"),
            isPresented: $showingArchiveConfirmation
        ) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "trip.archive.button"), role: .destructive) {
                archiveTrip()
            }
        } message: {
            Text("trip.archive.description")
        }
        .alert(
            String(localized: "trip.delete.title"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) {
                deleteTripPermanently()
            }
        } message: {
            Text("trip.delete.description")
        }
        .overlay {
            if isDeletingTrip {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .overlay { ProgressView().controlSize(.large).tint(.white) }
            }
        }
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
        VStack(spacing: 16) {
            Image(systemName: "receipt")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("summary.no.expenses")
                .font(.body)
                .foregroundStyle(.secondary)

            Button {
                showingPaymentSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("summary.record.payment")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.top, 80)
    }

    // MARK: - Trip Header

    private var tripHeader: some View {
        VStack(spacing: 6) {
            if let trip = viewModel.trip {
                Text(trip.title)
                    .font(.title2.weight(.bold))

                Text("\(trip.startDate, format: .dateTime.month(.abbreviated).day()) – \(trip.endDate, format: .dateTime.month(.abbreviated).day().year())")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Total expenses
            HStack(spacing: 16) {
                ForEach(viewModel.totalExpensesByCurrency, id: \.currency) { item in
                    VStack(spacing: 2) {
                        Text(item.total.formattedCurrency(item.currency))
                            .font(.title3.weight(.bold))
                        Text("summary.total.spent")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 8)

            Text("summary.bill.count \(viewModel.totalBillCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.top, 8)
    }

    // MARK: - My Balance Card

    private var myBalanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("summary.my.balance")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            let nonZero = viewModel.currencyBalances.compactMap { balance -> (Int, String)? in
                guard let my = balance.userBalances.first(where: { $0.userId == appState.currentUserId }),
                      my.amount != 0 else { return nil }
                return (my.amount, balance.currency)
            }

            // Card
            VStack(alignment: .leading, spacing: 6) {
                if nonZero.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("summary.all.settled")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                } else {
                    ForEach(nonZero, id: \.1) { amount, currency in
                        HStack(spacing: 6) {
                            if amount > 0 {
                                Text("summary.you.are.owed")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(amount.formattedCurrency(currency))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.green)
                            } else {
                                Text("summary.you.owe")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text((-amount).formattedCurrency(currency))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            .padding(.horizontal)
        }
    }

    // MARK: - Currency Section

    private func currencySection(_ balance: BalanceCalculator.CurrencyBalance) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Currency label
            Text(balance.currency)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                // Member balances
                ForEach(Array(balance.userBalances.enumerated()), id: \.element.id) { index, userBalance in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(userBalance.userId == appState.currentUserId
                                  ? Color.accentColor.opacity(0.15)
                                  : Color(.systemGray5))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text(memberInitials(viewModel.memberName(for: userBalance.userId)))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(userBalance.userId == appState.currentUserId
                                                     ? Color.accentColor : .secondary)
                            }

                        Text(viewModel.memberName(for: userBalance.userId))
                            .font(.subheadline)
                            .lineLimit(1)

                        Spacer()

                        if userBalance.amount > 0 {
                            Text("+\(userBalance.amount.formattedCurrency(balance.currency))")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.green)
                        } else if userBalance.amount < 0 {
                            Text(userBalance.amount.formattedCurrency(balance.currency))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.red)
                        } else {
                            Text("summary.settled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if index < balance.userBalances.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }

                // Settlements
                if !balance.debts.isEmpty {
                    Divider()

                    VStack(spacing: 0) {
                        ForEach(Array(balance.debts.enumerated()), id: \.element.id) { index, debt in
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.body)
                                    .foregroundStyle(.orange)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(viewModel.memberName(for: debt.fromUserId))
                                        .font(.subheadline.weight(.medium))
                                    HStack(spacing: 3) {
                                        Text("summary.pays")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(viewModel.memberName(for: debt.toUserId))
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(debt.amount.formattedCurrency(debt.currency))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)

                            if index < balance.debts.count - 1 {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                    .background(Color.orange.opacity(0.03))
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            .padding(.horizontal)
        }
    }

    // MARK: - Payment History

    private var paymentHistoryCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.payments.enumerated()), id: \.element.id) { index, payment in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(viewModel.memberName(for: payment.payerId))
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
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
                                .foregroundStyle(.secondary)
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
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    // MARK: - Archive

    private var archiveSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

            let isArchived = viewModel.trip?.archived == true

            Button {
                if isArchived {
                    unarchiveTrip()
                } else {
                    showingArchiveConfirmation = true
                }
            } label: {
                if isArchiving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text(isArchived ? "trip.unarchive.button" : "trip.archive.button")
                        .font(.body)
                        .foregroundStyle(isArchived ? Color.accentColor : .red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .disabled(isArchiving)
            .padding(.horizontal)

            if isOwner {
                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Text("trip.delete.button")
                        .font(.body)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .padding(.horizontal)
            }
        }
    }

    private func archiveTrip() {
        isArchiving = true
        Task {
            do {
                try await TripRepository().archiveTrip(tripId: tripId)
                try? await Task.sleep(for: .milliseconds(500))
                router.popToRoot()
            } catch {
                print("[Summary] ❌ Archive failed: \(error)")
            }
            isArchiving = false
        }
    }

    private func deleteTripPermanently() {
        isDeletingTrip = true
        Task {
            let start = ContinuousClock.now
            do {
                try await TripRepository().deleteTrip(tripId: tripId)
                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
                router.popToRoot()
            } catch {
                print("[Summary] ❌ Delete trip failed: \(error)")
                isDeletingTrip = false
            }
        }
    }

    private func unarchiveTrip() {
        isArchiving = true
        Task {
            do {
                try await TripRepository().unarchiveTrip(tripId: tripId)
                try? await Task.sleep(for: .milliseconds(500))
                // Reload to pick up the change
                if let userId = appState.currentUserId {
                    viewModel.load(tripId: tripId, userId: userId)
                }
            } catch {
                print("[Summary] ❌ Unarchive failed: \(error)")
            }
            isArchiving = false
        }
    }

    private func memberInitials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(name.prefix(2)).uppercased()
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

                // Only group block bills — personal block bills excluded from summary
                let billStream = try self.billRepository.watchGroupBillsForTrip(tripId: tripId)

                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
                self.isLoading = false

                for try await bills in billStream {
                    guard !Task.isCancelled else { break }

                    self.totalBillCount = bills.count

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
