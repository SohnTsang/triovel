import Foundation
import Supabase
import Auth

/// Handles all authentication: Sign in with Apple, email/password,
/// session restore, token refresh, and email verification.
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
    func signInWithApple(idToken: String, nonce: String) async throws {
        isLoading = true
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
            throw AuthError.appleSignInFailed
        }
    }

    // MARK: - Email / Password

    /// Sign up with email and password.
    /// Returns the email so the verification screen can display it.
    /// Does NOT set current session — user must verify email first.
    @discardableResult
    func signUp(email: String, password: String) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )
            // Check if email confirmation is required (no session means pending verification)
            if response.session != nil {
                // Auto-confirmed (e.g. dev environment) — set session
                self.currentSession = response.session
                self.currentUser = response.session?.user
            }
            // If no session, email verification is pending — caller handles this
            return email
        } catch {
            throw classifySignUpError(error)
        }
    }

    /// Whether the last sign-up produced a session (auto-confirmed) or not (needs verification).
    var hasSessionAfterSignUp: Bool {
        currentSession != nil
    }

    /// Sign in with email and password.
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(
                email: email,
                password: password
            )
            self.currentSession = session
            self.currentUser = session.user
        } catch {
            throw classifySignInError(error)
        }
    }

    // MARK: - Email Verification

    /// Resend the verification email to the given address.
    func resendVerificationEmail(to email: String) async throws {
        do {
            try await client.auth.resend(.signup, email: email)
        } catch {
            throw AuthError.networkError
        }
    }

    /// Handle the auth callback URL (triovel://auth-callback).
    /// Supabase encodes the token in the URL fragment.
    func handleAuthCallback(url: URL) async throws {
        do {
            let session = try await client.auth.session(from: url)
            self.currentSession = session
            self.currentUser = session.user
        } catch {
            throw AuthError.verificationExpired
        }
    }

    // MARK: - Sign Out

    /// Returns true on success, false if remote sign-out failed (local state still cleared).
    @discardableResult
    func signOut() async -> Bool {
        do {
            try await client.auth.signOut()
            clearLocalState()
            return true
        } catch {
            // Clear local state even if remote fails
            clearLocalState()
            return false
        }
    }

    private func clearLocalState() {
        currentSession = nil
        currentUser = nil
    }

    // MARK: - Error Classification

    private func classifySignUpError(_ error: Error) -> AuthError {
        let message = error.localizedDescription.lowercased()
        if message.contains("already registered") || message.contains("already exists") || message.contains("duplicate") {
            return .emailTaken
        }
        if message.contains("password") && (message.contains("weak") || message.contains("short") || message.contains("least")) {
            return .weakPassword
        }
        if message.contains("network") || message.contains("connection") || message.contains("offline") {
            return .networkError
        }
        return .networkError
    }

    private func classifySignInError(_ error: Error) -> AuthError {
        let message = error.localizedDescription.lowercased()
        if message.contains("invalid") || message.contains("credentials") || message.contains("wrong") || message.contains("not found") {
            return .wrongCredentials
        }
        if message.contains("confirm") || message.contains("verify") || message.contains("not confirmed") {
            return .emailNotVerified
        }
        if message.contains("network") || message.contains("connection") || message.contains("offline") {
            return .networkError
        }
        return .wrongCredentials
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case appleSignInFailed
    case emailTaken
    case weakPassword
    case wrongCredentials
    case emailNotVerified
    case networkError
    case verificationExpired
    case signOutFailed

    var localizedKey: String {
        switch self {
        case .appleSignInFailed: return "auth.error.apple.failed"
        case .emailTaken: return "auth.error.email.taken"
        case .weakPassword: return "auth.error.weak.password"
        case .wrongCredentials: return "auth.error.wrong.credentials"
        case .emailNotVerified: return "auth.error.not.verified"
        case .networkError: return "auth.error.network"
        case .verificationExpired: return "auth.error.verification.expired"
        case .signOutFailed: return "auth.error.sign.out.failed"
        }
    }

    var errorDescription: String? {
        String(localized: String.LocalizationValue(localizedKey))
    }
}
