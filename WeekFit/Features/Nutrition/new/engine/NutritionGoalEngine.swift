import Foundation

struct NutritionGoalSet {
    let baseDay: NutritionGoals
    let fullDay: NutritionGoals
    let smoothed: NutritionGoals
}

enum NutritionGoalEngine {
    
    private static let metabolicCalculator = MetabolicRateCalculator()
    private static let macroAdjuster = DynamicMacroAdjuster()
    private static let timeScoringEngine = TimeAdaptiveScoringEngine()
    
    static func calculate(
        metrics: DailyNutritionMetrics,
        profile: UserNutritionProfile
    ) -> NutritionGoalSet {
        
        let bmr = metabolicCalculator.calculateBMR(
            weight: profile.weightKg,
            height: profile.heightCm,
            age: profile.age,
            sex: profile.sex
        )
        
        let baseDayGoals = macroAdjuster.adjustGoals(
            bmr: bmr,
            activeCalories: 0,
            weight: profile.weightKg,
            goal: profile.goal
        )

        let fullDayGoals = macroAdjuster.adjustGoals(
            bmr: bmr,
            activeCalories: metrics.activeCalories,
            weight: profile.weightKg,
            goal: profile.goal
        )
        
        let smoothedGoals = timeScoringEngine.applyTimeSmoothing(
            to: fullDayGoals
        )
        
        return NutritionGoalSet(
            baseDay: baseDayGoals,
            fullDay: fullDayGoals,
            smoothed: smoothedGoals
        )
    }
}
