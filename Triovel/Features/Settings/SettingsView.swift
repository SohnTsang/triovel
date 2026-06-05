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
    @State private var displayName = ""
    @State private var isSavingName = false
    @State private var quarantineCount = 0
    @State private var isRetryingSync = false
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @FocusState private var nameFocused: Bool

    private var authService: AuthService { appState.authService }

    var body: some View {
        List {
            // Profile section
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            TextField(String(localized: "settings.display.name.placeholder"), text: $displayName)
                                .font(.headline)
                                .focused($nameFocused)
                                .submitLabel(.done)
                                .onChange(of: displayName) { _, v in
                                    if v.count > 50 { displayName = String(v.prefix(50)) }
                                }
                                .onSubmit { saveDisplayName() }

                            if isSavingName {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "pencil")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(authService.currentUser?.email ?? String(localized: "settings.no.email"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture { nameFocused = true }
            }

            // Account info
            Section(String(localized: "settings.account")) {
                SignInMethodRow(user: authService.currentUser)
            }

            // Sync issues — only shown when the server permanently rejected writes.
            // After the fix this should stay empty; it's a safety net so rejected
            // data is visible and retryable rather than silently lost.
            if quarantineCount > 0 {
                Section(String(localized: "settings.sync.section")) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(String(localized: "settings.sync.failed.title"), systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                                .font(.subheadline)
                            Spacer()
                            Text("\(quarantineCount)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                        }
                        Text(String(localized: "settings.sync.failed.detail"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)

                    Button {
                        retrySync()
                    } label: {
                        HStack {
                            Label(String(localized: "settings.sync.retry"), systemImage: "arrow.clockwise")
                            if isRetryingSync {
                                Spacer()
                                ProgressView().controlSize(.small)
                            }
                        }
                    }
                    .disabled(isRetryingSync)

                    Button(role: .destructive) {
                        dismissSyncIssues()
                    } label: {
                        Label(String(localized: "settings.sync.dismiss"), systemImage: "trash")
                    }
                    .disabled(isRetryingSync)
                }
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
                    safariURL = URL(string: "https://sohntsang.github.io/triovel/privacy-policy")
                } label: {
                    Label(String(localized: "settings.privacy.policy"), systemImage: "hand.raised")
                }

                Button {
                    safariURL = URL(string: "https://sohntsang.github.io/triovel/terms-and-conditions")
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
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(String(localized: "settings.title"))
        .plainBackButton()
        .onChange(of: nameFocused) { _, focused in
            if !focused && !isSavingName {
                saveDisplayName()
            }
        }
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
        .task {
            await loadDisplayName()
            await refreshQuarantineCount()
        }
    }

    // MARK: - Sync Quarantine

    private func refreshQuarantineCount() async {
        quarantineCount = await SyncQuarantineRepository().count()
    }

    private func retrySync() {
        isRetryingSync = true
        Task {
            let start = ContinuousClock.now
            await SyncQuarantineRepository().retryAll()
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }
            await refreshQuarantineCount()
            isRetryingSync = false
        }
    }

    private func dismissSyncIssues() {
        Task {
            try? await SyncQuarantineRepository().clearAll()
            await refreshQuarantineCount()
        }
    }

    private func loadDisplayName() async {
        guard let userId = appState.currentUserId else { return }
        do {
            let name: String? = try await SyncManager.shared.db.getOptional(
                sql: "SELECT display_name FROM users WHERE id = ?",
                parameters: [userId],
                mapper: { try $0.getString(name: "display_name") }
            )
            displayName = name ?? ""
        } catch {
            // Fall back to auth metadata
            if let metadata = authService.currentUser?.userMetadata,
               let name = metadata["full_name"]?.value as? String {
                displayName = name
            }
        }
    }

    private func saveDisplayName() {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let userId = appState.currentUserId else { return }
        isSavingName = true
        nameFocused = false

        Task {
            let start = ContinuousClock.now
            do {
                try await SyncManager.shared.db.execute(
                    sql: "UPDATE users SET display_name = ? WHERE id = ?",
                    parameters: [trimmed, userId]
                )
            } catch {
                print("[Settings] ❌ Update display name failed: \(error)")
            }
            let elapsed = ContinuousClock.now - start
            if elapsed < .milliseconds(500) {
                try? await Task.sleep(for: .milliseconds(500) - elapsed)
            }
            isSavingName = false
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
