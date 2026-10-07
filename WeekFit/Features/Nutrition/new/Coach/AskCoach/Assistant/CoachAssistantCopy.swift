import Foundation

enum CoachAssistantCopy {
    static func bi(_ english: String, _ russian: String, chinese: String? = nil) -> CoachBilingualText {
        let resolvedChinese = chinese
            ?? CoachChineseOverrides.resolved(english: english)
            ?? english
        return .en(english, russian, chinese: resolvedChinese)
    }

    static func resolve(_ text: CoachBilingualText) -> String {
        text.resolved()
    }

    static func areaLabel(_ area: CoachAssistantArea) -> CoachBilingualText {
        switch area {
        case .activity: return bi("Activity", "Активность")
        case .nutrition: return bi("Nutrition", "Питание")
        case .recovery: return bi("Recovery", "Восстановление")
        }
    }

    // MARK: - Opening

    struct OpeningLine: Equatable, Sendable {
        let id: String
        let text: CoachBilingualText
    }

    /// Varied check-in openers. Same-day restarts skip the time-of-day + name greeting.
    static func checkInOpening(
        givenName: String?,
        memory: CoachAssistantMemoryState,
        todayKey: String,
        date: Date = Date(),
        calendar: Calendar = .current,
        sameDayRestart: Bool? = nil
    ) -> OpeningLine {
        let day = CoachAssistantMemoryStore.day(todayKey, in: memory)
        let alreadyCheckedInToday =
            sameDayRestart
            ?? (day?.feeling != nil
                || day?.questionIDs.contains(where: { $0.hasPrefix("open.") }) == true)

        let pool = alreadyCheckedInToday
            ? returningCheckInVariants(givenName: givenName)
            : firstCheckInVariants(givenName: givenName, date: date, calendar: calendar)

        let previous = memory.lastOpeningVariantID
        let candidates = pool.filter { $0.id != previous }
        let usable = candidates.isEmpty ? pool : candidates
        let salt = (day?.questionIDs.count ?? 0) + (alreadyCheckedInToday ? 3 : 0)
        let index = abs(salt) % usable.count
        return usable[index]
    }

    static func timeOfDayGreeting(
        givenName: String?,
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachBilingualText {
        checkInOpening(
            givenName: givenName,
            memory: .empty,
            todayKey: CoachDailyObservation.dayKey(for: date, calendar: calendar),
            date: date,
            calendar: calendar,
            sameDayRestart: false
        ).text
    }

    /// Backward-compatible alias used by older call sites.
    static func feelingPrompt(givenName: String?) -> CoachBilingualText {
        // Re-check feeling mid-conversation — skip the formal time-of-day greeting.
        checkInOpening(
            givenName: givenName,
            memory: CoachAssistantMemoryStore.load(),
            todayKey: CoachDailyObservation.dayKey(for: Date()),
            sameDayRestart: true
        ).text
    }

    private static func timeOfDayLead(
        date: Date,
        calendar: Calendar
    ) -> (en: String, ru: String, zh: String) {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return ("Good morning", "Доброе утро", "早上好")
        case 12..<17: return ("Good afternoon", "Добрый день", "下午好")
        default: return ("Good evening", "Добрый вечер", "晚上好")
        }
    }

    private static func firstCheckInVariants(
        givenName: String?,
        date: Date,
        calendar: Calendar
    ) -> [OpeningLine] {
        let lead = timeOfDayLead(date: date, calendar: calendar)
        let name = givenName.flatMap { $0.isEmpty ? nil : $0 }

        var lines: [OpeningLine] = [
            OpeningLine(
                id: "open.tod.name",
                text: {
                    if let name {
                        return bi(
                            "\(lead.en), \(name). How are you feeling today?",
                            "\(lead.ru), \(name). Как вы себя чувствуете сегодня?",
                            chinese: "\(lead.zh)，\(name)。你今天感觉怎么样？"
                        )
                    }
                    return bi(
                        "\(lead.en). How are you feeling today?",
                        "\(lead.ru). Как вы себя чувствуете сегодня?",
                        chinese: "\(lead.zh)。你今天感觉怎么样？"
                    )
                }()
            ),
            OpeningLine(
                id: "open.quick.body",
                text: {
                    if let name {
                        return bi(
                            "\(name) — quick check-in. How’s your body feeling?",
                            "\(name) — короткий чек-ин. Как ощущается тело?",
                            chinese: "\(name)——快速确认一下。身体感觉如何？"
                        )
                    }
                    return bi(
                        "Quick check-in. How’s your body feeling?",
                        "Короткий чек-ин. Как ощущается тело?",
                        chinese: "快速确认一下。身体感觉如何？"
                    )
                }()
            ),
            OpeningLine(
                id: "open.energy.now",
                text: bi(
                    "How’s your energy right now?",
                    "Как сейчас с энергией?",
                    chinese: "你现在精力怎么样？"
                )
            ),
            OpeningLine(
                id: "open.soft.ask",
                text: {
                    if let name {
                        return bi(
                            "Hey \(name). How are you feeling?",
                            "Привет, \(name). Как самочувствие?",
                            chinese: "嗨，\(name)。你感觉怎么样？"
                        )
                    }
                    return bi(
                        "How are you feeling?",
                        "Как самочувствие?",
                        chinese: "你感觉怎么样？"
                    )
                }()
            )
        ]
        return lines
    }

    private static func returningCheckInVariants(givenName: String?) -> [OpeningLine] {
        let name = givenName.flatMap { $0.isEmpty ? nil : $0 }
        return [
            OpeningLine(
                id: "open.again.now",
                text: {
                    if let name {
                        return bi(
                            "Hey \(name). How are you feeling now?",
                            "Привет, \(name). Как вы себя чувствуете сейчас?",
                            chinese: "嗨，\(name)。你现在感觉怎么样？"
                        )
                    }
                    return bi(
                        "How are you feeling now?",
                        "Как вы себя чувствуете сейчас?",
                        chinese: "你现在感觉怎么样？"
                    )
                }()
            ),
            OpeningLine(
                id: "open.again.energy",
                text: bi(
                    "Another check-in. How’s energy right now?",
                    "Ещё один чек-ин. Как сейчас с энергией?",
                    chinese: "再确认一下。现在精力如何？"
                )
            ),
            OpeningLine(
                id: "open.again.body",
                text: {
                    if let name {
                        return bi(
                            "\(name), what’s your body telling you now?",
                            "\(name), что сейчас говорит тело?",
                            chinese: "\(name)，身体现在在告诉你什么？"
                        )
                    }
                    return bi(
                        "What’s your body telling you now?",
                        "Что сейчас говорит тело?",
                        chinese: "身体现在在告诉你什么？"
                    )
                }()
            ),
            OpeningLine(
                id: "open.again.short",
                text: bi(
                    "How are you feeling this time?",
                    "Как самочувствие на этот раз?",
                    chinese: "这次感觉怎么样？"
                )
            )
        ]
    }

    static func tiredClarifyPrompt() -> CoachBilingualText {
        bi("What are you noticing most?", "Что вы замечаете больше всего?")
    }

    static func mindPrompt() -> CoachBilingualText {
        topicPickPromptFirst()
    }

    /// Short post-feeling reply: acknowledge + ≤1 observation + mind prompt.
    static func conversationalReflection(
        feeling: CoachFeelingKind,
        clarification: CoachFeelingClarification?,
        outcome: CoachFeelingComparisonKind,
        evidence: CoachFeelingEvidenceSnapshot
    ) -> (text: CoachBilingualText, suggestions: [CoachAssistantChoice]) {
        _ = clarification
        _ = outcome
        let text = shortFeelingReply(feeling: feeling, evidence: evidence)
        return (text, areaStarterChoices())
    }

    /// Acknowledge + optional single observation + topic prompt.
    static func shortFeelingReply(
        feeling: CoachFeelingKind,
        evidence: CoachFeelingEvidenceSnapshot
    ) -> CoachBilingualText {
        let ack: CoachBilingualText = {
            switch feeling {
            case .tired:
                return bi("Got it — feeling tired.", "Понял — чувствуешь усталость.", chinese: "明白了——感觉有点累。")
            case .low:
                return bi("Got it — not great today.", "Понял — сегодня не очень.", chinese: "明白了——今天状态不太好。")
            case .okay:
                return bi("Got it.", "Понял.", chinese: "好的。")
            case .energized:
                return bi("Good to hear.", "Хорошо слышать.", chinese: "很高兴听到。")
            }
        }()

        let observation = primaryObservation(feeling: feeling, evidence: evidence)
        let mind = mindPrompt()

        if let observation {
            return bi(
                "\(ack.english) \(observation.english) \(mind.english)",
                "\(ack.russian) \(observation.russian) \(mind.russian)",
                chinese: "\(ack.chinese) \(observation.chinese) \(mind.chinese)"
            )
        }
        return bi(
            "\(ack.english) \(mind.english)",
            "\(ack.russian) \(mind.russian)",
            chinese: "\(ack.chinese) \(mind.chinese)"
        )
    }

    /// At most one useful observation, accurate to the evidence (never “typical” when below usual).
    static func primaryObservation(
        feeling: CoachFeelingKind,
        evidence: CoachFeelingEvidenceSnapshot
    ) -> CoachBilingualText? {
        let recoveryDelta: Int? = {
            guard let recovery = evidence.recoveryPercent,
                  let baseline = evidence.recoveryBaselinePercent else { return nil }
            return recovery - baseline
        }()
        let sleepDelta: Int? = {
            guard let sleep = evidence.sleepMinutes,
                  let baseline = evidence.sleepBaselineMinutes else { return nil }
            return sleep - baseline
        }()

        let recoveryLower = (recoveryDelta ?? 0) <= -CoachFeelingEvidenceRules.tiredRecoveryShortfallPoints
            || ((recoveryDelta ?? 0) < -CoachFeelingEvidenceRules.recoveryNearBaselinePoints)
        let sleepShorter = (sleepDelta ?? 0) <= -CoachFeelingEvidenceRules.tiredSleepShortfallMinutes
            || ((sleepDelta ?? 0) < -CoachFeelingEvidenceRules.sleepNearBaselineMinutes)

        // Prefer the clearest soft signal when present.
        if recoveryLower, let recovery = evidence.recoveryPercent {
            _ = recovery
            return bi(
                "Your recovery is below your usual range today.",
                "Восстановление сегодня ниже обычного диапазона."
            )
        }
        if sleepShorter {
            return bi(
                "You slept less than usual last night.",
                "Прошлой ночью вы спали меньше обычного."
            )
        }

        // Supporting “good” signals only when metrics are near/above usual.
        let recoveryNearOrUp = recoveryDelta.map {
            $0 >= -CoachFeelingEvidenceRules.recoveryNearBaselinePoints
        } ?? false
        let sleepNearOrUp = sleepDelta.map {
            $0 >= -CoachFeelingEvidenceRules.sleepNearBaselineMinutes
        } ?? false

        switch feeling {
        case .energized where recoveryNearOrUp || sleepNearOrUp:
            return bi(
                "Your recovery looks in good shape for you today.",
                "Восстановление сегодня выглядит для вас нормально."
            )
        case .okay where recoveryNearOrUp && sleepNearOrUp:
            return bi(
                "Your sleep and recovery look close to usual.",
                "Сон и восстановление близки к обычным."
            )
        case .tired where !recoveryLower && !sleepShorter
            && (evidence.recoveryPercent != nil || evidence.sleepMinutes != nil):
            return bi(
                "Your recorded sleep and recovery don’t fully explain it.",
                "Записанные сон и восстановление это объясняют не полностью."
            )
        case .low where !recoveryLower && !sleepShorter
            && (evidence.recoveryPercent != nil || evidence.sleepMinutes != nil):
            return bi(
                "Your recorded sleep and recovery don’t fully explain how you feel.",
                "Записанные сон и восстановление не полностью объясняют самочувствие."
            )
        default:
            if evidence.recoveryPercent == nil && evidence.sleepMinutes == nil {
                return nil
            }
            return nil
        }
    }

    static func areaStarterChoices(
        order: [CoachAssistantArea] = [.nutrition, .recovery, .activity]
    ) -> [CoachAssistantChoice] {
        order.map { area in
            switch area {
            case .nutrition:
                return .init(
                    id: "mind.nutrition",
                    title: bi("Nutrition", "Питание"),
                    destination: .nutritionGate
                )
            case .recovery:
                return .init(
                    id: "mind.recovery",
                    title: bi("Recovery", "Восстановление"),
                    destination: .recoveryGate
                )
            case .activity:
                return .init(
                    id: "mind.activity",
                    title: bi("Activity", "Активность"),
                    destination: .activityGate
                )
            }
        }
    }

    static func topicPickPrompt() -> CoachBilingualText {
        bi("What else do you want to look at?", "Что ещё посмотрим?")
    }

    static func topicPickPromptFirst() -> CoachBilingualText {
        bi("What shall we start with?", "С чего начнём?")
    }

    static func followUpEaseChoices() -> [CoachAssistantChoice] {
        [
            .init(
                id: "followup.ease.wentWell",
                title: bi("Yes", "Да"),
                destination: .activityToday
            ),
            .init(
                id: "followup.ease.skipped",
                title: bi("No", "Нет"),
                destination: .mindAsk
            ),
            .init(
                id: "followup.ease.stillDeciding",
                title: bi("Changed plans", "Планы изменились"),
                destination: .activityGate
            )
        ]
    }

    static func unavailableHealthDataCopy(authorized: Bool?) -> CoachBilingualText {
        // Only narrate authorization when it is affirmatively true.
        // false/nil both mean “unavailable for unknown reason” — never claim denial.
        if authorized == true {
            return bi(
                "Recent sleep, HRV, or resting heart rate readings aren’t available yet — they may still be syncing, or weren’t recorded.",
                "Свежих данных о сне, HRV или пульсе покоя пока нет — возможно, они ещё синхронизируются или не были записаны."
            )
        }
        return bi(
            "There isn’t enough recent sleep, HRV, or resting heart rate data available to personalize this yet.",
            "Пока недостаточно свежих данных о сне, HRV или пульсе покоя, чтобы персонализировать ответ."
        )
    }

    /// Fold at most one detail into the coach bubble (no external fact rows).
    static func bubbleText(
        _ primary: CoachBilingualText,
        detail: CoachBilingualText? = nil
    ) -> CoachBilingualText {
        guard let detail else { return primary }
        return bi(
            "\(primary.english) \(detail.english)",
            "\(primary.russian) \(detail.russian)",
            chinese: "\(primary.chinese) \(detail.chinese)"
        )
    }

    static func nutritionGateQuestion() -> CoachBilingualText {
        bi(
            "What would help with food today?",
            "Что будет полезно по питанию сегодня?"
        )
    }

    static func nutritionGateChoices() -> [CoachAssistantChoice] {
        [
            .init(
                id: "nutrition.helpChoose",
                title: bi("Next meal", "Следующий приём"),
                destination: .nutritionChooseMeal
            ),
            .init(
                id: "nutrition.remaining",
                title: bi("What’s left", "Что осталось"),
                destination: .nutritionRemaining
            )
        ]
    }

    static func recoveryGateQuestion() -> CoachBilingualText {
        bi(
            "Is this mostly about last night’s sleep, or has it been building for a few days?",
            "Это в основном про сон прошлой ночи, или так уже несколько дней?"
        )
    }

    static func recoveryGateChoices() -> [CoachAssistantChoice] {
        [
            .init(
                id: "recovery.justToday",
                title: bi("Last night", "Прошлая ночь"),
                destination: .recoveryToday
            ),
            .init(
                id: "recovery.fewDays",
                title: bi("A few days", "Несколько дней"),
                destination: .recoveryPattern
            )
        ]
    }

    static func activityGateQuestion() -> CoachBilingualText {
        bi(
            "What should we look at in your activity log?",
            "Что посмотрим в записях активности?"
        )
    }

    static func activityGateChoices() -> [CoachAssistantChoice] {
        [
            .init(
                id: "activity.todayBrief",
                title: bi("Today", "Сегодня"),
                destination: .activityToday
            ),
            .init(
                id: "activity.recent",
                title: bi("Last 7 days", "7 дней"),
                destination: .activityRecent
            ),
            .init(
                id: "activity.consistency",
                title: bi("Plan vs logged", "План и факты"),
                destination: .activityConsistency
            )
        ]
    }

    /// After a today / 7-day activity brief — stay past-focused; offer Recovery for sleep/HRV.
    static func activityTrendFollowUpChoices() -> [CoachAssistantChoice] {
        [
            .init(
                id: "activity.recent",
                title: bi("Last 7 days", "7 дней"),
                destination: .activityRecent
            ),
            .init(
                id: "mind.recovery",
                title: bi("Recovery", "Восстановление"),
                destination: .recoveryGate
            ),
            .init(
                id: "end.another",
                title: bi("Other topic", "Другая тема"),
                destination: .mindAsk
            ),
            .init(
                id: "end.done",
                title: bi("Done", "Готово"),
                destination: .end
            )
        ]
    }

    static func activityHistoryFollowUpChoices() -> [CoachAssistantChoice] {
        [
            .init(
                id: "mind.recovery",
                title: bi("Recovery", "Восстановление"),
                destination: .recoveryGate
            ),
            .init(
                id: "end.another",
                title: bi("Other topic", "Другая тема"),
                destination: .mindAsk
            ),
            .init(
                id: "end.done",
                title: bi("Done", "Готово"),
                destination: .end
            )
        ]
    }

    static func activityEffortChoices() -> [CoachAssistantChoice] {
        [
            .init(
                id: "activity.effort.easy",
                title: bi("Comfortable", "Комфортно"),
                destination: .activityToday
            ),
            .init(
                id: "activity.effort.moderate",
                title: bi("Moderate", "Умеренно"),
                destination: .activityToday
            ),
            .init(
                id: "activity.effort.hard",
                title: bi("Demanding", "Тяжеловато"),
                destination: .activityToday
            ),
            .init(
                id: "activity.effort.unsure",
                title: bi("Not sure", "Не уверен"),
                destination: .activityToday
            )
        ]
    }

    /// Short label for a completed session (title preferred over generic type).
    static func activityDisplayName(_ activity: CoachPlannedActivitySnapshot) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty, title.lowercased() != "workout", title.lowercased() != "activity" {
            return title
        }
        let type = activity.type.trimmingCharacters(in: .whitespacesAndNewlines)
        if !type.isEmpty, type.lowercased() != "workout", type.lowercased() != "meal" {
            return type.prefix(1).uppercased() + type.dropFirst()
        }
        return ""
    }

    /// Deduped bilingual summary of session names — “3 walks”, “2 walks and 1 ride”.
    static func activitySessionKindSummary(
        _ activities: [CoachPlannedActivitySnapshot]
    ) -> (en: String, ru: String)? {
        var counts: [(name: String, count: Int)] = []
        for activity in activities {
            let raw = activityDisplayName(activity)
            let name = raw.isEmpty ? "activity" : raw
            if let idx = counts.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                counts[idx].count += 1
            } else {
                counts.append((name, 1))
            }
        }
        guard !counts.isEmpty else { return nil }

        func pluralEN(_ name: String, _ n: Int) -> String {
            let lower = name.lowercased()
            if n == 1 { return lower }
            if lower.hasSuffix("s") || lower.hasSuffix("x") || lower.hasSuffix("ch") || lower.hasSuffix("sh") {
                return "\(n) \(lower)es"
            }
            if lower.hasSuffix("y"), let last = lower.dropLast().last, !"aeiou".contains(last) {
                return "\(n) \(lower.dropLast())ies"
            }
            return "\(n) \(lower)s"
        }
        func pluralRU(_ name: String, _ n: Int) -> String {
            // Keep the display name; Russian pluralization of activity titles is uneven.
            if n == 1 { return name }
            return "\(n)× \(name)"
        }

        let enParts = counts.map { pluralEN($0.name, $0.count) }
        let ruParts = counts.map { pluralRU($0.name, $0.count) }
        let en: String = {
            if enParts.count == 1 { return enParts[0] }
            if enParts.count == 2 { return "\(enParts[0]) and \(enParts[1])" }
            return enParts.dropLast().joined(separator: ", ") + ", and \(enParts.last!)"
        }()
        let ru: String = {
            if ruParts.count == 1 { return ruParts[0] }
            if ruParts.count == 2 { return "\(ruParts[0]) и \(ruParts[1])" }
            return ruParts.dropLast().joined(separator: ", ") + " и \(ruParts.last!)"
        }()
        return (en, ru)
    }

    /// EN/RU noun phrase identifying one completed session (duration / name / both).
    static func activitySessionPhrase(_ activity: CoachPlannedActivitySnapshot) -> (en: String, ru: String) {
        let minutes = max(1, activity.effectiveDurationMinutes)
        let name = activityDisplayName(activity)
        if name.isEmpty {
            return (
                "\(minutes)-minute activity",
                "активность на \(minutes) мин"
            )
        }
        return (
            "\(minutes)-minute \(name)",
            "\(name) (\(minutes) мин)"
        )
    }

    static func activityPickSessionPrompt() -> CoachBilingualText {
        bi(
            "You logged more than one activity today. Which session should we talk about?",
            "Сегодня записано больше одной активности. О какой сессии говорим?"
        )
    }

    static func activitySelectChoices(
        _ activities: [CoachPlannedActivitySnapshot]
    ) -> [CoachAssistantChoice] {
        activities.prefix(3).map { activity in
            let minutes = max(1, activity.effectiveDurationMinutes)
            let name = activityDisplayName(activity)
            let labelEN = name.isEmpty ? "\(minutes) min" : "\(name) · \(minutes) min"
            let labelRU = name.isEmpty ? "\(minutes) мин" : "\(name) · \(minutes) мин"
            return .init(
                id: "activity.select.\(activity.id)",
                title: bi(labelEN, labelRU),
                destination: .activityToday
            )
        }
    }

    /// Observation + exertion question with an explicit subject (never bare “it”).
    static func activityExertionAskText(
        activity: CoachPlannedActivitySnapshot,
        includeObservation: Bool
    ) -> CoachBilingualText {
        let phrase = activitySessionPhrase(activity)
        if includeObservation {
            return bi(
                "You logged an \(phrase.en) today. How demanding did that session feel?",
                "Сегодня записано: \(phrase.ru). Насколько напряжённой ощущалась эта сессия?"
            )
        }
        return bi(
            "How demanding did that \(phrase.en) feel?",
            "Насколько напряжённой ощущалась эта сессия (\(phrase.ru))?"
        )
    }

    static func activityIntensityChoices(offerEase: Bool) -> [CoachAssistantChoice] {
        var items: [CoachAssistantChoice] = [
            .init(
                id: "activity.keepEffort",
                title: bi("Keep planned effort", "Оставить запланированную нагрузку"),
                destination: .end
            )
        ]
        if offerEase {
            items.insert(
                .init(
                    id: "activity.proposeEase",
                    title: bi("Ease off a bit", "Сделать чуть легче"),
                    destination: .activityPlanConfirm
                ),
                at: 0
            )
        }
        return items + closingChoices()
    }

    // MARK: - Reflection (familiar wording)

    static func reflection(
        feeling: CoachFeelingKind,
        clarification: CoachFeelingClarification?,
        outcome: CoachFeelingComparisonKind,
        evidence: CoachFeelingEvidenceSnapshot
    ) -> (text: CoachBilingualText, facts: [CoachBilingualText], details: [CoachBilingualText]) {
        let text = shortFeelingReply(feeling: feeling, evidence: evidence)
        let legacy = CoachFeelingCopy.comparison(
            feeling: feeling,
            clarification: clarification,
            outcome: outcome,
            evidence: evidence
        )
        return (text, [], legacy.details)
    }

    private static func rewriteFact(_ fact: CoachBilingualText) -> CoachBilingualText {
        // Soften technical baseline phrasing in surface facts.
        let en = fact.english
            .replacingOccurrences(of: "recent baseline", with: "usual")
            .replacingOccurrences(of: "baseline", with: "usual")
        let ru = fact.russian
            .replacingOccurrences(of: "недавнего базового", with: "обычного")
            .replacingOccurrences(of: "базовый", with: "обычный")
            .replacingOccurrences(of: "базового", with: "обычного")
        return bi(en, ru)
    }

    // MARK: - Mind choices (area starters)

    static func mindChoices(
        feeling: CoachFeelingKind,
        hasPlannedWorkout: Bool,
        hasCompletedActivity: Bool
    ) -> [CoachAssistantChoice] {
        _ = hasPlannedWorkout
        _ = hasCompletedActivity
        let signals = CoachAssistantSignalSnapshot.build(
            checkInAt: Date(),
            observations: [],
            plannedActivities: [],
            nutrition: nil,
            recentActivityCount: 0,
            healthKitAuthorized: nil
        )
        let order = CoachAssistantInsightBuilder.orderedAreas(
            feeling: feeling,
            signals: signals,
            prefer: nil
        )
        return areaStarterChoices(order: order)
    }

    static func nutritionMenuChoices() -> [CoachAssistantChoice] {
        [
            .init(
                id: "nutrition.helpChoose",
                title: bi("Help me choose food", "Помоги выбрать еду"),
                destination: .nutritionChooseMeal
            ),
            .init(
                id: "nutrition.remaining",
                title: bi("Show what I have left", "Покажи, что осталось по целям"),
                destination: .nutritionRemaining
            ),
            .init(
                id: "nutrition.habits",
                title: bi("Look at my eating habits", "Посмотрим на привычки питания"),
                destination: .nutritionHabits
            )
        ]
    }

    static func closingChoices(includeOtherArea: Bool = true) -> [CoachAssistantChoice] {
        var items: [CoachAssistantChoice] = [
            .init(
                id: "end.done",
                title: bi("Done", "Готово"),
                destination: .end
            )
        ]
        if includeOtherArea {
            items.insert(
                .init(
                    id: "end.another",
                    title: bi("Other topic", "Другая тема"),
                    destination: .mindAsk
                ),
                at: 0
            )
        }
        return items
    }

    static func invitationBody(givenName: String?) -> CoachBilingualText {
        _ = givenName
        return bi(
            "A short chat about today’s sleep, training, and food.",
            "Короткий чат про сегодняшний сон, тренировки и еду."
        )
    }

    static func openMealsChoiceTitle() -> CoachBilingualText {
        bi("Open Meals", "Открыть Питание")
    }

    static func openProfileGoalsChoiceTitle() -> CoachBilingualText {
        bi("Open Profile", "Открыть Профиль")
    }

    static func reviewPlanSuggestionTitle() -> CoachBilingualText {
        bi("Review Plan suggestion", "Посмотреть идею для Плана")
    }

}
