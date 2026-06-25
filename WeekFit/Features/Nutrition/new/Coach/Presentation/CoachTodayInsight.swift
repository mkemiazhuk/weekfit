import Foundation

// MARK: - Presentation tokens (independent layers)

/// Color of the **primary story** — driven by `ScenarioKey` only, never by deficit modifiers.
enum CoachSemanticColor: String, Equatable, Sendable {
    case stable
    case ready
    case activity
    case live
    case recovery
    case protection
    case heat
    case risk
}

/// Risk signal layered **on top of** the story — independent from `semanticColor`.
enum CoachAlertSeverity: String, Equatable, Sendable {
    case none
    case elevated
    case critical
}

enum CoachUrgencyLevel: Int, Equatable, Sendable, Comparable {
    case calm = 0
    case focused = 1
    case live = 2
    case protective = 3
    case critical = 4

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Today Coach Insight

/// Presentation bundle for Today Coach Insight and teaser surfaces.
/// Copy text comes later from CopyRegistry; this is structure + chrome only.
struct CoachTodayInsight: Equatable, Sendable {
    let scenario: CoachScenarioKey
    let modifiers: CoachScenarioModifiers
    let semanticColor: CoachSemanticColor
    let alertSeverity: CoachAlertSeverity
    let safetyAlert: CoachSafetyAlert?
    let icon: String
    let urgencyLevel: CoachUrgencyLevel
}

// MARK: - Presentation resolver

enum CoachPresentationResolver {

    static func todayInsight(
        resolution: CoachScenarioResolution,
        context: CoachContext
    ) -> CoachTodayInsight {
        let stackedRisk = resolution.modifiers.stackedDayActiveRisk
        let stableDayProfile = stableDayProfile(
            scenario: resolution.scenario,
            modifiers: resolution.modifiers,
            dayReadiness: context.dayReadiness
        )
        let alertSeverity = resolveAlertSeverity(
            resolution: resolution,
            modifiers: resolution.modifiers,
            stackedDayActiveRisk: stackedRisk,
            context: context
        )
        return CoachTodayInsight(
            scenario: resolution.scenario,
            modifiers: resolution.modifiers,
            semanticColor: semanticColor(
                for: resolution.scenario,
                stableDayProfile: stableDayProfile
            ),
            alertSeverity: alertSeverity,
            safetyAlert: resolution.safetyAlert,
            icon: icon(
                for: resolution.scenario,
                activityType: presentationActivityType(
                    scenario: resolution.scenario,
                    context: context,
                    modifiers: resolution.modifiers
                ),
                stackedDayActiveRisk: stackedRisk,
                stableDayProfile: stableDayProfile,
                lastCompletedActivityType: context.lastCompletedSeriousActivityType
            ),
            urgencyLevel: urgencyLevel(
                scenario: resolution.scenario,
                safetyAlert: resolution.safetyAlert,
                alertSeverity: alertSeverity,
                stackedDayActiveRisk: stackedRisk,
                stableDayProfile: stableDayProfile
            )
        )
    }

    private static func stableDayProfile(
        scenario: CoachScenarioKey,
        modifiers: CoachScenarioModifiers,
        dayReadiness: CoachDayReadiness
    ) -> CoachStableDayProfile? {
        CoachStableDayProfile.resolve(
            scenario: scenario,
            modifiers: modifiers,
            dayReadiness: dayReadiness
        )
    }

    // MARK: Semantic color (scenario only — guard: never fuel/hydration/dayLoad)

    static func semanticColor(
        for scenario: CoachScenarioKey,
        stableDayProfile: CoachStableDayProfile? = nil
    ) -> CoachSemanticColor {
        if scenario == .stableDay, let stableDayProfile {
            return CoachStableDayPresentation.semanticColor(for: stableDayProfile)
        }
        return baseSemanticColor(for: scenario)
    }

    private static func baseSemanticColor(for scenario: CoachScenarioKey) -> CoachSemanticColor {
        switch scenario {
        case .stableDay:
            return .stable
        case .morningReadiness:
            return .ready
        case .tomorrowProtection, .protectTomorrowFresh:
            return .protection
        case .recoveryAfterHeavyYesterday:
            return .recovery
        case .lowRecoveryPrep:
            return .ready
        case .activeEndurance, .activeRacket, .activeStrength, .activeRecovery:
            return .activity
        case .duringEndurance, .duringRacket, .duringStrength, .duringRecovery:
            return .live
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate,
             .postRecoveryImmediate:
            return .activity
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled,
             .postRecoverySettled, .eveningAfterEndurance, .eveningAfterRacket,
             .eveningAfterStrength, .eveningAfterRecovery:
            return .recovery
        case .walkLightDay, .walkAfterHeavyLoad, .walkRecoveryAction:
            return .recovery
        case .walkEveningWindDown:
            return .stable
        case .saunaPreparation, .saunaActive:
            return .heat
        case .saunaRecovery:
            return .recovery
        }
    }

    // MARK: Alert severity (risk layer — independent from semanticColor)

    static func resolveAlertSeverity(
        resolution: CoachScenarioResolution,
        modifiers: CoachScenarioModifiers,
        stackedDayActiveRisk: Bool = false,
        context: CoachContext? = nil
    ) -> CoachAlertSeverity {
        if resolution.safetyAlert != nil || stackedDayActiveRisk {
            return .critical
        }
        if let context, CoachConversationNutritionPolicy.shouldSuppress(context: context) {
            return .none
        }
        if modifiers.fuelBehind || modifiers.hydrationBehind {
            return .elevated
        }
        return .none
    }

    // MARK: Urgency

    static func urgencyLevel(
        scenario: CoachScenarioKey,
        safetyAlert: CoachSafetyAlert?,
        alertSeverity: CoachAlertSeverity,
        stackedDayActiveRisk: Bool = false,
        stableDayProfile: CoachStableDayProfile? = nil
    ) -> CoachUrgencyLevel {
        if safetyAlert != nil || stackedDayActiveRisk {
            return .critical
        }
        if scenario == .stableDay, let stableDayProfile {
            return CoachStableDayPresentation.urgencyLevel(for: stableDayProfile)
        }
        return baseUrgencyLevel(for: scenario)
    }

    private static func baseUrgencyLevel(for scenario: CoachScenarioKey) -> CoachUrgencyLevel {
        switch scenario {
        case .stableDay, .morningReadiness, .walkLightDay, .walkEveningWindDown,
             .postEnduranceSettled, .postRacketSettled, .postStrengthSettled,
             .postRecoverySettled, .saunaRecovery:
            return .calm
        case .activeEndurance, .activeRacket, .activeStrength, .activeRecovery,
             .saunaPreparation, .walkAfterHeavyLoad, .walkRecoveryAction:
            return .focused
        case .duringEndurance, .duringRacket, .duringStrength, .duringRecovery,
             .saunaActive:
            return .live
        case .tomorrowProtection, .eveningAfterEndurance, .eveningAfterRacket,
             .eveningAfterStrength, .eveningAfterRecovery, .protectTomorrowFresh,
             .recoveryAfterHeavyYesterday, .lowRecoveryPrep:
            return .protective
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate,
             .postRecoveryImmediate:
            return .focused
        }
    }

    // MARK: Icon

    static func icon(
        for scenario: CoachScenarioKey,
        activityType: CoachActivityType,
        stackedDayActiveRisk: Bool = false,
        stableDayProfile: CoachStableDayProfile? = nil,
        lastCompletedActivityType: CoachActivityType = .none
    ) -> String {
        if stackedDayActiveRisk {
            return activityTypeIcon(activityType) ?? scenarioIcon(scenario)
        }
        if scenario == .stableDay, let stableDayProfile {
            return CoachStableDayPresentation.icon(
                for: stableDayProfile,
                lastCompletedActivityType: lastCompletedActivityType
            )
        }
        if let activityIcon = activityTypeIcon(activityType), isActivityBound(scenario) {
            return activityIcon
        }
        return scenarioIcon(scenario)
    }

    private static func presentationActivityType(
        scenario: CoachScenarioKey,
        context: CoachContext,
        modifiers: CoachScenarioModifiers
    ) -> CoachActivityType {
        if scenario == .stableDay,
           modifiers.completedSeriousActivities != .none,
           context.lastCompletedSeriousActivityType != .none {
            return context.lastCompletedSeriousActivityType
        }
        return context.activityType
    }

    private static func isActivityBound(_ scenario: CoachScenarioKey) -> Bool {
        scenario.activityFamily != nil
    }

    static func activityTypeIcon(_ type: CoachActivityType) -> String? {
        switch type {
        case .cycling:
            return "figure.outdoor.cycle"
        case .running:
            return "figure.run"
        case .tennis:
            return "figure.tennis"
        case .squash:
            return "figure.squash"
        case .upperBody, .lowerBody, .core, .fullBody:
            return "dumbbell.fill"
        case .walk:
            return "figure.walk"
        case .stretching:
            return "figure.cooldown"
        case .yoga:
            return "figure.yoga"
        case .breathing:
            return "wind"
        case .sauna:
            return "flame.fill"
        case .none:
            return nil
        }
    }

    private static func scenarioIcon(_ scenario: CoachScenarioKey) -> String {
        switch scenario {
        case .stableDay:
            return "checkmark.circle"
        case .morningReadiness:
            return "sunrise.fill"
        case .tomorrowProtection, .protectTomorrowFresh:
            return "moon.stars.fill"
        case .recoveryAfterHeavyYesterday:
            return "bed.double.fill"
        case .lowRecoveryPrep:
            return "heart.text.square.fill"
        default:
            return "figure.walk"
        }
    }
}
