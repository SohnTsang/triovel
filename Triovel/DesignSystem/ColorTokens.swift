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

    // Context colors
    static let personalTint = Color.orange
    static let personalBackground = Color.orange.opacity(0.04)
    static let personalBorder = Color.orange.opacity(0.2)

    // State colors
    static let syncingTint = Color.blue.opacity(0.6)
    static let failedTint = Color.red.opacity(0.7)
    static let pendingTint = Color.yellow.opacity(0.6)
}
