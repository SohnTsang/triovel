import SwiftUI

/// Inner content for the Home screen, extracted from HomeView to stay under 200 lines.
struct HomeContentView: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(Router.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showingNewTrip = false
    @State private var showingJoinTrip = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if viewModel.activeTrips.isEmpty {
                HomeEmptyStateView(
                    onCreateTrip: { attemptCreateTrip() },
                    onJoinTrip: { showingJoinTrip = true }
                )
            } else {
                ScrollView {
                    TripGridByYear(
                        trips: viewModel.activeTrips,
                        membersByTrip: viewModel.membersByTrip
                    ) { tripId in
                        router.push(.tripTimeline(tripId: tripId))
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                    .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
                    .frame(maxWidth: .infinity)
                }
            }

            // Floating + New Trip button
            Button {
                attemptCreateTrip()
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Triovel")
                    .font(.custom("Pacifico-Regular", size: 22))
                    .foregroundStyle(Color.accentColor)
            }
            if #available(iOS 26, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.push(.settings) } label: {
                        Image(systemName: "person.circle").font(.body.weight(.semibold)).foregroundStyle(Color(.label))
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.push(.settings) } label: {
                        Image(systemName: "person.circle").font(.body.weight(.semibold)).foregroundStyle(Color(.label))
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewTrip) {
            TripSetupView { tripId in
                Task { await viewModel.refresh() }
                router.push(.tripTimeline(tripId: tripId))
            }
        }
        .sheet(isPresented: $showingJoinTrip) {
            JoinTripView { tripId in
                Task { await viewModel.refresh() }
                router.push(.tripTimeline(tripId: tripId))
            }
        }
        .alert(
            String(localized: "home.trip.limit.title"),
            isPresented: $viewModel.showingTripLimitAlert
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text("home.trip.limit.message \(HomeViewModel.activeOwnedTripLimit)")
        }
    }

    private func attemptCreateTrip() {
        if viewModel.requestCreateTrip() {
            showingNewTrip = true
        }
    }
}
