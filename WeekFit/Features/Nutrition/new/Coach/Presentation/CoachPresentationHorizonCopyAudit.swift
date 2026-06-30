import Foundation

/// Audits hero/support copy against presentation horizon — phrase-level guards.
enum CoachPresentationHorizonCopyAudit {

    struct Finding: Equatable {
        let section: String
        let language: String
        let phrase: String
        let reason: String
    }

    struct Report: Equatable {
        let findings: [Finding]

        var isClean: Bool { findings.isEmpty }
    }

    static let prematureDayClosureRussian: [String] = [
        "остаток дня",
        "остаток вечера",
        "завершить день",
        "день можно завершить",
        "на сегодня достаточно",
        "плотный день позади",
        "доказывать уже нечего"
    ]

    static let prematureDayClosureEnglish: [String] = [
        "rest of the day",
        "rest of today",
        "finish the day",
        "enough for today",
        "day is done",
        "heavy day done",
        "nothing left to prove"
    ]

    static let prematureEveningRussian: [String] = [
        "сегодня вечером",
        "этим вечером",
        "к ночи важнее"
    ]

    static let prematureEveningEnglish: [String] = [
        "tonight",
        "this evening",
        "wind down now"
    ]

    static let prematureTomorrowRussian: [String] = [
        "завтрашние ноги",
        "берегите сон",
        "ложитесь"
    ]

    static let prematureTomorrowEnglish: [String] = [
        "tomorrow's legs",
        "protect sleep",
        "pick a bedtime"
    ]

    static let sleepNowRussian: [String] = [
        "ложитесь",
        "пора спать",
        "ко сну"
    ]

    static let sleepNowEnglish: [String] = [
        "pick a bedtime",
        "sleep now",
        "go to bed"
    ]

    static func audit(pack: CoachCopyPack, input: CoachCopyBuildInput) -> Report {
        audit(pack: pack, horizon: input.presentationHorizon)
    }

    static func audit(pack: CoachCopyPack, horizon: CoachPresentationHorizon) -> Report {
        var findings: [Finding] = []

        for (section, lines) in allSections(pack) {
            for (index, line) in lines.enumerated() {
                let sectionKey = "\(section)[\(index)]"
                findings += auditText(line.russian, section: sectionKey, language: "ru", horizon: horizon)
                findings += auditText(line.english, section: sectionKey, language: "en", horizon: horizon)
            }
        }

        return Report(findings: findings)
    }

    static func forbiddenPhrases(
        in text: String,
        horizon: CoachPresentationHorizon,
        language: String
    ) -> [String] {
        auditText(text, section: "text", language: language, horizon: horizon).map(\.phrase)
    }

    // MARK: - Private

    private static func allSections(_ pack: CoachCopyPack) -> [(String, [CoachBilingualText])] {
        [
            ("assessment", pack.assessment.lines),
            ("recommendation", pack.recommendation.lines),
            ("avoid", pack.avoid.lines),
            ("nextAction", pack.nextAction.lines),
            ("supportingSignals", pack.supportingSignals.lines)
        ]
    }

    private static func auditText(
        _ text: String,
        section: String,
        language: String,
        horizon: CoachPresentationHorizon
    ) -> [Finding] {
        let normalized = text.lowercased()
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var findings: [Finding] = []
        let isRussian = language == "ru"

        switch horizon {
        case .now:
            break
        case .nextHours, .laterToday:
            findings += matched(
                in: normalized,
                section: section,
                language: language,
                phrases: isRussian ? prematureDayClosureRussian : prematureDayClosureEnglish,
                reason: "\(horizon.rawValue) speaks too far ahead"
            )
            findings += matched(
                in: normalized,
                section: section,
                language: language,
                phrases: isRussian ? prematureEveningRussian : prematureEveningEnglish,
                reason: "\(horizon.rawValue) uses evening tone too early"
            )
            findings += matched(
                in: normalized,
                section: section,
                language: language,
                phrases: isRussian ? prematureTomorrowRussian : prematureTomorrowEnglish,
                reason: "\(horizon.rawValue) uses tomorrow tone too early"
            )
        case .evening:
            findings += matched(
                in: normalized,
                section: section,
                language: language,
                phrases: isRussian ? sleepNowRussian : sleepNowEnglish,
                reason: "evening uses sleep-now tone"
            )
        case .tomorrow:
            break
        }

        return findings
    }

    private static func matched(
        in text: String,
        section: String,
        language: String,
        phrases: [String],
        reason: String
    ) -> [Finding] {
        phrases.compactMap { phrase in
            guard text.contains(phrase) else { return nil }
            return Finding(section: section, language: language, phrase: phrase, reason: reason)
        }
    }
}
