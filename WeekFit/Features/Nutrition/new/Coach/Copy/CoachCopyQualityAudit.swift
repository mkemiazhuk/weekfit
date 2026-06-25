import Foundation

/// Copy quality guards for Phase 1 packs — catches V5-style drift before Phase 2.
enum CoachCopyQualityAudit {

    struct Report: Equatable {
        let violations: [String]

        var isClean: Bool { violations.isEmpty }
    }

    static func audit(pack: CoachCopyPack, input: CoachCopyBuildInput) -> Report {
        var violations: [String] = []

        violations += nonEmptySectionChecks(pack)
        violations += bilingualChecks(pack)
        violations += lengthChecks(pack)
        violations += duplicateChecks(pack)
        violations += supportSignalChecks(pack, input: input)
        violations += warningLayerChecks(pack, input: input)
        violations += supportingSignalCountCheck(pack)
        violations += subjectGuardChecks(pack: pack, input: input)

        return Report(violations: violations)
    }

    // MARK: - Section presence

    private static func nonEmptySectionChecks(_ pack: CoachCopyPack) -> [String] {
        var issues: [String] = []
        if pack.assessment.isEmpty { issues.append("assessment is empty") }
        if pack.recommendation.isEmpty { issues.append("recommendation is empty") }
        if pack.avoid.isEmpty { issues.append("avoid is empty") }
        if pack.nextAction.isEmpty { issues.append("nextAction is empty") }
        return issues
    }

    // MARK: - Bilingual parity

    private static func bilingualChecks(_ pack: CoachCopyPack) -> [String] {
        var issues: [String] = []
        for (name, section) in sectionPairs(pack) {
            for (index, line) in section.lines.enumerated() {
                if line.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append("\(name)[\(index)] missing english")
                }
                if line.russian.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append("\(name)[\(index)] missing russian")
                }
            }
        }
        if let warning = pack.warningLayer {
            if warning.message.english.isEmpty { issues.append("warningLayer missing english") }
            if warning.message.russian.isEmpty { issues.append("warningLayer missing russian") }
        }
        return issues
    }

    // MARK: - Length

    private static func lengthChecks(_ pack: CoachCopyPack) -> [String] {
        var issues: [String] = []
        for line in pack.assessment.lines {
            if sentenceCount(line.english) > 2 || sentenceCount(line.russian) > 2 {
                issues.append("assessment exceeds 2 sentences")
            }
        }
        for name in ["recommendation", "avoid", "nextAction"] {
            let section = section(named: name, pack: pack)
            for line in section.lines where sentenceCount(line.english) > 1 || sentenceCount(line.russian) > 1 {
                issues.append("\(name) exceeds 1 sentence")
            }
        }
        return issues
    }

    // MARK: - Duplicates

    private static func duplicateChecks(_ pack: CoachCopyPack) -> [String] {
        let mainSections: [(String, CoachCopySection)] = [
            ("assessment", pack.assessment),
            ("recommendation", pack.recommendation),
            ("avoid", pack.avoid),
            ("nextAction", pack.nextAction)
        ]

        var issues: [String] = []
        var seen: [String: String] = [:]

        for (sectionName, section) in mainSections {
            for line in section.lines {
                for (lang, text) in [("en", line.english), ("ru", line.russian)] {
                    let key = normalize(text)
                    guard !key.isEmpty else { continue }
                    if let prior = seen[key] {
                        issues.append("duplicate \(lang) line in \(prior) and \(sectionName)")
                    } else {
                        seen[key] = sectionName
                    }
                }
            }
        }

        issues += crossSectionOverlapChecks(pack)
        return issues
    }

    private static func crossSectionOverlapChecks(_ pack: CoachCopyPack) -> [String] {
        var issues: [String] = []
        let pairs: [(String, CoachCopySection, String, CoachCopySection)] = [
            ("assessment", pack.assessment, "recommendation", pack.recommendation),
            ("assessment", pack.assessment, "avoid", pack.avoid),
            ("assessment", pack.assessment, "nextAction", pack.nextAction),
            ("recommendation", pack.recommendation, "avoid", pack.avoid),
            ("recommendation", pack.recommendation, "nextAction", pack.nextAction),
            ("avoid", pack.avoid, "nextAction", pack.nextAction)
        ]

        for (leftName, left, rightName, right) in pairs {
            if sectionsShareSignificantPhrase(left, right) {
                issues.append("overlap between \(leftName) and \(rightName)")
            }
        }
        return issues
    }

    // MARK: - Support vs main story

    private static func supportSignalChecks(
        _ pack: CoachCopyPack,
        input: CoachCopyBuildInput
    ) -> [String] {
        var issues: [String] = []
        let mainStory = [
            allText(in: pack.assessment),
            allText(in: pack.recommendation),
            allText(in: pack.avoid),
            allText(in: pack.nextAction)
        ].flatMap { $0 }.joined(separator: " ")

        if input.modifiers.hydrationBehind, input.safetyAlert != .hydrationCritical {
            if mentionsHydration(mainStory) {
                issues.append("hydrationBehind leaked into main story sections")
            }
        }

        if input.modifiers.fuelBehind, input.safetyAlert != .fuelCritical {
            if mentionsFuel(mainStory) {
                issues.append("fuelBehind leaked into main story sections")
            }
        }

        return issues
    }

    // MARK: - Warning layer

    private static func warningLayerChecks(
        _ pack: CoachCopyPack,
        input: CoachCopyBuildInput
    ) -> [String] {
        switch input.safetyAlert {
        case .none:
            return pack.warningLayer == nil ? [] : ["warningLayer present without safetyAlert"]
        case .some(let alert):
            guard let layer = pack.warningLayer else {
                return ["missing warningLayer for critical safetyAlert"]
            }
            return layer.alert == alert ? [] : ["warningLayer alert mismatch"]
        }
    }

    private static func supportingSignalCountCheck(_ pack: CoachCopyPack) -> [String] {
        pack.supportingSignals.lines.count > 3
            ? ["supportingSignals exceeds 3 lines"]
            : []
    }

    private static func subjectGuardChecks(
        pack: CoachCopyPack,
        input: CoachCopyBuildInput
    ) -> [String] {
        guard CoachCopySubjectGuard.requiresScenarioSubject(input.scenario) else {
            return []
        }

        var issues: [String] = []
        if !CoachCopySubjectGuard.assessmentStartsWithScenarioSubject(
            pack: pack,
            scenario: input.scenario,
            activityType: input.activityType
        ) {
            issues.append("assessment does not open with scenario subject")
        }
        if !CoachCopySubjectGuard.mainSectionsAvoidMetricHero(pack: pack) {
            issues.append("main sections lead with metric hero")
        }
        return issues
    }

    // MARK: - Helpers

    private static func sectionPairs(_ pack: CoachCopyPack) -> [(String, CoachCopySection)] {
        [
            ("assessment", pack.assessment),
            ("recommendation", pack.recommendation),
            ("avoid", pack.avoid),
            ("nextAction", pack.nextAction),
            ("supportingSignals", pack.supportingSignals)
        ]
    }

    private static func section(named name: String, pack: CoachCopyPack) -> CoachCopySection {
        switch name {
        case "recommendation": return pack.recommendation
        case "avoid": return pack.avoid
        case "nextAction": return pack.nextAction
        default: return pack.assessment
        }
    }

    private static func allText(in section: CoachCopySection) -> [String] {
        section.lines.flatMap { [$0.english, $0.russian] }
    }

    private static func sentenceCount(_ text: String) -> Int {
        text.split(whereSeparator: { ".!?".contains($0) }).filter { !$0.isEmpty }.count
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
            .joined(separator: " ")
    }

    private static func sectionsShareSignificantPhrase(
        _ lhs: CoachCopySection,
        _ rhs: CoachCopySection
    ) -> Bool {
        let leftPhrases = significantPhrases(in: lhs)
        let rightPhrases = significantPhrases(in: rhs)
        return !leftPhrases.intersection(rightPhrases).isEmpty
    }

    private static func significantPhrases(in section: CoachCopySection) -> Set<String> {
        var phrases: Set<String> = []
        for line in section.lines {
            for text in [line.english, line.russian] {
                let words = normalize(text).split(separator: " ").map(String.init)
                guard words.count >= 3 else { continue }
                for window in 0...(words.count - 3) {
                    phrases.insert(words[window...(window + 2)].joined(separator: " "))
                }
            }
        }
        return phrases
    }

    static func mentionsHydration(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("water") || lower.contains("fluid") || lower.contains("hydration") ||
            lower.contains("drink") || lower.contains("sip") ||
            text.contains("вод") || text.contains("жидк") || text.contains("пейте") || text.contains("глот")
    }

    static func mentionsFuel(_ text: String) -> Bool {
        let lower = text.lowercased()
        let tokens = lower.split(whereSeparator: { !$0.isLetter }).map(String.init)
        if tokens.contains(where: { ["fuel", "eat", "food", "snack", "meal"].contains($0) }) {
            return true
        }
        return text.contains("питан") || text.contains("перекус") ||
            text.contains("Пое") || text.contains("пoe") || text.contains("ешьте") ||
            text.contains("Ешьте") || text.contains("поешь") || text.contains("Поешь")
    }
}
