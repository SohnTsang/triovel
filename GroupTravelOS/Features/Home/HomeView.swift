import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeContentView()
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .tripTimeline(let tripId):
                        TripTimelineView(tripId: tripId)
                    case .blockDetail(let blockId):
                        BlockDetailView(blockId: blockId)
                    case .tripSummary(let tripId):
                        TripSummaryView(tripId: tripId)
                    case .archivedTrips:
                        ArchivedTripsView()
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .environmentObject(router)
    }
}

/// Inner content extracted to stay under 200 lines per file.
private struct HomeContentView: View {
    @EnvironmentObject private var router: Router

    // Placeholder — will be replaced by ViewModel in next task
    @State private var activeTrips: [Trip] = []
    @State private var showingNewTrip = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if activeTrips.isEmpty {
                HomeEmptyStateView(showingNewTrip: $showingNewTrip)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(activeTrips) { trip in
                            TripCardView(trip: trip)
                                .onTapGesture {
                                    router.push(.tripTimeline(tripId: trip.id))
                                }
                        }
                    }
                    .padding()
                }
            }

            // Floating + New Trip button
            Button {
                showingNewTrip = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor, in: Circle())
                    .shadow(radius: 4, y: 2)
            }
            .padding(24)
        }
        .navigationTitle("Triovel")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.push(.settings)
                } label: {
                    Image(systemName: "person.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.archivedTrips)
                } label: {
                    Image(systemName: "archivebox")
                }
            }
        }
        .sheet(isPresented: $showingNewTrip) {
            TripSetupView()
        }
    }
}
