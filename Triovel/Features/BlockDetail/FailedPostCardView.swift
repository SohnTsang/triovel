import SwiftUI

/// Shown when a post failed to send. Calm retry affordance — never alarming.
struct FailedPostCardView: View {
    let bodyText: String
    let onRetry: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.failedTint)
                Text("post.failed.label")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 16) {
                Button {
                    onRetry()
                } label: {
                    Label(String(localized: "common.retry"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.medium))
                }

                Button(role: .destructive) {
                    onDiscard()
                } label: {
                    Text("post.failed.discard")
                        .font(.subheadline)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.failedTint.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(ColorTokens.failedTint.opacity(0.2), lineWidth: 0.5)
        )
    }
}
