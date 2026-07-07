import Foundation

/// Guards Today-card teaser copy against repeating metrics already visible in Overview rings.
enum CoachTeaserCopyAudit {

    enum Field: String, Equatable {
        case todayTitle
        case todayMessage
    }

    struct Finding: Equatable {
        let field: Field
        let language: String
        let reason: String
    }

    struct Report: Equatable {
        let scenario: CoachScenarioKey
        let variant: String?
        let findings: [Finding]

        var isClean: Bool { findings.isEmpty }

        var label: String {
            if let variant {
                return "\(scenario.rawValue) [\(variant)]"
            }
            return scenario.rawValue
        }
    }

    static func audit(_ content: CoachTeaserCopy.Content) -> [Finding] {
        audit(englishTitle: content.todayTitle.english, russianTitle: content.todayTitle.russian)
            + audit(englishMessage: content.todayMessage.english, russianMessage: content.todayMessage.russian)
    }

    private static func audit(englishTitle: String, russianTitle: String) -> [Finding] {
        titleFindings(in: englishTitle, language: "en")
            + titleFindings(in: russianTitle, language: "ru")
    }

    private static func audit(englishMessage: String, russianMessage: String) -> [Finding] {
        messageFindings(in: englishMessage, language: "en")
            + messageFindings(in: russianMessage, language: "ru")
    }

    private static func titleFindings(in text: String, language: String) -> [Finding] {
        metricFindings(in: text, field: .todayTitle, language: language, strict: true)
    }

    private static func messageFindings(in text: String, language: String) -> [Finding] {
        metricFindings(in: text, field: .todayMessage, language: language, strict: false)
    }

    private static func metricFindings(
        in text: String,
        field: Field,
        language: String,
        strict: Bool
    ) -> [Finding] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var findings: [Finding] = []

        if trimmed.contains("·") {
            findings.append(Finding(field: field, language: language, reason: "stat separator"))
        }

        if matches(trimmed, pattern: #"\d+\s*%"#) {
            findings.append(Finding(field: field, language: language, reason: "recovery percent"))
        }

        if matches(trimmed, pattern: #"(?i)\b\d+(\.\d+)?\s*(kcal|cal|ккал)\b"#) {
            findings.append(Finding(field: field, language: language, reason: "calorie total"))
        }

        if matches(trimmed, pattern: #"(?i)\b\d+\s*(h|hr|hrs|hours)\b(\s+\d+\s*(m|min|mins|minutes))?"#)
            || matches(trimmed, pattern: #"\b\d+\s*(ч|час)\b(\s+\d+\s*(м|мин))?"#)
            || matches(trimmed, pattern: #"\b\d+ч\s*\d+м\b"#) {
            findings.append(Finding(field: field, language: language, reason: "sleep duration"))
        }

        if strict, matches(trimmed, pattern: #"(?i)\brecovery\s+\d+\b"#)
            || matches(trimmed, pattern: #"(?i)\b\d+\s+recovery\b"#)
            || matches(trimmed, pattern: #"(?i)\brecovery\s+\d+\s*%"#) {
            findings.append(Finding(field: field, language: language, reason: "recovery score"))
        }

        if !strict {
            if matches(trimmed, pattern: #"(?i)\bsleep\s+\d"#)
                || matches(trimmed, pattern: #"(?i)\bсон\s+\d"#) {
                findings.append(Finding(field: field, language: language, reason: "sleep metric"))
            }
        }

        return findings
    }

    private static func matches(_ text: String, pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
