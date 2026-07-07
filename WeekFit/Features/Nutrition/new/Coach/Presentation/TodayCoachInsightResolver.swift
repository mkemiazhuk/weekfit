import Foundation

enum TodayCoachInsightPhase: Equatable {
    case insight(CoachUIPresentation, isRefreshing: Bool)
    case awaitingHealthConnect
    case awaitingMorningSync
    case preparing
}

enum TodayCoachInsightResolver {

    struct Input {
        let coachState: CoachState
        let cachedPresentation: CoachUIPresentation?
        let shouldShowHealthConnectPrompt: Bool
        let hasRecoverySignals: Bool
        let isHealthMetricsSettled: Bool
    }

    static func resolve(_ input: Input) -> TodayCoachInsightPhase {
        if let presentation = input.coachState.coachUIPresentation,
           input.coachState.canRenderTodayCoachInsight {
            let isRefreshing = input.coachState.status == .refreshingPrevious
                || !input.isHealthMetricsSettled
            return .insight(presentation, isRefreshing: isRefreshing)
        }

        if let cached = input.cachedPresentation {
            return .insight(cached, isRefreshing: true)
        }

        if input.shouldShowHealthConnectPrompt {
            return .awaitingHealthConnect
        }

        if !input.hasRecoverySignals {
            return .awaitingMorningSync
        }

        return .preparing
    }
}
