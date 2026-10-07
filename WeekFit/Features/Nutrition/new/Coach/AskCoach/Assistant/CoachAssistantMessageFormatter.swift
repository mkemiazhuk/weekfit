import Foundation

/// Presentation-only formatting for Assistant coach messages.
/// Does not invent facts — only structures already-chosen copy for scanning.
enum CoachAssistantMessageFormatter {

    /// Joins short parts compactly. Empty parts are dropped.
    /// Uses a blank paragraph only when parts are both substantial.
    static func compose(
        _ parts: CoachBilingualText...
    ) -> CoachBilingualText {
        compose(Array(parts))
    }

    static func compose(_ parts: [CoachBilingualText]) -> CoachBilingualText {
        let english = joinCompact(
            parts.map { $0.english.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
        let russian = joinCompact(
            parts.map { $0.russian.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        )
        let chinese = joinCompact(
            parts.map {
                let zh = $0.chinese.trimmingCharacters(in: .whitespacesAndNewlines)
                let source = $0.english.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !source.isEmpty else { return "" }
                if !zh.isEmpty, zh != $0.english { return zh }
                return CoachChineseOverrides.resolved(english: source) ?? zh
            }.filter { !$0.isEmpty }
        )
        return CoachBilingualText(english: english, russian: russian, chinese: chinese)
    }

    /// Softens long single-line coach replies for display without changing words.
    /// Short ack + question stay on one compact block — no automatic blank line.
    static func presentForDisplay(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if trimmed.contains("\n\n") {
            // Collapse blank lines inside short bubbles.
            let chunks = trimmed
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if chunks.count <= 2, chunks.allSatisfy({ $0.count <= 72 }) {
                return chunks.joined(separator: " ")
            }
            return chunks.joined(separator: "\n\n")
        }
        return trimmed
    }

    private static func joinCompact(_ parts: [String]) -> String {
        guard parts.count > 1 else { return parts.first ?? "" }
        let allShort = parts.allSatisfy { $0.count <= 72 }
        if allShort, parts.count <= 2 {
            return parts.joined(separator: " ")
        }
        return parts.joined(separator: "\n\n")
    }
}
