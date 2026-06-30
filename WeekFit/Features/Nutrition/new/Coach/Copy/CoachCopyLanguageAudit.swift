import Foundation

/// Detects accidental language mixing in bilingual coach copy.
enum CoachCopyLanguageAudit {

    struct Finding: Equatable {
        let section: String
        let language: String
        let reason: String
        let snippet: String
    }

    struct Report: Equatable {
        let findings: [Finding]

        var isClean: Bool { findings.isEmpty }
    }

    private static let allowedLatinTokens: Set<String> = [
        "am", "pm", "hr", "hrs", "min", "mins", "kcal", "cal", "hrv", "bpm",
        "gps", "hiit", "vo2", "tabata", "core", "ok"
    ]

    /// English coach vocabulary that must not leak into Russian copy.
    private static let forbiddenCoachVocabularyInRussian: Set<String> = [
        "recovery", "sleep", "rest", "load", "walk", "fuel", "hydration",
        "intensity", "training", "workout", "morning", "evening", "breakfast",
        "stretch", "optional", "block", "plan", "heavy", "light", "banked",
        "lagging", "matter", "matters", "keep", "today", "tomorrow", "yesterday",
        "before", "after", "during", "first", "late", "early", "quiet", "calm",
        "feel", "ready", "treat", "burn", "solid", "short", "night", "legs",
        "body", "hours", "hour", "minutes", "percent", "listen", "push",
        "session", "effort"
    ]

    static func audit(pack: CoachCopyPack) -> Report {
        var findings: [Finding] = []

        for (section, lines) in allSections(pack) {
            for (index, line) in lines.enumerated() {
                findings += auditText(
                    line.english,
                    section: "\(section)[\(index)]",
                    language: "en",
                    expectCyrillic: false
                )
                findings += auditText(
                    line.russian,
                    section: "\(section)[\(index)]",
                    language: "ru",
                    expectCyrillic: true
                )
            }
        }

        if let warning = pack.warningLayer {
            findings += auditText(
                warning.message.english,
                section: "warningLayer",
                language: "en",
                expectCyrillic: false
            )
            findings += auditText(
                warning.message.russian,
                section: "warningLayer",
                language: "ru",
                expectCyrillic: true
            )
        }

        return Report(findings: findings)
    }

    static func audit(bilingual: CoachBilingualText, section: String) -> [Finding] {
        auditText(
            bilingual.english,
            section: section,
            language: "en",
            expectCyrillic: false
        ) + auditText(
            bilingual.russian,
            section: section,
            language: "ru",
            expectCyrillic: true
        )
    }

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
        expectCyrillic: Bool
    ) -> [Finding] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var findings: [Finding] = []

        if expectCyrillic {
            for token in disallowedLatinTokens(in: trimmed) {
                findings.append(Finding(
                    section: section,
                    language: language,
                    reason: "latin token \"\(token)\"",
                    snippet: trimmedPrefix(trimmed)
                ))
            }
        } else if containsCyrillic(trimmed) {
            findings.append(Finding(
                section: section,
                language: language,
                reason: "cyrillic characters",
                snippet: trimmedPrefix(trimmed)
            ))
        }

        return findings
    }

    private static func disallowedLatinTokens(in text: String) -> [String] {
        let tokens = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }

        return tokens.filter { token in
            guard token.range(of: #"[a-z]"#, options: .regularExpression) != nil else {
                return false
            }
            if allowedLatinTokens.contains(token) {
                return false
            }
            return forbiddenCoachVocabularyInRussian.contains(token)
        }
    }

    private static func containsCyrillic(_ text: String) -> Bool {
        text.range(of: #"[А-Яа-яЁё]"#, options: .regularExpression) != nil
    }

    private static func trimmedPrefix(_ text: String, limit: Int = 72) -> String {
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }
}
