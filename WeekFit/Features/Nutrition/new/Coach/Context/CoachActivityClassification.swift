import Foundation
import WeekFitCoachCore

private extension PlannedActivity {
    var coachDescriptor: CoachActivityDescriptor {
        CoachActivityDescriptor(
            type: type,
            title: title,
            icon: icon,
            imageName: imageName
        )
    }
}

enum CoachActivityClassification {
    static func tokenText(for activity: PlannedActivity) -> String {
        WeekFitCoachCore.CoachActivityClassification.tokenText(for: activity.coachDescriptor)
    }

    static func isRecoveryTier(_ activity: PlannedActivity) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isRecoveryTier(activity.coachDescriptor)
    }

    static func isSignificantWorkout(_ activity: PlannedActivity) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isSignificantWorkout(activity.coachDescriptor)
    }

    static func isWalkLike(_ activity: PlannedActivity) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isWalkLike(activity.coachDescriptor)
    }

    static func isHikeLike(_ activity: PlannedActivity) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isHikeLike(activity.coachDescriptor)
    }
}
