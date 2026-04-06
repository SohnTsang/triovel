import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var router = Router()
    @State private var viewModel = HomeViewModel()

    var body: some View {
        @Bindable var routerBindable = router
        NavigationStack(path: $routerBindable.path) {
            HomeContentView(viewModel: viewModel)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .tripTimeline(let tripId):
                        TripTimelineView(tripId: tripId)
                    case .blockDetail(let blockId):
                        BlockDetailView(blockId: blockId)
                    case .tripSummary(let tripId):
                        TripSummaryView(tripId: tripId)
                    case .tripMembers(let tripId, let members, let inviteLink):
                        TripMembersView(tripId: tripId, members: members, inviteLink: inviteLink)
                    case .tripMedia(let tripId):
                        TripMediaView(tripId: tripId)
                    case .archivedTrips:
                        ArchivedTripsView(trips: viewModel.archivedTrips)
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .environment(router)
        .task {
            if let userId = appState.currentUserId {
                viewModel.load(userId: userId)
            }
        }
        .onChange(of: appState.pendingNavigateTripId) { _, tripId in
            if let tripId {
                appState.pendingNavigateTripId = nil
                // Small delay to let sync pick up the new trip
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    router.push(.tripTimeline(tripId: tripId))
                }
            }
        }
    }
}
