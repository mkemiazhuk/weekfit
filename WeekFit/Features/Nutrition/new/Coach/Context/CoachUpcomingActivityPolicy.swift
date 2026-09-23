import Foundation
import WeekFitPlanner

/// Whether today still has coach-relevant work ahead — blocks evening tomorrow protection.
enum CoachUpcomingActivityPolicy {

    static func hasMeaningfulActivityLaterToday(_ input: CoachInputSnapshot) -> Bool {
        input.dayContext.upcomingActivities.contains { activity in
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            guard activity.date >= input.now else { return false }
            return isMeaningful(activity)
        }
    }

    private static func isMeaningful(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        CoachCanonicalDayState.isCoachRelevantSnapshot(activity)
    }
}
