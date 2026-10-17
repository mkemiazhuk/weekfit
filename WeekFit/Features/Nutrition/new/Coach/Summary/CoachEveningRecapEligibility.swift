import Foundation
import WeekFitPlanner

/// Priority for the Coach surface (higher wins):
/// 1. Live session · 2. Upcoming / overdue unresolved plan session · 3. Evening recap (≥20:00) · 4. Other.
enum CoachEveningRecapEligibility {

    /// True when Coach should show the evening recap instead of the main recommendation card.
    static func shouldShowEveningRecap(
        now: Date,
        plannedActivities: [PlannedActivity],
        calendar: Calendar = .current
    ) -> Bool {
        guard CoachEveningSummaryPolicy.isEvening(now, calendar: calendar) else { return false }
        return !hasBlockingPlanSession(now: now, plannedActivities: plannedActivities, calendar: calendar)
    }

    /// Live workout/recovery or unresolved plan session for today (not food/water).
    static func hasBlockingPlanSession(
        now: Date,
        plannedActivities: [PlannedActivity],
        calendar: Calendar = .current
    ) -> Bool {
        let today = plannedActivities.filter { calendar.isDate($0.date, inSameDayAs: now) }

        for activity in today {
            if activity.isUserStartedLiveSession(now: now) {
                return true
            }
            let snap = CoachPlannedActivitySnapshot(from: activity)
            if CoachSessionPhaseStability.isCoachLiveSession(snap, now: now) {
                return true
            }
        }

        if hasUpcomingSession(now: now, today: today) {
            return true
        }

        if hasOverdueUnresolvedSession(now: now, today: today, calendar: calendar) {
            return true
        }

        return false
    }

    private static func hasUpcomingSession(now: Date, today: [PlannedActivity]) -> Bool {
        today.contains { activity in
            let snap = CoachPlannedActivitySnapshot(from: activity)
            guard CoachCanonicalDayState.isSessionFocusCandidate(snap) else { return false }
            return activity.date >= now
        }
    }

    /// Same idea as Plan/Today pending: overdue unfinished session slots still need confirm/skip.
    private static func hasOverdueUnresolvedSession(
        now: Date,
        today: [PlannedActivity],
        calendar: Calendar
    ) -> Bool {
        today.contains { activity in
            let snap = CoachPlannedActivitySnapshot(from: activity)
            guard CoachCanonicalDayState.isSessionFocusCandidate(snap) else { return false }
            let end = calendar.date(
                byAdding: .minute,
                value: max(activity.effectiveDurationMinutes, 1),
                to: activity.date
            ) ?? activity.date
            return now > end && snap.terminalState(now: now) == .planned
        }
    }

    /// Next moment Coach should re-evaluate evening-recap eligibility (local 20:00 or day boundary).
    static func nextRecheckDate(after now: Date = Date(), calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: now)
        if let eveningStart = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: dayStart),
           now < eveningStart {
            return eveningStart
        }
        return AppCalendarDayBoundary.nextBoundary(after: now, calendar: calendar)
    }
}
