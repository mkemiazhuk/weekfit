import Foundation

/// Conversational frame for idle/low-urgency moments — morning overview and evening wind-down.
enum CoachConversationPhase: String, Equatable, Sendable, CaseIterable {
    case steady
    /// First phase after waking — body, sleep, recovery, nearest event only.
    case morningOverview
    case dayClosing

    static let defaultReason = "steadyDefault"
}

struct CoachConversationPhaseResolution: Equatable, Sendable {
    let phase: CoachConversationPhase
    let reason: String

    static let steady = CoachConversationPhaseResolution(
        phase: .steady,
        reason: CoachConversationPhase.defaultReason
    )
}

extension CoachContext {

    func withConversationPhase(_ resolution: CoachConversationPhaseResolution) -> CoachContext {
        CoachContext(
            activityFamily: activityFamily,
            activityType: activityType,
            activityState: activityState,
            sessionPhase: sessionPhase,
            durationBand: durationBand,
            dayLoadBand: dayLoadBand,
            completedSeriousActivities: completedSeriousActivities,
            fuelState: fuelState,
            hydrationState: hydrationState,
            tomorrowDemand: tomorrowDemand,
            timeOfDay: timeOfDay,
            tomorrowWorkout: tomorrowWorkout,
            focusActivityID: focusActivityID,
            focusSource: focusSource,
            minutesUntilStart: minutesUntilStart,
            minutesSinceEnd: minutesSinceEnd,
            dayReadiness: dayReadiness,
            lastCompletedSeriousActivityType: lastCompletedSeriousActivityType,
            completedWalkToday: completedWalkToday,
            conversationPhase: resolution.phase,
            conversationPhaseReason: resolution.reason
        )
    }
}
