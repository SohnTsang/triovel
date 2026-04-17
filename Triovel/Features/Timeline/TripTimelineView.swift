import SwiftUI

struct TripTimelineView: View {
    let tripId: String
    @Environment(AppState.self) private var appState
    @Environment(Router.self) private var router
    @State private var viewModel = TripTimelineViewModel()

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showingAddMoment = false
    @State private var showingArchiveAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingEditTrip = false
    @State private var isDeletingTrip = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isTitleExpanded = false

    private var isOwner: Bool {
        viewModel.trip?.createdBy == appState.currentUserId
    }

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
                    // Trip title — tappable expand/collapse
                    if let trip = viewModel.trip {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isTitleExpanded.toggle()
                            }
                        } label: {
                            Text(trip.title)
                                .font(.title3.weight(.semibold))
                                .lineLimit(isTitleExpanded ? nil : 2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }

                    DayRibbonView(
                        days: filteredDays,
                        selectedIndex: $vm.selectedDayIndex
                    )

                    FilterBarView(
                        activeFilter: $vm.activeFilter,
                        selectedPersonId: $vm.selectedPersonId,
                        personalBlockAuthors: viewModel.personalBlockAuthors
                    )

                    // Show only the selected day's content
                    ScrollView {
                        if let selectedDay = filteredDays.indices.contains(viewModel.selectedDayIndex)
                            ? filteredDays[viewModel.selectedDayIndex] : nil {
                            DaySectionView(
                                day: selectedDay,
                                tripDisplayTimezone: viewModel.trip?.displayTimezone ?? "",
                                creatorNameForBlock: { viewModel.creatorName(for: $0) },
                                postCounts: viewModel.postCounts,
                                billCounts: viewModel.billCounts,
                                docCounts: viewModel.docCounts,
                                onBlockTap: { block in
                                    router.push(.blockDetail(blockId: block.id))
                                }
                            )
                            .padding(.vertical, 12)
                            .padding(.bottom, 80)
                            .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
                            .frame(maxWidth: .infinity)
                            .id(viewModel.selectedDayIndex)
                            .transition(.opacity)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 50, coordinateSpace: .local)
                            .onEnded { value in
                                let horizontal = value.translation.width
                                let vertical = value.translation.height
                                // Only trigger on predominantly horizontal swipes
                                guard abs(horizontal) > abs(vertical) else { return }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if horizontal < 0 && viewModel.selectedDayIndex < filteredDays.count - 1 {
                                        viewModel.selectedDayIndex += 1
                                    } else if horizontal > 0 && viewModel.selectedDayIndex > 0 {
                                        viewModel.selectedDayIndex -= 1
                                    }
                                }
                            }
                    )
                }
            }

            // Floating + Activity
            Button {
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

            // Toast overlay
            if showToast {
                VStack {
                    Text(toastMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.75), in: Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .plainBackButton()
        .toolbar {
            ToolbarItem(placement: .principal) {
                if viewModel.trip != nil {
                    Text("trip.detail.title")
                        .font(.headline)
                    /* Timezone subtitle — commented out for now
                    VStack(spacing: 2) {
                        Text("trip.detail.title")
                            .font(.headline)
                        HStack(spacing: 4) {
                            let tz = TimeZone(identifier: trip.displayTimezone) ?? .current
                            let abbr = tz.localizedName(for: .shortGeneric, locale: .current) ?? tz.abbreviation() ?? ""
                            let city = trip.displayTimezone.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? trip.displayTimezone
                            Text("\(abbr) · \(city)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if !appState.isSyncConnected && appState.hasSynced {
                                Image(systemName: "icloud.slash")
                                    .font(.caption2)
                                    .foregroundStyle(ColorTokens.pendingTint)
                            }
                        }
                    }
                    */
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if #available(iOS 26, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarTrailingButtons
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarTrailingButtons
                }
            }
        }
        /* Archive alert — commented out for now
        .alert(
            String(localized: "trip.archive.title"),
            isPresented: $showingArchiveAlert
        ) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "trip.archive.button"), role: .destructive) {
                Task {
                    let start = ContinuousClock.now
                    try? await TripRepository().archiveTrip(tripId: tripId)
                    let elapsed = ContinuousClock.now - start
                    if elapsed < .milliseconds(500) {
                        try? await Task.sleep(for: .milliseconds(500) - elapsed)
                    }
                    router.popToRoot()
                }
            }
        } message: {
            Text("trip.archive.description")
        }
        */
        .alert(
            String(localized: "trip.delete.title"),
            isPresented: $showingDeleteAlert
        ) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) {
                deleteTrip()
            }
        } message: {
            Text("trip.delete.description")
        }
        .overlay {
            if isDeletingTrip {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    }
            }
        }
        .sheet(isPresented: $showingEditTrip) {
            if let trip = viewModel.trip {
                EditTripView(trip: trip) {
                    if let userId = appState.currentUserId {
                        viewModel.load(tripId: tripId, userId: userId)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMoment) {
            let days = viewModel.filteredDays
            let dayIndex = viewModel.selectedDayIndex
            let dayDate = days.indices.contains(dayIndex) ? days[dayIndex].date : viewModel.trip?.startDate

            AddMomentView(
                tripId: tripId,
                defaultDay: dayIndex + 1,
                dayDate: dayDate,
                displayTimezone: viewModel.trip?.displayTimezone ?? TimeZone.current.identifier,
                onBlockCreated: { blockId in
                    router.push(.blockDetail(blockId: blockId))
                },
                timelineViewModel: viewModel
            )
        }
        .task(id: tripId) {
            // Let the push animation finish before starting heavy DB work.
            // Without this, fetching trip + generating days blocks the main
            // thread and freezes the slide animation midway.
            try? await Task.sleep(for: .milliseconds(350))
            if let userId = appState.currentUserId {
                viewModel.load(tripId: tripId, userId: userId)
            }
        }
        .onDisappear {
            viewModel.resetFilters()
        }
    }

    // MARK: - Toolbar Buttons

    private var toolbarTrailingButtons: some View {
        HStack(spacing: 12) {
            Button {
                router.push(.tripMembers(tripId: tripId, members: viewModel.members, inviteLink: viewModel.trip?.inviteLink))
            } label: {
                Image(systemName: "person.badge.plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(.label))
                    .padding(.bottom, -4)
            }
            .buttonStyle(.plain)

            tripMenu
        }
        .animation(nil, value: true)
    }

    // MARK: - Trip Menu

    private var tripMenu: some View {
        UIKitMenuButton(
            icon: "ellipsis.circle",
            actions: tripMenuActions
        )
        .frame(width: 28, height: 28)
    }

    private var tripMenuActions: [UIKitMenuButton.MenuAction] {
        var actions: [UIKitMenuButton.MenuAction] = [
            .init(String(localized: "trip.menu.bills"), image: "banknote") {
                router.push(.tripSummary(tripId: tripId))
            },
            .init(String(localized: "trip.media.title"), image: "photo.on.rectangle.angled") {
                router.push(.tripMedia(tripId: tripId))
            },
            .init(String(localized: "trip.files.title"), image: "doc.text") {
                router.push(.tripFiles(tripId: tripId))
            },
        ]

        actions.append(.init(String(localized: "trip.edit.title"), image: "pencil") {
            showingEditTrip = true
        })

        if isOwner {
            actions.append(.init(String(localized: "trip.delete.button"), image: "trash", isDestructive: true) {
                showingDeleteAlert = true
            })
        }

        return actions
    }

    // MARK: - Delete Trip

    private func deleteTrip() {
        isDeletingTrip = true
        Task {
            let start = ContinuousClock.now
            do {
                try await TripRepository().deleteTrip(tripId: tripId)
                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
                router.popToRoot()
            } catch {
                print("[Timeline] ❌ Delete trip failed: \(error)")
                isDeletingTrip = false
            }
        }
    }
}
