import SwiftUI

/// Consistent avatar circle with initials on colored background.
/// Sizes: 24pt (stacked chips), 36pt (inline), 48pt (profile), 64pt (settings).
struct AvatarView: View {
    let initials: String
    let userId: String
    var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(ColorTokens.avatarColor(for: userId))
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(fontSize)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
    }

    private var fontSize: Font {
        switch size {
        case ...28: return .caption2
        case 29...40: return .caption
        case 41...56: return .subheadline
        default: return .title3
        }
    }
}
