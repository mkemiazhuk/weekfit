//import Foundation
//
//
//struct DailyNutritionMetrics {
//    var protein: Double
//    var carbs: Double
//    var fats: Double
//    var calories: Double
//    var waterLiters: Double
//    var activeCalories: Double
//    var sleepHours: Double
//    var weightKg: Double
//}
//
//struct NutritionGoals {
//    var protein: Double
//    var carbs: Double
//    var fats: Double
//    var calories: Double
//    var waterLiters: Double
//}
//
//enum NutritionEngine {
//
//    static func calculate(
//        from metrics: DailyNutritionMetrics,
//        profile: UserNutritionProfile
//    ) -> NutritionResult {
//
//        let fullDayGoals = makeGoals(from: metrics, profile: profile)
//        let adjustedGoals = applyDayProgress(to: fullDayGoals)
//
//        let proteinScore = goalScore(metrics.protein, adjustedGoals.protein)
//        let waterScore = goalScore(metrics.waterLiters, adjustedGoals.waterLiters)
//        let caloriesScore = goalScore(metrics.calories, adjustedGoals.calories)
//        let carbsScore = goalScore(metrics.carbs, adjustedGoals.carbs)
//        let fatsScore = goalScore(metrics.fats, adjustedGoals.fats)
//
//        let score =
//            proteinScore * 0.35 +
//            waterScore * 0.20 +
//            caloriesScore * 0.20 +
//            carbsScore * 0.15 +
//            fatsScore * 0.10
//
//        let finalScore = min(max(score, 0), 100)
//        
//        let insights = [DynamicInsight]()
//
//        return NutritionResult(
//            score: finalScore,
//            status: status(for: finalScore),
//            goals: fullDayGoals,
//            targetCalories: adjustedGoals.calories,
//            consumedCalories: metrics.calories,
//            recommendation: recommendation(
//                metrics: metrics,
//                goals: adjustedGoals,
//                score: finalScore
//            ),
//            activeInsights: insights
//        )
//    }
//
//    private static func makeGoals(
//        from metrics: DailyNutritionMetrics,
//        profile: UserNutritionProfile
//    ) -> NutritionGoals {
//
//        let weight = max(profile.weightKg, metrics.weightKg, 40)
//        let height = max(profile.heightCm, 120)
//        let age = max(profile.age, 12)
//
//        let bmr: Double
//
//        switch profile.sex {
//        case .male:
//            bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
//
//        case .female:
//            bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 161
//
//        case .unknown:
//            let maleBMR = 10 * weight + 6.25 * height - 5 * Double(age) + 5
//            let femaleBMR = 10 * weight + 6.25 * height - 5 * Double(age) - 161
//            bmr = (maleBMR + femaleBMR) / 2
//        }
//
////        let activityFactor: Double
////
////        switch metrics.activeCalories {
////        case 0..<250:
////            activityFactor = 1.25
////        case 250..<500:
////            activityFactor = 1.40
////        case 500..<800:
////            activityFactor = 1.55
////        default:
////            activityFactor = 1.70
////        }
//
//        let baseTDEE = bmr * 1.25
//
//        let activeCaloriesAdjustment: Double
//
//        switch profile.goal {
//        case .fatLoss:
//            activeCaloriesAdjustment = metrics.activeCalories * 0.5
//        case .maintenance:
//            activeCaloriesAdjustment = metrics.activeCalories * 0.8
//        case .muscleGain:
//            activeCaloriesAdjustment = metrics.activeCalories * 1.0
//        }
//
//        let tdee = baseTDEE + activeCaloriesAdjustment
//
//        let caloriesGoal: Double
//
//        switch profile.goal {
//        case .fatLoss:
//            caloriesGoal = tdee * 0.85
//        case .maintenance:
//            caloriesGoal = tdee
//        case .muscleGain:
//            caloriesGoal = tdee * 1.10
//        }
//
//        let proteinMultiplier: Double
//
//        switch profile.goal {
//        case .fatLoss:
//            proteinMultiplier = 1.8
//        case .maintenance:
//            proteinMultiplier = 1.6
//        case .muscleGain:
//            proteinMultiplier = 2.0
//        }
//
//        let proteinGoal = weight * proteinMultiplier
//
//        let fatRatio: Double
//
//        switch profile.goal {
//        case .fatLoss:
//            fatRatio = 0.30
//        case .maintenance:
//            fatRatio = 0.28
//        case .muscleGain:
//            fatRatio = 0.25
//        }
//
//        let fatsGoal = caloriesGoal * fatRatio / 9
//        let proteinCalories = proteinGoal * 4
//        let fatCalories = fatsGoal * 9
//        let remainingCalories = max(caloriesGoal - proteinCalories - fatCalories, 0)
//        let carbsGoal = remainingCalories / 4
//
//        let waterGoal = weight * 0.035 + metrics.activeCalories / 1000 * 0.7
//
//        return NutritionGoals(
//            protein: proteinGoal,
//            carbs: carbsGoal,
//            fats: fatsGoal,
//            calories: caloriesGoal,
//            waterLiters: waterGoal
//        )
//    }
//    
//    private static func applyDayProgress(to goals: NutritionGoals) -> NutritionGoals {
//        let hour = Calendar.current.component(.hour, from: Date())
//        let progress = min(max(Double(hour) / 22.0, 0.35), 1.0)
//
//        return NutritionGoals(
//            protein: goals.protein * progress,
//            carbs: goals.carbs * progress,
//            fats: goals.fats * progress,
//            calories: goals.calories * progress,
//            waterLiters: goals.waterLiters * progress
//        )
//    }
//
//    private static func goalScore(_ value: Double, _ goal: Double) -> Double {
//        guard goal > 0 else { return 0 }
//
//        let ratio = value / goal
//
//        if ratio <= 1 {
//            return ratio * 100
//        } else {
//            let penalty = (ratio - 1) * 45
//            return max(100 - penalty, 0)
//        }
//    }
//
//    private static func status(for score: Double) -> String {
//        switch score {
//        case 85...100:
//            return "Excellent"
//        case 70..<85:
//            return "Good"
//        case 50..<70:
//            return "Average"
//        default:
//            return "Low"
//        }
//    }
//
//    private static func recommendation(
//        metrics: DailyNutritionMetrics,
//        goals: NutritionGoals,
//        score: Double
//    ) -> String {
//
//        let hasFood =
//            metrics.protein > 0 ||
//            metrics.carbs > 0 ||
//            metrics.fats > 0 ||
//            metrics.calories > 0
//
//        if !hasFood {
//            return "No meals logged yet. Add your first meal to start building today’s nutrition score."
//        }
//
//        if metrics.waterLiters < goals.waterLiters * 0.45 {
//            return "Hydration is low today. Add water or a hydration habit to improve recovery."
//        }
//
//        if metrics.protein < goals.protein * 0.65 {
//            return "Protein is below target. Add a high-protein meal to support recovery."
//        }
//
//        if metrics.activeCalories > 500 && metrics.carbs < goals.carbs * 0.6 {
//            return "You had a high activity day. Add quality carbs to restore energy."
//        }
//
//        if metrics.sleepHours < 6.5 {
//            return "Sleep was short. Choose magnesium-rich foods and hydrate well today."
//        }
//
//        if score >= 80 {
//            return "Nutrition looks strong today. Keep your current rhythm."
//        }
//
//        return "Balance protein, hydration and calories to improve today’s score."
//    }
//}
