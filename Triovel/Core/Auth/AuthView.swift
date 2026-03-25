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
            } onCompletion: { _ in
                // The actual flow goes through AppleSignInCoordinator
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(10)
            .padding(.horizontal, 32)
            .overlay {
                // Invisible button to trigger our coordinator flow
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
        appleCoordinator.onError = { error in
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

// MARK: - Email Form (extracted to stay under 200 lines)

private struct EmailAuthFormView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isSignUp: Bool
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onSubmit: () -> Void

    var body: some View {
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
            }

            Button {
                onSubmit()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(isSignUp ? String(localized: "auth.sign.up") : String(localized: "auth.sign.in"))
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
}
