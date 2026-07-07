import Foundation

/// Primary story of the day — one key per coaching frame.
/// Day load, deficits, and activity subtype live in `CoachScenarioModifiers`.
enum CoachScenarioKey: String, CaseIterable, Hashable, Sendable {

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
struct CoachScenarioModifiers: Equatable, Sendable {
    let dayLoad: CoachDayLoadBand
    let fuelBehind: Bool
    let hydrationBehind: Bool
    let tomorrowDemand: CoachTomorrowDemand
    let activityType: CoachActivityType
    let durationBand: CoachDurationBand
    let completedSeriousActivities: CoachCompletedSeriousActivities
    let timeOfDay: CoachTimeOfDay
    /// Serious live training on a heavy day with tomorrow demand — Today goes red.
    let stackedDayActiveRisk: Bool
    /// Latest completed serious activity today — idle post-training `stableDay` copy.
    let lastCompletedActivityType: CoachActivityType
    /// Completed walk logged today — avoids duplicate evening walk prompts.
    let completedWalkToday: Bool

    init(
        dayLoad: CoachDayLoadBand,
        fuelBehind: Bool,
        hydrationBehind: Bool,
        tomorrowDemand: CoachTomorrowDemand,
        activityType: CoachActivityType,
        durationBand: CoachDurationBand,
        completedSeriousActivities: CoachCompletedSeriousActivities,
        timeOfDay: CoachTimeOfDay,
        stackedDayActiveRisk: Bool,
        lastCompletedActivityType: CoachActivityType,
        completedWalkToday: Bool = false
    ) {
        self.dayLoad = dayLoad
        self.fuelBehind = fuelBehind
        self.hydrationBehind = hydrationBehind
        self.tomorrowDemand = tomorrowDemand
        self.activityType = activityType
        self.durationBand = durationBand
        self.completedSeriousActivities = completedSeriousActivities
        self.timeOfDay = timeOfDay
        self.stackedDayActiveRisk = stackedDayActiveRisk
        self.lastCompletedActivityType = lastCompletedActivityType
        self.completedWalkToday = completedWalkToday
    }

    static func from(context: CoachContext, scenario: CoachScenarioKey) -> CoachScenarioModifiers {
        let suppressNutrition = CoachConversationNutritionPolicy.shouldSuppress(context: context)
        return CoachScenarioModifiers(
            dayLoad: context.dayLoadBand,
            fuelBehind: suppressNutrition ? false : context.fuelState.isBehind,
            hydrationBehind: suppressNutrition ? false : context.hydrationState.isBehind,
            tomorrowDemand: context.tomorrowDemand,
            activityType: context.activityType,
            durationBand: context.durationBand,
            completedSeriousActivities: context.completedSeriousActivities,
            timeOfDay: context.timeOfDay,
            stackedDayActiveRisk: CoachStackedDayRisk.isActive(context: context, scenario: scenario),
            lastCompletedActivityType: context.lastCompletedSeriousActivityType,
            completedWalkToday: context.completedWalkToday
        )
    }
}

// MARK: - Resolution

/// Scenario + modifiers. `safetyAlert` is optional overlay — it never replaces `scenario`.
/// `fuelBehind` / `hydrationBehind` live only in `modifiers` and must not change `scenario`.
struct CoachScenarioResolution: Equatable, Sendable {
    let scenario: CoachScenarioKey
    let modifiers: CoachScenarioModifiers
    let safetyAlert: CoachSafetyAlert?
}

enum CoachSafetyAlert: String, Equatable, Sendable {
    case hydrationCritical
    case fuelCritical
}

extension CoachScenarioKey {

    var activityFamily: CoachActivityFamily? {
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
