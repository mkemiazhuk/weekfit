import Foundation

public struct CoachActivityDescriptor: Sendable, Equatable {
    public let type: String
    public let title: String
    public let icon: String
    public let imageName: String

    public init(type: String, title: String, icon: String, imageName: String) {
        self.type = type
        self.title = title
        self.icon = icon
        self.imageName = imageName
    }
}

public enum CoachActivityClassification {
    public static func tokenText(for activity: CoachActivityDescriptor) -> String {
        [
            activity.type,
            activity.title,
            activity.icon,
            activity.imageName
        ]
        .joined(separator: " ")
        .lowercased()
    }

    public static func isRecoveryTier(_ activity: CoachActivityDescriptor) -> Bool {
        let tokens = tokenText(for: activity)
        return tokens.contains("walk") ||
            tokens.contains("walking") ||
            tokens.contains("stretch") ||
            tokens.contains("yoga") ||
            tokens.contains("breath") ||
            tokens.contains("mobility") ||
            activity.type.lowercased() == "recovery"
    }

    public static func isSignificantWorkout(_ activity: CoachActivityDescriptor) -> Bool {
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
