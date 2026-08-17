import Foundation

/// Editorial gate for Discovery Tell moments at conversational pause.
enum CoachDiscoveryComposer {

    struct Input {
        let snapshot: CoachInputSnapshot
        let context: CoachContext
        let urgencyLevel: CoachUrgencyLevel
        let safetyAlert: CoachSafetyAlert?
        let alertSeverity: CoachAlertSeverity
    }

    /// Returns a discovery offer only when pause is active and an offer is pending.
    static func compose(_ input: Input) -> CoachDiscoveryOffer? {
        let pause = ConversationPauseResolver.resolve(
            ConversationPauseResolver.Input(
                snapshot: input.snapshot,
                context: input.context,
                urgencyLevel: input.urgencyLevel,
                safetyAlert: input.safetyAlert,
                alertSeverity: input.alertSeverity
            )
        )

        guard pause.isPaused else {
            log(pause: pause, offer: nil)
            return nil
        }

        guard let offer = CoachDiscoveryStore.nextOffer() else {
            log(pause: pause, offer: nil)
            return nil
        }

        log(pause: pause, offer: offer)
        return offer
    }

    private static func log(pause: ConversationPauseResolution, offer: CoachDiscoveryOffer?) {
        CoachLogger.trace(
            "[CoachDiscovery]",
            [
                "pause=\(pause.isPaused)",
                "pauseReason=\(pause.reason)",
                "blockedBy=\(pause.blockedBy?.rawValue ?? "none")",
                "offer=\(offer?.id ?? "nil")"
            ].joined(separator: " ")
        )
    }
}
