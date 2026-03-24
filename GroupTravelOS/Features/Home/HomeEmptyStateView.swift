import SwiftUI

/// Empty state shown when user has no active trips.
/// Friendly, not pushy — per design-system.md.
struct HomeEmptyStateView: View {
    let onCreateTrip: () -> Void
    let onJoinTrip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No trips yet")
                .font(.title2.weight(.medium))

            Text("Create your first trip or join one from a friend.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Button(action: onCreateTrip) {
                    Text("Create Trip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: onJoinTrip) {
                    Text("Join a Trip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}
