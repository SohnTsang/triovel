import SwiftUI

/// A single post in the block detail stream.
struct PostCardView: View {
    let post: Post
    let authorName: String
    let isOwn: Bool
    var media: [PostMedia] = []
    var isDeleting: Bool = false
    let onDelete: () -> Void
    let onRetry: (() -> Void)?
    var onMediaRetry: ((String) -> Void)?
    var onEdit: ((String) -> Void)?
    var onRemoveMedia: ((String) -> Void)?

    @State private var showingDeleteConfirmation = false
    @State private var showingEditSheet = false
    @State private var editText = ""
    @State private var mediaToRemove: Set<String> = []
    @State private var isSavingEdit = false

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
                        Button {
                            editText = post.body ?? ""
                            mediaToRemove = []
                            showingEditSheet = true
                        } label: {
                            Label(String(localized: "common.edit"), systemImage: "pencil")
                        }

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
        .background {
            if post.visibility == .private {
                RoundedRectangle(cornerRadius: 14).fill(ColorTokens.personalBackground)
            } else {
                RoundedRectangle(cornerRadius: 14).fill(ColorTokens.cardBackground)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    post.visibility == .private
                        ? ColorTokens.personalBorder
                        : Color(.systemGray4),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 2)
        .opacity(isDeleting ? 0.5 : 1.0)
        .overlay {
            if isDeleting {
                ProgressView()
                    .tint(.secondary)
            }
        }
        .allowsHitTesting(!isDeleting)
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
        .sheet(isPresented: $showingEditSheet) {
            editPostSheet
        }
    }

    // MARK: - Edit Post Sheet

    private var editPostSheet: some View {
        NavigationStack {
            Form {
                if post.body != nil {
                    Section {
                        TextField(String(localized: "post.edit.placeholder"), text: $editText, axis: .vertical)
                            .lineLimit(2...10)
                    }
                }

                // Media with remove buttons
                let visibleMedia = media.filter { !mediaToRemove.contains($0.id) }
                if !visibleMedia.isEmpty {
                    Section(String(localized: "post.edit.media")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(visibleMedia) { item in
                                    ZStack(alignment: .topTrailing) {
                                        CachedMediaView(
                                            mediaId: item.id,
                                            storagePath: item.storagePath,
                                            mediaType: item.mediaType
                                        )
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            mediaToRemove.insert(item.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.body)
                                                .foregroundStyle(.white)
                                                .shadow(radius: 2)
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if post.visibility == .private {
                    Section {
                        Label {
                            Text("post.edit.visibility.locked")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(ColorTokens.personalTint)
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "post.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        showingEditSheet = false
                    }
                    .disabled(isSavingEdit)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSavingEdit {
                        ProgressView()
                    } else {
                        Button(String(localized: "common.save")) {
                            saveEdit()
                        }
                        .disabled(!hasEditChanges)
                    }
                }
            }
            .interactiveDismissDisabled(isSavingEdit)
        }
        .presentationDetents([.medium, .large])
    }

    private var hasEditChanges: Bool {
        let textChanged = editText.trimmingCharacters(in: .whitespacesAndNewlines) != (post.body ?? "")
        let mediaRemoved = !mediaToRemove.isEmpty
        return textChanged || mediaRemoved
    }

    private func saveEdit() {
        isSavingEdit = true

        // Capture values before async — DB write happens AFTER loading
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        let textChanged = trimmed != (post.body ?? "")
        let removedIds = mediaToRemove

        Task {
            let start = ContinuousClock.now

            // Write to DB
            if textChanged {
                onEdit?(trimmed)
            }
            for mediaId in removedIds {
                onRemoveMedia?(mediaId)
            }

            // 500ms minimum loading, then dismiss
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }

            isSavingEdit = false
            showingEditSheet = false
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
