import Foundation
import Supabase

/// Handles trip CRUD against Supabase.
/// Will be replaced by PowerSync local-first writes in Phase 2.
@MainActor
final class TripRepository {
    private let client = SupabaseConfig.client

    // MARK: - Create Trip

    /// Creates a trip and adds the creator as owner in trip_members.
    /// Returns the created trip's ID.
    func createTrip(
        title: String,
        startDate: Date,
        endDate: Date,
        displayTimezone: String,
        baseCurrency: String,
        createdBy: String
    ) async throws -> String {
        let params = CreateTripParams(
            title: title,
            start_date: Self.dateOnlyString(from: startDate),
            end_date: Self.dateOnlyString(from: endDate),
            display_timezone: displayTimezone,
            base_currency: baseCurrency,
            created_by: createdBy
        )

        let rows: [TripRow] = try await client
            .from("trips")
            .insert(params)
            .select("id")
            .execute()
            .value

        guard let tripId = rows.first?.id else {
            throw TripRepositoryError.createFailed
        }

        // Add creator as owner
        let memberParams = CreateTripMemberParams(
            trip_id: tripId,
            user_id: createdBy,
            role: "owner"
        )
        try await client
            .from("trip_members")
            .insert(memberParams)
            .execute()

        return tripId
    }

    // MARK: - Join Trip

    /// Joins a trip by invite link. Returns the trip ID if successful.
    func joinTrip(inviteCode: String, userId: String) async throws -> String {
        // Look up trip by invite_link
        let rows: [TripRow] = try await client
            .from("trips")
            .select("id")
            .eq("invite_link", value: inviteCode)
            .execute()
            .value

        guard let tripId = rows.first?.id else {
            throw TripRepositoryError.tripNotFound
        }

        // Check if already a member
        let existing: [TripMemberRow] = try await client
            .from("trip_members")
            .select("id")
            .eq("trip_id", value: tripId)
            .eq("user_id", value: userId)
            .execute()
            .value

        if existing.isEmpty {
            let memberParams = CreateTripMemberParams(
                trip_id: tripId,
                user_id: userId,
                role: "member"
            )
            try await client
                .from("trip_members")
                .insert(memberParams)
                .execute()
        }

        return tripId
    }

    // MARK: - Fetch Trips

    /// Fetches all trips the user is a member of, split into active and archived.
    func fetchTrips(userId: String) async throws -> (active: [Trip], archived: [Trip]) {
        // Get trip IDs user is a member of
        let memberships: [TripMemberRow] = try await client
            .from("trip_members")
            .select("trip_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        let tripIds = memberships.map(\.trip_id)
        guard !tripIds.isEmpty else { return ([], []) }

        let rows: [TripDBRow] = try await client
            .from("trips")
            .select()
            .in("id", values: tripIds)
            .order("created_at", ascending: false)
            .execute()
            .value

        let trips = rows.map { $0.toDomain() }
        let active = trips.filter { !$0.archived }
        let archived = trips.filter { $0.archived }
        return (active, archived)
    }

    /// Fetches members for a list of trips.
    func fetchMembers(tripIds: [String]) async throws -> [String: [TripMemberDisplay]] {
        guard !tripIds.isEmpty else { return [:] }

        let rows: [TripMemberWithUser] = try await client
            .from("trip_members")
            .select("trip_id, user_id, users(display_name, avatar_path)")
            .in("trip_id", values: tripIds)
            .execute()
            .value

        var result: [String: [TripMemberDisplay]] = [:]
        for row in rows {
            let display = TripMemberDisplay(
                userId: row.user_id,
                displayName: row.users.display_name,
                avatarPath: row.users.avatar_path
            )
            result[row.trip_id, default: []].append(display)
        }
        return result
    }

    // MARK: - Helpers

    private static func dateOnlyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}

// MARK: - Error

enum TripRepositoryError: LocalizedError {
    case createFailed
    case tripNotFound

    var errorDescription: String? {
        switch self {
        case .createFailed:
            return "Failed to create trip."
        case .tripNotFound:
            return "No trip found with that invite code."
        }
    }
}

// MARK: - Codable DTOs

private struct CreateTripParams: Encodable {
    let title: String
    let start_date: String
    let end_date: String
    let display_timezone: String
    let base_currency: String
    let created_by: String
}

private struct CreateTripMemberParams: Encodable {
    let trip_id: String
    let user_id: String
    let role: String
}

private struct TripRow: Decodable {
    let id: String
}

private struct TripMemberRow: Decodable {
    let id: String?
    let trip_id: String

    enum CodingKeys: String, CodingKey {
        case id, trip_id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.trip_id = try container.decode(String.self, forKey: .trip_id)
    }
}

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

private struct TripMemberWithUser: Decodable {
    let trip_id: String
    let user_id: String
    let users: UserProfile

    struct UserProfile: Decodable {
        let display_name: String
        let avatar_path: String?
    }
}
