import SwiftUI

/// A single post in the block detail stream.
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
        VStack(alignment: .leading, spacing: 10) {
            // Author row
            HStack(spacing: 10) {
                // Avatar
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Text(initials)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(authorName)
                            .font(.subheadline.weight(.semibold))
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

                    // Time: h:mm · yyyy-MM-dd
                    Text(formattedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Own post actions — visible icon
                if isOwn {
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label(String(localized: "common.delete"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            post.visibility == .private
                ? ColorTokens.personalBackground
                : Color(.systemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .overlay(
            post.visibility == .private
                ? RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(ColorTokens.personalBorder, lineWidth: 1)
                : nil
        )
        .confirmationDialog(
            String(localized: "post.delete.confirm.title"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete"), role: .destructive) {
                onDelete()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text("post.delete.confirm.message")
        }
    }

    // MARK: - Helpers

    private var formattedTime: String {
        let time = post.createdAt.formatted(.dateTime.hour().minute())
        let date = post.createdAt.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
        return "\(time) · \(date)"
    }

    private var initials: String {
        let parts = authorName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(authorName.prefix(2)).uppercased()
    }
}
