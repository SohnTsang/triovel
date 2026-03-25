import SwiftUI

struct TripTimelineView: View {
    let tripId: String
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: Router
    @StateObject private var viewModel = TripTimelineViewModel()

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showingAddMoment = false
    @State private var addMomentGhostLabel: GhostBlockLabel?
    @State private var addMomentDayDate: Date?

    var body: some View {
        let filteredDays = viewModel.filteredDays

        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                DayRibbonView(
                    days: filteredDays,
                    selectedIndex: $viewModel.selectedDayIndex
                )

                FilterBarView(activeFilter: $viewModel.activeFilter)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(filteredDays) { day in
                                DaySectionView(
                                    day: day,
                                    creatorNameForBlock: { viewModel.creatorName(for: $0) },
                                    onGhostTap: { ghost in
                                        addMomentGhostLabel = ghost.label
                                        addMomentDayDate = ghost.dayDate
                                        showingAddMoment = true
                                    },
                                    onBlockTap: { block in
                                        router.push(.blockDetail(blockId: block.id))
                                    }
                                )
                                .id(day.dayNumber)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.bottom, 80)
                        .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: viewModel.selectedDayIndex) { _, newIndex in
                        let dayNumber = filteredDays.indices.contains(newIndex)
                            ? filteredDays[newIndex].dayNumber : 1
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            proxy.scrollTo(dayNumber, anchor: .top)
                        }
                    }
                }
            }

            // FAB: capsule with label
            Button {
                let currentDay = filteredDays.indices.contains(viewModel.selectedDayIndex)
                    ? filteredDays[viewModel.selectedDayIndex] : nil
                addMomentDayDate = currentDay?.date
                addMomentGhostLabel = nil
                showingAddMoment = true
            } label: {
                Label(String(localized: "timeline.add.moment"), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(ColorTokens.secondaryAccent, in: Capsule())
                    .shadow(color: ColorTokens.cardShadow, radius: 12, y: 4)
            }
            .padding(24)
        }
        .navigationTitle(viewModel.trip?.title ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        router.push(.tripMembers(
                            tripId: tripId,
                            members: viewModel.members,
                            inviteLink: viewModel.trip?.inviteLink
                        ))
                    } label: {
                        Image(systemName: "person.2")
                            .fontWeight(.medium)
                    }
                    Button {
                        router.push(.tripSummary(tripId: tripId))
                    } label: {
                        Image(systemName: "chart.bar")
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMoment) {
            AddMomentView(
                tripId: tripId,
                defaultDay: viewModel.selectedDayIndex + 1,
                dayDate: addMomentDayDate,
                ghostLabel: addMomentGhostLabel,
                displayTimezone: viewModel.trip?.displayTimezone ?? TimeZone.current.identifier,
                onBlockCreated: { blockId in
                    Task { await viewModel.refreshBlocks() }
                    router.push(.blockDetail(blockId: blockId))
                }
            )
        }
        .onAppear {
            if let userId = appState.currentUserId {
                viewModel.load(tripId: tripId, userId: userId)
            }
        }
        .onDisappear {
            viewModel.activeFilter = .all
        }
    }
}
