import SwiftUI

struct BlockDetailView: View {
    let blockId: String
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel = BlockDetailViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if let block = viewModel.block {
                blockContent(block)
            } else if let error = viewModel.errorMessage {
                errorState(error)
            } else {
                // Loading state (covers both delayed and immediate loading)
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Spacer()
            }
        }
        .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
        .frame(maxWidth: .infinity)
        .navigationBarTitleDisplayMode(.inline)
        .plainBackButton()
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let title = viewModel.block?.title {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .task {
            if let userId = appState.currentUserId {
                await viewModel.load(blockId: blockId, userId: userId)
            }
        }
    }

    // MARK: - Block Content

    @ViewBuilder
    private func blockContent(_ block: Block) -> some View {
        @Bindable var vm = viewModel
        BlockDetailHeaderView(
            block: block,
            canEdit: viewModel.canEditHeader,
            isSaving: viewModel.isSavingHeader,
            isEditing: $vm.isEditingHeader,
            editTitle: $vm.editTitle,
            editLocation: $vm.editLocation,
            editDescription: $vm.editDescription,
            editStartAt: $vm.editStartAt,
            onSave: { viewModel.saveHeaderEdits() }
        )

        Divider()

        // Unified chronological stream
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.isLoadingPosts {
                        PostSkeletonView()
                    } else if viewModel.posts.isEmpty && viewModel.failedDrafts.isEmpty {
                        emptyPostsState
                    } else {
                        // Real posts
                        ForEach(viewModel.posts) { post in
                            PostCardView(
                                post: post,
                                authorName: viewModel.authorName(for: post),
                                isOwn: viewModel.isOwnPost(post),
                                media: viewModel.mediaItems(for: post.id),
                                isDeleting: viewModel.deletingPostId == post.id,
                                onDelete: { viewModel.deletePost(post) },
                                onRetry: nil,
                                onMediaRetry: { mediaId in viewModel.retryMediaUpload(mediaId: mediaId) }
                            )
                            .id(post.id)
                        }

                        // Failed drafts
                        ForEach(viewModel.failedDrafts) { draft in
                            FailedPostCardView(
                                bodyText: draft.body,
                                onRetry: { viewModel.retryDraft(draft) },
                                onDiscard: { viewModel.discardDraft(draft) }
                            )
                        }
                    }
                }
                .padding(16)
            }
            .onChange(of: viewModel.posts.count) { _, _ in
                // Scroll to newest post
                if let last = viewModel.posts.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }

        // Composer
        PostComposerView(
            onSend: { body, visibility, mediaItems in
                viewModel.sendPost(body: body, visibility: visibility, mediaItems: mediaItems)
            },
            isSending: viewModel.isSendingPost
        )
    }

    // MARK: - Empty State

    private var emptyPostsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            Text("post.empty.title")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .padding(.bottom, 24)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "common.retry")) {
                Task {
                    if let userId = appState.currentUserId {
                        await viewModel.load(blockId: blockId, userId: userId)
                    }
                }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }
}
