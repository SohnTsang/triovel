import SwiftUI

/// Skeleton placeholder while posts are loading.
/// Matches PostCardView layout: accent avatar, name, time, body lines.
struct PostSkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                skeletonCard
            }
        }
        .onAppear { isAnimating = true }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Avatar — matches accent-tinted circle
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 4) {
                    // Name
                    RoundedRectangle(cornerRadius: 4)
                        .frame(width: 100, height: 13)
                    // Time: h:mm · yyyy-MM-dd
                    RoundedRectangle(cornerRadius: 4)
                        .frame(width: 140, height: 10)
                }
                Spacer()
            }

            // Body lines
            RoundedRectangle(cornerRadius: 4)
                .frame(height: 14)
            RoundedRectangle(cornerRadius: 4)
                .frame(width: 200, height: 14)
        }
        .padding(14)
        .foregroundStyle(Color(.systemGray5))
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(
            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
            value: isAnimating
        )
    }
}
