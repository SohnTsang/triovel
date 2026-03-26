import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var appleCoordinator = AppleSignInCoordinator()
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showEmailForm = false
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var authService: AuthService { appState.authService }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App branding
            VStack(spacing: 8) {
                Text("Triovel")
                    .font(.largeTitle.weight(.bold))
                Text("auth.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Primary: Sign in with Apple
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { _ in }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
            .padding(.horizontal, 32)
            .overlay {
                Button {
                    startAppleSignIn()
                } label: {
                    Color.clear
                }
                .frame(height: 50)
                .padding(.horizontal, 32)
            }

            // Divider
            HStack {
                Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                Text("auth.or")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Rectangle().frame(height: 1).foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 32)

            // Secondary: Email / Password
            if showEmailForm {
                emailFormContent
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showEmailForm = true
                    }
                } label: {
                    Text("auth.continue.email")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal, 32)
            }

            Spacer()
                .frame(height: 32)
        }
        .frame(maxWidth: sizeClass == .regular ? 500 : .infinity)
        .frame(maxWidth: .infinity)
        .onAppear {
            setupAppleCoordinator()
        }
    }

    // MARK: - Email Form

    @ViewBuilder
    private var emailFormContent: some View {
        VStack(spacing: 12) {
            TextField("auth.email.placeholder", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))

            SecureField("auth.password.placeholder", text: $password)
                .textContentType(isSignUp ? .newPassword : .password)
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                authenticateWithEmail()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(isSignUp
                        ? String(localized: "auth.sign.up")
                        : String(localized: "auth.sign.in"))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(email.isEmpty || password.isEmpty || isLoading)

            Button {
                isSignUp.toggle()
                errorMessage = nil
            } label: {
                Text(isSignUp
                    ? String(localized: "auth.switch.to.sign.in")
                    : String(localized: "auth.switch.to.sign.up"))
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Apple Sign-In

    private func startAppleSignIn() {
        appleCoordinator.startSignInWithApple()
    }

    private func setupAppleCoordinator() {
        appleCoordinator.onCompletion = { idToken, nonce in
            Task {
                isLoading = true
                errorMessage = nil
                do {
                    try await authService.signInWithApple(idToken: idToken, nonce: nonce)
                    appState.completeSignIn()
                } catch {
                    errorMessage = (error as? AuthError)?.errorDescription
                        ?? String(localized: "auth.error.apple.failed")
                }
                isLoading = false
            }
        }
        appleCoordinator.onError = { _ in
            // User cancelled — do nothing per user-flows.md
        }
    }

    // MARK: - Email Auth

    private func authenticateWithEmail() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                if isSignUp {
                    let result = try await authService.signUp(email: email, password: password)
                    if result.needsVerification {
                        // Show verification screen — user must confirm email
                        appState.awaitVerification(email: result.email)
                    } else {
                        // Auto-confirmed (dev) — go to Home
                        appState.completeSignIn()
                    }
                } else {
                    try await authService.signIn(email: email, password: password)
                    appState.completeSignIn()
                }
            } catch let authError as AuthError {
                if authError == .emailNotVerified {
                    // Sign-in blocked by unverified email — show verification screen
                    appState.awaitVerification(email: email)
                } else {
                    errorMessage = authError.errorDescription
                }
            } catch {
                errorMessage = String(localized: "auth.error.network")
            }
            isLoading = false
        }
    }
}
