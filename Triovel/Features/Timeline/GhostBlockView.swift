import SwiftUI

struct GhostBlockView: View {
    let ghost: GhostBlock
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: iconName)
                    .foregroundStyle(.tertiary)
                Text(ghost.label.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .foregroundStyle(Color(.systemGray4))
            )
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
