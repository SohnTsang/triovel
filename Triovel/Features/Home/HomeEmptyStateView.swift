import SwiftUI

/// Empty state shown when user has no active trips.
/// Friendly, not pushy — per design-system.md.
struct HomeEmptyStateView: View {
    let onCreateTrip: () -> Void
    let onJoinTrip: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("home.empty.title")
                .font(.title2.weight(.medium))

            Text("home.empty.subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Button(action: onCreateTrip) {
                    Text("home.create.trip")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))

                Button(action: onJoinTrip) {
                    Text("home.join.trip")
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                }
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
    }
}
