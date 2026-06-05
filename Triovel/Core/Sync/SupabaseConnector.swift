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

        for entry in transaction.crud {
            do {
                try await apply(entry: entry, client: client)
            } catch {
                // Transient errors (network down, auth token expired, 5xx) WILL
                // succeed on a later retry — abort the whole transaction so
                // PowerSync re-runs it with backoff. The data stays in the queue.
                if Self.isTransient(error) {
                    print("[Sync] ⚠️ Transient upload error on \(entry.table)/\(entry.id) — will retry: \(error)")
                    throw error
                }
                // Permanent errors (RLS denial, FK/constraint violation, unknown
                // schema column) will NEVER succeed on retry. Rethrowing here would
                // wedge the entire upload queue forever — one bad row blocking every
                // other write for every user. Skip so the queue drains, but record
                // the row in the local quarantine so it's surfaced + retryable in-app
                // instead of vanishing silently.
                print("[Sync] ❌ PERMANENT upload rejection on \(entry.table)/\(entry.id) — quarantining so queue can drain: \(error)")
                await Self.quarantine(entry: entry, error: error, database: database)
            }
        }

        // Reaching here means every entry either uploaded or was permanently
        // rejected and skipped. Transient failures already rethrew above, so it is
        // safe to clear these entries from the local queue.
        try await transaction.complete()
    }

    /// Push a single CRUD entry to Supabase. Throws on failure (caller classifies).
    private func apply(entry: any CrudEntry, client: SupabaseClient) async throws {
        try await Self.performUpload(
            table: entry.table,
            rowId: entry.id,
            op: entry.op.rawValue,
            opData: entry.opData ?? [:],
            client: client
        )
    }

    /// Shared upload primitive used by both the live queue (`apply`) and the
    /// quarantine retry path. `op` is the PowerSync UpdateType raw value
    /// (PUT / PATCH / DELETE). Throws on failure.
    static func performUpload(
        table: String,
        rowId: String,
        op: String,
        opData: [String: String?],
        client: SupabaseClient
    ) async throws {
        switch op {
        case UpdateType.delete.rawValue:
            try await client.from(table).delete().eq("id", value: rowId).execute()

        case UpdateType.patch.rawValue:
            let patchTyped = TypedCrudData(data: opData, table: table)
            try await client.from(table).update(patchTyped).eq("id", value: rowId).execute()

        default: // PUT (insert, with update fallback if the row already exists)
            let typed = TypedCrudData(
                data: opData.merging(["id": rowId]) { _, new in new },
                table: table
            )
            // Insert first, fall back to update if the row already exists.
            // Avoids upsert() which requires both INSERT and UPDATE RLS permissions.
            do {
                try await client.from(table).insert(typed).execute()
            } catch {
                let msg = String(describing: error).lowercased()
                if isDuplicate(msg) {
                    // Row already exists server-side (a retried insert, or — for
                    // trip_members — an owner row created by a server trigger).
                    // The data is already present, which is what matters. Try to
                    // reconcile via update; if the table has no UPDATE policy the
                    // update is denied, but that's fine — nothing left to sync.
                    do {
                        let updateData = TypedCrudData(data: opData, table: table)
                        try await client.from(table).update(updateData).eq("id", value: rowId).execute()
                    } catch {
                        if isTransient(error) { throw error }
                        // Permanent update failure on an already-existing row —
                        // the row is present, so treat as resolved.
                    }
                } else {
                    throw error
                }
            }
        }
    }

    // MARK: - Quarantine

    /// Record a permanently-rejected write to the local-only `sync_quarantine`
    /// table so it can be surfaced and retried instead of silently lost.
    private static func quarantine(
        entry: any CrudEntry,
        error: Error,
        database: any PowerSyncDatabaseProtocol
    ) async {
        let payload = encodePayload(entry.opData)
        let now = ISO8601DateFormatter().string(from: Date())
        do {
            try await database.execute(
                sql: """
                    INSERT INTO sync_quarantine (id, table_name, row_id, op, payload, error, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                parameters: [
                    UUID().uuidString.lowercased(),
                    entry.table,
                    entry.id,
                    entry.op.rawValue,
                    payload,
                    String(describing: error),
                    now,
                ]
            )
        } catch {
            print("[Sync] ⚠️ Failed to quarantine \(entry.table)/\(entry.id): \(error)")
        }
    }

    /// Encode opData (string→optional-string) as a JSON object for storage.
    static func encodePayload(_ opData: [String: String?]?) -> String {
        guard let opData else { return "{}" }
        var obj: [String: Any] = [:]
        for (key, value) in opData { obj[key] = value ?? NSNull() }
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    /// Decode a stored JSON payload back into opData form for retry.
    static func decodePayload(_ json: String) -> [String: String?] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        var result: [String: String?] = [:]
        for (key, value) in obj {
            if value is NSNull { result[key] = String?.none }
            else if let s = value as? String { result[key] = s }
            else { result[key] = String(describing: value) }
        }
        return result
    }

    // MARK: - Error Classification

    /// True if the error is worth retrying (the write can still succeed later).
    /// Anything NOT matched here is treated as permanent so it can never wedge the
    /// queue — losing one genuinely-rejected row is far better than blocking all sync.
    private static func isTransient(_ error: Error) -> Bool {
        if error is URLError { return true }
        let msg = String(describing: error).lowercased()
        // Connectivity
        if msg.contains("network") || msg.contains("timed out") || msg.contains("timeout")
            || msg.contains("connection") || msg.contains("could not connect")
            || msg.contains("offline") || msg.contains("cancelled")
            || msg.contains("not connected to the internet") {
            return true
        }
        // Auth — token expired / unauthorized. PowerSync refreshes credentials & retries.
        if msg.contains("jwt") || msg.contains("\"401\"") || msg.contains("(401)")
            || msg.contains("status: 401") || msg.contains("expired") || msg.contains("unauthorized") {
            return true
        }
        // Server-side transient
        if msg.contains("\"500\"") || msg.contains("\"502\"") || msg.contains("\"503\"")
            || msg.contains("\"504\"") || msg.contains("rate limit") || msg.contains("too many requests") {
            return true
        }
        return false
    }

    /// True if the error is a unique/duplicate-key violation.
    private static func isDuplicate(_ lowercasedMessage: String) -> Bool {
        lowercasedMessage.contains("23505")
            || lowercasedMessage.contains("duplicate")
            || lowercasedMessage.contains("unique")
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
