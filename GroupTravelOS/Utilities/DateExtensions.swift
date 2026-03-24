import Foundation

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
