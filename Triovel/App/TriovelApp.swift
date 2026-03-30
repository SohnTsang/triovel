import SwiftUI

@main
struct TriovelApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Reconnect sync when app returns to foreground
                Task { await appState.ensureSyncConnected() }
            }
        }
    }
}
