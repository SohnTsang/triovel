import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
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
            Section("Account") {
                SignInMethodRow(user: authService.currentUser)
            }

            // Legal — placeholder slots per compliance.md
            Section("Legal") {
                Button {
                    // Privacy Policy — link to hosted page before App Store submission
                } label: {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }

                Button {
                    // Terms of Service — link to hosted page before App Store submission
                } label: {
                    Label("Terms of Service", systemImage: "doc.text")
                }
            }

            // Danger zone
            Section {
                Button(role: .destructive) {
                    showingSignOutConfirmation = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Sign out?", isPresented: $showingSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task { await appState.signOut() }
            }
        }
        .confirmationDialog(
            "Delete account?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                // Full deletion flow — before App Store submission
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This cannot be undone.")
        }
    }
}
