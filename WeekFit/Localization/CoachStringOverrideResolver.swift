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
        if let template = resolveTemplate(english: english, table: table, cacheKey: cacheKey) {
            return template
        }
        // `mergeOpener` joins known sentences with a space; translate pieces when the full
        // join is missing from the table (e.g. morning recovery + calendar line).
        return resolvedBySentencePieces(english: trimmed, table: table, cacheKey: cacheKey)
    }

    /// Translates space-joined coach sentences when each piece exists in the table.
    static func resolvedBySentencePieces(
        english: String,
        table: [String: String],
        cacheKey: String
    ) -> String? {
        let pieces = sentencePieces(english)
        guard pieces.count >= 2 else { return nil }
        var translated: [String] = []
        translated.reserveCapacity(pieces.count)
        for piece in pieces {
            if let exact = table[piece], !exact.isEmpty {
                translated.append(exact)
                continue
            }
            if let template = resolveTemplate(english: piece, table: table, cacheKey: cacheKey),
               !template.isEmpty {
                translated.append(template)
                continue
            }
            return nil
        }
        return translated.joined(separator: " ")
    }

    /// Splits on `.!?` sentence ends while keeping decimal points like `20.5` intact.
    static func sentencePieces(_ text: String) -> [String] {
        let terminators = CharacterSet(charactersIn: ".!?")
        var pieces: [String] = []
        var current = ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if let scalar = ch.unicodeScalars.first, terminators.contains(scalar) {
                let prevIsDigit = i > 0 && chars[i - 1].isNumber
                let nextIsDigit = i + 1 < chars.count && chars[i + 1].isNumber
                if ch == "." && prevIsDigit && nextIsDigit {
                    current.append(ch)
                    i += 1
                    continue
                }
                current.append(ch)
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    pieces.append(trimmed)
                }
                current = ""
                i += 1
                while i < chars.count && chars[i].isWhitespace {
                    i += 1
                }
                continue
            }
            current.append(ch)
            i += 1
        }
        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            pieces.append(trailing)
        }
        return pieces
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
