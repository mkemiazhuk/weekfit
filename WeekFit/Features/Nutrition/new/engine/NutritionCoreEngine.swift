import Foundation
import SwiftUI
import SwiftData

@MainActor
enum NutritionCoreEngine {
    
    static func calculate(
        from metrics: DailyNutritionMetrics,
        profile: UserNutritionProfile,
        activities: [PlannedActivity]
    ) -> NutritionResult {
        
        let goals = NutritionGoalEngine.calculate(
            metrics: metrics,
            profile: profile
        )
        
        let brain = HumanBrain.build(
            metrics: metrics,
            profile: profile,
            baseDayGoals: goals.baseDay,
            fullDayGoals: goals.fullDay,
            smoothedGoals: goals.smoothed,
            activities: activities
        )
        
        let decision = CoachDecisionEngine.makeDecision(
            from: brain
        )
        
        let insights = CoachInsightFactory.generateInsights(
            brain: brain,
            decision: decision
        )
        
        let score = NutritionScoreEngine.calculateScore(
            metrics: metrics,
            goals: goals.fullDay
        )
        
        return NutritionResult(
            score: score,
            status: CoachCopy.headline(
                brain: brain,
                decision: decision
            ),
            goals: goals.fullDay,
            targetCalories: goals.fullDay.calories,
            consumedCalories: metrics.calories,
            recommendation: CoachCopy.summary(
                brain: brain,
                decision: decision,
                complianceScore: score
            ),
            activeInsights: insights,
            brain: brain,
            decision: decision
        )
    }
}


