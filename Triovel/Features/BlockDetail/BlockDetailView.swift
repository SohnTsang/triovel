import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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
    @State private var showingEditSheet = false
    @State private var showingDocumentPicker = false
    @State private var showingDocumentPhotoPicker = false
    @State private var documentPhotoItem: PhotosPickerItem?
    @State private var selectedStreamTab: StreamTab = .posts

    private enum StreamTab {
        case posts, bills, documents
    }
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
            if viewModel.canEditHeader {
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
                onEdit: { amount, currency, note, memberIds in
                    viewModel.updateBill(bill, amount: amount, currency: currency, note: note, memberIds: memberIds)
                },
                canDelete: bill.payerId == appState.currentUserId,
                canEdit: bill.payerId == appState.currentUserId,
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
        .sheet(isPresented: $showingEditSheet) {
            if let block = viewModel.block {
                EditBlockSheet(
                    block: block,
                    tripDisplayTimezone: viewModel.tripDisplayTimezone,
                    tripStartDate: viewModel.tripStartDate,
                    tripEndDate: viewModel.tripEndDate
                ) { fields in
                    await viewModel.applyEditFields(fields)
                }
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.pdf, .jpeg, .png, .heic],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let fileName = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                let fileType: DocumentFileType = ext == "pdf" ? .pdf : .image
                viewModel.addDocument(url: url, fileName: fileName, fileType: fileType)
            case .failure(let error):
                print("[BlockDetail] ❌ File import failed: \(error)")
            }
        }
        .photosPicker(
            isPresented: $showingDocumentPhotoPicker,
            selection: $documentPhotoItem,
            matching: .images
        )
        .onChange(of: documentPhotoItem) { _, item in
            guard let item else { return }
            documentPhotoItem = nil
            Task {
                await processDocumentPhoto(item)
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
        .alert(
            String(localized: "common.error"),
            isPresented: .init(
                get: { viewModel.block != nil && viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(String(localized: "common.ok"), role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
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

    private func processDocumentPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        let fileName = "photo_\(Date.now.timeIntervalSince1970.formatted(.number.grouping(.never))).jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: tempURL)
            // Compression happens in DocumentFileManager.importFile
            viewModel.addDocument(url: tempURL, fileName: fileName, fileType: .image)
        } catch {
            print("[BlockDetail] ❌ Failed to write photo to temp: \(error)")
        }
    }

    // MARK: - Block Content

    @ViewBuilder
    private func blockContent(_ block: Block) -> some View {
        @Bindable var vm = viewModel

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    BlockDetailHeaderView(
                        block: block,
                        canEdit: viewModel.canEditHeader,
                        tripDisplayTimezone: viewModel.tripDisplayTimezone,
                        billSummary: viewModel.billSummary,
                        onEditTap: { showingEditSheet = true }
                    )

                    Divider()

                    // Tab bar
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedStreamTab = .posts
                            }
                        } label: {
                            streamTabIcon("text.bubble", tab: .posts, count: viewModel.posts.count)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        HStack(spacing: 12) {
                            // Contextual add button — left of the tab icons
                            if selectedStreamTab == .bills || selectedStreamTab == .documents {
                                tabAddButton
                                    .transition(.scale.combined(with: .opacity))
                            }

                            streamTabIcon("doc.text", tab: .documents, count: viewModel.documents.count)
                            streamTabIcon("banknote", tab: .bills, count: viewModel.bills.count)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                    // Stream content
                    VStack(spacing: 12) {
                        switch selectedStreamTab {
                        case .posts:
                            postsContent
                        case .bills:
                            billsContent
                        case .documents:
                            documentsContent(block)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
                }
            }
            .onChange(of: viewModel.posts.count) { _, _ in
                if selectedStreamTab == .posts, let last = viewModel.posts.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }

        // Composer — only visible on posts tab
        if selectedStreamTab == .posts {
            PostComposerView(
                onSend: { body, visibility, mediaItems in
                    viewModel.sendPost(body: body, visibility: visibility, mediaItems: mediaItems)
                },
                isSending: viewModel.isSendingPost
            )
        }
    }

    // MARK: - Stream Tab Icon

    @ViewBuilder
    private func streamTabIcon(_ icon: String, tab: StreamTab, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedStreamTab = selectedStreamTab == tab ? .posts : tab
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(selectedStreamTab == tab ? Color.accentColor : .secondary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(selectedStreamTab == tab ? Color.accentColor : Color(.systemGray4), lineWidth: 1.5)
                    )

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(Color.accentColor, in: Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Add Button

    private var addButtonStyle: some View {
        Image(systemName: "plus")
            .font(.subheadline)
            .foregroundStyle(Color.accentColor)
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
    }

    @ViewBuilder
    private var tabAddButton: some View {
        if selectedStreamTab == .bills {
            Button {
                showingBillEntry = true
            } label: {
                addButtonStyle
            }
            .buttonStyle(.plain)
        } else if selectedStreamTab == .documents {
            Menu {
                Button {
                    showingDocumentPhotoPicker = true
                } label: {
                    Label(String(localized: "document.add.photo"), systemImage: "photo")
                }
                Button {
                    showingDocumentPicker = true
                } label: {
                    Label(String(localized: "document.add.file"), systemImage: "doc.badge.plus")
                }
            } label: {
                addButtonStyle
            }
        }
    }

    // MARK: - Stream Content (inline, no nested ScrollView)

    @ViewBuilder
    private var postsContent: some View {
        if viewModel.isLoadingPosts {
            PostSkeletonView()
        } else if viewModel.posts.isEmpty && viewModel.failedDrafts.isEmpty {
            emptyPostsState
        } else {
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

            ForEach(viewModel.failedDrafts) { draft in
                FailedPostCardView(
                    bodyText: draft.body,
                    onRetry: { viewModel.retryDraft(draft) },
                    onDiscard: { viewModel.discardDraft(draft) }
                )
            }
        }
    }

    @ViewBuilder
    private var billsContent: some View {
        if viewModel.bills.isEmpty {
            VStack(spacing: 12) {
                Spacer().frame(height: 40)
                Image(systemName: "banknote")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("block.stream.bills.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    showingBillEntry = true
                } label: {
                    Text("bill.add.button")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .frame(maxWidth: .infinity)
        } else {
            ForEach(viewModel.bills) { bill in
                BillCardView(
                    bill: bill,
                    payerName: viewModel.payerName(for: bill),
                    shareCount: viewModel.billShareCounts[bill.id] ?? 0,
                    isDeleting: viewModel.deletingBillId == bill.id,
                    onTap: { selectedBill = bill }
                )
            }
        }
    }

    @ViewBuilder
    private func documentsContent(_ block: Block) -> some View {
        if viewModel.documents.isEmpty {
            VStack(spacing: 12) {
                Spacer().frame(height: 40)
                Image(systemName: "doc.text")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("block.stream.docs.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Menu {
                    Button {
                        showingDocumentPhotoPicker = true
                    } label: {
                        Label(String(localized: "document.add.photo"), systemImage: "photo")
                    }
                    Button {
                        showingDocumentPicker = true
                    } label: {
                        Label(String(localized: "document.add.file"), systemImage: "doc.badge.plus")
                    }
                } label: {
                    Text("document.add.button")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Color.accentColor)
            }
            .frame(maxWidth: .infinity)
        } else {
            DocumentSectionView(
                documents: viewModel.documents,
                currentUserId: appState.currentUserId,
                tripId: block.tripId,
                onDelete: { viewModel.deleteDocument($0) },
                onRetry: { viewModel.retryDocumentUpload($0) },
                onRename: { doc, name in viewModel.renameDocument(doc, newName: name) }
            )
        }
    }

    // MARK: - Menu

    private var blockMenuButton: some View {
        UIKitMenuButton(
            icon: "ellipsis.circle",
            actions: blockMenuActions
        )
        .frame(width: 28, height: 28)
    }

    private var blockMenuActions: [UIKitMenuButton.MenuAction] {
        var actions: [UIKitMenuButton.MenuAction] = []

        if viewModel.canEditHeader {
            actions.append(.init(String(localized: "block.edit.title"), image: "pencil") {
                showingEditSheet = true
            })
            actions.append(.init(String(localized: "block.delete.button"), image: "trash", isDestructive: true) {
                showingDeleteBlock = true
            })
        }

        return actions
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
