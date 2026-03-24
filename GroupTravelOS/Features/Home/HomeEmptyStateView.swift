import SwiftUI

struct HomeEmptyStateView: View {
    @Binding var showingNewTrip: Bool

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
                Button {
                    showingNewTrip = true
                } label: {
                    Text("Create Trip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    // Join trip flow — Phase 1 follow-up
                } label: {
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
