import Foundation

/// Computes conversational frame for Coach — morning overview and evening wind-down.
enum CoachConversationPhaseResolver {

    private static let bedtimeHour = 20
    private static let bedtimeMinute = 30

    static func resolve(
        input: CoachInputSnapshot,
        context: CoachContext,
        isFirstOpenToday: Bool? = nil
    ) -> CoachConversationPhaseResolution {
        _ = isFirstOpenToday

        if let ownerReason = liveSessionOwnerReason(context) {
            return CoachConversationPhaseResolution(phase: .steady, reason: ownerReason)
        }

        if isDayClosingCandidate(input: input, context: context) {
            return CoachConversationPhaseResolution(phase: .dayClosing, reason: "bedtimeWindowNoMeaningfulWorkLeft")
        }

        if CoachMorningOverviewPolicy.isActive(input: input, context: context) {
            return morningOverviewResolution(input: input, context: context)
        }

        return .steady
    }

    // MARK: - Live session owners (always steady)

    /// Only live / protection owners override morning overview — upcoming prep stays in overview.
    private static func liveSessionOwnerReason(_ context: CoachContext) -> String? {
        if context.focusSource == .active {
            return "activeWorkoutOwner"
        }
        if context.sessionPhase == .during || context.activityState == .active {
            return "duringWorkoutOwner"
        }
        if context.sessionPhase == .immediatePost {
            return "immediatePostOwner"
        }
        if context.sessionPhase == .tomorrowProtection {
            return "tomorrowProtectionOwner"
        }
        return nil
    }

    private static func morningOverviewResolution(
        input: CoachInputSnapshot,
        context: CoachContext
    ) -> CoachConversationPhaseResolution {
        if context.focusSource == .upcoming, context.activityType != .none {
            return CoachConversationPhaseResolution(
                phase: .morningOverview,
                reason: "morningWindowUpcomingActivity"
            )
        }
        if context.sessionPhase == .idle, context.focusSource == .idle {
            return CoachConversationPhaseResolution(
                phase: .morningOverview,
                reason: "morningWindowIdleDay"
            )
        }
        return CoachConversationPhaseResolution(
            phase: .morningOverview,
            reason: "morningWindowActive"
        )
    }

    // MARK: - Day closing

    private static func isDayClosingCandidate(
        input: CoachInputSnapshot,
        context: CoachContext
    ) -> Bool {
        guard isBedtimeWindow(now: input.now, timeOfDay: context.timeOfDay) else {
            return false
        }
        guard isClosingEligibleSessionPhase(context.sessionPhase) else {
            return false
        }
        guard !CoachUpcomingActivityPolicy.hasMeaningfulActivityLaterToday(input) else {
            return false
        }
        return true
    }

    private static func isBedtimeWindow(now: Date, timeOfDay: CoachTimeOfDay) -> Bool {
        if timeOfDay == .lateEvening || timeOfDay == .night {
            return true
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        return hour > bedtimeHour || (hour == bedtimeHour && minute >= bedtimeMinute)
    }

    private static func isClosingEligibleSessionPhase(_ phase: CoachSessionPhase) -> Bool {
        switch phase {
        case .idle, .settledPost, .evening:
            return true
        case .pre, .during, .immediatePost, .tomorrowProtection:
            return false
        }
    }
}
