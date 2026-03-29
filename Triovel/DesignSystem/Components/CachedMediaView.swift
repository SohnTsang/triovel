import SwiftUI

/// Async image view that loads from local files, cache, or Supabase Storage.
/// Uses .task for off-main-thread loading — never blocks scroll.
///
/// Loading priority:
///   1. Local thumbnail (own uploads)
///   2. Memory/disk cache (previously downloaded)
///   3. Remote download from Supabase Storage
struct CachedMediaView: View {
    let mediaId: String
    let storagePath: String?
    let mediaType: MediaType

    @State private var image: UIImage?
    @State private var loadState: LoadState = .idle

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.systemGray5)
                    .overlay {
                        switch loadState {
                        case .loading:
                            ProgressView()
                                .tint(.secondary)
                        case .failed:
                            Image(systemName: mediaType == .photo ? "photo" : "video")
                                .foregroundStyle(.quaternary)
                        default:
                            Image(systemName: mediaType == .photo ? "photo" : "video")
                                .foregroundStyle(.quaternary)
                        }
                    }
            }
        }
        .task(id: mediaId) {
            guard image == nil else { return }
            await loadImage()
        }
    }

    private func loadImage() async {
        loadState = .loading

        if let loaded = await ImageCache.shared.loadThumbnail(
            mediaId: mediaId,
            storagePath: storagePath
        ) {
            withAnimation(.easeIn(duration: 0.15)) {
                image = loaded
            }
            loadState = .loaded
        } else {
            loadState = storagePath != nil ? .failed : .idle
        }
    }
}

// MARK: - State

extension CachedMediaView {
    enum LoadState {
        case idle
        case loading
        case loaded
        case failed
    }
}
