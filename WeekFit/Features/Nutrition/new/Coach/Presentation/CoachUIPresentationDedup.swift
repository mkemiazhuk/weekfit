import Foundation

/// Removes near-duplicate coach hero lines before CoachView renders adjacent blocks.
enum CoachUIPresentationDedup {

    struct HeroCopy: Equatable {
        var coachTitle: String
        var assessment: String
        var recommendation: String
        var avoid: String
        var nextAction: String
    }

    static func compact(_ copy: HeroCopy) -> HeroCopy {
        var result = copy
        var prior: [String] = []

        result.assessment = deduped(result.assessment, prior: &prior)
        result.recommendation = deduped(result.recommendation, prior: &prior)
        result.avoid = deduped(result.avoid, prior: &prior)
        result.nextAction = deduped(result.nextAction, prior: &prior)

        return result
    }

    static func isNearDuplicate(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalize(lhs)
        let right = normalize(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }

        if left == right { return true }

        let shorter = left.count <= right.count ? left : right
        let longer = left.count <= right.count ? right : left
        if shorter.count >= 24, longer.contains(shorter) { return true }

        return !significantPhrases(in: left).isDisjoint(with: significantPhrases(in: right))
    }

    private static func deduped(_ text: String, prior: inout [String]) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if prior.contains(where: { isNearDuplicate(trimmed, $0) }) {
            return ""
        }

        prior.append(trimmed)
        return trimmed
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
            .joined(separator: " ")
    }

    private static func significantPhrases(in text: String) -> Set<String> {
        let words = normalize(text).split(separator: " ").map(String.init)
        guard words.count >= 3 else { return [] }

        var phrases: Set<String> = []
        for index in 0...(words.count - 3) {
            phrases.insert(words[index...(index + 2)].joined(separator: " "))
        }
        return phrases
    }
}
