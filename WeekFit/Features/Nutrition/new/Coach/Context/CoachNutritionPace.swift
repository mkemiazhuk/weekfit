import Foundation

/// Time-of-day aware fuel / hydration evaluation for Coach modifiers.
enum CoachNutritionPace {

    static func fuelState(
        nutrition: CoachNutritionContext?,
        hour: Int,
        activityFamily: CoachActivityFamily,
        durationBand: CoachDurationBand,
        completedSeriousActivities: CoachCompletedSeriousActivities = .none
    ) -> CoachFuelState {
        guard let nutrition else { return .unknown }

        let calorieProgress = progress(nutrition.caloriesCurrent, goal: nutrition.caloriesGoal)
        let proteinProgress = progress(nutrition.proteinCurrent, goal: nutrition.proteinGoal)

        let isLongEndurance = activityFamily == .endurance &&
            (durationBand == .long || durationBand == .extended)

        if isLongEndurance && calorieProgress < 0.30 {
            return .critical
        }

        let expectedCalories = expectedCalorieProgress(hour: hour)
        let expectedProtein = expectedProteinProgress(hour: hour)
        let calorieRelative = relativeProgress(actual: calorieProgress, expected: expectedCalories)
        let proteinRelative = relativeProgress(actual: proteinProgress, expected: expectedProtein)
        let threshold = behindThreshold(for: hour)

        // After serious training, either calories or protein lagging is enough —
        // don't wait for both to slip before asking for a meal.
        if completedSeriousActivities != .none {
            if calorieRelative < threshold || proteinRelative < threshold {
                return .behind
            }
            return .adequate
        }

        if calorieRelative < threshold && proteinRelative < threshold {
            return .behind
        }

        return .adequate
    }

    static func hydrationState(
        nutrition: CoachNutritionContext?,
        hour: Int,
        activityFamily: CoachActivityFamily,
        durationBand: CoachDurationBand,
        activityState: CoachActivityState
    ) -> CoachHydrationState {
        guard let nutrition else { return .unknown }

        let waterProgress = progress(nutrition.waterCurrent, goal: nutrition.waterGoal)
        let expectedWater = expectedHydrationProgress(hour: hour)
        let relative = relativeProgress(actual: waterProgress, expected: expectedWater)

        let isActiveLongEndurance = activityState == .active &&
            activityFamily == .endurance &&
            (durationBand == .long || durationBand == .extended)

        if isActiveLongEndurance && waterProgress < 0.25 {
            return .critical
        }

        if hour >= 20 && waterProgress < 0.25 {
            return .critical
        }

        if relative < criticalRelativeThreshold(
            hour: hour,
            activityState: activityState,
            activityFamily: activityFamily,
            durationBand: durationBand
        ) {
            return .critical
        }

        if relative < behindRelativeThreshold(
            hour: hour,
            activityState: activityState,
            activityFamily: activityFamily,
            durationBand: durationBand
        ) {
            return .behind
        }

        return .adequate
    }

    // MARK: - Expected pace

    static func expectedCalorieProgress(hour: Int) -> Double {
        interpolate(hour: hour, points: [
            (6, 0.05),
            (8, 0.12),
            (12, 0.38),
            (16, 0.62),
            (20, 0.88),
            (22, 1.00)
        ])
    }

    static func expectedProteinProgress(hour: Int) -> Double {
        interpolate(hour: hour, points: [
            (6, 0.04),
            (8, 0.10),
            (12, 0.28),
            (16, 0.52),
            (20, 0.84),
            (22, 0.96)
        ])
    }

    static func expectedHydrationProgress(hour: Int) -> Double {
        HumanBrain.expectedHydrationProgress(for: hour)
    }

    // MARK: - Private

    private static func progress(_ current: Double, goal: Double) -> Double {
        guard goal > 0 else { return 1 }
        return current / goal
    }

    private static func relativeProgress(actual: Double, expected: Double) -> Double {
        guard expected > 0 else { return 1 }
        return actual / expected
    }

    private static func behindThreshold(for hour: Int) -> Double {
        hour < 10 ? 0.50 : 0.75
    }

    private static func behindRelativeThreshold(
        hour: Int,
        activityState: CoachActivityState,
        activityFamily: CoachActivityFamily,
        durationBand: CoachDurationBand
    ) -> Double {
        if activityState == .active,
           activityFamily == .endurance,
           durationBand == .long || durationBand == .extended {
            return 0.90
        }
        if hour < 10 {
            return 0.50
        }
        return 0.75
    }

    private static func criticalRelativeThreshold(
        hour: Int,
        activityState: CoachActivityState,
        activityFamily: CoachActivityFamily,
        durationBand: CoachDurationBand
    ) -> Double {
        if activityState == .active,
           activityFamily == .endurance,
           durationBand == .long || durationBand == .extended {
            return 0.50
        }
        if hour >= 12 {
            return 0.50
        }
        return 0.35
    }

    private static func interpolate(hour: Int, points: [(Int, Double)]) -> Double {
        guard let first = points.first, let last = points.last else { return 1 }
        if hour <= first.0 { return first.1 }
        if hour >= last.0 { return last.1 }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let next = points[index]
            guard hour <= next.0 else { continue }
            let span = Double(next.0 - previous.0)
            let progress = span > 0 ? Double(hour - previous.0) / span : 1
            return previous.1 + ((next.1 - previous.1) * progress)
        }

        return last.1
    }
}
