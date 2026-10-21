import Foundation

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
        return day == input.day && locale == input.locale && source == "ai"
            && !headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && headline.count <= 120 && limitations.count <= 6
            && [today, now, tomorrow].allSatisfy {
                !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && $0.text.count <= 700 && $0.evidenceIds.allSatisfy(ids.contains)
            }
    }
}

enum CoachEveningSummaryPolicy {
    /// Coach surface for evening recap (Your day + AI + feeling).
    static let isCoachSurfaceEnabled = true

    /// Auto path: after 20:00 local; at most one AI summary per local day.
    /// First successful answer is cached and reused — fingerprint / tab re-entry must not regenerate.
    static let enforcesOncePerDayAndEveningWindow = true

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
        return clampCommentary(parts.joined(separator: " "), maxSentences: 3)
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
