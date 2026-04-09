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
        .background { RoundedRectangle(cornerRadius: 14).fill(ColorTokens.cardBackground) }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 2)
    }

    @ViewBuilder
    private var coverImage: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let path = trip.coverImagePath, !path.isEmpty {
                    CachedMediaView(
                        mediaId: "trip-cover-\(trip.id)",
                        storagePath: path,
                        mediaType: .photo
                    )
                } else {
                    Color(.systemGray5)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title3)
                                .foregroundStyle(.quaternary)
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
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

// MARK: - Trip Grid By Year

/// Groups trips by start year and displays as 2-column grids with year headers.
struct TripGridByYear: View {
    let trips: [Trip]
    let membersByTrip: [String: [TripMemberDisplay]]
    let onTripTap: (String) -> Void

    private var groupedByYear: [(year: Int, trips: [Trip])] {
        let cal = Calendar.current
        var groups: [Int: [Trip]] = [:]
        for trip in trips {
            let year = cal.component(.year, from: trip.startDate)
            groups[year, default: []].append(trip)
        }
        return groups.sorted { $0.key > $1.key }.map { (year: $0.key, trips: $0.value) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            ForEach(groupedByYear, id: \.year) { group in
                // Year header
                Text(String(group.year))
                    .font(.title3.weight(.bold))
                    .padding(.top, group.year == groupedByYear.first?.year ? 0 : 4)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(group.trips) { trip in
                        TripCardView(
                            trip: trip,
                            members: membersByTrip[trip.id] ?? []
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTripTap(trip.id)
                        }
                    }
                }
            }
        }
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
        let y = DateFormatter()
        y.dateFormat = "yyyy"
        return "\(f.string(from: startDate)) – \(f.string(from: endDate)), \(y.string(from: endDate))"
    }
}
