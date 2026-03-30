import SwiftUI

struct ArchivedTripsView: View {
    let trips: [Trip]
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(Router.self) private var router

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
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12),
                        ],
                        spacing: 12
                    ) {
                        ForEach(trips) { trip in
                            TripCardView(trip: trip, members: [])
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    router.push(.tripTimeline(tripId: trip.id))
                                }
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
        .plainBackButton()
    }
}
