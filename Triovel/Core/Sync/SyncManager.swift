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

    /// Prevents re-entrant connect() calls that cause disconnect/reconnect loops.
    /// When db.connect() is called on an already-connected instance, PowerSync
    /// first stops the current connection (emitting connected=false), then starts
    /// a new one. The status watcher misinterprets the brief disconnect as a
    /// connection drop and triggers another reconnect — creating an infinite loop.
    private var isConnecting = false
    private var hasAuditedThisSession = false

    private init() {
        db = PowerSyncDatabase(
            schema: AppSchema.schema,
            dbFilename: "triovel.sqlite"
        )
    }

    /// Connect to PowerSync with Supabase credentials.
    /// Call after successful sign-in.
    func connect(currentUserId: String? = nil) async throws {
        // Guard: if already connected or in the process of connecting, skip.
        // Calling db.connect() on an active connection causes a stop+restart
        // cycle that the status watcher misinterprets as a real disconnect.
        guard !isConnecting else {
            print("[Sync] Already connecting, skipping")
            return
        }
        if db.currentStatus.connected {
            print("[Sync] Already connected, skipping")
            return
        }

        isConnecting = true
        defer { isConnecting = false }

        let connector = SupabaseConnector()
        try await db.connect(connector: connector)
        print("[Sync] Connected to PowerSync")

        // Privacy audit: run once per session, not on every reconnect
        if !hasAuditedThisSession, let userId = currentUserId {
            hasAuditedThisSession = true
            Task.detached(priority: .utility) { [db] in
                try? await Task.sleep(for: .seconds(5)) // Wait for initial sync
                await Self.auditPrivacyLeaks(db: db, currentUserId: userId)
            }
        }
    }

    /// Logs a warning if private posts from other users exist in local SQLite.
    /// This should never happen if PowerSync sync rules are correctly configured.
    /// If it does, the client-side SQL filters in PostRepository prevent display.
    private static func auditPrivacyLeaks(db: PowerSyncDatabaseProtocol, currentUserId: String) async {
        do {
            let rows: [Int] = try await db.getAll(
                sql: "SELECT COUNT(*) as cnt FROM posts WHERE visibility = 'private' AND user_id != ?",
                parameters: [currentUserId],
                mapper: { cursor in try cursor.getInt(name: "cnt") }
            )
            let count = rows.first ?? 0
            if count > 0 {
                print("[Sync] ⚠️ PRIVACY AUDIT: \(count) private post(s) from other users in local DB. Deploy updated sync rules from docs/powersync-sync-rules.yaml to PowerSync dashboard.")
            } else {
                print("[Sync] ✓ Privacy audit passed — no leaked private posts")
            }
        } catch {
            print("[Sync] Privacy audit skipped: \(error)")
        }
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
        hasAuditedThisSession = false
        do {
            try await db.disconnectAndClear()
            print("[Sync] Disconnected and cleared local data")
        } catch {
            print("[Sync] DisconnectAndClear error: \(error)")
        }
    }
}
