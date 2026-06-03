import Foundation

/// Fixed reference instant for deterministic timeline math (2026-05-25 14:00 local).
enum CoachTestClock {
    static var reference: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 25
        components.hour = 14
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 1_748_184_000)
    }

    static func offset(hours: Double, from base: Date = reference) -> Date {
        base.addingTimeInterval(hours * 3600)
    }

    static func offset(minutes: Int, from base: Date = reference) -> Date {
        base.addingTimeInterval(TimeInterval(minutes * 60))
    }
}
