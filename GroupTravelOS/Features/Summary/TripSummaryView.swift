import SwiftUI

/// Trip Summary — money/admin dashboard. Full implementation in Phase 4.
struct TripSummaryView: View {
    let tripId: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Trip header placeholder
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 120)

                    Text("Trip Title")
                        .font(.title2.weight(.semibold))
                }
                .padding(.horizontal)

                // Empty state for no expenses
                VStack(spacing: 12) {
                    Image(systemName: "banknote")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No shared expenses yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
            }
            .padding(.top)
        }
        .navigationTitle("Summary")
    }
}
