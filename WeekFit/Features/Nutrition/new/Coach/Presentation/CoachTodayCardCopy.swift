import Foundation

/// Today Coach card should explain *why this plan*, not restating Up Next.
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
        let rawMessage = presentation.showsLimitedConfidenceBadge
            ? presentation.recommendation
            : presentation.todayMessage

        let title = resolvedTitle(
            raw: presentation.todayTitle,
            presentation: presentation,
            nextActivityTitle: next
        )
        let message = resolvedMessage(
            raw: rawMessage,
            title: title,
            presentation: presentation,
            nextActivityTitle: next
        )
        return Display(title: title, message: message)
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
        raw: String,
        presentation: CoachUIPresentation,
        nextActivityTitle: String
    ) -> String {
        if nextActivityTitle.isEmpty || !echoesActivity(raw, activityTitle: nextActivityTitle) {
            return raw
        }

        let candidates = [
            whyClause(from: presentation.assessment, nextActivityTitle: nextActivityTitle),
            presentation.whyRows
                .map(\.title)
                .first { !echoesActivity($0, activityTitle: nextActivityTitle) },
            whyTitle(for: presentation.scenario)
        ]

        let picked = candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { candidate in
                !candidate.isEmpty && candidate.count <= 26
            } ?? whyTitle(for: presentation.scenario)

        return concise(picked, maxLength: 26)
    }

    private static func resolvedMessage(
        raw: String,
        title: String,
        presentation: CoachUIPresentation,
        nextActivityTitle: String
    ) -> String {
        let duplicatesTitle = CoachUIPresentationDedup.isNearDuplicate(raw, title)
        let echoesNext = !nextActivityTitle.isEmpty && echoesActivity(raw, activityTitle: nextActivityTitle)
        if !raw.isEmpty, !duplicatesTitle, !echoesNext {
            return raw
        }

        let candidates = [
            presentation.recommendation,
            presentation.assessment,
            presentation.avoid
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
            return concise(picked, maxLength: 72)
        }

        return raw
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
            return WeekFitTrilingual("Today's plan", "План на сегодня", "今日计划")
        }
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
