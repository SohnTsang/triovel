import Foundation
import PowerSync
import Supabase

/// Reads blocks from local PowerSync SQLite. Writes locally first.
final class BlockRepository: @unchecked Sendable {
    private var db: PowerSyncDatabaseProtocol { SyncManager.shared.db }

    // MARK: - Create Block (local-first)

    func createBlock(
        id: String? = nil,
        tripId: String,
        title: String,
        context: BlockContext,
        startAt: Date,
        endAt: Date? = nil,
        displayTimezone: String,
        localTimezone: String? = nil,
        createdBy: String
    ) async throws -> Block {
        let blockId = id ?? UUID().uuidString.lowercased()
        let isoStartAt = Self.isoString(from: startAt)
        let isoEndAt = endAt.map { Self.isoString(from: $0) }
        let now = Self.isoString(from: Date())

        try await db.execute(
            sql: """
                INSERT INTO blocks (id, trip_id, title, context, start_at, end_at, display_timezone, local_timezone, created_by, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            parameters: [
                blockId, tripId, title, context.rawValue,
                isoStartAt, isoEndAt, displayTimezone, localTimezone, createdBy, now,
            ]
        )

        print("[BlockRepo] Created block locally: \(blockId)")
        BetaAnalytics.trackBlockCreated(context: context.rawValue)

        return Block(
            id: blockId,
            tripId: tripId,
            title: title,
            context: context,
            createdBy: createdBy,
            startAt: startAt,
            endAt: endAt,
            locationText: nil,
            description: nil,
            displayTimezone: displayTimezone,
            localTimezone: localTimezone,
            untimedRank: nil,
            coverMediaId: nil,
            createdAt: Date()
        )
    }

    // MARK: - Fetch Blocks (local read)

    func fetchBlocks(tripId: String, limit: Int = 100, offset: Int = 0) async throws -> [Block] {
        try await db.getAll(
            sql: """
                SELECT * FROM blocks
                WHERE trip_id = ?
                ORDER BY start_at ASC
                LIMIT ? OFFSET ?
                """,
            parameters: [tripId, limit, offset],
            mapper: Self.blockMapper
        )
    }

    /// Reactive stream of blocks for a trip.
    func watchBlocks(tripId: String) throws -> AsyncThrowingStream<[Block], Error> {
        try db.watch(
            sql: """
                SELECT * FROM blocks
                WHERE trip_id = ?
                ORDER BY start_at ASC
                """,
            parameters: [tripId],
            mapper: Self.blockMapper
        )
    }

    // MARK: - Fetch Single Block (local read)

    func fetchBlock(blockId: String) async throws -> Block {
        guard let block = try await db.getOptional(
            sql: "SELECT * FROM blocks WHERE id = ?",
            parameters: [blockId],
            mapper: Self.blockMapper
        ) else {
            throw BlockRepositoryError.notFound
        }
        return block
    }

    // MARK: - Update Block Header (local-first)

    func updateBlockHeader(
        blockId: String,
        title: String? = nil,
        context: BlockContext? = nil,
        locationText: String? = nil,
        description: String? = nil,
        startAt: Date? = nil,
        endAt: Date?? = nil,
        localTimezone: String?? = nil
    ) async throws {
        var setClauses: [String] = []
        var params: [Sendable?] = []

        if let title {
            setClauses.append("title = ?")
            params.append(title)
        }
        if let context {
            setClauses.append("context = ?")
            params.append(context.rawValue)
        }
        if let locationText {
            setClauses.append("location_text = ?")
            params.append(locationText)
        }
        if let description {
            setClauses.append("description = ?")
            params.append(description)
        }
        if let startAt {
            setClauses.append("start_at = ?")
            params.append(Self.isoString(from: startAt))
        }
        // Double-optional: .some(nil) clears, .some(.some(date)) sets, nil = no change
        if let endAtOuter = endAt {
            setClauses.append("end_at = ?")
            params.append(endAtOuter.map { Self.isoString(from: $0) })
        }
        if let tzOuter = localTimezone {
            setClauses.append("local_timezone = ?")
            params.append(tzOuter)
        }

        guard !setClauses.isEmpty else { return }
        params.append(blockId)

        try await db.execute(
            sql: "UPDATE blocks SET \(setClauses.joined(separator: ", ")) WHERE id = ?",
            parameters: params
        )
    }

    // MARK: - Delete Block (local-first, cascade)

    /// Permanently deletes a block and all related data inside it.
    /// Cascade: posts, post_media, bills, bill_shares, block_documents.
    func deleteBlock(blockId: String) async throws {
        // 1. Gather media files for cleanup
        let mediaItems: [(id: String, postId: String, mediaType: String)] = try await db.getAll(
            sql: """
                SELECT pm.id, pm.post_id, pm.media_type FROM post_media pm
                JOIN posts p ON pm.post_id = p.id
                WHERE p.block_id = ?
                """,
            parameters: [blockId],
            mapper: { cursor in (
                id: try cursor.getString(name: "id"),
                postId: try cursor.getString(name: "post_id"),
                mediaType: try cursor.getString(name: "media_type")
            )}
        )

        // 1b. Gather document files for cleanup
        let docItems: [(id: String, storagePath: String?)] = try await db.getAll(
            sql: "SELECT id, storage_path FROM block_documents WHERE block_id = ?",
            parameters: [blockId],
            mapper: { cursor in (
                id: try cursor.getString(name: "id"),
                storagePath: try cursor.getStringOptional(name: "storage_path")
            )}
        )

        // 2. Delete in dependency order
        try await db.writeTransaction { tx in
            try tx.execute(
                sql: "DELETE FROM post_media WHERE post_id IN (SELECT id FROM posts WHERE block_id = ?)",
                parameters: [blockId]
            )
            try tx.execute(
                sql: "DELETE FROM bill_shares WHERE bill_id IN (SELECT id FROM bills WHERE block_id = ?)",
                parameters: [blockId]
            )
            try tx.execute(
                sql: "DELETE FROM block_documents WHERE block_id = ?",
                parameters: [blockId]
            )
            try tx.execute(
                sql: "DELETE FROM posts WHERE block_id = ?",
                parameters: [blockId]
            )
            try tx.execute(
                sql: "DELETE FROM bills WHERE block_id = ?",
                parameters: [blockId]
            )
            try tx.execute(
                sql: "DELETE FROM blocks WHERE id = ?",
                parameters: [blockId]
            )
        }

        // 3. Clean up media storage (best-effort)
        if !mediaItems.isEmpty {
            let paths = mediaItems.map { item in
                let ext = item.mediaType == "photo" ? "jpg" : "mp4"
                return "posts/\(item.postId)/\(item.id).\(ext)"
            }
            do {
                _ = try await SupabaseConfig.client.storage
                    .from("trip-media")
                    .remove(paths: paths)
            } catch {
                print("[BlockRepo] ⚠️ Media storage cleanup failed: \(error)")
            }
        }

        // 3b. Clean up document storage (best-effort)
        for doc in docItems {
            await DocumentFileManager.shared.deleteDocument(docId: doc.id, storagePath: doc.storagePath)
        }

        // 4. Clean up local media files
        for item in mediaItems {
            let type: MediaType = item.mediaType == "photo" ? .photo : .video
            MediaFileManager.deleteLocalFiles(for: item.id, type: type)
        }

        print("[BlockRepo] Deleted block and all related data: \(blockId)")
    }

    // MARK: - Fetch Trip (local read, for block detail context)

    func fetchTrip(tripId: String) async throws -> Trip {
        guard let trip = try await db.getOptional(
            sql: "SELECT * FROM trips WHERE id = ?",
            parameters: [tripId],
            mapper: TripRepository.tripMapper
        ) else {
            throw BlockRepositoryError.notFound
        }
        return trip
    }

    // MARK: - Mapper

    static let blockMapper: @Sendable (SqlCursor) throws -> Block = { cursor in
        let startAtStr = try cursor.getString(name: "start_at")
        let endAtStr = try cursor.getStringOptional(name: "end_at")
        let createdAtStr = try cursor.getString(name: "created_at")

        return Block(
            id: try cursor.getString(name: "id"),
            tripId: try cursor.getString(name: "trip_id"),
            title: try cursor.getString(name: "title"),
            context: BlockContext(rawValue: try cursor.getString(name: "context")) ?? .group,
            createdBy: try cursor.getString(name: "created_by"),
            startAt: parseISO(startAtStr),
            endAt: endAtStr.flatMap { parseISO($0) },
            locationText: try cursor.getStringOptional(name: "location_text"),
            description: try cursor.getStringOptional(name: "description"),
            displayTimezone: try cursor.getString(name: "display_timezone"),
            localTimezone: try cursor.getStringOptional(name: "local_timezone"),
            untimedRank: try cursor.getIntOptional(name: "untimed_rank"),
            coverMediaId: try cursor.getStringOptional(name: "cover_media_id"),
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

enum BlockRepositoryError: LocalizedError {
    case createFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .createFailed: return "Failed to create block."
        case .notFound: return "Block not found."
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
