import SwiftUI

enum TimelineFilter: String, CaseIterable, Sendable {
    case all = "All"
    case group = "Group"
    case personal = "Personal"

    var localizedName: String {
        switch self {
        case .all: return String(localized: "timeline.filter.all")
        case .group: return String(localized: "timeline.filter.group")
        case .personal: return String(localized: "timeline.filter.personal")
        }
    }
}

struct FilterBarView: View {
    @Binding var activeFilter: TimelineFilter
    @Binding var selectedPersonId: String?

    /// People who have personal blocks (for person chip filtering).
    var personalBlockAuthors: [PersonChipData]

    var body: some View {
        VStack(spacing: 8) {
            Picker("timeline.filter.label", selection: $activeFilter) {
                ForEach(TimelineFilter.allCases, id: \.self) { filter in
                    Text(filter.localizedName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: activeFilter) { _, newValue in
                // Clear person selection when switching away from Personal
                if newValue != .personal {
                    selectedPersonId = nil
                }
            }

            // Person chips — only when Personal is selected and multiple people exist
            if activeFilter == .personal && personalBlockAuthors.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "All personal" chip
                        PersonChip(
                            name: String(localized: "timeline.filter.personal.all"),
                            isSelected: selectedPersonId == nil,
                            onTap: { selectedPersonId = nil }
                        )

                        ForEach(personalBlockAuthors) { person in
                            PersonChip(
                                name: person.displayName,
                                isSelected: selectedPersonId == person.userId,
                                onTap: { selectedPersonId = person.userId }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Person Chip

private struct PersonChip: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(name)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? Color.accentColor.opacity(0.15)
                        : Color(.tertiarySystemBackground)
                )
                .foregroundStyle(isSelected ? Color.accentColor : ColorTokens.secondaryLabel)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Person Chip Data

struct PersonChipData: Identifiable, Sendable {
    let userId: String
    let displayName: String

    var id: String { userId }
}
