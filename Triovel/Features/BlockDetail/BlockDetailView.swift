import SwiftUI

struct BlockDetailView: View {
    let blockId: String
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel = BlockDetailViewModel()
    @State private var showingBillEntry = false
    @State private var selectedBill: Bill?
    @State private var showingPaymentEntry = false
    @State private var showingDeleteBlock = false
    @State private var isDeletingBlock = false
    @Environment(Router.self) private var router

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
            if #available(iOS 26, *) {
                ToolbarItem(placement: .topBarTrailing) {
                    blockMenuButton
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    blockMenuButton
                }
            }
        }
        .sheet(isPresented: $showingBillEntry) {
            if let block = viewModel.block {
                BillEntryView(
                    blockId: block.id,
                    tripId: block.tripId,
                    members: viewModel.allMembers,
                    baseCurrency: viewModel.tripBaseCurrency,
                    currentUserId: appState.currentUserId ?? ""
                )
            }
        }
        .sheet(item: $selectedBill) { bill in
            BillDetailView(
                bill: bill,
                payerName: viewModel.payerName(for: bill),
                shares: viewModel.billShareDisplays(for: bill.id),
                payments: viewModel.tripPayments,
                members: viewModel.allMembers,
                currentUserId: appState.currentUserId ?? "",
                onDelete: { viewModel.deleteBill(bill) },
                canDelete: bill.payerId == appState.currentUserId,
                onRecordPayment: {
                    selectedBill = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingPaymentEntry = true
                    }
                }
            )
        }
        .sheet(isPresented: $showingPaymentEntry) {
            if let block = viewModel.block {
                PaymentEntrySheet(
                    tripId: block.tripId,
                    members: viewModel.allMembers,
                    baseCurrency: viewModel.tripBaseCurrency,
                    currentUserId: appState.currentUserId ?? ""
                )
            }
        }
        .alert(
            String(localized: "block.delete.title"),
            isPresented: $showingDeleteBlock
        ) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) {
                deleteBlock()
            }
        } message: {
            Text("block.delete.description")
        }
        .overlay {
            if isDeletingBlock {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .overlay { ProgressView().controlSize(.large).tint(.white) }
            }
        }
        .task {
            if let userId = appState.currentUserId {
                await viewModel.load(blockId: blockId, userId: userId)
            }
        }
    }

    private func deleteBlock() {
        isDeletingBlock = true
        Task {
            let start = ContinuousClock.now
            do {
                try await BlockRepository().deleteBlock(blockId: blockId)
                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
                router.pop()
            } catch {
                print("[BlockDetail] ❌ Delete block failed: \(error)")
                isDeletingBlock = false
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
            tripDisplayTimezone: viewModel.tripDisplayTimezone,
            isSaving: viewModel.isSavingHeader,
            billSummary: viewModel.billSummary,
            isEditing: $vm.isEditingHeader,
            editTitle: $vm.editTitle,
            editLocation: $vm.editLocation,
            editDescription: $vm.editDescription,
            editStartAt: $vm.editStartAt,
            editEndAt: $vm.editEndAt,
            editLocalTimezone: $vm.editLocalTimezone,
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
                                onMediaRetry: { mediaId in viewModel.retryMediaUpload(mediaId: mediaId) },
                                onEdit: { newBody in viewModel.editPost(post, newBody: newBody) },
                                onRemoveMedia: { mediaId in viewModel.deleteMedia(mediaId: mediaId, post: post) }
                            )
                            .id(post.id)
                        }

                        // Bills
                        ForEach(viewModel.bills) { bill in
                            BillCardView(
                                bill: bill,
                                payerName: viewModel.payerName(for: bill),
                                shareCount: viewModel.billShareCounts[bill.id] ?? 0,
                                isDeleting: viewModel.deletingBillId == bill.id,
                                onTap: { selectedBill = bill }
                            )
                            .id("bill-\(bill.id)")
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

    // MARK: - Menu

    private var blockMenuButton: some View {
        Menu {
            Button {
                showingBillEntry = true
            } label: {
                Label(String(localized: "bill.add.button"), systemImage: "banknote")
            }

            if viewModel.canEditHeader {
                Button {
                    if let block = viewModel.block {
                        viewModel.editTitle = block.title
                        viewModel.editLocation = block.locationText ?? ""
                        viewModel.editDescription = block.description ?? ""
                        viewModel.editStartAt = block.startAt
                        viewModel.editEndAt = block.endAt
                        viewModel.editLocalTimezone = block.localTimezone
                        viewModel.isEditingHeader = true
                    }
                } label: {
                    Label(String(localized: "block.edit.title"), systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    showingDeleteBlock = true
                } label: {
                    Label(String(localized: "block.delete.button"), systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.label))
        }
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
