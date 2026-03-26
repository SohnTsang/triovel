import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false

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

            // Danger zone — triggers confirmationDialogs, not inline destructive actions
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
        .confirmationDialog(
            String(localized: "settings.sign.out.confirm"),
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.sign.out"), role: .destructive) {
                Task { await appState.signOut() }
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text("settings.sign.out.message")
        }
        .confirmationDialog(
            String(localized: "settings.delete.confirm"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.delete.account"), role: .destructive) {
                // Full deletion flow — before App Store submission
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text("settings.delete.message")
        }
    }
}
