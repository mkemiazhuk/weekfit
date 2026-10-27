import Foundation
import NaturalLanguage

struct CoachEveningSummaryInput: Codable, Sendable {
    struct Fact: Codable, Sendable {
        let id: String
        let text: String
    }
    let schemaVersion: Int
    let day: String
    let timezone: String
    let locale: String
    let phase: String
    let facts: [String: [Fact]]
}

struct CoachEveningSummary: Codable, Equatable, Sendable {
    struct Passage: Codable, Equatable, Sendable {
        let text: String
        let evidenceIds: [String]
    }
    let headline: String
    let today: Passage
    let now: Passage
    let tomorrow: Passage
    let limitations: [String]
    let day: String
    let locale: String
    let generatedAt: String
    let source: String

    func isValid(for input: CoachEveningSummaryInput) -> Bool {
        validationFailures(for: input).isEmpty
    }

    /// A result already stored by the server. Evidence is not re-checked against a later snapshot.
    func isRecoveredDisplayable(forDay day: String) -> Bool {
        self.day == day
            && ["ai", "fallback"].contains(source)
            && !headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !today.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !now.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !tomorrow.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Precise client-side rejection codes for diagnostics (never log personal text).
    func validationFailures(for input: CoachEveningSummaryInput) -> [String] {
        var failures: [String] = []
        let ids = Set(input.facts.values.flatMap { $0.map(\.id) })
        let allowedSources: Set<String> = ["ai", "fallback"]

        if day != input.day { failures.append("day_mismatch") }
        if locale != input.locale { failures.append("locale_mismatch") }
        if !allowedSources.contains(source) { failures.append("source_invalid") }
        if headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append("headline_empty")
        }
        if headline.count > 120 { failures.append("headline_too_long") }
        if limitations.count > 6 { failures.append("limitations_too_many") }

        for (name, passage) in [("today", today), ("now", now), ("tomorrow", tomorrow)] {
            let text = passage.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { failures.append("\(name)_empty") }
            if passage.text.count > 700 { failures.append("\(name)_too_long") }
            let unknown = passage.evidenceIds.filter { !ids.contains($0) }
            if !unknown.isEmpty {
                failures.append("\(name)_unknown_evidence:\(unknown.sorted().joined(separator: ","))")
            }
        }

        if source != "fallback" {
            let visible = [today.text, tomorrow.text, now.text].joined(separator: " ")
            if !CoachEveningSummaryPolicy.textMatchesRequestedLocale(visible, locale: locale) {
                failures.append("locale_text_mismatch")
            }
        }
        return failures
    }
}

enum CoachEveningSummaryPolicy {
    /// Coach surface for evening recap (Your day + AI + feeling).
    static let isCoachSurfaceEnabled = true

    /// Kept so older DEBUG defaults cannot turn the limit back off.
    static let oncePerDayOverrideKey = "weekfit.coach.eveningSummary.oncePerDay"

    /// After 20:00 local, at most one backend call per local day.
    /// The attempt is reserved before the request. Failure, timeout, language change,
    /// and tab re-entry do not call again. A new local day after 20:00 may call once.
    static var enforcesOncePerDayAndEveningWindow: Bool { true }

    static var allowsManualRefreshAnytime: Bool { !enforcesOncePerDayAndEveningWindow }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// How a stored summary day relates to the user's local day.
    /// Compares `YYYY-MM-DD` keys from `calendar`, never the UTC day of `generatedAt`.
    enum SummaryDayRelation: Equatable {
        case current
        case yesterday
        case earlier(Date)
    }

    static func summaryDayRelation(
        summaryDay: String,
        now: Date,
        calendar: Calendar = .current
    ) -> SummaryDayRelation {
        let today = dayKey(now, calendar: calendar)
        if summaryDay == today { return .current }
        let start = calendar.startOfDay(for: now)
        if let previous = calendar.date(byAdding: .day, value: -1, to: start),
           dayKey(previous, calendar: calendar) == summaryDay {
            return .yesterday
        }
        return .earlier(date(fromDayKey: summaryDay, calendar: calendar) ?? start)
    }

    /// Caption for a summary that is not the user's current local day. `nil` means show it as today.
    static func summaryDayCaption(
        summaryDay: String?,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard let summaryDay else { return nil }
        switch summaryDayRelation(summaryDay: summaryDay, now: now, calendar: calendar) {
        case .current:
            return nil
        case .yesterday:
            return WeekFitLocalizedString("coach.eveningRecap.summaryDay.yesterday")
        case .earlier(let date):
            let formatter = DateFormatter()
            formatter.locale = WeekFitCurrentLocale()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
            return formatter.string(from: date)
        }
    }

    static func date(fromDayKey key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)
    }

    static func isEvening(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.hour, from: date) >= 20
    }

    /// When once-per-day mode is on, generation requires the evening window.
    static func allowsGeneration(at date: Date, calendar: Calendar = .current) -> Bool {
        if enforcesOncePerDayAndEveningWindow {
            return isEvening(date, calendar: calendar)
        }
        return true
    }

    /// Prefer day conclusion + tomorrow guidance; fall back to the short `now` note.
    static func displayCommentary(from summary: CoachEveningSummary) -> String {
        let today = summary.today.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let tomorrow = summary.tomorrow.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = summary.now.text.trimmingCharacters(in: .whitespacesAndNewlines)

        var parts: [String] = []
        if !today.isEmpty { parts.append(today) }
        if !tomorrow.isEmpty { parts.append(tomorrow) }
        if parts.isEmpty, !now.isEmpty { parts.append(now) }
        let joined = clampCommentary(parts.joined(separator: " "), maxSentences: 3)
        // Drop English (or otherwise mismatched) sentences under a non-matching UI language.
        return filteringToRequestedLocale(joined, locale: summary.locale)
    }

    /// Rejects clear language leaks (e.g. English under `pl`) while staying permissive on short/ambiguous text.
    /// Checks sentence-by-sentence so a Polish comparison cannot mask an English AI takeaway.
    static func textMatchesRequestedLocale(_ text: String, locale: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        guard nlLanguage(for: locale) != nil else { return true }

        let parts = splitIntoSentences(trimmed)
        let sentences = parts.isEmpty ? [trimmed] : parts
        return sentences.allSatisfy { sentenceMatchesRequestedLocale($0, locale: locale) }
    }

    /// Keep only sentences that match the requested locale (drops English leaks under PL/RU/…).
    static func filteringToRequestedLocale(_ text: String, locale: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard nlLanguage(for: locale) != nil else { return trimmed }

        let sentences = splitIntoSentences(trimmed)
        guard !sentences.isEmpty else {
            return sentenceMatchesRequestedLocale(trimmed, locale: locale) ? trimmed : ""
        }

        let kept = sentences.filter { sentenceMatchesRequestedLocale($0, locale: locale) }
        guard !kept.isEmpty else { return "" }
        return joinSentences(kept)
    }

    /// Splits on `.!?。！？` while preserving decimal points inside numbers (`20.5`, `30.9`).
    static func splitIntoSentences(_ text: String) -> [String] {
        let terminators = CharacterSet(charactersIn: ".!?。！？")
        var sentences: [String] = []
        var current = ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            guard let scalar = ch.unicodeScalars.first, terminators.contains(scalar) else {
                current.append(ch)
                i += 1
                continue
            }

            // Keep `digit.digit` (and multi-dot versions like 1.2.3) intact.
            let prevIsDigit = i > 0 && chars[i - 1].isNumber
            let nextIsDigit = i + 1 < chars.count && chars[i + 1].isNumber
            if ch == "." && prevIsDigit && nextIsDigit {
                current.append(ch)
                i += 1
                continue
            }

            current.append(ch)
            var j = i + 1
            while j < chars.count,
                  let nextScalar = chars[j].unicodeScalars.first,
                  terminators.contains(nextScalar) {
                // Still protect decimal runs that somehow abut terminators.
                let runPrevDigit = chars[j - 1].isNumber
                let runNextDigit = j + 1 < chars.count && chars[j + 1].isNumber
                if chars[j] == "." && runPrevDigit && runNextDigit {
                    break
                }
                current.append(chars[j])
                j += 1
            }
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                sentences.append(trimmed)
            }
            current = ""
            i = j
        }
        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            sentences.append(trailing)
        }
        return sentences
    }

    static func firstSentence(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = splitIntoSentences(trimmed).first else { return "" }
        if first.hasSuffix(".") || first.hasSuffix("!") || first.hasSuffix("?")
            || first.hasSuffix("。") || first.hasSuffix("！") || first.hasSuffix("？") {
            return first
        }
        return first + "."
    }

    private static func joinSentences(_ sentences: [String]) -> String {
        let joined = sentences.joined(separator: " ")
        if joined.hasSuffix(".") || joined.hasSuffix("!") || joined.hasSuffix("?")
            || joined.hasSuffix("。") || joined.hasSuffix("！") || joined.hasSuffix("？") {
            return joined
        }
        return joined + "."
    }

    private static func sentenceMatchesRequestedLocale(_ text: String, locale: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Short fragments (names, numbers) are too ambiguous to reject.
        guard trimmed.count >= 24 else { return true }
        guard let expected = nlLanguage(for: locale) else { return true }

        // Strip Latin tech tokens so HRV/kcal/etc. do not tip Polish/Russian notes to English.
        let normalized = localeCheckNormalized(trimmed)
        guard normalized.count >= 18 else { return true }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(normalized)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 4)
        if let score = hypotheses[expected], score >= 0.22 {
            return true
        }
        guard let dominant = recognizer.dominantLanguage else { return true }
        if dominant == expected { return true }

        let topScore = hypotheses.values.max() ?? 0
        if topScore < 0.5 { return true }
        if dominant == .english, expected != .english, (hypotheses[.english] ?? 0) >= 0.55 {
            return false
        }
        return dominant == expected
    }

    /// Removes metric acronyms/units that are language-neutral Latin noise for NL detection.
    private static func localeCheckNormalized(_ text: String) -> String {
        let tokens = [
            "HRV", "SDNN", "RHR", "REM", "kcal", "bpm", "ms", "min", "km",
            "HealthKit", "Apple", "Exercise", "WeekFit", "VO2", "Zone"
        ]
        var result = text
        for token in tokens {
            result = result.replacingOccurrences(of: token, with: " ", options: .caseInsensitive)
        }
        return result
            .replacingOccurrences(of: #"\d+([.,]\d+)?"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nlLanguage(for locale: String) -> NLLanguage? {
        switch locale {
        case "en": return .english
        case "ru": return .russian
        case "zh-Hans": return .simplifiedChinese
        case "fr": return .french
        case "pl": return .polish
        case "es": return .spanish
        case "de": return .german
        case "ja": return .japanese
        case "it": return .italian
        case "ko": return .korean
        default: return nil
        }
    }

    private static func clampCommentary(_ text: String, maxSentences: Int = 2) -> String {
        let sentences = splitIntoSentences(text)
        if sentences.isEmpty { return text }
        let kept = Array(sentences.prefix(max(1, maxSentences)))
        return joinSentences(kept)
    }
}
