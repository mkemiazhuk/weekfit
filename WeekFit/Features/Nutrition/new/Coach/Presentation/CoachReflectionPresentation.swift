import Foundation

/// Presentation-only copy for Coach reflection — does not affect eligibility or beliefs.
enum CoachReflectionPresentation {

    struct Content: Equatable, Sendable {
        let leadIn: String
        let message: String
    }

    static func content(for offer: ReflectionOffer) -> Content {
        Content(
            leadIn: leadIn(for: offer.kind, pauseReason: offer.pauseReason),
            message: offer.message
        )
    }

    static func leadIn(for kind: ReflectionKind, pauseReason: String) -> String {
        switch kind {
        case .newDiscovery:
            if pauseReason.contains("evening") {
                return CoachState.localized(
                    english: "Before we finish…",
                    russian: "Перед тем как закончить…"
                )
            }
            return CoachState.localized(
                english: "One thing I've been noticing…",
                russian: "Есть кое-что, что я замечаю…"
            )
        case .confirmation:
            return CoachState.localized(
                english: "Looking back over the last few weeks…",
                russian: "Если оглянуться на последние недели…"
            )
        case .revision:
            return CoachState.localized(
                english: "Something in my understanding has shifted…",
                russian: "Кое-что в моём понимании изменилось…"
            )
        case .retired:
            return CoachState.localized(
                english: "Before we finish…",
                russian: "Перед тем как закончить…"
            )
        case .uncertainty:
            return CoachState.localized(
                english: "I'm still trying to understand this…",
                russian: "Я всё ещё пытаюсь это понять…"
            )
        }
    }
}
