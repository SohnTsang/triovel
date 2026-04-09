import SwiftUI

/// Bill detail sheet — shows full breakdown of who owes what + payment records.
struct BillDetailView: View {
    let bill: Bill
    let payerName: String
    let shares: [BillShareDisplay]
    var payments: [Payment] = []
    var members: [TripMemberDisplay] = []
    var currentUserId: String = ""
    var blockTitle: String? = nil
    var onDelete: (() -> Void)?
    var canDelete: Bool = false
    var onRecordPayment: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    amountHeader
                    payerSection
                    splitSection

                    if canDelete {
                        deleteSection
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .navigationTitle(String(localized: "bill.detail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.done")) { dismiss() }
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.done")) { dismiss() }
                    }
                }
            }
            .alert(
                String(localized: "bill.delete.confirm.title"),
                isPresented: $showingDeleteConfirmation
            ) {
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.delete"), role: .destructive) {
                    isDeleting = true
                    let start = ContinuousClock.now
                    onDelete?()
                    Task {
                        let elapsed = ContinuousClock.now - start
                        if elapsed < .milliseconds(500) {
                            try? await Task.sleep(for: .milliseconds(500) - elapsed)
                        }
                        dismiss()
                    }
                }
            } message: {
                Text("bill.delete.confirm.message")
            }
        }
    }

    /// Payments in the same currency as this bill.
    private var relatedPayments: [Payment] {
        payments.filter { $0.currency == bill.currency }
    }

    // MARK: - Amount Header

    private var amountHeader: some View {
        VStack(spacing: 6) {
            if let title = blockTitle {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(bill.amount.formattedCurrency(bill.currency))
                .font(.largeTitle.weight(.bold))

            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Payer

    private var payerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("bill.detail.paid.by")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            HStack {
                Text(payerName)
                    .font(.subheadline)
                Spacer()
                Text(bill.amount.formattedCurrency(bill.currency))
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Split Breakdown

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("bill.detail.split")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
                .padding(.horizontal, 20)

            ForEach(shares) { share in
                HStack {
                    Text(share.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text(share.shareAmount.formattedCurrency(bill.currency))
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Payment Records

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("summary.payment.history")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(relatedPayments.enumerated()), id: \.element.id) { index, payment in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(memberName(payment.payerId))
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(memberName(payment.receiverId))
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

                    if index < relatedPayments.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background { RoundedRectangle(cornerRadius: 12).fill(ColorTokens.billBackground) }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ColorTokens.billBorder, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 2)
            .padding(.horizontal)
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            if isDeleting {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                Text("bill.delete")
                    .font(.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .disabled(isDeleting)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        bill.createdAt.formatted(.dateTime.year().month(.abbreviated).day().hour().minute())
    }

    private func memberName(_ userId: String) -> String {
        members.first(where: { $0.userId == userId })?.displayName ?? userId.prefix(8).description
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(name.prefix(2)).uppercased()
    }
}

/// Display model for bill share with resolved member name.
struct BillShareDisplay: Identifiable, Sendable {
    let id: String
    let userId: String
    let displayName: String
    let shareAmount: Int
}
