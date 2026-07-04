import Foundation

/// Presentation-only conversational energy — how urgent Coach chrome should feel.
enum CoachConversationEnergy: String, Equatable, Sendable, CaseIterable {
    case low
    case medium
    case high
}

/// Derives conversational energy from activity family and scenario — no routing changes.
enum CoachConversationEnergyPolicy {

    struct Input: Equatable, Sendable {
        let scenario: CoachScenarioKey
        let safetyAlert: CoachSafetyAlert?
        let alertSeverity: CoachAlertSeverity
        let stackedDayActiveRisk: Bool
        let stableDayProfile: CoachStableDayProfile?

        static func from(
            resolution: CoachScenarioResolution,
            alertSeverity: CoachAlertSeverity,
            stableDayProfile: CoachStableDayProfile?
        ) -> Input {
            Input(
                scenario: resolution.scenario,
                safetyAlert: resolution.safetyAlert,
                alertSeverity: alertSeverity,
                stackedDayActiveRisk: resolution.modifiers.stackedDayActiveRisk,
                stableDayProfile: stableDayProfile
            )
        }

        static func from(result: CoachEngine.Result) -> Input {
            let profile = CoachStableDayProfile.resolve(
                scenario: result.scenario,
                modifiers: result.modifiers,
                dayReadiness: result.context.dayReadiness
            )
            return from(
                resolution: result.resolution,
                alertSeverity: result.todayInsight.alertSeverity,
                stableDayProfile: profile
            )
        }

        static func from(input: CoachCopyBuildInput) -> Input {
            let profile = CoachStableDayProfile.resolve(
                scenario: input.scenario,
                modifiers: input.modifiers,
                dayReadiness: input.dayReadiness
            )
            return Input(
                scenario: input.scenario,
                safetyAlert: input.safetyAlert,
                alertSeverity: input.alertSeverity,
                stackedDayActiveRisk: input.modifiers.stackedDayActiveRisk,
                stableDayProfile: profile
            )
        }
    }

    static func resolve(_ input: Input) -> CoachConversationEnergy {
        if input.safetyAlert != nil || input.stackedDayActiveRisk {
            return .high
        }
        if input.alertSeverity == .critical {
            return .high
        }

        switch input.scenario {
        case .stableDay:
            if let profile = input.stableDayProfile, profile.isProtective {
                return .medium
            }
            return .low

        case .morningReadiness, .recoveryAfterHeavyYesterday:
            return .low

        case .tomorrowProtection, .protectTomorrowFresh, .lowRecoveryPrep:
            return .medium

        case .activeEndurance, .activeRacket, .activeStrength,
             .duringEndurance, .duringRacket, .duringStrength:
            return .high

        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate:
            return .medium

        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled,
             .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength:
            return .low

        case .walkLightDay, .walkEveningWindDown, .walkAfterHeavyLoad, .walkRecoveryAction,
             .activeRecovery, .duringRecovery, .postRecoveryImmediate, .postRecoverySettled,
             .eveningAfterRecovery:
            return .low

        case .saunaPreparation, .saunaRecovery:
            return .low

        case .saunaActive:
            return .high
        }
    }

    static func resolve(result: CoachEngine.Result) -> CoachConversationEnergy {
        resolve(Input.from(result: result))
    }

    static func resolve(input: CoachCopyBuildInput) -> CoachConversationEnergy {
        resolve(Input.from(input: input))
    }

    // MARK: - Chrome mapping

    static func urgencyLevel(
        energy: CoachConversationEnergy,
        scenario: CoachScenarioKey,
        safetyAlert: CoachSafetyAlert?,
        stackedDayActiveRisk: Bool
    ) -> CoachUrgencyLevel {
        if safetyAlert != nil || stackedDayActiveRisk {
            return .critical
        }
        switch energy {
        case .low:
            return .calm
        case .medium:
            return .protective
        case .high:
            if isDuring(scenario) {
                return .live
            }
            return .focused
        }
    }

    static func adjustedSemanticColor(
        base: CoachSemanticColor,
        energy: CoachConversationEnergy,
        scenario: CoachScenarioKey
    ) -> CoachSemanticColor {
        switch energy {
        case .low, .medium:
            if base == .live {
                return .recovery
            }
            if base == .activity, isRecoveryFamily(scenario) {
                return .recovery
            }
            return base
        case .high:
            return base
        }
    }

    // MARK: - Private

    private static func isDuring(_ scenario: CoachScenarioKey) -> Bool {
        switch scenario {
        case .duringEndurance, .duringRacket, .duringStrength, .duringRecovery, .saunaActive:
            return true
        default:
            return false
        }
    }

    private static func isRecoveryFamily(_ scenario: CoachScenarioKey) -> Bool {
        scenario.activityFamily == .recovery
    }
}
