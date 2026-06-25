import Foundation
import SwiftUI

/// Dev-facing coach integration trace for Today/Coach presentation.
struct CoachIntegrationDebug: Equatable, Sendable {
    let scenario: CoachScenarioKey
    let copyPackExists: Bool
    let usingCoach: Bool
    let fallbackReason: String?

    static func resolve(
        from result: CoachEngine.Result,
        usingCoach: Bool
    ) -> CoachIntegrationDebug {
        let copyPackExists = result.copyPack != nil
        let fallbackReason: String? = usingCoach
            ? nil
            : copyPackExists
                ? "bridgeBuildFailed"
                : "copyRegistryMissing:\(result.scenario.rawValue)"

        return CoachIntegrationDebug(
            scenario: result.scenario,
            copyPackExists: copyPackExists,
            usingCoach: usingCoach,
            fallbackReason: fallbackReason
        )
    }

    var logSummary: String {
        if usingCoach {
            return "usingCoach=yes scenario=\(scenario.rawValue) copyPack=yes"
        }
        return [
            "usingCoach=no",
            "scenario=\(scenario.rawValue)",
            "copyPack=\(copyPackExists ? "yes" : "nil")",
            "fallbackReason=\(fallbackReason ?? "unknown")"
        ].joined(separator: " ")
    }

    var devLabel: String {
        if usingCoach {
            return "Coach active · scenario: \(scenario.rawValue) · copyPack: yes"
        }
        return "Coach fallback · scenario: \(scenario.rawValue) · copyPack: \(copyPackExists ? "yes" : "nil")"
    }
}

/// Localized Coach + Today chrome derived from Coach copy — UI layer only.
struct CoachUIPresentation: Equatable, Sendable {
    let scenario: CoachScenarioKey
    let assessment: String
    let recommendation: String
    let avoid: String
    let nextAction: String
    let supportingSignals: [String]
    let warningMessage: String?
    let warningAlert: CoachSafetyAlert?
    let semanticColor: CoachSemanticColor
    let alertSeverity: CoachAlertSeverity
    let icon: String
    let urgencyLevel: CoachUrgencyLevel
    let statusLabel: String
    let coachTitle: String
    let todayTitle: String
    let todayMessage: String
    let whyRows: [CoachPresentationWhyRow]

    var accentColor: Color { semanticColor.uiColor }
}

extension CoachSemanticColor {
    var uiColor: Color {
        switch self {
        case .stable, .ready:
            return CoachPalette.stable
        case .activity, .live:
            return CoachPalette.activity
        case .recovery:
            return CoachPalette.recovery
        case .protection:
            return CoachPalette.protection
        case .heat:
            return CoachPalette.warning
        case .risk:
            return CoachPalette.stress
        }
    }
}

extension CoachAlertSeverity {
    var uiAccentColor: Color? {
        switch self {
        case .none:
            return nil
        case .elevated:
            return CoachPalette.fueling
        case .critical:
            return CoachPalette.warning
        }
    }
}
