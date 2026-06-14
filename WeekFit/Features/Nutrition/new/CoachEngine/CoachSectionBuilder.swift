import SwiftUI

enum CoachSectionBuilder {

    static func build(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext,
        trainingFallback: [String],
        coachAccentColor: Color,
        priority: CoachDayPriorityResult? = nil
    ) -> [CoachSection] {

        if let priority,
           priorityHasSectionContent(priority) {
            return normalizedSections(prioritySections(priority, color: coachAccentColor))
        }

        let profile = CoachActivityProfileResolver.resolve(scenario: scenario)

        let sections: [CoachSection]

        switch profile {

        case .breathing:
            sections = breathingSections(
                scenario: scenario
            )

        case .recovery:
            sections = recoverySections(
                scenario: scenario,
                nutrition: nutrition
            )

        case .heat:
            sections = heatSections(
                scenario: scenario,
                nutrition: nutrition
            )

        default:
            sections = workoutSections(
                scenario: scenario,
                nutrition: nutrition,
                trainingFallback: trainingFallback,
                coachAccentColor: coachAccentColor
            )
        }

        return normalizedSections(sections)
    }
}

private extension CoachSectionBuilder {

    static func prioritySections(
        _ priority: CoachDayPriorityResult,
        color: Color
    ) -> [CoachSection] {

        let whyText = priority.whyThisMatters?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanedSupportBullets = priority.supportBullets
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { bullet in
                guard let whyText, !whyText.isEmpty else { return true }

                let bulletNormalized = bullet.lowercased()
                let whyNormalized = whyText.lowercased()

                return bulletNormalized != whyNormalized &&
                       !whyNormalized.contains(bulletNormalized) &&
                       !bulletNormalized.contains(whyNormalized)
            }
        let localizedSupportBullets = localizedPrioritySupportBullets(
            for: priority,
            rawBullets: cleanedSupportBullets
        )

        var sections = [
            CoachSection(
                title: supportTitle(for: priority),
                subtitle: supportSubtitle(for: priority),
                icon: supportIcon(for: priority.priority),
                color: color,
                style: .cards,
                items: localizedSupportBullets
            )
        ]

        if let whyText, !whyText.isEmpty {
            sections.append(
                CoachSection(
                    title: WeekFitLocalizedString("coach.info.whyThisMatters.title"),
                    subtitle: WeekFitLocalizedString("coach.section.priorityWhy.subtitle"),
                    icon: "leaf.fill",
                    color: CoachPalette.recovery,
                    style: .info,
                    informationalText: localizedPriorityText(
                        whyText,
                        fallback: priorityWhyFallback(for: priority)
                    )
                )
            )
        }

        let planChallenge = priority.planChallenge?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if shouldShowPlanChallenge(for: priority, planChallenge: planChallenge) {
            sections.append(
                CoachSection(
                    title: WeekFitLocalizedString("coach.info.planChallenge.title"),
                    subtitle: WeekFitLocalizedString("coach.info.planChallenge.subtitle"),
                    icon: "exclamationmark.triangle.fill",
                    color: CoachPalette.warning,
                    style: .info,
                    informationalText: localizedPriorityText(
                        planChallenge ?? "",
                        fallback: priorityPlanFallback(for: priority)
                    )
                )
            )
        }

        return sections.filter { !$0.isEmpty }
    }

    static func supportTitle(for priority: CoachDayPriorityResult) -> String {
        switch priority.priority {
        case .recovery, .sleepPreparation:
            return priority.limiter == .sleep ? WeekFitLocalizedString("coach.section.sleepSupport.title") : WeekFitLocalizedString("coach.section.recoverySupport.title")
        case .hydration:
            return WeekFitLocalizedString("coach.section.hydrationSupport.title")
        case .fueling:
            return WeekFitLocalizedString("coach.section.fuelingSupport.title")
        case .planChallenge:
            return WeekFitLocalizedString("coach.info.planAdjustment.title")
        case .performance:
            return WeekFitLocalizedString("coach.section.trainingAdjustment.title")
        case .activeSession:
            return WeekFitLocalizedString("coach.section.sessionFocus.title")
        case .stable:
            return WeekFitLocalizedString("coach.section.dailyRhythm.title")
        }
    }

    static func supportSubtitle(for priority: CoachDayPriorityResult) -> String {
        switch priority.priority {
        case .sleepPreparation:
            return WeekFitLocalizedString("coach.section.subtitle.sleepPreparation")
        case .recovery:
            return WeekFitLocalizedString("coach.section.subtitle.recovery")
        case .hydration:
            return WeekFitLocalizedString("coach.section.subtitle.hydration")
        case .fueling:
            return WeekFitLocalizedString("coach.section.subtitle.fueling")
        case .planChallenge:
            return WeekFitLocalizedString("coach.section.subtitle.planChallenge")
        case .performance:
            return WeekFitLocalizedString("coach.section.subtitle.performance")
        case .activeSession:
            return WeekFitLocalizedString("coach.section.subtitle.activeSession")
        case .stable:
            return WeekFitLocalizedString("coach.section.subtitle.stable")
        }
    }

    static func supportIcon(for priority: CoachDayPriority) -> String {
        switch priority {
        case .recovery, .sleepPreparation:
            return "moon.stars.fill"
        case .hydration:
            return "drop.fill"
        case .fueling:
            return "bolt.fill"
        case .planChallenge:
            return "exclamationmark.triangle.fill"
        case .performance:
            return "speedometer"
        case .activeSession:
            return "checkmark"
        case .stable:
            return "waveform.path.ecg"
        }
    }

    static func priorityHasSectionContent(_ priority: CoachDayPriorityResult) -> Bool {
        !priority.supportBullets.isEmpty ||
            !(priority.whyThisMatters?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ||
            !(priority.planChallenge?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) ||
            priority.priority == .planChallenge
    }

    static func shouldShowPlanChallenge(
        for priority: CoachDayPriorityResult,
        planChallenge: String?
    ) -> Bool {
        !(planChallenge?.isEmpty ?? true) || priority.priority == .planChallenge
    }

    static func localizedPrioritySupportBullets(
        for priority: CoachDayPriorityResult,
        rawBullets: [String]
    ) -> [String] {
        guard !rawBullets.isEmpty else {
            return []
        }

        let fallbacks = prioritySupportFallbacks(for: priority)
        return rawBullets.enumerated().map { index, bullet in
            localizedPriorityText(
                bullet,
                fallback: fallbacks[index % fallbacks.count]
            )
        }
    }

    static func localizedPriorityText(_ text: String, fallback: String) -> String {
        let localized = WeekFitCoachRuntimeLocalizedString(text)
        if localized != text || !WeekFitCurrentLocale().identifier.hasPrefix("ru") {
            return localized
        }
        return fallback
    }

    static func prioritySupportFallbacks(for priority: CoachDayPriorityResult) -> [String] {
        switch priority.priority {
        case .sleepPreparation:
            return ["Сохраните сон сегодня", "Сделайте вечер спокойным", "Не добавляйте позднюю нагрузку"]
        case .recovery:
            return ["Держите движение легким", "Восстановите воду и питание", "Не добавляйте интенсивность"]
        case .hydration:
            return ["Пейте воду постепенно", "Держите бутылку рядом", "Не догоняйте цель одним большим объемом"]
        case .fueling:
            return ["Добавьте простой прием пищи", "Сделайте еду легко усваиваемой", "Не откладывайте питание до старта"]
        case .planChallenge:
            return ["Снизьте потолок нагрузки", "Сохраните сон сегодня", "Оставьте план гибким"]
        case .performance:
            return ["Начните легче обычного", "Держите усилие повторяемым", "Корректируйте по самочувствию"]
        case .activeSession:
            return ["Держите усилие ровным", "Пейте спокойно", "Закончите с запасом"]
        case .stable:
            return ["Сохраняйте ритм", "Держите воду и питание ровно", "Не добавляйте лишнюю нагрузку"]
        }
    }

    static func priorityWhyFallback(for priority: CoachDayPriorityResult) -> String {
        switch priority.priority {
        case .sleepPreparation:
            return "Сон сегодня задает качество восстановления и готовность к следующему дню."
        case .recovery:
            return "Организм лучше адаптируется, когда после нагрузки есть место для восстановления."
        case .hydration:
            return "Жидкость поддерживает качество движения, терморегуляцию и восстановление."
        case .fueling:
            return "Питание делает энергию доступной до нагрузки и помогает восстановиться после нее."
        case .planChallenge:
            return "План работает лучше, когда его можно адаптировать под реальную готовность."
        case .performance:
            return "Качество тренировки зависит от контролируемого старта и умения вовремя снизить усилие."
        case .activeSession:
            return "Во время тренировки важнее повторяемое усилие, чем попытка добрать план любой ценой."
        case .stable:
            return "Стабильный день не требует исправления, ему нужен ровный ритм."
        }
    }

    static func priorityPlanFallback(for priority: CoachDayPriorityResult) -> String {
        switch priority.priority {
        case .planChallenge, .performance:
            return "Если готовность не улучшится к тренировке, сделайте ее легче или перенесите интенсивность."
        case .recovery, .sleepPreparation:
            return "Оставьте следующий блок гибким, пока восстановление не станет надежнее."
        case .hydration:
            return "Не повышайте нагрузку, пока гидратация не вернется в норму."
        case .fueling:
            return "Не начинайте требовательную работу, пока питание не закрыто."
        case .activeSession:
            return "Пусть текущая тренировка задаст реальный темп нагрузки."
        case .stable:
            return "План можно оставить без изменений."
        }
    }

    static func normalizedSections(_ sections: [CoachSection]) -> [CoachSection] {
        var seenSectionKeys = Set<String>()
        var seenTextIdeas = Set<String>()
        var result: [CoachSection] = []

        for section in sections where !section.isEmpty {
            let title = WeekFitCoachRuntimeLocalizedString(section.title)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = WeekFitCoachRuntimeLocalizedString(section.subtitle)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let sectionKey = normalizedIdea("\(title) \(subtitle) \(section.icon)")
            guard !sectionKey.isEmpty, !seenSectionKeys.contains(sectionKey) else { continue }

            let items = section.items.compactMap { item -> String? in
                let localized = WeekFitCoachRuntimeLocalizedString(item)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let idea = normalizedIdea(localized)
                guard !localized.isEmpty, !idea.isEmpty, !seenTextIdeas.contains(idea) else {
                    return nil
                }
                seenTextIdeas.insert(idea)
                return localized
            }

            let informationalText: String? = {
                guard let text = section.informationalText else { return nil }
                let localized = WeekFitCoachRuntimeLocalizedString(text)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let idea = normalizedIdea(localized)
                guard !localized.isEmpty, !idea.isEmpty, !seenTextIdeas.contains(idea) else {
                    return nil
                }
                seenTextIdeas.insert(idea)
                return localized
            }()

            let cleaned = CoachSection(
                title: title,
                subtitle: subtitle,
                icon: section.icon,
                color: section.color,
                style: section.style,
                items: items,
                informationalText: informationalText
            )
            guard !cleaned.isEmpty else { continue }
            seenSectionKeys.insert(sectionKey)
            result.append(cleaned)
        }

        return result
    }

    static func normalizedIdea(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "[^a-zа-яё0-9]+", with: " ", options: .regularExpression)
            .split(separator: " ")
            .filter { token in
                !["the", "and", "this", "that", "with", "для", "это", "сейчас", "сегодня", "чтобы"].contains(String(token))
            }
            .joined(separator: " ")
    }
}

// MARK: - Workout / Performance

private extension CoachSectionBuilder {

    static func workoutSections(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext,
        trainingFallback: [String],
        coachAccentColor: Color
    ) -> [CoachSection] {

        let fuelItems = CoachFuelingMessageBuilder.messages(
            scenario: scenario,
            nutrition: nutrition,
            maxItems: 3
        )

        let sessionItems = CoachSessionMessageBuilder.messages(
            scenario: scenario,
            fallback: trainingFallback,
            maxItems: 3
        )

        return [
            CoachSection(
                title: WeekFitLocalizedString("coach.section.fuelHydration.title"),
                subtitle: fuelSubtitle(for: scenario),
                icon: "fork.knife",
                color: WeekFitTheme.meal,
                style: .compact,
                items: fuelItems
            ),

            CoachSection(
                title: WeekFitLocalizedString("coach.section.sessionFocus.title"),
                subtitle: sessionSubtitle(for: scenario),
                icon: "checkmark",
                color: coachAccentColor,
                style: .cards,
                items: sessionItems
            )
        ]
    }
}

// MARK: - Breathing / Mindfulness

private extension CoachSectionBuilder {

    static func breathingSections(
        scenario: CoachActivityScenario
    ) -> [CoachSection] {

        switch scenario.stage {

        case .before:
            return [
                CoachSection(
                    title: WeekFitLocalizedString("coach.section.settleIn.title"),
                    subtitle: WeekFitLocalizedString("coach.section.settleIn.subtitle"),
                    icon: "wind",
                    color: CoachPalette.recovery,
                    style: .cards,
                    items: [
                        WeekFitLocalizedString("coach.section.breathing.before.sit"),
                        WeekFitLocalizedString("coach.section.breathing.before.exhale"),
                        WeekFitLocalizedString("coach.section.breathing.before.noForce")
                    ]
                ),

                CoachSection(
                    title: WeekFitLocalizedString("coach.section.insight.title"),
                    subtitle: WeekFitLocalizedString("coach.section.insight.keepInMind"),
                    icon: "leaf.fill",
                    color: CoachPalette.recovery,
                    style: .info,
                    informationalText: WeekFitLocalizedString("coach.section.breathing.before.insight")
                )
            ]

        case .during:
            return [
                CoachSection(
                    title: WeekFitLocalizedString("coach.section.stayWithIt.title"),
                    subtitle: WeekFitLocalizedString("coach.section.stayWithIt.subtitle"),
                    icon: "wind",
                    color: CoachPalette.recovery,
                    style: .cards,
                    items: [
                        WeekFitLocalizedString("coach.section.breathing.during.comfortable"),
                        WeekFitLocalizedString("coach.section.breathing.during.gentleExhale"),
                        WeekFitLocalizedString("coach.section.breathing.during.returnCalmly")
                    ]
                )
            ]

        case .after:
            return [
                CoachSection(
                    title: WeekFitLocalizedString("coach.section.recoveryEffect.title"),
                    subtitle: WeekFitLocalizedString("coach.section.recoveryEffect.subtitle"),
                    icon: "leaf.fill",
                    color: CoachPalette.recovery,
                    style: .cards,
                    items: [
                        WeekFitLocalizedString("coach.section.breathing.after.heartRate"),
                        WeekFitLocalizedString("coach.section.breathing.after.stress"),
                        WeekFitLocalizedString("coach.section.breathing.after.recoveryMode")
                    ]
                ),

                CoachSection(
                    title: WeekFitLocalizedString("coach.section.next.title"),
                    subtitle: WeekFitLocalizedString("coach.section.next.subtitle"),
                    icon: "moon.stars.fill",
                    color: CoachPalette.recovery,
                    style: .cards,
                    items: [
                        WeekFitLocalizedString("coach.section.breathing.after.screens"),
                        WeekFitLocalizedString("coach.section.breathing.after.routine"),
                        WeekFitLocalizedString("coach.section.breathing.after.noStress")
                    ]
                ),

                CoachSection(
                    title: WeekFitLocalizedString("coach.section.insight.title"),
                    subtitle: WeekFitLocalizedString("coach.section.insight.afterwards"),
                    icon: "sparkles",
                    color: CoachPalette.recovery,
                    style: .info,
                    informationalText: WeekFitLocalizedString("coach.section.breathing.after.insight")
                )
            ]

        case .stable:
            return []
        }
    }
}

// MARK: - Recovery

private extension CoachSectionBuilder {

    static func recoverySections(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext
    ) -> [CoachSection] {

        let supportItems = recoverySupportItems(
            scenario: scenario,
            nutrition: nutrition
        )

        return [
            CoachSection(
                title: WeekFitLocalizedString("coach.section.recoverySupport.title"),
                subtitle: recoverySupportSubtitle(for: scenario),
                icon: "drop.fill",
                color: WeekFitTheme.meal,
                style: .compact,
                items: supportItems
            ),

            CoachSection(
                title: WeekFitLocalizedString("coach.info.whyThisMatters.title"),
                subtitle: WeekFitLocalizedString("coach.section.recoveryWhy.subtitle"),
                icon: "leaf.fill",
                color: CoachPalette.recovery,
                style: .info,
                informationalText: recoveryWhyText(scenario: scenario)
            )
        ]
    }

    static func recoverySupportItems(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext
    ) -> [String] {

        let text = activityText(scenario)

        if isWalk(text) {
            if scenario.dayTime == .evening ||
                scenario.dayTime == .lateEvening ||
                scenario.dayTime == .night {
                return [
                    WeekFitLocalizedString("coach.section.recovery.walkEvening.water"),
                    WeekFitLocalizedString("coach.section.recovery.walkEvening.proteinDinner"),
                    WeekFitLocalizedString("coach.section.recovery.walkEvening.avoidHeavyFood")
                ]
            }

            return [
                WeekFitLocalizedString("coach.section.recovery.walk.water"),
                WeekFitLocalizedString("coach.section.recovery.walk.pace"),
                WeekFitLocalizedString("coach.section.recovery.walk.breathing")
            ]
        }

        if isStretching(text) {
            return [
                WeekFitLocalizedString("coach.section.recovery.stretching.slowly"),
                WeekFitLocalizedString("coach.section.recovery.stretching.noPain"),
                WeekFitLocalizedString("coach.section.recovery.stretching.range")
            ]
        }

        if isYoga(text) {
            return [
                WeekFitLocalizedString("coach.section.recovery.yoga.gentle"),
                WeekFitLocalizedString("coach.section.recovery.yoga.noForce"),
                WeekFitLocalizedString("coach.section.recovery.yoga.finishCalmer")
            ]
        }

        return [
            WeekFitLocalizedString("coach.section.recovery.general.hydration"),
            WeekFitLocalizedString("coach.section.recovery.general.moveGently"),
            WeekFitLocalizedString("coach.section.recovery.general.noLoad")
        ]
    }
}

// MARK: - Heat / Sauna

private extension CoachSectionBuilder {

    static func heatSections(
        scenario: CoachActivityScenario,
        nutrition: CoachNutritionContext
    ) -> [CoachSection] {

        [
            CoachSection(
                title: WeekFitLocalizedString("coach.section.recoverySupport.title"),
                subtitle: heatSupportSubtitle(for: scenario),
                icon: "drop.fill",
                color: WeekFitTheme.meal,
                style: .compact,
                items: heatSupportItems(scenario: scenario)
            ),

            CoachSection(
                title: WeekFitLocalizedString("coach.info.whyThisMatters.title"),
                subtitle: WeekFitLocalizedString("coach.section.heatWhy.subtitle"),
                icon: "flame.fill",
                color: CoachPalette.warning,
                style: .info,
                informationalText: WeekFitLocalizedString("coach.section.heatWhy.text")
            )
        ]
    }

    static func heatSupportItems(
        scenario: CoachActivityScenario
    ) -> [String] {

        switch scenario.stage {
        case .before:
            return [
                WeekFitLocalizedString("coach.section.heat.before.water"),
                WeekFitLocalizedString("coach.section.heat.minerals"),
                WeekFitLocalizedString("coach.section.heat.before.foodLight")
            ]

        case .during:
            return [
                WeekFitLocalizedString("coach.section.heat.during.comfortable"),
                WeekFitLocalizedString("coach.section.heat.during.exitDizzy"),
                WeekFitLocalizedString("coach.section.heat.during.noPush")
            ]

        case .after:
            return [
                WeekFitLocalizedString("coach.section.heat.after.waterSlowly"),
                WeekFitLocalizedString("coach.section.heat.minerals"),
                WeekFitLocalizedString("coach.section.heat.after.calmEvening")
            ]

        case .stable:
            return []
        }
    }
}

// MARK: - Subtitles

private extension CoachSectionBuilder {

    static func fuelSubtitle(
        for scenario: CoachActivityScenario
    ) -> String {
        switch scenario.stage {
        case .before:
            return WeekFitLocalizedString("coach.section.fuel.subtitle.before")
        case .during:
            return WeekFitLocalizedString("coach.section.fuel.subtitle.during")
        case .after:
            return WeekFitLocalizedString("coach.section.fuel.subtitle.after")
        case .stable:
            return WeekFitLocalizedString("coach.section.fuel.subtitle.stable")
        }
    }

    static func sessionSubtitle(
        for scenario: CoachActivityScenario
    ) -> String {
        switch scenario.stage {
        case .before:
            return WeekFitLocalizedString("coach.section.session.subtitle.before")
        case .during:
            return WeekFitLocalizedString("coach.section.session.subtitle.during")
        case .after:
            return WeekFitLocalizedString("coach.section.session.subtitle.after")
        case .stable:
            return WeekFitLocalizedString("coach.section.session.subtitle.stable")
        }
    }

    static func recoverySupportSubtitle(
        for scenario: CoachActivityScenario
    ) -> String {
        switch scenario.stage {
        case .before:
            return WeekFitLocalizedString("coach.section.recovery.subtitle.before")
        case .during:
            return WeekFitLocalizedString("coach.section.recovery.subtitle.during")
        case .after:
            return WeekFitLocalizedString("coach.section.recovery.subtitle.after")
        case .stable:
            return WeekFitLocalizedString("coach.section.recovery.subtitle.stable")
        }
    }

    static func heatSupportSubtitle(
        for scenario: CoachActivityScenario
    ) -> String {
        switch scenario.stage {
        case .before:
            return WeekFitLocalizedString("coach.section.heat.subtitle.before")
        case .during:
            return WeekFitLocalizedString("coach.section.heat.subtitle.during")
        case .after:
            return WeekFitLocalizedString("coach.section.recovery.subtitle.after")
        case .stable:
            return WeekFitLocalizedString("coach.section.heat.subtitle.stable")
        }
    }

    static func recoveryWhyText(
        scenario: CoachActivityScenario
    ) -> String {

        let text = activityText(scenario)

        if isWalk(text) {
            return WeekFitLocalizedString("coach.section.recovery.why.walk")
        }

        if isStretching(text) {
            return WeekFitLocalizedString("coach.section.recovery.why.stretching")
        }

        if isYoga(text) {
            return WeekFitLocalizedString("coach.section.recovery.why.yoga")
        }

        return WeekFitLocalizedString("coach.section.recovery.why.general")
    }
}

// MARK: - Helpers

private extension CoachSectionBuilder {

    static func activityText(
        _ scenario: CoachActivityScenario
    ) -> String {
        "\(scenario.activity?.title ?? "") \(scenario.activity?.type ?? "")"
            .lowercased()
    }

    static func isWalk(_ text: String) -> Bool {
        text.contains("walk") ||
        text.contains("walking") ||
        text.contains("hike")
    }

    static func isStretching(_ text: String) -> Bool {
        text.contains("stretch") ||
        text.contains("mobility")
    }

    static func isYoga(_ text: String) -> Bool {
        text.contains("yoga")
    }
}
