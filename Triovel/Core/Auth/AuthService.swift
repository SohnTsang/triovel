import Foundation
import Supabase
import Auth

/// Handles all authentication: Sign in with Apple, email/password,
/// session restore, and token refresh.
///
/// Auth refresh flow (per sync.md):
/// 1. Restore local session
/// 2. Refresh Supabase auth token if expired
/// 3. Resume data sync (Phase 2)
/// 4. Resume media queue (Phase 3)
@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentSession: Session?
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let client = SupabaseConfig.client

    // MARK: - Session Restore & Token Refresh

    /// Called on app launch to restore an existing session.
    /// If the session token is expired, Supabase SDK auto-refreshes it.
    func restoreSession() async -> Bool {
        do {
            let session = try await client.auth.session
            self.currentSession = session
            self.currentUser = session.user
            return true
        } catch {
            // No valid session — user needs to sign in
            self.currentSession = nil
            self.currentUser = nil
            return false
        }
    }

    /// Explicitly refresh the session token.
    /// Use after long offline periods before resuming sync.
    func refreshSession() async throws {
        let session = try await client.auth.refreshSession()
        self.currentSession = session
        self.currentUser = session.user
    }

    // MARK: - Sign in with Apple

    /// Complete Apple Sign-In using the identity token from ASAuthorization.
    /// Both Apple and email/password link to the same Supabase Auth user record.
    func signInWithApple(idToken: String, nonce: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            self.currentSession = session
            self.currentUser = session.user
        } catch {
            self.errorMessage = "Apple sign-in failed. Please try again."
            throw error
        }
    }

    // MARK: - Email / Password

    /// Sign up with email and password.
    func signUp(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )
            if let session = response.session {
                self.currentSession = session
                self.currentUser = session.user
            }
        } catch {
            self.errorMessage = "Sign up failed. Please try again."
            throw error
        }
    }

    /// Sign in with email and password.
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            self.currentSession = session
            self.currentUser = session.user
        } catch {
            self.errorMessage = "Sign in failed. Check your credentials."
            throw error
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Even if remote sign-out fails, clear local state
        }
        currentSession = nil
        currentUser = nil
    }
}
