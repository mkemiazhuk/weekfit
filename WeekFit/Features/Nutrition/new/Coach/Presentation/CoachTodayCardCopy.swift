import Foundation

/// Today’s Focus teaser — must stay consistent with the Coach tab hero.
/// Title mirrors `coachTitle`; message mirrors the Coach lead (`assessment`),
/// with light fallbacks. Still avoids restating the Up Next activity name.
enum CoachTodayCardCopy {

    struct Display: Equatable {
        let title: String
        let message: String
    }

    static func display(
        from presentation: CoachUIPresentation,
        nextActivityTitle: String?
    ) -> Display {
        let next = nextActivityTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = resolvedTitle(presentation: presentation, nextActivityTitle: next)
        let message = resolvedMessage(
            presentation: presentation,
            title: title,
            nextActivityTitle: next
        )
        return Display(title: title, message: message)
    }

    /// Full personal recommendation for the compact Today card.
    /// Returns nil when the presentation has no headline of its own.
    static func focusCard(from presentation: CoachUIPresentation) -> Display? {
        func trim(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let title = [presentation.coachTitle, presentation.todayTitle]
            .map(trim)
            .first { !$0.isEmpty }
        guard let title else { return nil }

        let message = [
            presentation.assessment,
            presentation.todayMessage,
            presentation.recommendation,
            presentation.nextAction
        ]
        .map(trim)
        .first { !$0.isEmpty && !CoachUIPresentationDedup.isNearDuplicate($0, title) }

        if let message {
            return Display(title: title, message: message)
        }

        let stance = whyTitle(for: presentation.scenario)
        if stance != genericStance, !CoachUIPresentationDedup.isNearDuplicate(stance, title) {
            return Display(title: title, message: stance)
        }
        return Display(title: title, message: "")
    }

    static func echoesActivity(_ text: String, activityTitle: String) -> Bool {
        let hay = normalize(text)
        let event = normalize(activityTitle)
        guard !hay.isEmpty, !event.isEmpty else { return false }
        if hay == event { return true }
        if event.count >= 4, hay.contains(event) { return true }
        if hay.count >= 4, event.contains(hay) { return true }

        let eventTokens = tokens(in: event)
        let hayTokens = tokens(in: hay)
        let overlapping = eventTokens.intersection(hayTokens).filter { $0.count >= 4 }
        return !overlapping.isEmpty
    }

    // MARK: - Resolve

    private static func resolvedTitle(
        presentation: CoachUIPresentation,
        nextActivityTitle: String
    ) -> String {
        // Prefer the same headline the Coach tab shows.
        let coachTitle = presentation.coachTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let todayTitle = presentation.todayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferred = !coachTitle.isEmpty ? coachTitle : todayTitle

        if preferred.isEmpty {
            return whyTitle(for: presentation.scenario)
        }

        if nextActivityTitle.isEmpty || !echoesActivity(preferred, activityTitle: nextActivityTitle) {
            return concise(preferred, maxLength: 28)
        }

        // Title would just restate Up Next — fall back to a why stance, then assessment clause.
        let candidates = [
            presentation.todayTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            whyClause(from: presentation.assessment, nextActivityTitle: nextActivityTitle),
            presentation.whyRows
                .map(\.title)
                .first { !echoesActivity($0, activityTitle: nextActivityTitle) },
            whyTitle(for: presentation.scenario)
        ]

        let picked = candidates
            .compactMap { value -> String? in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                guard !echoesActivity(trimmed, activityTitle: nextActivityTitle) else { return nil }
                return trimmed
            }
            .first { $0.count <= 28 } ?? whyTitle(for: presentation.scenario)

        return concise(picked, maxLength: 28)
    }

    private static func resolvedMessage(
        presentation: CoachUIPresentation,
        title: String,
        nextActivityTitle: String
    ) -> String {
        // Same lead line the Coach tab shows under the headline.
        let candidates = [
            presentation.assessment,
            presentation.todayMessage,
            presentation.recommendation,
            presentation.nextAction
        ]

        if let picked = candidates.first(where: { candidate in
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            if CoachUIPresentationDedup.isNearDuplicate(trimmed, title) { return false }
            if !nextActivityTitle.isEmpty, echoesActivity(trimmed, activityTitle: nextActivityTitle) {
                return false
            }
            return true
        }) {
            return concise(picked, maxLength: 90)
        }

        return ""
    }

    /// Prefer the clause after a dash — usually the reason, not the event name.
    private static func whyClause(from text: String, nextActivityTitle: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let separators = CharacterSet(charactersIn: "—–-·|")
        let parts = trimmed
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let preferred = parts.reversed().first { part in
            part.count >= 12 && !echoesActivity(part, activityTitle: nextActivityTitle)
        }
        if let preferred {
            return sentenceCased(preferred)
        }

        if !echoesActivity(trimmed, activityTitle: nextActivityTitle) {
            return trimmed
        }
        return nil
    }

    private static func whyTitle(for scenario: CoachScenarioKey) -> String {
        switch scenario {
        case .walkLightDay, .walkAfterHeavyLoad:
            return WeekFitTrilingual("Keep it light", "Держите легко", "保持轻松")
        case .walkRecoveryAction:
            return WeekFitTrilingual("Ease the legs", "Разгрузить ноги", "放松双腿")
        case .walkEveningWindDown:
            return WeekFitTrilingual("Wind down", "Сбавьте обороты", "放慢节奏")
        case .protectTomorrowFresh, .tomorrowProtection:
            return WeekFitTrilingual("Save it for tomorrow", "Запас на завтра", "留给明天")
        case .recoveryAfterHeavyYesterday:
            return WeekFitTrilingual("Recovery day", "Спокойный день", "恢复日")
        case .activeStrength, .duringStrength:
            return WeekFitTrilingual("Leave something", "С запасом", "留点余力")
        case .activeEndurance, .duringEndurance:
            return WeekFitTrilingual("Hold your pace", "Держите ритм", "保持节奏")
        case .saunaPreparation, .saunaActive:
            return WeekFitTrilingual("Don't overheat", "Не перегревайтесь", "别过热")
        case .activeRecovery, .duringRecovery:
            return WeekFitTrilingual("Soft reset", "Мягкий сброс", "轻柔放松")
        default:
            return genericStance
        }
    }

    private static var genericStance: String {
        WeekFitTrilingual("Today's plan", "План на сегодня", "今日计划")
    }

    // MARK: - Text

    private static func tokens(in text: String) -> Set<String> {
        Set(text.split(separator: " ").map(String.init).filter { $0.count >= 4 })
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func sentenceCased(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private static func concise(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
