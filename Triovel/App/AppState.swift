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

    let authService = AuthService()

    /// Called on app launch. Follows the auth refresh flow from sync.md:
    /// 1. Restore local session
    /// 2. Refresh auth token if expired (handled by Supabase SDK automatically)
    /// 3. Resume data sync (Phase 2)
    /// 4. Resume media queue (Phase 3)
    func restoreSession() async {
        let restored = await authService.restoreSession()
        if restored, let user = authService.currentUser {
            currentUserId = user.id.uuidString.lowercased()
            print("[Auth] Session restored, userId: \(currentUserId ?? "nil")")
            authStatus = .signedIn
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
                // The error is surfaced via the AuthError type
            }

        case "trip":
            // triovel://trip/{invite_code} — handle in Phase 1 follow-up
            break

        default:
            // Malformed deep link — navigate to Home if signed in, ignore otherwise
            break
        }
    }

    func signOut() async {
        await authService.signOut()
        currentUserId = nil
        authStatus = .signedOut
    }
}
