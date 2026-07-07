import Foundation

enum NutritionQualityPresenter {

    struct Input: Equatable {
        let protein: Double
        let carbs: Double
        let fats: Double
        let fiber: Double
        let calories: Double
        let proteinGoal: Double
        let carbsGoal: Double
        let fatsGoal: Double
        let fiberGoal: Double
        let caloriesGoal: Double
        let mealsLogged: Bool
        let isToday: Bool
    }

    struct MacroProgress: Equatable {
        let protein: Double
        let carbs: Double
        let fats: Double
        let fiber: Double
        let calories: Double
    }

    enum PrimaryInsight: Equatable {
        case noMealsLogged
        case proteinWellBelowTarget
        case sufficientCaloriesLowProtein
        case fiberLow
        case carbsLow
        case fatsLow
        case proteinBelowTarget
        case carbsBelowTarget
        case fatsBelowTarget
        case fiberBelowTarget
        case macrosWellBalanced
        case greatProteinIntake
    }

    static func qualityScore(for input: Input) -> Int {
        let values = [
            macroProgress(value: input.protein, goal: input.proteinGoal),
            macroProgress(value: input.carbs, goal: input.carbsGoal),
            macroProgress(value: input.fats, goal: input.fatsGoal),
            macroProgress(value: input.fiber, goal: input.fiberGoal)
        ]

        guard !values.isEmpty else { return 0 }

        return Int((values.reduce(0, +) / Double(values.count) * 100).rounded())
    }

    static func macroProgress(for input: Input) -> MacroProgress {
        MacroProgress(
            protein: macroProgress(value: input.protein, goal: input.proteinGoal),
            carbs: macroProgress(value: input.carbs, goal: input.carbsGoal),
            fats: macroProgress(value: input.fats, goal: input.fatsGoal),
            fiber: macroProgress(value: input.fiber, goal: input.fiberGoal),
            calories: macroProgress(value: input.calories, goal: input.caloriesGoal)
        )
    }

    static func primaryInsight(for input: Input) -> PrimaryInsight {
        guard input.mealsLogged else {
            return .noMealsLogged
        }

        let progress = macroProgress(for: input)

        if progress.protein >= 0.85 &&
            progress.carbs >= 0.85 &&
            progress.fats >= 0.85 &&
            progress.fiber >= 0.85 {
            return .macrosWellBalanced
        }

        if progress.protein >= 0.90 &&
            progress.protein >= progress.carbs &&
            progress.protein >= progress.fats &&
            progress.protein >= progress.fiber {
            return .greatProteinIntake
        }

        if progress.protein < 0.55 {
            return .proteinWellBelowTarget
        }

        if progress.calories >= 0.75 && progress.protein < 0.65 {
            return .sufficientCaloriesLowProtein
        }

        if progress.fiber < 0.50 {
            return .fiberLow
        }

        if progress.fats < 0.45 {
            return .fatsLow
        }

        if progress.carbs < 0.55 {
            return .carbsLow
        }

        let lowest = [
            (PrimaryInsight.proteinBelowTarget, progress.protein),
            (PrimaryInsight.carbsBelowTarget, progress.carbs),
            (PrimaryInsight.fatsBelowTarget, progress.fats),
            (PrimaryInsight.fiberBelowTarget, progress.fiber)
        ].min { $0.1 < $1.1 }

        return lowest?.0 ?? .macrosWellBalanced
    }

    static func primaryInsightText(for input: Input) -> String {
        switch primaryInsight(for: input) {
        case .noMealsLogged:
            return input.isToday
                ? WeekFitLocalizedString("nutrition.details.quality.insight.noMealsToday")
                : WeekFitLocalizedString("nutrition.details.quality.insight.noMealsPastDay")
        case .proteinWellBelowTarget:
            return WeekFitLocalizedString("nutrition.details.quality.insight.proteinWellBelow")
        case .sufficientCaloriesLowProtein:
            return WeekFitLocalizedString("nutrition.details.quality.insight.caloriesOkProteinLow")
        case .fiberLow:
            return WeekFitLocalizedString("nutrition.details.quality.insight.fiberLow")
        case .carbsLow:
            return WeekFitLocalizedString("nutrition.details.quality.insight.carbsLow")
        case .fatsLow:
            return WeekFitLocalizedString("nutrition.details.quality.insight.fatsLow")
        case .proteinBelowTarget:
            return WeekFitLocalizedString("nutrition.details.quality.insight.proteinBelow")
        case .carbsBelowTarget:
            return WeekFitLocalizedString("nutrition.details.quality.insight.carbsBelow")
        case .fatsBelowTarget:
            return WeekFitLocalizedString("nutrition.details.quality.insight.fatsBelow")
        case .fiberBelowTarget:
            return WeekFitLocalizedString("nutrition.details.quality.insight.fiberBelow")
        case .macrosWellBalanced:
            return WeekFitLocalizedString("nutrition.details.quality.insight.wellBalanced")
        case .greatProteinIntake:
            return WeekFitLocalizedString("nutrition.details.quality.insight.greatProtein")
        }
    }

    static func subtitleText(isToday: Bool) -> String {
        isToday
            ? WeekFitLocalizedString("nutrition.details.quality.subtitle.today")
            : WeekFitLocalizedString("nutrition.details.quality.subtitle.pastDay")
    }

    private static func macroProgress(value: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(value / goal, 0), 1)
    }
}
