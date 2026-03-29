import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    private var authService: AuthService { appState.authService }

    var body: some View {
        List {
            // Profile section
            Section {
                ProfileHeaderView(user: authService.currentUser)
            }

            // Account info
            Section(String(localized: "settings.account")) {
                SignInMethodRow(user: authService.currentUser)
            }

            // Appearance
            Section(String(localized: "settings.appearance")) {
                Picker(String(localized: "settings.appearance.theme"), selection: $appearanceMode) {
                    Text("settings.appearance.light").tag(AppearanceMode.light)
                    Text("settings.appearance.dark").tag(AppearanceMode.dark)
                    Text("settings.appearance.system").tag(AppearanceMode.system)
                }
            }

            // Legal — placeholder slots per compliance.md
            Section(String(localized: "settings.legal")) {
                Button {
                    // Privacy Policy — link to hosted page before App Store submission
                } label: {
                    Label(String(localized: "settings.privacy.policy"), systemImage: "hand.raised")
                }

                Button {
                    // Terms of Service — link to hosted page before App Store submission
                } label: {
                    Label(String(localized: "settings.terms"), systemImage: "doc.text")
                }
            }

            // Danger zone
            Section {
                Button(role: .destructive) {
                    showingSignOutConfirmation = true
                } label: {
                    Label(String(localized: "settings.sign.out"), systemImage: "rectangle.portrait.and.arrow.right")
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label(String(localized: "settings.delete.account"), systemImage: "trash")
                }
            }
        }
        .navigationTitle(String(localized: "settings.title"))
        .plainBackButton()
        .alert(
            String(localized: "settings.sign.out.confirm"),
            isPresented: $showingSignOutConfirmation
        ) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "settings.sign.out"), role: .destructive) {
                Task { await appState.signOut() }
            }
        } message: {
            Text("settings.sign.out.message")
        }
        .alert(
            String(localized: "settings.delete.confirm"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "settings.delete.account"), role: .destructive) {
                // Full deletion flow — before App Store submission
            }
        } message: {
            Text("settings.delete.message")
        }
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable {
    case light
    case dark
    case system

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
