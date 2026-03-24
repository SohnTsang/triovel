import SwiftUI

/// Subtle indicator for sync/pending/failed states on cards.
enum SyncState: Sendable {
    case synced
    case pending
    case syncing
    case failed
}

struct SyncStateIndicator: View {
    let state: SyncState

    var body: some View {
        switch state {
        case .synced:
            EmptyView()
        case .pending:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(ColorTokens.pendingTint)
        case .syncing:
            ProgressView()
                .scaleEffect(0.6)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundStyle(ColorTokens.failedTint)
        }
    }
}
