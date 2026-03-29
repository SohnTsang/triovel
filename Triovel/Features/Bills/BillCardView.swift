import SwiftUI

/// Bill card in the block detail stream.
/// Visually distinct from posts — green accent, receipt layout.
struct BillCardView: View {
    let bill: Bill
    let payerName: String
    let shareCount: Int
    var onTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: icon + amount + time
            HStack(alignment: .top) {
                Image(systemName: "receipt")
                    .font(.body)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.amount.formattedCurrency(bill.currency))
                        .font(.title3.weight(.bold))

                    Text(formattedTime)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Per-person share
                if shareCount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text((bill.amount / shareCount).formattedCurrency(bill.currency))
                            .font(.subheadline.weight(.medium))
                        Text("bill.per.person")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Divider()

            // Bottom row: payer + split info
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(localized: "bill.paid.by.name \(payerName)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("bill.split.count \(shareCount)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    private var formattedTime: String {
        let time = bill.createdAt.formatted(.dateTime.hour().minute())
        let date = bill.createdAt.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        return "\(time) · \(date)"
    }
}
