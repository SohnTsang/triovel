import Foundation
import PowerSync

/// Holds the PowerSync database and manages sync lifecycle.
///
/// Access the database from any context via `SyncManager.shared.db`.
/// The database is thread-safe (Sendable). Connect/disconnect are called
/// from AppState on sign-in/sign-out.
final class SyncManager: @unchecked Sendable {
    static let shared = SyncManager()

    /// Local PowerSync SQLite database. Safe to access from any actor.
    let db: PowerSyncDatabaseProtocol

    private init() {
        db = PowerSyncDatabase(
            schema: AppSchema.schema,
            dbFilename: "triovel.sqlite"
        )
    }

    /// Connect to PowerSync with Supabase credentials.
    /// Call after successful sign-in.
    func connect() async throws {
        let connector = SupabaseConnector()
        try await db.connect(connector: connector)
        print("[Sync] Connected to PowerSync")
    }

    /// Disconnect from PowerSync. Call on sign-out.
    func disconnect() async {
        do {
            try await db.disconnect()
            print("[Sync] Disconnected")
        } catch {
            print("[Sync] Disconnect error: \(error)")
        }
    }

    /// Disconnect and clear all local data. Call on sign-out
    /// to ensure no data leaks between accounts.
    func disconnectAndClear() async {
        do {
            try await db.disconnectAndClear()
            print("[Sync] Disconnected and cleared local data")
        } catch {
            print("[Sync] DisconnectAndClear error: \(error)")
        }
    }
}
