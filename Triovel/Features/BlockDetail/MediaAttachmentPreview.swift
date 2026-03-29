import SwiftUI

/// Horizontal scrollable preview of selected media before sending.
/// Shows thumbnails with remove buttons + loading skeletons for processing items.
struct MediaAttachmentPreview: View {
    let items: [MediaItem]
    let processingCount: Int
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: item.thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Video badge
                        if item.type == .video {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.black.opacity(0.5), in: Circle())
                                .padding(4)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        }

                        // Remove button
                        Button {
                            onRemove(item.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .offset(x: 4, y: -4)
                    }
                    .frame(width: 72, height: 72)
                }

                // Loading skeletons for items still being processed
                ForEach(0..<processingCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 72, height: 72)
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.secondary)
                        }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}
