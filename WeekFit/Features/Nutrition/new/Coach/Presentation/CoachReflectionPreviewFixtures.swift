import Foundation

struct CoachReflectionPreviewGuidance: Equatable, Sendable {
    let title: String
    let assessment: String
    let recommendation: String
    let nextAction: String
}

enum CoachReflectionPreviewFixtures {
    static let emergingOffer = ReflectionOffer(
        id: "preview.emerged",
        kind: .newDiscovery,
        message: "I've started noticing something about your sleep. When your bedtime stays consistent, your recovery tends to be stronger the next day.",
        beliefID: CoachBeliefID.sleepConsistencyRecovery.rawValue,
        pauseReason: "settledPostNoWorkRemaining"
    )

    static let eveningOffer = ReflectionOffer(
        id: "preview.evening",
        kind: .newDiscovery,
        message: "I've started noticing something about your sleep. When your bedtime stays consistent, your recovery tends to be stronger the next day.",
        beliefID: CoachBeliefID.sleepConsistencyRecovery.rawValue,
        pauseReason: "eveningNoWorkRemaining"
    )

    static let longRussianOffer = ReflectionOffer(
        id: "preview.ru",
        kind: .confirmation,
        message: "Теперь я увереннее в этом. За последние недели видно, что когда вы ложитесь примерно в одно и то же время, восстановление на следующий день остаётся заметно выше, даже если нагрузка в тот же день была высокой.",
        beliefID: CoachBeliefID.sleepConsistencyRecovery.rawValue,
        pauseReason: "settledPostNoWorkRemaining"
    )

    static let eveningGuidance = CoachReflectionPreviewGuidance(
        title: "Recovering now",
        assessment: "Today's work is done.",
        recommendation: "Let the evening stay calm and protect sleep.",
        nextAction: "Hydrate and start winding down."
    )

    static let defaultGuidance = CoachReflectionPreviewGuidance(
        title: "Recovering now",
        assessment: "The main load is behind you.",
        recommendation: "Keep the rest of the day calm.",
        nextAction: "Water and an easy meal."
    )
}
