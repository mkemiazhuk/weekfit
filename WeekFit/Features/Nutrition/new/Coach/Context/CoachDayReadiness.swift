import Foundation

// MARK: - Day readiness (recovery + yesterday load)

enum CoachRecoveryBand: String, Equatable, Sendable {
    case good
    case moderate
    case low
}

struct CoachDayReadiness: Equatable, Sendable {
    let recoveryPercent: Int
    let sleepHours: Double
    let recoveryBand: CoachRecoveryBand
    let hadHeavyYesterday: Bool
    let sleepIsLow: Bool

    static let unknown = CoachDayReadiness(
        recoveryPercent: 70,
        sleepHours: 7.5,
        recoveryBand: .moderate,
        hadHeavyYesterday: false,
        sleepIsLow: false
    )

    var isLowRecovery: Bool { recoveryBand == .low }

    var isGoodRecovery: Bool { recoveryBand == .good }
}

enum CoachDayReadinessResolver {

    private static let goodRecoveryThreshold = 70
    private static let lowRecoveryThreshold = 55
    private static let lowSleepHours = 6.0

    static func resolve(from input: CoachInputSnapshot) -> CoachDayReadiness {
        let recovery = input.recoveryContext
        let recoveryBand = recoveryBand(for: recovery.recoveryPercent)
        let hadHeavyYesterday = input.brain.past.hasHighActivityLoad
            || input.brain.past.completedWorkoutsCount >= 2

        return CoachDayReadiness(
            recoveryPercent: recovery.recoveryPercent,
            sleepHours: recovery.sleepHours,
            recoveryBand: recoveryBand,
            hadHeavyYesterday: hadHeavyYesterday,
            sleepIsLow: recovery.sleepHours < lowSleepHours
        )
    }

    private static func recoveryBand(for percent: Int) -> CoachRecoveryBand {
        if percent >= goodRecoveryThreshold { return .good }
        if percent >= lowRecoveryThreshold { return .moderate }
        return .low
    }
}

enum CoachDayReadinessRouter {

    // MARK: - Idle day stories

    static func idleScenario(for context: CoachContext) -> CoachScenarioKey {
        if shouldUseRecoveryAfterHeavyYesterday(context) {
            return .recoveryAfterHeavyYesterday
        }
        if shouldUseProtectTomorrowFresh(context) {
            return .protectTomorrowFresh
        }
        if context.timeOfDay == .morning,
           context.dayLoadBand == .fresh,
           context.completedSeriousActivities == .none {
            return .morningReadiness
        }
        return .stableDay
    }

    static func shouldUseProtectTomorrowFresh(_ context: CoachContext) -> Bool {
        guard context.sessionPhase == .idle else { return false }
        guard context.activityFamily == .none else { return false }
        guard context.dayReadiness.isGoodRecovery else { return false }
        guard context.dayLoadBand != .heavy && context.dayLoadBand != .extreme else { return false }
        guard context.completedSeriousActivities == .none else { return false }
        guard context.tomorrowDemand == .moderate || context.tomorrowDemand == .hard else { return false }
        switch context.timeOfDay {
        case .morning, .midday:
            return true
        default:
            return false
        }
    }

    static func shouldUseRecoveryAfterHeavyYesterday(_ context: CoachContext) -> Bool {
        guard context.sessionPhase == .idle else { return false }
        guard context.activityFamily == .none else { return false }
        guard context.dayReadiness.hadHeavyYesterday else { return false }
        guard context.dayLoadBand == .fresh else { return false }
        return context.dayReadiness.isLowRecovery || context.dayReadiness.sleepIsLow
    }

    // MARK: - Pre-session protective prep

    static func shouldUseLowRecoveryPrep(_ context: CoachContext) -> Bool {
        guard context.sessionPhase == .pre else { return false }
        guard context.activityState == .upcoming else { return false }
        switch context.activityFamily {
        case .endurance, .strength, .racket:
            break
        default:
            return false
        }
        let readiness = context.dayReadiness
        return readiness.isLowRecovery
            || readiness.sleepIsLow
            || (readiness.recoveryBand == .moderate && readiness.sleepHours < 5.5)
    }

    static func lowRecoveryPreSessionScenario(for context: CoachContext) -> CoachScenarioKey? {
        shouldUseLowRecoveryPrep(context) ? .lowRecoveryPrep : nil
    }
}
