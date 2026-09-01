import Foundation

/// Shared scheduling against today's existing plan.
/// Prevents inventing creates that overlap activities already on the day
/// (e.g. Stretching at 11:00 during a 10:00–12:30 bike).
enum ProposalPlanScheduleResolver {

    /// Non-skipped, non-nutrition activities that occupy calendar time today.
    static func blockingActivities(
        from todayActivities: [CoachPlannedActivitySnapshot]
    ) -> [CoachPlannedActivitySnapshot] {
        todayActivities.filter {
            !$0.isSkipped
                && CoachActivityClassifier.type(for: $0) != .none
                && !CoachCanonicalDayState.isNutritionLog($0)
        }
    }

    static func hasIntervalConflict(
        proposed: Date,
        durationMinutes: Int,
        with activities: [CoachPlannedActivitySnapshot]
    ) -> Bool {
        let duration = max(durationMinutes, 1)
        let proposedEnd = proposed.addingTimeInterval(TimeInterval(duration * 60))
        for activity in activities {
            let start = activity.date
            let end = start.addingTimeInterval(TimeInterval(max(activity.durationMinutes, 1) * 60))
            if proposed < end && proposedEnd > start {
                return true
            }
        }
        return false
    }

    /// Keeps `preferred` when free; otherwise slides after the blocking block.
    /// Returns `nil` when no free slot fits the constraints (drop the invent).
    static func resolveCreateStart(
        preferred: Date,
        durationMinutes: Int,
        against activities: [CoachPlannedActivitySnapshot],
        now: Date,
        maxSlideFromPreferredMinutes: Int? = 120,
        calendar: Calendar = .current
    ) -> Date? {
        let blockers = blockingActivities(from: activities)
        let earliest = now.addingTimeInterval(15 * 60)
        var candidate = preferred
        if candidate < earliest {
            candidate = earliest
        }

        if !hasIntervalConflict(
            proposed: candidate,
            durationMinutes: durationMinutes,
            with: blockers
        ) {
            return candidate
        }

        // Slide after each overlapping block (end + 15 min), rounded to :00 / :30.
        for _ in 0..<8 {
            guard let next = nextSlotAfterConflicts(
                starting: candidate,
                durationMinutes: durationMinutes,
                blockers: blockers,
                calendar: calendar
            ) else {
                return nil
            }
            candidate = max(next, earliest)
            if let maxSlide = maxSlideFromPreferredMinutes {
                let delta = abs(candidate.timeIntervalSince(preferred)) / 60
                if delta > Double(maxSlide) {
                    return nil
                }
            }
            if !hasIntervalConflict(
                proposed: candidate,
                durationMinutes: durationMinutes,
                with: blockers
            ) {
                return candidate
            }
        }
        return nil
    }

    private static func nextSlotAfterConflicts(
        starting: Date,
        durationMinutes: Int,
        blockers: [CoachPlannedActivitySnapshot],
        calendar: Calendar
    ) -> Date? {
        let duration = max(durationMinutes, 1)
        let proposedEnd = starting.addingTimeInterval(TimeInterval(duration * 60))
        var latestBlockingEnd: Date?
        for activity in blockers {
            let start = activity.date
            let end = start.addingTimeInterval(TimeInterval(max(activity.durationMinutes, 1) * 60))
            if starting < end && proposedEnd > start {
                if latestBlockingEnd == nil || end > latestBlockingEnd! {
                    latestBlockingEnd = end
                }
            }
        }
        guard let blockEnd = latestBlockingEnd else { return nil }
        let raw = blockEnd.addingTimeInterval(15 * 60)
        return roundUpToHalfHour(raw, calendar: calendar)
    }

    private static func roundUpToHalfHour(_ date: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = comps.minute ?? 0
        if minute == 0 || minute == 30 {
            comps.second = 0
            return calendar.date(from: comps) ?? date
        }
        if minute < 30 {
            comps.minute = 30
        } else {
            comps.minute = 0
            comps.hour = (comps.hour ?? 0) + 1
        }
        comps.second = 0
        return calendar.date(from: comps) ?? date
    }
}
