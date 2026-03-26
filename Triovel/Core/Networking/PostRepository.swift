import Foundation
import Supabase

/// Handles post CRUD against Supabase.
/// Will be replaced by PowerSync local-first writes when sync is integrated.
@MainActor
final class PostRepository {
    private let client = SupabaseConfig.client

    // MARK: - Create Post

    func createPost(
        blockId: String,
        userId: String,
        body: String,
        visibility: PostVisibility
    ) async throws -> Post {
        let params = CreatePostParams(
            block_id: blockId,
            user_id: userId,
            body: body,
            visibility: visibility.rawValue
        )

        let rows: [PostDBRow] = try await client
            .from("posts")
            .insert(params)
            .select()
            .execute()
            .value

        guard let row = rows.first else {
            throw PostRepositoryError.createFailed
        }

        return row.toDomain()
    }

    // MARK: - Fetch Posts for Block

    /// Fetches posts for a block. Filters private posts to only the current user.
    func fetchPosts(blockId: String, currentUserId: String) async throws -> [Post] {
        // Fetch all shared posts + only this user's private posts
        // RLS should enforce this server-side, but we double-check client-side
        let rows: [PostDBRow] = try await client
            .from("posts")
            .select()
            .eq("block_id", value: blockId)
            .order("created_at", ascending: true)
            .execute()
            .value

        return rows
            .map { $0.toDomain() }
            .filter { post in
                post.visibility == .shared || post.userId == currentUserId
            }
    }

    // MARK: - Update Post

    func updatePost(postId: String, body: String) async throws {
        try await client
            .from("posts")
            .update(["body": body])
            .eq("id", value: postId)
            .execute()
    }

    // MARK: - Delete Post

    func deletePost(postId: String) async throws {
        try await client
            .from("posts")
            .delete()
            .eq("id", value: postId)
            .execute()
    }
}

// MARK: - Error

enum PostRepositoryError: LocalizedError {
    case createFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .createFailed: return "Failed to create post."
        case .notFound: return "Post not found."
        }
    }
}

// MARK: - DTOs

private struct CreatePostParams: Encodable {
    let block_id: String
    let user_id: String
    let body: String
    let visibility: String
}

private struct PostDBRow: Decodable {
    let id: String
    let block_id: String
    let user_id: String
    let body: String?
    let visibility: String
    let created_at: String

    func toDomain() -> Post {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        let date = isoFormatter.date(from: created_at)
            ?? isoBasic.date(from: created_at)
            ?? Date()

        return Post(
            id: id,
            blockId: block_id,
            userId: user_id,
            body: body,
            visibility: PostVisibility(rawValue: visibility) ?? .shared,
            createdAt: date
        )
    }
}
