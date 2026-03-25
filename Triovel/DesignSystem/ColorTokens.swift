import SwiftUI

/// Semantic color tokens for the Triovel design system.
/// Uses system colors for automatic light/dark mode support.
/// Brand identity: warm, trustworthy, effortless, tactile, human, unhurried.
enum ColorTokens {
    // MARK: - Brand Colors

    /// Warm teal — primary brand color, set via AccentColor in Assets.xcassets
    static let accent = Color.accentColor

    /// Warm coral — secondary accent for interactive elements, FABs, CTAs
    static let secondaryAccent = Color(red: 0.87, green: 0.45, blue: 0.38)

    /// Warm coral for dark mode (slightly brighter for contrast)
    static let secondaryAccentDark = Color(red: 0.92, green: 0.52, blue: 0.45)

    // MARK: - Backgrounds

    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)

    // MARK: - Text

    static let label = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let tertiaryLabel = Color(.tertiaryLabel)

    // MARK: - Surfaces

    static let separator = Color(.separator)

    /// Card background — slightly elevated feel
    static let cardBackground = Color(.secondarySystemBackground)

    /// Card shadow per visual-design.md: opacity 0.06, radius 8, y 2
    static let cardShadow = Color.black.opacity(0.06)

    // MARK: - Context Colors (Personal blocks)

    static let personalTint = Color(red: 0.87, green: 0.45, blue: 0.38)
    static let personalBackground = Color(red: 0.87, green: 0.45, blue: 0.38).opacity(0.06)
    static let personalBorder = Color(red: 0.87, green: 0.45, blue: 0.38).opacity(0.2)

    // MARK: - State Colors

    static let syncingTint = Color.blue.opacity(0.6)
    static let failedTint = Color.red.opacity(0.7)
    static let pendingTint = Color.yellow.opacity(0.6)

    // MARK: - Avatar Colors

    /// Generate a consistent color from a user ID for avatar backgrounds.
    static func avatarColor(for userId: String) -> Color {
        let colors: [Color] = [
            Color(red: 0.290, green: 0.565, blue: 0.565), // teal
            Color(red: 0.87, green: 0.45, blue: 0.38),    // coral
            Color(red: 0.55, green: 0.47, blue: 0.67),    // muted purple
            Color(red: 0.40, green: 0.60, blue: 0.45),    // sage green
            Color(red: 0.72, green: 0.52, blue: 0.38),    // warm brown
            Color(red: 0.45, green: 0.55, blue: 0.72),    // steel blue
        ]
        let hash = userId.utf8.reduce(0) { $0 &+ Int($1) }
        return colors[abs(hash) % colors.count]
    }
}
