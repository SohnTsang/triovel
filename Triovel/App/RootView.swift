import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.authStatus {
            case .unknown:
                ProgressView(String(localized: "state.restoring.session"))
            case .signedOut:
                AuthView()
            case .verificationPending(let email):
                EmailVerificationView(
                    email: email,
                    authService: appState.authService,
                    onVerified: { appState.completeSignIn() },
                    onBack: { appState.cancelVerification() }
                )
            case .signedIn:
                HomeView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.authStatus)
        .task {
            await appState.restoreSession()
        }
        .onOpenURL { url in
            Task {
                await appState.handleDeepLink(url: url)
            }
        }
    }
}
