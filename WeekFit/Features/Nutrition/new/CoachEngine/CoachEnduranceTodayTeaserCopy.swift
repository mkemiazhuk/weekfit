import Foundation

/// Tactical Today lines for endurance arc chapters — same family as Coach, shorter voice.
enum CoachEnduranceTodayTeaserCopy {

    static func teaser(
        story: CoachFinalStory,
        input: CoachInputSnapshot,
        scenario: CoachPresentationScenario
    ) -> (idea: String, action: String)? {
        if let deficit = deficitTeaser(story: story, input: input) {
            return deficit
        }

        guard let context = CoachEnduranceNarrativeContextResolver.resolve(story: story, input: input) else {
            return nil
        }

        switch scenario {
        case .activeWorkout:
            guard context.phase == .during else { return nil }
            return chapterTeaser(for: context.chapter)
        case .postWorkoutRecovery:
            guard context.phase == .postRecoveryWindow, context.chapter == .recoveryWindow else { return nil }
            return chapterTeaser(for: .recoveryWindow)
        default:
            return nil
        }
    }

    static func deficitTeaser(
        story: CoachFinalStory,
        input: CoachInputSnapshot
    ) -> (idea: String, action: String)? {
        guard CoachEnduranceNarrativeContextResolver.isActiveEnduranceSession(story: story, input: input) else {
            return nil
        }

        switch story.owner {
        case .fuelingDuringActivity:
            return (
                localized(english: "Refuel now", russian: "Подкрепитесь сейчас"),
                localized(english: "A short snack will bring the rhythm back.", russian: "Короткий перекус вернёт темп.")
            )
        case .hydrationExecution:
            return (
                localized(english: "Time to top up fluids", russian: "Пора пополнить воду"),
                localized(english: "Sip steadily — not all at once.", russian: "Пейте понемногу, не залпом.")
            )
        default:
            return nil
        }
    }

    static func chapterTeaser(for chapter: CoachEnduranceSessionChapter) -> (idea: String, action: String) {
        switch chapter {
        case .opening:
            return (
                localized(english: "Start easy", russian: "Сначала легко"),
                localized(english: "Add effort once breathing settles.", russian: "Добавляйте усилие, когда дыхание успокоится.")
            )
        case .establish:
            return (
                localized(english: "Don't skip the next fuel stop", russian: "Не пропускайте следующий приём"),
                localized(english: "Keep the next snack on schedule.", russian: "Следующий перекус держите по графику.")
            )
        case .maintain:
            return (
                localized(english: "Stick to the plan", russian: "Продолжайте по плану"),
                localized(english: "Steady pace — no surges.", russian: "Темп ровный — без рывков.")
            )
        case .protect:
            return (
                localized(english: "Don't add effort now", russian: "Не добавляйте усилие сейчас"),
                localized(english: "Hold the finish calmly.", russian: "Дожмите до финиша спокойно.")
            )
        case .recoveryWindow:
            return (
                localized(english: "Recovery leads now", russian: "Сейчас важнее восстановление"),
                localized(english: "Protein and carbs in the next hour.", russian: "Белок и углеводы в ближайший час.")
            )
        }
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}
