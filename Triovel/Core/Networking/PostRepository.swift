import Foundation
import PowerSync

/// Reads posts from local PowerSync SQLite. Writes locally first.
/// Private posts are filtered server-side by sync rules AND client-side as defense-in-depth.
final class PostRepository {
    private var db: PowerSyncDatabaseProtocol { SyncManager.shared.db }

    // MARK: - Create Post (local-first)

    func createPost(
        blockId: String,
        tripId: String,
        userId: String,
        body: String,
        visibility: PostVisibility
    ) async throws -> Post {
        let postId = UUID().uuidString.lowercased()
        let now = Self.isoString(from: Date())

        try await db.execute(
            sql: """
                INSERT INTO posts (id, block_id, trip_id, user_id, body, visibility, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
            parameters: [postId, blockId, tripId, userId, body, visibility.rawValue, now]
        )

        print("[PostRepo] Created post locally: \(postId)")
        BetaAnalytics.trackPostCreated(visibility: visibility.rawValue)

        return Post(
            id: postId,
            blockId: blockId,
            userId: userId,
            body: body,
            visibility: visibility,
            createdAt: Date()
        )
    }

    // MARK: - Fetch Posts (local read)

    func fetchPosts(blockId: String, currentUserId: String, limit: Int = 100, offset: Int = 0) async throws -> [Post] {
        try await db.getAll(
            sql: """
                SELECT * FROM posts
                WHERE block_id = ?
                  AND (visibility = 'shared' OR user_id = ?)
                ORDER BY created_at ASC
                LIMIT ? OFFSET ?
                """,
            parameters: [blockId, currentUserId, limit, offset],
            mapper: Self.postMapper
        )
    }

    /// Reactive stream of posts for a block.
    func watchPosts(blockId: String, currentUserId: String) throws -> AsyncThrowingStream<[Post], Error> {
        try db.watch(
            sql: """
                SELECT * FROM posts
                WHERE block_id = ?
                  AND (visibility = 'shared' OR user_id = ?)
                ORDER BY created_at ASC
                """,
            parameters: [blockId, currentUserId],
            mapper: Self.postMapper
        )
    }

    // MARK: - Update Post (local-first)

    func updatePost(postId: String, body: String) async throws {
        try await db.execute(
            sql: "UPDATE posts SET body = ? WHERE id = ?",
            parameters: [body, postId]
        )
    }

    // MARK: - Delete Post (local-first)

    func deletePost(postId: String) async throws {
        try await db.execute(
            sql: "DELETE FROM posts WHERE id = ?",
            parameters: [postId]
        )
        print("[PostRepo] Deleted post locally: \(postId)")
    }

    // MARK: - Mapper

    static let postMapper: @Sendable (SqlCursor) throws -> Post = { cursor in
        let createdAtStr = try cursor.getString(name: "created_at")
        return Post(
            id: try cursor.getString(name: "id"),
            blockId: try cursor.getString(name: "block_id"),
            userId: try cursor.getString(name: "user_id"),
            body: try cursor.getStringOptional(name: "body"),
            visibility: PostVisibility(rawValue: try cursor.getString(name: "visibility")) ?? .shared,
            createdAt: parseISO(createdAtStr)
        )
    }

    // MARK: - Helpers

    private static func isoString(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
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

private func parseISO(_ str: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: str) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: str) ?? Date()
}
