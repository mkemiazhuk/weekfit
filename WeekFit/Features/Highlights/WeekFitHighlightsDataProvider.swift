import Foundation

struct WeekFitHighlightsDataProvider {

    @MainActor
    func loadMonthlyMetrics(
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        plannedActivities: [PlannedActivity],
        endingAt endDate: Date = Date(),
        calendar: Calendar = .current
    ) async -> [DailyMetrics] {
        let today = calendar.startOfDay(for: endDate)
        let dates = (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 29, to: today)
        }

        var output: [DailyMetrics] = []
        output.reserveCapacity(dates.count)

        for date in dates {
            let metrics = await healthManager.readActivityMetrics(for: date)
            let dayActivities = plannedActivities.filter {
                calendar.isDate($0.date, inSameDayAs: date)
            }
            let nutritionTotals = nutritionTotals(
                for: date,
                today: today,
                dayActivities: dayActivities,
                nutritionViewModel: nutritionViewModel,
                calendar: calendar
            )

            output.append(DailyMetrics(
                date: date,
                recoveryScore: clampedScore(metrics.recoveryPercent),
                activityVolume: activityVolume(from: metrics, dayActivities: dayActivities),
                nutritionScore: nutritionScore(
                    from: nutritionTotals,
                    goals: nutritionViewModel.nutritionResult?.goals
                ),
                sleepConsistency: clampedScore(metrics.sleepScore)
            ))
        }

        return output
    }
}

private extension WeekFitHighlightsDataProvider {

    struct NutritionTotals {
        let calories: Double
        let protein: Double
        let carbs: Double
        let fats: Double
        let fiber: Double
        let waterLiters: Double
        let mealCount: Int

        var hasSignal: Bool {
            calories > 0 ||
                protein > 0 ||
                carbs > 0 ||
                fats > 0 ||
                fiber > 0 ||
                waterLiters > 0 ||
                mealCount > 0
        }
    }

    func nutritionTotals(
        for date: Date,
        today: Date,
        dayActivities: [PlannedActivity],
        nutritionViewModel: NutritionViewModel,
        calendar: Calendar
    ) -> NutritionTotals {
        let completedFood = dayActivities.filter {
            $0.isCompleted &&
                !$0.isSkipped &&
                ($0.timelineEventKind == .food || $0.timelineEventKind == .drink)
        }

        let plannedTotals = NutritionTotals(
            calories: Double(completedFood.reduce(0) { $0 + $1.calories }),
            protein: Double(completedFood.reduce(0) { $0 + $1.protein }),
            carbs: Double(completedFood.reduce(0) { $0 + $1.carbs }),
            fats: Double(completedFood.reduce(0) { $0 + $1.fats }),
            fiber: Double(completedFood.reduce(0) { $0 + $1.fiber }),
            waterLiters: waterLiters(from: dayActivities),
            mealCount: completedFood.filter { $0.timelineEventKind == .food }.count
        )

        guard calendar.isDate(date, inSameDayAs: today),
              let todayMetrics = nutritionViewModel.currentMetrics else {
            return plannedTotals
        }

        return NutritionTotals(
            calories: max(plannedTotals.calories, todayMetrics.calories),
            protein: max(plannedTotals.protein, todayMetrics.protein),
            carbs: max(plannedTotals.carbs, todayMetrics.carbs),
            fats: max(plannedTotals.fats, todayMetrics.fats),
            fiber: max(plannedTotals.fiber, todayMetrics.fiber),
            waterLiters: max(plannedTotals.waterLiters, todayMetrics.waterLiters),
            mealCount: max(plannedTotals.mealCount, todayMetrics.calories > 0 ? 1 : 0)
        )
    }

    func activityVolume(
        from metrics: ActivityMetricsSnapshot,
        dayActivities: [PlannedActivity]
    ) -> Int {
        let completedWorkoutMinutes = dayActivities
            .filter {
                $0.isCompleted &&
                    !$0.isSkipped &&
                    $0.timelineEventKind == .workout
            }
            .reduce(0) { $0 + $1.effectiveDurationMinutes }

        let load = metrics.activeCalories +
            Double(metrics.exerciseMinutes * 8) +
            Double(metrics.steps) / 100.0 +
            Double(completedWorkoutMinutes * 5)

        return max(0, Int(load.rounded()))
    }

    func nutritionScore(from totals: NutritionTotals, goals: NutritionGoals?) -> Int {
        guard totals.hasSignal else { return 0 }

        guard let goals else {
            return clampedScore(totals.mealCount * 25)
        }

        let macroScore = average([
            adherenceScore(current: totals.protein, goal: goals.protein),
            adherenceScore(current: totals.carbs, goal: goals.carbs),
            adherenceScore(current: totals.fats, goal: goals.fats),
            adherenceScore(current: totals.fiber, goal: goals.fiber)
        ])

        let weightedScore =
            adherenceScore(current: totals.calories, goal: goals.calories) * 0.35 +
            adherenceScore(current: totals.protein, goal: goals.protein) * 0.25 +
            macroScore * 0.25 +
            adherenceScore(current: totals.waterLiters, goal: goals.waterLiters) * 0.15

        return clampedScore(Int(weightedScore.rounded()))
    }

    func waterLiters(from activities: [PlannedActivity]) -> Double {
        let completedHydrationLogs = activities.filter {
            $0.isCompleted &&
                !$0.isSkipped &&
                $0.timelineEventKind == .drink &&
                QuickLogActivityPortions.isHydrationLog($0)
        }

        return QuickLogActivityPortions.totalWaterLiters(from: completedHydrationLogs)
    }

    func adherenceScore(current: Double, goal: Double) -> Double {
        guard goal > 0, current > 0 else { return 0 }
        let ratio = current / goal
        let distanceFromTarget = min(abs(1.0 - ratio), 1.0)
        return (1.0 - distanceFromTarget) * 100.0
    }

    func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    func clampedScore(_ value: Int) -> Int {
        min(max(value, 0), 100)
    }
}
