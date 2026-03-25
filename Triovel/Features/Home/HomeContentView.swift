import SwiftUI

/// Inner content for the Home screen, extracted from HomeView to stay under 200 lines.
struct HomeContentView: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject private var router: Router
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showingNewTrip = false
    @State private var showingJoinTrip = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if viewModel.activeTrips.isEmpty {
                HomeEmptyStateView(
                    onCreateTrip: { attemptCreateTrip() },
                    onJoinTrip: { showingJoinTrip = true }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.activeTrips) { trip in
                            TripCardView(
                                trip: trip,
                                members: viewModel.membersByTrip[trip.id] ?? []
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                router.push(.tripTimeline(tripId: trip.id))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                    .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
                    .frame(maxWidth: .infinity)
                }
            }

            // FAB: 56pt circle, accent color, subtle shadow
            Button {
                attemptCreateTrip()
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(ColorTokens.secondaryAccent, in: Circle())
                    .shadow(color: ColorTokens.cardShadow, radius: 12, y: 4)
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
                        .fontWeight(.medium)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.archivedTrips)
                } label: {
                    Image(systemName: "archivebox")
                        .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $showingNewTrip) {
            TripSetupView { tripId in
                router.push(.tripTimeline(tripId: tripId))
            }
        }
        .sheet(isPresented: $showingJoinTrip) {
            JoinTripView { tripId in
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
