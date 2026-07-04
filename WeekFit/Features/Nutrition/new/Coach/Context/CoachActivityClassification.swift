import Foundation
import WeekFitCoachCore

private extension CoachPlannedActivitySnapshot {
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
    static func tokenText(for activity: CoachPlannedActivitySnapshot) -> String {
        WeekFitCoachCore.CoachActivityClassification.tokenText(for: activity.coachDescriptor)
    }

    static func isRecoveryTier(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isRecoveryTier(activity.coachDescriptor)
    }

    static func isSignificantWorkout(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isSignificantWorkout(activity.coachDescriptor)
    }

    static func isWalkLike(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isWalkLike(activity.coachDescriptor)
    }

    static func isHikeLike(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isHikeLike(activity.coachDescriptor)
    }
}
