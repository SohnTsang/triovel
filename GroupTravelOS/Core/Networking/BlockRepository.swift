import Foundation
import Supabase

/// Handles block CRUD against Supabase.
/// Will be replaced by PowerSync local-first writes in Phase 2.
@MainActor
final class BlockRepository {
    private let client = SupabaseConfig.client

    // MARK: - Create Block

    /// Creates a block in the given trip. Returns the full block.
    func createBlock(
        tripId: String,
        title: String,
        context: BlockContext,
        startAt: Date,
        displayTimezone: String,
        createdBy: String
    ) async throws -> Block {
        let params = CreateBlockParams(
            trip_id: tripId,
            title: title,
            context: context.rawValue,
            start_at: Self.isoString(from: startAt),
            display_timezone: displayTimezone,
            created_by: createdBy
        )

        let rows: [BlockDBRow] = try await client
            .from("blocks")
            .insert(params)
            .select()
            .execute()
            .value

        guard let row = rows.first else {
            throw BlockRepositoryError.createFailed
        }

        return row.toDomain()
    }

    // MARK: - Fetch Blocks for Trip

    func fetchBlocks(tripId: String) async throws -> [Block] {
        let rows: [BlockDBRow] = try await client
            .from("blocks")
            .select()
            .eq("trip_id", value: tripId)
            .order("start_at", ascending: true)
            .execute()
            .value

        return rows.map { $0.toDomain() }
    }

    // MARK: - Fetch Single Block

    func fetchBlock(blockId: String) async throws -> Block {
        let rows: [BlockDBRow] = try await client
            .from("blocks")
            .select()
            .eq("id", value: blockId)
            .execute()
            .value

        guard let row = rows.first else {
            throw BlockRepositoryError.notFound
        }

        return row.toDomain()
    }

    // MARK: - Update Block Header

    /// Only block creator or trip owner should call this (enforced by RLS).
    func updateBlockHeader(
        blockId: String,
        title: String?,
        locationText: String?,
        startAt: Date?
    ) async throws {
        var updates: [String: AnyEncodable] = [:]
        if let title { updates["title"] = AnyEncodable(title) }
        if let locationText { updates["location_text"] = AnyEncodable(locationText) }
        if let startAt { updates["start_at"] = AnyEncodable(Self.isoString(from: startAt)) }

        guard !updates.isEmpty else { return }

        try await client
            .from("blocks")
            .update(updates)
            .eq("id", value: blockId)
            .execute()
    }

    // MARK: - Fetch Trip (for block detail context)

    func fetchTrip(tripId: String) async throws -> Trip {
        let rows: [TripDBRow] = try await client
            .from("trips")
            .select()
            .eq("id", value: tripId)
            .execute()
            .value

        guard let row = rows.first else {
            throw BlockRepositoryError.notFound
        }

        return row.toDomain()
    }

    // MARK: - Helpers

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

// MARK: - Simple AnyEncodable for partial updates

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        _encode = { encoder in
            try wrapped.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
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

// MARK: - DTOs

private struct CreateBlockParams: Encodable {
    let trip_id: String
    let title: String
    let context: String
    let start_at: String
    let display_timezone: String
    let created_by: String
}

private struct BlockDBRow: Decodable {
    let id: String
    let trip_id: String
    let title: String
    let context: String
    let created_by: String
    let start_at: String
    let end_at: String?
    let location_text: String?
    let display_timezone: String
    let local_timezone: String?
    let untimed_rank: Int?
    let cover_media_id: String?
    let created_at: String

    func toDomain() -> Block {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        func parseDate(_ str: String) -> Date {
            isoFormatter.date(from: str)
                ?? isoBasic.date(from: str)
                ?? Date()
        }

        return Block(
            id: id,
            tripId: trip_id,
            title: title,
            context: BlockContext(rawValue: context) ?? .group,
            createdBy: created_by,
            startAt: parseDate(start_at),
            endAt: end_at.flatMap { parseDate($0) },
            locationText: location_text,
            displayTimezone: display_timezone,
            localTimezone: local_timezone,
            untimedRank: untimed_rank,
            coverMediaId: cover_media_id,
            createdAt: parseDate(created_at)
        )
    }
}

// Re-use TripDBRow from TripRepository — extracted here for block context
private struct TripDBRow: Decodable {
    let id: String
    let title: String
    let start_date: String
    let end_date: String
    let cover_image_path: String?
    let invite_link: String?
    let display_timezone: String
    let base_currency: String
    let archived: Bool
    let created_by: String
    let created_at: String

    func toDomain() -> Trip {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return Trip(
            id: id,
            title: title,
            startDate: dateFormatter.date(from: start_date) ?? Date(),
            endDate: dateFormatter.date(from: end_date) ?? Date(),
            coverImagePath: cover_image_path,
            inviteLink: invite_link,
            displayTimezone: display_timezone,
            baseCurrency: base_currency,
            archived: archived,
            createdBy: created_by,
            createdAt: isoFormatter.date(from: created_at) ?? Date()
        )
    }
}
