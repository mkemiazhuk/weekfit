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

    struct PresentationContext: Equatable, Sendable {
        let sessionPhase: CoachSessionPhase
        let focusSource: CoachFocusSource
        let activityState: CoachActivityState
        let completedSeriousActivities: CoachCompletedSeriousActivities
        let dayLoad: CoachDayLoadBand
    }

    static func resolve(
        energy: CoachConversationEnergy,
        scenario: CoachScenarioKey,
        safetyAlert: CoachSafetyAlert?,
        stackedDayActiveRisk: Bool,
        stableDayProfile: CoachStableDayProfile?,
        presentationContext: PresentationContext? = nil
    ) -> Labels {
        if safetyAlert != nil {
            return Labels(english: "IMPORTANT", russian: "ВАЖНО")
        }
        if stackedDayActiveRisk {
            return Labels(english: "ATTENTION", russian: "ВНИМАНИЕ")
        }

        if let presentationContext,
           let contextual = contextualLabels(
               energy: energy,
               scenario: scenario,
               context: presentationContext
           ) {
            return contextual
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

    private static func contextualLabels(
        energy: CoachConversationEnergy,
        scenario: CoachScenarioKey,
        context: PresentationContext
    ) -> Labels? {
        if scenario == .walkRecoveryAction,
           context.sessionPhase == .pre,
           context.focusSource == .upcoming {
            return focusNow
        }

        if scenario == .saunaPreparation,
           context.sessionPhase == .pre,
           context.focusSource == .upcoming,
           context.completedSeriousActivities != .none
               || context.dayLoad == .heavy
               || context.dayLoad == .extreme {
            return focusNow
        }

        return nil
    }

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
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength,
             .eveningAfterRecovery, .recoveryAfterHeavyYesterday:
            return saveEnergy
        default:
            return Labels(english: "RECOVERING", russian: "ВОССТАНАВЛИВАЕМСЯ")
        }
    }

    private static func mediumLabels(scenario: CoachScenarioKey) -> Labels {
        switch scenario {
        case .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate:
            return focusNow
        default:
            return saveEnergy
        }
    }

    private static func highLabels(scenario: CoachScenarioKey) -> Labels {
        switch scenario {
        case .duringEndurance, .duringRacket, .duringStrength, .saunaActive:
            return Labels(english: "LIVE", russian: "СЕЙЧАС")
        default:
            return focusNow
        }
    }

    private static let focusNow = Labels(english: "FOCUS NOW", russian: "СЕЙЧАС ВАЖНО")
    private static let saveEnergy = Labels(english: "SAVE ENERGY", russian: "БЕРЕЖЁМ СИЛЫ")
}
