import SwiftUI

struct CoachFinalStoryRenderedSupportSignal: Hashable {
    let kind: CoachFinalStorySupportSignal.Kind
    let title: String
    let icon: String
    let colorFamily: CoachFinalStoryColorFamily

    var color: Color { colorFamily.color }
}

struct CoachFinalStoryRenderedReason: Hashable {
    let kind: CoachFinalStoryReason.Kind
    let title: String
    let icon: String
    let colorFamily: CoachFinalStoryColorFamily

    var color: Color {
        switch kind {
        case .sleep:
            return Color(red: 0.55, green: 0.40, blue: 0.85)
        case .recovery:
            return CoachPalette.recovery
        case .time, .tomorrow:
            return Color(red: 0.40, green: 0.62, blue: 0.96)
        case .training:
            return CoachPalette.stable
        case .constraint:
            return CoachPalette.warning
        case .hydration:
            return CoachPalette.hydration
        case .fuel:
            return CoachPalette.fueling
        case .stability:
            return Color(red: 0.48, green: 0.58, blue: 0.72)
        }
    }
}

struct CoachFinalStoryRenderModel {
    let owner: CoachFinalStoryOwner
    let primaryFocus: CoachDayFocus
    let title: String
    let subtitle: String
    let badge: String
    let heroState: String
    let icon: String
    let colorFamily: CoachFinalStoryColorFamily
    let primaryRecommendation: String
    let avoidRecommendation: String
    let whatHappened: String
    let whatMattersNow: String
    let whatToDoNext: String
    let whatToAvoid: String
    let primaryActionTitle: String
    let primaryActionIcon: String
    let supportActions: [CoachSupportActionV3]
    let whyRows: [CoachFinalStoryRenderedReason]
    let supportSignals: [CoachFinalStoryRenderedSupportSignal]

    var color: Color { colorFamily.color }

    init(story: CoachFinalStory) {
        #if DEBUG
        CoachLogger.trace(
            "[CoachV4Audit.Render.In]",
            "owner=\(story.owner.rawValue) title=\"\(story.title.resolved)\""
        )
        #endif
        let title = story.title.resolved
        let subtitle = story.subtitle.resolved
        let whatHappened = story.whatHappened.resolved
        let whatMattersNow = Self.uniqueHeroText(
            story.whatMattersNow.resolved,
            fallbackCandidates: [
                Self.fallbackRecommendation(owner: story.owner)
            ],
            avoiding: [title, subtitle, whatHappened]
        )
        let whatToDoNext = story.whatToDoNext.resolved
        let whatToAvoid = story.whatToAvoid.resolved
        let primaryRecommendation = Self.uniqueHeroText(
            story.primaryRecommendation.resolved,
            fallbackCandidates: [
                whatToDoNext,
                Self.fallbackRecommendation(owner: story.owner)
            ],
            avoiding: [title, subtitle]
        )
        let explicitAvoidance = story.avoidRecommendation.resolved.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitWhatToAvoid = whatToAvoid.trimmingCharacters(in: .whitespacesAndNewlines)
        let avoidRecommendation = explicitAvoidance.isEmpty && explicitWhatToAvoid.isEmpty
            ? ""
            : Self.uniqueHeroText(
                explicitAvoidance,
                fallbackCandidates: [
                    explicitWhatToAvoid,
                    Self.fallbackAvoidance(owner: story.owner)
                ],
                avoiding: [title, subtitle, primaryRecommendation]
            )
        let visibleHeroTexts = [
            title,
            subtitle,
            whatHappened,
            whatMattersNow,
            whatToDoNext,
            whatToAvoid,
            primaryRecommendation,
            avoidRecommendation
        ]

        self.owner = story.owner
        self.primaryFocus = story.primaryFocus
        self.title = title
        self.subtitle = subtitle
        self.badge = story.badgeState.resolved
        self.heroState = story.heroState.resolved
        self.icon = story.icon
        self.colorFamily = story.colorFamily
        self.primaryRecommendation = primaryRecommendation
        self.avoidRecommendation = avoidRecommendation
        self.whatHappened = whatHappened
        self.whatMattersNow = whatMattersNow
        self.whatToDoNext = whatToDoNext
        self.whatToAvoid = whatToAvoid
        let heroDomains = Self.semanticDomains(in: visibleHeroTexts)
            .union(Self.semanticDomains(in: [story.primaryAction.title.resolved]))
        let shouldSuppressSemanticDuplicates = story.owner == .activityPreparation && heroDomains.contains("heat") ||
            story.owner == .tomorrowProtection
        let occupiedHeroDomains: Set<String> = {
            if story.owner == .activityPreparation && heroDomains.contains("heat") {
                return heroDomains.intersection(["heat", "hydration"])
            }
            if story.owner == .tomorrowProtection {
                return heroDomains.intersection(["tomorrow", "sleep"])
                    .union(["intensity"])
            }
            return []
        }()
        var seenWhyRows = Set<String>()
        var seenWhyDomains = occupiedHeroDomains
        let whyRows = story.reasons.compactMap { reason -> CoachFinalStoryRenderedReason? in
            let title = reason.text.resolved.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            let normalizedTitle = Self.normalized(title)
            guard !visibleHeroTexts.contains(where: { Self.normalized($0) == normalizedTitle }) else {
                return nil
            }
            let reasonDomains = Self.semanticDomains(for: reason.kind, title: title)
            guard !shouldSuppressSemanticDuplicates || reasonDomains.isEmpty || reasonDomains.isDisjoint(with: seenWhyDomains) else {
                return nil
            }
            guard seenWhyRows.insert(normalizedTitle).inserted else {
                return nil
            }
            if shouldSuppressSemanticDuplicates {
                seenWhyDomains.formUnion(reasonDomains)
            }
            return CoachFinalStoryRenderedReason(
                kind: reason.kind,
                title: title,
                icon: reason.icon,
                colorFamily: reason.colorFamily
            )
        }
        .prefix(3)
        .map { $0 }
        let primaryActionTitle = story.primaryAction.title.resolved
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionIcon = story.primaryAction.icon
        self.supportActions = Self.visibleSupportActions(
            story.supportActions,
            avoiding: visibleHeroTexts + whyRows.map(\.title),
            avoidingDomains: seenWhyDomains
        )
        self.whyRows = whyRows
        self.supportSignals = CoachFinalStoryRenderModel.visibleSupportSignals(for: story)
        #if DEBUG
        let usedFallback = primaryRecommendation != story.primaryRecommendation.resolved ||
            avoidRecommendation != story.avoidRecommendation.resolved ||
            whatMattersNow != story.whatMattersNow.resolved
        let fallbackSource = usedFallback ? "uniqueHeroText" : "none"
        CoachLogger.trace(
            "[CoachV4Audit.Render.Out]",
            "owner=\(self.owner.rawValue) title=\"\(self.title)\" usedFallback=\(usedFallback) fallbackSource=\(fallbackSource)"
        )
        #endif
    }
}

extension CoachFinalStory {
    var todaySemanticInsight: DynamicInsight {
        DynamicInsight(
            icon: icon,
            title: todaySemanticTitleKey,
            text: todaySemanticSubtitleKey,
            color: color,
            actionID: "coach_final_story.\(owner.rawValue)",
            actionLabel: "Open Coach",
            tags: todaySemanticTags
        )
    }

    private var todaySemanticTitleKey: String {
        nonEmptySemanticKey(titleKey, fallback: "coach.final.story.\(owner.rawValue).title")
    }

    private var todaySemanticSubtitleKey: String {
        nonEmptySemanticKey(subtitleKey, fallback: "coach.final.story.\(owner.rawValue).subtitle")
    }

    private func nonEmptySemanticKey(_ key: String, fallback: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private var todaySemanticTags: Set<CoachTag> {
        var tags = Set<CoachTag>()

        switch owner {
        case .hydration, .hydrationExecution:
            tags.insert(.hydration)
        case .fuel, .fuelingDuringActivity:
            tags.insert(.carbs)
        case .postActivityRecovery, .recovery:
            tags.insert(.recovery)
        case .activeActivity, .pacingExecution, .sustainableExecution, .activityPreparation:
            tags.insert(.schedule)
        case .tomorrowProtection:
            tags.insert(.schedule)
            tags.insert(.sleep)
        case .readiness:
            tags.insert(.recovery)
        case .stableOverview:
            tags.insert(.consistency)
        }

        for signal in supportSignals {
            switch signal.kind {
            case .hydration:
                tags.insert(.hydration)
            case .fuel:
                tags.insert(.carbs)
            case .recovery:
                tags.insert(.recovery)
            case .sleep:
                tags.insert(.sleep)
            case .activity:
                tags.insert(.schedule)
            }
        }

        if tags.isEmpty {
            tags.insert(.consistency)
        }

        return tags
    }
}

extension CoachFinalStoryRenderModel {
    static func uniqueHeroText(
        _ preferred: String,
        fallbackCandidates: [String],
        avoiding existingTexts: [String]
    ) -> String {
        for candidate in [preferred] + fallbackCandidates {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let normalizedCandidate = normalized(trimmed)
            guard !textOverlapsAny(normalizedCandidate, in: Set(existingTexts.map(normalized))) else {
                continue
            }
            return trimmed
        }

        return preferred.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func fallbackRecommendation(owner: CoachFinalStoryOwner) -> String {
        switch owner {
        case .activeActivity:
            return localized(
                english: "Hold the next block controlled and skip surges.",
                russian: "Следующий блок держите под контролем и без рывков."
            )
        case .pacingExecution:
            return localized(
                english: "Keep the next 10 minutes easy, then reassess.",
                russian: "Следующие 10 минут держите легко, затем оцените состояние."
            )
        case .sustainableExecution:
            return localized(
                english: "Take carbs every 20-30 minutes and keep the rhythm repeatable.",
                russian: "Принимайте углеводы каждые 20-30 минут и держите повторяемый ритм."
            )
        case .fuelingDuringActivity:
            return localized(
                english: "Consume 30-60 g carbohydrates within the next 15 minutes.",
                russian: "Примите 30-60 г углеводов в течение ближайших 15 минут."
            )
        case .hydrationExecution:
            return localized(
                english: "Drink 300-500 ml during the next 20 minutes.",
                russian: "Выпейте 300-500 мл в течение ближайших 20 минут."
            )
        case .activityPreparation:
            return localized(
                english: "Prepare calmly, then let the first minutes confirm the pace.",
                russian: "Подготовьтесь спокойно, а темп подтвердите в первые минуты."
            )
        case .postActivityRecovery, .recovery:
            return localized(
                english: "Prioritize recovery now: food, water, and an easy evening.",
                russian: "Сейчас главный ход — восстановление: еда, вода и спокойный вечер."
            )
        case .hydration:
            return localized(
                english: "Drink gradually and keep the next block easier.",
                russian: "Пейте постепенно и сделайте следующий блок легче."
            )
        case .fuel:
            return localized(
                english: "Add usable energy before asking for more effort.",
                russian: "Добавьте энергии, прежде чем требовать от себя больше."
            )
        case .tomorrowProtection:
            return localized(
                english: "Spend less today so tomorrow starts cleaner.",
                russian: "Потратьте меньше сегодня, чтобы завтра начать свежее."
            )
        case .readiness, .stableOverview:
            return localized(
                english: "Keep the plan simple and avoid adding extra intensity.",
                russian: "Держите план простым и не добавляйте лишнюю интенсивность."
            )
        }
    }

    static func fallbackAvoidance(owner: CoachFinalStoryOwner) -> String {
        switch owner {
        case .activeActivity:
            return localized(
                english: "Do not add effort until breathing and form settle.",
                russian: "Не добавляйте усилие, пока дыхание и техника не стабилизируются."
            )
        case .pacingExecution:
            return localized(
                english: "Do not test fitness in the opening block.",
                russian: "Не проверяйте форму в начале."
            )
        case .sustainableExecution:
            return localized(
                english: "Do not wait for hunger or thirst to set the schedule.",
                russian: "Не ждите голода или жажды, чтобы задать график."
            )
        case .fuelingDuringActivity:
            return localized(
                english: "Do not wait for hunger before fueling.",
                russian: "Не ждите голода, чтобы начать питание."
            )
        case .hydrationExecution:
            return localized(
                english: "Do not try to catch up with one large drink.",
                russian: "Не догоняйте воду одним большим объёмом."
            )
        case .activityPreparation:
            return localized(
                english: "Do not turn the warm-up into a test.",
                russian: "Не делайте разминку проверкой."
            )
        case .postActivityRecovery, .recovery:
            return localized(
                english: "Do not add another hard effort today.",
                russian: "Не добавляйте сегодня ещё одну тяжёлую нагрузку."
            )
        case .hydration:
            return localized(
                english: "Do not try to fix all fluids at once.",
                russian: "Не пытайтесь восполнить всю воду за один раз."
            )
        case .fuel:
            return localized(
                english: "Do not wait for a crash before eating.",
                russian: "Не ждите резкого спада энергии, чтобы поесть."
            )
        case .tomorrowProtection:
            return localized(
                english: "Do not spend the energy tomorrow needs.",
                russian: "Не расходуйте энергию, которая нужна завтра."
            )
        case .readiness, .stableOverview:
            return localized(
                english: "Do not complicate the day without a real signal.",
                russian: "Не усложняйте день без явного сигнала."
            )
        }
    }

    static func localized(english: String, russian: String) -> String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? russian : english
    }

    static func visibleSupportActions(
        _ actions: [CoachSupportActionV3],
        avoiding existingTexts: [String],
        avoidingDomains existingDomains: Set<String>
    ) -> [CoachSupportActionV3] {
        var seenTitles = Set(existingTexts.map(normalized))
        var seenDomains = existingDomains
        var visible: [CoachSupportActionV3] = []

        for action in actions {
            let title = action.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let normalizedTitle = normalized(title)
            let normalizedSubtitle = normalized(action.subtitle)
            let actionDomains = semanticDomains(for: action.type)
            guard !textOverlapsAny(normalizedTitle, in: seenTitles) else { continue }
            guard normalizedSubtitle.isEmpty || !textOverlapsAny(normalizedSubtitle, in: seenTitles) else { continue }
            guard actionDomains.isEmpty || actionDomains.isDisjoint(with: seenDomains) else { continue }
            seenTitles.insert(normalizedTitle)
            seenDomains.formUnion(actionDomains)
            visible.append(action)
            if visible.count == 3 { break }
        }

        return visible
    }

    static func semanticDomains(in texts: [String]) -> Set<String> {
        texts.reduce(into: Set<String>()) { domains, text in
            domains.formUnion(semanticDomains(in: text))
        }
    }

    static func semanticDomains(for kind: CoachFinalStoryReason.Kind, title: String) -> Set<String> {
        switch kind {
        case .sleep:
            return ["sleep"]
        case .recovery:
            return ["recovery"]
        case .time:
            return ["time"]
        case .tomorrow:
            return ["tomorrow"]
        case .training:
            var domains = semanticDomains(in: title)
            if domains.contains("heat") {
                domains.insert("heat")
            } else {
                domains.insert("training")
            }
            return domains
        case .constraint:
            return ["constraint"]
        case .hydration:
            return ["hydration"]
        case .fuel:
            return ["fuel"]
        case .stability:
            return Set(["stability"]).union(semanticDomains(in: title))
        }
    }

    static func semanticDomains(for type: CoachSupportActionTypeV3) -> Set<String> {
        switch type {
        case .hydrateBeforeSession, .steadyHydration, .rehydrateGradually, .electrolyteRecovery:
            return ["hydration"]
        case .lightFueling, .sustainEnergy, .startRecoveryNutrition, .recoveryMeal, .keepDigestionLight:
            return ["fuel"]
        case .sleepPriority:
            return ["sleep"]
        case .cooldown, .lightRecoveryMovement:
            return ["recovery"]
        case .downshiftNervousSystem:
            return ["downshift"]
        case .controlIntensity:
            return ["intensity"]
        case .mobilityPrep:
            return ["mobility"]
        case .breathingReset:
            return ["breathing"]
        case .stayConsistent:
            return ["stability"]
        }
    }

    static func semanticDomains(in text: String) -> Set<String> {
        let value = normalized(text)
        var domains = Set<String>()
        if value.contains("hydrate") ||
            value.contains("hydration") ||
            value.contains("water") ||
            value.contains("fluid") ||
            value.contains("drink") ||
            value.contains("sip") ||
            value.contains("вод") ||
            value.contains("пей") ||
            value.contains("пить") {
            domains.insert("hydration")
        }
        if value.contains("sleep") ||
            value.contains("сон") ||
            value.contains("сна") {
            domains.insert("sleep")
        }
        if value.contains("tomorrow") ||
            value.contains("завтра") ||
            value.contains("завтраш") {
            domains.insert("tomorrow")
        }
        if value.contains("sauna") ||
            value.contains("heat") ||
            value.contains("hot") ||
            value.contains("тепл") ||
            value.contains("саун") {
            domains.insert("heat")
        }
        if value.contains("stress") ||
            value.contains("stressor") ||
            value.contains("load") ||
            value.contains("workout") ||
            value.contains("training") ||
            value.contains("extra work") ||
            value.contains("another hard") ||
            value.contains("нагруз") ||
            value.contains("трениров") ||
            value.contains("лишн") ||
            value.contains("стресс") {
            domains.insert("training")
            domains.insert("intensity")
        }
        if value.contains("recovery") ||
            value.contains("recover") ||
            value.contains("восстанов") {
            domains.insert("recovery")
        }
        if value.contains("carb") ||
            value.contains("protein") ||
            value.contains("fuel") ||
            value.contains("energy") ||
            value.contains("eat") ||
            value.contains("углев") ||
            value.contains("бел") ||
            value.contains("пит") ||
            value.contains("энерг") {
            domains.insert("fuel")
        }
        return domains
    }

    static func textOverlapsAny(_ value: String, in existing: Set<String>) -> Bool {
        existing.contains { textsOverlap(value, $0) }
    }

    static func textsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalized(lhs).trimmingCharacters(in: CharacterSet(charactersIn: ".。!?！？"))
        let right = normalized(rhs).trimmingCharacters(in: CharacterSet(charactersIn: ".。!?！？"))
        guard left.count >= 12, right.count >= 12 else {
            return left == right
        }
        return left == right || left.contains(right) || right.contains(left)
    }

    static func visibleSupportSignals(for story: CoachFinalStory) -> [CoachFinalStoryRenderedSupportSignal] {
        let heroTexts = [
            story.title.resolved,
            story.subtitle.resolved,
            story.whatHappened.resolved,
            story.whatMattersNow.resolved,
            story.whatToDoNext.resolved,
            story.whatToAvoid.resolved,
            story.primaryRecommendation.resolved,
            story.avoidRecommendation.resolved,
            story.primaryAction.title.resolved
        ].map { value in
            normalized(value)
        }
        var seenEvidence = Set<String>()

        return story.supportSignals.compactMap { signal in
            let evidenceKey = supportEvidenceKey(for: signal.kind)
            guard seenEvidence.insert(evidenceKey).inserted else { return nil }

            let signalTitle = signal.title.resolved.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedTitle = (isGenericSupportTitle(signalTitle)
                ? supportExplanation(for: signal.kind, owner: story.owner)
                : signalTitle)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !resolvedTitle.isEmpty else { return nil }
            guard !heroTexts.contains(normalized(resolvedTitle)) else { return nil }

            return CoachFinalStoryRenderedSupportSignal(
                kind: signal.kind,
                title: resolvedTitle,
                icon: signal.icon,
                colorFamily: colorFamily(for: signal.kind)
            )
        }
    }

    static func colorFamily(for signalKind: CoachFinalStorySupportSignal.Kind) -> CoachFinalStoryColorFamily {
        switch signalKind {
        case .hydration:
            return .hydration
        case .fuel:
            return .fuel
        case .recovery, .sleep:
            return .recovery
        case .activity:
            return .activity
        }
    }

    static func supportExplanation(
        for signalKind: CoachFinalStorySupportSignal.Kind,
        owner: CoachFinalStoryOwner
    ) -> String {
        let key: String
        switch signalKind {
        case .hydration:
            key = owner == .activityPreparation || owner == .activeActivity
                ? "coach.final.support.hydration.activity"
                : owner == .recovery || owner == .postActivityRecovery
                ? "coach.final.support.hydration.recovery"
                : "coach.final.support.hydration.stable"
        case .fuel:
            key = owner == .activityPreparation || owner == .activeActivity
                ? "coach.final.support.fuel.activity"
                : owner == .recovery || owner == .postActivityRecovery
                ? "coach.final.support.fuel.recovery"
                : "coach.final.support.fuel.stable"
        case .recovery:
            key = "coach.final.support.recovery"
        case .sleep:
            key = "coach.final.support.sleep"
        case .activity:
            key = "coach.final.support.activity"
        }

        return WeekFitLocalizedString(key)
    }

    static func supportEvidenceKey(for signalKind: CoachFinalStorySupportSignal.Kind) -> String {
        switch signalKind {
        case .hydration:
            return "hydration-status"
        case .fuel:
            return "nutrition-status"
        case .recovery:
            return "recovery-status"
        case .sleep:
            return "sleep-status"
        case .activity:
            return "activity-status"
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func isGenericSupportTitle(_ value: String) -> Bool {
        let normalized = normalized(value)
        return normalized.isEmpty ||
            normalized.contains("supports this story") ||
            normalized.contains("supports this conclusion") ||
            normalized.contains("is part of the decision")
    }
}
