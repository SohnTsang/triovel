import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.authStatus {
            case .unknown:
                ProgressView("Restoring session…")
            case .signedOut:
                AuthView()
            case .signedIn:
                HomeView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.authStatus)
        .task {
            await appState.restoreSession()
        }
    }
}
