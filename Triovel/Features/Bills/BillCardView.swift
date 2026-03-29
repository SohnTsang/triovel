import SwiftUI

/// Bill card in the block detail stream.
/// Visually distinct from posts (receipt icon, tinted background).
struct BillCardView: View {
    let bill: Bill
    let payerName: String
    let shareCount: Int

    var body: some View {
        HStack(spacing: 12) {
            // Receipt icon
            Circle()
                .fill(Color.green.opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "banknote")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.green)
                }

            VStack(alignment: .leading, spacing: 4) {
                // Amount + currency
                Text(bill.amount.formattedCurrency(bill.currency))
                    .font(.headline)

                // Payer + split info
                HStack(spacing: 4) {
                    Text(payerName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text("bill.split.count \(shareCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Time
                Text(bill.createdAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.green.opacity(0.15), lineWidth: 1)
        )
    }
}
