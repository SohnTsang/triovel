import Foundation

/// Tracks per-trip cumulative storage and applies compression escalation.
///
/// Thresholds (per scope-control.md):
///   1.5GB: one-time calm notice
///   2.0GB: auto-increase compression (photo → ~800KB, video → ~15MB)
///   5.0GB: pause remote sync, content stays local
enum MediaCostController {

    static let softCeiling: Int64 = 1_500_000_000   // 1.5 GB
    static let compressionCeiling: Int64 = 2_000_000_000  // 2 GB
    static let hardCeiling: Int64 = 5_000_000_000    // 5 GB

    /// Returns compression targets based on current trip storage.
    static func compressionTargets(tripStorageBytes: Int64) -> (photoBytes: Int, videoBytes: Int) {
        if tripStorageBytes >= compressionCeiling {
            // Past 2GB: increase compression
            return (photoBytes: 800_000, videoBytes: 15_000_000)
        }
        // Normal targets
        return (photoBytes: 1_500_000, videoBytes: 30_000_000)
    }

    /// Whether uploads should be paused (past 5GB hard ceiling).
    static func shouldPauseUploads(tripStorageBytes: Int64) -> Bool {
        tripStorageBytes >= hardCeiling
    }

    /// Check if a storage warning should be shown.
    static func storageWarning(tripStorageBytes: Int64) -> StorageWarning? {
        if tripStorageBytes >= hardCeiling {
            return .full
        } else if tripStorageBytes >= compressionCeiling {
            return .exceeded
        } else if tripStorageBytes >= softCeiling {
            return .approaching
        }
        return nil
    }
}

enum StorageWarning: Sendable {
    case approaching   // 1.5 GB — one-time calm notice
    case exceeded      // 2.0 GB — compression escalated silently
    case full          // 5.0 GB — uploads paused
}
