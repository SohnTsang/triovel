import Foundation
import PowerSync
import Supabase

/// Reads trips from local PowerSync SQLite. Writes locally first, then
/// PowerSync uploads to Supabase via the connector.
/// Exception: joinTrip requires network (trip not in local DB until membership exists).
final class TripRepository {
    private var db: PowerSyncDatabaseProtocol { SyncManager.shared.db }
    private let client = SupabaseConfig.client

    // MARK: - Create Trip (local-first)

    func createTrip(
        title: String,
        startDate: Date,
        endDate: Date,
        displayTimezone: String,
        baseCurrency: String,
        createdBy: String
    ) async throws -> String {
        let tripId = UUID().uuidString.lowercased()
        let memberId = UUID().uuidString.lowercased()
        let now = Self.isoString(from: Date())

        try await db.writeTransaction { tx in
            try tx.execute(
                sql: """
                    INSERT INTO trips (id, title, start_date, end_date, display_timezone, base_currency, archived, created_by, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)
                    """,
                parameters: [
                    tripId, title,
                    Self.dateOnlyString(from: startDate),
                    Self.dateOnlyString(from: endDate),
                    displayTimezone, baseCurrency,
                    createdBy, now,
                ]
            )
            // Mirror the on_trip_created trigger locally
            try tx.execute(
                sql: """
                    INSERT INTO trip_members (id, trip_id, user_id, role, joined_at)
                    VALUES (?, ?, ?, 'owner', ?)
                    """,
                parameters: [memberId, tripId, createdBy, now]
            )
        }

        print("[TripRepo] Created trip locally: \(tripId)")
        BetaAnalytics.trackTripCreated()
        return tripId
    }

    // MARK: - Join Trip (requires network)

    func joinTrip(inviteCode: String, userId: String) async throws -> String {
        print("[TripRepo] JOIN trip with code: \(inviteCode)")

        let rows: [TripIdRow] = try await client
            .from("trips")
            .select("id")
            .eq("invite_link", value: inviteCode)
            .execute()
            .value

        guard let tripId = rows.first?.id else {
            throw TripRepositoryError.tripNotFound
        }

        let existing: [MemberIdRow] = try await client
            .from("trip_members")
            .select("id")
            .eq("trip_id", value: tripId)
            .eq("user_id", value: userId)
            .execute()
            .value

        if existing.isEmpty {
            let params = JoinTripParams(trip_id: tripId, user_id: userId, role: "member")
            try await client
                .from("trip_members")
                .insert(params)
                .execute()
            print("[TripRepo] Joined trip: \(tripId)")
        } else {
            print("[TripRepo] Already a member of trip: \(tripId)")
        }

        return tripId
    }

    // MARK: - Archive / Unarchive

    func archiveTrip(tripId: String) async throws {
        try await db.execute(
            sql: "UPDATE trips SET archived = 1 WHERE id = ?",
            parameters: [tripId]
        )
        print("[TripRepo] Archived trip: \(tripId)")
    }

    func unarchiveTrip(tripId: String) async throws {
        try await db.execute(
            sql: "UPDATE trips SET archived = 0 WHERE id = ?",
            parameters: [tripId]
        )
        print("[TripRepo] Unarchived trip: \(tripId)")
    }

    // MARK: - Fetch Trips (local read)

    func fetchTrips(userId: String) async throws -> (active: [Trip], archived: [Trip]) {
        let trips = try await db.getAll(
            sql: """
                SELECT t.* FROM trips t
                JOIN trip_members tm ON t.id = tm.trip_id
                WHERE tm.user_id = ?
                ORDER BY t.created_at DESC
                """,
            parameters: [userId],
            mapper: Self.tripMapper
        )
        let active = trips.filter { !$0.archived }
        let archived = trips.filter { $0.archived }
        return (active, archived)
    }

    /// Reactive stream of trips for the given user.
    func watchTrips(userId: String) throws -> AsyncThrowingStream<[Trip], Error> {
        try db.watch(
            sql: """
                SELECT t.* FROM trips t
                JOIN trip_members tm ON t.id = tm.trip_id
                WHERE tm.user_id = ?
                ORDER BY t.created_at DESC
                """,
            parameters: [userId],
            mapper: Self.tripMapper
        )
    }

    // MARK: - Fetch Members (local read)

    func fetchMembers(tripIds: [String]) async throws -> [String: [TripMemberDisplay]] {
        guard !tripIds.isEmpty else { return [:] }

        let placeholders = tripIds.map { _ in "?" }.joined(separator: ", ")
        let rows = try await db.getAll(
            sql: """
                SELECT tm.trip_id, tm.user_id, tm.role, u.display_name, u.avatar_path
                FROM trip_members tm
                JOIN users u ON tm.user_id = u.id
                WHERE tm.trip_id IN (\(placeholders))
                """,
            parameters: tripIds.map { $0 as Sendable? },
            mapper: MemberWithTrip.from
        )

        var result: [String: [TripMemberDisplay]] = [:]
        for row in rows {
            result[row.tripId, default: []].append(row.display)
        }
        return result
    }

    // MARK: - Trip Mapper

    static let tripMapper: @Sendable (SqlCursor) throws -> Trip = { cursor in
        let startDateStr = try cursor.getString(name: "start_date")
        let endDateStr = try cursor.getString(name: "end_date")
        let createdAtStr = try cursor.getString(name: "created_at")

        return Trip(
            id: try cursor.getString(name: "id"),
            title: try cursor.getString(name: "title"),
            startDate: parseDateOnly(startDateStr),
            endDate: parseDateOnly(endDateStr),
            coverImagePath: try cursor.getStringOptional(name: "cover_image_path"),
            inviteLink: try cursor.getStringOptional(name: "invite_link"),
            displayTimezone: try cursor.getString(name: "display_timezone"),
            baseCurrency: try cursor.getString(name: "base_currency"),
            archived: (try? cursor.getInt(name: "archived")) == 1,
            createdBy: try cursor.getString(name: "created_by"),
            createdAt: parseISO(createdAtStr)
        )
    }

    // MARK: - Helpers

    private static func dateOnlyString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    private static func isoString(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}

// MARK: - Error

enum TripRepositoryError: LocalizedError {
    case createFailed
    case tripNotFound

    var errorDescription: String? {
        switch self {
        case .createFailed: return "Failed to create trip."
        case .tripNotFound: return "No trip found with that invite code."
        }
    }
}

// MARK: - Date Parsing

private func parseDateOnly(_ str: String) -> Date {
    let parts = str.split(separator: "-")
    guard parts.count == 3,
          let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2])
    else { return Date() }
    var c = DateComponents()
    c.year = y; c.month = m; c.day = d
    return Calendar.current.date(from: c) ?? Date()
}

private func parseISO(_ str: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: str) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: str) ?? Date()
}

// MARK: - DTOs (for Supabase direct calls in joinTrip)

private struct TripIdRow: Decodable { let id: String }
private struct MemberIdRow: Decodable { let id: String }
private struct JoinTripParams: Encodable {
    let trip_id: String
    let user_id: String
    let role: String
}

private struct MemberWithTrip: Sendable {
    let tripId: String
    let display: TripMemberDisplay

    static let from: @Sendable (SqlCursor) throws -> MemberWithTrip = { cursor in
        MemberWithTrip(
            tripId: try cursor.getString(name: "trip_id"),
            display: TripMemberDisplay(
                userId: try cursor.getString(name: "user_id"),
                displayName: try cursor.getString(name: "display_name"),
                avatarPath: try cursor.getStringOptional(name: "avatar_path"),
                role: TripMember.Role(rawValue: try cursor.getString(name: "role")) ?? .member
            )
        )
    }
}
