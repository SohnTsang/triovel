import SwiftUI

struct TripMembersView: View {
    let tripId: String
    let members: [TripMemberDisplay]
    let inviteLink: String?

    @State private var showingCopied = false
    @State private var showingShareSheet = false

    var body: some View {
        List {
            // Members
            Section {
                ForEach(sortedMembers) { member in
                    MemberRow(member: member)
                }
            }

            // Solo trip hint
            if members.count <= 1 {
                Section {
                    Button {
                        if inviteLink != nil {
                            showingShareSheet = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                            Text("members.invite.only.you")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }

            // Share section
            if let link = inviteLink, !link.isEmpty {
                Section {
                    // Share button (native share sheet)
                    Button {
                        showingShareSheet = true
                    } label: {
                        Label(String(localized: "members.invite.share"), systemImage: "square.and.arrow.up")
                    }

                    // Copy link
                    Button {
                        UIPasteboard.general.string = link
                        showingCopied = true
                    } label: {
                        Label(String(localized: "trip.members.copy.link"), systemImage: "link")
                    }
                } footer: {
                    Text("trip.members.share.footer")
                }
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
            if let link = inviteLink {
                ShareSheet(items: [shareMessage(link: link)])
            }
        }
    }

    /// Owners first, then alphabetical by name.
    private var sortedMembers: [TripMemberDisplay] {
        members.sorted { a, b in
            if a.role != b.role {
                return a.role == .owner
            }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    private func shareMessage(link: String) -> String {
        "Join my trip on Triovel!\n\nInvite code: \(link)"
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
