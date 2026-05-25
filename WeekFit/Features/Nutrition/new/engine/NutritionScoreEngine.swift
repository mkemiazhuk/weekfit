import Foundation

enum NutritionScoreEngine {
    
    static func calculateScore(
        metrics: DailyNutritionMetrics,
        goals: NutritionGoals
    ) -> Double {
        
        let caloriesTarget = max(goals.calories, 1.0)
        let progress = metrics.calories / caloriesTarget * 100.0
        
        return min(
            max(progress, 0.0),
            100.0
        )
    }
}
