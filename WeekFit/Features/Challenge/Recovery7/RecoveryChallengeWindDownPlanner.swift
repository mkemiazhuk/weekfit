import Foundation

/// Pure wind-down time suggestion / validation for Recovery Challenge Day 1.
enum RecoveryChallengeWindDownPlanner {

    struct Plan: Equatable, Sendable {
        /// Absolute instant of the planned wind-down in the given timezone calendar.
        var targetAt: Date
        /// Minutes from midnight of `targetAt`’s calendar day.
        var minuteOfDay: Int
        /// `yyyy-MM-dd` for `targetAt` in the enrollment/device timezone.
        var dayKey: String
        /// True when `targetAt` falls on the calendar day after `now`.
        var isTomorrow: Bool
        /// True when `targetAt` is strictly after `now`.
        var isInFuture: Bool
    }

    enum ConfirmationError: Error, Equatable, Sendable {
        /// An unsaved suggestion drifted into the past — refresh instead of saving silently.
        case staleSuggestion
    }

    /// Suggest ~15 minutes from `now`, rounded upward onto a 15-minute boundary.
    /// Example: 22:30 → 22:45. Never returns a time ≤ `now`.
    static func suggest(
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> Plan {
        let calendar = calendar(for: timeZone)
        let plusFifteen = now.addingTimeInterval(15 * 60)
        var suggested = ceilToFifteenMinuteBoundary(plusFifteen, calendar: calendar)
        if suggested <= now {
            suggested = calendar.date(byAdding: .minute, value: 15, to: suggested) ?? suggested.addingTimeInterval(15 * 60)
        }
        return plan(for: suggested, now: now, timeZone: timeZone)
    }

    /// “Start now” — current minute as an explicit choice (still requires CTA to complete).
    static func startNow(
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> Plan {
        let calendar = calendar(for: timeZone)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let floored = calendar.date(from: comps) ?? now
        return plan(for: floored, now: now, timeZone: timeZone)
    }

    /// Rebuild a saved plan from persisted minute-of-day (+ optional day key).
    /// Does not auto-bump a past time into tomorrow.
    static func planFromSaved(
        minuteOfDay: Int,
        dayKey: String?,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> Plan {
        let calendar = calendar(for: timeZone)
        let clamped = max(0, min(23 * 60 + 59, minuteOfDay))
        let baseDay: Date = {
            if let dayKey, let day = RecoveryChallengeEngine.dateFromDayKey(dayKey, timeZone: timeZone) {
                return calendar.startOfDay(for: day)
            }
            return calendar.startOfDay(for: now)
        }()
        let target = calendar.date(byAdding: .minute, value: clamped, to: baseDay) ?? now
        return plan(for: target, now: now, timeZone: timeZone)
    }

    /// Resolve a picker edit (hour/minute) onto today or keep explicit past-on-today.
    static func planFromPickerSelection(
        selected: Date,
        now: Date = Date(),
        timeZone: TimeZone = .current,
        treatAsSuggestion: Bool
    ) -> Plan {
        let calendar = calendar(for: timeZone)
        let minute = RecoveryChallengeEngine.minuteOfDay(from: selected, timeZone: timeZone)
        let todayStart = calendar.startOfDay(for: now)
        var target = calendar.date(byAdding: .minute, value: minute, to: todayStart) ?? selected

        if treatAsSuggestion {
            if target <= now {
                // Suggestion must stay in the future — roll to tomorrow rather than past tonight.
                target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
            }
        }
        // Explicit choice: keep tonight even if already past (user’s plan).
        return plan(for: target, now: now, timeZone: timeZone)
    }

    /// Gate confirmation so a stale unsaved suggestion is never persisted as a future plan.
    static func validatedPlanForConfirmation(
        selected: Date,
        isExplicitChoice: Bool,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> Result<Plan, ConfirmationError> {
        if isExplicitChoice {
            return .success(
                planFromPickerSelection(
                    selected: selected,
                    now: now,
                    timeZone: timeZone,
                    treatAsSuggestion: false
                )
            )
        }
        let plan = planFromPickerSelection(
            selected: selected,
            now: now,
            timeZone: timeZone,
            treatAsSuggestion: true
        )
        guard plan.isInFuture else {
            return .failure(.staleSuggestion)
        }
        // If the picker still holds a past clock time for “today”, treat as stale.
        let calendar = calendar(for: timeZone)
        let minute = RecoveryChallengeEngine.minuteOfDay(from: selected, timeZone: timeZone)
        let todayStart = calendar.startOfDay(for: now)
        if let todayCandidate = calendar.date(byAdding: .minute, value: minute, to: todayStart),
           todayCandidate <= now,
           calendar.isDate(selected, inSameDayAs: now) {
            return .failure(.staleSuggestion)
        }
        return .success(plan)
    }

    static func formatTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func formatTimeAndDayLabel(
        plan: Plan,
        timeZone: TimeZone = .current,
        tomorrowFormat: (String) -> String
    ) -> String {
        let time = formatTime(plan.targetAt, timeZone: timeZone)
        if plan.isTomorrow {
            return tomorrowFormat(time)
        }
        return time
    }

    // MARK: - Internals

    static func ceilToFifteenMinuteBoundary(_ date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )
        let minute = comps.minute ?? 0
        let remainder = minute % 15
        var flooredComps = comps
        flooredComps.minute = minute - remainder
        flooredComps.second = 0
        flooredComps.nanosecond = 0
        let floored = calendar.date(from: flooredComps) ?? date
        let onBoundary = remainder == 0 && (comps.second ?? 0) == 0 && (comps.nanosecond ?? 0) == 0
        if onBoundary {
            return floored
        }
        return calendar.date(byAdding: .minute, value: 15, to: floored) ?? date
    }

    private static func plan(for target: Date, now: Date, timeZone: TimeZone) -> Plan {
        let calendar = calendar(for: timeZone)
        let minute = RecoveryChallengeEngine.minuteOfDay(from: target, timeZone: timeZone)
        let dayKey = RecoveryChallengeEngine.dayKey(for: target, timeZone: timeZone)
        let isTomorrow = calendar.startOfDay(for: target) > calendar.startOfDay(for: now)
        return Plan(
            targetAt: target,
            minuteOfDay: minute,
            dayKey: dayKey,
            isTomorrow: isTomorrow,
            isInFuture: target > now
        )
    }

    private static func calendar(for timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
