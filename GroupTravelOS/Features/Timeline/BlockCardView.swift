import SwiftUI

struct BlockCardView: View {
    let block: Block

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Context chip for personal blocks
            if block.context == .personal {
                Text("Personal")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }

            Text(block.title)
                .font(.headline)

            if let location = block.locationText {
                Label(location, systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(block.startAt, style: .time)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            block.context == .personal
                ? Color.orange.opacity(0.04)
                : Color(.systemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    block.context == .personal
                        ? Color.orange.opacity(0.2)
                        : Color(.systemGray5),
                    lineWidth: 1
                )
        )
    }
}
