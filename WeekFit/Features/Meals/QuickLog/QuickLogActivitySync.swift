import Foundation
import SwiftData

enum QuickLogActivitySync {

    @MainActor
    static func sync(
        profile: QuickLogNutritionProfile,
        selection: QuickLogSelection,
        plannedActivities: [PlannedActivity],
        modelContext: ModelContext
    ) -> String? {
        let nutrition = QuickLogServingMath.nutrition(for: profile, selection: selection)
        let effectivePortions = nutrition.portions

        if effectivePortions <= 0 {
            if let activityID = selection.loggedActivityID,
               let activity = plannedActivities.first(where: { $0.id == activityID }) {
                ActivityNotificationService.shared.cancelNotifications(for: activity)
                modelContext.delete(activity)
                try? modelContext.save()
            }
            return nil
        }

        let colors = accentColors(for: profile.kind)
        let activityType: String = {
            switch profile.kind {
            case .drink: return "drink"
            case .snack: return "snack"
            case .meal: return "meal"
            }
        }()
        let durationMinutes = QuickLogActivityPortions.encodeDurationMinutes(
            profile: profile,
            nutrition: nutrition
        )

        if let activityID = selection.loggedActivityID,
           let activity = plannedActivities.first(where: { $0.id == activityID }) {
            activity.calories = nutrition.calories
            activity.protein = nutrition.protein
            activity.carbs = nutrition.carbs
            activity.fats = nutrition.fats
            activity.fiber = nutrition.fiber
            activity.durationMinutes = durationMinutes
            activity.isCompleted = true
            activity.isSkipped = false
            try? modelContext.save()
            return activityID
        }

        let activity = PlannedActivity(
            id: UUID().uuidString,
            date: Date(),
            type: activityType,
            title: profile.title,
            durationMinutes: durationMinutes,
            icon: profile.icon,
            imageName: profile.isWater ? "hydration" : profile.imageName,
            colorRed: colors.red,
            colorGreen: colors.green,
            colorBlue: colors.blue,
            calories: nutrition.calories,
            protein: nutrition.protein,
            carbs: nutrition.carbs,
            fats: nutrition.fats,
            fiber: nutrition.fiber,
            isCompleted: true,
            isSkipped: false,
            source: "today"
        )

        AppReviewDemoPlannedActivityTagger.tagIfNeeded(activity)
        modelContext.insert(activity)
        try? modelContext.save()

        return activity.id
    }

    private static func accentColors(for kind: QuickLogItemKind) -> (red: Double, green: Double, blue: Double) {
        switch kind {
        case .drink:
            return (0.25, 0.55, 0.95)
        case .meal, .snack:
            return (0.50, 0.74, 0.54)
        }
    }
}
