import SwiftUI

struct BlockCardView: View {
    let block: Block
    var creatorName: String?
    var syncState: SyncState = .synced

    var body: some View {
        TriovelCard(background: cardBackground) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
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
                    .font(TypographyTokens.cardTitle)
                    .foregroundStyle(ColorTokens.label)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label {
                        Text(block.startAt, style: .time)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.secondaryLabel)

                    if let location = block.locationText {
                        Label(location, systemImage: "mappin")
                            .font(TypographyTokens.caption)
                            .foregroundStyle(ColorTokens.secondaryLabel)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    private var cardBackground: Color {
        block.context == .personal
            ? ColorTokens.personalBackground
            : ColorTokens.cardBackground
    }
}
