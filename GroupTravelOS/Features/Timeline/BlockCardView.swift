import SwiftUI

struct BlockCardView: View {
    let block: Block
    var creatorName: String?
    var syncState: SyncState = .synced

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Context chip for personal blocks
                if block.context == .personal {
                    ContextChip(
                        context: .personal,
                        userName: creatorName
                    )
                }
                Spacer()
                SyncStateIndicator(state: syncState)
            }

            Text(block.title)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 12) {
                if let location = block.locationText {
                    Label(location, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(block.startAt, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            block.context == .personal
                ? ColorTokens.personalBackground
                : Color(.systemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    block.context == .personal
                        ? ColorTokens.personalBorder
                        : Color(.systemGray5),
                    lineWidth: 1
                )
        )
    }
}
