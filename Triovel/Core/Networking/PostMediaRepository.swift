import Foundation
import PowerSync

/// CRUD for post_media records in local PowerSync SQLite.
final class PostMediaRepository {
    private var db: PowerSyncDatabaseProtocol { SyncManager.shared.db }

    // MARK: - Create

    func createPostMedia(
        postId: String,
        mediaType: MediaType,
        tripId: String
    ) async throws -> PostMedia {
        let mediaId = UUID().uuidString.lowercased()
        let now = Self.isoString(from: Date())

        try await db.execute(
            sql: """
                INSERT INTO post_media (id, post_id, media_type, upload_status, created_at)
                VALUES (?, ?, ?, 'queued', ?)
                """,
            parameters: [mediaId, postId, mediaType.rawValue, now]
        )

        print("[PostMediaRepo] Created post_media: \(mediaId), type: \(mediaType.rawValue)")

        return PostMedia(
            id: mediaId,
            postId: postId,
            storagePath: nil,
            mediaType: mediaType,
            uploadStatus: .queued,
            thumbnailPath: nil,
            createdAt: Date()
        )
    }

    // MARK: - Update Status

    func updateUploadStatus(mediaId: String, status: UploadStatus) async throws {
        try await db.execute(
            sql: "UPDATE post_media SET upload_status = ? WHERE id = ?",
            parameters: [status.rawValue, mediaId]
        )
    }

    func updateStoragePath(mediaId: String, storagePath: String, thumbnailPath: String?) async throws {
        try await db.execute(
            sql: "UPDATE post_media SET storage_path = ?, thumbnail_path = ?, upload_status = 'uploaded' WHERE id = ?",
            parameters: [storagePath, thumbnailPath, mediaId]
        )
    }

    // MARK: - Fetch

    func fetchMediaForPost(postId: String) async throws -> [PostMedia] {
        try await db.getAll(
            sql: "SELECT * FROM post_media WHERE post_id = ? ORDER BY created_at ASC",
            parameters: [postId],
            mapper: Self.postMediaMapper
        )
    }

    /// Reactive stream of all media for posts in a block.
    func watchMediaForBlock(blockId: String) throws -> AsyncThrowingStream<[PostMedia], Error> {
        try db.watch(
            sql: """
                SELECT pm.* FROM post_media pm
                JOIN posts p ON pm.post_id = p.id
                WHERE p.block_id = ?
                ORDER BY pm.created_at ASC
                """,
            parameters: [blockId],
            mapper: Self.postMediaMapper
        )
    }

    /// All items pending upload (queued or failed).
    func fetchPendingUploads() async throws -> [PostMedia] {
        try await db.getAll(
            sql: "SELECT * FROM post_media WHERE upload_status IN ('queued', 'failed') ORDER BY created_at ASC",
            parameters: nil,
            mapper: Self.postMediaMapper
        )
    }

    // MARK: - Mapper

    static let postMediaMapper: @Sendable (SqlCursor) throws -> PostMedia = { cursor in
        let createdAtStr = try cursor.getString(name: "created_at")
        return PostMedia(
            id: try cursor.getString(name: "id"),
            postId: try cursor.getString(name: "post_id"),
            storagePath: try cursor.getStringOptional(name: "storage_path"),
            mediaType: MediaType(rawValue: try cursor.getString(name: "media_type")) ?? .photo,
            uploadStatus: UploadStatus(rawValue: try cursor.getString(name: "upload_status")) ?? .queued,
            thumbnailPath: try cursor.getStringOptional(name: "thumbnail_path"),
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

private func parseISO(_ str: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: str) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: str) ?? Date()
}
