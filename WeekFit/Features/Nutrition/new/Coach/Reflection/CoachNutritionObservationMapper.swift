import Foundation
import WeekFitPlanner

enum CoachNutritionObservationMapper {

    static func mealsLoggedCount(
        for date: Date,
        plannedActivities: [CoachPlannedActivitySnapshot]
    ) -> Int {
        completedMealActivities(for: date, plannedActivities: plannedActivities).count
    }

    static func resolvedTotals(
        for date: Date,
        plannedActivities: [CoachPlannedActivitySnapshot],
        healthSnapshot: NutritionMetricsSnapshot?
    ) -> (totals: CoachDailyObservationNutritionBuilder.ResolvedDayTotals, isAvailable: Bool)? {
        let mealActivities = completedMealActivities(for: date, plannedActivities: plannedActivities)
        let hydrationActivities = completedHydrationActivities(for: date, plannedActivities: plannedActivities)

        let planned = mealActivities.isEmpty
            ? .zero
            : plannedNutritionTotals(from: mealActivities)
        let plannedWater = hydrationActivities.isEmpty
            ? 0.0
            : plannedWaterLiters(from: hydrationActivities)
        let mealsLoggedCount = mealActivities.count

        guard let healthSnapshot else {
            guard planned.hasSignal || plannedWater > 0 || mealsLoggedCount > 0 else {
                return nil
            }

            return (
                CoachDailyObservationNutritionBuilder.ResolvedDayTotals(
                    proteinGrams: planned.protein,
                    carbsGrams: planned.carbs,
                    fatGrams: planned.fats,
                    caloriesEaten: planned.calories,
                    hydrationLiters: plannedWater,
                    mealsLoggedCount: mealsLoggedCount
                ),
                true
            )
        }

        return (
            CoachDailyObservationNutritionBuilder.ResolvedDayTotals(
                proteinGrams: max(healthSnapshot.protein, planned.protein),
                carbsGrams: max(healthSnapshot.carbs, planned.carbs),
                fatGrams: max(healthSnapshot.fats, planned.fats),
                caloriesEaten: max(healthSnapshot.calories, planned.calories),
                hydrationLiters: max(healthSnapshot.waterLiters, plannedWater),
                mealsLoggedCount: max(healthSnapshot.mealsLoggedCount, mealsLoggedCount)
            ),
            healthSnapshot.isResolved
        )
    }

    /// Boundary adapter for call sites that still hold live SwiftData rows.
    static func resolvedTotals(
        for date: Date,
        plannedActivities activities: [PlannedActivity],
        healthSnapshot: NutritionMetricsSnapshot?
    ) -> (totals: CoachDailyObservationNutritionBuilder.ResolvedDayTotals, isAvailable: Bool)? {
        resolvedTotals(
            for: date,
            plannedActivities: activities.coachSnapshots(),
            healthSnapshot: healthSnapshot
        )
    }

    static func mealsLoggedCount(
        for date: Date,
        plannedActivities activities: [PlannedActivity]
    ) -> Int {
        mealsLoggedCount(for: date, plannedActivities: activities.coachSnapshots())
    }

    // MARK: - Planned logs

    private struct PlannedNutritionTotals: Equatable {
        let protein: Double
        let carbs: Double
        let fats: Double
        let calories: Double

        static let zero = PlannedNutritionTotals(protein: 0, carbs: 0, fats: 0, calories: 0)

        var hasSignal: Bool {
            protein > 0 || carbs > 0 || fats > 0 || calories > 0
        }
    }

    private static func plannedNutritionTotals(
        from activities: [CoachPlannedActivitySnapshot]
    ) -> PlannedNutritionTotals {
        let needsLibraryMatch = activities.contains {
            $0.protein == 0 && $0.carbs == 0 && $0.fats == 0 && $0.calories == 0
        }
        let meals = needsLibraryMatch ? NutritionRepository().loadMeals() : []

        var protein = 0.0
        var carbs = 0.0
        var fats = 0.0
        var calories = 0.0

        for activity in activities {
            if let matchedMeal = matchMeal(for: activity, in: meals) {
                protein += Double(matchedMeal.protein)
                carbs += Double(matchedMeal.carbs)
                fats += Double(matchedMeal.fats)
                calories += Double(matchedMeal.calories)
            } else {
                protein += Double(activity.protein)
                carbs += Double(activity.carbs)
                fats += Double(activity.fats)
                calories += Double(activity.calories)
            }
        }

        return PlannedNutritionTotals(
            protein: protein,
            carbs: carbs,
            fats: fats,
            calories: calories
        )
    }

    private static func plannedWaterLiters(
        from activities: [CoachPlannedActivitySnapshot]
    ) -> Double {
        let needsLibraryMatch = activities.contains {
            !isHydrationActivityByText($0) && $0.calories == 0 && $0.durationMinutes == 0
        }
        let meals = needsLibraryMatch ? NutritionRepository().loadMeals() : []

        let totalMilliliters = activities.reduce(0) { total, activity in
            if isHydrationActivityByText(activity) {
                return total + hydrationVolumeMilliliters(for: activity)
            }
            if let matchedMeal = matchMeal(for: activity, in: meals), matchedMeal.type == .hydration {
                return total + hydrationVolumeMilliliters(for: activity)
            }
            return total
        }
        return Double(totalMilliliters) / 1_000.0
    }

    private static func completedMealActivities(
        for date: Date,
        plannedActivities: [CoachPlannedActivitySnapshot]
    ) -> [CoachPlannedActivitySnapshot] {
        plannedActivities.filter { activity in
            guard Calendar.current.isDate(activity.date, inSameDayAs: date) else { return false }
            guard activity.isCompleted, !activity.isSkipped else { return false }
            let type = normalized(activity.type)
            return (type == "meal" || type == "drink") && !isHydrationActivityByText(activity)
        }
    }

    private static func completedHydrationActivities(
        for date: Date,
        plannedActivities: [CoachPlannedActivitySnapshot]
    ) -> [CoachPlannedActivitySnapshot] {
        plannedActivities.filter { activity in
            guard Calendar.current.isDate(activity.date, inSameDayAs: date) else { return false }
            guard activity.isCompleted, !activity.isSkipped else { return false }
            return isHydrationActivityByText(activity)
        }
    }

    private static func matchMeal(for activity: CoachPlannedActivitySnapshot, in meals: [Meals]) -> Meals? {
        let activityTitle = normalized(activity.title)
        let activityImage = normalized(activity.imageName)

        if let exactTitleMatch = meals.first(where: { normalized($0.title) == activityTitle }) {
            return exactTitleMatch
        }
        if let imageMatch = meals.first(where: { normalized($0.imageName) == activityImage }) {
            return imageMatch
        }
        if let containsMatch = meals.first(where: {
            let mealTitle = normalized($0.title)
            return mealTitle.contains(activityTitle) || activityTitle.contains(mealTitle)
        }) {
            return containsMatch
        }
        return nil
    }

    private static func isHydrationActivityByText(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        let text = normalized("\(activity.type) \(activity.title) \(activity.imageName)")
        return text.contains("hydration") || text.contains("water")
    }

    private static func hydrationVolumeMilliliters(for activity: CoachPlannedActivitySnapshot) -> Int {
        if activity.durationMinutes >= 50 {
            return activity.durationMinutes
        }
        return 250
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }
}
