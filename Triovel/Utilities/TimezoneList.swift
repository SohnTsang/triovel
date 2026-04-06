import Foundation

/// Shared timezone data for pickers across the app.
/// Sorted from UTC-12 (Baker Island) to UTC+14 (Line Islands).
/// Covers every whole and half-hour offset with representative cities.
enum TimezoneList {
    struct Option: Identifiable {
        let identifier: String
        let label: String
        var id: String { identifier }
    }

    /// All timezone options, sorted west → east (UTC-12 to UTC+14).
    static let all: [Option] = {
        let zones: [(id: String, city: String)] = [
            ("Pacific/Midway",          "Baker Island"),           // UTC-12 (no DST representative)
            ("Pacific/Pago_Pago",       "Pago Pago"),              // UTC-11
            ("Pacific/Honolulu",        "Honolulu"),               // UTC-10
            ("Pacific/Marquesas",       "Marquesas"),              // UTC-9:30
            ("America/Anchorage",       "Anchorage"),              // UTC-9
            ("America/Los_Angeles",     "Los Angeles"),            // UTC-8
            ("America/Denver",          "Denver"),                 // UTC-7
            ("America/Chicago",         "Chicago"),                // UTC-6
            ("America/New_York",        "New York"),               // UTC-5
            ("America/Toronto",         "Toronto"),                // UTC-5
            ("America/Halifax",         "Halifax"),                 // UTC-4
            ("America/St_Johns",        "St. John's"),             // UTC-3:30
            ("America/Sao_Paulo",       "S\u{00E3}o Paulo"),       // UTC-3
            ("America/Buenos_Aires",    "Buenos Aires"),           // UTC-3
            ("Atlantic/South_Georgia",  "South Georgia"),          // UTC-2
            ("Atlantic/Azores",         "Azores"),                 // UTC-1
            ("Europe/London",           "London"),                 // UTC+0
            ("Europe/Paris",            "Paris"),                  // UTC+1
            ("Europe/Berlin",           "Berlin"),                 // UTC+1
            ("Europe/Rome",             "Rome"),                   // UTC+1
            ("Europe/Madrid",           "Madrid"),                 // UTC+1
            ("Europe/Amsterdam",        "Amsterdam"),              // UTC+1
            ("Europe/Istanbul",         "Istanbul"),               // UTC+3
            ("Europe/Moscow",           "Moscow"),                 // UTC+3
            ("Asia/Tehran",             "Tehran"),                 // UTC+3:30
            ("Asia/Dubai",              "Dubai"),                  // UTC+4
            ("Asia/Kabul",              "Kabul"),                  // UTC+4:30
            ("Asia/Karachi",            "Karachi"),                // UTC+5
            ("Asia/Kolkata",            "Kolkata"),                // UTC+5:30
            ("Asia/Kathmandu",          "Kathmandu"),              // UTC+5:45
            ("Asia/Dhaka",              "Dhaka"),                  // UTC+6
            ("Asia/Yangon",             "Yangon"),                 // UTC+6:30
            ("Asia/Bangkok",            "Bangkok"),                // UTC+7
            ("Asia/Singapore",          "Singapore"),              // UTC+8
            ("Asia/Hong_Kong",          "Hong Kong"),              // UTC+8
            ("Asia/Shanghai",           "Shanghai"),               // UTC+8
            ("Asia/Taipei",             "Taipei"),                 // UTC+8
            ("Asia/Seoul",              "Seoul"),                  // UTC+9
            ("Asia/Tokyo",              "Tokyo"),                  // UTC+9
            ("Australia/Adelaide",      "Adelaide"),               // UTC+9:30
            ("Australia/Sydney",        "Sydney"),                 // UTC+10
            ("Australia/Melbourne",     "Melbourne"),              // UTC+10
            ("Pacific/Noumea",          "Noumea"),                 // UTC+11
            ("Pacific/Auckland",        "Auckland"),               // UTC+12
            ("Pacific/Chatham",         "Chatham Islands"),        // UTC+12:45
            ("Pacific/Tongatapu",       "Nuku\u{02BB}alofa"),      // UTC+13
            ("Pacific/Kiritimati",      "Kiritimati"),             // UTC+14
        ]

        return zones.map { identifier, city in
            let tz = TimeZone(identifier: identifier) ?? .current
            let offset = tz.secondsFromGMT()
            let hours = offset / 3600
            let minutes = abs(offset % 3600) / 60
            let sign = offset >= 0 ? "+" : "-"
            let offsetStr = minutes > 0
                ? String(format: "UTC%@%d:%02d", sign, abs(hours), minutes)
                : "UTC\(sign)\(abs(hours))"
            return Option(identifier: identifier, label: "\(offsetStr) \(city)")
        }
    }()

    /// Format a timezone identifier as a display label: "UTC+9 Tokyo"
    /// Matches the picker option format for consistency.
    static func displayLabel(for identifier: String) -> String {
        let tz = TimeZone(identifier: identifier) ?? .current
        let offset = tz.secondsFromGMT()
        let hours = offset / 3600
        let minutes = abs(offset % 3600) / 60
        let sign = offset >= 0 ? "+" : "-"
        let offsetStr = minutes > 0
            ? String(format: "UTC%@%d:%02d", sign, abs(hours), minutes)
            : "UTC\(sign)\(abs(hours))"
        let city = identifier.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? identifier
        return "\(offsetStr) \(city)"
    }
}
