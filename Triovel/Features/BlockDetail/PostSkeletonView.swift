import SwiftUI

/// Skeleton placeholder while posts are loading.
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
                Circle()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .frame(width: 100, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .frame(width: 60, height: 10)
                }
                Spacer()
            }

            RoundedRectangle(cornerRadius: 4)
                .frame(height: 14)
            RoundedRectangle(cornerRadius: 4)
                .frame(width: 200, height: 14)
        }
        .padding(16)
        .foregroundStyle(Color(.systemGray5))
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(
            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
            value: isAnimating
        )
    }
}
