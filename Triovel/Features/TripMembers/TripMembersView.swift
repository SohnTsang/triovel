import SwiftUI

struct TripMembersView: View {
    let tripId: String
    let members: [TripMemberDisplay]
    let inviteLink: String?

    @State private var showingCopied = false

    var body: some View {
        List {
            Section {
                ForEach(sortedMembers) { member in
                    MemberRow(member: member)
                }
            }

            if let link = inviteLink, !link.isEmpty {
                Section {
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

// MARK: - Member Row

private struct MemberRow: View {
    let member: TripMemberDisplay

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                if member.avatarPath != nil {
                    Circle().fill(Color(.systemGray4))
                } else {
                    Circle()
                        .fill(Color(.systemGray4))
                        .overlay {
                            Text(member.initials)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                        }
                }
            }
            .frame(width: 40, height: 40)

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
