import SwiftUI

/// Typography presets matching visual-design.md hierarchy.
/// Screen titles: .title2 bold — one per screen
/// Section headers: .headline — groups content
/// Card titles: .body bold or .callout bold
/// Body text: .body
/// Metadata: .caption or .footnote in secondary color
enum TypographyTokens {
    // Screen title — one per screen, establishes context
    static let screenTitle = Font.title2.weight(.bold)

    // Section header — groups content, not shouty
    static let sectionHeader = Font.headline

    // Card title — readable at a glance
    static let cardTitle = Font.body.weight(.bold)

    // Callout title — slightly larger card title variant
    static let calloutTitle = Font.callout.weight(.bold)

    // Body text — comfortable reading size
    static let body = Font.body

    // Subheadline — secondary body text
    static let subheadline = Font.subheadline

    // Caption — metadata, dates, timestamps
    static let caption = Font.caption

    // Caption medium — slightly emphasized metadata
    static let captionMedium = Font.caption.weight(.medium)

    // Footnote — smallest metadata
    static let footnote = Font.footnote

    // App name on auth screen — only place .largeTitle is used
    static let appTitle = Font.title.weight(.bold)
}
