import Foundation
enum CoachActivityPhase {
    case preparing(activity: PlannedActivity, kind: CoachActivityKind, minutesUntil: Int)
    case active(activity: PlannedActivity, kind: CoachActivityKind)
    case recovering(activity: PlannedActivity, kind: CoachActivityKind, minutesSinceEnd: Int)
    case stable
}

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
enum CoachActivityContextResolver {

    static func kind(for activity: PlannedActivity) -> CoachActivityKind {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()

        if title.contains("sauna") ||
            type.contains("sauna") ||
            title.contains("hot yoga") ||
            type.contains("hot yoga") ||
            title.contains("heat") ||
            type.contains("heat") {
            return .heat
        }

        if type == "meal" ||
            title.contains("meal") ||
            title.contains("lunch") ||
            title.contains("dinner") {
            return .meal
        }

        let isExplicitRecovery =
            type.contains("recovery") ||
            title.contains("recovery block") ||
            title.contains("recovery") ||
            title.contains("breath") ||
            type.contains("breath")

        if isExplicitRecovery {
            return .recovery
        }

        let isRun =
            title.contains("run") ||
            type.contains("run")

        let isSwim =
            title.contains("swim") ||
            title.contains("swimming") ||
            type.contains("swim") ||
            type.contains("swimming")

        let isRide =
            title.contains("cycling") ||
            title.contains("cycle") ||
            title.contains("bike") ||
            title.contains("biking") ||
            title.contains("ride") ||
            title.contains("cardio") ||
            type.contains("cycling") ||
            type.contains("cycle") ||
            type.contains("bike") ||
            type.contains("biking") ||
            type.contains("ride") ||
            type.contains("cardio")

        let isWalkOrHike =
            CoachActivityClassification.isWalkLike(activity) ||
            CoachActivityClassification.isHikeLike(activity)

        if isWalkOrHike {
            return .recovery
        }

        if isRun || isRide || isSwim {
            return .endurance
        }

        let isRacketSport =
            title.contains("tennis") ||
            title.contains("squash") ||
            title.contains("padel") ||
            title.contains("pickleball") ||
            title.contains("badminton") ||
            type.contains("tennis") ||
            type.contains("squash") ||
            type.contains("padel") ||
            type.contains("pickleball") ||
            type.contains("badminton")

        if title.contains("gym") ||
            title.contains("strength") ||
            title.contains("hiit") ||
            title.contains("training") ||
            title.contains("workout") ||
            type.contains("gym") ||
            type.contains("strength") ||
            type.contains("hiit") ||
            type.contains("training") ||
            type.contains("workout") ||
            isRacketSport {
            return .workout
        }

        if title.contains("yoga") ||
            title.contains("stretch") ||
            title.contains("mobility") ||
            type.contains("yoga") ||
            type.contains("stretch") ||
            type.contains("mobility") {
            return .recovery
        }

        return .other
    }

    static func load(for activity: PlannedActivity) -> CoachActivityLoad {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()
        let duration = activity.durationMinutes
        let calories = activityCalories(activity)

        if duration >= 180 || calories >= 1800 {
            return .extreme
        }

        if duration >= 120 || calories >= 1000 {
            return .high
        }

        if CoachActivityClassification.isWalkLike(activity) {
            return calories >= 600 ? .moderate : .low
        }

        if CoachActivityClassification.isHikeLike(activity) {
            if duration >= 180 || calories >= 1000 { return .moderate }
            return .low
        }

        if title.contains("walk") || type.contains("walk") {
            return duration >= 90 || calories >= 500 ? .moderate : .low
        }

        if title.contains("cycling") ||
            title.contains("cycle") ||
            title.contains("bike") ||
            title.contains("ride") ||
            title.contains("run") ||
            type.contains("cycling") ||
            type.contains("run") {

            if duration >= 120 || calories >= 1000 { return .high }
            if duration >= 60 || calories >= 400 { return .moderate }
            return .low
        }

        if title.contains("strength") ||
            title.contains("gym") ||
            title.contains("hiit") ||
            title.contains("workout") ||
            type.contains("strength") ||
            type.contains("gym") ||
            type.contains("hiit") ||
            type.contains("workout") {

            if duration >= 90 || calories >= 700 { return .high }
            return .moderate
        }

        if title.contains("yoga") ||
            title.contains("stretch") ||
            title.contains("mobility") ||
            title.contains("recovery") ||
            title.contains("breath") ||
            type.contains("breath") {
            return .low
        }

        return .moderate
    }

    static func activityCalories(_ activity: PlannedActivity) -> Int {
        let mirror = Mirror(reflecting: activity)

        let possibleNames = [
            "activeCalories",
            "calories",
            "caloriesBurned",
            "burnedCalories",
            "energyBurned",
            "activeEnergy"
        ]

        for child in mirror.children {
            guard let label = child.label,
                  possibleNames.contains(label) else {
                continue
            }

            if let value = child.value as? Int {
                return value
            }

            if let value = child.value as? Double {
                return Int(value)
            }

            if let value = child.value as? CGFloat {
                return Int(value)
            }

            if let value = child.value as? Optional<Double>,
               let unwrapped = value {
                return Int(unwrapped)
            }

            if let value = child.value as? Optional<Int>,
               let unwrapped = value {
                return unwrapped
            }
        }

        return 0
    }
}
