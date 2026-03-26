import Foundation

/// ViewModel for BlockDetailView. Fetches block + posts from Supabase,
/// determines edit permissions, handles header edits, and manages post CRUD.
@MainActor
final class BlockDetailViewModel: ObservableObject {
    @Published private(set) var block: Block?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // Edit state
    @Published var isEditingHeader = false
    @Published var editTitle = ""
    @Published var editLocation = ""

    // Posts
    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoadingPosts = false
    @Published private(set) var isSendingPost = false
    @Published private(set) var memberNames: [String: String] = [:]

    // Failed posts queue — retryable drafts that didn't send
    @Published var failedDrafts: [FailedDraft] = []

    private var currentUserId: String?
    private var tripOwnerId: String?
    private let blockRepository = BlockRepository()
    private let postRepository = PostRepository()

    /// Only block creator or trip owner can edit header.
    var canEditHeader: Bool {
        guard let userId = currentUserId, let block else { return false }
        return block.createdBy == userId || tripOwnerId == userId
    }

    // MARK: - Load

    func load(blockId: String, userId: String) async {
        currentUserId = userId
        isLoading = true
        errorMessage = nil

        do {
            let fetchedBlock = try await blockRepository.fetchBlock(blockId: blockId)
            self.block = fetchedBlock

            // Fetch trip to determine owner + member names
            let trip = try await blockRepository.fetchTrip(tripId: fetchedBlock.tripId)
            self.tripOwnerId = trip.createdBy

            // Fetch member names for display
            await loadMemberNames(tripId: fetchedBlock.tripId)
        } catch {
            errorMessage = String(localized: "block.detail.error.load")
        }

        isLoading = false

        // Load posts after block loads
        await loadPosts()
    }

    /// Load directly from a block we already have (e.g. after creation).
    func loadDirect(block: Block, userId: String, tripOwnerId: String?) {
        self.block = block
        self.currentUserId = userId
        self.tripOwnerId = tripOwnerId
        self.isLoading = false

        Task { await loadPosts() }
    }

    // MARK: - Posts

    func loadPosts() async {
        guard let block, let userId = currentUserId else { return }
        isLoadingPosts = posts.isEmpty

        do {
            let fetched = try await postRepository.fetchPosts(
                blockId: block.id,
                currentUserId: userId
            )
            self.posts = fetched
        } catch {
            if posts.isEmpty {
                errorMessage = String(localized: "post.error.load")
            }
        }

        isLoadingPosts = false
    }

    func sendPost(body: String, visibility: PostVisibility) {
        guard let block, let userId = currentUserId else { return }
        isSendingPost = true

        Task {
            do {
                let post = try await postRepository.createPost(
                    blockId: block.id,
                    userId: userId,
                    body: body,
                    visibility: visibility
                )
                posts.append(post)
            } catch {
                // Add to failed drafts for retry
                failedDrafts.append(FailedDraft(
                    body: body,
                    visibility: visibility
                ))
            }
            isSendingPost = false
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

        Task {
            do {
                try await postRepository.deletePost(postId: post.id)
            } catch {
                // Re-add on failure
                posts.append(post)
                posts.sort { $0.createdAt < $1.createdAt }
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

        Task {
            do {
                try await blockRepository.updateBlockHeader(
                    blockId: block.id,
                    title: trimmedTitle != block.title ? trimmedTitle : nil,
                    locationText: newLocation != (block.locationText ?? "") ? newLocation : nil,
                    startAt: nil
                )

                // Update local state optimistically
                self.block?.title = trimmedTitle
                self.block?.locationText = newLocation.isEmpty ? nil : newLocation
                isEditingHeader = false
            } catch {
                errorMessage = String(localized: "block.detail.error.save")
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
