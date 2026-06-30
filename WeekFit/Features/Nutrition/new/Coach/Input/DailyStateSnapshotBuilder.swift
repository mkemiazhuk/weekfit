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
    let isHealthAccessGranted: Bool
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
            isHealthAccessGranted: isHealthAccessGranted,
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
        let calendar = Calendar.current
        let selectedDayStart = calendar.startOfDay(for: selectedDate)
        nutritionViewModel.prepareForDay(selectedDate)

        if let loadedDay = healthManager.displayMetricsDayStart,
           !calendar.isDate(loadedDay, inSameDayAs: selectedDayStart) {
            healthManager.prepareForDisplayDay(selectedDayStart)
        }

        let resolvedDayActivities = dayActivities ?? activities(on: selectedDate, from: allPlannedActivities)
        let preservedMetrics = preservedNutritionMetrics(
            selectedDate: selectedDate,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel
        )
        let metricsAreCurrent = healthManager.areDisplayMetricsLoaded(for: selectedDate, calendar: calendar)
        let nutritionMetrics = DailyNutritionMetrics(
            protein: preservedMetrics.protein,
            carbs: preservedMetrics.carbs,
            fats: preservedMetrics.fats,
            fiber: preservedMetrics.fiber,
            calories: preservedMetrics.calories,
            waterLiters: preservedMetrics.waterLiters,
            activeCalories: metricsAreCurrent ? healthManager.activeCalories : 0,
            sleepHours: healthManager.sleepHours,
            weightKg: healthManager.weight
        )
        let profile = ProfileService().makeNutritionProfile(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm,
            age: healthManager.age,
            sex: healthManager.biologicalSex
        )
        let plannedActivityGoal = resolvedDayActivities.reduce(0.0) { partial, activity in
            partial + Double(max(0, CoachActivityContextResolver.activityCalories(activity)))
        }
        let profileActivityGoal = ActivityGoalEngine.calculate(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm,
            age: healthManager.age,
            sex: healthManager.biologicalSex,
            recoveryPercent: Int(healthManager.recoveryPercent),
            sleepHours: healthManager.sleepHours,
            vo2Max: healthManager.cardioFitnessVO2,
            goal: profile.goal
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
            isHealthAccessGranted: healthManager.isHealthAccessGranted,
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
        selectedDate: Date,
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel
    ) -> DailyNutritionMetrics {
        let selectedDayStart = Calendar.current.startOfDay(for: selectedDate)
        let canUseViewModel = nutritionViewModel.trackedNutritionDayStart.map {
            Calendar.current.isDate($0, inSameDayAs: selectedDayStart)
        } == true

        guard canUseViewModel else {
            guard healthManager.areDisplayMetricsLoaded(for: selectedDate) else {
                return DailyNutritionMetrics(
                    protein: 0,
                    carbs: 0,
                    fats: 0,
                    fiber: 0,
                    calories: 0,
                    waterLiters: 0,
                    activeCalories: 0,
                    sleepHours: healthManager.sleepHours,
                    weightKg: healthManager.weight
                )
            }

            return DailyNutritionMetrics(
                protein: healthManager.protein,
                carbs: healthManager.carbs,
                fats: healthManager.fats,
                fiber: healthManager.fiber,
                calories: healthManager.calories,
                waterLiters: healthManager.waterLiters,
                activeCalories: healthManager.activeCalories,
                sleepHours: healthManager.sleepHours,
                weightKg: healthManager.weight
            )
        }

        let current = nutritionViewModel.currentMetrics
        let coach = nutritionViewModel.coachMetricsSnapshot?.nutritionContext
        let metricsAreCurrent = healthManager.areDisplayMetricsLoaded(for: selectedDate)

        func highest(_ healthKit: Double, _ viewModel: Double?, _ coachValue: Double?) -> Double {
            max(healthKit, viewModel ?? 0, coachValue ?? 0)
        }

        func healthKitValue(_ value: Double) -> Double {
            metricsAreCurrent ? value : 0
        }

        return DailyNutritionMetrics(
            protein: highest(healthKitValue(healthManager.protein), current?.protein, coach?.proteinCurrent),
            carbs: highest(healthKitValue(healthManager.carbs), current?.carbs, coach?.carbsCurrent),
            fats: highest(healthKitValue(healthManager.fats), current?.fats, coach?.fatsCurrent),
            fiber: highest(healthKitValue(healthManager.fiber), current?.fiber, nil),
            calories: highest(healthKitValue(healthManager.calories), current?.calories, coach?.caloriesCurrent),
            waterLiters: highest(healthKitValue(healthManager.waterLiters), current?.waterLiters, coach?.waterCurrent),
            activeCalories: metricsAreCurrent ? healthManager.activeCalories : 0,
            sleepHours: healthManager.sleepHours,
            weightKg: healthManager.weight
        )
    }
}
