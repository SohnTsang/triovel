import SwiftUI

/// Full-screen gallery viewer for post media. Swipe between images.
/// Dark background, close button, page indicator.
struct FullScreenMediaViewer: View {
    let media: [PostMedia]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int

    init(media: [PostMedia], initialIndex: Int) {
        self.media = media
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(media.enumerated()), id: \.element.id) { index, item in
                    CachedMediaView(
                        mediaId: item.id,
                        storagePath: item.storagePath,
                        mediaType: item.mediaType
                    )
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))
            .ignoresSafeArea()

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .padding(16)
                }
                Spacer()
            }

            // Counter
            if media.count > 1 {
                VStack {
                    Spacer()
                    Text("\(currentIndex + 1) / \(media.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.4), in: Capsule())
                        .padding(.bottom, 50)
                }
            }
        }
        .statusBarHidden()
    }
}
