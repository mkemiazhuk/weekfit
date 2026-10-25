import Foundation

/// Exact and `\(…)` template lookup for hardcoded English coach copy.
enum CoachStringOverrideResolver {

    static func resolved(english: String, table: [String: String], cacheKey: String) -> String? {
        if let exact = table[english], !exact.isEmpty {
            return exact
        }
        let trimmed = english.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != english, let exact = table[trimmed], !exact.isEmpty {
            return exact
        }
        return resolveTemplate(english: english, table: table, cacheKey: cacheKey)
    }

    private struct TemplateRule {
        let pattern: NSRegularExpression
        let template: String
        let captureCount: Int
    }

    private static var rulesByTable: [String: [TemplateRule]] = [:]

    private static func rules(for table: [String: String], cacheKey: String) -> [TemplateRule] {
        if let cached = rulesByTable[cacheKey] {
            return cached
        }
        var rules: [TemplateRule] = []
        rules.reserveCapacity(160)
        for (english, translated) in table where english.contains("\\(") {
            let parts = splitInterpolations(english)
            let captureCount = parts.filter(\.isInterpolation).count
            guard captureCount > 0 else { continue }
            let literalChars = parts.reduce(into: 0) { count, part in
                if case .literal(let text) = part {
                    count += text.filter { !$0.isWhitespace }.count
                }
            }
            guard literalChars >= 10 else { continue }
            guard let pattern = makePattern(from: parts) else { continue }
            rules.append(TemplateRule(pattern: pattern, template: translated, captureCount: captureCount))
        }
        rules.sort { $0.pattern.pattern.count > $1.pattern.pattern.count }
        rulesByTable[cacheKey] = rules
        return rules
    }

    private static func resolveTemplate(english: String, table: [String: String], cacheKey: String) -> String? {
        let range = NSRange(english.startIndex..<english.endIndex, in: english)
        for rule in rules(for: table, cacheKey: cacheKey) {
            guard let match = rule.pattern.firstMatch(in: english, options: [], range: range) else {
                continue
            }
            var captures: [String] = []
            captures.reserveCapacity(rule.captureCount)
            for index in 1...rule.captureCount {
                guard let captureRange = Range(match.range(at: index), in: english) else { break }
                captures.append(String(english[captureRange]))
            }
            guard captures.count == rule.captureCount else { continue }
            return fillTemplate(rule.template, captures: captures)
        }
        return nil
    }

    private static func fillTemplate(_ template: String, captures: [String]) -> String {
        var captureIndex = 0
        var out = ""
        for part in splitInterpolations(template) {
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

    private enum Part {
        case literal(String)
        case interpolation

        var isInterpolation: Bool {
            if case .interpolation = self { return true }
            return false
        }
    }

    private static func splitInterpolations(_ template: String) -> [Part] {
        var parts: [Part] = []
        var literal = ""
        var index = template.startIndex
        while index < template.endIndex {
            let next = template.index(after: index)
            if template[index] == "\\", next < template.endIndex {
                var paren = next
                while paren < template.endIndex, template[paren].isWhitespace {
                    paren = template.index(after: paren)
                }
                if paren < template.endIndex, template[paren] == "(" {
                    if !literal.isEmpty {
                        parts.append(.literal(literal))
                        literal = ""
                    }
                    var cursor = template.index(after: paren)
                    var depth = 1
                    while cursor < template.endIndex, depth > 0 {
                        let character = template[cursor]
                        if character == "(" { depth += 1 }
                        else if character == ")" { depth -= 1 }
                        cursor = template.index(after: cursor)
                    }
                    parts.append(.interpolation)
                    index = cursor
                    continue
                }
            }
            literal.append(template[index])
            index = next
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

enum CoachExtraLanguageTables {
    static func entries(for language: AppLanguage) -> [String: String] {
        switch language {
        case .french: return french
        case .polish: return polish
        case .spanish: return spanish
        case .german: return german
        case .japanese: return japanese
        case .italian: return italian
        case .korean: return korean
        default: return [:]
        }
    }
}
