import Foundation
import WeekFitPlanner

enum PlannedActivityNutritionResolver {

    static func resolvedFiber(for activity: PlannedActivity, in catalog: [Meals]) -> Int {
        if activity.fiber > 0 {
            return activity.fiber
        }

        return matchedMeal(for: activity, in: catalog)?.fiber ?? 0
    }

    static func matchedMeal(for activity: PlannedActivity, in catalog: [Meals]) -> Meals? {
        let activityType = activity.type.lowercased()
        guard activityType == "meal" || activityType == "drink" else { return nil }

        let normalizedTitle = CustomMealStore.normalizedTitle(activity.title)
        if !normalizedTitle.isEmpty,
           let titleMatch = catalog.first(where: {
               CustomMealStore.normalizedTitle($0.title) == normalizedTitle
           }) {
            return titleMatch
        }

        let activityTitle = activity.title.normalized
        let activityImage = activity.imageName.normalized

        if !activityTitle.isEmpty,
           let exactTitleMatch = catalog.first(where: { $0.title.normalized == activityTitle }) {
            return exactTitleMatch
        }

        if !activityImage.isEmpty,
           let imageMatch = catalog.first(where: { $0.imageName.normalized == activityImage }) {
            return imageMatch
        }

        if !activityTitle.isEmpty,
           let containsMatch = catalog.first(where: {
               let mealTitle = $0.title.normalized
               return mealTitle.contains(activityTitle) || activityTitle.contains(mealTitle)
           }) {
            return containsMatch
        }

        return nil
    }
}

private extension String {
    var normalized: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
