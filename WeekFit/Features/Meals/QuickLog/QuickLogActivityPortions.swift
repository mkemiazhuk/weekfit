import Foundation
import WeekFitPlanner

enum QuickLogActivityPortions {

    private static let legacyDrinkDuration = 5
    private static let legacyMealDuration = 15
    private static let waterMillilitersThreshold = 50
    private static let defaultWaterServingML = 250

    static func encodeDurationMinutes(
        profile: QuickLogNutritionProfile,
        nutrition: QuickLogNutritionValues
    ) -> Int {
        if profile.isWater {
            let ml = nutrition.milliliters
                ?? (nutrition.portions * (profile.mlPerServing ?? Double(defaultWaterServingML)))
            return max(Int(ml.rounded()), defaultWaterServingML)
        }

        return max(Int((nutrition.portions * 10).rounded()), 10)
    }

    static func portions(for activity: PlannedActivity) -> Double? {
        guard isQuickLogNutritionActivity(activity) else { return nil }

        if isWaterActivity(activity) {
            let ml = waterMilliliters(for: activity)
            return Double(ml) / Double(defaultWaterServingML)
        }

        if activity.durationMinutes == legacyDrinkDuration
            || activity.durationMinutes == legacyMealDuration {
            return 1
        }

        guard activity.durationMinutes >= 1 else { return nil }
        return Double(activity.durationMinutes) / 10
    }

    static func isHydrationLog(_ activity: PlannedActivity) -> Bool {
        if isWaterActivity(activity) { return true }

        let source = activity.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return source == "waterlog"
    }

    static func hydrationVolumeMilliliters(for activity: PlannedActivity) -> Int {
        storedWaterMilliliters(for: activity)
    }

    static func waterMilliliters(for activity: PlannedActivity) -> Int {
        guard isHydrationLog(activity) else { return 0 }
        return storedWaterMilliliters(for: activity)
    }

    static func totalWaterMilliliters(from activities: [PlannedActivity]) -> Int {
        activities.reduce(into: 0) { total, activity in
            guard activity.isCompleted, !activity.isSkipped, isHydrationLog(activity) else { return }
            total += storedWaterMilliliters(for: activity)
        }
    }

    static func totalWaterLiters(from activities: [PlannedActivity]) -> Double {
        Double(totalWaterMilliliters(from: activities)) / 1000.0
    }

    static func metadataPrimary(for activity: PlannedActivity) -> String? {
        guard isQuickLogNutritionActivity(activity) else { return nil }

        if isWaterActivity(activity) {
            return waterMetadata(for: activity)
        }

        guard let portions = portions(for: activity) else { return nil }

        if portions > 1 {
            if activity.calories > 0 {
                return String(
                    format: WeekFitLocalizedString("nutrition.details.meal.caloriesFormat"),
                    activity.calories
                )
            }
            return WeekFitCountPluralization.portionsPhrase(
                quantity: portions,
                formattedQuantity: formattedPortions(portions)
            )
        }

        if activity.type.lowercased() == "meal", activity.calories > 0 {
            return String(
                format: WeekFitLocalizedString("nutrition.details.meal.caloriesFormat"),
                activity.calories
            )
        }

        return nil
    }

    static func formattedPortions(_ value: Double) -> String {
        QuickLogServingMath.formattedQuantity(value)
    }

    private static func waterMetadata(for activity: PlannedActivity) -> String {
        let ml = waterMilliliters(for: activity)
        if ml >= 1000 {
            return WeekFitLocalizedString("quickLog.quantity.water.oneLiter")
        }
        return String(format: WeekFitLocalizedString("common.unit.millilitersFormat"), ml)
    }

    private static func isQuickLogNutritionActivity(_ activity: PlannedActivity) -> Bool {
        guard activity.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "today" else {
            return false
        }

        switch activity.timelineEventKind {
        case .food, .drink:
            return true
        default:
            return false
        }
    }

    private static func isWaterActivity(_ activity: PlannedActivity) -> Bool {
        let image = activity.imageName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return image == "hydration" || title == "water"
    }

    private static func storedWaterMilliliters(for activity: PlannedActivity) -> Int {
        if activity.durationMinutes >= waterMillilitersThreshold {
            return activity.durationMinutes
        }

        return defaultWaterServingML
    }
}
