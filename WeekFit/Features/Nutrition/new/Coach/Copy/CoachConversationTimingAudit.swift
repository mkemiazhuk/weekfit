import Foundation

/// Audits coach copy for time-inappropriate closure / evening phrasing.
enum CoachConversationTimingAudit {

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

    /// Before 18:00 — rest-of-day / evening tone must not appear.
    static let beforeEveningRussian: [String] = [
        "остаток дня",
        "перед сном",
        "вечер"
    ]

    /// Before 21:00 (and outside day-closing frame) — day-closure tone must not appear.
    static let beforeWindDownRussian: [String] = [
        "на сегодня достаточно",
        "завершить день",
        "день можно завершить",
        "завершаем день",
        "заканчивайте день",
        "плотный день позади"
    ]

  static func audit(pack: CoachCopyPack, input: CoachCopyBuildInput) -> Report {
        var findings: [Finding] = []

        for (section, lines) in allSections(pack) {
            for (index, line) in lines.enumerated() {
                findings += auditText(
                    line.russian,
                    section: "\(section)[\(index)]",
                    language: "ru",
                    timeOfDay: input.timeOfDay,
                    conversationPhase: input.conversationPhase
                )
            }
        }

        if let warning = pack.warningLayer {
            findings += auditText(
                warning.message.russian,
                section: "warningLayer",
                language: "ru",
                timeOfDay: input.timeOfDay,
                conversationPhase: input.conversationPhase
            )
        }

        return Report(findings: findings)
    }

    static func forbiddenPhrases(
        in text: String,
        timeOfDay: CoachTimeOfDay,
        conversationPhase: CoachConversationPhase = .steady
    ) -> [String] {
        auditText(
            text,
            section: "text",
            language: "ru",
            timeOfDay: timeOfDay,
            conversationPhase: conversationPhase
        ).map(\.phrase)
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
        timeOfDay: CoachTimeOfDay,
        conversationPhase: CoachConversationPhase
    ) -> [Finding] {
        let normalized = text.lowercased()
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var findings: [Finding] = []

        if !CoachCopyClosureTiming.allowsRestOfDayPhrasing(timeOfDay) {
            for phrase in beforeEveningRussian where normalized.contains(phrase) {
                findings.append(Finding(
                    section: section,
                    language: language,
                    phrase: phrase,
                    reason: "before 18:00 evening tone"
                ))
            }
        }

        if !CoachCopyClosureTiming.allowsDayClosurePhrasing(
            timeOfDay: timeOfDay,
            conversationPhase: conversationPhase
        ) {
            for phrase in beforeWindDownRussian where normalized.contains(phrase) {
                findings.append(Finding(
                    section: section,
                    language: language,
                    phrase: phrase,
                    reason: "before 21:00 day-closure tone"
                ))
            }
        }

        return findings
    }
}
