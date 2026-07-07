import Foundation

// MARK: - 🧬 METABOLIC AND LOGIC ENGINES

final class MetabolicRateCalculator {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    func calculateBMR(weight: Double, height: Double, age: Int, sex: BiologicalSex) -> Double {
        let safeWeight = max(weight, 40.0)
        let safeHeight = max(height, 120.0)
        let safeAge = max(Double(age), 12.0)
        
        switch sex {
        case .male:   return 10.0 * safeWeight + 6.25 * safeHeight - 5.0 * safeAge + 5.0
        case .female: return 10.0 * safeWeight + 6.25 * safeHeight - 5.0 * safeAge - 161.0
        case .unknown:
            let maleBMR = 10.0 * safeWeight + 6.25 * safeHeight - 5.0 * safeAge + 5.0
            let femaleBMR = 10.0 * safeWeight + 6.25 * safeHeight - 5.0 * safeAge - 161.0
            return (maleBMR + femaleBMR) / 2.0
        }
    }
    
    func calculateBaseTDEE(bmr: Double) -> Double { bmr }
}

final class DynamicMacroAdjuster {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    private enum CalorieTargetPolicy {
        static let fatLossMultiplier = 0.85
        /// Prevents unrealistically low targets while still leaving a visible gap vs maintenance.
        static let fatLossMinimumBMRRatio = 0.90
        static let muscleGainMultiplier = 1.10
    }

    func adjustGoals(bmr: Double, activeCalories: Double, weight: Double, goal: NutritionGoal) -> NutritionGoals {
        let safeWeight = max(weight, 40.0)
        let activeFactor: Double
        
        switch goal {
        case .fatLoss:      activeFactor = 0.5
        case .maintenance:  activeFactor = 0.8
        case .muscleGain:   activeFactor = 1.0
        }
        
        let dynamicTDEE = bmr + (activeCalories * activeFactor)
        let targetCalories: Double
        
        switch goal {
        case .fatLoss:
            let deficitTarget = dynamicTDEE * CalorieTargetPolicy.fatLossMultiplier
            let safetyFloor = bmr * CalorieTargetPolicy.fatLossMinimumBMRRatio
            targetCalories = max(deficitTarget, safetyFloor)
        case .maintenance:  targetCalories = dynamicTDEE
        case .muscleGain:   targetCalories = dynamicTDEE * CalorieTargetPolicy.muscleGainMultiplier
        }
        
        let proteinMultiplier: Double
        let fatRatio: Double
        
        switch goal {
        case .fatLoss:
            proteinMultiplier = 1.8
            fatRatio = 0.30
        case .maintenance:
            proteinMultiplier = 1.6
            fatRatio = 0.28
        case .muscleGain:
            proteinMultiplier = 2.0
            fatRatio = 0.25
        }
        
        let proteinGoal = safeWeight * proteinMultiplier
        let fatsGoal = (targetCalories * fatRatio) / 9.0
        
        let proteinCalories = proteinGoal * 4.0
        let fatCalories = fatsGoal * 9.0
        let remainingCalories = max(targetCalories - proteinCalories - fatCalories, 0.0)
        let carbsGoal = remainingCalories / 4.0
        
        let fiberGoal = min(max((targetCalories / 1000.0) * 14.0, 25.0), 45.0)
        let waterGoal = safeWeight * 0.035 + (activeCalories / 1000.0) * 0.7
        
        return NutritionGoals(
            calories: targetCalories,
            protein: proteinGoal,
            carbs: carbsGoal,
            fats: fatsGoal,
            fiber: fiberGoal,
            waterLiters: waterGoal
        )
    }
}

final class TimeAdaptiveScoringEngine {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    func applyTimeSmoothing(
        to goals: NutritionGoals,
        currentHour: Int = Calendar.current.component(.hour, from: Date())
    ) -> NutritionGoals {
        let factor: Double
        
        switch currentHour {
        case 0..<10:  factor = 0.45
        case 10..<16: factor = 0.70
        default:      factor = 1.00
        }
        
        return NutritionGoals(
            calories: goals.calories * factor,
            protein: goals.protein * factor,
            carbs: goals.carbs * factor,
            fats: goals.fats * factor,
            fiber: goals.fiber * factor,
            waterLiters: goals.waterLiters * factor
        )
    }
    
    func calculateFinalScore(metrics: DailyNutritionMetrics, smoothedGoals: NutritionGoals) -> Double {
        let rawScore =
            evaluateComponent(metrics.protein, target: smoothedGoals.protein) * 0.30 +
            evaluateComponent(metrics.waterLiters, target: smoothedGoals.waterLiters) * 0.20 +
            evaluateComponent(metrics.calories, target: smoothedGoals.calories) * 0.20 +
            evaluateComponent(metrics.carbs, target: smoothedGoals.carbs) * 0.15 +
            evaluateComponent(metrics.fats, target: smoothedGoals.fats) * 0.10 +
            evaluateComponent(metrics.fiber, target: smoothedGoals.fiber) * 0.05
        
        return min(max(rawScore, 0.0), 100.0)
    }
    
    private func evaluateComponent(_ value: Double, target: Double) -> Double {
        guard target > 0.0 else { return 0.0 }
        let ratio = value / target
        
        if ratio <= 1.05 {
            return min(ratio * 100.0, 100.0)
        }
        
        return max(100.0 - (ratio - 1.05) * 450.0, 0.0)
    }
}
