import SwiftUI

struct TripTimelineView: View {
    let tripId: String
    @Environment(AppState.self) private var appState
    @Environment(Router.self) private var router
    @State private var viewModel = TripTimelineViewModel()
    @State private var hasAppeared = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showingAddMoment = false
    @State private var addMomentGhostLabel: GhostBlockLabel?
    @State private var addMomentDayDate: Date?

    var body: some View {
        @Bindable var vm = viewModel
        let filteredDays = viewModel.filteredDays

        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                DayRibbonView(
                    days: filteredDays,
                    selectedIndex: $vm.selectedDayIndex
                )

                FilterBarView(activeFilter: $vm.activeFilter)

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
                        .padding(.vertical, 12)
                        .padding(.bottom, 80)
                        .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: viewModel.selectedDayIndex) { _, newIndex in
                        let dayNumber = filteredDays.indices.contains(newIndex)
                            ? filteredDays[newIndex].dayNumber : 1
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(dayNumber, anchor: .top)
                        }
                    }
                }
            }

            // Floating + Activity
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
                    .background(Color.accentColor, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding(24)
        }
        .navigationTitle(viewModel.trip?.title ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        router.push(.tripMembers(
                            tripId: tripId,
                            members: viewModel.members,
                            inviteLink: viewModel.trip?.inviteLink
                        ))
                    } label: {
                        Image(systemName: "person.2")
                            .font(.subheadline)
                    }

                    Button {
                        router.push(.tripSummary(tripId: tripId))
                    } label: {
                        Image(systemName: "chart.bar")
                            .font(.subheadline)
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
                    // Refresh timeline to show new block (ghost disappears)
                    Task { await viewModel.refreshBlocks() }
                    // Navigate into the new block detail
                    router.push(.blockDetail(blockId: blockId))
                }
            )
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            if let userId = appState.currentUserId {
                viewModel.load(tripId: tripId, userId: userId)
            }
        }
        .onDisappear {
            viewModel.activeFilter = .all
        }
    }
}
