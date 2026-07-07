import Foundation

enum TodayAtmosphereMode: String, Equatable, Sendable {
    case ready
    case protect
    case load
}

enum TodayTimePhase: String, Equatable, Sendable {
    case morning
    case day
    case evening
    case night
}

struct TodayAtmosphereSnapshot: Equatable, Sendable {
    let mode: TodayAtmosphereMode
    let timePhase: TodayTimePhase
}

enum TodayAtmosphereResolver {

    static func resolve(
        recoveryPercent: Int,
        hasRecoverySignals: Bool,
        sleepHours: Double,
        activeCalories: Double,
        activityGoal: Double,
        completedTrainingCount: Int,
        hour: Int
    ) -> TodayAtmosphereSnapshot {
        let timePhase = timePhase(for: hour)
        let mode = atmosphereMode(
            recoveryPercent: recoveryPercent,
            hasRecoverySignals: hasRecoverySignals,
            sleepHours: sleepHours,
            activeCalories: activeCalories,
            activityGoal: activityGoal,
            completedTrainingCount: completedTrainingCount
        )

        return TodayAtmosphereSnapshot(mode: mode, timePhase: timePhase)
    }

    static func timePhase(for hour: Int) -> TodayTimePhase {
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .day
        case 17..<22: return .evening
        default: return .night
        }
    }

    private static func atmosphereMode(
        recoveryPercent: Int,
        hasRecoverySignals: Bool,
        sleepHours: Double,
        activeCalories: Double,
        activityGoal: Double,
        completedTrainingCount: Int
    ) -> TodayAtmosphereMode {
        if shouldProtect(
            recoveryPercent: recoveryPercent,
            hasRecoverySignals: hasRecoverySignals,
            sleepHours: sleepHours
        ) {
            return .protect
        }

        if shouldShowLoad(
            activeCalories: activeCalories,
            activityGoal: activityGoal,
            completedTrainingCount: completedTrainingCount
        ) {
            return .load
        }

        return .ready
    }

    private static func shouldProtect(
        recoveryPercent: Int,
        hasRecoverySignals: Bool,
        sleepHours: Double
    ) -> Bool {
        if hasRecoverySignals, recoveryPercent > 0, recoveryPercent < 55 {
            return true
        }

        if sleepHours > 0, sleepHours < 5.5 {
            return true
        }

        return false
    }

    private static func shouldShowLoad(
        activeCalories: Double,
        activityGoal: Double,
        completedTrainingCount: Int
    ) -> Bool {
        if activeCalories >= 650 {
            return true
        }

        if completedTrainingCount >= 2 {
            return true
        }

        if activityGoal > 0, activeCalories / activityGoal >= 0.85 {
            return true
        }

        return false
    }
}
