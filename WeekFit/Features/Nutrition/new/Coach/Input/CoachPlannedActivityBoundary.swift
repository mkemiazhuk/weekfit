import Foundation
import WeekFitPlanner

/// Call-site adapters for live SwiftData rows. Coach snapshots must store value copies only;
/// these overloads convert at the boundary and must not be used for long-lived coach state.
enum CoachPlannedActivityBoundary {
    static func snapshot(from activity: PlannedActivity) -> CoachPlannedActivitySnapshot {
        CoachPlannedActivitySnapshot(from: activity)
    }
}

extension CoachActivityClassifier {
    static func family(for activity: PlannedActivity) -> CoachActivityFamily {
        family(for: CoachPlannedActivitySnapshot(from: activity))
    }

    static func type(for activity: PlannedActivity) -> CoachActivityType {
        type(for: CoachPlannedActivitySnapshot(from: activity))
    }

    static func isSeriousTraining(_ activity: PlannedActivity) -> Bool {
        isSeriousTraining(CoachPlannedActivitySnapshot(from: activity))
    }

    static func coachKind(for activity: PlannedActivity) -> CoachActivityKind {
        coachKind(for: CoachPlannedActivitySnapshot(from: activity))
    }

    static func coachLoad(for activity: PlannedActivity) -> CoachActivityLoad {
        coachLoad(for: CoachPlannedActivitySnapshot(from: activity))
    }

    static func activityCalories(for activity: PlannedActivity) -> Int {
        activityCalories(for: CoachPlannedActivitySnapshot(from: activity))
    }
}

extension CoachActivityContextResolver {
    static func kind(for activity: PlannedActivity) -> CoachActivityKind {
        kind(for: CoachPlannedActivitySnapshot(from: activity))
    }

    static func load(for activity: PlannedActivity) -> CoachActivityLoad {
        load(for: CoachPlannedActivitySnapshot(from: activity))
    }

    static func activityCalories(_ activity: PlannedActivity) -> Int {
        activityCalories(CoachPlannedActivitySnapshot(from: activity))
    }
}

extension CoachActivityWindowPolicy {
    static func recentCompletedFocusWindowMinutes(for activity: PlannedActivity) -> Int {
        recentCompletedFocusWindowMinutes(for: CoachPlannedActivitySnapshot(from: activity))
    }

    static func preparationLeadMinutes(for activity: PlannedActivity) -> Int {
        preparationLeadMinutes(for: CoachPlannedActivitySnapshot(from: activity))
    }

    static func recoveryHoldMinutes(for activity: PlannedActivity) -> Int {
        recoveryHoldMinutes(for: CoachPlannedActivitySnapshot(from: activity))
    }
}

extension CoachFocusResolver {
    static func resolve(
        input: CoachInputSnapshot,
        explicitFocus: PlannedActivity?
    ) -> CoachFocusSelection {
        resolve(
            input: input,
            explicitFocus: explicitFocus.map(CoachPlannedActivitySnapshot.init)
        )
    }
}

extension CoachTomorrowDemandResolver {
    static func isTraining(_ activity: PlannedActivity) -> Bool {
        isTraining(CoachPlannedActivitySnapshot(from: activity))
    }
}

extension CoachActivityClassification {
    static func isRecoveryTier(_ activity: PlannedActivity) -> Bool {
        isRecoveryTier(CoachPlannedActivitySnapshot(from: activity))
    }

    static func isWalkLike(_ activity: PlannedActivity) -> Bool {
        isWalkLike(CoachPlannedActivitySnapshot(from: activity))
    }

    static func isHikeLike(_ activity: PlannedActivity) -> Bool {
        isHikeLike(CoachPlannedActivitySnapshot(from: activity))
    }
}
