import Foundation
internal import Combine

@MainActor
final class CoachScreenViewModel: ObservableObject {

    @Published var selectedDate = Date()
    @Published var pendingFuelItem: FastFuelItem?

    func selectedDateTitle(for date: Date) -> String {
        WeekFitShortWeekdayMonthDay(date)
    }

    func plannedActivities(
        for selectedDate: Date,
        from plannedActivities: [PlannedActivity]
    ) -> [PlannedActivity] {
        CoachCanonicalDayState.selectedDayActivities(
            from: plannedActivities,
            selectedDate: selectedDate
        )
    }

    func dayContext(
        selectedDate: Date,
        allPlannedActivities: [PlannedActivity],
        now: Date = Date()
    ) -> CoachDayContext {
        CoachDayContextBuilder.build(
            activities: plannedActivities(
                for: selectedDate,
                from: allPlannedActivities
            ),
            selectedDate: selectedDate,
            now: now
        )
    }

    func coachDayContext(
        selectedDate: Date,
        allPlannedActivities: [PlannedActivity],
        brain: HumanBrain.State?,
        now: Date = Date()
    ) -> CoachDayActivityContext {
        CoachActivityContextResolver.resolveDayContext(
            activities: plannedActivities(
                for: selectedDate,
                from: allPlannedActivities
            ),
            selectedDate: selectedDate,
            now: now,
            brain: brain
        )
    }

    func hasTodayRecoverySignals(healthManager: HealthManager) -> Bool {
        healthManager.sleepMinutes > 0 ||
        healthManager.timeInBedMinutes > 0 ||
        healthManager.hrvSDNN > 0 ||
        healthManager.restingHeartRate > 0
    }

    func shouldShowHealthConnectPrompt(healthManager: HealthManager) -> Bool {
        !hasTodayRecoverySignals(healthManager: healthManager) &&
        (
            !healthManager.isHealthAccessRequested ||
            (!healthManager.isHealthAccessGranted && healthManager.hasCompletedHealthAccessCheck)
        )
    }
}
