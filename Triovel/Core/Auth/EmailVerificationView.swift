import SwiftUI

/// Shown after email sign-up when verification is required.
/// User must tap email link before landing on Home.
struct EmailVerificationView: View {
    let email: String
    let authService: AuthService
    let onVerified: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isResending = false
    @State private var resendSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "envelope.badge")
                .font(.system(size: 56))
                .foregroundStyle(.accentColor)

            Text("auth.verify.title")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("auth.verify.subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(email)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if resendSuccess {
                Text("auth.verify.resent")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Button {
                resendEmail()
            } label: {
                if isResending {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("auth.verify.resend")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isResending)
            .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: sizeClass == .regular ? 500 : .infinity)
        .frame(maxWidth: .infinity)
    }

    private func resendEmail() {
        isResending = true
        errorMessage = nil
        resendSuccess = false

        Task {
            do {
                try await authService.resendVerificationEmail(to: email)
                resendSuccess = true
            } catch {
                errorMessage = String(localized: "auth.error.network")
            }
            isResending = false
        }
    }
}
