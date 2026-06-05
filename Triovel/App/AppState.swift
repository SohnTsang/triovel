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

    // Deep link: pending invite code to join after sign-in
    var pendingInviteCode: String?
    // Deep link: trip ID to navigate to after joining
    var pendingNavigateTripId: String?

    // Sync status (observed by UI for indicators)
    private(set) var isSyncConnected = false
    private(set) var hasSynced = false
    private(set) var lastSyncedAt: Date?

    let authService = AuthService()
    @ObservationIgnored private var syncStatusTask: Task<Void, Never>?

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
            // Process any pending deep link invite
            await processPendingInvite()
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
            // triovel://trip/{invite_code}
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            guard let code = pathComponents.first, !code.isEmpty else { return }

            if authStatus == .signedIn, let userId = currentUserId {
                // Already signed in — join immediately
                await joinTripFromDeepLink(code: code, userId: userId)
            } else {
                // Not signed in — save for after sign-in
                pendingInviteCode = code
            }

        default:
            break
        }
    }

    /// Join a trip from a deep link invite code.
    func joinTripFromDeepLink(code: String, userId: String) async {
        do {
            let tripId = try await TripRepository().joinTrip(inviteCode: code, userId: userId)
            pendingNavigateTripId = tripId
            print("[AppState] Joined trip from deep link: \(tripId)")
        } catch {
            print("[AppState] ❌ Deep link join failed: \(error)")
            // Trip will still be accessible if user was already a member
        }
    }

    /// Process any pending invite code after sign-in completes.
    func processPendingInvite() async {
        guard let code = pendingInviteCode, let userId = currentUserId else { return }
        pendingInviteCode = nil
        await joinTripFromDeepLink(code: code, userId: userId)
    }

    func signOut() async {
        // Drain pending uploads BEFORE clearing local data, so sign-out can never
        // destroy writes that haven't reached Supabase yet.
        syncStatusTask?.cancel()
        let drained = await SyncManager.shared.waitForUploadsToComplete()
        if drained {
            await SyncManager.shared.disconnectAndClear()
            await ImageCache.shared.clearAll()
        } else {
            // Unsynced data remains — keep it on device rather than lose it.
            // It finishes uploading the next time this user signs in.
            await SyncManager.shared.disconnect()
            print("[Auth] ⚠️ Signed out with unsynced data retained locally")
        }
        resetSyncState()
        await authService.signOut()
        currentUserId = nil
        authStatus = .signedOut
    }

    /// Permanently delete the current user's account.
    /// Clears all local data and navigates to auth screen.
    func deleteAccount() async throws {
        // Account is being deleted server-side, so there is nothing to preserve —
        // clear all local data unconditionally.
        try await authService.deleteAccount()
        syncStatusTask?.cancel()
        await SyncManager.shared.disconnectAndClear()
        await ImageCache.shared.clearAll()
        resetSyncState()
        currentUserId = nil
        authStatus = .signedOut
    }

    // MARK: - Sync Lifecycle

    /// Reconnect sync if disconnected (called when app returns to foreground).
    /// Refreshes the auth token first so PowerSync gets a valid JWT.
    func ensureSyncConnected() async {
        guard authStatus == .signedIn, !isSyncConnected else { return }
        print("[Sync] Reconnecting on foreground...")
        do {
            // Refresh token before reconnecting — stale JWTs are the #1 cause
            // of PowerSync staying offline despite having internet.
            try await authService.refreshSession()
            print("[Sync] ✓ Token refreshed")
        } catch {
            print("[Sync] ⚠️ Token refresh failed (will try connect anyway): \(error)")
        }
        do {
            try await SyncManager.shared.connect(currentUserId: currentUserId)
            print("[Sync] ✓ Foreground reconnect succeeded")
        } catch {
            print("[Sync] ❌ Foreground reconnect failed: \(error)")
        }
    }

    private func connectSync() async {
        do {
            try await SyncManager.shared.connect(currentUserId: currentUserId)
            startWatchingSyncStatus()
            // Step 4 of auth refresh flow: resume media upload queue
            MediaUploadQueue.shared.resumePendingUploads()
        } catch {
            print("[Sync] ❌ Connect failed: \(error)")
        }
    }

    private func resetSyncState() {
        isSyncConnected = false
        hasSynced = false
        lastSyncedAt = nil
    }

    private func startWatchingSyncStatus() {
        syncStatusTask?.cancel()
        syncStatusTask = Task { [weak self] in
            var reconnectAttempts = 0
            let maxReconnectAttempts = 5
            for await status in SyncManager.shared.db.currentStatus.asFlow() {
                guard let self, !Task.isCancelled else { break }
                self.isSyncConnected = status.connected
                self.lastSyncedAt = status.lastSyncedAt
                if status.hasSynced == true {
                    self.hasSynced = true
                }

                if status.connected {
                    // Connection restored — reset retry counter
                    reconnectAttempts = 0
                } else if !status.connecting && self.authStatus == .signedIn && reconnectAttempts < maxReconnectAttempts {
                    // Connection dropped (not just in the process of connecting).
                    reconnectAttempts += 1
                    let delay = min(reconnectAttempts * 3, 15) // 3s, 6s, 9s, 12s, 15s
                    print("[Sync] ⚠️ Connection lost, reconnecting in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))...")
                    Task {
                        try? await Task.sleep(for: .seconds(delay))
                        guard !Task.isCancelled else { return }
                        // Refresh token before reconnecting — expired JWTs cause
                        // silent credential failures in SupabaseConnector.
                        do {
                            try await self.authService.refreshSession()
                        } catch {
                            print("[Sync] ⚠️ Token refresh failed: \(error)")
                        }
                        do {
                            try await SyncManager.shared.connect(currentUserId: self.currentUserId)
                            print("[Sync] ✓ Auto-reconnected")
                        } catch {
                            print("[Sync] ❌ Auto-reconnect failed: \(error)")
                        }
                    }
                }
            }
        }
    }
}
