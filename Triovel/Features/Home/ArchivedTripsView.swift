import SwiftUI

struct ArchivedTripsView: View {
    let trips: [Trip]
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if trips.isEmpty {
                ContentUnavailableView(
                    String(localized: "home.archived.empty"),
                    systemImage: "archivebox",
                    description: Text("home.archived.empty.description")
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
        .navigationTitle(String(localized: "home.archived.title"))
    }
}
