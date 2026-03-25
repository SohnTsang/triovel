import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false

    private var authService: AuthService { appState.authService }

    var body: some View {
        List {
            // Profile section — avatar (large, 64pt) + name + email
            Section {
                ProfileHeaderView(user: authService.currentUser)
            }

            // Account info
            Section(String(localized: "settings.account")) {
                SignInMethodRow(user: authService.currentUser)
            }

            // Legal
            Section(String(localized: "settings.legal")) {
                Button {
                    // Privacy Policy — hosted page before App Store
                } label: {
                    Label(String(localized: "settings.privacy.policy"), systemImage: "hand.raised")
                        .foregroundStyle(ColorTokens.label)
                }

                Button {
                    // Terms of Service — hosted page before App Store
                } label: {
                    Label(String(localized: "settings.terms"), systemImage: "doc.text")
                        .foregroundStyle(ColorTokens.label)
                }
            }

            // Danger zone — sign out + delete, plain red text
            Section {
                Button {
                    showingSignOutConfirmation = true
                } label: {
                    Text(String(localized: "settings.sign.out"))
                        .foregroundStyle(.red)
                }

                Button {
                    showingDeleteConfirmation = true
                } label: {
                    Text(String(localized: "settings.delete.account"))
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "settings.title"))
        .confirmationDialog(String(localized: "settings.sign.out.confirm"), isPresented: $showingSignOutConfirmation) {
            Button(String(localized: "settings.sign.out"), role: .destructive) {
                Task { await appState.signOut() }
            }
        }
        .confirmationDialog(
            String(localized: "settings.delete.confirm"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.delete.account"), role: .destructive) {
                // Full deletion flow — before App Store submission
            }
        } message: {
            Text("settings.delete.message")
        }
    }
}
