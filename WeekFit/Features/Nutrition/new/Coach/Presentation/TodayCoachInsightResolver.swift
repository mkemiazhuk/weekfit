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
        // Prefer live Coach presentation whenever it has Today copy — even if
        // `canRenderTodayCoachInsight` is still false — so Focus matches Coach
        // instead of showing a stale “Assessing your recovery” settling card.
        if let presentation = input.coachState.coachUIPresentation,
           hasTodayCopy(presentation) {
            let isRefreshing = !input.coachState.canRenderTodayCoachInsight
                || input.coachState.status == .refreshingPrevious
                || !input.isHealthMetricsSettled
            return .insight(presentation, isRefreshing: isRefreshing)
        }

        if let cached = input.cachedPresentation, hasTodayCopy(cached) {
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

    private static func hasTodayCopy(_ presentation: CoachUIPresentation) -> Bool {
        let todayTitle = presentation.todayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !todayTitle.isEmpty { return true }
        // Fall back to Coach headline so Focus can mirror the Coach tab card.
        return !presentation.coachTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
