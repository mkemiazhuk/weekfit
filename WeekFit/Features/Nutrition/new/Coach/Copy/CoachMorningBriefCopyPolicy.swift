import Foundation

/// Instructional morning copy — sleep/recovery facts, today's plan, one concrete next step.
enum CoachMorningBriefCopyPolicy {

    struct Pack {
        let assessment: CoachBilingualText
        let recommendation: CoachBilingualText
        let avoid: CoachBilingualText
        let nextAction: CoachBilingualText
    }

    struct Teaser {
        let todayTitle: CoachBilingualText
        let todayMessage: CoachBilingualText
        let coachHeadline: CoachBilingualText
    }

    // MARK: - Registry packs

    static func morningReadinessPack(for facts: CoachMorningBriefFacts) -> Pack {
        Pack(
            assessment: morningAssessment(facts),
            recommendation: planRecommendation(facts),
            avoid: morningAvoid(facts),
            nextAction: morningNextAction(facts)
        )
    }

    static func protectTomorrowFreshAssessment(
        facts: CoachMorningBriefFacts,
        tomorrowWorkout: CoachTomorrowWorkout?
    ) -> CoachBilingualText {
        let opener = recoveryOpener(facts, prefix: .morning)
        guard let workout = tomorrowWorkout else {
            return mergeOpener(
                opener,
                .en(
                    "Tomorrow already has real work — keep today calm.",
                    "Завтра серьёзная работа — сегодня спокойно."
                )
            )
        }

        let title = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return mergeOpener(
                opener,
                .en(
                    "Tomorrow already has real work on the calendar.",
                    "Завтра в календаре серьёзная работа."
                )
            )
        }

        let titles = CoachWorkoutTitleLocalization.tomorrowAlreadyScheduled(rawTitle: title)
        return mergeOpener(
            opener,
            .en(titles.english, titles.russian)
        )
    }

    static func recoveryAfterHeavyYesterdayAssessment(for facts: CoachMorningBriefFacts) -> CoachBilingualText {
        if facts.recoveryDataAvailable {
            let sleep = formatSleepHours(facts.sleepHours, russian: false)
            let sleepRU = formatSleepHours(facts.sleepHours, russian: true)
            return .en(
                "Morning — yesterday's load is still in the legs, sleep \(sleep), recovery \(facts.recoveryPercent)%.",
                "Утро — вчера ещё в теле, сон \(sleepRU), готовность \(facts.recoveryPercent)%."
            )
        }
        return .en(
            "Morning — yesterday's load is still in the legs — today needs a softer line.",
            "Утро — вчерашняя нагрузка ещё чувствуется — сегодня мягче."
        )
    }

    static func recoveryAfterHeavyYesterdayNextAction(for facts: CoachMorningBriefFacts) -> CoachBilingualText {
        if let activity = facts.nextActivity {
            return nextActionForActivity(activity, facts: facts, prepLeadMinutes: 20)
        }
        return .en(
            "Walk 15 minutes, then stretch before anything demanding.",
            "15 минут прогулки и растяжка — перед любой нагрузкой."
        )
    }

    // MARK: - Teaser

    static func teaser(for facts: CoachMorningBriefFacts, scenario: CoachScenarioKey) -> Teaser {
        Teaser(
            todayTitle: teaserTitle(facts, scenario: scenario),
            todayMessage: teaserMessage(facts, scenario: scenario),
            coachHeadline: teaserHeadline(facts, scenario: scenario)
        )
    }

    // MARK: - Assessment

    private enum OpenerPrefix {
        case morning
        case plain
    }

    private static func morningAssessment(_ facts: CoachMorningBriefFacts) -> CoachBilingualText {
        let opener = recoveryOpener(facts, prefix: .morning)

        if let activity = facts.nextActivity {
            let title = displayTitle(activity)
            return mergeOpener(
                opener,
                .en(
                    "Next up: \(title) at \(activity.formattedStartTime).",
                    "Дальше: \(title) в \(activity.formattedStartTime)."
                )
            )
        }

        if facts.todayActivityCount == 0 {
            return mergeOpener(
                opener,
                .en(
                    "Nothing heavy is on the calendar yet.",
                    "В календаре пока ничего тяжёлого."
                )
            )
        }

        return mergeOpener(
            opener,
            .en(
                "\(facts.todayActivityCount) sessions planned today.",
                "Сегодня \(facts.todayActivityCount) блоков в плане."
            )
        )
    }

    private static func recoveryOpener(_ facts: CoachMorningBriefFacts, prefix: OpenerPrefix) -> CoachBilingualText {
        guard facts.recoveryDataAvailable else {
            switch prefix {
            case .morning:
                return .en(
                    "Morning — check legs and sleep before the day picks up speed.",
                    "Утро — оцените ноги и сон, прежде чем день разгонится."
                )
            case .plain:
                return .en("", "")
            }
        }

        let sleepEN = formatSleepHours(facts.sleepHours, russian: false)
        let sleepRU = formatSleepHours(facts.sleepHours, russian: true)
        let recovery = facts.recoveryPercent
        let recoveryLabelRU = "готовность"

        if facts.hadHeavyYesterday && facts.recoveryBand == .good {
            return .en(
                "Morning — legs still hold yesterday's load, recovery at \(recovery)%.",
                "Утро — ноги помнят вчера, \(recoveryLabelRU) \(recovery)%."
            )
        }

        if facts.sleepIsLow || facts.recoveryBand == .low {
            return .en(
                "Morning — short night at \(sleepEN), recovery at \(recovery)%.",
                "Утро — короткая ночь \(sleepRU), \(recoveryLabelRU) \(recovery)%."
            )
        }

        if facts.recoveryBand == .moderate {
            return .en(
                "Morning — sleep \(sleepEN), recovery at \(recovery)% — not fully topped up.",
                "Утро — сон \(sleepRU), \(recoveryLabelRU) \(recovery)% — ещё не на полном запасе."
            )
        }

        return .en(
            "Morning — sleep \(sleepEN), recovery at \(recovery)%.",
            "Утро — сон \(sleepRU), \(recoveryLabelRU) \(recovery)%."
        )
    }

    // MARK: - Recommendation / avoid / next action

    private static func planRecommendation(_ facts: CoachMorningBriefFacts) -> CoachBilingualText {
        if let activity = facts.nextActivity {
            let title = displayTitle(activity)
            let duration = activity.durationMinutes
            if facts.seriousActivityCount > 1 {
                return .en(
                    "Lead with \(title) at \(activity.formattedStartTime) — \(duration) min, then hold the rest steady.",
                    "Начните с \(title) в \(activity.formattedStartTime) — \(duration) мин, остальное ровно."
                )
            }
            return .en(
                "First block: \(title) at \(activity.formattedStartTime) — \(duration) min on the plan.",
                "Первый блок: \(title) в \(activity.formattedStartTime) — \(duration) мин по плану."
            )
        }

        if let tomorrow = facts.tomorrowWorkout,
           !tomorrow.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let title = tomorrow.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return .en(
                "Open morning — \(title) is tomorrow at \(tomorrow.formattedStartTime).",
                "Свободное утро — \(title) завтра в \(tomorrow.formattedStartTime)."
            )
        }

        if facts.sleepIsLow || facts.recoveryBand == .low {
            return .en(
                "Keep the first block light — recovery is still building.",
                "Первый блок легче — восстановление ещё набирается."
            )
        }

        if facts.recoveryBand == .moderate {
            return .en(
                "Start steady — leave room to feel better by midday.",
                "Начните ровно — к полудню должно стать легче."
            )
        }

        return .en(
            "Anchor one priority block before noon.",
            "Зафиксируйте один приоритетный блок до полудня."
        )
    }

    private static func morningAvoid(_ facts: CoachMorningBriefFacts) -> CoachBilingualText {
        if facts.hadHeavyYesterday {
            return .en(
                "Don't chase yesterday's numbers or stack hard blocks early.",
                "Не гонитесь за вчерашними цифрами и не добавляйте тяжести с утра."
            )
        }
        if facts.sleepIsLow || facts.recoveryBand == .low {
            return .en(
                "Don't open with full intensity — the tank isn't full yet.",
                "Не начинайте на полной — запас ещё не полный."
            )
        }
        if facts.seriousActivityCount > 0 {
            return .en(
                "Don't skip warmup or rush the first block.",
                "Не пропускайте разминку и не торопите первый блок."
            )
        }
        return .en(
            "Don't turn the first hour into a race.",
            "Не устраивайте гонку с самого утра."
        )
    }

    private static func morningNextAction(_ facts: CoachMorningBriefFacts) -> CoachBilingualText {
        if let activity = facts.nextActivity {
            return nextActionForActivity(activity, facts: facts, prepLeadMinutes: 45)
        }
        if facts.hadHeavyYesterday || facts.recoveryBand == .low {
            return .en(
                "Walk 15 minutes, then stretch before planning anything hard.",
                "15 минут прогулки и растяжка — перед планированием нагрузки."
            )
        }
        return .en(
            "Take a 10-minute walk or stretch, then pick today's first block.",
            "10 минут прогулки или растяжки — потом выберите первый блок дня."
        )
    }

    private static func nextActionForActivity(
        _ activity: CoachPlannedActivitySummary,
        facts: CoachMorningBriefFacts,
        prepLeadMinutes: Int
    ) -> CoachBilingualText {
        let title = displayTitle(activity)
        let time = activity.formattedStartTime
        let minutesOut = facts.minutesUntilNextActivity

        switch activity.activityType {
        case .cycling, .running:
            if let minutes = minutesOut, minutes > prepLeadMinutes {
                return .en(
                    "Eat a light breakfast now if you haven't — \(title) at \(time).",
                    "Лёгкий завтрак, если ещё не ели — \(title) в \(time)."
                )
            }
            return .en(
                "10-minute warmup — \(title) starts at \(time).",
                "10 минут разминки — \(title) в \(time)."
            )
        case .tennis, .squash:
            return .en(
                "Warm up 15 minutes — \(title) at \(time).",
                "15 минут разминки — \(title) в \(time)."
            )
        case .upperBody, .lowerBody, .core, .fullBody:
            return .en(
                "First sets light — \(title) at \(time), form before load.",
                "Первые подходы легко — \(title) в \(time), форма важнее."
            )
        case .walk:
            return .en(
                "Head out for \(title) at \(time) — easy pace, no target.",
                "Выходите на \(title) в \(time) — лёгкий темп, без цели."
            )
        default:
            return .en(
                "Prep gear and arrive 10 minutes early — \(title) at \(time).",
                "Соберите форму и приходите за 10 минут — \(title) в \(time)."
            )
        }
    }

    // MARK: - Teaser lines

    private static func teaserTitle(
        _ facts: CoachMorningBriefFacts,
        scenario: CoachScenarioKey
    ) -> CoachBilingualText {
        switch scenario {
        case .recoveryAfterHeavyYesterday:
            return .en("Recovery day", "День восстановления")
        case .protectTomorrowFresh:
            return .en("Save it for tomorrow", "Сохраните запас на завтра")
        default:
            if facts.recoveryBand == .low || facts.sleepIsLow {
                return .en("Easy morning", "Спокойного утра")
            }
            return .en("Good morning", "Доброе утро")
        }
    }

    private static func teaserMessage(_ facts: CoachMorningBriefFacts, scenario: CoachScenarioKey) -> CoachBilingualText {
        if let activity = facts.nextActivity {
            let title = displayTitle(activity)
            return .en(
                "\(title) at \(activity.formattedStartTime) — prep from \(prepStartTime(activity, leadMinutes: 15)).",
                "\(title) в \(activity.formattedStartTime) — готовьтесь с \(prepStartTime(activity, leadMinutes: 15))."
            )
        }

        switch scenario {
        case .recoveryAfterHeavyYesterday:
            return .en(
                "Yesterday still counts — walk before anything hard.",
                "Вчера ещё в теле — прогулка перед нагрузкой."
            )
        case .protectTomorrowFresh:
            return .en(
                "Keep today easy — tomorrow needs fresh legs.",
                "Сегодня легко — завтра нужны свежие ноги."
            )
        default:
            return .en(
                "Pick one priority block before noon.",
                "Выберите один приоритетный блок до полудня."
            )
        }
    }

    private static func teaserHeadline(_ facts: CoachMorningBriefFacts, scenario: CoachScenarioKey) -> CoachBilingualText {
        if let activity = facts.nextActivity {
            switch activity.activityType {
            case .cycling:
                return .en("Before the ride", "Перед заездом")
            case .running:
                return .en("Before the run", "Перед пробежкой")
            case .tennis, .squash:
                return .en("Before the match", "Перед игрой")
            case .upperBody, .lowerBody, .core, .fullBody:
                return .en("Before lifting", "Перед силовой")
            case .walk:
                return .en("Before the walk", "Перед прогулкой")
            default:
                return .en("Before session", "Перед тренировкой")
            }
        }

        switch scenario {
        case .recoveryAfterHeavyYesterday:
            return .en("Recovery morning", "Утро восстановления")
        case .protectTomorrowFresh:
            return .en("Save it for tomorrow", "Сохраните запас на завтра")
        default:
            return .en("Morning plan", "План на утро")
        }
    }

    // MARK: - Helpers

    private static func mergeOpener(_ opener: CoachBilingualText, _ tail: CoachBilingualText) -> CoachBilingualText {
        guard !opener.english.isEmpty else { return tail }
        return .en(
            "\(opener.english) \(tail.english)",
            "\(opener.russian) \(tail.russian)"
        )
    }

    private static func displayTitle(_ activity: CoachPlannedActivitySummary) -> String {
        let trimmed = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? activityTypeLabel(activity.activityType, russian: false) : trimmed
    }

    private static func activityTypeLabel(_ type: CoachActivityType, russian: Bool) -> String {
        switch type {
        case .cycling:
            return russian ? "Заезд" : "Ride"
        case .running:
            return russian ? "Пробежка" : "Run"
        case .tennis:
            return russian ? "Теннис" : "Tennis"
        case .squash:
            return russian ? "Сквош" : "Squash"
        case .upperBody, .lowerBody, .core, .fullBody:
            return russian ? "Силовая" : "Strength"
        case .walk:
            return russian ? "Прогулка" : "Walk"
        default:
            return russian ? "Тренировка" : "Session"
        }
    }

    private static func formatSleepHours(_ hours: Double, russian: Bool) -> String {
        let totalMinutes = max(0, Int((hours * 60).rounded()))
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if russian {
            if m == 0 { return "\(h)ч" }
            return "\(h)ч \(m)м"
        }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private static func prepStartTime(_ activity: CoachPlannedActivitySummary, leadMinutes: Int) -> String {
        let total = activity.startHour * 60 + activity.startMinute - leadMinutes
        let normalized = ((total % (24 * 60)) + (24 * 60)) % (24 * 60)
        return String(format: "%d:%02d", normalized / 60, normalized % 60)
    }
}
