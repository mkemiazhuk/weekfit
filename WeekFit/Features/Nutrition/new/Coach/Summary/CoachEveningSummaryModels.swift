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

    /// Auto path: after 20:00 local; regenerate when activity fingerprint changes.
    /// Manual Get/Refresh is not the primary UX anymore.
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

    /// Prefer `now` (concrete evening step); fall back to `today` takeaway.
    static func displayCommentary(from summary: CoachEveningSummary) -> String {
        let now = summary.now.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !now.isEmpty { return clampCommentary(now) }
        let today = summary.today.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clampCommentary(today)
    }

    private static func clampCommentary(_ text: String) -> String {
        let sentences = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?。！？"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if sentences.isEmpty { return text }
        let kept = Array(sentences.prefix(2))
        var joined = kept.joined(separator: ". ")
        if !joined.hasSuffix(".") && !joined.hasSuffix("!") && !joined.hasSuffix("?") {
            joined += "."
        }
        return joined
    }
}
