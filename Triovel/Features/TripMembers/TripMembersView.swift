import SwiftUI

struct TripMembersView: View {
    let tripId: String
    let members: [TripMemberDisplay]
    let inviteLink: String?

    @State private var inviteCode: String?
    @State private var isGeneratingLink = false
    @State private var showingCopied = false
    @State private var showingShareSheet = false
    @State private var errorMessage: String?

    private let tripRepository = TripRepository()

    /// Full shareable URL that opens the app or redirects to App Store.
    private var shareURL: String? {
        guard let code = inviteCode ?? inviteLink else { return nil }
        return "https://sohntsang.github.io/triovel/join?code=\(code)"
    }

    var body: some View {
        List {
            // Members
            Section {
                ForEach(sortedMembers) { member in
                    MemberRow(member: member)
                }
            }

            // Invite section — always shown
            Section {
                if let url = shareURL {
                    // Share button (native share sheet)
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label(String(localized: "members.invite.share"), systemImage: "square.and.arrow.up")
                    }

                    // Copy link
                    Button {
                        UIPasteboard.general.string = url
                        withAnimation { showingCopied = true }
                    } label: {
                        Label(String(localized: "trip.members.copy.link"), systemImage: "link")
                    }
                } else {
                    // Generate link button
                    Button {
                        generateLink()
                    } label: {
                        if isGeneratingLink {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("members.invite.generating")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Label(String(localized: "members.invite.create.link"), systemImage: "link.badge.plus")
                        }
                    }
                    .disabled(isGeneratingLink)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("trip.members.share.footer")
            }
        }
        .navigationTitle(String(localized: "trip.members.title"))
        .plainBackButton()
        .overlay {
            if showingCopied {
                copiedToast
            }
        }
        .onChange(of: showingCopied) { _, copied in
            if copied {
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingCopied = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [shareMessage(url: url)])
            }
        }
        .task {
            // Pre-load invite code
            inviteCode = inviteLink
        }
    }

    // MARK: - Generate Link

    private func generateLink() {
        isGeneratingLink = true
        errorMessage = nil

        Task {
            let start = ContinuousClock.now
            do {
                let code = try await tripRepository.ensureInviteLink(tripId: tripId)
                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }
                inviteCode = code
            } catch {
                print("[Members] ❌ Generate invite link failed: \(error)")
                errorMessage = String(localized: "members.invite.error")
            }
            isGeneratingLink = false
        }
    }

    // MARK: - Helpers

    private var sortedMembers: [TripMemberDisplay] {
        members.sorted { a, b in
            if a.role != b.role {
                return a.role == .owner
            }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    private func shareMessage(url: String) -> String {
        "Join my trip on Triovel!\n\n\(url)"
    }

    private var copiedToast: some View {
        VStack {
            Spacer()
            Text("trip.members.link.copied")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(.darkGray), in: Capsule())
                .padding(.bottom, 32)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.2), value: showingCopied)
    }
}

// MARK: - Share Sheet (UIKit wrapper)

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: TripMemberDisplay

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(member.initials)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.body)
                    .lineLimit(1)

                if member.role == .owner {
                    Text("trip.members.role.organizer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
