import Foundation

enum CoachWorkoutTitleLocalization {

    static func displayTitle(
        _ rawTitle: String,
        language: AppLanguage = WeekFitCurrentAppLanguage()
    ) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        switch language {
        case .russian:
            return WeekFitCoachRuntimeLocalizedString(trimmed, russian: true)
        case .chineseSimplified:
            if let chinese = chineseTitles[trimmed] ?? chineseTitles[trimmed.lowercased()] {
                return chinese
            }
            if let fromPlanner = chineseFromPlannerOption(trimmed) {
                return fromPlanner
            }
            if let override = CoachChineseOverrides.resolved(english: trimmed) {
                return override
            }
            return WeekFitCoachRuntimeLocalizedString(trimmed)
        case .english:
            return trimmed
        }
    }

    /// Backward-compatible API used by older call sites.
    static func displayTitle(_ rawTitle: String, russian: Bool) -> String {
        displayTitle(rawTitle, language: russian ? .russian : .english)
    }

    static func bilingual(_ rawTitle: String) -> (english: String, russian: String) {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (trimmed, trimmed) }
        return (
            trimmed,
            WeekFitCoachRuntimeLocalizedString(trimmed, russian: true)
        )
    }

    static func trilingual(_ rawTitle: String) -> (english: String, russian: String, chinese: String) {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (trimmed, trimmed, trimmed) }
        return (
            trimmed,
            WeekFitCoachRuntimeLocalizedString(trimmed, russian: true),
            displayTitle(trimmed, language: .chineseSimplified)
        )
    }

    /// Lowercase activity label for mid-sentence Russian copy.
    static func russianPhraseTitle(_ rawTitle: String) -> String {
        decapitalizePhrase(displayTitle(rawTitle, language: .russian))
    }

    static func tomorrowReserveTeaser(rawTitle: String, russian: Bool) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return russian
                ? "Берегите силы на завтра."
                : "Hold reserve for tomorrow's session."
        }
        if russian {
            return "Завтра \(russianPhraseTitle(trimmed)) — сегодня берегите силы."
        }
        if WeekFitUsesChineseSimplifiedLanguage() {
            return "为明天的\(displayTitle(trimmed, language: .chineseSimplified))留出余力。"
        }
        return "Hold reserve for \(displayTitle(trimmed, language: .english)) tomorrow."
    }

    static func tomorrowMainSessionAssessment(
        rawTitle: String,
        quietDayEmphasis: Bool
    ) -> (english: String, russian: String) {
        let titles = bilingual(rawTitle)
        guard !titles.english.isEmpty else {
            return (
                "Tomorrow brings your biggest effort — today is about arriving ready.",
                "Завтра главная нагрузка — сегодня важно подойти к ней свежим."
            )
        }

        if quietDayEmphasis {
            return (
                "\(titles.english) is tomorrow's main session — a quieter day now helps you show up ready.",
                "Завтра \(russianPhraseTitle(rawTitle)) — главная нагрузка. Спокойный день поможет подойти к ней свежим."
            )
        }

        return (
            "\(titles.english) is tomorrow's main session — today is about arriving ready.",
            "Завтра \(russianPhraseTitle(rawTitle)) — главная нагрузка. Сегодня важно подойти к ней свежим."
        )
    }

    static func tomorrowCalendarSignal(rawTitle: String) -> (english: String, russian: String) {
        let titles = bilingual(rawTitle)
        guard !titles.english.isEmpty else {
            return (
                "Tomorrow still needs fresh legs.",
                "Завтра нужны свежие ноги."
            )
        }
        return (
            "\(titles.english) is on the calendar tomorrow.",
            "Завтра в плане — \(russianPhraseTitle(rawTitle))."
        )
    }

    static func tomorrowAlreadyScheduled(rawTitle: String) -> (english: String, russian: String) {
        let titles = bilingual(rawTitle)
        guard !titles.english.isEmpty else {
            return (
                "Tomorrow already has real work on the calendar.",
                "Завтра в календаре серьёзная работа."
            )
        }
        return (
            "\(titles.english) tomorrow already has real work on the calendar.",
            "Завтра \(russianPhraseTitle(rawTitle)) уже в плане."
        )
    }

    static func recoverySolidTomorrowScheduled(rawTitle: String) -> (english: String, russian: String) {
        let scheduled = tomorrowAlreadyScheduled(rawTitle: rawTitle)
        return (
            "Recovery looks solid — \(scheduled.english)",
            "Восстановление в порядке — \(scheduled.russian)."
        )
    }

    private static func decapitalizePhrase(_ title: String) -> String {
        guard let first = title.first else { return title }
        return first.lowercased() + title.dropFirst()
    }

    private static func chineseFromPlannerOption(_ title: String) -> String? {
        let keyMap: [String: String] = [
            "Cycling": "planner.option.cycling",
            "Running": "planner.option.running",
            "Swimming": "planner.option.swimming",
            "Hiking": "planner.option.hiking",
            "Upper Body": "planner.option.upperBody",
            "Core": "planner.option.core",
            "Lower Body": "planner.option.lowerBody",
            "Full Body": "planner.option.fullBody",
            "Tennis": "planner.option.tennis",
            "Squash": "planner.option.squash",
            "High Intensity Interval Training": "planner.option.hiit",
            "HIIT": "planner.option.hiit",
            "Stretching": "planner.option.stretching",
            "Walk": "planner.option.walk",
            "Sauna": "planner.option.sauna",
            "Yoga": "planner.option.yoga",
            "Breathing": "planner.option.breathing",
            "Drink Water": "planner.option.drinkWater",
            "Sleep Routine": "planner.option.sleepRoutine",
            "No Screens": "planner.option.noScreens",
            "Morning Routine": "planner.option.morningRoutine"
        ]
        guard let key = keyMap[title] else { return nil }
        return WeekFitLocalizedString(key, locale: Locale(identifier: AppLanguage.chineseSimplified.rawValue))
    }

    private static let chineseTitles: [String: String] = [
        "Cycling": "骑行",
        "cycling": "骑行",
        "Running": "跑步",
        "running": "跑步",
        "Swimming": "游泳",
        "swimming": "游泳",
        "Hiking": "徒步",
        "Walk": "步行",
        "walk": "步行",
        "Walking": "步行",
        "HIIT": "HIIT",
        "Tennis": "网球",
        "Squash": "壁球",
        "Yoga": "瑜伽",
        "Sauna": "桑拿",
        "Stretching": "拉伸",
        "Breathing": "呼吸",
        "Upper Body": "上肢",
        "Lower Body": "下肢",
        "Full Body": "全身",
        "Core": "核心",
        "Strength": "力量",
        "Long Run": "长跑",
        "Easy Run": "轻松跑",
        "Tempo Run": "节奏跑",
        "Recovery Run": "恢复跑",
        "ride": "骑行",
        "run": "跑步",
        "swim": "游泳",
        "session": "训练"
    ]
}
