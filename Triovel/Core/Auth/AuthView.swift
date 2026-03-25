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
        VStack(spacing: 0) {
            Spacer()

            // Top 40%: App branding — breathe
            VStack(spacing: 12) {
                Text("Triovel")
                    .font(TypographyTokens.appTitle)
                    .foregroundStyle(ColorTokens.label)

                Text("auth.subtitle")
                    .font(TypographyTokens.body)
                    .foregroundStyle(ColorTokens.secondaryLabel)
            }

            Spacer()
            Spacer()

            // Sign in with Apple — native, full-width, prominent
            VStack(spacing: 20) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { _ in }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    Button {
                        startAppleSignIn()
                    } label: {
                        Color.clear
                    }
                    .frame(height: 50)
                }

                // Divider with "or"
                HStack(spacing: 16) {
                    Rectangle().frame(height: 0.5).foregroundStyle(ColorTokens.separator)
                    Text("auth.or")
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.tertiaryLabel)
                    Rectangle().frame(height: 0.5).foregroundStyle(ColorTokens.separator)
                }

                // Email auth
                if showEmailForm {
                    EmailAuthFormView(
                        email: $email,
                        password: $password,
                        isSignUp: $isSignUp,
                        isLoading: $isLoading,
                        errorMessage: $errorMessage,
                        onSubmit: { authenticateWithEmail() }
                    )
                } else {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showEmailForm = true
                        }
                    } label: {
                        Text("auth.continue.email")
                    }
                    .buttonStyle(.triovelSecondary)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(height: 48)
        }
        .frame(maxWidth: sizeClass == .regular ? 440 : .infinity)
        .frame(maxWidth: .infinity)
        .onAppear {
            setupAppleCoordinator()
        }
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
                    errorMessage = String(localized: "auth.apple.failed")
                }
                isLoading = false
            }
        }
        appleCoordinator.onError = { _ in
            errorMessage = String(localized: "auth.apple.failed")
        }
    }

    // MARK: - Email Auth

    private func authenticateWithEmail() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                if isSignUp {
                    try await authService.signUp(email: email, password: password)
                } else {
                    try await authService.signIn(email: email, password: password)
                }
                appState.completeSignIn()
            } catch {
                errorMessage = authService.errorMessage
            }
            isLoading = false
        }
    }
}

// MARK: - Email Form

private struct EmailAuthFormView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isSignUp: Bool
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            TriovelTextField(
                placeholder: "auth.email.placeholder",
                text: $email,
                textContentType: .emailAddress,
                keyboardType: .emailAddress,
                autocapitalization: .never
            )

            TriovelTextField(
                placeholder: "auth.password.placeholder",
                text: $password,
                isSecure: true,
                textContentType: isSignUp ? .newPassword : .password
            )

            if let error = errorMessage {
                Text(error)
                    .font(TypographyTokens.caption)
                    .foregroundStyle(.red)
            }

            Button {
                onSubmit()
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(isSignUp ? String(localized: "auth.sign.up") : String(localized: "auth.sign.in"))
                }
            }
            .buttonStyle(.triovelPrimary)
            .disabled(email.isEmpty || password.isEmpty || isLoading)

            Button {
                isSignUp.toggle()
                errorMessage = nil
            } label: {
                Text(isSignUp
                    ? String(localized: "auth.switch.to.sign.in")
                    : String(localized: "auth.switch.to.sign.up"))
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(ColorTokens.accent)
            }
        }
    }
}
