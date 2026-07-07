import Foundation

enum CoachActivityKind {
    case endurance
    case workout
    case heat
    case recovery
    case meal
    case other
}

enum CoachActivityLoad {
    case low
    case moderate
    case high
    case extreme
}

/// Legacy bridge — delegates to `CoachActivityClassifier` (single taxonomy source).
/// Prefer `CoachActivityClassifier.type` / `family` for scenario routing.
enum CoachActivityContextResolver {

    static func kind(for activity: CoachPlannedActivitySnapshot) -> CoachActivityKind {
        CoachActivityClassifier.coachKind(for: activity)
    }

    static func load(for activity: CoachPlannedActivitySnapshot) -> CoachActivityLoad {
        CoachActivityClassifier.coachLoad(for: activity)
    }

    static func activityCalories(_ activity: CoachPlannedActivitySnapshot) -> Int {
        CoachActivityClassifier.activityCalories(for: activity)
    }
}
