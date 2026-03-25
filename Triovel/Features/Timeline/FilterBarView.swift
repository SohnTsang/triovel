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

    var body: some View {
        Picker("Filter", selection: $activeFilter) {
            ForEach(TimelineFilter.allCases, id: \.self) { filter in
                Text(filter.localizedName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
