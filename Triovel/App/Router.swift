import Observation
import SwiftUI

@Observable
@MainActor
final class Router {
    var path = NavigationPath()

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
    case tripMembers(tripId: String, members: [TripMemberDisplay], inviteLink: String?)
    case tripMedia(tripId: String)
    case tripFiles(tripId: String)
    case archivedTrips
    case settings
}
