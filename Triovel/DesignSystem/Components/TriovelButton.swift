import SwiftUI

/// Primary button style matching visual-design.md specs.
/// Filled with accent color, 14pt corner radius, min height 50pt, finger-friendly.
struct TriovelPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1.0) : 0.4)
    }
}

/// Secondary button style — plain text in accent color, no border.
struct TriovelSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, minHeight: 50)
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1.0) : 0.4)
    }
}

/// Destructive text button — plain text in red, no border.
struct TriovelDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.red)
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1.0) : 0.4)
    }
}

extension ButtonStyle where Self == TriovelPrimaryButtonStyle {
    static var triovelPrimary: TriovelPrimaryButtonStyle { .init() }
}

extension ButtonStyle where Self == TriovelSecondaryButtonStyle {
    static var triovelSecondary: TriovelSecondaryButtonStyle { .init() }
}

extension ButtonStyle where Self == TriovelDestructiveButtonStyle {
    static var triovelDestructive: TriovelDestructiveButtonStyle { .init() }
}
