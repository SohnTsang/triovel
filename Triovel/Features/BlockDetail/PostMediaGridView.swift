import SwiftUI

/// Displays media attachments in a post card, handling all upload states.
/// - 1 image: full width, 200pt height
/// - 2+ images: horizontal scrollable strip (bounded height, swipe to see more)
/// Tap any image → full-screen gallery viewer.
struct PostMediaGridView: View {
    let media: [PostMedia]
    var onRetry: ((String) -> Void)?

    private let cornerRadius: CGFloat = 8
    @State private var fullScreenIndex: Int?

    var body: some View {
        if media.count == 1 {
            singleMediaView(media[0])
        } else if !media.isEmpty {
            multiMediaStrip
        }
    }

    // MARK: - Single Media (full width, tappable)

    @ViewBuilder
    private func singleMediaView(_ item: PostMedia) -> some View {
        mediaCell(item, index: 0)
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .fullScreenCover(item: $fullScreenIndex) { index in
                FullScreenMediaViewer(media: media, initialIndex: index)
            }
    }

    // MARK: - Multi Media (horizontal strip)

    private var multiMediaStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(media.enumerated()), id: \.element.id) { index, item in
                        mediaCell(item, index: index)
                            .frame(width: 160, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    }
                }
            }

            // Photo count hint
            if media.count > 2 {
                Text("media.count \(media.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .fullScreenCover(item: $fullScreenIndex) { index in
            FullScreenMediaViewer(media: media, initialIndex: index)
        }
    }

    // MARK: - Media Cell (handles upload states + tap)

    @ViewBuilder
    private func mediaCell(_ item: PostMedia, index: Int) -> some View {
        if item.uploadStatus == .failed {
            failedCell(item)
        } else if isUploaded(item) {
            // Uploaded — show image, tappable for full-screen
            CachedMediaView(
                mediaId: item.id,
                storagePath: item.storagePath,
                mediaType: item.mediaType
            )
            .contentShape(Rectangle())
            .onTapGesture {
                fullScreenIndex = index
            }
        } else {
            // Queued / uploading — syncing overlay
            ZStack {
                CachedMediaView(
                    mediaId: item.id,
                    storagePath: nil,
                    mediaType: item.mediaType
                )
                .opacity(0.5)

                VStack(spacing: 4) {
                    ProgressView()
                        .tint(.white)
                    Text("media.syncing")
                        .font(.caption2)
                        .foregroundStyle(.white)
                }
                .padding(8)
                .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }
            .background(Color(.systemGray5))
        }
    }

    @ViewBuilder
    private func failedCell(_ item: PostMedia) -> some View {
        ZStack {
            CachedMediaView(
                mediaId: item.id,
                storagePath: nil,
                mediaType: item.mediaType
            )
            .opacity(0.3)

            VStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(.white)
                Text("media.failed.retry")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(8)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        }
        .background(Color(.systemGray5))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(ColorTokens.failedTint, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onRetry?(item.id)
        }
    }

    // MARK: - Helpers

    /// True if the media has finished uploading (local or remote).
    private func isUploaded(_ item: PostMedia) -> Bool {
        item.storagePath != nil || item.uploadStatus == .uploaded
    }
}

// MARK: - Int Identifiable conformance for fullScreenCover(item:)

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
