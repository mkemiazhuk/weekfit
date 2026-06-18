import Foundation

struct CoachNarrative {
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = coachNarrativeLocalizedText(
            title,
            fallback: "Держите тренировку под контролем"
        )
        self.message = coachNarrativeLocalizedText(
            message,
            fallback: "Сделайте следующий шаг легче, держите усилие повторяемым и корректируйте план по самочувствию."
        )
    }
}

private func coachNarrativeLocalizedText(_ text: String, fallback: String) -> String {
    let localized = WeekFitLocalizedString(text)
    if localized != text || !WeekFitCurrentLocale().identifier.hasPrefix("ru") {
        return localized
    }
    return fallback
}
