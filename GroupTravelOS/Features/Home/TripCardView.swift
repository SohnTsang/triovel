import SwiftUI

struct TripCardView: View {
    let trip: Trip
    let members: [TripMemberDisplay]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cover image area
            coverImage

            VStack(alignment: .leading, spacing: 6) {
                Text(trip.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(trip.formattedDateRange)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            // Member avatars
            if !members.isEmpty {
                MemberAvatarRow(members: members)
                    .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    @ViewBuilder
    private var coverImage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray5))
            .frame(height: 140)
            .overlay {
                if trip.coverImagePath != nil {
                    // Actual image loading comes with media pipeline (Phase 3)
                    Color.clear
                } else {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundStyle(.quaternary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Member Avatar Row

struct MemberAvatarRow: View {
    let members: [TripMemberDisplay]

    /// Show at most 5 avatars, then a +N overflow chip.
    private let maxVisible = 5

    var body: some View {
        HStack(spacing: -8) {
            ForEach(visibleMembers) { member in
                AvatarCircle(member: member)
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.systemGray5), in: Circle())
                    .overlay { Circle().stroke(.white, lineWidth: 2) }
            }
        }
    }

    private var visibleMembers: [TripMemberDisplay] {
        Array(members.prefix(maxVisible))
    }

    private var overflowCount: Int {
        max(0, members.count - maxVisible)
    }
}

// MARK: - Single Avatar

private struct AvatarCircle: View {
    let member: TripMemberDisplay

    var body: some View {
        ZStack {
            if member.avatarPath != nil {
                // Actual avatar loading comes with media pipeline
                Circle().fill(Color(.systemGray4))
            } else {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay {
                        Text(member.initials)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(width: 28, height: 28)
        .overlay { Circle().stroke(.white, lineWidth: 2) }
    }
}

// MARK: - Date Formatting

extension Trip {
    var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) – \(end)"
    }
}
