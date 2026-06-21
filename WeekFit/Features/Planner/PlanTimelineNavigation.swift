import Foundation
import HealthKit
import SwiftUI
import WeekFitPlanner

enum PlanTimelineRouter {

    static func meal(
        for activity: PlannedActivity,
        customMeals: [Meals]
    ) -> Meals {
        if let matched = matchingCustomMeal(for: activity, in: customMeals) {
            return matched
        }
        return Meals.fromLoggedActivity(activity)
    }

    static func shouldOpenNutrition(for activity: PlannedActivity) -> Bool {
        activity.timelineEventKind == .drink
    }

    static func shouldOpenActivityDetail(for activity: PlannedActivity) -> Bool {
        switch activity.timelineEventKind {
        case .workout, .recovery, .sauna, .plannedActivity, .calendar, .sleep:
            return true
        case .food, .drink, .bodyWeight, .mood, .coachNote:
            return false
        }
    }

    private static func matchingCustomMeal(
        for activity: PlannedActivity,
        in customMeals: [Meals]
    ) -> Meals? {
        guard activity.type.lowercased() == "meal" else { return nil }

        let normalizedTitle = CustomMealStore.normalizedTitle(activity.title)
        guard !normalizedTitle.isEmpty else { return nil }

        return customMeals.first {
            CustomMealStore.normalizedTitle($0.title) == normalizedTitle
        }
    }
}

@MainActor
struct PlannedActivitySessionResolver {

    private let snapshotProvider = ActivityIntelligenceSnapshotProvider()

    func resolve(
        _ activity: PlannedActivity,
        healthManager: HealthManager
    ) async -> ActivitySessionSnapshot {
        if let workoutID = activity.healthKitWorkoutUUID.flatMap(UUID.init(uuidString:)),
           let workout = await healthManager.loadWorkout(id: workoutID, near: activity.date) {
            return snapshotProvider.makeSnapshot(from: workout)
        }

        return snapshotProvider.makePlannedActivitySnapshot(activity)
    }
}

extension Meals {

    static func fromLoggedActivity(_ activity: PlannedActivity) -> Meals {
        let subtitle = activity.calories > 0
            ? String(format: WeekFitLocalizedString("planner.activitySubtitle.mealCaloriesFormat"), activity.calories)
            : WeekFitLocalizedString("planner.loggedMeal")

        let isCustomFood = isCustomFoodActivity(activity)

        return Meals(
            id: activity.id,
            title: activity.title,
            subtitle: subtitle,
            imageName: activity.imageName,
            type: .balanced,
            calories: activity.calories,
            protein: activity.protein,
            carbs: activity.carbs,
            fats: activity.fats,
            fiber: activity.fiber,
            benefits: [],
            ingredients: [],
            libraryKind: isCustomFood ? .product : .meal,
            creationMode: isCustomFood ? .manual : nil
        )
    }

    private static func isCustomFoodActivity(_ activity: PlannedActivity) -> Bool {
        let source = activity.source.lowercased()
        return source == "today"
            || source == "nutritionlog"
            || source == "foodlog"
    }
}
