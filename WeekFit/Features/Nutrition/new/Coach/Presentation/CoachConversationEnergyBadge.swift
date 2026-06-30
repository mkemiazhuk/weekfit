import Foundation

/// Context-aware status badge labels aligned with conversational energy.
enum CoachConversationEnergyBadge {

    struct Labels: Equatable, Sendable {
        let english: String
        let russian: String

        func localized(russian: Bool) -> String {
            russian ? self.russian : english
        }
    }

    static func resolve(
        energy: CoachConversationEnergy,
        scenario: CoachScenarioKey,
        safetyAlert: CoachSafetyAlert?,
        stackedDayActiveRisk: Bool,
        stableDayProfile: CoachStableDayProfile?
    ) -> Labels {
        if safetyAlert != nil {
            return Labels(english: "IMPORTANT", russian: "ВАЖНО")
        }
        if stackedDayActiveRisk {
            return Labels(english: "ATTENTION", russian: "ВНИМАНИЕ")
        }

        switch energy {
        case .low:
            return lowLabels(scenario: scenario, stableDayProfile: stableDayProfile)
        case .medium:
            return mediumLabels(scenario: scenario)
        case .high:
            return highLabels(scenario: scenario)
        }
    }

    static func resolve(from insight: CoachTodayInsight) -> Labels {
        resolve(
            energy: insight.conversationEnergy,
            scenario: insight.scenario,
            safetyAlert: insight.safetyAlert,
            stackedDayActiveRisk: insight.modifiers.stackedDayActiveRisk,
            stableDayProfile: nil
        )
    }

    // MARK: - Private

    private static func lowLabels(
        scenario: CoachScenarioKey,
        stableDayProfile: CoachStableDayProfile?
    ) -> Labels {
        _ = stableDayProfile
        switch scenario {
        case .stableDay, .morningReadiness:
            return Labels(english: "ALL GOOD", russian: "ВСЁ ХОРОШО")
        case .walkLightDay:
            return Labels(english: "EASY DAY", russian: "СПОКОЙНЫЙ ДЕНЬ")
        default:
            return Labels(english: "RECOVERING", russian: "ВОССТАНАВЛИВАЕМСЯ")
        }
    }

    private static func mediumLabels(scenario: CoachScenarioKey) -> Labels {
        switch scenario {
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate,
             .saunaActive:
            return Labels(english: "STAY STEADY", russian: "ДЕРЖИМ РИТМ")
        default:
            return Labels(english: "SAVE ENERGY", russian: "БЕРЕЖЁМ СИЛЫ")
        }
    }

    private static func highLabels(scenario: CoachScenarioKey) -> Labels {
        switch scenario {
        case .duringEndurance, .duringRacket, .duringStrength:
            return Labels(english: "LIVE", russian: "СЕЙЧАС")
        default:
            return Labels(english: "FOCUS NOW", russian: "СЕЙЧАС ВАЖНО")
        }
    }
}
