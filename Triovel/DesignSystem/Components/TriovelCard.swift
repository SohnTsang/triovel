import SwiftUI

/// Reusable card container matching visual-design.md specs.
/// Corner radius: 16pt, subtle shadow, secondarySystemBackground.
struct TriovelCard<Content: View>: View {
    var background: Color = ColorTokens.cardBackground
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: ColorTokens.cardShadow, radius: 8, x: 0, y: 2)
    }
}
