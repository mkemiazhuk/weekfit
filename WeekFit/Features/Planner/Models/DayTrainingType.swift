import Foundation

/// Primary training stimulus for a planned day.
enum DayTrainingType: Equatable {
    case recovery
    case endurance
    case strength
    case mixed
}

enum DayTrainingTypeClassifier {

    enum ActivityStimulus: Equatable {
        case recovery
        case endurance
        case strength
    }

    /// Returns `nil` when the day has no training-relevant activities (meals/habits only).
    nonisolated static func classify(activities: [PlannedActivity]) -> DayTrainingType? {
        var hasEndurance = false
        var hasStrength = false
        var hasTrainingActivity = false

        for activity in activities {
            guard let stimulus = activityStimulus(for: activity) else { continue }
            hasTrainingActivity = true

            switch stimulus {
            case .recovery:
                break
            case .endurance:
                hasEndurance = true
            case .strength:
                hasStrength = true
            }
        }

        guard hasTrainingActivity else { return nil }

        if hasEndurance && hasStrength { return .mixed }
        if hasEndurance { return .endurance }
        if hasStrength { return .strength }
        return .recovery
    }

    nonisolated static func activityStimulus(for activity: PlannedActivity) -> ActivityStimulus? {
        let type = activity.type.lowercased()
        if type == "meal" || type == "habit" || type == "drink" || type == "snack" {
            return nil
        }

        let title = activity.title.lowercased()
        let imageName = activity.imageName.lowercased()

        if matchesRecovery(imageName: imageName, title: title, type: type) {
            return .recovery
        }

        if matchesEndurance(imageName: imageName, title: title) {
            return .endurance
        }

        if matchesStrength(imageName: imageName, title: title, type: type) {
            return .strength
        }

        if type == "workout" {
            return .strength
        }

        if type == "recovery" {
            return .recovery
        }

        return nil
    }

    nonisolated private static func matchesRecovery(
        imageName: String,
        title: String,
        type: String
    ) -> Bool {
        if recoveryImageNames.contains(imageName) {
            return true
        }

        let recoveryKeywords = [
            "walk", "walking", "stretch", "stretching", "yoga",
            "breath", "breathing", "sauna", "mobility"
        ]

        return recoveryKeywords.contains(where: { title.contains($0) }) || type == "sauna"
    }

    nonisolated private static func matchesEndurance(imageName: String, title: String) -> Bool {
        if enduranceImageNames.contains(imageName) {
            return true
        }

        let enduranceKeywords = [
            "cycling", "cycle", "running", "run", "tennis", "squash",
            "swim", "swimming", "ride", "bike", "biking", "cardio"
        ]

        return enduranceKeywords.contains(where: { title.contains($0) })
    }

    nonisolated private static func matchesStrength(
        imageName: String,
        title: String,
        type: String
    ) -> Bool {
        if strengthImageNames.contains(imageName) {
            return true
        }

        let strengthKeywords = [
            "upper body", "lower body", "full body", "core",
            "strength", "gym", "hiit", "training", "workout"
        ]

        return strengthKeywords.contains(where: { title.contains($0) }) && type == "workout"
    }

    private static let recoveryImageNames: Set<String> = [
        "recovery-walk",
        "recovery-stretch",
        "recovery-sauna",
        "recovery-yoga",
        "recovery-breathing"
    ]

    private static let enduranceImageNames: Set<String> = [
        "workout-cycling",
        "workout-running",
        "workout-tennis",
        "workout-squash"
    ]

    private static let strengthImageNames: Set<String> = [
        "workout-strength",
        "workout-core",
        "workout-lowerbody",
        "workout-fullbody"
    ]
}
