import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var router = Router()
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeContentView(viewModel: viewModel)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .tripTimeline(let tripId):
                        TripTimelineView(tripId: tripId)
                    case .blockDetail(let blockId):
                        BlockDetailView(blockId: blockId)
                    case .tripSummary(let tripId):
                        TripSummaryView(tripId: tripId)
                    case .archivedTrips:
                        ArchivedTripsView(trips: viewModel.archivedTrips)
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .environmentObject(router)
        .onAppear {
            if let userId = appState.currentUserId {
                viewModel.load(userId: userId)
            }
        }
    }
}
