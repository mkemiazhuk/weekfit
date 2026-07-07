import Foundation

struct AmbientBackgroundSnapshot: Equatable, Sendable {
    let style: AmbientBackgroundStyle
    let intensity: CGFloat
}

enum AmbientBackgroundResolver {

    struct Input: Equatable, Sendable {
        let hour: Int
        let recoveryPercent: Int
        let hasRecoverySignals: Bool
        let sleepHours: Double
        let activeCalories: Double
        let activityGoal: Double
        let completedTrainingCount: Int
        let caloriesConsumed: Double
        let caloriesGoal: Double
        let ambientOpacityScale: CGFloat

        init(
            hour: Int,
            recoveryPercent: Int,
            hasRecoverySignals: Bool,
            sleepHours: Double,
            activeCalories: Double,
            activityGoal: Double,
            completedTrainingCount: Int,
            caloriesConsumed: Double,
            caloriesGoal: Double,
            ambientOpacityScale: CGFloat = 1
        ) {
            self.hour = hour
            self.recoveryPercent = recoveryPercent
            self.hasRecoverySignals = hasRecoverySignals
            self.sleepHours = sleepHours
            self.activeCalories = activeCalories
            self.activityGoal = activityGoal
            self.completedTrainingCount = completedTrainingCount
            self.caloriesConsumed = caloriesConsumed
            self.caloriesGoal = caloriesGoal
            self.ambientOpacityScale = ambientOpacityScale
        }
    }

    static func resolve(_ input: Input) -> AmbientBackgroundSnapshot {
        let style = semanticStyle(for: input) ?? timeStyle(for: input.hour)
        let intensity = clamp(
            style.baseIntensity * input.ambientOpacityScale,
            min: 0.022,
            max: 0.055
        )
        return AmbientBackgroundSnapshot(style: style, intensity: intensity)
    }

    private static func semanticStyle(for input: Input) -> AmbientBackgroundStyle? {
        if shouldRestProtect(input) {
            return .restProtection
        }

        if shouldNutritionWarning(input) {
            return .nutrition
        }

        if shouldActivityAccent(input) {
            return .activity
        }

        if shouldRecoveryAccent(input) {
            return .recovery
        }

        return nil
    }

    private static func timeStyle(for hour: Int) -> AmbientBackgroundStyle {
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .day
        case 17..<22: return .evening
        default: return .night
        }
    }

    private static func shouldRestProtect(_ input: Input) -> Bool {
        if input.hasRecoverySignals, input.recoveryPercent > 0, input.recoveryPercent < 55 {
            return true
        }
        if input.sleepHours > 0, input.sleepHours < 5.5 {
            return true
        }
        return false
    }

    private static func shouldNutritionWarning(_ input: Input) -> Bool {
        guard input.caloriesGoal > 0 else { return false }
        let progress = input.caloriesConsumed / input.caloriesGoal
        let remainingRatio = max(0, input.caloriesGoal - input.caloriesConsumed) / input.caloriesGoal

        if progress >= 1.05 {
            return true
        }

        if input.hour >= 14, remainingRatio <= 0.22, input.caloriesConsumed > 0 {
            return true
        }

        return false
    }

    private static func shouldActivityAccent(_ input: Input) -> Bool {
        if input.activeCalories >= 650 {
            return true
        }
        if input.completedTrainingCount >= 2 {
            return true
        }
        if input.activityGoal > 0, input.activeCalories / input.activityGoal >= 0.85 {
            return true
        }
        return false
    }

    private static func shouldRecoveryAccent(_ input: Input) -> Bool {
        input.hasRecoverySignals && input.recoveryPercent >= 72
    }

    private static func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}
