import Foundation

/// English → Simplified Chinese overrides for hardcoded `CoachBilingualText` copy.
/// Generated / maintained by `scripts/generate_coach_chinese_overrides.py`.
/// Missing keys fall back to the bilingual `chinese` field (then English).
///
/// Keys that still contain Swift interpolation markers (`\(…)`) are matched as
/// templates against runtime-interpolated English, then captures are filled into
/// the Chinese template.
enum CoachChineseOverrides {
    static let table: [String: String] = CoachChineseOverridesTable.entries

    /// Exact table hit, or template match for interpolated English.
    static func resolved(english: String) -> String? {
        if let exact = table[english], !exact.isEmpty {
            return exact
        }
        let trimmed = english.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != english, let exact = table[trimmed], !exact.isEmpty {
            return exact
        }
        return resolveTemplate(english: english)
    }

    // MARK: - Template matching

    private struct TemplateRule {
        let pattern: NSRegularExpression
        let chineseTemplate: String
        let captureCount: Int
    }

    private static let templateRules: [TemplateRule] = {
        var rules: [TemplateRule] = []
        rules.reserveCapacity(160)
        for (key, chinese) in table where key.contains("\\(") {
            let enParts = splitInterpolations(key)
            let captureCount = enParts.filter(\.isInterpolation).count
            guard captureCount > 0 else { continue }
            // Skip near-empty templates like "\(a) \(b) \(c)" — they match
            // almost any English string and produce garbage Chinese.
            let literalChars = enParts.reduce(into: 0) { count, part in
                if case .literal(let text) = part {
                    count += text.filter { !$0.isWhitespace }.count
                }
            }
            guard literalChars >= 10 else { continue }
            guard let pattern = makePattern(from: enParts) else { continue }
            rules.append(
                TemplateRule(
                    pattern: pattern,
                    chineseTemplate: chinese,
                    captureCount: captureCount
                )
            )
        }
        return rules.sorted { $0.pattern.pattern.count > $1.pattern.pattern.count }
    }()

    private static func resolveTemplate(english: String) -> String? {
        let range = NSRange(english.startIndex..<english.endIndex, in: english)
        for rule in templateRules {
            guard let match = rule.pattern.firstMatch(in: english, options: [], range: range) else {
                continue
            }
            var captures: [String] = []
            captures.reserveCapacity(rule.captureCount)
            for i in 1...rule.captureCount {
                guard let r = Range(match.range(at: i), in: english) else { break }
                captures.append(String(english[r]))
            }
            guard captures.count == rule.captureCount else { continue }
            return fillTemplate(rule.chineseTemplate, captures: captures)
        }
        return nil
    }

    /// Replaces each `\(…)` in order with the corresponding English capture.
    /// If Chinese has no placeholders, returns the static translation.
    private static func fillTemplate(_ template: String, captures: [String]) -> String {
        let parts = splitInterpolations(template)
        var captureIndex = 0
        var out = ""
        for part in parts {
            switch part {
            case .literal(let text):
                out += text
            case .interpolation:
                if captureIndex < captures.count {
                    out += captures[captureIndex]
                    captureIndex += 1
                }
            }
        }
        return out
    }

    // MARK: - Parsing helpers

    private enum Part {
        case literal(String)
        case interpolation

        var isInterpolation: Bool {
            if case .interpolation = self { return true }
            return false
        }
    }

    /// Splits `…\(expr)…` (runtime form of Swift `\\(expr)` table keys).
    /// Also tolerates MT artifacts like `\ (expr)` / `\ (expr with spaces)`.
    private static func splitInterpolations(_ template: String) -> [Part] {
        var parts: [Part] = []
        var literal = ""
        var i = template.startIndex
        while i < template.endIndex {
            let next = template.index(after: i)
            if template[i] == "\\", next < template.endIndex {
                var paren = next
                while paren < template.endIndex, template[paren].isWhitespace {
                    paren = template.index(after: paren)
                }
                if paren < template.endIndex, template[paren] == "(" {
                    if !literal.isEmpty {
                        parts.append(.literal(literal))
                        literal = ""
                    }
                    var j = template.index(after: paren) // after '('
                    var depth = 1
                    while j < template.endIndex, depth > 0 {
                        let c = template[j]
                        if c == "(" { depth += 1 }
                        else if c == ")" { depth -= 1 }
                        j = template.index(after: j)
                    }
                    parts.append(.interpolation)
                    i = j
                    continue
                }
            }
            literal.append(template[i])
            i = next
        }
        if !literal.isEmpty {
            parts.append(.literal(literal))
        }
        return parts
    }

    private static func makePattern(from parts: [Part]) -> NSRegularExpression? {
        var pattern = "^"
        for part in parts {
            switch part {
            case .literal(let text):
                pattern += NSRegularExpression.escapedPattern(for: text)
            case .interpolation:
                pattern += "(.+?)"
            }
        }
        pattern += "$"
        return try? NSRegularExpression(pattern: pattern, options: [])
    }
}
