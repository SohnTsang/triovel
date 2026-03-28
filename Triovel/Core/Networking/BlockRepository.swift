import Foundation
import PowerSync

/// Reads blocks from local PowerSync SQLite. Writes locally first.
final class BlockRepository {
    private var db: PowerSyncDatabaseProtocol { SyncManager.shared.db }

    // MARK: - Create Block (local-first)

    func createBlock(
        tripId: String,
        title: String,
        context: BlockContext,
        startAt: Date,
        displayTimezone: String,
        createdBy: String
    ) async throws -> Block {
        let blockId = UUID().uuidString.lowercased()
        let isoStartAt = Self.isoString(from: startAt)
        let now = Self.isoString(from: Date())

        try await db.execute(
            sql: """
                INSERT INTO blocks (id, trip_id, title, context, start_at, display_timezone, created_by, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
            parameters: [
                blockId, tripId, title, context.rawValue,
                isoStartAt, displayTimezone, createdBy, now,
            ]
        )

        print("[BlockRepo] Created block locally: \(blockId)")

        return Block(
            id: blockId,
            tripId: tripId,
            title: title,
            context: context,
            createdBy: createdBy,
            startAt: startAt,
            endAt: nil,
            locationText: nil,
            description: nil,
            displayTimezone: displayTimezone,
            localTimezone: nil,
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
        title: String?,
        locationText: String?,
        description: String?,
        startAt: Date?
    ) async throws {
        var setClauses: [String] = []
        var params: [Sendable?] = []

        if let title {
            setClauses.append("title = ?")
            params.append(title)
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

        guard !setClauses.isEmpty else { return }
        params.append(blockId)

        try await db.execute(
            sql: "UPDATE blocks SET \(setClauses.joined(separator: ", ")) WHERE id = ?",
            parameters: params
        )
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
