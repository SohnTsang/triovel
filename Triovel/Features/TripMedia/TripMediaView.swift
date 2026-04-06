import SwiftUI

/// Grid gallery of all media in a trip. Tap to open full-screen viewer.
/// Sort by newest or oldest.
struct TripMediaView: View {
    let tripId: String

    @Environment(AppState.self) private var appState
    @State private var media: [PostMedia] = []
    @State private var isLoading = false
    @State private var sortNewestFirst = true
    @State private var fullScreenIndex: Int?

    private let repository = PostMediaRepository()

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    private var sortedMedia: [PostMedia] {
        if sortNewestFirst {
            return media.sorted { $0.createdAt > $1.createdAt }
        } else {
            return media.sorted { $0.createdAt < $1.createdAt }
        }
    }

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.regular)
                    Spacer()
                }
            } else if media.isEmpty {
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
                    let cellSize = (geo.size.width - 4) / 3 // 3 columns, 2pt spacing each

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(Array(sortedMedia.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    fullScreenIndex = index
                                } label: {
                                    MediaThumbnailCell(
                                        item: item,
                                        size: cellSize
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "trip.media.title"))
        .navigationBarTitleDisplayMode(.inline)
        .plainBackButton()
        .toolbar {
            if #available(iOS 26, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    sortButton
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    sortButton
                }
            }
        }
        .fullScreenCover(item: fullScreenBinding) { wrapper in
            FullScreenMediaViewer(
                media: sortedMedia,
                initialIndex: wrapper.index
            )
        }
        .task {
            await loadMedia()
        }
    }

    // MARK: - Sort Button

    private var sortButton: some View {
        Menu {
            Picker(selection: $sortNewestFirst) {
                Text("trip.media.sort.newest").tag(true)
                Text("trip.media.sort.oldest").tag(false)
            } label: {
                EmptyView()
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.label))
        }
    }

    // MARK: - Load

    private func loadMedia() async {
        guard let userId = appState.currentUserId else { return }
        isLoading = true
        let start = ContinuousClock.now
        do {
            media = try await repository.fetchMediaForTrip(tripId: tripId, currentUserId: userId)
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

// MARK: - Thumbnail Cell

/// Fixed-size square cell. Shows a gray placeholder immediately,
/// then loads the image async. No layout shift because the frame
/// is locked before the image arrives.
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

/// Identifiable wrapper so fullScreenCover(item:) works with an index.
private struct IndexWrapper: Identifiable {
    let index: Int
    var id: Int { index }
}
