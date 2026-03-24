import SwiftUI

struct ArchivedTripsView: View {
    @State private var archivedTrips: [Trip] = []

    var body: some View {
        Group {
            if archivedTrips.isEmpty {
                ContentUnavailableView(
                    "No archived trips",
                    systemImage: "archivebox",
                    description: Text("Trips you archive will appear here.")
                )
            } else {
                List(archivedTrips) { trip in
                    TripCardView(trip: trip)
                }
            }
        }
        .navigationTitle("Archived Trips")
    }
}
