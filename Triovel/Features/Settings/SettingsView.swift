import SwiftUI
import SafariServices

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteError: String?
    @State private var safariURL: URL?
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

            // Legal
            Section(String(localized: "settings.legal")) {
                Button {
                    safariURL = URL(string: "https://sohntsang.github.io/triovel/privacy-policy.html")
                } label: {
                    Label(String(localized: "settings.privacy.policy"), systemImage: "hand.raised")
                }

                Button {
                    safariURL = URL(string: "https://sohntsang.github.io/triovel/terms-and-conditions.html")
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

            if let error = deleteError {
                Section {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
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
                performDeleteAccount()
            }
        } message: {
            Text("settings.delete.message")
        }
        .overlay {
            if isDeletingAccount {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .overlay { ProgressView().controlSize(.large).tint(.white) }
            }
        }
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
    }

    private func performDeleteAccount() {
        isDeletingAccount = true
        deleteError = nil

        Task {
            let start = ContinuousClock.now
            do {
                try await appState.deleteAccount()
                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
            } catch {
                print("[Settings] ❌ Delete account failed: \(error)")
                deleteError = String(localized: "settings.delete.error")
                isDeletingAccount = false
            }
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

// MARK: - URL Identifiable

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
