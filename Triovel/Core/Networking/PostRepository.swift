import Foundation
import Supabase

/// Handles post CRUD against Supabase.
/// Will be replaced by PowerSync local-first writes when sync is integrated.
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

        print("[PostRepo] INSERT post: blockId=\(blockId), visibility=\(visibility.rawValue)")

        do {
            let rows: [PostDBRow] = try await client
                .from("posts")
                .insert(params)
                .select()
                .execute()
                .value

            print("[PostRepo] INSERT success, rows: \(rows.count)")

            guard let row = rows.first else {
                throw PostRepositoryError.createFailed
            }

            return row.toDomain()
        } catch {
            print("[PostRepo] ❌ INSERT failed: \(error)")
            throw error
        }
    }

    // MARK: - Fetch Posts for Block

    /// Fetches posts for a block with pagination. Filters private posts to only the current user.
    func fetchPosts(blockId: String, currentUserId: String, limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        print("[PostRepo] SELECT posts for block: \(blockId), limit=\(limit), offset=\(offset)")
        do {
            let rows: [PostDBRow] = try await client
                .from("posts")
                .select()
                .eq("block_id", value: blockId)
                .order("created_at", ascending: true)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value

            print("[PostRepo] SELECT success, rows: \(rows.count)")

            return rows
                .map { $0.toDomain() }
                .filter { post in
                    post.visibility == .shared || post.userId == currentUserId
                }
        } catch {
            print("[PostRepo] ❌ SELECT posts failed: \(error)")
            throw error
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
        print("[PostRepo] DELETE post: \(postId)")
        do {
            try await client
                .from("posts")
                .delete()
                .eq("id", value: postId)
                .execute()
            print("[PostRepo] DELETE success")
        } catch {
            print("[PostRepo] ❌ DELETE failed: \(error)")
            throw error
        }
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
