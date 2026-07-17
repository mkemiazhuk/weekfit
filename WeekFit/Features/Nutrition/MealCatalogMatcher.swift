import Foundation
import WeekFitPlanner

/// Resolves catalog meals for planned activities without fuzzy substring traps
/// (e.g. "Tea" must never match "Pork Steaks" because "steaks" contains "tea").
///
/// Future-proof rules when adding Quick Log drinks/snacks:
/// 1. Put macros on the activity at log time (Quick Log already does this).
/// 2. Keep `source` as `today` / `nutritionLog` / `appReviewDemo`.
/// 3. Log snacks with `type: snack` (drinks with `type: drink`) — those never rematch meals.
/// 4. Prefer `ingredient-*`, `snack-*`, or `recovery-*` image names.
/// 5. Do not rely on title/image fuzzy matching for calories.
enum MealCatalogMatcher {

    /// Sources that already write absolute nutrition onto the activity.
    static func hasAuthoritativeNutrition(source: String) -> Bool {
        let normalized = source
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch normalized {
        case "today", "nutritionlog", "waterlog", "applereviewdemo":
            return true
        default:
            return normalized.contains("reviewdemo")
        }
    }

    /// Quick Log / drink-snack assets carry their own macros — never replace with a meal row.
    static func prefersStoredNutrition(
        source: String,
        type: String,
        imageName: String
    ) -> Bool {
        if hasAuthoritativeNutrition(source: source) {
            return true
        }

        let normalizedType = type
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalizedType == "drink" || normalizedType == "snack" {
            return true
        }

        let image = normalize(imageName)
        if image == "hydration" {
            return true
        }

        // Shipping Quick Log assets (including a few legacy names without snack-/ingredient-).
        let protectedExactImages: Set<String> = [
            "protein-bar",
            "rice-cakes"
        ]
        if protectedExactImages.contains(image) {
            return true
        }

        let protectedPrefixes = ["ingredient-", "snack-", "recovery-"]
        return protectedPrefixes.contains { image.hasPrefix($0) }
    }

    static func prefersStoredNutrition(activity: PlannedActivity) -> Bool {
        prefersStoredNutrition(
            source: activity.source,
            type: activity.type,
            imageName: activity.imageName
        )
    }

    static func match(title: String, imageName: String, in meals: [Meals]) -> Meals? {
        let activityTitle = normalize(title)
        let activityImage = normalize(imageName)

        if !activityTitle.isEmpty,
           let exactTitleMatch = meals.first(where: { normalize($0.title) == activityTitle }) {
            return exactTitleMatch
        }

        // Only match stable meal artwork. Ingredient/quick-log asset names are shared
        // across many catalog items and must not remap drink/snack calories.
        if !activityImage.isEmpty,
           activityImage.hasPrefix("meal-"),
           let imageMatch = meals.first(where: { normalize($0.imageName) == activityImage }) {
            return imageMatch
        }

        return nil
    }

    static func match(activity: PlannedActivity, in meals: [Meals]) -> Meals? {
        if prefersStoredNutrition(activity: activity) {
            return nil
        }
        return match(title: activity.title, imageName: activity.imageName, in: meals)
    }

    /// Detects legacy fuzzy traps (substring contains) between catalogs.
    /// Used by regression tests so new items cannot reintroduce Tea→Steak bugs.
    static func substringCollisions(
        quickItems: [QuickItem],
        meals: [Meals]
    ) -> [(quickTitle: String, mealTitle: String, mealCalories: Int)] {
        var collisions: [(String, String, Int)] = []

        for item in quickItems {
            let quickTitle = normalize(item.title)
            guard !quickTitle.isEmpty else { continue }

            for meal in meals {
                let mealTitle = normalize(meal.title)
                guard !mealTitle.isEmpty, mealTitle != quickTitle else { continue }

                if mealTitle.contains(quickTitle) || quickTitle.contains(mealTitle) {
                    collisions.append((item.title, meal.title, meal.calories))
                }
            }
        }

        return collisions
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
