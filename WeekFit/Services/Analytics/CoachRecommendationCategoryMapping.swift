import Foundation

extension CoachRecommendationCategory {
    /// Maps a shipped Coach scenario (and optional safety overlay) to a bounded analytics category.
    ///
    /// Does not send scenario raw values, copy, or HealthKit quantities.
    /// Uses `general` only when no deterministic product family applies.
    static func from(
        scenario: CoachScenarioKey,
        warningAlert: CoachSafetyAlert? = nil
    ) -> CoachRecommendationCategory {
        switch warningAlert {
        case .hydrationCritical:
            return .hydration
        case .fuelCritical:
            return .nutrition
        case nil:
            break
        }

        switch scenario {
        case .morningReadiness:
            return .sleep

        case .stableDay:
            return .general

        case .tomorrowProtection, .protectTomorrowFresh,
             .recoveryAfterHeavyYesterday, .lowRecoveryPrep:
            return .recovery

        case .activeEndurance, .duringEndurance, .postEnduranceImmediate,
             .postEnduranceSettled, .eveningAfterEndurance,
             .activeRacket, .duringRacket, .postRacketImmediate,
             .postRacketSettled, .eveningAfterRacket,
             .activeStrength, .duringStrength, .postStrengthImmediate,
             .postStrengthSettled, .eveningAfterStrength:
            return .activity

        case .walkLightDay, .walkAfterHeavyLoad, .walkEveningWindDown, .walkRecoveryAction,
             .activeRecovery, .duringRecovery, .postRecoveryImmediate,
             .postRecoverySettled, .eveningAfterRecovery,
             .saunaPreparation, .saunaActive, .saunaRecovery:
            return .recovery
        }
    }
}
