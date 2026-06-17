import Foundation

// MARK: - Production Session Message Builder

enum CoachSessionMessageBuilder {

    static func messages(
        scenario: CoachActivityScenario,
        fallback: [String],
        maxItems: Int = 3
    ) -> [String] {

        let profile = CoachActivityProfileResolver.resolve(scenario: scenario)
        let messages = profileMessages(
            profile: profile,
            stage: scenario.stage,
            scenario: scenario
        )

        let selected = messages.isEmpty ? fallback : messages

        return Array(unique(selected).map(localized).prefix(maxItems))
    }
}

// MARK: - Messages

private extension CoachSessionMessageBuilder {

    static func profileMessages(
        profile: CoachFuelingActivityProfile,
        stage: CoachActivityStage,
        scenario: CoachActivityScenario
    ) -> [String] {

        switch (profile, stage) {

        case (.breathing, .before):
            return [
                "Sit or lie down comfortably",
                "Let the exhale become slower",
                "Do not force the breath"
            ]

        case (.breathing, .during):
            return [
                "Keep the breath comfortable",
                "Make the exhale gentle",
                "Return calmly if your mind wanders"
            ]

        case (.breathing, .after):
            return [
                "Keep the recovery effect",
                "Continue calmly",
                "Avoid jumping back into stress"
            ]

        // MARK: Running

        case (.endurance(.running), .before):
            if isVeryLongSession(scenario) {
                return [
                    "Keep a pace you could hold all day",
                    "Avoid pushing early hills",
                    "Finish with energy left"
                ]
            }

            return [
                "Start slower than you think",
                "Keep a pace where you can talk",
                "Finish feeling like you could do more"
            ]

        case (.endurance(.running), .during):
            return [
                "Keep the effort steady",
                "Relax your shoulders",
                "Do not chase speed today"
            ]

        case (.endurance(.running), .after):
            return [
                "Walk for a few minutes",
                "Let your breathing settle",
                "Keep the rest of the day easy"
            ]

        // MARK: Cycling

        case (.endurance(.cycling), .before):
            if isVeryLongSession(scenario) {
                return [
                    "Keep a pace you could hold all day",
                    "Avoid pushing on climbs too early",
                    "Finish with energy left"
                ]
            }

            return [
                "Ride easy for the first 10 min",
                "Stay comfortable early",
                "Save energy for the second half"
            ]

        case (.endurance(.cycling), .during):
            if isVeryLongSession(scenario) {
                return [
                    "Keep pressure smooth",
                    "Avoid sudden hard pushes",
                    "Finish stronger than you started"
                ]
            }

            return [
                "Keep pressure smooth",
                "Avoid sudden hard pushes",
                "Finish with energy left"
            ]

        case (.endurance(.cycling), .after):
            return [
                "Spin or walk easy for a few minutes",
                "Let your legs settle",
                "Keep the evening easy"
            ]

        // MARK: Tennis

        case (.racket(.tennis), .before):
            return [
                "Stay light on your feet",
                "Play with control first",
                "Use the first games to find rhythm"
            ]

        case (.racket(.tennis), .during):
            return [
                "Relax between points",
                "Do not rush the next shot",
                "Win with consistency first"
            ]

        case (.racket(.tennis), .after):
            return [
                "Let the body calm down",
                "Protect sleep tonight",
                "Avoid another hard session"
            ]

        // MARK: Squash

        case (.racket(.squash), .before):
            return [
                "Warm up before the first rally",
                "Control the first games",
                "Save energy for the finish"
            ]

        case (.racket(.squash), .during):
            return [
                "Slow down between rallies",
                "Control your breathing",
                "Do not make every rally all-out"
            ]

        case (.racket(.squash), .after):
            return [
                "Cool down gradually",
                "Keep the rest of the day easy",
                "Avoid another hard workout"
            ]

        // MARK: Strength

        case (.strength, .before):
            return [
                "Start with lighter warm-up sets",
                "Focus on clean technique",
                "Leave energy for the final sets"
            ]

        case (.strength, .during):
            return [
                "Keep good form on every set",
                "Leave 1–2 reps in reserve",
                "Stop before technique breaks down"
            ]

        case (.strength, .after):
            return [
                "Walk for 5–10 min",
                "Let your heart rate settle",
                "Avoid adding extra workouts"
            ]

        // MARK: Heat

        case (.heat, .before):
            return [
                "Keep the session comfortable",
                "Do not chase discomfort",
                "Stop before it feels stressful"
            ]

        case (.heat, .during):
            return [
                "Leave if you feel dizzy",
                "Do not stay longer than feels good",
                "Focus on relaxing"
            ]

        case (.heat, .after):
            return [
                "Let your body settle",
                "Keep the evening calm",
                "Avoid hard training after heat"
            ]

        // MARK: Recovery

        case (.recovery, .before):
            return [
                "Keep the pace easy",
                "Move like this is recovery",
                "Finish feeling better, not tired"
            ]

        case (.recovery, .during):
            return [
                "Stay relaxed",
                "Breathe normally",
                "Do not turn this into training"
            ]

        case (.recovery, .after):
            return [
                "Keep the recovery effect",
                "Continue calmly",
                "Avoid adding load"
            ]

        // MARK: General endurance / racket / other

        case (.endurance(.general), .before):
            return [
                "Start easy",
                "Keep the effort comfortable",
                "Finish with energy left"
            ]

        case (.endurance(.general), .during):
            return [
                "Keep effort steady",
                "Stay relaxed",
                "Avoid pushing too early"
            ]

        case (.endurance(.general), .after):
            return [
                "Let your breathing settle",
                "Keep the rest of the day easy",
                "Avoid extra intensity"
            ]

        case (.racket(.general), .before):
            return [
                "Warm up properly",
                "Play with control first",
                "Build rhythm gradually"
            ]

        case (.racket(.general), .during):
            return [
                "Stay relaxed",
                "Do not rush",
                "Focus on consistency"
            ]

        case (.racket(.general), .after):
            return [
                "Let the body calm down",
                "Keep the rest of the day easy",
                "Avoid extra intensity"
            ]

        case (.other, .before):
            return [
                "Start easy",
                "Stay steady",
                "Keep the plan simple"
            ]

        case (.other, .during):
            return [
                "Keep effort steady",
                "Stay comfortable",
                "Finish calmly"
            ]

        case (.other, .after):
            return [
                "Return to the plan",
                "Keep the next step simple",
                "Stay consistent"
            ]

        case (_, .stable):
            return []
        }
    }

    static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { continue }

            let key = clean.lowercased()
            guard !seen.contains(key) else { continue }

            seen.insert(key)
            result.append(clean)
        }

        return result
    }

    static func localized(_ text: String) -> String {
        let catalogValue = WeekFitLocalizedString(text)
        if catalogValue != text || !WeekFitCurrentLocale().identifier.hasPrefix("ru") {
            return catalogValue
        }

        return russianFixedMessageTranslations[text] ?? text
    }

    static let russianFixedMessageTranslations: [String: String] = [
        "Avoid adding extra workouts": "Не добавляйте лишние тренировки",
        "Avoid adding load": "Не добавляйте нагрузку",
        "Avoid another hard session": "Не добавляйте еще одну тяжелую тренировку",
        "Avoid another hard workout": "Не добавляйте еще одну тяжелую тренировку",
        "Avoid extra intensity": "Избегайте лишней интенсивности",
        "Avoid hard training after heat": "Избегайте тяжелой тренировки после тепла",
        "Avoid jumping back into stress": "Не возвращайтесь резко в стресс",
        "Avoid pushing early hills": "Не давите на ранних подъемах",
        "Avoid pushing on climbs too early": "Не давите на подъемах слишком рано",
        "Avoid pushing too early": "Не давите слишком рано",
        "Avoid sudden hard pushes": "Избегайте резких тяжелых ускорений",
        "Breathe normally": "Дышите нормально",
        "Build rhythm gradually": "Набирайте ритм постепенно",
        "Continue calmly": "Продолжайте спокойно",
        "Control the first games": "Контролируйте первые геймы",
        "Control your breathing": "Контролируйте дыхание",
        "Cool down gradually": "Остывайте постепенно",
        "Do not chase discomfort": "Не гонитесь за дискомфортом",
        "Do not chase speed today": "Сегодня не гонитесь за скоростью",
        "Do not force the breath": "Не форсируйте дыхание",
        "Do not make every rally all-out": "Не играйте каждый розыгрыш на максимуме",
        "Do not rush": "Не спешите",
        "Do not rush the next shot": "Не спешите со следующим ударом",
        "Do not stay longer than feels good": "Не оставайтесь дольше комфортного",
        "Do not turn this into training": "Не делайте из этого тренировку",
        "Finish calmly": "Закончите спокойно",
        "Finish feeling better, not tired": "Закончите с ощущением лучше, а не усталости",
        "Finish feeling like you could do more": "Закончите с ощущением, что могли бы сделать еще",
        "Finish stronger than you started": "Закончите сильнее, чем начали",
        "Finish with energy left": "Закончите с запасом энергии",
        "Focus on clean technique": "Сфокусируйтесь на чистой технике",
        "Focus on consistency": "Сфокусируйтесь на стабильности",
        "Focus on relaxing": "Сфокусируйтесь на расслаблении",
        "Keep a pace where you can talk": "Держите темп, при котором можете говорить",
        "Keep a pace you could hold all day": "Держите темп, который могли бы держать весь день",
        "Keep effort steady": "Держите ровное усилие",
        "Keep good form on every set": "Держите хорошую технику в каждом подходе",
        "Keep pressure smooth": "Держите давление плавным",
        "Keep the breath comfortable": "Держите дыхание комфортным",
        "Keep the effort comfortable": "Держите усилие комфортным",
        "Keep the effort steady": "Держите усилие ровным",
        "Keep the evening calm": "Держите вечер спокойным",
        "Keep the evening easy": "Держите вечер легким",
        "Keep the next step simple": "Держите следующий шаг простым",
        "Keep the pace easy": "Держите темп легким",
        "Keep the plan simple": "Держите план простым",
        "Keep the recovery effect": "Сохраните эффект восстановления",
        "Keep the rest of the day easy": "Оставьте остаток дня легким",
        "Keep the session comfortable": "Держите тренировку комфортной",
        "Leave 1–2 reps in reserve": "Оставляйте 1–2 повтора в запасе",
        "Leave energy for the final sets": "Оставьте энергию на финальные подходы",
        "Leave if you feel dizzy": "Выходите, если почувствуете головокружение",
        "Let the body calm down": "Дайте телу успокоиться",
        "Let the exhale become slower": "Позвольте выдоху стать медленнее",
        "Let your body settle": "Дайте телу стабилизироваться",
        "Let your breathing settle": "Дайте дыханию успокоиться",
        "Let your heart rate settle": "Дайте пульсу успокоиться",
        "Let your legs settle": "Дайте ногам восстановиться",
        "Make the exhale gentle": "Сделайте выдох мягким",
        "Move like this is recovery": "Двигайтесь так, будто это восстановление",
        "Play with control first": "Сначала играйте с контролем",
        "Protect sleep tonight": "Сохраните сон сегодня вечером",
        "Relax between points": "Расслабляйтесь между очками",
        "Relax your shoulders": "Расслабьте плечи",
        "Return calmly if your mind wanders": "Спокойно возвращайтесь, если мысли уходят",
        "Return to the plan": "Вернитесь к плану",
        "Ride easy for the first 10 min": "Первые 10 минут едьте легко",
        "Save energy for the finish": "Сохраните энергию на финиш",
        "Save energy for the second half": "Сохраните энергию на вторую половину",
        "Sit or lie down comfortably": "Сядьте или лягте удобно",
        "Slow down between rallies": "Замедляйтесь между розыгрышами",
        "Spin or walk easy for a few minutes": "Легко покрутите педали или пройдитесь несколько минут",
        "Start easy": "Начните легко",
        "Start slower than you think": "Начните медленнее, чем кажется нужным",
        "Start with lighter warm-up sets": "Начните с более легких разминочных подходов",
        "Stay comfortable": "Оставайтесь в комфорте",
        "Stay comfortable early": "В начале оставайтесь в комфорте",
        "Stay consistent": "Оставайтесь последовательными",
        "Stay light on your feet": "Оставайтесь легкими на ногах",
        "Stay relaxed": "Оставайтесь расслабленными",
        "Stay steady": "Оставайтесь ровными",
        "Stop before it feels stressful": "Остановитесь до ощущения стресса",
        "Stop before technique breaks down": "Остановитесь до ухудшения техники",
        "Use the first games to find rhythm": "Используйте первые геймы, чтобы найти ритм",
        "Walk for 5–10 min": "Пройдитесь 5–10 минут",
        "Walk for a few minutes": "Пройдитесь несколько минут",
        "Warm up before the first rally": "Разомнитесь перед первым розыгрышем",
        "Warm up properly": "Разомнитесь как следует",
        "Win with consistency first": "Сначала выигрывайте стабильностью"
    ]
}

// MARK: - Helpers

private extension CoachSessionMessageBuilder {

    static func durationMinutes(_ scenario: CoachActivityScenario) -> Int {
        guard let activity = scenario.activity else {
            return 0
        }

        return max(activity.effectiveDurationMinutes, activity.durationMinutes)
    }

    static func isVeryLongSession(_ scenario: CoachActivityScenario) -> Bool {
        durationMinutes(scenario) >= 150 ||
        scenario.durationBucket == .over90
    }
}
