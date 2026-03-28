import SwiftUI

/// Displays media attachments in a post card, handling all upload states.
/// 1 image = full width, 2+ = 2-column grid.
struct PostMediaGridView: View {
    let media: [PostMedia]
    var onRetry: ((String) -> Void)?

    private let spacing: CGFloat = 4
    private let cornerRadius: CGFloat = 8

    var body: some View {
        if media.count == 1 {
            singleMediaView(media[0])
        } else if media.count == 2 {
            HStack(spacing: spacing) {
                mediaView(media[0])
                mediaView(media[1])
            }
            .frame(height: 160)
        } else if !media.isEmpty {
            let rows = stride(from: 0, to: media.count, by: 2).map { i in
                Array(media[i..<min(i + 2, media.count)])
            }
            VStack(spacing: spacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: spacing) {
                        ForEach(row) { item in
                            mediaView(item)
                        }
                    }
                    .frame(height: 120)
                }
            }
        }
    }

    // MARK: - Single Media (full width)

    @ViewBuilder
    private func singleMediaView(_ item: PostMedia) -> some View {
        mediaView(item)
            .frame(height: 200)
    }

    // MARK: - Media View (handles upload states)

    /// True if the media has finished uploading.
    /// Uses storage_path as primary indicator because upload_status gets overwritten
    /// by PowerSync sync reconciliation (local 'uploaded' → server 'queued' → loop).
    /// Also checks local file existence as fallback — if we have the file, show it.
    private func isUploaded(_ item: PostMedia) -> Bool {
        item.storagePath != nil
            || item.uploadStatus == .uploaded
            || MediaFileManager.loadThumbnail(for: item.id) != nil
    }

    @ViewBuilder
    private func mediaView(_ item: PostMedia) -> some View {
        if item.uploadStatus == .failed {
            failedView(item)
        } else if isUploaded(item) {
            // Uploaded — show image
            thumbnailImage(for: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            // Queued / uploading — syncing overlay
            ZStack {
                thumbnailImage(for: item)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    private func failedView(_ item: PostMedia) -> some View {
        ZStack {
            thumbnailImage(for: item)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(ColorTokens.failedTint, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onRetry?(item.id)
        }
    }

    // MARK: - Thumbnail

    @ViewBuilder
    private func thumbnailImage(for item: PostMedia) -> some View {
        if let thumb = MediaFileManager.loadThumbnail(for: item.id) {
            Image(uiImage: thumb)
                .resizable()
                .scaledToFill()
        } else {
            // Fallback: gray placeholder
            Color(.systemGray5)
                .overlay {
                    Image(systemName: item.mediaType == .photo ? "photo" : "video")
                        .foregroundStyle(.tertiary)
                }
        }
    }
}
