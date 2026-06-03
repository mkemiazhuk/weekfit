import Foundation

enum ActivityGoalEngine {

    static func calculate(
        weightKg: Double,
        heightCm: Double,
        age: Int,
        sex: BiologicalSex,
        recoveryPercent: Int,
        sleepHours: Double,
        vo2Max: Double
    ) -> Double {

        let weight = max(weightKg, 40.0)
        let height = max(heightCm, 120.0)
        let safeAge = max(Double(age), 12.0)

        let sexBonus: Double = {
            switch sex {
            case .male:
                return 5.0
            case .female:
                return -161.0
            case .unknown:
                return -78.0
            }
        }()

        let bmr = 10.0 * weight + 6.25 * height - 5.0 * safeAge + sexBonus

        var factor: Double = 0.32

        if recoveryPercent >= 85 {
            factor += 0.05
        } else if recoveryPercent >= 70 {
            factor += 0.02
        } else if recoveryPercent < 50 {
            factor -= 0.06
        } else if recoveryPercent < 60 {
            factor -= 0.04
        }

        if sleepHours > 0 {
            if sleepHours < 5.5 {
                factor -= 0.06
            } else if sleepHours < 6.5 {
                factor -= 0.03
            } else if sleepHours >= 7.5 {
                factor += 0.02
            }
        }

        if vo2Max >= 48 {
            factor += 0.04
        } else if vo2Max >= 42 {
            factor += 0.025
        } else if vo2Max > 0 && vo2Max < 32 {
            factor -= 0.03
        }

        let minGoal = bmr * 0.22
        let maxGoal = bmr * 0.52

        let rawGoal = bmr * factor
        let clampedGoal = min(max(rawGoal, minGoal), maxGoal)

        return (clampedGoal / 10.0).rounded() * 10.0
    }
}
