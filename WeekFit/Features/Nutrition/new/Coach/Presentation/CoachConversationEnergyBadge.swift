import Foundation

/// Context-aware status badge labels aligned with conversational energy.
enum CoachConversationEnergyBadge {

    struct Labels: Equatable, Sendable {
        let english: String
        let russian: String
        let chinese: String

        init(english: String, russian: String, chinese: String? = nil) {
            self.english = english
            self.russian = russian
            self.chinese = chinese ?? english
        }

        func localized(russian: Bool) -> String {
            // Legacy parameter kept for call sites; prefer explicit app language.
            if russian { return self.russian }
            return CoachBilingualText(english: english, russian: self.russian, chinese: chinese).resolved()
        }

        func resolved() -> String {
            CoachBilingualText(english: english, russian: russian, chinese: chinese).resolved()
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
            return Labels(english: "IMPORTANT", russian: "ВАЖНО", chinese: "重要")
        }
        if stackedDayActiveRisk {
            return Labels(english: "ATTENTION", russian: "ВНИМАНИЕ", chinese: "注意")
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
            return Labels(english: "ALL GOOD", russian: "ВСЁ ХОРОШО", chinese: "状态不错")
        case .walkLightDay:
            return Labels(english: "EASY DAY", russian: "СПОКОЙНЫЙ ДЕНЬ", chinese: "轻松日")
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength,
             .eveningAfterRecovery, .recoveryAfterHeavyYesterday:
            return saveEnergy
        default:
            return Labels(english: "RECOVERING", russian: "ВОССТАНАВЛИВАЕМСЯ", chinese: "恢复中")
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
            return Labels(english: "LIVE", russian: "СЕЙЧАС", chinese: "进行中")
        default:
            return focusNow
        }
    }

    private static let focusNow = Labels(english: "FOCUS NOW", russian: "СЕЙЧАС ВАЖНО", chinese: "现在专注")
    private static let saveEnergy = Labels(english: "SAVE ENERGY", russian: "БЕРЕЖЁМ СИЛЫ", chinese: "节省体力")
}
