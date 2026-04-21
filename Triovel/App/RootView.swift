import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some View {
        Group {
            switch appState.authStatus {
            case .unknown:
                // Match launch screen exactly — no blank flash
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .overlay {
                        Image("LaunchIcon")
                            .offset(y: -20)
                    }
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
        .preferredColorScheme(appearanceMode.colorScheme)
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
