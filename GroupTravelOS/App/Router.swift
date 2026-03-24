import SwiftUI

@MainActor
final class Router: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ destination: Destination) {
        path.append(destination)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}

enum Destination: Hashable {
    case tripTimeline(tripId: String)
    case blockDetail(blockId: String)
    case tripSummary(tripId: String)
    case archivedTrips
    case settings
}
