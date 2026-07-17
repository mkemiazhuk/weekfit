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
        switch CoachActivityClassifier.family(for: activity) {
        case .endurance, .strength, .racket, .heat, .recovery:
            return true
        case .none:
            break
        }

        let type = activity.type.lowercased()
        let title = activity.title.lowercased()
        let imageName = activity.imageName.lowercased()
        if type == "meal" || type == "drink" || type == "snack" || imageName == "hydration" {
            return false
        }
        if type == "workout" || type == "recovery" || type == "sauna" {
            return true
        }

        return activity.effectiveDurationMinutes >= 20 ||
            title.contains("run") ||
            title.contains("cycling") ||
            title.contains("ride") ||
            title.contains("walk") ||
            title.contains("yoga") ||
            title.contains("stretch")
    }
}
