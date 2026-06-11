import Foundation
internal import Combine

@MainActor
final class CoachInputProvider: ObservableObject {
    @Published private(set) var lastInput: CoachInputSnapshot?
    @Published private(set) var lastRefreshReason: String = "notLoaded"

    func refresh(
        selectedDate: Date,
        plannedActivities: [PlannedActivity],
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        source: String,
        refreshHealth: Bool = false
    ) async {
        let dayActivities = Self.activities(on: selectedDate, from: plannedActivities)

        if refreshHealth {
            await healthManager.loadHealthData(
                for: selectedDate,
                plannedActivities: dayActivities
            )
        }

        refreshFromCurrentState(
            selectedDate: selectedDate,
            dayActivities: dayActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            source: source
        )
    }

    func refreshFromCurrentState(
        selectedDate: Date,
        dayActivities: [PlannedActivity],
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachCoordinator: CoachCoordinator,
        source: String
    ) {
        let metrics = DailyNutritionMetrics(
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0,
            calories: 0,
            waterLiters: 0,
            activeCalories: healthManager.activeCalories,
            sleepHours: healthManager.sleepHours,
            weightKg: healthManager.weight
        )

        let profile = UserNutritionProfile.createAutomatic(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm,
            age: healthManager.age,
            sex: healthManager.biologicalSex == .male ? .male : .female
        )

        nutritionViewModel.updateNutrition(
            metrics: metrics,
            profile: profile,
            plannedActivities: dayActivities,
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: Int(healthManager.recoveryPercent),
                sleepHours: healthManager.sleepHours
            ),
            debugSource: "CoachInputProvider.\(source)"
        )

        guard let snapshot = nutritionViewModel.coachMetricsSnapshot else {
            coachCoordinator.updateInput(nil)
            _ = coachCoordinator.recomputeIfNeeded(reason: source)
            lastInput = nil
            lastRefreshReason = source
            return
        }

        let plannedActivityGoal = dayActivities.reduce(0.0) { partial, activity in
            partial + Double(max(0, CoachActivityContextResolverV3.activityCalories(activity)))
        }
        let profileActivityGoal = ActivityGoalEngine.calculate(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm,
            age: healthManager.age,
            sex: healthManager.biologicalSex,
            recoveryPercent: Int(healthManager.recoveryPercent),
            sleepHours: healthManager.sleepHours,
            vo2Max: healthManager.cardioFitnessVO2
        )
        let automatedActivityGoal = max(300, plannedActivityGoal, profileActivityGoal)

        let input = CoachInputSnapshot(
            metricsSnapshotID: snapshot.id,
            selectedDate: selectedDate,
            now: Date(),
            brain: snapshot.brain,
            plannedActivities: dayActivities,
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: healthManager.activeCalories,
                exerciseMinutes: healthManager.exerciseMinutes,
                standHours: healthManager.standHours,
                activityGoalCalories: automatedActivityGoal,
                activityProgress: healthManager.activeCalories / automatedActivityGoal
            ),
            planSource: .swiftDataPlannedActivity,
            recoveryContext: snapshot.recoveryContext,
            nutritionContext: snapshot.nutritionContext,
            source: "CoachInputProvider.\(source)"
        )

        coachCoordinator.updateInput(input)
        _ = coachCoordinator.recomputeIfNeeded(reason: source)
        lastInput = input
        lastRefreshReason = source
    }

    static func activities(on date: Date, from activities: [PlannedActivity]) -> [PlannedActivity] {
        let calendar = Calendar.current
        return activities.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
}
