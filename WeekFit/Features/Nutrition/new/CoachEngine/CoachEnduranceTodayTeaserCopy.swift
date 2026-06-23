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

        let shouldProtectTomorrow = input.dayPriorityModel.tomorrowDemand == .hard
        let coachingJob = CoachDayLoadNarrativeResolver.resolveFromSnapshot(
            input: input,
            shouldProtectTomorrow: shouldProtectTomorrow
        ).coachingJob

        switch scenario {
        case .activeWorkout:
            guard context.phase == .during else { return nil }
            return chapterTeaser(for: context.chapter, coachingJob: coachingJob)
        case .postWorkoutRecovery:
            guard context.phase == .postRecoveryWindow, context.chapter == .recoveryWindow else { return nil }
            return chapterTeaser(for: .recoveryWindow, coachingJob: .optimizeExecution)
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

    static func chapterTeaser(
        for chapter: CoachEnduranceSessionChapter,
        coachingJob: CoachDayLoadCoachingJob = .optimizeExecution
    ) -> (idea: String, action: String) {
        if coachingJob != .optimizeExecution {
            return protectionChapterTeaser(for: chapter, coachingJob: coachingJob)
        }

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

    private static func protectionChapterTeaser(
        for chapter: CoachEnduranceSessionChapter,
        coachingJob: CoachDayLoadCoachingJob
    ) -> (idea: String, action: String) {
        switch chapter {
        case .opening:
            if coachingJob == .dayCap {
                return (
                    localized(english: "Second session today", russian: "Вторая поездка сегодня"),
                    localized(english: "Keep the whole ride light.", russian: "Держите весь заезд лёгким.")
                )
            }
            return (
                localized(english: "Day is already heavy", russian: "День уже тяжёлый"),
                localized(english: "Hold the cap — don't add load.", russian: "Держите потолок — не добавляйте нагрузку.")
            )
        case .establish:
            return (
                localized(english: "Minimum fuel only", russian: "Минимум еды"),
                localized(english: "Small amounts on schedule.", russian: "Малые порции по графику.")
            )
        case .maintain:
            return (
                localized(english: "Hold the floor", russian: "Держите дно"),
                localized(english: "No surges — protect the day.", russian: "Без рывков — берегите день.")
            )
        case .protect:
            return (
                localized(english: "Close without costing the day", russian: "Закройте без ущерба для дня"),
                localized(english: "Finish calmly, not fast.", russian: "Дожмите спокойно, не быстро.")
            )
        case .recoveryWindow:
            return chapterTeaser(for: .recoveryWindow, coachingJob: .optimizeExecution)
        }
    }

    private static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }
}
