import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum AuthStatus {
        case unknown
        case signedOut
        case signedIn
    }

    @Published var authStatus: AuthStatus = .unknown
    @Published var currentUserId: String?

    let authService = AuthService()

    /// Called on app launch. Follows the auth refresh flow from sync.md:
    /// 1. Restore local session
    /// 2. Refresh auth token if expired (handled by Supabase SDK automatically)
    /// 3. Resume data sync (Phase 2)
    /// 4. Resume media queue (Phase 3)
    func restoreSession() async {
        let restored = await authService.restoreSession()
        if restored, let user = authService.currentUser {
            currentUserId = user.id.uuidString
            authStatus = .signedIn
            // Phase 2: resume PowerSync data sync here
            // Phase 3: resume media upload queue here
        } else {
            authStatus = .signedOut
        }
    }

    /// Called after successful sign-in (Apple or email/password).
    func completeSignIn() {
        guard let user = authService.currentUser else { return }
        currentUserId = user.id.uuidString
        authStatus = .signedIn
    }

    func signOut() async {
        await authService.signOut()
        currentUserId = nil
        authStatus = .signedOut
    }
}
