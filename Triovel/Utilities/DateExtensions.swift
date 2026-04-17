import Foundation
import SwiftUI

extension Date {
    /// Format time (hour:minute) in a specific timezone.
    /// Use this instead of `.dateTime.hour().minute()` which uses the device timezone.
    func timeString(in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timeZone
        return formatter.string(from: self)
    }
}

/// A SwiftUI Text that displays a Date's time in a specific timezone.
/// Drop-in replacement for `Text(date, format: .dateTime.hour().minute())`
struct TimeText: View {
    let date: Date
    let timeZone: TimeZone

    init(_ date: Date, in timeZoneId: String) {
        self.date = date
        self.timeZone = TimeZone(identifier: timeZoneId) ?? .current
    }

    var body: some View {
        Text(date.timeString(in: timeZone))
    }
}

extension Date {
    /// Returns the start of day in the given timezone.
    func startOfDay(in timeZone: TimeZone) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: self)
    }

    /// Returns the day number (1-based) relative to a trip start date.
    func dayNumber(from tripStart: Date, in timeZone: TimeZone) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: tripStart)
        let current = calendar.startOfDay(for: self)
        let days = calendar.dateComponents([.day], from: start, to: current).day ?? 0
        return days + 1
    }
}
