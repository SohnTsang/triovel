import SwiftUI
import Observation

/// Trip Summary — money/admin dashboard.
/// Balances grouped by currency. NEVER combine mixed currencies.
struct TripSummaryView: View {
    let tripId: String
    @Environment(AppState.self) private var appState
    @State private var viewModel = TripSummaryViewModel()
    @State private var showingPaymentSheet = false
    @State private var selectedBill: Bill?
    @State private var showingArchiveConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var isArchiving = false
    @State private var isDeletingTrip = false
    @State private var isDeletingPayment = false
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
                VStack(spacing: 0) {
                    tripHeader
                    sheetDivider

                    // Your balance
                    sectionLabel("summary.section.my.balance")
                    yourStatusCard
                    sheetDivider.padding(.top, 6)

                    // Who owes who
                    if viewModel.currencyBalances.contains(where: { !$0.debts.isEmpty }) {
                        sectionLabel("summary.section.who.owes")
                        settleUpCard
                        sheetDivider.padding(.top, 6)
                    }

                    // Payments + record payback
                    sectionLabel("summary.payment.history")
                    if !viewModel.payments.isEmpty {
                        paymentHistoryCard
                    }
                    Button {
                        showingPaymentSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("summary.record.payback")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    sheetDivider.padding(.top, 16)

                    // All bills
                    if !viewModel.billsWithActivity.isEmpty {
                        sectionLabel("summary.section.bills")
                        allBillsCard
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
        .navigationTitle(String(localized: "summary.title"))
        .plainBackButton()
        /* Archive alert — commented out for now
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
        */
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
            if isDeletingTrip || isDeletingPayment {
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
                onPaymentCreated: {
                    if let userId = appState.currentUserId {
                        await viewModel.reload(tripId: tripId, userId: userId)
                    }
                }
            )
        }
        .sheet(item: $selectedBill) { bill in
            let activity = viewModel.billsWithActivity.first(where: { $0.bill.id == bill.id })
            BillDetailView(
                bill: bill,
                payerName: viewModel.memberName(for: bill.payerId),
                shares: viewModel.billShareDisplays(for: bill.id),
                currentUserId: appState.currentUserId ?? "",
                blockTitle: activity?.activityName
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

    // MARK: - Cashflow Style Components

    /// Section label — small caps, left aligned
    private func sectionLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 2)
    }

    /// Thin divider line across full width
    private var sheetDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
            .padding(.horizontal, 20)
    }

    /// A row: label on left, amount on right
    private func ledgerRow(_ label: String, amount: String, color: Color = .primary, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.weight(.semibold) : .subheadline)
            Spacer()
            Text(amount)
                .font(bold ? .subheadline.weight(.bold) : .subheadline.weight(.medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    /// A row with subtitle
    private func ledgerRowWithDetail(_ label: String, detail: String, amount: String, color: Color = .primary) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.subheadline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(amount)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Trip Header

    private var tripHeader: some View {
        VStack(spacing: 4) {
            if let trip = viewModel.trip {
                Text(trip.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text("\(trip.startDate, format: .dateTime.month(.abbreviated).day()) – \(trip.endDate, format: .dateTime.month(.abbreviated).day().year())")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(viewModel.totalExpensesByCurrency, id: \.currency) { item in
                        Text(item.total.formattedCurrency(item.currency))
                            .font(.title2.weight(.bold))
                    }
                }
                .padding(.top, 4)

                Text("summary.bill.count \(viewModel.totalBillCount)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Your Balance

    private var yourStatusCard: some View {
        let debts = viewModel.myDebts(userId: appState.currentUserId ?? "")

        return VStack(spacing: 0) {
            if debts.isEmpty {
                ledgerRow(String(localized: "summary.all.settled"), amount: "✓", color: .green, bold: true)
            } else {
                ForEach(Array(debts.enumerated()), id: \.offset) { index, debt in
                    if debt.youOwe {
                        ledgerRow(
                            "You owe \(debt.name)",
                            amount: debt.amount.formattedCurrency(debt.currency),
                            color: .red,
                            bold: true
                        )
                    } else {
                        ledgerRow(
                            "\(debt.name) owes you",
                            amount: debt.amount.formattedCurrency(debt.currency),
                            color: .green,
                            bold: true
                        )
                    }
                }
            }
        }
    }

    // MARK: - Who Owes Who

    private var settleUpCard: some View {
        let allDebts = viewModel.currencyBalances.flatMap(\.debts)

        return VStack(spacing: 0) {
            ForEach(allDebts) { debt in
                ledgerRow(
                    "\(viewModel.memberName(for: debt.fromUserId)) owes \(viewModel.memberName(for: debt.toUserId))",
                    amount: debt.amount.formattedCurrency(debt.currency),
                    color: .orange
                )
            }
        }
    }

    // MARK: - Payment History

    private var paymentHistoryCard: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.payments) { payment in
                SwipeToDeleteRow {
                    ledgerRowWithDetail(
                        "\(viewModel.memberName(for: payment.payerId)) paid \(viewModel.memberName(for: payment.receiverId))",
                        detail: payment.createdAt.formatted(.dateTime.month(.abbreviated).day()),
                        amount: payment.amount.formattedCurrency(payment.currency),
                        color: .blue
                    )
                } onDelete: {
                    deletePayment(payment)
                }
            }
        }
    }

    private func deletePayment(_ payment: Payment) {
        isDeletingPayment = true
        Task {
            let start = ContinuousClock.now
            do {
                try await PaymentRepository().deletePayment(paymentId: payment.id)
            } catch {
                print("[Summary] ❌ Delete payment failed: \(error)")
            }
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }
            // Reload data BEFORE removing overlay so the UI updates behind it
            if let userId = appState.currentUserId {
                await viewModel.reload(tripId: tripId, userId: userId)
            }
            isDeletingPayment = false
        }
    }

    // MARK: - All Bills

    private var allBillsCard: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.billsWithActivity) { item in
                Button {
                    selectedBill = item.bill
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.activityName)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text("\(viewModel.memberName(for: item.bill.payerId)) paid · \(item.shareCount) people")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.bill.amount.formattedCurrency(item.bill.currency))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                sheetDivider
            }

            // Total row
            HStack {
                Text("summary.total.spent")
                    .font(.subheadline.weight(.bold))
                Spacer()
                HStack(spacing: 8) {
                    ForEach(viewModel.totalExpensesByCurrency, id: \.currency) { item in
                        Text(item.total.formattedCurrency(item.currency))
                            .font(.subheadline.weight(.bold))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
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
            let start = ContinuousClock.now
            do {
                try await TripRepository().archiveTrip(tripId: tripId)
                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
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
            let start = ContinuousClock.now
            do {
                try await TripRepository().unarchiveTrip(tripId: tripId)
                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
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

// MARK: - Models

/// Bill with its activity (block) name for display.
struct BillWithActivity: Identifiable, Sendable {
    let bill: Bill
    let activityName: String
    let shareCount: Int
    var id: String { bill.id }
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
    private(set) var billsWithActivity: [BillWithActivity] = []
    private(set) var billSharesMap: [String: [BillShare]] = [:]
    private(set) var payments: [Payment] = []
    private(set) var isLoading = false

    private let blockRepository = BlockRepository()
    private let tripRepository = TripRepository()
    private let billRepository = BillRepository()
    private let paymentRepository = PaymentRepository()
    private var memberNames: [String: String] = [:]
    private var blockNames: [String: String] = [:]
    @ObservationIgnored private var watchTask: Task<Void, Never>?

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

                // Fetch block names for bill → activity mapping
                let blocks = try await self.blockRepository.fetchBlocks(tripId: tripId)
                for block in blocks { self.blockNames[block.id] = block.title }

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
                    self.billSharesMap = Dictionary(grouping: shares, by: \.billId)

                    // Bills with activity names + share count
                    self.billsWithActivity = bills.map { bill in
                        let count = shares.filter { $0.billId == bill.id }.count
                        return BillWithActivity(
                            bill: bill,
                            activityName: self.blockNames[bill.blockId] ?? String(localized: "post.author.unknown"),
                            shareCount: count
                        )
                    }.sorted { $0.bill.createdAt > $1.bill.createdAt }

                    let payments = try await self.paymentRepository.fetchPaymentsForTrip(tripId: tripId)
                    self.payments = payments

                    self.currencyBalances = BalanceCalculator.calculate(
                        bills: bills,
                        shares: shares,
                        payments: payments
                    )

                    print("[Summary] Bills: \(bills.count), Shares: \(shares.count), Payments: \(payments.count)")
                }
            } catch {
                if !(error is CancellationError) {
                    print("[Summary] ❌ Load error: \(error)")
                }
            }
            if self.isLoading { self.isLoading = false }
        }
    }

    /// One-shot async reload — returns after data is refreshed.
    /// Used by delete/add payment to update UI behind the overlay before dismissing it.
    func reload(tripId: String, userId: String) async {
        do {
            let bills = try await billRepository.fetchGroupBillsForTrip(tripId: tripId)
            self.totalBillCount = bills.count

            var totals: [String: Int] = [:]
            for bill in bills { totals[bill.currency, default: 0] += bill.amount }
            self.totalExpensesByCurrency = totals.map { (currency: $0.key, total: $0.value) }
                .sorted { $0.currency < $1.currency }

            let shares = try await billRepository.fetchAllSharesForTrip(tripId: tripId)
            self.billSharesMap = Dictionary(grouping: shares, by: \.billId)

            self.billsWithActivity = bills.map { bill in
                let count = shares.filter { $0.billId == bill.id }.count
                return BillWithActivity(
                    bill: bill,
                    activityName: blockNames[bill.blockId] ?? String(localized: "post.author.unknown"),
                    shareCount: count
                )
            }.sorted { $0.bill.createdAt > $1.bill.createdAt }

            let payments = try await paymentRepository.fetchPaymentsForTrip(tripId: tripId)
            self.payments = payments

            self.currencyBalances = BalanceCalculator.calculate(
                bills: bills, shares: shares, payments: payments
            )
        } catch {
            print("[Summary] ❌ Reload error: \(error)")
        }
    }

    func memberName(for userId: String) -> String {
        memberNames[userId] ?? String(localized: "post.author.unknown")
    }

    func billShareDisplays(for billId: String) -> [BillShareDisplay] {
        guard let shares = billSharesMap[billId] else { return [] }
        return shares.map { share in
            BillShareDisplay(
                id: share.id,
                userId: share.userId,
                displayName: memberNames[share.userId] ?? String(localized: "post.author.unknown"),
                shareAmount: share.shareAmount
            )
        }
    }

    /// Get debts involving the current user as human-readable lines.
    func myDebts(userId: String) -> [(name: String, amount: Int, currency: String, youOwe: Bool)] {
        var results: [(name: String, amount: Int, currency: String, youOwe: Bool)] = []
        for balance in currencyBalances {
            for debt in balance.debts {
                if debt.fromUserId == userId {
                    results.append((memberName(for: debt.toUserId), debt.amount, debt.currency, true))
                } else if debt.toUserId == userId {
                    results.append((memberName(for: debt.fromUserId), debt.amount, debt.currency, false))
                }
            }
        }
        return results
    }
}
