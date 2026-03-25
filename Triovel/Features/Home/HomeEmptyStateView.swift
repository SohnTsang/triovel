import SwiftUI

/// Empty state shown when user has no active trips.
/// Centered, calm, two clear CTAs — per visual-design.md.
struct HomeEmptyStateView: View {
    let onCreateTrip: () -> Void
    let onJoinTrip: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.accent.opacity(0.5))

            VStack(spacing: 8) {
                Text("home.empty.title")
                    .font(TypographyTokens.screenTitle)
                    .foregroundStyle(ColorTokens.label)

                Text("home.empty.subtitle")
                    .font(TypographyTokens.body)
                    .foregroundStyle(ColorTokens.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button(action: onCreateTrip) {
                    Text("home.create.trip")
                }
                .buttonStyle(.triovelPrimary)

                Button(action: onJoinTrip) {
                    Text("home.join.trip")
                }
                .buttonStyle(.triovelSecondary)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: sizeClass == .regular ? 440 : .infinity)
        .frame(maxWidth: .infinity)
    }
}
