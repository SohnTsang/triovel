import Foundation
import PowerSync

/// A write the server permanently rejected and the upload queue had to skip.
struct QuarantinedItem: Identifiable, Sendable {
    let id: String
    let tableName: String
    let rowId: String
    let op: String
    let payload: String
    let error: String
    let createdAt: Date
}

/// Reads and retries rows in the local-only `sync_quarantine` table.
///
/// When `uploadData` hits a permanent rejection (RLS / FK / constraint), it skips
/// the row so the queue can drain and records it here. This repository surfaces
/// those rows in-app and lets the user re-attempt them once the underlying cause
/// (e.g. a missing migration) is fixed.
final class SyncQuarantineRepository: @unchecked Sendable {
    private var db: PowerSyncDatabaseProtocol { SyncManager.shared.db }

    /// Number of quarantined rows.
    func count() async -> Int {
        do {
            let rows: [Int] = try await db.getAll(
                sql: "SELECT COUNT(*) AS cnt FROM sync_quarantine",
                parameters: [],
                mapper: { try $0.getInt(name: "cnt") }
            )
            return rows.first ?? 0
        } catch {
            return 0
        }
    }

    /// All quarantined rows, newest first.
    func fetchAll() async throws -> [QuarantinedItem] {
        try await db.getAll(
            sql: "SELECT * FROM sync_quarantine ORDER BY created_at DESC",
            parameters: [],
            mapper: Self.mapper
        )
    }

    /// Re-attempt every quarantined write. Rows that succeed are removed; rows that
    /// fail again stay for a future retry. Returns (succeeded, failed) counts.
    @discardableResult
    func retryAll() async -> (succeeded: Int, failed: Int) {
        let items = (try? await fetchAll()) ?? []
        var succeeded = 0
        var failed = 0
        let client = SupabaseConfig.client
        for item in items {
            do {
                try await SupabaseConnector.performUpload(
                    table: item.tableName,
                    rowId: item.rowId,
                    op: item.op,
                    opData: SupabaseConnector.decodePayload(item.payload),
                    client: client
                )
                try? await delete(id: item.id)
                succeeded += 1
            } catch {
                print("[Sync] Quarantine retry still failing for \(item.tableName)/\(item.rowId): \(error)")
                failed += 1
            }
        }
        return (succeeded, failed)
    }

    /// Delete a single quarantined row.
    func delete(id: String) async throws {
        try await db.execute(
            sql: "DELETE FROM sync_quarantine WHERE id = ?",
            parameters: [id]
        )
    }

    /// Discard all quarantined rows.
    func clearAll() async throws {
        try await db.execute(sql: "DELETE FROM sync_quarantine", parameters: [])
    }

    // MARK: - Mapper

    private static let mapper: @Sendable (SqlCursor) throws -> QuarantinedItem = { cursor in
        QuarantinedItem(
            id: try cursor.getString(name: "id"),
            tableName: try cursor.getString(name: "table_name"),
            rowId: try cursor.getString(name: "row_id"),
            op: try cursor.getString(name: "op"),
            payload: (try? cursor.getString(name: "payload")) ?? "{}",
            error: (try? cursor.getString(name: "error")) ?? "",
            createdAt: parseISOTimestamp((try? cursor.getString(name: "created_at")) ?? "")
        )
    }
}

private func parseISOTimestamp(_ str: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: str) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: str) ?? Date()
}
