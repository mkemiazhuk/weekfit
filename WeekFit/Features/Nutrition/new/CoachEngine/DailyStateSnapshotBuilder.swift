import Foundation

struct DailyStateSnapshot {
    let selectedDate: Date
    let now: Date
    let dayActivities: [PlannedActivity]
    let allPlannedActivities: [PlannedActivity]
    let nutritionMetrics: DailyNutritionMetrics
    let profile: UserNutritionProfile
    let recoveryContext: CoachRecoveryContext
    let actualLoad: CoachActualLoadSnapshot
    let source: String

    func makeCoachInput(
        from metricsSnapshot: CoachMetricsSnapshot,
        source: String
    ) -> CoachInputSnapshot {
        CoachInputSnapshot(
            metricsSnapshotID: metricsSnapshot.id,
            selectedDate: selectedDate,
            now: now,
            brain: metricsSnapshot.brain,
            plannedActivities: allPlannedActivities,
            actualLoad: actualLoad,
            planSource: .swiftDataPlannedActivity,
            recoveryContext: metricsSnapshot.recoveryContext,
            nutritionContext: metricsSnapshot.nutritionContext,
            source: source
        )
    }
}

@MainActor
enum DailyStateSnapshotBuilder {
    static func build(
        selectedDate: Date,
        dayActivities: [PlannedActivity]? = nil,
        allPlannedActivities: [PlannedActivity],
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        now: Date = Date(),
        source: String
    ) -> DailyStateSnapshot {
        let resolvedDayActivities = dayActivities ?? activities(on: selectedDate, from: allPlannedActivities)
        let preservedMetrics = preservedNutritionMetrics(
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel
        )
        let nutritionMetrics = DailyNutritionMetrics(
            protein: preservedMetrics.protein,
            carbs: preservedMetrics.carbs,
            fats: preservedMetrics.fats,
            fiber: preservedMetrics.fiber,
            calories: preservedMetrics.calories,
            waterLiters: preservedMetrics.waterLiters,
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
        let plannedActivityGoal = resolvedDayActivities.reduce(0.0) { partial, activity in
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

        return DailyStateSnapshot(
            selectedDate: selectedDate,
            now: now,
            dayActivities: resolvedDayActivities,
            allPlannedActivities: allPlannedActivities,
            nutritionMetrics: nutritionMetrics,
            profile: profile,
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: Int(healthManager.recoveryPercent),
                sleepHours: healthManager.sleepHours
            ),
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: healthManager.activeCalories,
                exerciseMinutes: healthManager.exerciseMinutes,
                standHours: healthManager.standHours,
                activityGoalCalories: automatedActivityGoal,
                activityProgress: healthManager.activeCalories / automatedActivityGoal
            ),
            source: source
        )
    }

    static func activities(on date: Date, from activities: [PlannedActivity]) -> [PlannedActivity] {
        let calendar = Calendar.current
        return activities
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    private static func preservedNutritionMetrics(
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel
    ) -> DailyNutritionMetrics {
        let current = nutritionViewModel.currentMetrics
        let coach = nutritionViewModel.coachMetricsSnapshot?.nutritionContext

        return DailyNutritionMetrics(
            protein: max(healthManager.protein, current?.protein ?? 0, coach?.proteinCurrent ?? 0),
            carbs: max(healthManager.carbs, current?.carbs ?? 0, coach?.carbsCurrent ?? 0),
            fats: max(healthManager.fats, current?.fats ?? 0, coach?.fatsCurrent ?? 0),
            fiber: max(healthManager.fiber, current?.fiber ?? 0),
            calories: max(healthManager.calories, current?.calories ?? 0, coach?.caloriesCurrent ?? 0),
            waterLiters: max(healthManager.waterLiters, current?.waterLiters ?? 0, coach?.waterCurrent ?? 0),
            activeCalories: healthManager.activeCalories,
            sleepHours: healthManager.sleepHours,
            weightKg: healthManager.weight
        )
    }
}
