import Foundation

/// Tracks first Coach interaction per calendar day. Not part of `CoachInputFingerprint` (PR1).
enum CoachSessionTracker {

    private static let openedDayKey = "coach_session_tracker_opened_day_v1"

    static func isFirstOpenToday(now: Date, calendar: Calendar = .current) -> Bool {
        if let testOverride = testOverrideFirstOpen {
            return testOverride
        }
        let todayKey = dayKey(for: now, calendar: calendar)
        return UserDefaults.standard.string(forKey: openedDayKey) != todayKey
    }

    static func markCoachInteraction(now: Date, calendar: Calendar = .current) {
        guard testOverrideFirstOpen == nil else { return }
        UserDefaults.standard.set(dayKey(for: now, calendar: calendar), forKey: openedDayKey)
    }

    static func resetForTests() {
        testOverrideFirstOpen = nil
        UserDefaults.standard.removeObject(forKey: openedDayKey)
    }

    static func setTestFirstOpen(_ value: Bool?) {
        testOverrideFirstOpen = value
    }

    // MARK: - Private

    private static var testOverrideFirstOpen: Bool?

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let start = calendar.startOfDay(for: date)
        return String(Int(start.timeIntervalSince1970))
    }
}
