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
                "Morning — yesterday logged real training load, sleep \(sleep), recovery \(facts.recoveryPercent)%.",
                "Утро — вчера была заметная нагрузка, сон \(sleepRU), энергия \(facts.recoveryPercent)%."
            )
        }
        return .en(
            "Morning — yesterday logged real training load — keep today's first block softer.",
            "Утро — вчера была заметная нагрузка — первый блок сегодня мягче."
        )
    }

    static func recoveryAfterHeavyYesterdayNextAction(for facts: CoachMorningBriefFacts) -> CoachBilingualText {
        if let activity = facts.nextActivity, facts.nextActivityIsImminent {
            return nextActionForImminentActivity(activity, facts: facts)
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

        // Mention the next workout at most once here — recommendation/next action stay distinct.
        if let activity = facts.nextActivity, facts.nextActivityIsImminent {
            let title = displayTitle(activity)
            return mergeOpener(
                opener,
                .en(
                    "Next up: \(title) at \(activity.formattedStartTime).",
                    "Дальше: \(title) в \(activity.formattedStartTime)."
                )
            )
        }

        if let activity = facts.nextActivity {
            let title = displayTitle(activity)
            return mergeOpener(
                opener,
                .en(
                    "Later today: \(title) at \(activity.formattedStartTime).",
                    "Позже сегодня: \(title) в \(activity.formattedStartTime)."
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
                "Сегодня в плане \(facts.todayActivityCount) блоков."
            )
        )
    }

    private static func recoveryOpener(_ facts: CoachMorningBriefFacts, prefix: OpenerPrefix) -> CoachBilingualText {
        guard facts.recoveryDataAvailable else {
            switch prefix {
            case .morning:
                return .en(
                    "Morning — recovery data is still catching up.",
                    "Утро — данные восстановления ещё подтягиваются."
                )
            case .plain:
                return .en("", "")
            }
        }

        let sleepEN = formatSleepHours(facts.sleepHours, russian: false)
        let sleepRU = formatSleepHours(facts.sleepHours, russian: true)
        let recovery = facts.recoveryPercent
        let recoveryLabelRU = "готовность"

        // Measured facts only — do not invent how legs/muscles feel from yesterday's load flag.
        if facts.hadHeavyYesterday {
            return .en(
                "Morning — yesterday logged real training load, sleep \(sleepEN), recovery at \(recovery)%.",
                "Утро — вчера была заметная нагрузка, сон \(sleepRU), \(recoveryLabelRU) \(recovery)%."
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
                "Утро — сон \(sleepRU), \(recoveryLabelRU) \(recovery)% — запас сил ещё не полный."
            )
        }

        return .en(
            "Morning — sleep \(sleepEN), recovery at \(recovery)%.",
            "Утро — сон \(sleepRU), \(recoveryLabelRU) \(recovery)%."
        )
    }

    // MARK: - Recommendation / avoid / next action

    private static func planRecommendation(_ facts: CoachMorningBriefFacts) -> CoachBilingualText {
        // Imminent prep owns the next-action slot — keep recommendation about pacing, not the same event.
        if facts.nextActivityIsImminent {
            if facts.sleepIsLow || facts.recoveryBand == .low {
                return .en(
                    "Keep the first minutes easy — recovery is still building.",
                    "Первые минуты легче — тело ещё восстанавливается."
                )
            }
            if facts.hadHeavyYesterday {
                return .en(
                    "Start steadier than yesterday's peak effort.",
                    "Начните ровнее, чем вчерашний пик."
                )
            }
            return .en(
                "Warm up first, then settle into the planned effort.",
                "Сначала разминка, потом плановый темп."
            )
        }

        if facts.nextActivity != nil {
            // Event already named in assessment — give a morning action, not a second echo.
            if facts.hadHeavyYesterday || facts.recoveryBand == .low || facts.sleepIsLow {
                return .en(
                    "Keep the morning easy until that session is closer.",
                    "Держите утро спокойным, пока сессия не станет ближе."
                )
            }
            return .en(
                "Use the morning for fuel, hydration, and an easy warmup walk.",
                "Утро — для еды, воды и лёгкой разминочной прогулки."
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
                "Первый блок легче — тело ещё восстанавливается."
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
            "Выберите один главный блок и сделайте его до полудня."
        )
    }

    private static func morningAvoid(_ facts: CoachMorningBriefFacts) -> CoachBilingualText {
        if facts.hadHeavyYesterday {
            return .en(
                "Don't chase yesterday's numbers or stack hard blocks early.",
                "Не гонитесь за вчерашними цифрами и не добавляйте нагрузку с утра."
            )
        }
        if facts.sleepIsLow || facts.recoveryBand == .low {
            return .en(
                "Don't open with full intensity — the tank isn't full yet.",
                "Не начинайте на полной — бак ещё не полный."
            )
        }
        if facts.nextActivityIsImminent {
            return .en(
                "Don't skip warmup or rush the opening minutes.",
                "Не пропускайте разминку и не торопите первые минуты."
            )
        }
        // No useful caution — omit section via empty copy.
        return .en("", "")
    }

    private static func morningNextAction(_ facts: CoachMorningBriefFacts) -> CoachBilingualText {
        if let activity = facts.nextActivity, facts.nextActivityIsImminent {
            return nextActionForImminentActivity(activity, facts: facts)
        }
        if facts.hadHeavyYesterday || facts.recoveryBand == .low {
            return .en(
                "Walk 15 minutes, then stretch before planning anything hard.",
                "15 минут прогулки и растяжка — прежде чем планировать что-то тяжёлое."
            )
        }
        return .en(
            "Take a 10-minute walk or stretch, then pick today's first block.",
            "10 минут прогулки или растяжки — потом выберите первый блок дня."
        )
    }

    private static func nextActionForImminentActivity(
        _ activity: CoachPlannedActivitySummary,
        facts: CoachMorningBriefFacts
    ) -> CoachBilingualText {
        let title = displayTitle(activity)
        let time = activity.formattedStartTime
        let minutesOut = facts.minutesUntilNextActivity
        let farLead = CoachActivityWindowPolicy.beforeSessionCopyWindowMinutes

        switch activity.activityType {
        case .cycling, .running, .swimming, .hiit:
            if let minutes = minutesOut, minutes > 45 {
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
        case .stretching, .yoga, .breathing, .sauna:
            return .en(
                "Settle in a few minutes early — \(title) at \(time).",
                "Приходите чуть раньше — \(title) в \(time)."
            )
        case .none:
            // Neutral fallback — never invent gear/arrival language for unknown types.
            if let minutes = minutesOut, minutes <= farLead {
                return .en(
                    "Be ready around \(time) for \(title).",
                    "Будьте готовы около \(time) к \(title)."
                )
            }
            return .en(
                "Take a 10-minute walk or stretch before the day fills in.",
                "10 минут прогулки или растяжки, пока день не заполнился."
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
            return .en("Recovery day", "Спокойный день восстановления")
        case .protectTomorrowFresh:
            return .en("Save it for tomorrow", "Сохраните запас на завтра")
        default:
            if facts.recoveryBand == .low || facts.sleepIsLow {
                return .en("Easy morning", "Лёгкое утро")
            }
            return .en("Good morning", "Доброе утро")
        }
    }

    private static func teaserMessage(_ facts: CoachMorningBriefFacts, scenario: CoachScenarioKey) -> CoachBilingualText {
        if let activity = facts.nextActivity, facts.nextActivityIsImminent {
            let title = displayTitle(activity)
            return .en(
                "\(title) at \(activity.formattedStartTime) — prep from \(prepStartTime(activity, leadMinutes: 15)).",
                "\(title) в \(activity.formattedStartTime) — готовьтесь с \(prepStartTime(activity, leadMinutes: 15))."
            )
        }

        if let activity = facts.nextActivity {
            let title = displayTitle(activity)
            return .en(
                "\(title) later at \(activity.formattedStartTime).",
                "\(title) позже в \(activity.formattedStartTime)."
            )
        }

        switch scenario {
        case .recoveryAfterHeavyYesterday:
            return .en(
                "Yesterday's training load is logged — keep the morning easy.",
                "Вчерашняя нагрузка в логе — утро держите лёгким."
            )
        case .protectTomorrowFresh:
            return .en(
                "Keep today easy — tomorrow needs capacity.",
                "Сегодня легко — завтра нужен запас."
            )
        default:
            return .en(
                "Pick one priority block before noon.",
                "Выберите один главный блок и сделайте его до полудня."
            )
        }
    }

    private static func teaserHeadline(_ facts: CoachMorningBriefFacts, scenario: CoachScenarioKey) -> CoachBilingualText {
        // “Before session” only inside the prep window for a real classified workout.
        if let activity = facts.nextActivity, facts.nextActivityIsImminent {
            switch activity.activityType {
            case .cycling:
                return .en("Before the ride", "Перед заездом")
            case .running:
                return .en("Before the run", "Перед пробежкой")
            case .swimming:
                return .en("Before the swim", "Перед плаванием")
            case .hiit:
                return .en("Before HIIT", "Перед HIIT")
            case .tennis, .squash:
                return .en("Before the match", "Перед игрой")
            case .upperBody, .lowerBody, .core, .fullBody:
                return .en("Before lifting", "Перед силовой")
            case .walk:
                return .en("Before the walk", "Перед прогулкой")
            case .stretching, .yoga, .breathing, .sauna:
                return .en("Before recovery", "Перед восстановлением")
            case .none:
                return .en("Morning plan", "План на утро")
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
        case .swimming:
            return russian ? "Заплыв" : "Swim"
        case .hiit:
            return "HIIT"
        case .tennis:
            return russian ? "Теннис" : "Tennis"
        case .squash:
            return russian ? "Сквош" : "Squash"
        case .upperBody, .lowerBody, .core, .fullBody:
            return russian ? "Силовая" : "Strength"
        case .walk:
            return russian ? "Прогулка" : "Walk"
        default:
            return russian ? "Активность" : "Activity"
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
