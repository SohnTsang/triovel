import AuthenticationServices
import CryptoKit
import Foundation

/// Coordinates the Sign in with Apple flow.
/// Generates a nonce, presents the Apple auth sheet, and returns
/// the identity token + nonce for Supabase to verify.
@MainActor
final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    /// Called on successful Apple authorization with (idToken, nonce).
    var onCompletion: ((String, String) -> Void)?
    var onError: ((Error) -> Void)?

    private var currentNonce: String?

    // MARK: - Start Sign In

    func startSignInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else {
            return
        }

        Task { @MainActor in
            guard let nonce = currentNonce else { return }
            onCompletion?(idToken, nonce)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // User cancelled or auth failed
        Task { @MainActor in
            if (error as? ASAuthorizationError)?.code != .canceled {
                onError?(error)
            }
        }
    }

    // MARK: - Presentation Context

    @MainActor
    func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        // Return the key window for presenting the Apple Sign-In sheet
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first
        else {
            return ASPresentationAnchor()
        }
        return window
    }

    // MARK: - Nonce Helpers

    /// Generate a random nonce string for Apple Sign-In.
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            // Fallback to UUID-based nonce if SecRandom fails
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    /// SHA256 hash of the nonce for Apple's servers.
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
