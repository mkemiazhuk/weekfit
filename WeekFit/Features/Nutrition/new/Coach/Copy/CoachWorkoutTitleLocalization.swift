import Foundation

enum CoachWorkoutTitleLocalization {

    static func displayTitle(_ rawTitle: String, russian: Bool) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        return russian ? WeekFitCoachRuntimeLocalizedString(trimmed) : trimmed
    }

    static func bilingual(_ rawTitle: String) -> (english: String, russian: String) {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (trimmed, trimmed) }
        return (trimmed, WeekFitCoachRuntimeLocalizedString(trimmed))
    }

    /// Lowercase activity label for mid-sentence Russian copy.
    static func russianPhraseTitle(_ rawTitle: String) -> String {
        decapitalizePhrase(displayTitle(rawTitle, russian: true))
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
        return "Hold reserve for \(displayTitle(trimmed, russian: false)) tomorrow."
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
}
