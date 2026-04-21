import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @Environment(AppState.self) private var appState
    @State private var appleCoordinator = AppleSignInCoordinator()
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showResetPassword = false
    @State private var resetEmailSent = false
    @FocusState private var focusedField: AuthField?

    private enum AuthField: Hashable {
        case email, password, confirmPassword
    }

    private var authService: AuthService { appState.authService }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Top section — branding
                    VStack(spacing: 8) {
                        Text("Triovel")
                            .font(.custom("Pacifico-Regular", size: 32))
                            .foregroundStyle(Color.accentColor)

                        Text("auth.subtitle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 48)

                    // Primary: Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { _ in }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
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

                    // Divider: line — or — line
                    HStack(spacing: 16) {
                        Rectangle().frame(height: 0.5).foregroundStyle(.quaternary)
                        Text("auth.or")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Rectangle().frame(height: 0.5).foregroundStyle(.quaternary)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)

                    // Email form — different between Sign In and Sign Up
                    emailForm
                        .animation(.easeInOut(duration: 0.2), value: isSignUp)

                    Spacer().frame(height: 32)
                }
                .frame(maxWidth: sizeClass == .regular ? 500 : .infinity)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
        }
        .onTapGesture {
            focusedField = nil
        }
        .onAppear {
            setupAppleCoordinator()
        }
        .sheet(isPresented: $showResetPassword) {
            ResetPasswordSheet(authService: authService) { sent in
                if sent {
                    resetEmailSent = true
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Email Form

    @ViewBuilder
    private var emailForm: some View {
        VStack(spacing: 12) {
            // Email
            TextField("auth.email.placeholder", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: .email)
                .authField(isFocused: focusedField == .email)

            // Password
            SecureField("auth.password.placeholder", text: $password)
                .textContentType(isSignUp ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .authField(isFocused: focusedField == .password)

            // Confirm password — only in Sign Up mode
            if isSignUp {
                SecureField("auth.confirm.password.placeholder", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirmPassword)
                    .authField(isFocused: focusedField == .confirmPassword)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Forgot password — sign-in mode only
            if !isSignUp {
                HStack {
                    Spacer()
                    Button {
                        showResetPassword = true
                        errorMessage = nil
                    } label: {
                        Text("auth.forgot.password")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            // Reset email sent confirmation
            if resetEmailSent {
                Text("auth.reset.sent")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            // Submit button — FIXED frame, never resizes
            Button {
                authenticateWithEmail()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isSignUp
                            ? String(localized: "auth.create.account")
                            : String(localized: "auth.sign.in"))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .disabled(!isFormValid || isLoading)
            .padding(.top, 4)

            // Mode switch link
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSignUp.toggle()
                    confirmPassword = ""
                    errorMessage = nil
                    resetEmailSent = false
                }
            } label: {
                Text(isSignUp
                    ? String(localized: "auth.switch.to.sign.in")
                    : String(localized: "auth.switch.to.sign.up"))
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
    }

    private var isFormValid: Bool {
        let hasEmail = !email.isEmpty
        let hasPassword = !password.isEmpty
        if isSignUp {
            return hasEmail && hasPassword && !confirmPassword.isEmpty && password == confirmPassword
        }
        return hasEmail && hasPassword
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
        // Validate confirm password match
        if isSignUp && password != confirmPassword {
            errorMessage = String(localized: "auth.error.passwords.mismatch")
            return
        }

        Task {
            isLoading = true
            errorMessage = nil
            do {
                if isSignUp {
                    let result = try await authService.signUp(email: email, password: password)
                    if result.needsVerification {
                        appState.awaitVerification(email: result.email)
                    } else {
                        appState.completeSignIn()
                    }
                } else {
                    try await authService.signIn(email: email, password: password)
                    appState.completeSignIn()
                }
            } catch let authError as AuthError {
                if authError == .emailNotVerified {
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

// MARK: - Reset Password Sheet

private struct ResetPasswordSheet: View {
    let authService: AuthService
    let onSent: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var resetEmail = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sent = false
    @FocusState private var emailFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Text("auth.reset.title")
                .font(.title2.weight(.semibold))
                .padding(.top, 24)

            Text("auth.reset.subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            TextField("auth.email.placeholder", text: $resetEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($emailFocused)
                .authField(isFocused: emailFocused)
                .padding(.horizontal, 32)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if sent {
                Text("auth.reset.sent")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                sendReset()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("auth.reset.send")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .disabled(resetEmail.isEmpty || isLoading || sent)
            .padding(.horizontal, 32)

            Spacer()
        }
        .onAppear {
            emailFocused = true
        }
    }

    private func sendReset() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                try await authService.resetPassword(email: resetEmail)
                sent = true
                onSent(true)
            } catch let authError as AuthError {
                errorMessage = authError.errorDescription
            } catch {
                errorMessage = String(localized: "auth.error.network")
            }
            isLoading = false
        }
    }
}

// MARK: - Auth Field Style

struct AuthFieldModifier: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isFocused ? Color.accentColor : Color(.systemGray3),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

extension View {
    func authField(isFocused: Bool) -> some View {
        modifier(AuthFieldModifier(isFocused: isFocused))
    }
}
