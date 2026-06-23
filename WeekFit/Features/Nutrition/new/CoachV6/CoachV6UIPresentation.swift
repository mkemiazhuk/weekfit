import Foundation
import SwiftUI

/// Dev-facing V6 integration trace — why Today/Coach use V6 or fall back to V5.
struct CoachV6IntegrationDebug: Equatable, Sendable {
    let scenario: CoachV6ScenarioKey
    let copyPackExists: Bool
    let usingV6: Bool
    let fallbackReason: String?

    static func resolve(
        from result: CoachV6Engine.Result,
        usingV6: Bool
    ) -> CoachV6IntegrationDebug {
        let copyPackExists = result.copyPack != nil
        let fallbackReason: String? = usingV6
            ? nil
            : copyPackExists
                ? "bridgeBuildFailed"
                : "copyRegistryMissing:\(result.scenario.rawValue)"

        return CoachV6IntegrationDebug(
            scenario: result.scenario,
            copyPackExists: copyPackExists,
            usingV6: usingV6,
            fallbackReason: fallbackReason
        )
    }

    var logSummary: String {
        if usingV6 {
            return "usingV6=yes scenario=\(scenario.rawValue) copyPack=yes"
        }
        return [
            "usingV6=no",
            "scenario=\(scenario.rawValue)",
            "copyPack=\(copyPackExists ? "yes" : "nil")",
            "fallbackReason=\(fallbackReason ?? "unknown")"
        ].joined(separator: " ")
    }

    var devLabel: String {
        if usingV6 {
            return "CoachV6 active · scenario: \(scenario.rawValue) · copyPack: yes"
        }
        return "CoachV6 fallback · scenario: \(scenario.rawValue) · copyPack: \(copyPackExists ? "yes" : "nil")"
    }
}

/// Localized Coach + Today chrome derived from CoachV6 copy — UI layer only.
struct CoachV6UIPresentation: Equatable, Sendable {
    let scenario: CoachV6ScenarioKey
    let assessment: String
    let recommendation: String
    let avoid: String
    let nextAction: String
    let supportingSignals: [String]
    let warningMessage: String?
    let warningAlert: CoachV6SafetyAlert?
    let semanticColor: CoachV6SemanticColor
    let alertSeverity: CoachV6AlertSeverity
    let icon: String
    let urgencyLevel: CoachV6UrgencyLevel
    let statusLabel: String
    let coachTitle: String
    let todayTitle: String
    let todayMessage: String
}

extension CoachV6SemanticColor {
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

extension CoachV6AlertSeverity {
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
