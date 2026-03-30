import Foundation

/// Lightweight, privacy-safe local analytics for beta testing.
/// No third-party SDK, no user-identifiable data, no content tracking.
/// All counters stored in UserDefaults — read by the team, not uploaded.
enum BetaAnalytics {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    // MARK: - Track Events

    static func trackTripCreated() {
        increment("analytics.trips.created")
    }

    static func trackBlockCreated(context: String) {
        increment("analytics.blocks.created.\(context)")
    }

    static func trackPostCreated(visibility: String) {
        increment("analytics.posts.created.\(visibility)")
    }

    static func trackBillCreated() {
        increment("analytics.bills.created")
    }

    static func trackPaymentRecorded() {
        increment("analytics.payments.recorded")
    }

    static func trackMediaUploadSuccess() {
        increment("analytics.media.upload.success")
    }

    static func trackMediaUploadFailure() {
        increment("analytics.media.upload.failure")
    }

    // MARK: - Read Counters

    static func allCounters() -> [String: Int] {
        let keys = [
            "analytics.trips.created",
            "analytics.blocks.created.group",
            "analytics.blocks.created.personal",
            "analytics.posts.created.shared",
            "analytics.posts.created.private",
            "analytics.bills.created",
            "analytics.payments.recorded",
            "analytics.media.upload.success",
            "analytics.media.upload.failure",
        ]
        var result: [String: Int] = [:]
        for key in keys {
            let value = defaults.integer(forKey: key)
            if value > 0 { result[key] = value }
        }
        return result
    }

    // MARK: - Private

    private static func increment(_ key: String) {
        let current = defaults.integer(forKey: key)
        defaults.set(current + 1, forKey: key)
    }
}
