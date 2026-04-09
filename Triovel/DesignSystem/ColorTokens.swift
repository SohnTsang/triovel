import SwiftUI

/// Semantic color tokens for the design system.
/// Uses system colors for automatic light/dark mode support.
enum ColorTokens {
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)

    static let label = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let tertiaryLabel = Color(.tertiaryLabel)

    static let separator = Color(.separator)

    // Card bubble backgrounds
    static let cardBubbleStart = Color(.systemGray6).opacity(0.5)
    static let cardBubbleEnd = Color(.systemGray6).opacity(0.15)
    static let billBubbleStart = Color.green.opacity(0.06)
    static let billBubbleEnd = Color.green.opacity(0.015)
    static let billBorder = Color.green.opacity(0.35)

    /// Default card bubble gradient (lighter center, tinted edges)
    static var cardBackground: some ShapeStyle {
        RadialGradient(
            colors: [cardBubbleEnd, cardBubbleStart],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )
    }

    /// Bill card bubble gradient (lighter center, tinted edges)
    static var billBackground: some ShapeStyle {
        RadialGradient(
            colors: [billBubbleEnd, billBubbleStart],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )
    }

    // Context colors
    static let personalTint = Color.orange
    static let personalBorder = Color.orange.opacity(0.35)
    static let personalBubbleStart = Color.orange.opacity(0.06)
    static let personalBubbleEnd = Color.orange.opacity(0.015)

    /// Personal card bubble gradient (lighter center, tinted edges)
    static var personalBackground: some ShapeStyle {
        RadialGradient(
            colors: [personalBubbleEnd, personalBubbleStart],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )
    }

    // Settle up / who owes who
    static let settleBubbleStart = Color.orange.opacity(0.06)
    static let settleBubbleEnd = Color.orange.opacity(0.015)
    static let settleBorder = Color.orange.opacity(0.35)

    static var settleBackground: some ShapeStyle {
        RadialGradient(
            colors: [settleBubbleEnd, settleBubbleStart],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )
    }

    // State colors
    static let syncingTint = Color.blue.opacity(0.6)
    static let failedTint = Color.red.opacity(0.7)
    static let pendingTint = Color.yellow.opacity(0.6)
}
