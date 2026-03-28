import SwiftUI

struct TripTimelineView: View {
    let tripId: String
    @Environment(AppState.self) private var appState
    @Environment(Router.self) private var router
    @State private var viewModel = TripTimelineViewModel()

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showingAddMoment = false
    @State private var addMomentDayDate: Date?

    var body: some View {
        @Bindable var vm = viewModel
        let filteredDays = viewModel.filteredDays

        ZStack(alignment: .bottomTrailing) {
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    DayRibbonView(
                        days: filteredDays,
                        selectedIndex: $vm.selectedDayIndex
                    )

                    FilterBarView(
                        activeFilter: $vm.activeFilter,
                        selectedPersonId: $vm.selectedPersonId,
                        personalBlockAuthors: viewModel.personalBlockAuthors
                    )

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 24) {
                                ForEach(filteredDays) { day in
                                    DaySectionView(
                                        day: day,
                                        creatorNameForBlock: { viewModel.creatorName(for: $0) },
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
            }

            // Floating + Activity
            Button {
                let currentDay = filteredDays.indices.contains(viewModel.selectedDayIndex)
                    ? filteredDays[viewModel.selectedDayIndex] : nil
                addMomentDayDate = currentDay?.date
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
        .navigationBarTitleDisplayMode(.inline)
        .plainBackButton()
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let title = viewModel.trip?.title {
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                        if !appState.isSyncConnected && appState.hasSynced {
                            Text(String(localized: "state.offline"))
                                .font(.caption2)
                                .foregroundStyle(ColorTokens.pendingTint)
                        }
                    }
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if #available(iOS 26, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.push(.tripMembers(tripId: tripId, members: viewModel.members, inviteLink: viewModel.trip?.inviteLink))
                    } label: { Image(systemName: "person.2").font(.body.weight(.semibold)).foregroundStyle(Color(.label)) }
                }
                .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.push(.tripSummary(tripId: tripId)) } label: {
                        Image(systemName: "chart.bar").font(.body.weight(.semibold)).foregroundStyle(Color(.label))
                    }
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            router.push(.tripMembers(tripId: tripId, members: viewModel.members, inviteLink: viewModel.trip?.inviteLink))
                        } label: { Image(systemName: "person.2").font(.body.weight(.semibold)).foregroundStyle(Color(.label)) }
                        Button { router.push(.tripSummary(tripId: tripId)) } label: {
                            Image(systemName: "chart.bar").font(.body.weight(.semibold)).foregroundStyle(Color(.label))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMoment) {
            AddMomentView(
                tripId: tripId,
                defaultDay: viewModel.selectedDayIndex + 1,
                dayDate: addMomentDayDate,
                displayTimezone: viewModel.trip?.displayTimezone ?? TimeZone.current.identifier,
                onBlockCreated: { blockId in
                    // Watch query auto-updates timeline; just navigate
                    router.push(.blockDetail(blockId: blockId))
                }
            )
        }
        .task(id: tripId) {
            if let userId = appState.currentUserId {
                viewModel.load(tripId: tripId, userId: userId)
            }
        }
        .onDisappear {
            viewModel.resetFilters()
        }
    }
}
