import Foundation

/// General application macro and calorie progression strategies
enum NutritionGoal: String, Codable, CaseIterable, Identifiable {
    case fatLoss      // Calorie deficit management
    case maintenance  // Homeostasis preservation
    case muscleGain   // Controlled hyper-caloric surplus tracking

    var id: String { rawValue }
}

/// Biological gender parameters required for Mifflin-St Jeor metabolic tracking
enum BiologicalSex: String, Codable {
    case male
    case female
    case unknown
}

struct UserNutritionProfile: Equatable, Hashable {
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

    /// Weight and height from HealthKit are required to infer a BMI-based goal.
    static func hasSufficientHealthDataForAutoGoal(weightKg: Double, heightCm: Double) -> Bool {
        weightKg > 0 && heightCm > 0
    }

    static func suggestedGoal(weightKg: Double, heightCm: Double) -> NutritionGoal {
        let safeWeight = max(weightKg, 40.0)
        let safeHeightMeters = max(heightCm, 120.0) / 100.0
        let bmi = safeWeight / (safeHeightMeters * safeHeightMeters)

        if bmi >= 25.0 {
            return .fatLoss
        }
        if bmi < 18.5 {
            return .muscleGain
        }
        return .maintenance
    }

    static func resolve(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex,
        manualGoal: NutritionGoal?,
        isManualGoal: Bool
    ) -> UserNutritionProfile {
        let goal = resolveGoal(
            weightKg: weightKg,
            heightCm: heightCm,
            manualGoal: manualGoal,
            isManualGoal: isManualGoal
        )

        return UserNutritionProfile(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            sex: sex,
            goal: goal
        )
    }

    static func resolveGoal(
        weightKg: Double,
        heightCm: Double,
        manualGoal: NutritionGoal?,
        isManualGoal: Bool
    ) -> NutritionGoal {
        if isManualGoal, let manualGoal {
            return manualGoal
        }

        return manualGoal ?? .maintenance
    }

    static func needsManualBodyGoalSelection(
        weightKg: Double,
        heightCm: Double,
        manualGoal: NutritionGoal?,
        isManualGoal: Bool
    ) -> Bool {
        !hasSufficientHealthDataForAutoGoal(weightKg: weightKg, heightCm: heightCm) && !isManualGoal
    }

    /// Automatic initialization engine that dynamically calculates the optimal fitness trajectory using World Health Organization BMI categories
    static func createAutomatic(weightKg: Double, heightCm: Double, age: Int, sex: BiologicalSex) -> UserNutritionProfile {
        resolve(
            weightKg: weightKg,
            heightCm: heightCm,
            age: age,
            sex: sex,
            manualGoal: nil,
            isManualGoal: false
        )
    }
}

enum NutritionGoalDisplay {
    static func title(for goal: NutritionGoal) -> String {
        switch goal {
        case .fatLoss:
            return WeekFitLocalizedString("settings.profile.bodyGoal.option.lose")
        case .maintenance:
            return WeekFitLocalizedString("settings.profile.bodyGoal.option.maintain")
        case .muscleGain:
            return WeekFitLocalizedString("settings.profile.bodyGoal.option.gain")
        }
    }

    static func subtitle(for goal: NutritionGoal) -> String {
        switch goal {
        case .fatLoss:
            return WeekFitLocalizedString("settings.profile.bodyGoal.option.lose.subtitle")
        case .maintenance:
            return WeekFitLocalizedString("settings.profile.bodyGoal.option.maintain.subtitle")
        case .muscleGain:
            return WeekFitLocalizedString("settings.profile.bodyGoal.option.gain.subtitle")
        }
    }
}
