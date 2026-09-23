import Foundation

nonisolated enum CoachActivityKind: Equatable, Sendable {
    case endurance
    case workout
    case heat
    case recovery
    case meal
    case other
}

nonisolated enum CoachActivityLoad: Equatable, Sendable {
    case low
    case moderate
    case high
    case extreme
}

/// Legacy bridge — delegates to `CoachActivityClassifier` (single taxonomy source).
/// Prefer `CoachActivityClassifier.type` / `family` for scenario routing.
enum CoachActivityContextResolver {

    nonisolated static func kind(for activity: CoachPlannedActivitySnapshot) -> CoachActivityKind {
        CoachActivityClassifier.coachKind(for: activity)
    }

    nonisolated static func load(for activity: CoachPlannedActivitySnapshot) -> CoachActivityLoad {
        CoachActivityClassifier.coachLoad(for: activity)
    }

    nonisolated static func activityCalories(_ activity: CoachPlannedActivitySnapshot) -> Int {
        CoachActivityClassifier.activityCalories(for: activity)
    }
}
