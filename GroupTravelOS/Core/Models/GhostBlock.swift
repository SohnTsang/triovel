import Foundation

/// Ghost blocks are UI-only scaffolding — never persisted to DB.
/// They provide structure for empty days (Breakfast, Lunch, Dinner).
struct GhostBlock: Identifiable, Hashable, Sendable {
    let id: String
    let dayDate: Date
    let label: GhostBlockLabel
    let suggestedTime: Date

    var title: String { label.rawValue }
}

enum GhostBlockLabel: String, CaseIterable, Sendable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"

    /// Default hour of day for each ghost block.
    var defaultHour: Int {
        switch self {
        case .breakfast: return 8
        case .lunch: return 12
        case .dinner: return 19
        }
    }
}
