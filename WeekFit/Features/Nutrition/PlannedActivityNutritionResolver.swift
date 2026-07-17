import Foundation
import WeekFitPlanner

enum PlannedActivityNutritionResolver {

    static func resolvedFiber(for activity: PlannedActivity, in catalog: [Meals]) -> Int {
        if activity.fiber > 0 {
            return activity.fiber
        }

        if MealCatalogMatcher.prefersStoredNutrition(activity: activity) {
            return activity.fiber
        }

        return matchedMeal(for: activity, in: catalog)?.fiber ?? 0
    }

    static func matchedMeal(for activity: PlannedActivity, in catalog: [Meals]) -> Meals? {
        let activityType = activity.type.lowercased()
        guard activityType == "meal" || activityType == "drink" || activityType == "snack" else { return nil }

        if MealCatalogMatcher.prefersStoredNutrition(activity: activity) {
            return nil
        }

        let normalizedTitle = CustomMealStore.normalizedTitle(activity.title)
        if !normalizedTitle.isEmpty,
           let titleMatch = catalog.first(where: {
               CustomMealStore.normalizedTitle($0.title) == normalizedTitle
           }) {
            return titleMatch
        }

        return MealCatalogMatcher.match(activity: activity, in: catalog)
    }
}
