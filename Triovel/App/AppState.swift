import Observation
import SwiftUI

@Observable
@MainActor
final class AppState {
    enum AuthStatus: Equatable {
        case unknown
        case signedOut
        case verificationPending(email: String)
        case signedIn
    }

    var authStatus: AuthStatus = .unknown
    var currentUserId: String?

    // Sync status (observed by UI for indicators)
    private(set) var isSyncConnected = false
    private(set) var hasSynced = false
    private(set) var lastSyncedAt: Date?

    let authService = AuthService()
    nonisolated(unsafe) private var syncStatusTask: Task<Void, Never>?

    /// Called on app launch. Follows the auth refresh flow from sync.md:
    /// 1. Restore local session
    /// 2. Refresh auth token if expired (handled by Supabase SDK automatically)
    /// 3. Resume data sync via PowerSync
    /// 4. Resume media queue (Phase 3)
    func restoreSession() async {
        let restored = await authService.restoreSession()
        if restored, let user = authService.currentUser {
            currentUserId = user.id.uuidString.lowercased()
            print("[Auth] Session restored, userId: \(currentUserId ?? "nil")")
            authStatus = .signedIn
            await connectSync()
        } else {
            print("[Auth] No session to restore")
            authStatus = .signedOut
        }
    }

    /// Called after successful sign-in (Apple or email with auto-confirm).
    func completeSignIn() {
        guard let user = authService.currentUser else { return }
        currentUserId = user.id.uuidString.lowercased()
        print("[Auth] Sign-in complete, userId: \(currentUserId ?? "nil")")
        authStatus = .signedIn

        Task {
            await connectSync()
        }
    }

    /// Called after email sign-up when verification is required.
    func awaitVerification(email: String) {
        authStatus = .verificationPending(email: email)
    }

    /// Called when user wants to go back to sign-in from verification screen.
    func cancelVerification() {
        authStatus = .signedOut
    }

    /// Handle deep link URLs (triovel://auth-callback, triovel://trip/{code}).
    func handleDeepLink(url: URL) async {
        guard let host = url.host else { return }

        switch host {
        case "auth-callback":
            do {
                try await authService.handleAuthCallback(url: url)
                completeSignIn()
            } catch {
                // Link expired or invalid — stay on verification screen
            }

        case "trip":
            // triovel://trip/{invite_code} — handle in follow-up
            break

        default:
            break
        }
    }

    func signOut() async {
        // Disconnect sync and clear local data before signing out
        await disconnectSync()
        await authService.signOut()
        currentUserId = nil
        authStatus = .signedOut
    }

    // MARK: - Sync Lifecycle

    private func connectSync() async {
        do {
            try await SyncManager.shared.connect()
            startWatchingSyncStatus()
        } catch {
            print("[Sync] ❌ Connect failed: \(error)")
        }
    }

    private func disconnectSync() async {
        syncStatusTask?.cancel()
        await SyncManager.shared.disconnectAndClear()
        isSyncConnected = false
        hasSynced = false
        lastSyncedAt = nil
    }

    private func startWatchingSyncStatus() {
        syncStatusTask?.cancel()
        syncStatusTask = Task { [weak self] in
            for await status in SyncManager.shared.db.currentStatus.asFlow() {
                guard let self, !Task.isCancelled else { break }
                self.isSyncConnected = status.connected
                self.lastSyncedAt = status.lastSyncedAt
                if status.hasSynced == true {
                    self.hasSynced = true
                }
            }
        }
    }
}
