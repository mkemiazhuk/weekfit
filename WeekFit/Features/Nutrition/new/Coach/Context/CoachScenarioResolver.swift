import Foundation

enum CoachScenarioResolver {

    // MARK: Guard rules (enforced by resolver + unit tests)
    //
    // 1. `primaryScenario` reads sessionPhase, activityFamily, activityType, activityState,
    //    timeOfDay, dayLoadBand (walk routing), completedSeriousActivities (walk only),
    //    and `dayReadiness` for idle + pre-session day stories only.
    // 2. `fuelState` / `hydrationState` MUST NOT influence `primaryScenario`.
    // 3. `dayLoadBand` MUST NOT appear in ScenarioKey — only in modifiers.dayLoad.
    // 4. `safetyAlert` is computed after scenario; never feeds back into scenario selection.

    static func resolve(_ context: CoachContext) -> CoachScenarioResolution {
        let scenario = primaryScenario(for: context)
        let modifiers = CoachScenarioModifiers.from(context: context, scenario: scenario)
        let safetyAlert = safetyAlert(for: context, scenario: scenario)
        return CoachScenarioResolution(
            scenario: scenario,
            modifiers: modifiers,
            safetyAlert: safetyAlert
        )
    }

    /// Same story frame with fuel/hydration stripped — used by guard tests.
    static func primaryScenarioIgnoringNutrition(_ context: CoachContext) -> CoachScenarioKey {
        let neutral = CoachContext(
            activityFamily: context.activityFamily,
            activityType: context.activityType,
            activityState: context.activityState,
            sessionPhase: context.sessionPhase,
            durationBand: context.durationBand,
            dayLoadBand: context.dayLoadBand,
            completedSeriousActivities: context.completedSeriousActivities,
            fuelState: .adequate,
            hydrationState: .adequate,
            tomorrowDemand: context.tomorrowDemand,
            timeOfDay: context.timeOfDay,
            tomorrowWorkout: context.tomorrowWorkout,
            focusActivityID: context.focusActivityID,
            focusSource: context.focusSource,
            minutesUntilStart: context.minutesUntilStart,
            minutesSinceEnd: context.minutesSinceEnd,
            dayReadiness: context.dayReadiness,
            lastCompletedSeriousActivityType: context.lastCompletedSeriousActivityType
        )
        return primaryScenario(for: neutral)
    }

    // MARK: - Primary scenario

    private static func primaryScenario(for context: CoachContext) -> CoachScenarioKey {
        if context.sessionPhase == .tomorrowProtection {
            return .tomorrowProtection
        }

        if context.sessionPhase == .idle {
            return idleScenario(for: context)
        }

        switch context.activityFamily {
        case .endurance:
            return enduranceScenario(for: context)
        case .racket:
            return racketScenario(for: context)
        case .strength:
            return strengthScenario(for: context)
        case .recovery:
            return recoveryScenario(for: context)
        case .heat:
            return heatScenario(for: context)
        case .none:
            return idleScenario(for: context)
        }
    }

    // MARK: - Safety alert (does not replace primary scenario)

    private static func safetyAlert(
        for context: CoachContext,
        scenario: CoachScenarioKey
    ) -> CoachSafetyAlert? {
        guard context.sessionPhase == .during else { return nil }

        switch scenario {
        case .duringEndurance:
            if context.hydrationState == .critical {
                return .hydrationCritical
            }
            if context.fuelState == .critical {
                return .fuelCritical
            }
        case .duringRacket, .saunaActive:
            if context.hydrationState == .critical {
                return .hydrationCritical
            }
        default:
            break
        }
        return nil
    }

    // MARK: - Idle

    private static func idleScenario(for context: CoachContext) -> CoachScenarioKey {
        CoachDayReadinessRouter.idleScenario(for: context)
    }

    // MARK: - Endurance

    private static func enduranceScenario(for context: CoachContext) -> CoachScenarioKey {
        switch context.sessionPhase {
        case .pre:
            return CoachDayReadinessRouter.lowRecoveryPreSessionScenario(for: context)
                ?? .activeEndurance
        case .during:
            return .duringEndurance
        case .immediatePost:
            return .postEnduranceImmediate
        case .settledPost:
            return .postEnduranceSettled
        case .evening:
            return .eveningAfterEndurance
        case .tomorrowProtection, .idle:
            return idleScenario(for: context)
        }
    }

    // MARK: - Racket

    private static func racketScenario(for context: CoachContext) -> CoachScenarioKey {
        switch context.sessionPhase {
        case .pre:
            return CoachDayReadinessRouter.lowRecoveryPreSessionScenario(for: context)
                ?? .activeRacket
        case .during:
            return .duringRacket
        case .immediatePost:
            return .postRacketImmediate
        case .settledPost:
            return .postRacketSettled
        case .evening:
            return .eveningAfterRacket
        case .tomorrowProtection, .idle:
            return idleScenario(for: context)
        }
    }

    // MARK: - Strength

    private static func strengthScenario(for context: CoachContext) -> CoachScenarioKey {
        switch context.sessionPhase {
        case .pre:
            return CoachDayReadinessRouter.lowRecoveryPreSessionScenario(for: context)
                ?? .activeStrength
        case .during:
            return .duringStrength
        case .immediatePost:
            return .postStrengthImmediate
        case .settledPost:
            return .postStrengthSettled
        case .evening:
            return .eveningAfterStrength
        case .tomorrowProtection, .idle:
            return idleScenario(for: context)
        }
    }

    // MARK: - Recovery

    private static func recoveryScenario(for context: CoachContext) -> CoachScenarioKey {
        if context.activityType == .walk {
            return walkScenario(for: context)
        }
        return mindfulRecoveryScenario(for: context)
    }

    private static func walkScenario(for context: CoachContext) -> CoachScenarioKey {
        if isWalkEveningWindDown(context) {
            return .walkEveningWindDown
        }
        if isWalkRecoveryAction(context) {
            return .walkRecoveryAction
        }
        if isHeavyDay(context.dayLoadBand) {
            return .walkAfterHeavyLoad
        }
        return .walkLightDay
    }

    private static func isWalkEveningWindDown(_ context: CoachContext) -> Bool {
        switch context.activityState {
        case .upcoming, .active:
            break
        case .justFinished, .none, .finished:
            return false
        }

        guard context.timeOfDay == .evening || context.timeOfDay == .lateEvening else {
            return context.sessionPhase == .evening
        }

        return true
    }

    private static func isWalkRecoveryAction(_ context: CoachContext) -> Bool {
        guard context.completedSeriousActivities != .none else { return false }
        switch context.sessionPhase {
        case .pre, .during, .immediatePost:
            return true
        case .settledPost, .evening, .tomorrowProtection, .idle:
            return false
        }
    }

    private static func mindfulRecoveryScenario(for context: CoachContext) -> CoachScenarioKey {
        switch context.sessionPhase {
        case .pre:
            return .activeRecovery
        case .during:
            return .duringRecovery
        case .immediatePost:
            return .postRecoveryImmediate
        case .settledPost:
            return .postRecoverySettled
        case .evening:
            return .eveningAfterRecovery
        case .tomorrowProtection, .idle:
            return idleScenario(for: context)
        }
    }

    // MARK: - Heat

    private static func heatScenario(for context: CoachContext) -> CoachScenarioKey {
        switch context.sessionPhase {
        case .pre:
            return .saunaPreparation
        case .during:
            return .saunaActive
        case .immediatePost, .settledPost, .evening:
            if isWithinHeatRecoveryWindow(context) {
                return .saunaRecovery
            }
            return idleScenario(for: context)
        case .tomorrowProtection, .idle:
            return idleScenario(for: context)
        }
    }

    private static func isWithinHeatRecoveryWindow(_ context: CoachContext) -> Bool {
        CoachActivityWindowPolicy.isWithinHeatRecoveryWindow(
            minutesSinceEnd: context.minutesSinceEnd,
            sessionPhase: context.sessionPhase
        )
    }

    // MARK: - Helpers

    private static func isHeavyDay(_ band: CoachDayLoadBand) -> Bool {
        band == .moderate || band == .heavy || band == .extreme
    }
}
