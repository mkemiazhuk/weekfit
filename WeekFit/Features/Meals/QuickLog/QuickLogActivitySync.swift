import Foundation
import SwiftData

enum QuickLogActivitySync {

    @MainActor
    static func sync(
        profile: QuickLogNutritionProfile,
        selection: QuickLogSelection,
        plannedActivities: [PlannedActivity],
        modelContext: ModelContext,
        analyticsSource: AnalyticsSource = .today,
        analyticsMethod: FoodLoggingMethod = .quickLog
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
            do {
                try modelContext.save()
                recordSuccessfulLog(
                    kind: profile.kind,
                    source: analyticsSource,
                    method: analyticsMethod
                )
            } catch {
                recordFailedLog(kind: profile.kind, source: analyticsSource, method: analyticsMethod)
            }
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
        do {
            try modelContext.save()
            recordSuccessfulLog(
                kind: profile.kind,
                source: analyticsSource,
                method: analyticsMethod
            )
        } catch {
            modelContext.delete(activity)
            recordFailedLog(kind: profile.kind, source: analyticsSource, method: analyticsMethod)
            return nil
        }

        return activity.id
    }

    @MainActor
    private static func recordSuccessfulLog(
        kind: QuickLogItemKind,
        source: AnalyticsSource,
        method: FoodLoggingMethod
    ) {
        switch kind {
        case .drink:
            ReviewEngagement.record(.drinkLogged)
            ProductAnalytics.hydrationLoggingCompleted(
                method: method == .quickLog ? .quickLog : .other,
                source: source
            )
        case .meal, .snack:
            ReviewEngagement.record(.foodLogged)
            ProductAnalytics.foodLoggingCompleted(method: method, source: source)
        }
    }

    @MainActor
    private static func recordFailedLog(
        kind: QuickLogItemKind,
        source: AnalyticsSource,
        method: FoodLoggingMethod
    ) {
        switch kind {
        case .drink:
            ProductAnalytics.hydrationLoggingFailed(
                method: method == .quickLog ? .quickLog : .other,
                source: source,
                reason: .saveFailed
            )
        case .meal, .snack:
            ProductAnalytics.foodLoggingFailed(method: method, source: source, reason: .saveFailed)
        }
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
