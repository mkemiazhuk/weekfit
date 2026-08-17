import Foundation

/// Single text-fitting engine for all WeekFit widget copy.
///
/// Guarantees (text-agnostic):
/// - never emits user-visible ellipsis
/// - never cuts mid-word / mid-token
/// - never leaves dangling separators (`—`, `-`, `·`, commas, etc.)
/// - if nothing safe fits the budget, returns a known-good fallback
public enum WeekFitWidgetTextFitting {
    public enum Slot: Equatable, Sendable {
        case smallState
        case smallHero
        case smallNextTitle
        case smallNextHeader
        case mediumHeadline
        case mediumDetail
        case mediumNextTitle
        case mediumNextMeta

        public var limit: Int {
            switch self {
            case .smallState: return 16
            case .smallHero: return 18
            case .smallNextTitle: return 12
            case .smallNextHeader: return 14
            case .mediumHeadline: return 26
            case .mediumDetail: return 40
            case .mediumNextTitle: return 14
            case .mediumNextMeta: return 16
            }
        }
    }

    /// Fits arbitrary upstream copy into a layout slot.
    public static func fit(_ raw: String, to slot: Slot, fallback: String) -> String {
        fit(raw, limit: slot.limit, fallback: fallback)
    }

    /// Fits arbitrary upstream copy into an explicit character budget.
    public static func fit(_ raw: String, limit: Int, fallback: String) -> String {
        let safeFallback = finalize(fallback, limit: limit) ?? shortenedFallback(fallback, limit: limit)

        let normalized = normalize(raw)
        guard !normalized.isEmpty else { return safeFallback }

        // 1) Whole string.
        if let whole = finalize(normalized, limit: limit) {
            return whole
        }

        // 2) Prefer the longest complete segment that still fits.
        //    Segments come from punctuation / dash / newline breaks — language-agnostic.
        let parts = segments(from: normalized)
            .compactMap { finalize($0, limit: limit) }
            .sorted { $0.count > $1.count }
        if let best = parts.first {
            return best
        }

        // 3) Pack whole words only.
        if let packed = packWords(normalized, limit: limit) {
            return packed
        }

        return safeFallback
    }

    public static func containsEllipsis(_ text: String) -> Bool {
        text.contains("…") || text.contains("...")
    }

    public static func isDisplaySafe(_ text: String, limit: Int) -> Bool {
        guard !text.isEmpty else { return false }
        guard text.count <= limit else { return false }
        guard !containsEllipsis(text) else { return false }
        guard finish(text) == text else { return false }
        return true
    }

    // MARK: - Pipeline

    /// Collapse whitespace, strip ellipsis glyphs already present in source copy.
    private static func normalize(_ raw: String) -> String {
        let stripped = raw
            .replacingOccurrences(of: "…", with: " ")
            .replacingOccurrences(of: "...", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")

        let scalars = stripped.split(whereSeparator: { $0.isNewline || $0.isWhitespace })
        return scalars.joined(separator: " ")
    }

    /// Trim and strip dangling separators. Nil if empty or still over limit.
    private static func finalize(_ text: String, limit: Int) -> String? {
        let value = finish(text)
        guard !value.isEmpty, value.count <= limit, !containsEllipsis(value) else { return nil }
        return value
    }

    private static func finish(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Leading separators (e.g. fragment after a dash split).
        let edge = CharacterSet(charactersIn: "-—–·.,;:/|")
        while let first = value.unicodeScalars.first, edge.contains(first) {
            value = String(value.unicodeScalars.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        while let last = value.unicodeScalars.last, edge.contains(last) {
            value = String(value.unicodeScalars.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }

    /// Split into candidate phrases on hard breaks. Order preserved.
    private static func segments(from text: String) -> [String] {
        // Treat dashes / middots / punctuation as hard boundaries — not content-specific.
        let pattern = #"[.!?…;:\n]+|[—–−]|[ \t]*-[ \t]*|[·•|/]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text]
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var result: [String] = []
        var last = text.startIndex

        for match in regex.matches(in: text, range: range) {
            guard let matchRange = Range(match.range, in: text) else { continue }
            let piece = String(text[last..<matchRange.lowerBound])
            let cleaned = finish(piece)
            if !cleaned.isEmpty { result.append(cleaned) }
            last = matchRange.upperBound
        }
        let tail = finish(String(text[last...]))
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    private static func packWords(_ text: String, limit: Int) -> String? {
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        var phrase = ""
        for token in tokens {
            if isSeparatorToken(token) {
                // Hard stop: never continue past a dash/bullet mid-pack.
                break
            }
            let candidate = phrase.isEmpty ? token : phrase + " " + token
            let finished = finish(candidate)
            if finished.count > limit { break }
            phrase = finished
        }
        guard !phrase.isEmpty else { return nil }
        // One very long token that exceeds the budget → reject (no mid-word cut).
        if phrase.split(whereSeparator: \.isWhitespace).count == 1, phrase.count > limit {
            return nil
        }
        return finalize(phrase, limit: limit)
    }

    private static func isSeparatorToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        let separators: Set<String> = ["-", "—", "–", "−", "·", "•", "|", "/", ":", ";"]
        return separators.contains(trimmed)
    }

    private static func shortenedFallback(_ fallback: String, limit: Int) -> String {
        if let packed = packWords(normalize(fallback), limit: limit) {
            return packed
        }
        // Last resort: empty string is safer than a clipped fragment.
        return ""
    }
}
