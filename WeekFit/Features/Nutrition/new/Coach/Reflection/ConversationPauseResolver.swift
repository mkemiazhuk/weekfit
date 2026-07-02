import Foundation

/// Determines whether today's operational Coach conversation has naturally completed.
/// Read-only presentation gate — never routes scenarios or changes Guidance.
enum ConversationPauseResolver {

    struct Input: Sendable {
        let snapshot: CoachInputSnapshot
        let context: CoachContext
        let urgencyLevel: CoachUrgencyLevel
        let safetyAlert: CoachSafetyAlert?
        let alertSeverity: CoachAlertSeverity
    }

    static func resolve(_ input: Input) -> ConversationPauseResolution {
        if let blocker = guidanceOwnerBlocker(input) {
            return ConversationPauseResolution(
                isPaused: false,
                reason: "blockedBy\(blocker.rawValue)",
                blockedBy: blocker
            )
        }

        return ConversationPauseResolution(
            isPaused: true,
            reason: pauseReason(for: input.context),
            blockedBy: nil
        )
    }

    // MARK: - Blockers

    private static func guidanceOwnerBlocker(_ input: Input) -> ConversationPauseBlocker? {
        if input.safetyAlert != nil {
            return .safetyAlert
        }

        if input.alertSeverity != .none {
            return .safetyAlert
        }

        if input.urgencyLevel >= .protective {
            return .elevatedUrgency
        }

        if input.context.focusSource == .active {
            return .activeWorkout
        }

        if input.context.sessionPhase == .during || input.context.activityState == .active {
            return .duringWorkout
        }

        if input.context.sessionPhase == .immediatePost {
            return .immediatePostRecovery
        }

        if input.context.sessionPhase == .pre {
            return .imminentPreparation
        }

        if input.context.sessionPhase == .tomorrowProtection {
            return .tomorrowProtection
        }

        if CoachUpcomingActivityPolicy.hasMeaningfulActivityLaterToday(input.snapshot) {
            return .meaningfulWorkRemaining
        }

        return nil
    }

    private static func pauseReason(for context: CoachContext) -> String {
        switch context.sessionPhase {
        case .settledPost:
            return "settledPostNoWorkRemaining"
        case .evening:
            return "eveningNoWorkRemaining"
        case .idle:
            return "idleNoWorkRemaining"
        case .pre, .during, .immediatePost, .tomorrowProtection:
            return "unexpectedSessionPhase"
        }
    }
}
