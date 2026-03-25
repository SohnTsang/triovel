import SwiftUI

enum TimelineFilter: String, CaseIterable, Sendable {
    case all = "All"
    case group = "Group"
    case personal = "Personal"
}

struct FilterBarView: View {
    @Binding var activeFilter: TimelineFilter

    var body: some View {
        Picker("Filter", selection: $activeFilter) {
            ForEach(TimelineFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
