import Foundation

/// Audits Why-row copy with the same horizon and semantic timing rules as hero copy.
enum WhyRowTimingAudit {

    struct Finding: Equatable {
        let index: Int
        let language: String
        let phrase: String
        let reason: String
    }

    struct Report: Equatable {
        let findings: [Finding]

        var isClean: Bool { findings.isEmpty }
    }

    static func audit(
        rows: [(String, String)],
        input: CoachCopyBuildInput
    ) -> Report {
        let horizon = input.presentationHorizon
        var findings: [Finding] = []

        for (index, row) in rows.enumerated() {
            let text = row.0
            let language = row.1
            let normalized = text.lowercased()
            guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            for phrase in CoachPresentationHorizonCopyAudit.forbiddenPhrases(
                in: text,
                horizon: horizon,
                language: language
            ) {
                findings.append(Finding(
                    index: index,
                    language: language,
                    phrase: phrase,
                    reason: "horizon mismatch in why row"
                ))
            }

            if horizon == .nextHours {
                let behindPhrases = language == "ru" ? behindToneRussian : behindToneEnglish
                for phrase in behindPhrases where normalized.contains(phrase) {
                    findings.append(Finding(
                        index: index,
                        language: language,
                        phrase: phrase,
                        reason: "why row sounds behind while day still has room"
                    ))
                }
            }
        }

        return Report(findings: findings)
    }

    static func audit(
        rows: [String],
        input: CoachCopyBuildInput
    ) -> Report {
        let language = WeekFitCurrentLocale().identifier.hasPrefix("ru") ? "ru" : "en"
        return audit(rows: rows.map { ($0, language) }, input: input)
    }

    static func audit(
        presentation: CoachUIPresentation,
        input: CoachCopyBuildInput
    ) -> Report {
        audit(rows: presentation.whyRows.map(\.title), input: input)
    }

    // MARK: - Phrase sets

    private static let behindToneRussian: [String] = [
        "воды за день пока маловато",
        "воды пока не хватает",
        "еды пока меньше",
        "калорий маловато",
        "сильно отстаёт"
    ]

    private static let behindToneEnglish: [String] = [
        "water is running behind",
        "water still behind",
        "fuel intake is lagging",
        "calories lag"
    ]
}
