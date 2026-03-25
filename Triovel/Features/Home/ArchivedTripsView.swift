import SwiftUI

struct ArchivedTripsView: View {
    let trips: [Trip]
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if trips.isEmpty {
                ContentUnavailableView(
                    "No archived trips",
                    systemImage: "archivebox",
                    description: Text("Trips you archive will appear here.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(trips) { trip in
                            TripCardView(trip: trip, members: [])
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Archived Trips")
    }
}
