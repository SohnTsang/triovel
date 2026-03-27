import Foundation
import Observation

/// ViewModel for BlockDetailView. Fetches block + posts from Supabase,
/// determines edit permissions, handles header edits, and manages post CRUD.
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

    deinit {
        loadTask?.cancel()
        sendTask?.cancel()
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
            print("[BlockDetail] Trip loaded: \(trip.title)")

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

        await loadPosts()
    }

    /// Load directly from a block we already have (e.g. after creation).
    func loadDirect(block: Block, userId: String, tripOwnerId: String?) {
        self.block = block
        self.currentUserId = userId
        self.tripOwnerId = tripOwnerId
        self.isLoading = false

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.loadPosts()
        }
    }

    // MARK: - Posts

    func loadPosts() async {
        guard let block, let userId = currentUserId else {
            print("[BlockDetail] Skipping loadPosts — block=\(block != nil), userId=\(currentUserId ?? "nil")")
            return
        }

        let showSkeleton = posts.isEmpty
        if showSkeleton { isLoadingPosts = true }
        let start = ContinuousClock.now

        do {
            let fetched = try await postRepository.fetchPosts(
                blockId: block.id,
                currentUserId: userId
            )
            self.posts = fetched
            print("[BlockDetail] Posts loaded: \(fetched.count)")
        } catch {
            print("[BlockDetail] ❌ loadPosts failed: \(error)")
            if posts.isEmpty {
                errorMessage = String(localized: "post.error.load")
            }
        }

        if showSkeleton {
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }
        }
        isLoadingPosts = false
    }

    func sendPost(body: String, visibility: PostVisibility) {
        guard let block, let userId = currentUserId else { return }
        isSendingPost = true

        sendTask?.cancel()
        sendTask = Task { [weak self] in
            guard let self else { return }
            do {
                let post = try await self.postRepository.createPost(
                    blockId: block.id,
                    userId: userId,
                    body: body,
                    visibility: visibility
                )
                self.posts.append(post)
                print("[BlockDetail] Post sent: \(post.id)")
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
        // Optimistic removal
        posts.removeAll { $0.id == post.id }

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.postRepository.deletePost(postId: post.id)
            } catch {
                // Re-add on failure
                self.posts.append(post)
                self.posts.sort { $0.createdAt < $1.createdAt }
            }
        }
    }

    func isOwnPost(_ post: Post) -> Bool {
        post.userId == currentUserId
    }

    func authorName(for post: Post) -> String {
        memberNames[post.userId] ?? String(localized: "post.author.unknown")
    }

    // MARK: - Member Names

    private func loadMemberNames(tripId: String) async {
        do {
            let client = SupabaseConfig.client
            let rows: [MemberNameRow] = try await client
                .from("trip_members")
                .select("user_id, users(display_name)")
                .eq("trip_id", value: tripId)
                .execute()
                .value

            var names: [String: String] = [:]
            for row in rows {
                names[row.user_id] = row.users.display_name
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

        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.blockRepository.updateBlockHeader(
                    blockId: block.id,
                    title: trimmedTitle != block.title ? trimmedTitle : nil,
                    locationText: newLocation != (block.locationText ?? "") ? newLocation : nil,
                    startAt: nil
                )

                self.block?.title = trimmedTitle
                self.block?.locationText = newLocation.isEmpty ? nil : newLocation
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

// MARK: - Member Name DTO

import Supabase

private struct MemberNameRow: Decodable {
    let user_id: String
    let users: UserName

    struct UserName: Decodable {
        let display_name: String
    }
}
