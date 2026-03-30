import SwiftUI

struct TripCardView: View {
    let trip: Trip
    let members: [TripMemberDisplay]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover image
            coverImage

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(trip.formattedDateRangeShort)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)

            if !members.isEmpty {
                MemberAvatarRow(members: members)
                    .padding(.horizontal, 2)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let path = trip.coverImagePath, !path.isEmpty {
            CachedMediaView(
                mediaId: "trip-cover-\(trip.id)",
                storagePath: path,
                mediaType: .photo
            )
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
                .frame(height: 100)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.quaternary)
                }
        }
    }
}

// MARK: - Member Avatar Row

struct MemberAvatarRow: View {
    let members: [TripMemberDisplay]

    private let maxVisible = 4

    var body: some View {
        HStack(spacing: -6) {
            ForEach(visibleMembers) { member in
                AvatarCircle(member: member)
            }

            if overflowCount > 0 {
                Text("+\(overflowCount)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color(.systemGray5), in: Circle())
                    .overlay { Circle().stroke(.white, lineWidth: 1.5) }
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
        Circle()
            .fill(Color(.systemGray4))
            .frame(width: 24, height: 24)
            .overlay {
                if member.avatarPath == nil {
                    Text(member.initials)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .overlay { Circle().stroke(.white, lineWidth: 1.5) }
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

    var formattedDateRangeShort: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return "\(f.string(from: startDate)) – \(f.string(from: endDate))"
    }
}
