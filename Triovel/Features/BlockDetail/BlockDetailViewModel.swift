import Foundation
import Observation
import PowerSync
import Supabase

/// ViewModel for BlockDetailView. Reads block + posts from local SQLite,
/// determines edit permissions, handles header edits, and manages post CRUD.
/// Posts are watched reactively — new posts appear instantly after local write.
@Observable
@MainActor
final class BlockDetailViewModel {
    private(set) var block: Block?
    private(set) var isLoading = false
    var errorMessage: String?

    // Posts
    private var allPosts: [Post] = []
    private(set) var isLoadingPosts = false
    private(set) var isSendingPost = false
    private(set) var memberNames: [String: String] = [:]

    // Pending IDs: written to DB but hidden from UI until 500ms loading finishes
    private var pendingPostIds: Set<String> = []

    /// Posts visible in the UI — filters out pending (not yet revealed) posts
    var posts: [Post] {
        allPosts.filter { !pendingPostIds.contains($0.id) }
    }

    // Media
    private(set) var postMediaMap: [String: [PostMedia]] = [:]

    // Failed posts queue — retryable drafts that didn't send
    var failedDrafts: [FailedDraft] = []

    private var currentUserId: String?
    private var tripOwnerId: String?
    private let blockRepository = BlockRepository()
    private let postRepository = PostRepository()
    private let postMediaRepository = PostMediaRepository()
    private let billRepository = BillRepository()

    // Bills in this block
    private(set) var bills: [Bill] = []
    private(set) var billShareCounts: [String: Int] = [:]
    private(set) var billSharesMap: [String: [BillShare]] = [:]
    private(set) var tripPayments: [Payment] = []
    private let paymentRepository = PaymentRepository()

    // Documents
    private(set) var documents: [BlockDocument] = []
    private(set) var deletingDocId: String?
    private let documentRepository = BlockDocumentRepository()

    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var sendTask: Task<Void, Never>?
    @ObservationIgnored private var postWatchTask: Task<Void, Never>?
    @ObservationIgnored private var mediaWatchTask: Task<Void, Never>?
    @ObservationIgnored private var billWatchTask: Task<Void, Never>?
    @ObservationIgnored private var docWatchTask: Task<Void, Never>?

    deinit {
        loadTask?.cancel()
        sendTask?.cancel()
        postWatchTask?.cancel()
        mediaWatchTask?.cancel()
        billWatchTask?.cancel()
        docWatchTask?.cancel()
    }

    /// Only block creator or trip owner can edit header.
    var canEditHeader: Bool {
        guard let userId = currentUserId, let block else { return false }
        return block.createdBy == userId || tripOwnerId == userId
    }

    // MARK: - Load

    func load(blockId: String, userId: String) async {
        currentUserId = userId
        errorMessage = nil

        let showLoading = block == nil
        if showLoading {
            isLoading = true
            isLoadingPosts = true
        }
        let start = ContinuousClock.now

        print("[BlockDetail] Loading block: \(blockId), userId: \(userId)")

        do {
            let fetchedBlock = try await blockRepository.fetchBlock(blockId: blockId)
            self.block = fetchedBlock
            print("[BlockDetail] Block loaded: \(fetchedBlock.title)")

            let trip = try await blockRepository.fetchTrip(tripId: fetchedBlock.tripId)
            self.tripOwnerId = trip.createdBy
            self.tripBaseCurrency = trip.baseCurrency
            self.tripDisplayTimezone = trip.displayTimezone
            self.tripStartDate = trip.startDate
            self.tripEndDate = trip.endDate
            self.tripPayments = (try? await self.paymentRepository.fetchPaymentsForTrip(tripId: fetchedBlock.tripId)) ?? []

            await loadMemberNames(tripId: fetchedBlock.tripId)
        } catch {
            print("[BlockDetail] ❌ Load failed: \(error)")
            errorMessage = String(localized: "block.detail.error.load")
        }

        if showLoading {
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }
        }
        isLoading = false

        // Start reactive post watching
        startWatchingPosts(blockId: blockId, userId: userId)
    }

    /// Load directly from a block we already have (e.g. after creation).
    func loadDirect(block: Block, userId: String, tripOwnerId: String?) {
        self.block = block
        self.currentUserId = userId
        self.tripOwnerId = tripOwnerId
        self.isLoading = false

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.loadMemberNames(tripId: block.tripId)
            self.startWatchingPosts(blockId: block.id, userId: userId)
        }
    }

    // MARK: - Post Watch

    private func startWatchingPosts(blockId: String, userId: String) {
        // Start media watch alongside posts
        startWatchingMedia(blockId: blockId)
        startWatchingBills(blockId: blockId)
        startWatchingDocuments(blockId: blockId)

        postWatchTask?.cancel()
        postWatchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = try self.postRepository.watchPosts(
                    blockId: blockId,
                    currentUserId: userId
                )
                var isFirst = true
                let start = ContinuousClock.now

                for try await posts in stream {
                    guard !Task.isCancelled else { break }
                    self.allPosts = posts

                    if isFirst && self.isLoadingPosts {
                        let elapsed = ContinuousClock.now - start
                        if elapsed < .milliseconds(500) {
                            try? await Task.sleep(for: .milliseconds(500) - elapsed)
                        }
                        self.isLoadingPosts = false
                        isFirst = false
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    print("[BlockDetail] ❌ Post watch error: \(error)")
                    if self.allPosts.isEmpty {
                        self.errorMessage = String(localized: "post.error.load")
                    }
                }
            }
            if self.isLoadingPosts { self.isLoadingPosts = false }
        }
    }

    // MARK: - Post CRUD

    func sendPost(body: String, visibility: PostVisibility, mediaItems: [MediaItem] = []) {
        guard let block, let userId = currentUserId else { return }
        isSendingPost = true

        sendTask?.cancel()
        sendTask = Task { [weak self] in
            guard let self else { return }
            let start = ContinuousClock.now

            do {
                // Write to DB immediately (offline-safe, survives app kill)
                let post = try await self.postRepository.createPost(
                    blockId: block.id,
                    tripId: block.tripId,
                    userId: userId,
                    body: body,
                    visibility: visibility
                )

                // Hide from UI until 500ms loading finishes
                self.pendingPostIds.insert(post.id)

                // Enqueue media for upload
                for item in mediaItems {
                    do {
                        _ = try await MediaUploadQueue.shared.enqueue(
                            mediaItem: item,
                            postId: post.id,
                            tripId: block.tripId
                        )
                    } catch {
                        print("[BlockDetail] ❌ Media enqueue failed: \(error)")
                    }
                }

                // 500ms minimum spinner, then reveal
                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
                self.pendingPostIds.remove(post.id)
            } catch {
                print("[BlockDetail] ❌ sendPost failed: \(error)")
                self.failedDrafts.append(FailedDraft(
                    body: body,
                    visibility: visibility
                ))
            }

            self.isSendingPost = false
        }
    }

    func retryDraft(_ draft: FailedDraft) {
        failedDrafts.removeAll { $0.id == draft.id }
        sendPost(body: draft.body, visibility: draft.visibility)
    }

    func discardDraft(_ draft: FailedDraft) {
        failedDrafts.removeAll { $0.id == draft.id }
    }

    func editPost(_ post: Post, newBody: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.postRepository.updatePost(postId: post.id, body: newBody)
                print("[BlockDetail] Edited post: \(post.id)")
            } catch {
                print("[BlockDetail] ❌ Edit post failed: \(error)")
            }
        }
    }

    /// Delete a single media item from a post. Cleans up storage + local files.
    func deleteMedia(mediaId: String, post: Post) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let media = try await self.postMediaRepository.fetchMediaForPost(postId: post.id)
                guard let item = media.first(where: { $0.id == mediaId }) else { return }

                // Delete from local DB
                let db = SyncManager.shared.db
                try await db.execute(
                    sql: "DELETE FROM post_media WHERE id = ?",
                    parameters: [mediaId]
                )

                // Clean up Supabase Storage
                let ext = item.mediaType == .photo ? "jpg" : "mp4"
                let storagePath = "posts/\(post.id)/\(mediaId).\(ext)"
                do {
                    _ = try await SupabaseConfig.client.storage
                        .from("trip-media")
                        .remove(paths: [storagePath])
                } catch {
                    print("[BlockDetail] ⚠️ Media storage cleanup failed: \(error)")
                }

                // Clean up local files
                MediaFileManager.deleteLocalFiles(for: mediaId, type: item.mediaType)
                print("[BlockDetail] Deleted media: \(mediaId)")
            } catch {
                print("[BlockDetail] ❌ Delete media failed: \(error)")
            }
        }
    }

    private(set) var deletingPostId: String?

    func deletePost(_ post: Post) {
        deletingPostId = post.id

        Task { [weak self] in
            guard let self else { return }
            let start = ContinuousClock.now

            do {
                // 1. Fetch media before deleting
                let media = try await self.postMediaRepository.fetchMediaForPost(postId: post.id)

                // 2. Delete from DB immediately (offline-safe)
                try await self.postRepository.deletePost(postId: post.id)

                // 3. Clean up storage files (deterministic paths, no orphans)
                if !media.isEmpty {
                    let storagePaths = media.map { item in
                        let ext = item.mediaType == .photo ? "jpg" : "mp4"
                        return "posts/\(post.id)/\(item.id).\(ext)"
                    }
                    do {
                        _ = try await SupabaseConfig.client.storage
                            .from("trip-media")
                            .remove(paths: storagePaths)
                        print("[BlockDetail] Deleted \(storagePaths.count) storage files")
                    } catch {
                        print("[BlockDetail] ⚠️ Storage cleanup failed: \(error)")
                    }

                    // 4. Delete local files
                    for item in media {
                        MediaFileManager.deleteLocalFiles(for: item.id, type: item.mediaType)
                    }
                }
            } catch {
                print("[BlockDetail] ❌ deletePost failed: \(error)")
            }

            // 500ms minimum spinner on the card, then it disappears
            // (the watch already removed it from allPosts, but deletingPostId
            // kept the spinner showing — now we clear it)
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }
            self.deletingPostId = nil
        }
    }

    func isOwnPost(_ post: Post) -> Bool {
        post.userId == currentUserId
    }

    func authorName(for post: Post) -> String {
        memberNames[post.userId] ?? String(localized: "post.author.unknown")
    }

    func mediaItems(for postId: String) -> [PostMedia] {
        postMediaMap[postId] ?? []
    }

    func retryMediaUpload(mediaId: String) {
        Task {
            await MediaUploadQueue.shared.retryUpload(mediaId: mediaId)
        }
    }

    // MARK: - Media Watch

    private func startWatchingMedia(blockId: String) {
        mediaWatchTask?.cancel()
        mediaWatchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let userId = self.currentUserId ?? ""
                let stream = try self.postMediaRepository.watchMediaForBlock(blockId: blockId, currentUserId: userId)
                for try await allMedia in stream {
                    guard !Task.isCancelled else { break }
                    var map: [String: [PostMedia]] = [:]
                    for item in allMedia {
                        map[item.postId, default: []].append(item)
                    }
                    self.postMediaMap = map
                }
            } catch {
                if !(error is CancellationError) {
                    print("[BlockDetail] ❌ Media watch error: \(error)")
                }
            }
        }
    }

    // MARK: - Bill Watch

    private func startWatchingBills(blockId: String) {
        billWatchTask?.cancel()
        billWatchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = try self.billRepository.watchBillsForBlock(blockId: blockId)
                for try await bills in stream {
                    guard !Task.isCancelled else { break }
                    self.bills = bills

                    // Fetch shares for display + detail
                    var counts: [String: Int] = [:]
                    var sharesMap: [String: [BillShare]] = [:]
                    for bill in bills {
                        let shares = try await self.billRepository.fetchSharesForBill(billId: bill.id)
                        counts[bill.id] = shares.count
                        sharesMap[bill.id] = shares
                    }
                    self.billShareCounts = counts
                    self.billSharesMap = sharesMap
                }
            } catch {
                if !(error is CancellationError) {
                    print("[BlockDetail] ❌ Bill watch error: \(error)")
                }
            }
        }
    }

    // MARK: - Documents

    private func startWatchingDocuments(blockId: String) {
        docWatchTask?.cancel()
        docWatchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = try self.documentRepository.watchDocuments(blockId: blockId)
                for try await docs in stream {
                    guard !Task.isCancelled else { break }
                    self.documents = docs
                }
            } catch {
                if !(error is CancellationError) {
                    print("[BlockDetail] ❌ Document watch error: \(error)")
                }
            }
        }
    }

    func addDocument(url: URL, fileName: String, fileType: DocumentFileType) {
        guard let block, let userId = currentUserId else { return }

        Task { [weak self] in
            guard let self else { return }

            // 1. Pre-generate ID so import goes to the right directory
            let docId = UUID().uuidString.lowercased()

            // 2. Import file to local storage first (validates size)
            let fileSize: Int
            do {
                fileSize = try await DocumentFileManager.shared.importFile(
                    from: url, docId: docId, fileName: fileName
                )
            } catch let error as DocumentError {
                self.errorMessage = error.errorDescription
                return
            } catch {
                self.errorMessage = String(localized: "document.error.generic")
                return
            }

            // 3. Create DB record (appears in UI immediately via watch)
            let doc: BlockDocument
            do {
                doc = try await self.documentRepository.createDocument(
                    id: docId,
                    blockId: block.id,
                    userId: userId,
                    fileName: fileName,
                    fileType: fileType,
                    fileSize: fileSize
                )
            } catch {
                print("[BlockDetail] ❌ createDocument failed: \(error)")
                await DocumentFileManager.shared.deleteLocalFiles(docId: docId)
                self.errorMessage = String(localized: "document.error.generic")
                return
            }

            // 4. Upload (non-blocking — card shows "uploading" status)
            do {
                try await DocumentFileManager.shared.upload(
                    docId: doc.id, fileName: fileName, tripId: block.tripId
                )
            } catch {
                // Upload failed — card stays with "failed" status + retry button.
                // Don't delete the record — user can retry later or it uploads
                // when back online.
                print("[BlockDetail] ⚠️ Upload failed, will retry: \(error)")
            }
        }
    }

    func deleteDocument(_ doc: BlockDocument) {
        deletingDocId = doc.id

        Task { [weak self] in
            guard let self else { return }
            let start = ContinuousClock.now
            do {
                try await self.documentRepository.deleteDocument(docId: doc.id)
                await DocumentFileManager.shared.deleteDocument(
                    docId: doc.id, storagePath: doc.storagePath
                )
            } catch {
                print("[BlockDetail] ❌ deleteDocument failed: \(error)")
            }
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }
            self.deletingDocId = nil
        }
    }

    func retryDocumentUpload(_ doc: BlockDocument) {
        guard let block else { return }
        Task {
            await DocumentFileManager.shared.retryUpload(
                docId: doc.id, fileName: doc.fileName, tripId: block.tripId
            )
        }
    }

    /// Bill total summary for header badge (e.g. "¥12,000")
    var billSummary: String? {
        guard !bills.isEmpty else { return nil }
        // Group by currency, show each total
        var totals: [String: Int] = [:]
        for bill in bills { totals[bill.currency, default: 0] += bill.amount }
        return totals.map { $0.value.formattedCurrency($0.key) }.joined(separator: " + ")
    }

    func payerName(for bill: Bill) -> String {
        memberNames[bill.payerId] ?? String(localized: "post.author.unknown")
    }

    /// All trip members — used by BillEntryView for the member checklist.
    var allMembers: [TripMemberDisplay] {
        memberNames.map { userId, name in
            TripMemberDisplay(userId: userId, displayName: name, avatarPath: nil)
        }
    }

    /// Trip base currency — set during load from the trip record.
    private(set) var tripBaseCurrency: String = "USD"

    /// Trip display timezone — set during load from the trip record.
    private(set) var tripDisplayTimezone: String = TimeZone.current.identifier
    private(set) var tripStartDate: Date = Date()
    private(set) var tripEndDate: Date = Date()

    /// Bill share displays for the detail view.
    func billShareDisplays(for billId: String) -> [BillShareDisplay] {
        guard let shares = billSharesMap[billId] else { return [] }
        return shares.map { share in
            BillShareDisplay(
                id: share.id,
                userId: share.userId,
                displayName: memberNames[share.userId] ?? String(localized: "post.author.unknown"),
                shareAmount: share.shareAmount
            )
        }
    }

    private(set) var deletingBillId: String?

    func deleteBill(_ bill: Bill) {
        deletingBillId = bill.id

        Task { [weak self] in
            guard let self else { return }
            let start = ContinuousClock.now
            do {
                // Write immediately (offline-safe)
                try await self.billRepository.deleteBill(billId: bill.id)
            } catch {
                print("[BlockDetail] ❌ deleteBill failed: \(error)")
            }

            // 500ms minimum spinner on card
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }
            self.deletingBillId = nil
        }
    }

    // MARK: - Member Names (local read)

    private func loadMemberNames(tripId: String) async {
        let db = SyncManager.shared.db
        do {
            let rows = try await db.getAll(
                sql: """
                    SELECT tm.user_id, u.display_name
                    FROM trip_members tm
                    JOIN users u ON tm.user_id = u.id
                    WHERE tm.trip_id = ?
                    """,
                parameters: [tripId],
                mapper: MemberNameEntry.from
            )
            var names: [String: String] = [:]
            for row in rows {
                names[row.userId] = row.displayName
            }
            self.memberNames = names
        } catch {
            // Non-critical — posts still display, just without names
        }
    }

    // MARK: - Save Header Edits

    private(set) var isSavingHeader = false

    /// Called from EditBlockSheet with the new field values.
    /// Async so the sheet can await completion before dismissing.
    func applyEditFields(_ fields: EditBlockFields) async {
        guard let block else { return }

        let timeChanged = abs(fields.startAt.timeIntervalSince(block.startAt)) > 60
        let endAtChanged = fields.endAt != block.endAt
        let localTzChanged = fields.localTimezone != block.localTimezone
        isSavingHeader = true
        let start = ContinuousClock.now

        do {
            try await blockRepository.updateBlockHeader(
                blockId: block.id,
                title: fields.title != block.title ? fields.title : nil,
                locationText: fields.location != (block.locationText ?? "") ? fields.location : nil,
                description: fields.description != (block.description ?? "") ? fields.description : nil,
                startAt: timeChanged ? fields.startAt : nil,
                endAt: endAtChanged ? .some(fields.endAt) : nil,
                localTimezone: localTzChanged ? .some(fields.localTimezone) : nil
            )

            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }

            self.block?.title = fields.title
            self.block?.locationText = fields.location.isEmpty ? nil : fields.location
            self.block?.description = fields.description.isEmpty ? nil : fields.description
            if timeChanged { self.block?.startAt = fields.startAt }
            if endAtChanged { self.block?.endAt = fields.endAt }
            if localTzChanged { self.block?.localTimezone = fields.localTimezone }
        } catch {
            self.errorMessage = String(localized: "block.detail.error.save")
        }

        isSavingHeader = false
    }
}

// MARK: - Failed Draft

struct FailedDraft: Identifiable {
    let id = UUID()
    let body: String
    let visibility: PostVisibility
}

// MARK: - Member Name Entry

private struct MemberNameEntry: Sendable {
    let userId: String
    let displayName: String

    static let from: @Sendable (SqlCursor) throws -> MemberNameEntry = { cursor in
        MemberNameEntry(
            userId: try cursor.getString(name: "user_id"),
            displayName: try cursor.getString(name: "display_name")
        )
    }
}
