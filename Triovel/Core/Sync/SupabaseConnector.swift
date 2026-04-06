import Foundation
import PowerSync
import Supabase

/// Connects PowerSync to Supabase: provides JWT credentials and
/// handles the CRUD upload queue (local writes → Supabase).
final class SupabaseConnector: PowerSyncBackendConnectorProtocol {

    // MARK: - Credentials

    func fetchCredentials() async throws -> PowerSyncCredentials? {
        do {
            let session = try await SupabaseConfig.client.auth.session
            print("[Sync] ✓ Credentials fetched (token expires: \(Date(timeIntervalSince1970: session.expiresAt)))")
            return PowerSyncCredentials(
                endpoint: PowerSyncConfig.powersyncURL,
                token: session.accessToken
            )
        } catch {
            print("[Sync] ❌ fetchCredentials failed: \(error)")
            throw error
        }
    }

    // MARK: - Upload

    func uploadData(database: any PowerSyncDatabaseProtocol) async throws {
        guard let transaction = try await database.getNextCrudTransaction() else {
            return
        }

        let client = SupabaseConfig.client
        do {
            for entry in transaction.crud {
                let typed = TypedCrudData(
                    data: (entry.opData ?? [:]).merging(["id": entry.id]) { _, new in new },
                    table: entry.table
                )

                switch entry.op {
                case .put:
                    // Use insert() first, fall back to update() if row exists.
                    // Avoids upsert() which requires both INSERT and UPDATE RLS
                    // permissions (fails for trips because trip_members trigger
                    // hasn't fired yet when UPDATE policy is checked).
                    do {
                        try await client.from(entry.table).insert(typed).execute()
                    } catch {
                        let msg = String(describing: error).lowercased()
                        if msg.contains("23505") || msg.contains("duplicate") || msg.contains("unique") {
                            // Row already exists — update instead
                            let updateData = TypedCrudData(data: entry.opData ?? [:], table: entry.table)
                            try await client.from(entry.table).update(updateData).eq("id", value: entry.id).execute()
                        } else {
                            throw error
                        }
                    }

                case .patch:
                    guard let opData = entry.opData else { continue }
                    let patchTyped = TypedCrudData(data: opData, table: entry.table)
                    try await client.from(entry.table).update(patchTyped).eq("id", value: entry.id).execute()

                case .delete:
                    try await client.from(entry.table).delete().eq("id", value: entry.id).execute()
                }
            }
            try await transaction.complete()
        } catch {
            print("[Sync] ❌ Upload failed (will retry): \(error)")
            // Always rethrow — PowerSync will retry with exponential backoff.
            // Never silently discard data.
            throw error
        }
    }
}

// MARK: - Type-Correct CRUD Encoding

/// PowerSync opData stores all values as strings. PostgREST needs proper
/// JSON types (numbers, booleans) for integer/boolean Postgres columns.
/// This wrapper encodes values with the correct JSON types.
private struct TypedCrudData: Encodable {
    private let entries: [(String, CrudValue)]

    init(data: [String: String?], table: String) {
        self.entries = data.map { key, value in
            guard let value else { return (key, .null) }

            if Self.booleanColumns[table]?.contains(key) == true {
                return (key, .boolean(value == "1" || value.lowercased() == "true"))
            }
            if Self.integerColumns[table]?.contains(key) == true {
                if let intValue = Int(value) {
                    return (key, .integer(intValue))
                }
            }
            return (key, .text(value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in entries {
            guard let ck = DynamicKey(stringValue: key) else { continue }
            switch value {
            case .text(let s): try container.encode(s, forKey: ck)
            case .integer(let i): try container.encode(i, forKey: ck)
            case .boolean(let b): try container.encode(b, forKey: ck)
            case .null: try container.encodeNil(forKey: ck)
            }
        }
    }

    private enum CrudValue {
        case text(String)
        case integer(Int)
        case boolean(Bool)
        case null
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    /// Postgres boolean columns per table.
    private static let booleanColumns: [String: Set<String>] = [
        "trips": ["archived"],
    ]

    /// Postgres integer columns per table (amounts, ranks).
    private static let integerColumns: [String: Set<String>] = [
        "blocks": ["untimed_rank"],
        "bills": ["amount"],
        "bill_shares": ["share_amount"],
        "block_documents": ["file_size"],
        "payments": ["amount"],
    ]
}
