import Foundation

/// General application macro and calorie progression strategies
enum NutritionGoal: String, Codable {
    case fatLoss      // Calorie deficit management
    case maintenance  // Homeostasis preservation
    case muscleGain   // Controlled hyper-caloric surplus tracking
}

/// Biological gender parameters required for Mifflin-St Jeor metabolic tracking
enum BiologicalSex: String, Codable {
    case male
    case female
    case unknown
}

final class UserNutritionProfile {
    let weightKg: Double
    let heightCm: Double
    let age: Int
    let sex: BiologicalSex
    let goal: NutritionGoal
    
    init(weightKg: Double, heightCm: Double, age: Int, sex: BiologicalSex, goal: NutritionGoal) {
        self.weightKg = max(weightKg, 40.0) // Defensive safeguard configuration against corrupted sensor weights
        self.heightCm = max(heightCm, 120.0)
        self.age = max(age, 12)
        self.sex = sex
        self.goal = goal
    }
    
    /// Automatic initialization engine that dynamically calculates the optimal fitness trajectory using World Health Organization BMI categories
    static func createAutomatic(weightKg: Double, heightCm: Double, age: Int, sex: BiologicalSex) -> UserNutritionProfile {
        let safeWeight = max(weightKg, 40.0)
        let safeHeightMeters = max(heightCm, 120.0) / 100.0 // Map centimeters to meters for BMI equations
        
        // Body Mass Index Calculation formula: BMI = weight / (height * height)
        let bmi = safeWeight / (safeHeightMeters * safeHeightMeters)
        
        let determinedGoal: NutritionGoal
        
        // Algorithmic goal attribution according to standard clinical BMI baselines
        if bmi >= 25.0 {
            determinedGoal = .fatLoss     // Overweight profile -> Apply safe fat loss deficit targets
        } else if bmi < 18.5 {
            determinedGoal = .muscleGain   // Underweight profile -> Apply lean tissue surplus targets
        } else {
            determinedGoal = .maintenance  // Healthy profile -> Retain stable metabolic homeostasis bounds
        }
        
        return UserNutritionProfile(
            weightKg: safeWeight,
            heightCm: heightCm,
            age: age,
            sex: sex,
            goal: determinedGoal
        )
    }
}
