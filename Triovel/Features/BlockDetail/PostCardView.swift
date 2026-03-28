import SwiftUI

/// A single post in the block detail stream.
/// Shows author avatar, name, time, body text, and privacy indicator.
struct PostCardView: View {
    let post: Post
    let authorName: String
    let isOwn: Bool
    var media: [PostMedia] = []
    let onDelete: () -> Void
    let onRetry: (() -> Void)?
    var onMediaRetry: ((String) -> Void)?

    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author row
            HStack(spacing: 10) {
                // Avatar
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(initials)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(authorName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)

                        if post.visibility == .private {
                            Label {
                                Text("post.visibility.just.me")
                                    .font(.caption2)
                            } icon: {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                            }
                            .foregroundStyle(ColorTokens.personalTint)
                        }
                    }

                    Text(post.createdAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Own post actions
                if isOwn {
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label(String(localized: "common.delete"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                }
            }

            // Post body
            if let body = post.body, !body.isEmpty {
                Text(body)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Media attachments
            if !media.isEmpty {
                PostMediaGridView(media: media, onRetry: onMediaRetry)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            post.visibility == .private
                ? ColorTokens.personalBackground
                : Color(.secondarySystemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            post.visibility == .private
                ? RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(ColorTokens.personalBorder, lineWidth: 0.5)
                : nil
        )
        .alert(
            String(localized: "post.delete.confirm.title"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) {
                onDelete()
            }
        } message: {
            Text("post.delete.confirm.message")
        }
    }

    private var initials: String {
        let parts = authorName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(authorName.prefix(2)).uppercased()
    }
}
