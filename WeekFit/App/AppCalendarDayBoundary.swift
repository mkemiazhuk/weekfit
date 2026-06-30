import Foundation

/// Tracks the last active calendar day across app launches and in-memory sessions.
enum AppCalendarDayBoundary {

    private static let persistedDayStartKey = "weekfit_last_active_calendar_day_start"

    struct Rollover: Equatable {
        let previousDayStart: Date
        let newDayStart: Date
    }

    static func loadPersistedDayStart() -> Date? {
        UserDefaults.standard.object(forKey: persistedDayStartKey) as? Date
    }

    static func persistDayStart(_ dayStart: Date) {
        UserDefaults.standard.set(dayStart, forKey: persistedDayStartKey)
    }

    /// Returns a rollover when the persisted calendar day differs from `now`.
    /// Updates persistence to the current day start.
    static func detectPersistedRollover(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Rollover? {
        let newDayStart = calendar.startOfDay(for: now)
        defer { persistDayStart(newDayStart) }

        guard let previousDayStart = loadPersistedDayStart() else {
            return nil
        }

        guard !calendar.isDate(previousDayStart, inSameDayAs: newDayStart) else {
            return nil
        }

        return Rollover(previousDayStart: previousDayStart, newDayStart: newDayStart)
    }

    static func isSameCalendarDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func dayStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func nextBoundary(after now: Date = Date(), calendar: Calendar = .current) -> Date {
        TodayDayBoundaryPolicy.nextBoundary(after: now, calendar: calendar)
    }
}
