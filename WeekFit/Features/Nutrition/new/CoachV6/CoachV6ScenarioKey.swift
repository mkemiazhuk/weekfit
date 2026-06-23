import Foundation

/// Primary story of the day — one key per coaching frame.
/// Day load, deficits, and activity subtype live in `CoachV6ScenarioModifiers`.
enum CoachV6ScenarioKey: String, CaseIterable, Hashable, Sendable {

    // MARK: Day-level (no focused activity)

    case stableDay
    case morningReadiness
    case tomorrowProtection
    case protectTomorrowFresh
    case recoveryAfterHeavyYesterday
    case lowRecoveryPrep

    // MARK: Endurance — Cycling, Running

    case activeEndurance
    case duringEndurance
    case postEnduranceImmediate
    case postEnduranceSettled
    case eveningAfterEndurance

    // MARK: Racket — Tennis, Squash

    case activeRacket
    case duringRacket
    case postRacketImmediate
    case postRacketSettled
    case eveningAfterRacket

    // MARK: Strength — Upper / Lower / Core / Full Body

    case activeStrength
    case duringStrength
    case postStrengthImmediate
    case postStrengthSettled
    case eveningAfterStrength

    // MARK: Recovery — Walk

    case walkLightDay
    case walkAfterHeavyLoad
    case walkEveningWindDown
    case walkRecoveryAction

    // MARK: Recovery — Stretching, Yoga, Breathing

    case activeRecovery
    case duringRecovery
    case postRecoveryImmediate
    case postRecoverySettled
    case eveningAfterRecovery

    // MARK: Heat — Sauna

    case saunaPreparation
    case saunaActive
    case saunaRecovery
}

// MARK: - Modifiers

/// Copy-shaping factors layered on top of the primary scenario.
struct CoachV6ScenarioModifiers: Equatable, Sendable {
    let dayLoad: CoachV6DayLoadBand
    let fuelBehind: Bool
    let hydrationBehind: Bool
    let tomorrowDemand: CoachV6TomorrowDemand
    let activityType: CoachV6ActivityType
    let durationBand: CoachV6DurationBand
    let completedSeriousActivities: CoachV6CompletedSeriousActivities
    let timeOfDay: CoachV6TimeOfDay
    /// Serious live training on a heavy day with tomorrow demand — Today goes red.
    let stackedDayActiveRisk: Bool

    static func from(context: CoachV6Context, scenario: CoachV6ScenarioKey) -> CoachV6ScenarioModifiers {
        CoachV6ScenarioModifiers(
            dayLoad: context.dayLoadBand,
            fuelBehind: context.fuelState.isBehind,
            hydrationBehind: context.hydrationState.isBehind,
            tomorrowDemand: context.tomorrowDemand,
            activityType: context.activityType,
            durationBand: context.durationBand,
            completedSeriousActivities: context.completedSeriousActivities,
            timeOfDay: context.timeOfDay,
            stackedDayActiveRisk: CoachV6StackedDayRisk.isActive(context: context, scenario: scenario)
        )
    }
}

// MARK: - Resolution

/// Scenario + modifiers. `safetyAlert` is optional overlay — it never replaces `scenario`.
/// `fuelBehind` / `hydrationBehind` live only in `modifiers` and must not change `scenario`.
struct CoachV6ScenarioResolution: Equatable, Sendable {
    let scenario: CoachV6ScenarioKey
    let modifiers: CoachV6ScenarioModifiers
    let safetyAlert: CoachV6SafetyAlert?
}

enum CoachV6SafetyAlert: String, Equatable, Sendable {
    case hydrationCritical
    case fuelCritical
}

extension CoachV6ScenarioKey {

    var activityFamily: CoachV6ActivityFamily? {
        switch self {
        case .stableDay, .morningReadiness, .tomorrowProtection,
             .protectTomorrowFresh, .recoveryAfterHeavyYesterday, .lowRecoveryPrep:
            return nil
        case .activeEndurance, .duringEndurance, .postEnduranceImmediate,
             .postEnduranceSettled, .eveningAfterEndurance:
            return .endurance
        case .activeRacket, .duringRacket, .postRacketImmediate,
             .postRacketSettled, .eveningAfterRacket:
            return .racket
        case .activeStrength, .duringStrength, .postStrengthImmediate,
             .postStrengthSettled, .eveningAfterStrength:
            return .strength
        case .walkLightDay, .walkAfterHeavyLoad, .walkEveningWindDown, .walkRecoveryAction,
             .activeRecovery, .duringRecovery, .postRecoveryImmediate,
             .postRecoverySettled, .eveningAfterRecovery:
            return .recovery
        case .saunaPreparation, .saunaActive, .saunaRecovery:
            return .heat
        }
    }

    static var totalCount: Int { allCases.count }
}
