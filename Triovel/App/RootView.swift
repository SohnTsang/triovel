import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some View {
        Group {
            switch appState.authStatus {
            case .unknown:
                // Match launch screen storyboard: centerX, centerY - 20pt
                GeometryReader { geo in
                    Color(.systemBackground)
                        .ignoresSafeArea()
                        .overlay {
                            Image("LaunchIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 90, height: 60)
                                .position(
                                    x: geo.size.width / 2,
                                    y: geo.size.height / 2 - 20
                                )
                        }
                }
                .ignoresSafeArea()
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
