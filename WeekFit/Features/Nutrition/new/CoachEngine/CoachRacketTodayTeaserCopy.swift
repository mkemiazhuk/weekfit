import Foundation

/// Tactical Today lines for racket arc chapters — same family as Coach, shorter voice.
enum CoachRacketTodayTeaserCopy {

    static func teaser(
        story: CoachFinalStory,
        input: CoachInputSnapshot,
        scenario: CoachPresentationScenario
    ) -> (idea: String, action: String)? {
        if let deficit = deficitTeaser(story: story, input: input) {
            return deficit
        }

        guard let context = CoachRacketNarrativeContextResolver.resolve(story: story, input: input) else {
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
        guard CoachRacketNarrativeContextResolver.isActiveRacketSession(story: story, input: input) else {
            return nil
        }

        switch story.owner {
        case .fuelingDuringActivity:
            return (
                localized(english: "Refuel now", russian: "Подкрепитесь сейчас"),
                localized(english: "A short snack keeps the legs responding.", russian: "Короткий перекус помогает ногам отвечать.")
            )
        case .hydrationExecution:
            return (
                localized(english: "Time to top up fluids", russian: "Пора пополнить воду"),
                localized(english: "Sip between games — not all at once.", russian: "Пейте между геймами — не залпом.")
            )
        default:
            return nil
        }
    }

    static func chapterTeaser(for chapter: CoachRacketSessionChapter) -> (idea: String, action: String) {
        switch chapter {
        case .warmIn:
            return (
                localized(english: "Warm in first", russian: "Сначала разомнитесь"),
                localized(english: "Add pace when footwork feels settled.", russian: "Добавляйте темп, когда ноги стабильны.")
            )
        case .findRhythm:
            return (
                localized(english: "Hold rally rhythm", russian: "Держите ритм розыгрыша"),
                localized(english: "Timing and length before speed.", russian: "Тайминг и длина — перед скоростью.")
            )
        case .manageLoad:
            return (
                localized(english: "Choose your sprints", russian: "Выбирайте рывки"),
                localized(english: "Not every rally needs full chase.", russian: "Не каждый розыгрыш требует полного преследования.")
            )
        case .closeSmart:
            return (
                localized(english: "Close without overspending", russian: "Закройте без перегиба"),
                localized(english: "No extra sprints for pride.", russian: "Без лишних рывков ради азарта.")
            )
        case .recoveryWindow:
            return (
                localized(english: "Recovery leads now", russian: "Сейчас важнее восстановление"),
                localized(english: "Fluids and calm legs in the next hour.", russian: "Вода и спокойные ноги в ближайший час.")
            )
        }
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}
