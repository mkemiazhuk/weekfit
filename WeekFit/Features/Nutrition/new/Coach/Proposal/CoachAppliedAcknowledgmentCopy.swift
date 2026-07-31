import Foundation

/// Post-Apply Coach copy: execution-assistant tone from accepted changes only.
enum CoachAppliedAcknowledgmentCopy {

    /// Provenance terminal outcomes that mean the adjustment is no longer "on the plan".
    static let clearedTerminalOutcomes: Set<String> = ["deleted", "ignored"]

    struct Summary: Equatable, Sendable {
        let acceptedKinds: [CoachChangeKind]
        let guidanceOnly: Bool

        var hasMutations: Bool {
            acceptedKinds.contains { $0 != .guidanceOnly }
        }
    }

    /// Resolves whether Coach should stay in post-Apply execution tone,
    /// acknowledge a cleared plan, or fall through to regular copy.
    static func planAdjustmentMode(forDayKey dayKey: String) -> CoachPlanAdjustmentMode {
        let adjustments = CoachAdjustmentProvenanceStore.adjustments(forDayKey: dayKey)
            .filter { $0.kind != .guidanceOnly }
        guard !adjustments.isEmpty else {
            // Applied with guidance-only / legacy empty provenance — keep execution tone.
            return .appliedExecuting
        }
        let stillActive = adjustments.contains { adjustment in
            guard let outcome = adjustment.terminalOutcome?.lowercased() else { return true }
            return !clearedTerminalOutcomes.contains(outcome)
        }
        return stillActive ? .appliedExecuting : .clearedAfterApply
    }

    static func summary(
        proposal: MorningPlanProposal?,
        dayKey: String
    ) -> Summary {
        let history = CoachDecisionHistoryStore.entries(forDayKey: dayKey)
            .filter { $0.accepted && ($0.applyOutcome == .applied || $0.applyOutcome == .skippedAlreadyMatched || $0.applyOutcome == .ignoredGuidanceOnly) }

        let kindsFromHistory = history.map(\.kind)
        if !kindsFromHistory.isEmpty {
            let unique = uniqueKinds(kindsFromHistory)
            let guidanceOnly = unique.allSatisfy { $0 == .guidanceOnly }
            return Summary(acceptedKinds: unique, guidanceOnly: guidanceOnly)
        }

        let provenanceKinds = CoachAdjustmentProvenanceStore.adjustments(forDayKey: dayKey).map(\.kind)
        if !provenanceKinds.isEmpty {
            return Summary(acceptedKinds: uniqueKinds(provenanceKinds), guidanceOnly: false)
        }

        let selected = proposal?.changes.filter(\.isSelected).map(\.kind) ?? []
        let unique = uniqueKinds(selected)
        return Summary(
            acceptedKinds: unique,
            guidanceOnly: !unique.isEmpty && unique.allSatisfy { $0 == .guidanceOnly }
        )
    }

    static func assessment(for summary: Summary) -> CoachBilingualText {
        .en(
            "Today’s plan is ready.",
            "План на сегодня готов."
        )
    }

    static func recommendation(for summary: Summary) -> CoachBilingualText {
        if summary.guidanceOnly || !summary.hasMutations {
            return .en(
                "Keep the guidance in mind and I’ll help you stay on track.",
                "Держите эти подсказки в уме — я помогу оставаться в ритме."
            )
        }

        let phrase = mutationPhrase(for: summary.acceptedKinds)
        return .en(
            "\(phrase) I’ll help you stay on track.",
            "\(phraseRU(for: summary.acceptedKinds)) Я помогу оставаться в ритме."
        )
    }

    static func avoid(for summary: Summary) -> CoachBilingualText {
        .en(
            "No need to rethink the morning adjustments — focus on executing what you chose.",
            "Не нужно снова пересматривать утренние правки — сосредоточьтесь на выбранном плане."
        )
    }

    static func nextAction(for summary: Summary) -> CoachBilingualText {
        .en(
            "When the next session starts, check in how you feel and stay steady.",
            "Когда начнётся следующая сессия, оцените самочувствие и двигайтесь спокойно."
        )
    }

    static func pack(for summary: Summary, scenario: CoachScenarioKey) -> CoachCopyPack {
        CoachCopyPack(
            scenario: scenario,
            assessment: .single(assessment(for: summary)),
            recommendation: .single(recommendation(for: summary)),
            avoid: .single(avoid(for: summary)),
            nextAction: .single(nextAction(for: summary)),
            supportingSignals: .single(.en(
                "Morning adjustments are already on the plan.",
                "Утренние правки уже в плане."
            )),
            warningLayer: nil
        )
    }

    /// Soft acknowledgment when the user removes coach-placed morning adjustments.
    static func clearedPlanSupportingSignal() -> CoachBilingualText {
        .en(
            "You cleared the morning adjustment — that’s fine. Here’s what still matters today.",
            "Вы убрали утреннюю правку — всё в порядке. Вот что сейчас важнее."
        )
    }

    /// Protective / dial-back scenarios that should not re-offer unresolved plan changes.
    static func shouldOverrideProtectiveCopy(scenario: CoachScenarioKey) -> Bool {
        switch scenario {
        case .lowRecoveryPrep,
             .protectTomorrowFresh,
             .recoveryAfterHeavyYesterday,
             .tomorrowProtection,
             .walkAfterHeavyLoad,
             .walkRecoveryAction,
             .morningReadiness:
            return true
        default:
            return false
        }
    }

    private static func uniqueKinds(_ kinds: [CoachChangeKind]) -> [CoachChangeKind] {
        var seen = Set<CoachChangeKind>()
        var ordered: [CoachChangeKind] = []
        for kind in kinds where kind != .guidanceOnly || kinds.allSatisfy({ $0 == .guidanceOnly }) {
            if seen.insert(kind).inserted {
                ordered.append(kind)
            }
        }
        if ordered.isEmpty {
            return Array(Set(kinds))
        }
        return ordered
    }

    private static func mutationPhrase(for kinds: [CoachChangeKind]) -> String {
        let mutating = kinds.filter { $0 != .guidanceOnly }
        let hasShorten = mutating.contains(.modifyDuration)
        let hasMove = mutating.contains(.moveActivity)
        let hasSkip = mutating.contains(.skipActivity)
        let hasWalk = mutating.contains(.createRecoveryWalk)
            || mutating.contains(.createPlannedActivity)
        let hasMeal = mutating.contains(.createMealFromLibrary)

        var parts: [String] = []
        if hasShorten { parts.append("shortened a workout") }
        if hasMove { parts.append("moved a session") }
        if hasSkip { parts.append("skipped a session") }
        if hasWalk { parts.append("added movement") }
        if hasMeal { parts.append("added a meal") }

        guard !parts.isEmpty else {
            return "Your chosen adjustments are on the plan."
        }
        if parts.count == 1 {
            return "I \(parts[0])."
        }
        if parts.count == 2 {
            return "I \(parts[0]) and \(parts[1])."
        }
        let head = parts.dropLast().joined(separator: ", ")
        return "I \(head), and \(parts.last!)."
    }

    private static func phraseRU(for kinds: [CoachChangeKind]) -> String {
        let mutating = kinds.filter { $0 != .guidanceOnly }
        let hasShorten = mutating.contains(.modifyDuration)
        let hasMove = mutating.contains(.moveActivity)
        let hasSkip = mutating.contains(.skipActivity)
        let hasWalk = mutating.contains(.createRecoveryWalk)
            || mutating.contains(.createPlannedActivity)
        let hasMeal = mutating.contains(.createMealFromLibrary)

        var parts: [String] = []
        if hasShorten { parts.append("сократил тренировку") }
        if hasMove { parts.append("перенёс сессию") }
        if hasSkip { parts.append("пропустил сессию") }
        if hasWalk { parts.append("добавил движение") }
        if hasMeal { parts.append("добавил приём пищи") }

        guard !parts.isEmpty else {
            return "Выбранные правки уже в плане."
        }
        if parts.count == 1 {
            return "Я \(parts[0])."
        }
        if parts.count == 2 {
            return "Я \(parts[0]) и \(parts[1])."
        }
        let head = parts.dropLast().joined(separator: ", ")
        return "Я \(head) и \(parts.last!)."
    }
}
