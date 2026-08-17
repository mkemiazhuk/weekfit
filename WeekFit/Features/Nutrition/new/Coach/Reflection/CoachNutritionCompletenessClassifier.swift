import Foundation

enum CoachNutritionCompletenessClassifier {

    static func classify(
        mealsLoggedCount: Int,
        caloriesEaten: Int,
        proteinGrams: Int,
        carbsGrams: Int,
        fatGrams: Int,
        hydrationLiters: Double
    ) -> CoachNutritionCompleteness {
        let hasMacroSignal =
            caloriesEaten > 0
            || proteinGrams > 0
            || carbsGrams > 0
            || fatGrams > 0

        if mealsLoggedCount <= 0 && !hasMacroSignal {
            return hydrationLiters > 0 ? .partial : .empty
        }

        if mealsLoggedCount >= 2 {
            return .complete
        }

        if mealsLoggedCount == 1 {
            return hasMacroSignal ? .partial : .empty
        }

        // HealthKit-only macros without in-app meal logs — usable but not fully trusted.
        if hasMacroSignal {
            return .partial
        }

        return .empty
    }
}

enum CoachNutritionSourceClassifier {

    static func infer(
        hasHealthKitSignal: Bool,
        hasPlannedMealSignal: Bool
    ) -> CoachNutritionSource {
        switch (hasHealthKitSignal, hasPlannedMealSignal) {
        case (true, true):
            return .mixed
        case (true, false):
            return .healthKit
        case (false, true):
            return .plannedMeals
        case (false, false):
            return .none
        }
    }
}

enum CoachPostWorkoutNutritionObservation {
    static let defaultWindowMinutes = 180

    static func hardestWorkoutEndMinutes(
        from workouts: [CoachWorkoutObservationSample]
    ) -> Int? {
        let hard = workouts.filter(\.isHardTraining)
        let candidates = hard.isEmpty ? workouts : hard
        return candidates.compactMap(\.endMinutesFromMidnight).max()
    }

    static func proteinGramsWithinWindow(
        dayStart: Date,
        workoutEndMinutes: Int?,
        plannedActivities: [CoachPlannedActivitySnapshot],
        calendar: Calendar = .current,
        windowMinutes: Int = defaultWindowMinutes
    ) -> Int? {
        guard let workoutEndMinutes,
              let workoutEnd = calendar.date(
                byAdding: .minute,
                value: workoutEndMinutes,
                to: dayStart
              ),
              let windowEnd = calendar.date(
                byAdding: .minute,
                value: windowMinutes,
                to: workoutEnd
              ) else {
            return nil
        }

        let protein = plannedActivities.reduce(0) { total, activity in
            guard activity.isCompleted, !activity.isSkipped else { return total }
            let type = activity.type
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let isMealLike = type == "meal" || type == "drink" || type == "snack"
            guard isMealLike else { return total }
            let text = "\(activity.type) \(activity.title) \(activity.imageName)".lowercased()
            if text.contains("hydration") || text.contains("water") {
                return total
            }
            guard activity.date >= workoutEnd, activity.date <= windowEnd else {
                return total
            }
            return total + max(activity.protein, 0)
        }

        return protein
    }
}
