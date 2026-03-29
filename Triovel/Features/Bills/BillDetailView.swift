import SwiftUI

/// Bill detail sheet — shows full breakdown of who owes what.
struct BillDetailView: View {
    let bill: Bill
    let payerName: String
    let shares: [BillShareDisplay]
    var onDelete: (() -> Void)?
    var canDelete: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Amount hero
                    amountHeader

                    // Payer
                    payerSection

                    // Split breakdown
                    splitSection

                    // Delete (payer only)
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
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("bill.delete.confirm.message")
            }
        }
    }

    // MARK: - Amount Header

    private var amountHeader: some View {
        VStack(spacing: 6) {
            Text(bill.amount.formattedCurrency(bill.currency))
                .font(.largeTitle.weight(.bold))

            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Payer

    private var payerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("bill.detail.paid.by")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(initials(payerName))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                Text(payerName)
                    .font(.body.weight(.medium))

                Spacer()

                Text(bill.amount.formattedCurrency(bill.currency))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.green)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Split Breakdown

    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("bill.detail.split")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Text(initials(share.displayName))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.white)
                            }

                        Text(share.displayName)
                            .font(.subheadline)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(share.shareAmount.formattedCurrency(bill.currency))
                                .font(.subheadline.weight(.medium))

                            // Show status: paid or owes
                            if share.userId == bill.payerId {
                                Text("bill.detail.paid")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            } else {
                                Text("bill.detail.owes")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if index < shares.count - 1 {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Text("bill.delete")
                .font(.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var formattedDate: String {
        bill.createdAt.formatted(.dateTime.year().month(.abbreviated).day().hour().minute())
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
