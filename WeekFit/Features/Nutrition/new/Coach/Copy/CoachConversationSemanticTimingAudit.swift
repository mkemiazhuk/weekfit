import Foundation

/// Semantic conversation-timing audit — catches copy that passes phrase blacklists but still
/// sounds wrong for the moment (morning/midday completion tone, ungrounded «already done», fasting).
enum CoachConversationSemanticTimingAudit {

    struct Finding: Equatable {
        let section: String
        let language: String
        let phrase: String
        let reason: String
    }

    struct Report: Equatable {
        let findings: [Finding]

        var isClean: Bool { findings.isEmpty }
    }

    struct Context: Equatable {
        let timeOfDay: CoachTimeOfDay
        let conversationPhase: CoachConversationPhase
        let scenario: CoachScenarioKey
        let hadHeavyYesterday: Bool
        let isLowRecovery: Bool
        let completedSeriousWorkToday: Bool
        let completedRecoveryWalkToday: Bool
        let isTomorrowProtection: Bool
        let mealWindowOpen: Bool
        let dehydrationRisk: Bool
        let fuelBehind: Bool
        let hydrationBehind: Bool

        var isMorningOrMidday: Bool {
            timeOfDay == .morning || timeOfDay == .midday
        }

        var isBeforeNoon: Bool {
            timeOfDay == .morning
        }

        var isRecoveryDay: Bool {
            isLowRecovery || hadHeavyYesterday || scenario == .recoveryAfterHeavyYesterday
        }

        static func from(_ input: CoachCopyBuildInput) -> Context {
            Context(
                timeOfDay: input.timeOfDay,
                conversationPhase: input.conversationPhase,
                scenario: input.scenario,
                hadHeavyYesterday: input.dayReadiness.hadHeavyYesterday,
                isLowRecovery: input.dayReadiness.isLowRecovery || input.dayReadiness.sleepIsLow,
                completedSeriousWorkToday: input.modifiers.completedSeriousActivities != .none,
                completedRecoveryWalkToday: completedRecoveryWalkToday(input),
                isTomorrowProtection: input.scenario == .tomorrowProtection
                    || input.modifiers.tomorrowDemand == .hard
                    || input.modifiers.tomorrowDemand == .moderate,
                mealWindowOpen: input.mealWindowOpen,
                dehydrationRisk: input.dehydrationRisk,
                fuelBehind: input.modifiers.fuelBehind || input.fuelState.isBehind,
                hydrationBehind: input.modifiers.hydrationBehind || input.hydrationState.isBehind
            )
        }

        static func completedRecoveryWalkToday(_ input: CoachCopyBuildInput) -> Bool {
            if input.modifiers.completedWalkToday {
                return true
            }
            switch input.scenario {
            case .walkAfterHeavyLoad, .walkRecoveryAction:
                return CoachWalkRecoveryActionCopy.phase(for: input) == .completed
            default:
                break
            }
            guard input.modifiers.activityType == .walk else { return false }
            switch input.activityState {
            case .finished, .justFinished:
                return true
            default:
                return input.focusSource == .recentCompleted
            }
        }
    }

    // MARK: - Phrase sets

    /// Morning/midday — must not imply the day is already complete.
    static let dayCompleteRussian: [String] = [
        "день позади",
        "день сделан",
        "день за вами",
        "доказывать уже нечего",
        "достаточно сделано",
        "на сегодня достаточно",
        "день можно завершить",
        "завершить день"
    ]

    static let dayCompleteEnglish: [String] = [
        "day is behind",
        "day behind you",
        "day is done",
        "nothing left to prove",
        "enough has been done",
        "enough for today"
    ]

    /// Early recovery day — closure framing before noon.
    static let earlyRecoveryClosureRussian: [String] = [
        "день позади",
        "доказывать уже нечего",
        "достаточно сделано",
        "на сегодня достаточно"
    ]

    static let earlyRecoveryClosureEnglish: [String] = [
        "day is behind you",
        "nothing left to prove",
        "enough has been done"
    ]

  static let completionMarkerRussian: [String] = [
        "уже сделан",
        "уже есть",
        "уже помог",
        "уже была",
        "доказывать уже нечего",
        "помогли",
        "не нужно добавлять"
    ]

    static let completionMarkerEnglish: [String] = [
        "already done",
        "already banked",
        "already made",
        "already helped",
        "already in the",
        "already on the",
        "is banked",
        "work is banked",
        "nothing left to prove",
        "no need to add",
        "helped things settle",
        "helped the body"
    ]

    static let groundingAnchorRussian: [String] = [
        "вчера",
        "прогулк",
        "работа",
        "заезд",
        "пробежк",
        "игр",
        "силов",
        "утрен",
        "завтра",
        "восстановлен",
        "отдых",
        "нагрузк"
    ]

    static let groundingAnchorEnglish: [String] = [
        "yesterday",
        "walk",
        "work",
        "ride",
        "run",
        "match",
        "strength",
        "morning",
        "tomorrow",
        "recovery",
        "rest",
        "load"
    ]

    static let eatNowRussian: [String] = [
        "еды пока меньше",
        "поешьте",
        "поешьте",
        "ешьте",
        "нормально поешьте",
        "еда по плану",
        "вода, еда"
    ]

    static let eatNowEnglish: [String] = [
        "food is low",
        "eat soon",
        "eat now",
        "eat a proper",
        "water, food and rest",
        "food as planned"
    ]

    static let hydrationWarningRussian: [String] = [
        "воды мало",
        "воды не хватает",
        "воды за день пока маловато",
        "очень мало воды",
        "пейте понемногу"
    ]

    static let hydrationWarningEnglish: [String] = [
        "water is running behind",
        "water still behind",
        "fluids are critically",
        "drink a glass"
    ]

    // MARK: - Audit

    static func audit(pack: CoachCopyPack, input: CoachCopyBuildInput) -> Report {
        audit(pack: pack, context: Context.from(input))
    }

    static func audit(pack: CoachCopyPack, context: Context) -> Report {
        var findings: [Finding] = []

        let closureAllowed = CoachCopyClosureTiming.allowsDayClosurePhrasing(
            timeOfDay: context.timeOfDay,
            conversationPhase: context.conversationPhase
        )

        for (section, lines) in allSections(pack) {
            for (index, line) in lines.enumerated() {
                let sectionKey = "\(section)[\(index)]"
                findings += auditText(line.russian, section: sectionKey, language: "ru", context: context, closureAllowed: closureAllowed, isMainStory: isMainStory(section))
                findings += auditText(line.english, section: sectionKey, language: "en", context: context, closureAllowed: closureAllowed, isMainStory: isMainStory(section))
            }
        }

        if let warning = pack.warningLayer {
            findings += auditText(
                warning.message.russian,
                section: "warningLayer",
                language: "ru",
                context: context,
                closureAllowed: closureAllowed,
                isMainStory: false
            )
        }

        return Report(findings: findings)
    }

    // MARK: - Private

    private static func allSections(_ pack: CoachCopyPack) -> [(String, [CoachBilingualText])] {
        [
            ("assessment", pack.assessment.lines),
            ("recommendation", pack.recommendation.lines),
            ("avoid", pack.avoid.lines),
            ("nextAction", pack.nextAction.lines),
            ("supportingSignals", pack.supportingSignals.lines)
        ]
    }

    private static func isMainStory(_ section: String) -> Bool {
        section != "supportingSignals"
    }

    private static func auditText(
        _ text: String,
        section: String,
        language: String,
        context: Context,
        closureAllowed: Bool,
        isMainStory: Bool
    ) -> [Finding] {
        let normalized = text.lowercased()
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        var findings: [Finding] = []

        if context.isMorningOrMidday, !closureAllowed {
            findings += matchedPhrases(
                in: normalized,
                language: language,
                section: section,
                phrases: language == "ru" ? dayCompleteRussian : dayCompleteEnglish,
                reason: "morning/midday implies day is complete"
            )
        }

        if context.isBeforeNoon, context.isRecoveryDay, !closureAllowed {
            findings += matchedPhrases(
                in: normalized,
                language: language,
                section: section,
                phrases: language == "ru" ? earlyRecoveryClosureRussian : earlyRecoveryClosureEnglish,
                reason: "before noon recovery day uses closure framing"
            )
        }

        if !CoachCopyClosureTiming.allowsRestOfDayPhrasing(context.timeOfDay), isMainStory {
            findings += unanchoredCompletionMarkers(
                in: normalized,
                language: language,
                section: section,
                context: context
            )
        }

        if !context.mealWindowOpen, isMainStory {
            findings += matchedPhrases(
                in: normalized,
                language: language,
                section: section,
                phrases: language == "ru" ? eatNowRussian : eatNowEnglish,
                reason: "eat-now tone before first meal window"
            )
        }

        if !context.mealWindowOpen, section.hasPrefix("supportingSignals") {
            if normalized.contains("еды пока меньше") || normalized.contains("fuel intake is lagging") {
                findings.append(Finding(
                    section: section,
                    language: language,
                    phrase: language == "ru" ? "еды пока меньше" : "fuel intake is lagging",
                    reason: "fuel-behind why-row during fasting window"
                ))
            }
        }

        if context.isMorningOrMidday,
           context.hydrationBehind,
           !context.dehydrationRisk,
           isMainStory {
            findings += matchedPhrases(
                in: normalized,
                language: language,
                section: section,
                phrases: language == "ru" ? hydrationWarningRussian : hydrationWarningEnglish,
                reason: "hydration warning dominates main story before midday"
            )
        }

        return findings
    }

    private static func matchedPhrases(
        in text: String,
        language: String,
        section: String,
        phrases: [String],
        reason: String
    ) -> [Finding] {
        phrases.compactMap { phrase in
            guard text.contains(phrase) else { return nil }
            return Finding(section: section, language: language, phrase: phrase, reason: reason)
        }
    }

    private static func unanchoredCompletionMarkers(
        in text: String,
        language: String,
        section: String,
        context: Context
    ) -> [Finding] {
        let markers = language == "ru" ? completionMarkerRussian : completionMarkerEnglish
        let anchors = language == "ru" ? groundingAnchorRussian : groundingAnchorEnglish
        let sentences = text.split(whereSeparator: { ".!?".contains($0) }).map(String.init)

        var findings: [Finding] = []
        for sentence in sentences {
            let lower = sentence.lowercased()
            guard let marker = markers.first(where: { lower.contains($0) }) else { continue }
            if anchors.contains(where: { lower.contains($0) }) { continue }
            if contextAllowsCompletionMarker(marker, context: context, sentence: lower) { continue }
            findings.append(Finding(
                section: section,
                language: language,
                phrase: marker,
                reason: "completion tone without grounding anchor"
            ))
        }
        return findings
    }

    private static func contextAllowsCompletionMarker(
        _ marker: String,
        context: Context,
        sentence: String
    ) -> Bool {
        if context.isTomorrowProtection,
           sentence.contains("завтра") || sentence.contains("tomorrow") {
            return true
        }
        if context.completedSeriousWorkToday,
           sentence.contains("работ") || sentence.contains("work")
            || sentence.contains("banked") || sentence.contains("сделан") {
            return true
        }
        if context.completedRecoveryWalkToday,
           sentence.contains("прогулк") || sentence.contains("walk") {
            return true
        }
        if context.hadHeavyYesterday,
           sentence.contains("вчера") || sentence.contains("yesterday") {
            return true
        }
        if context.isLowRecovery,
           sentence.contains("восстановлен") || sentence.contains("recovery")
            || sentence.contains("отдых") || sentence.contains("rest") {
            return true
        }
        return false
    }
}
