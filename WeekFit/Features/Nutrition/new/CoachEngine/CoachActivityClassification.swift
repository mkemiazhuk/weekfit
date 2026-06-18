import WeekFitCoachCore

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
}

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
