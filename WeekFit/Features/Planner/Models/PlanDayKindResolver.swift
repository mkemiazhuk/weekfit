import Foundation

enum PlanDayKind: Equatable {
    case endurance
    case load
    case mixed
    case recovery
    case open

    var label: String {
        switch self {
        case .endurance: return WeekFitLocalizedString("planner.dayKind.endurance")
        case .load: return WeekFitLocalizedString("planner.dayKind.load")
        case .mixed: return WeekFitLocalizedString("planner.dayKind.mixed")
        case .recovery: return WeekFitLocalizedString("planner.dayKind.recovery")
        case .open: return WeekFitLocalizedString("planner.dayKind.open")
        }
    }

    var legendLabel: String {
        switch self {
        case .endurance: return WeekFitLocalizedString("planner.legend.endurance")
        case .load: return WeekFitLocalizedString("planner.legend.highLoad")
        case .mixed: return WeekFitLocalizedString("planner.legend.mixed")
        case .recovery: return WeekFitLocalizedString("planner.legend.recovery")
        case .open: return WeekFitLocalizedString("planner.dayKind.open")
        }
    }

    var barCount: Int {
        switch self {
        case .endurance: return 4
        case .load: return 3
        case .mixed: return 2
        case .recovery: return 1
        case .open: return 0
        }
    }
}

enum PlanDayKindResolver {

    private enum WorkoutBucket: Hashable {
        case light
        case endurance
        case strength
    }

    nonisolated static func resolve(activities: [PlannedActivity]) -> PlanDayKind {
        guard !activities.isEmpty else {
            return .open
        }

        let workouts = activities.filter { $0.type.lowercased() == "workout" }
        let recovery = activities.filter { $0.type.lowercased() == "recovery" }
        let meals = activities.filter { $0.type.lowercased() == "meal" }
        let habits = activities.filter { $0.type.lowercased() == "habit" }

        let workoutMinutes = workouts.reduce(0) { $0 + max($1.durationMinutes, 0) }
        let recoveryMinutes = recovery.reduce(0) { $0 + max($1.durationMinutes, 0) }

        if workouts.isEmpty && !recovery.isEmpty {
            return .recovery
        }

        if isMixedDay(
            workouts: workouts,
            recovery: recovery,
            meals: meals,
            habits: habits
        ) {
            return .mixed
        }

        let hasLongWorkout = workouts.contains { $0.durationMinutes >= 50 }

        if hasLongWorkout || workoutMinutes >= 60 {
            return .endurance
        }

        if workouts.count >= 2 || workoutMinutes >= 45 {
            return .load
        }

        if workouts.isEmpty && recoveryMinutes >= 20 {
            return .recovery
        }

        if !workouts.isEmpty && hasOnlyLightWorkouts(workouts) {
            return .recovery
        }

        if !workouts.isEmpty {
            return .load
        }

        return .recovery
    }

    nonisolated private static func isMixedDay(
        workouts: [PlannedActivity],
        recovery: [PlannedActivity],
        meals: [PlannedActivity],
        habits: [PlannedActivity]
    ) -> Bool {
        if !workouts.isEmpty,
           !recovery.isEmpty || !meals.isEmpty || !habits.isEmpty {
            return true
        }

        if workouts.count >= 2, hasHeterogeneousWorkouts(workouts) {
            return true
        }

        return false
    }

    nonisolated private static func hasHeterogeneousWorkouts(_ workouts: [PlannedActivity]) -> Bool {
        Set(workouts.map(workoutBucket(for:))).count >= 2
    }

    nonisolated private static func hasOnlyLightWorkouts(_ workouts: [PlannedActivity]) -> Bool {
        !workouts.isEmpty && workouts.allSatisfy {
            workoutBucket(for: $0) == .light
        }
    }

    nonisolated private static func workoutBucket(for activity: PlannedActivity) -> WorkoutBucket {
        let title = activity.title.lowercased()

        let lightKeywords = ["walk", "walking", "yoga", "stretch", "stretching", "mobility", "breath"]
        if lightKeywords.contains(where: { title.contains($0) }) {
            return .light
        }

        let enduranceKeywords = [
            "cycling", "cycle", "running", "run", "tennis", "squash",
            "swim", "swimming", "ride", "bike", "biking", "cardio"
        ]
        if enduranceKeywords.contains(where: { title.contains($0) }) {
            return .endurance
        }

        return .strength
    }
}
