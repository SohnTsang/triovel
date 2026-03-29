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

    // Edit state
    var isEditingHeader = false
    var editTitle = ""
    var editLocation = ""
    var editDescription = ""
    var editStartAt = Date()

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
    nonisolated(unsafe) private var loadTask: Task<Void, Never>?
    nonisolated(unsafe) private var sendTask: Task<Void, Never>?
    nonisolated(unsafe) private var postWatchTask: Task<Void, Never>?
    nonisolated(unsafe) private var mediaWatchTask: Task<Void, Never>?

    deinit {
        loadTask?.cancel()
        sendTask?.cancel()
        postWatchTask?.cancel()
        mediaWatchTask?.cancel()
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
                try? await Task.sleep(for: .milliseconds(500))
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

    private(set) var deletingPostId: String?

    func deletePost(_ post: Post) {
        deletingPostId = post.id

        Task { [weak self] in
            guard let self else { return }

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
            try? await Task.sleep(for: .milliseconds(500))
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
                let stream = try self.postMediaRepository.watchMediaForBlock(blockId: blockId)
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

    func saveHeaderEdits() {
        guard let block else { return }
        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let newLocation = editLocation.trimmingCharacters(in: .whitespaces)
        let newDescription = editDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let timeChanged = abs(editStartAt.timeIntervalSince(block.startAt)) > 60
        isSavingHeader = true

        Task { [weak self] in
            guard let self else { return }

            do {
                // Write to DB immediately (offline-safe)
                try await self.blockRepository.updateBlockHeader(
                    blockId: block.id,
                    title: trimmedTitle != block.title ? trimmedTitle : nil,
                    locationText: newLocation != (block.locationText ?? "") ? newLocation : nil,
                    description: newDescription != (block.description ?? "") ? newDescription : nil,
                    startAt: timeChanged ? self.editStartAt : nil
                )

                // 500ms minimum spinner, then update UI
                try? await Task.sleep(for: .milliseconds(500))

                self.block?.title = trimmedTitle
                self.block?.locationText = newLocation.isEmpty ? nil : newLocation
                self.block?.description = newDescription.isEmpty ? nil : newDescription
                if timeChanged { self.block?.startAt = self.editStartAt }
                self.isEditingHeader = false
            } catch {
                self.errorMessage = String(localized: "block.detail.error.save")
            }

            self.isSavingHeader = false
        }
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
