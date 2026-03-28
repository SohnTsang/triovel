import Foundation
import Observation
import PowerSync

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
    var editTime = Date()

    // Posts
    private(set) var posts: [Post] = []
    private(set) var isLoadingPosts = false
    private(set) var isSendingPost = false
    private(set) var memberNames: [String: String] = [:]

    // Failed posts queue — retryable drafts that didn't send
    var failedDrafts: [FailedDraft] = []

    private var currentUserId: String?
    private var tripOwnerId: String?
    private let blockRepository = BlockRepository()
    private let postRepository = PostRepository()
    nonisolated(unsafe) private var loadTask: Task<Void, Never>?
    nonisolated(unsafe) private var sendTask: Task<Void, Never>?
    nonisolated(unsafe) private var postWatchTask: Task<Void, Never>?

    deinit {
        loadTask?.cancel()
        sendTask?.cancel()
        postWatchTask?.cancel()
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
                    self.posts = posts

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
                    if self.posts.isEmpty {
                        self.errorMessage = String(localized: "post.error.load")
                    }
                }
            }
            if self.isLoadingPosts { self.isLoadingPosts = false }
        }
    }

    // MARK: - Post CRUD

    func sendPost(body: String, visibility: PostVisibility) {
        guard let block, let userId = currentUserId else { return }
        isSendingPost = true

        sendTask?.cancel()
        sendTask = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.postRepository.createPost(
                    blockId: block.id,
                    userId: userId,
                    body: body,
                    visibility: visibility
                )
                // Watch query picks up the new post automatically
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

    func deletePost(_ post: Post) {
        Task { [weak self] in
            guard let self else { return }
            do {
                // Local delete — watch query removes it from UI
                try await self.postRepository.deletePost(postId: post.id)
            } catch {
                print("[BlockDetail] ❌ deletePost failed: \(error)")
            }
        }
    }

    func isOwnPost(_ post: Post) -> Bool {
        post.userId == currentUserId
    }

    func authorName(for post: Post) -> String {
        memberNames[post.userId] ?? String(localized: "post.author.unknown")
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

    func saveHeaderEdits() {
        guard let block else { return }
        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let newLocation = editLocation.trimmingCharacters(in: .whitespaces)
        let newDescription = editDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { [weak self] in
            guard let self else { return }
            do {
                let timeChanged = abs(self.editTime.timeIntervalSince(block.startAt)) > 60

                try await self.blockRepository.updateBlockHeader(
                    blockId: block.id,
                    title: trimmedTitle != block.title ? trimmedTitle : nil,
                    locationText: newLocation != (block.locationText ?? "") ? newLocation : nil,
                    description: newDescription != (block.description ?? "") ? newDescription : nil,
                    startAt: timeChanged ? self.editTime : nil
                )

                self.block?.title = trimmedTitle
                self.block?.locationText = newLocation.isEmpty ? nil : newLocation
                self.block?.description = newDescription.isEmpty ? nil : newDescription
                if timeChanged { self.block?.startAt = self.editTime }
                self.isEditingHeader = false
            } catch {
                self.errorMessage = String(localized: "block.detail.error.save")
            }
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
