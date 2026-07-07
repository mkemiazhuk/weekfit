import Foundation

/// Editorial layer for Coach reflection utterances at conversational pause.
enum ReflectionComposer {

    struct Input {
        let snapshot: CoachInputSnapshot
        let context: CoachContext
        let urgencyLevel: CoachUrgencyLevel
        let safetyAlert: CoachSafetyAlert?
        let alertSeverity: CoachAlertSeverity
    }

    /// Returns a reflection offer only when pause is active and understanding changed.
    static func compose(_ input: Input) -> ReflectionOffer? {
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

        guard let event = CoachUnderstandingStore.nextUnspokenEvent() else {
            log(pause: pause, offer: nil)
            return nil
        }

        let offer = ReflectionOffer(
            id: event.id,
            kind: ReflectionCopy.reflectionKind(for: event),
            message: ReflectionCopy.message(for: event),
            beliefID: event.beliefID.rawValue,
            pauseReason: pause.reason
        )

        log(pause: pause, offer: offer)
        return offer
    }

    private static func log(pause: ConversationPauseResolution, offer: ReflectionOffer?) {
        CoachLogger.trace(
            "[CoachReflection]",
            [
                "pause=\(pause.isPaused)",
                "pauseReason=\(pause.reason)",
                "blockedBy=\(pause.blockedBy?.rawValue ?? "none")",
                "offer=\(offer?.id ?? "nil")"
            ].joined(separator: " ")
        )
    }
}
