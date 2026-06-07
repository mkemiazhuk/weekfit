import Foundation

enum CoachActivityPhasePriorityResolver {

    static func resolve(
        activities: [PlannedActivity],
        selectedDate: Date,
        now: Date = Date()
    ) -> CoachActivityPhaseV3 {
        CoachDayActivityContextResolver.phase(
            activities: activities,
            selectedDate: selectedDate,
            now: now
        )
    }
}
