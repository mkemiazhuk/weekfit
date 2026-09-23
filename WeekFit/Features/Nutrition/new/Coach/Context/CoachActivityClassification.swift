import Foundation
import WeekFitCoachCore

private extension CoachPlannedActivitySnapshot {
    nonisolated var coachDescriptor: CoachActivityDescriptor {
        CoachActivityDescriptor(
            type: type,
            title: title,
            icon: icon,
            imageName: imageName
        )
    }
}

enum CoachActivityClassification {
    nonisolated static func tokenText(for activity: CoachPlannedActivitySnapshot) -> String {
        WeekFitCoachCore.CoachActivityClassification.tokenText(for: activity.coachDescriptor)
    }

    nonisolated static func isRecoveryTier(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isRecoveryTier(activity.coachDescriptor)
    }

    nonisolated static func isSignificantWorkout(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isSignificantWorkout(activity.coachDescriptor)
    }

    nonisolated static func isWalkLike(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isWalkLike(activity.coachDescriptor)
    }

    nonisolated static func isHikeLike(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        WeekFitCoachCore.CoachActivityClassification.isHikeLike(activity.coachDescriptor)
    }
}
