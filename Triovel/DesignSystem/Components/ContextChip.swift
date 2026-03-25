import SwiftUI

/// Visual chip showing Group or Personal context on blocks.
struct ContextChip: View {
    let context: BlockContext
    var userName: String?

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
    }

    private var label: String {
        switch context {
        case .group:
            return "Group"
        case .personal:
            if let name = userName {
                return "Personal \u{00B7} \(name)"
            }
            return "Personal"
        }
    }

    private var foregroundColor: Color {
        context == .personal ? ColorTokens.personalTint : ColorTokens.accent
    }

    private var backgroundColor: Color {
        context == .personal
            ? ColorTokens.personalTint.opacity(0.12)
            : ColorTokens.accent.opacity(0.10)
    }
}
