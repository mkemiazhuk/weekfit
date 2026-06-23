import Foundation

// MARK: - Presentation tokens (independent layers)

/// Color of the **primary story** — driven by `ScenarioKey` only, never by deficit modifiers.
enum CoachV6SemanticColor: String, Equatable, Sendable {
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
enum CoachV6AlertSeverity: String, Equatable, Sendable {
    case none
    case elevated
    case critical
}

enum CoachV6UrgencyLevel: Int, Equatable, Sendable, Comparable {
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
struct CoachV6TodayInsight: Equatable, Sendable {
    let scenario: CoachV6ScenarioKey
    let modifiers: CoachV6ScenarioModifiers
    let semanticColor: CoachV6SemanticColor
    let alertSeverity: CoachV6AlertSeverity
    let safetyAlert: CoachV6SafetyAlert?
    let icon: String
    let urgencyLevel: CoachV6UrgencyLevel
}

// MARK: - Presentation resolver

enum CoachV6PresentationResolver {

    static func todayInsight(
        resolution: CoachV6ScenarioResolution,
        context: CoachV6Context
    ) -> CoachV6TodayInsight {
        let stackedRisk = resolution.modifiers.stackedDayActiveRisk
        let alertSeverity = resolveAlertSeverity(
            resolution: resolution,
            modifiers: resolution.modifiers,
            stackedDayActiveRisk: stackedRisk
        )
        return CoachV6TodayInsight(
            scenario: resolution.scenario,
            modifiers: resolution.modifiers,
            semanticColor: stackedRisk
                ? .risk
                : semanticColor(for: resolution.scenario),
            alertSeverity: alertSeverity,
            safetyAlert: resolution.safetyAlert,
            icon: icon(
                for: resolution.scenario,
                activityType: context.activityType,
                stackedDayActiveRisk: stackedRisk
            ),
            urgencyLevel: urgencyLevel(
                scenario: resolution.scenario,
                safetyAlert: resolution.safetyAlert,
                alertSeverity: alertSeverity,
                stackedDayActiveRisk: stackedRisk
            )
        )
    }

    // MARK: Semantic color (scenario only — guard: never fuel/hydration/dayLoad)

    static func semanticColor(for scenario: CoachV6ScenarioKey) -> CoachV6SemanticColor {
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
        resolution: CoachV6ScenarioResolution,
        modifiers: CoachV6ScenarioModifiers,
        stackedDayActiveRisk: Bool = false
    ) -> CoachV6AlertSeverity {
        if resolution.safetyAlert != nil || stackedDayActiveRisk {
            return .critical
        }
        if modifiers.fuelBehind || modifiers.hydrationBehind {
            return .elevated
        }
        return .none
    }

    // MARK: Urgency

    static func urgencyLevel(
        scenario: CoachV6ScenarioKey,
        safetyAlert: CoachV6SafetyAlert?,
        alertSeverity: CoachV6AlertSeverity,
        stackedDayActiveRisk: Bool = false
    ) -> CoachV6UrgencyLevel {
        if safetyAlert != nil || stackedDayActiveRisk {
            return .critical
        }
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
        for scenario: CoachV6ScenarioKey,
        activityType: CoachV6ActivityType,
        stackedDayActiveRisk: Bool = false
    ) -> String {
        if stackedDayActiveRisk {
            return "exclamationmark.triangle.fill"
        }
        if let activityIcon = activityTypeIcon(activityType), isActivityBound(scenario) {
            return activityIcon
        }
        return scenarioIcon(scenario)
    }

    private static func isActivityBound(_ scenario: CoachV6ScenarioKey) -> Bool {
        scenario.activityFamily != nil
    }

    private static func activityTypeIcon(_ type: CoachV6ActivityType) -> String? {
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
            return "figure.flexibility"
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

    private static func scenarioIcon(_ scenario: CoachV6ScenarioKey) -> String {
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
