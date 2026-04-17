import SwiftUI

/// Grid gallery of all media in a trip, grouped by day.
/// Each day section shows "Day N · MMM d" header, then a 3-column grid.
struct TripMediaView: View {
    let tripId: String

    @Environment(AppState.self) private var appState
    @State private var daySections: [MediaDaySection] = []
    @State private var flatMedia: [PostMedia] = []
    @State private var isLoading = false
    @State private var fullScreenIndex: Int?

    private let repository = PostMediaRepository()

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.regular)
                    Spacer()
                }
            } else if flatMedia.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("trip.media.empty")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                GeometryReader { geo in
                    let cellSize = (geo.size.width - 4) / 3

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(daySections) { section in
                                // Day header
                                Text(section.title)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 16)
                                    .padding(.top, section.id == daySections.first?.id ? 0 : 8)

                                // Media grid for this day
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(section.items) { item in
                                        Button {
                                            fullScreenIndex = item.flatIndex
                                        } label: {
                                            MediaThumbnailCell(item: item.media, size: cellSize)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "trip.media.title"))
        .navigationBarTitleDisplayMode(.inline)
        .plainBackButton()
        .fullScreenCover(item: fullScreenBinding) { wrapper in
            FullScreenMediaViewer(
                media: flatMedia,
                initialIndex: wrapper.index
            )
        }
        .task {
            await loadMedia()
        }
    }

    // MARK: - Load

    private func loadMedia() async {
        guard let userId = appState.currentUserId else { return }
        isLoading = true
        let start = ContinuousClock.now
        do {
            let blockRepo = BlockRepository()
            let trip = try await blockRepo.fetchTrip(tripId: tripId)
            let items = try await repository.fetchMediaWithBlockDate(tripId: tripId, currentUserId: userId)

            let tz = TimeZone(identifier: trip.displayTimezone) ?? .current
            var cal = Calendar.current
            cal.timeZone = tz
            let tripStart = cal.startOfDay(for: trip.startDate)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            dateFormatter.timeZone = tz

            // Group by day number
            var dayMap: [Int: [MediaDayItem]] = [:]
            var flat: [PostMedia] = []

            for (index, item) in items.enumerated() {
                let blockDay = cal.startOfDay(for: item.blockStartAt)
                let dayNumber = max(1, cal.dateComponents([.day], from: tripStart, to: blockDay).day! + 1)
                let dayItem = MediaDayItem(media: item.media, flatIndex: index)
                dayMap[dayNumber, default: []].append(dayItem)
                flat.append(item.media)
            }

            let sections = dayMap.sorted { $0.key < $1.key }.map { dayNum, items in
                let dayDate = cal.date(byAdding: .day, value: dayNum - 1, to: tripStart) ?? tripStart
                let dateStr = dateFormatter.string(from: dayDate)
                return MediaDaySection(
                    dayNumber: dayNum,
                    title: String(localized: "timeline.day \(dayNum)") + " · " + dateStr,
                    items: items
                )
            }

            daySections = sections
            flatMedia = flat
        } catch {
            print("[TripMedia] ❌ Failed to load media: \(error)")
        }
        let elapsed = ContinuousClock.now - start
        if elapsed < .milliseconds(500) {
            try? await Task.sleep(for: .milliseconds(500) - elapsed)
        }
        isLoading = false
    }

    // MARK: - Full Screen Binding

    private var fullScreenBinding: Binding<IndexWrapper?> {
        Binding(
            get: { fullScreenIndex.map { IndexWrapper(index: $0) } },
            set: { fullScreenIndex = $0?.index }
        )
    }
}

// MARK: - Models

private struct MediaDaySection: Identifiable {
    let dayNumber: Int
    let title: String
    let items: [MediaDayItem]
    var id: Int { dayNumber }
}

private struct MediaDayItem: Identifiable {
    let media: PostMedia
    let flatIndex: Int
    var id: String { media.id }
}

// MARK: - Thumbnail Cell

private struct MediaThumbnailCell: View {
    let item: PostMedia
    let size: CGFloat

    var body: some View {
        CachedMediaView(
            mediaId: item.id,
            storagePath: item.storagePath,
            mediaType: item.mediaType
        )
        .frame(width: size, height: size)
        .clipped()
        .contentShape(Rectangle())
    }
}

private struct IndexWrapper: Identifiable {
    let index: Int
    var id: Int { index }
}
