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
        let ids = Set(input.facts.values.flatMap { $0.map(\.id) })
        let allowedSources: Set<String> = ["ai", "fallback"]
        return day == input.day && locale == input.locale && allowedSources.contains(source)
            && !headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && headline.count <= 120 && limitations.count <= 6
            && [today, now, tomorrow].allSatisfy {
                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && $0.text.count <= 700 && $0.evidenceIds.allSatisfy(ids.contains)
            }
            && (source == "fallback"
                || CoachEveningSummaryPolicy.textMatchesRequestedLocale(
                    [today.text, tomorrow.text, now.text].joined(separator: " "),
                    locale: locale
                ))
    }
}

enum CoachEveningSummaryPolicy {
    /// Coach surface for evening recap (Your day + AI + feeling).
    static let isCoachSurfaceEnabled = true

    /// UserDefaults override (DEBUG). `true` = production once-per-day; unset/`false` = repeat AI calls.
    static let oncePerDayOverrideKey = "weekfit.coach.eveningSummary.oncePerDay"

    /// Auto path: after 20:00 local; at most one AI summary per local day.
    /// First successful answer is cached and reused — fingerprint / tab re-entry must not regenerate.
    /// DEBUG defaults to unrestricted so local prompt/locale iteration can re-hit the service.
    static var enforcesOncePerDayAndEveningWindow: Bool {
        #if DEBUG
        if UserDefaults.standard.object(forKey: oncePerDayOverrideKey) != nil {
            return UserDefaults.standard.bool(forKey: oncePerDayOverrideKey)
        }
        return false
        #else
        true
        #endif
    }

    static var allowsManualRefreshAnytime: Bool { !enforcesOncePerDayAndEveningWindow }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
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

        let sentences = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?。！？"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let parts = sentences.isEmpty ? [trimmed] : sentences
        return parts.allSatisfy { sentenceMatchesRequestedLocale($0, locale: locale) }
    }

    /// Keep only sentences that match the requested locale (drops English leaks under PL/RU/…).
    static func filteringToRequestedLocale(_ text: String, locale: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard nlLanguage(for: locale) != nil else { return trimmed }

        let sentences = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?。！？"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !sentences.isEmpty else {
            return sentenceMatchesRequestedLocale(trimmed, locale: locale) ? trimmed : ""
        }

        let kept = sentences.filter { sentenceMatchesRequestedLocale($0, locale: locale) }
        guard !kept.isEmpty else { return "" }
        var joined = kept.joined(separator: ". ")
        if !joined.hasSuffix(".") && !joined.hasSuffix("!") && !joined.hasSuffix("?") {
            joined += "."
        }
        return joined
    }

    private static func sentenceMatchesRequestedLocale(_ text: String, locale: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Short fragments (names, numbers) are too ambiguous to reject.
        guard trimmed.count >= 24 else { return true }
        guard let expected = nlLanguage(for: locale) else { return true }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
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
        let sentences = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?。！？"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if sentences.isEmpty { return text }
        let kept = Array(sentences.prefix(max(1, maxSentences)))
        var joined = kept.joined(separator: ". ")
        if !joined.hasSuffix(".") && !joined.hasSuffix("!") && !joined.hasSuffix("?") {
            joined += "."
        }
        return joined
    }
}
