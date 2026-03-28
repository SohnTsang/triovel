import Foundation
import PowerSync
import Supabase

/// Connects PowerSync to Supabase: provides JWT credentials and
/// handles the CRUD upload queue (local writes → Supabase).
final class SupabaseConnector: PowerSyncBackendConnectorProtocol {

    // MARK: - Credentials

    func fetchCredentials() async throws -> PowerSyncCredentials? {
        let session = try await SupabaseConfig.client.auth.session
        return PowerSyncCredentials(
            endpoint: PowerSyncConfig.powersyncURL,
            token: session.accessToken
        )
    }

    // MARK: - Upload

    func uploadData(database: any PowerSyncDatabaseProtocol) async throws {
        guard let transaction = try await database.getNextCrudTransaction() else {
            return
        }

        do {
            let client = SupabaseConfig.client
            for entry in transaction.crud {
                switch entry.op {
                case .put:
                    var data = entry.opData ?? [:]
                    data["id"] = entry.id
                    let typed = TypedCrudData(data: data, table: entry.table)
                    try await client.from(entry.table).upsert(typed).execute()

                case .patch:
                    guard let opData = entry.opData else { continue }
                    let typed = TypedCrudData(data: opData, table: entry.table)
                    try await client.from(entry.table).update(typed).eq("id", value: entry.id).execute()

                case .delete:
                    try await client.from(entry.table).delete().eq("id", value: entry.id).execute()
                }
            }
            try await transaction.complete()
        } catch {
            // If the error is a permanent Postgres issue (RLS violation, constraint error),
            // discard the transaction to prevent infinite retry loops.
            // Transient errors (network) are rethrown for PowerSync to retry.
            if isFatalPostgresError(error) {
                print("[Sync] ⚠️ Discarding transaction due to fatal error: \(error)")
                try await transaction.complete()
            } else {
                print("[Sync] ❌ Upload failed (will retry): \(error)")
                throw error
            }
        }
    }

    /// Postgres errors that will never succeed on retry (RLS, constraints, etc.).
    /// Network errors should be retried.
    private func isFatalPostgresError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("row-level security")
            || message.contains("violates")
            || message.contains("42501")  // insufficient privilege
            || message.contains("23505")  // unique violation
            || message.contains("23503")  // foreign key violation
            || message.contains("23502")  // not-null violation
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
        "payments": ["amount"],
    ]
}
