import Foundation

/// UserDefaults-backed weekly focus selected from Ask Coach.
enum AskCoachFocusStore {
    static let storageKey = "coach.askCoach.weeklyFocus.v1"
    private static let lock = NSLock()
    private static var defaults: UserDefaults = .standard

    static func load() -> AskCoachWeeklyFocus? {
        lock.lock()
        defer { lock.unlock() }
        return loadUnsafe()
    }

    static func save(_ focus: AskCoachWeeklyFocus) {
        lock.lock()
        saveUnsafe(focus)
        lock.unlock()
    }

    static func clear() {
        lock.lock()
        defaults.removeObject(forKey: storageKey)
        lock.unlock()
    }

    @discardableResult
    static func setFocus(
        kind: AskCoachFocusKind,
        now: Date = Date(),
        calendar: Calendar = .current,
        durationDays: Int = 7
    ) -> AskCoachWeeklyFocus {
        var calendar = calendar
        calendar.timeZone = TimeZone.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: max(0, durationDays - 1), to: start) ?? start
        let focus = AskCoachWeeklyFocus(
            id: UUID().uuidString,
            kind: kind,
            startDayKey: CoachDailyObservation.dayKey(for: start, calendar: calendar),
            endDayKey: CoachDailyObservation.dayKey(for: end, calendar: calendar),
            createdAt: now,
            dismissed: false
        )
        save(focus)
        return focus
    }

    @discardableResult
    static func dismiss(now: Date = Date(), calendar: Calendar = .current) -> AskCoachWeeklyFocus? {
        lock.lock()
        defer { lock.unlock() }
        guard var focus = loadUnsafe() else { return nil }
        focus.dismissed = true
        saveUnsafe(focus)
        return focus
    }

    /// Active focus whose end day has not passed.
    static func activeFocus(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> AskCoachWeeklyFocus? {
        guard let focus = load(), focus.isActive else { return nil }
        let dayKey = CoachDailyObservation.dayKey(for: date, calendar: calendar)
        guard focus.includes(dayKey: dayKey) else { return nil }
        return focus
    }

    /// Focus that has ended and can be reviewed (not dismissed).
    static func reviewableFocus(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) -> AskCoachWeeklyFocus? {
        guard let focus = load(), !focus.dismissed else { return nil }
        let dayKey = CoachDailyObservation.dayKey(for: date, calendar: calendar)
        guard focus.hasEnded(on: dayKey) else { return nil }
        return focus
    }

    // MARK: - Test seam

    static func useDefaults(_ defaults: UserDefaults) {
        lock.lock()
        self.defaults = defaults
        lock.unlock()
    }

    static func resetDefaults() {
        lock.lock()
        defaults = .standard
        lock.unlock()
    }

    // MARK: - Private

    private static func loadUnsafe() -> AskCoachWeeklyFocus? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(AskCoachWeeklyFocus.self, from: data)
    }

    private static func saveUnsafe(_ focus: AskCoachWeeklyFocus) {
        guard let data = try? JSONEncoder().encode(focus) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
