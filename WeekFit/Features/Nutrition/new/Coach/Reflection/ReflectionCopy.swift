import Foundation

enum ReflectionCopy {

    static func message(for event: UnderstandingEvent) -> String {
        switch (event.beliefID, event.change, event.maturity) {
        case (.sleepConsistencyRecovery, .emerged, .emerging):
            return CoachState.localized(
                english: "I've started noticing something about your sleep. When your bedtime stays consistent, your recovery tends to be stronger the next day.",
                russian: "Я начинаю замечать кое-что про ваш сон. Когда время отхода ко сну остаётся стабильным, восстановление на следующий день обычно выше."
            )
        case (.sleepConsistencyRecovery, .emerged, .established), (.sleepConsistencyRecovery, .strengthened, .established):
            return CoachState.localized(
                english: "I'm more confident about this now. Your recovery is consistently stronger when your sleep timing stays steady.",
                russian: "Теперь я увереннее в этом. Ваше восстановление стабильно выше, когда режим сна остаётся ровным."
            )
        default:
            return CoachState.localized(
                english: "I've learned something new about how your body responds over time.",
                russian: "Я узнал кое-что новое о том, как ваше тело реагирует со временем."
            )
        }
    }

    static func reflectionKind(for event: UnderstandingEvent) -> ReflectionKind {
        switch event.change {
        case .emerged:
            return .newDiscovery
        case .strengthened:
            return .confirmation
        }
    }
}
