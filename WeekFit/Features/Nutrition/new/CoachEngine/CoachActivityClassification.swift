import Foundation

enum CoachActivityClassification {
    static func tokenText(for activity: PlannedActivity) -> String {
        [
            activity.type,
            activity.title,
            activity.icon,
            activity.imageName
        ]
        .joined(separator: " ")
        .lowercased()
    }

    static func isRecoveryTier(_ activity: PlannedActivity) -> Bool {
        let tokens = tokenText(for: activity)
        return tokens.contains("walk") ||
            tokens.contains("walking") ||
            tokens.contains("stretch") ||
            tokens.contains("yoga") ||
            tokens.contains("breath") ||
            tokens.contains("mobility") ||
            activity.type.lowercased() == "recovery"
    }

    static func isSignificantWorkout(_ activity: PlannedActivity) -> Bool {
        guard !isRecoveryTier(activity) else { return false }

        let tokens = tokenText(for: activity)
        return tokens.contains("cycling") ||
            tokens.contains("bicycle") ||
            tokens.contains("running") ||
            tokens.contains("run") ||
            tokens.contains("tennis") ||
            tokens.contains("squash") ||
            tokens.contains("upper body") ||
            tokens.contains("lower body") ||
            tokens.contains("full body") ||
            tokens.contains("core") ||
            tokens.contains("strength") ||
            tokens.contains("workout")
    }
}
