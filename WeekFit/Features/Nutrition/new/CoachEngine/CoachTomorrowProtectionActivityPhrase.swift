import Foundation

/// Localized tomorrow-stake phrases for Wind Down / tomorrowProtection copy.
/// Russian uses full accusative/feminine phrases — never `завтрашний` + raw activity title.
enum CoachTomorrowProtectionActivityPhrase {

    struct Forms: Equatable {
        let englishObject: String
        /// After «Сохраните силы» / «Не тратьте силы» — e.g. «на завтрашнюю длинную поездку».
        let russianWithPrepositionNa: String
        /// Direct object — e.g. «завтрашнюю длинную поездку».
        let russianAccusativeObject: String
        /// Sentence subject — e.g. «Завтрашняя длинная поездка».
        let russianTomorrowSubject: String
        /// After «запланирована» — e.g. «длинная поездка».
        let russianPlannedFeminine: String
    }

    static func forms(for activity: PlannedActivity) -> Forms {
        let text = "\(activity.title) \(activity.type)".lowercased()
        let duration = activity.effectiveDurationMinutes
        let kind = CoachActivityContextResolverV3.kind(for: activity)
        let isLongEndurance = duration >= 120 || (kind == .endurance && duration >= 120)

        if text.contains("cycl") || text.contains("bike") || text.contains("ride") || text.contains("вел") {
            if isLongEndurance {
                return Forms(
                    englishObject: "long ride",
                    russianWithPrepositionNa: "на завтрашнюю длинную поездку",
                    russianAccusativeObject: "завтрашнюю длинную поездку",
                    russianTomorrowSubject: "Завтрашняя длинная поездка",
                    russianPlannedFeminine: "длинная поездка"
                )
            }
            return Forms(
                englishObject: "ride",
                russianWithPrepositionNa: "на завтрашнюю велотренировку",
                russianAccusativeObject: "завтрашнюю велотренировку",
                russianTomorrowSubject: "Завтрашняя велотренировка",
                russianPlannedFeminine: "велотренировка"
            )
        }

        if text.contains("run") || text.contains("running") || text.contains("jog") || text.contains("бег") {
            if isLongEndurance {
                return Forms(
                    englishObject: "long run",
                    russianWithPrepositionNa: "на завтрашнюю длинную пробежку",
                    russianAccusativeObject: "завтрашнюю длинную пробежку",
                    russianTomorrowSubject: "Завтрашняя длинная пробежка",
                    russianPlannedFeminine: "длинная пробежка"
                )
            }
            return Forms(
                englishObject: "run",
                russianWithPrepositionNa: "на завтрашнюю пробежку",
                russianAccusativeObject: "завтрашнюю пробежку",
                russianTomorrowSubject: "Завтрашняя пробежка",
                russianPlannedFeminine: "пробежка"
            )
        }

        if text.contains("swim") || text.contains("swimming") {
            if isLongEndurance {
                return Forms(
                    englishObject: "long swim",
                    russianWithPrepositionNa: "на завтрашний длинный заплыв",
                    russianAccusativeObject: "завтрашний длинный заплыв",
                    russianTomorrowSubject: "Завтрашний длинный заплыв",
                    russianPlannedFeminine: "длинный заплыв"
                )
            }
            return Forms(
                englishObject: "swim",
                russianWithPrepositionNa: "на завтрашний заплыв",
                russianAccusativeObject: "завтрашний заплыв",
                russianTomorrowSubject: "Завтрашний заплыв",
                russianPlannedFeminine: "заплыв"
            )
        }

        if text.contains("strength") || text.contains("gym") || kind == .workout {
            return Forms(
                englishObject: "strength session",
                russianWithPrepositionNa: "на завтрашнюю силовую тренировку",
                russianAccusativeObject: "завтрашнюю силовую тренировку",
                russianTomorrowSubject: "Завтрашняя силовая тренировка",
                russianPlannedFeminine: "силовая тренировка"
            )
        }

        return Forms(
            englishObject: "session",
            russianWithPrepositionNa: "на завтрашнюю тренировку",
            russianAccusativeObject: "завтрашнюю тренировку",
            russianTomorrowSubject: "Завтрашняя тренировка",
            russianPlannedFeminine: "тренировка"
        )
    }

    static func saveEnergyTitle(for activity: PlannedActivity) -> (english: String, russian: String) {
        let phrase = forms(for: activity)
        return (
            "Save your energy for tomorrow's \(phrase.englishObject)",
            "Сохраните силы \(phrase.russianWithPrepositionNa)"
        )
    }

    static func plannedTomorrowAssessment(for activity: PlannedActivity) -> (english: String, russian: String) {
        let phrase = forms(for: activity)
        let duration = activity.effectiveDurationMinutes
        return (
            "Tomorrow has a \(duration)-minute \(phrase.englishObject) planned.",
            "Завтра запланирована \(phrase.russianPlannedFeminine) на \(duration) минут."
        )
    }

    static func easierStartSituation(for activity: PlannedActivity) -> (english: String, russian: String) {
        let phrase = forms(for: activity)
        return (
            "Tonight should make tomorrow's \(phrase.englishObject) easier to start.",
            "Сегодняшний вечер должен облегчить \(phrase.russianAccusativeObject)."
        )
    }

    static func doNotSpendEnergyTonight(for activity: PlannedActivity) -> (english: String, russian: String) {
        let phrase = forms(for: activity)
        return (
            "Do not spend energy tonight that tomorrow's \(phrase.englishObject) will need.",
            "Не тратьте сегодня силы \(phrase.russianWithPrepositionNa)."
        )
    }

    static func higherPriorityDemand(for activity: PlannedActivity) -> (english: String, russian: String) {
        let phrase = forms(for: activity)
        return (
            "Tomorrow's \(phrase.englishObject) is the higher-priority demand.",
            "\(phrase.russianTomorrowSubject) — более приоритетная нагрузка."
        )
    }

    static func eveningWhatMatters(loadAlreadyHigh: Bool) -> (english: String, russian: String) {
        if loadAlreadyHigh {
            return (
                "You already have enough work in the tank for today.",
                "На сегодня работы уже достаточно."
            )
        }
        return (
            "Don't add more load to today.",
            "Сегодня лучше не добирать нагрузку."
        )
    }

    static func tomorrowStakeReason(for activity: PlannedActivity) -> (english: String, russian: String) {
        let phrase = forms(for: activity)
        if activity.effectiveDurationMinutes >= 120 {
            return (
                "Tomorrow's \(phrase.englishObject) is waiting.",
                "Завтра вас ждёт \(phrase.russianPlannedFeminine)."
            )
        }
        return (
            "Tomorrow's \(phrase.englishObject) is on the plan.",
            "Завтра запланирована \(phrase.russianPlannedFeminine)."
        )
    }
}
