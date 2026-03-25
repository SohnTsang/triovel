import SwiftUI

struct TripCardView: View {
    let trip: Trip
    let members: [TripMemberDisplay]

    var body: some View {
        TriovelCard {
            VStack(alignment: .leading, spacing: 0) {
                // Cover image — 16:9 aspect ratio, clipped to top corners
                coverImage

                VStack(alignment: .leading, spacing: 8) {
                    Text(trip.title)
                        .font(TypographyTokens.cardTitle)
                        .foregroundStyle(ColorTokens.label)
                        .lineLimit(1)

                    Text(trip.formattedDateRange)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(ColorTokens.secondaryLabel)

                    if !members.isEmpty {
                        MemberAvatarRow(members: members)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        Rectangle()
            .fill(Color(.tertiarySystemBackground))
            .aspectRatio(16/9, contentMode: .fit)
            .overlay {
                if trip.coverImagePath != nil {
                    Color.clear
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .foregroundStyle(ColorTokens.tertiaryLabel)
                }
            }
    }
}

// MARK: - Member Avatar Row

struct MemberAvatarRow: View {
    let members: [TripMemberDisplay]
    private let maxVisible = 4

    var body: some View {
        HStack(spacing: -8) {
            ForEach(visibleMembers) { member in
                AvatarView(
                    initials: member.initials,
                    userId: member.userId,
                    size: 24
                )
                .overlay { Circle().stroke(ColorTokens.cardBackground, lineWidth: 2) }
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ColorTokens.secondaryLabel)
                    .frame(width: 24, height: 24)
                    .background(Color(.tertiarySystemBackground), in: Circle())
                    .overlay { Circle().stroke(ColorTokens.cardBackground, lineWidth: 2) }
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
