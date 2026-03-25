import SwiftUI

struct GhostBlockView: View {
    let ghost: GhostBlock
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.body)
                    .foregroundStyle(ColorTokens.tertiaryLabel)

                Text(ghost.label.rawValue)
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(ColorTokens.tertiaryLabel)

                Spacer()

                Image(systemName: "plus")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ColorTokens.tertiaryLabel)
            }
            .padding(16)
            .background(Color(.tertiarySystemBackground).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(ColorTokens.separator)
            )
            .opacity(0.6)
        }
    }

    private var iconName: String {
        switch ghost.label {
        case .breakfast: return "cup.and.saucer"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.stars"
        }
    }
}
