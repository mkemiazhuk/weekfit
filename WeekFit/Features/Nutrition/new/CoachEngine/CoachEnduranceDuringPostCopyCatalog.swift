import Foundation

enum CoachEnduranceDuringPostCopyCatalog {

    struct BilingualText: Hashable {
        let english: String
        let russian: String
    }

    struct ActionCopy {
        let type: CoachSupportActionTypeV3
        let title: BilingualText
        let subtitle: BilingualText
    }

    struct WindowCopy {
        let hero: BilingualText
        let assessment: BilingualText
        let situation: BilingualText
        let primary: ActionCopy
        let avoidance: BilingualText
        let extras: [ActionCopy]
    }

    struct ReasonCopy {
        let kind: CoachFinalStoryReason.Kind
        let english: String
        let russian: String
        let icon: String
        let colorFamily: CoachFinalStoryColorFamily
    }

    enum Phase {
        case pacing
        case sustainable
        case fueling
        case hydration
        case postLong
        case postMedium
        case postShort
    }

    enum PostTiming {
        case immediate
        case settled
        case stale

        static func from(minutesSinceEnd: Int) -> PostTiming {
            if minutesSinceEnd >= 240 { return .stale }
            if minutesSinceEnd >= 90 { return .settled }
            return .immediate
        }
    }

    struct PostContext {
        let recoveryPercent: Int
        let caloriesBurned: Double
        let shouldProtectTomorrow: Bool
        let timePhase: CoachFinalDecisionTimeOfDay
    }

    static func window(
        for phase: Phase,
        activity: PlannedActivity?,
        longSession: Bool,
        minutesSinceEnd: Int = 0,
        postContext: PostContext? = nil
    ) -> WindowCopy {
        let modality = CoachSessionPrepCopyCatalog.modality(for: activity)
        let postTiming = PostTiming.from(minutesSinceEnd: minutesSinceEnd)
        switch (phase, modality) {
        case (.pacing, .cycling):
            return pacingCycling(longSession: longSession)
        case (.pacing, .running):
            return pacingRunning(longSession: longSession)
        case (.pacing, _):
            return pacingGeneral(longSession: longSession)
        case (.sustainable, .cycling):
            return sustainableCycling(longSession: longSession)
        case (.sustainable, .running):
            return sustainableRunning(longSession: longSession)
        case (.sustainable, _):
            return sustainableGeneral(longSession: longSession)
        case (.fueling, .cycling):
            return fuelingCycling()
        case (.fueling, .running):
            return fuelingRunning()
        case (.fueling, _):
            return fuelingGeneral()
        case (.hydration, _):
            return hydrationGeneral()
        case (.postLong, .cycling):
            return postLongCycling(timing: postTiming, context: postContext)
        case (.postLong, .running):
            return postLongRunning(timing: postTiming, context: postContext)
        case (.postLong, _):
            return postLongGeneral(timing: postTiming, context: postContext)
        case (.postMedium, _):
            return postMediumGeneral(timing: postTiming, context: postContext)
        case (.postShort, _):
            return postShortGeneral(timing: postTiming, context: postContext)
        }
    }

    static func reasons(
        for phase: Phase,
        activity: PlannedActivity?,
        elapsedMinutes: Int,
        remainingMinutes: Int?,
        recoveryPercent: Int,
        caloriesBurned: Double,
        shouldProtectTomorrow: Bool,
        minutesSinceEnd: Int = 0
    ) -> [ReasonCopy] {
        switch phase {
        case .pacing:
            var items: [ReasonCopy] = []
            if let remainingMinutes, remainingMinutes > 0 {
                items.append(
                    ReasonCopy(
                        kind: .time,
                        english: "About \(remainingMinutes) minutes of work remain.",
                        russian: "Впереди ещё около \(remainingMinutes) минут работы.",
                        icon: "clock.fill",
                        colorFamily: .ready
                    )
                )
            }
            items.append(
                ReasonCopy(
                    kind: .recovery,
                    english: recoveryPercent >= 75
                        ? "Recovery still gives room to build into the session."
                        : "Recovery is limited, so the opening should stay conservative.",
                    russian: recoveryPercent >= 75
                        ? "Восстановление ещё даёт запас нарастить нагрузку."
                        : "Восстановление ограничено — старт лучше держать консервативным.",
                    icon: "heart.fill",
                    colorFamily: .recovery
                )
            )
            return Array(items.prefix(2))

        case .sustainable:
            var items: [ReasonCopy] = []
            if let remainingMinutes, remainingMinutes > 45 {
                items.append(
                    ReasonCopy(
                        kind: .time,
                        english: "More than \(remainingMinutes / 60) hour\(remainingMinutes >= 120 ? "s" : "") of work still ahead.",
                        russian: remainingMinutes >= 120
                            ? "Впереди ещё больше \(remainingMinutes / 60) часов работы."
                            : "Впереди ещё больше часа работы.",
                        icon: "clock.fill",
                        colorFamily: .ready
                    )
                )
            } else if elapsedMinutes > 0 {
                items.append(
                    ReasonCopy(
                        kind: .time,
                        english: "You are \(elapsedMinutes) minutes into the session.",
                        russian: "Вы уже \(elapsedMinutes) минут в сессии.",
                        icon: "clock.fill",
                        colorFamily: .ready
                    )
                )
            }
            items.append(
                ReasonCopy(
                    kind: .fuel,
                    english: "Regular fuel now keeps the second half steadier.",
                    russian: "Регулярное питание сейчас сделает вторую половину ровнее.",
                    icon: "bolt.fill",
                    colorFamily: .fuel
                )
            )
            return Array(items.prefix(2))

        case .fueling:
            return [
                ReasonCopy(
                    kind: .fuel,
                    english: "Carb intake is behind what this workload needs.",
                    russian: "Углеводов меньше, чем требует текущая нагрузка.",
                    icon: "bolt.fill",
                    colorFamily: .fuel
                ),
                ReasonCopy(
                    kind: .time,
                    english: remainingMinutes.map { "Roughly \($0) minutes of work remain." } ?? "There is still meaningful work ahead.",
                    russian: remainingMinutes.map { "Примерно \($0) минут работы впереди." } ?? "Впереди ещё заметная работа.",
                    icon: "clock.fill",
                    colorFamily: .ready
                )
            ]

        case .hydration:
            return [
                ReasonCopy(
                    kind: .hydration,
                    english: "Fluid intake is behind the session demand.",
                    russian: "Воды меньше, чем требует сессия.",
                    icon: "drop.fill",
                    colorFamily: .hydration
                ),
                ReasonCopy(
                    kind: .time,
                    english: remainingMinutes.map { "About \($0) minutes remain to correct this." } ?? "There is still time to correct this.",
                    russian: remainingMinutes.map { "Ещё около \($0) минут, чтобы это исправить." } ?? "Ещё есть время это исправить.",
                    icon: "clock.fill",
                    colorFamily: .ready
                )
            ]

        case .postLong, .postMedium, .postShort:
            return []

        }
    }

    static func extras(
        for phase: Phase,
        activity: PlannedActivity?,
        longSession: Bool,
        minutesSinceEnd: Int = 0
    ) -> [ActionCopy] {
        let postTiming = PostTiming.from(minutesSinceEnd: minutesSinceEnd)
        switch phase {
        case .pacing:
            let modality = CoachSessionPrepCopyCatalog.modality(for: activity)
            if modality == .cycling {
                return [
                    action(.steadyHydration, "Sip from your bottle", "Small mouthfuls only", "Глоток из бутылки", "Только маленькими глотками")
                ]
            }
            return [
                action(.steadyHydration, "Sip if thirsty", "No need to drink a lot now", "Глоток при жажде", "Много пить сейчас не нужно")
            ]
        case .sustainable:
            return [
                action(.steadyHydration, "Drink with each fueling block", "Small sips, not a full bottle at once", "Пейте с каждым приёмом пищи", "Маленькими глотками, не залпом")
            ]
        case .fueling:
            return [
                action(.steadyHydration, "Drink 300-500 ml over 20 minutes", "Pair fluid with the carbs", "Выпейте 300-500 мл за 20 минут", "Совместите воду с углеводами")
            ]
        case .hydration:
            return [
                action(.sustainEnergy, "Take a small carb top-up if needed", "Only if energy is fading", "Небольшой перекус углеводов при необходимости", "Только если падает энергия")
            ]
        case .postLong:
            switch postTiming {
            case .immediate:
                return [
                    action(.rehydrateGradually, "Drink 500-750 ml over the next hour", "Spread it out, not all at once", "500-750 мл в течение часа", "Растяните, не залпом"),
                    action(.sleepPriority, "Protect sleep tonight", "That is where endurance recovery happens", "Берегите сон сегодня", "Там идёт основное восстановление")
                ]
            case .settled:
                return [
                    action(.sleepPriority, "Protect sleep tonight", "That is where endurance recovery happens", "Берегите сон сегодня", "Там идёт основное восстановление")
                ]
            case .stale:
                return [
                    action(.sleepPriority, "Keep the evening calm", "Sleep is the main recovery lever now", "Спокойный вечер", "Сон сейчас главный рычаг восстановления")
                ]
            }
        case .postMedium:
            switch postTiming {
            case .immediate:
                return [
                    action(.rehydrateGradually, "Drink 300-500 ml over the next hour", "Small sips through the hour", "300-500 мл в течение часа", "Маленькими глотками в течение часа")
                ]
            case .settled, .stale:
                return [
                    action(.sleepPriority, "Protect sleep tonight", "Let the body finish recovering overnight", "Берегите сон сегодня", "Дайте телу доработать восстановление ночью")
                ]
            }
        case .postShort:
            return []
        }
    }

    static func minutesSinceEnd(activity: PlannedActivity?, now: Date) -> Int {
        guard let activity else { return 0 }
        let end = activity.date.addingTimeInterval(TimeInterval(max(activity.effectiveDurationMinutes, 1) * 60))
        return max(0, Int(now.timeIntervalSince(end) / 60))
    }

    static func remainingMinutes(activity: PlannedActivity?, now: Date) -> Int? {
        guard let activity else { return nil }
        let elapsed = max(0, Int(now.timeIntervalSince(activity.date) / 60))
        let total = max(max(activity.effectiveDurationMinutes, activity.durationMinutes), 1)
        return max(total - elapsed, 0)
    }

    static func elapsedMinutes(activity: PlannedActivity?, now: Date) -> Int {
        guard let activity else { return 0 }
        return max(0, Int(now.timeIntervalSince(activity.date) / 60))
    }

    private static func bi(_ english: String, _ russian: String) -> BilingualText {
        BilingualText(english: english, russian: russian)
    }

    private static func action(
        _ type: CoachSupportActionTypeV3,
        _ titleEN: String,
        _ subtitleEN: String,
        _ titleRU: String,
        _ subtitleRU: String
    ) -> ActionCopy {
        ActionCopy(
            type: type,
            title: bi(titleEN, titleRU),
            subtitle: bi(subtitleEN, subtitleRU)
        )
    }

    // MARK: - Pacing

    private static func pacingCycling(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Ease into the ride", "Войдите в поездку плавно"),
            assessment: bi(
                "The ride just started — breathing and legs need a few minutes to settle.",
                "Поездка только началась — дыханию и ногам нужно несколько минут."
            ),
            situation: bi("Check bottles and cadence, not power.", "Проверьте бутылки и ритм, не мощность."),
            primary: action(
                .controlIntensity,
                "Keep the next 10 minutes easy",
                "Add effort only when breathing settles",
                "Следующие 10 минут держите легко",
                "Добавляйте усилие, когда дыхание успокоится"
            ),
            avoidance: bi(
                longSession ? "Do not chase groups or climbs in the first kilometres." : "Do not sprint from the first corner.",
                longSession ? "Не гонитесь за группой или подъёмами в первых километрах." : "Не рваните с первого поворота."
            ),
            extras: []
        )
    }

    private static func pacingRunning(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Ease into the run", "Войдите в пробежку плавно"),
            assessment: bi(
                "The run just started — let breathing and stride find a rhythm.",
                "Пробежка только началась — дайте дыханию и шагу найти ритм."
            ),
            situation: bi("Focus on relaxed shoulders and quiet footfalls.", "Держите плечи расслабленными и шаг тихим."),
            primary: action(
                .controlIntensity,
                "Keep the next 10 minutes easy",
                "Speed up only when breathing feels calm",
                "Следующие 10 минут держите легко",
                "Ускоряйтесь, когда дыхание станет спокойным"
            ),
            avoidance: bi(
                longSession ? "Do not chase target pace in the first kilometre." : "Do not sprint the first 500 metres.",
                longSession ? "Не гонитесь за целевым темпом в первом километре." : "Не рваните первые 500 метров."
            ),
            extras: []
        )
    }

    private static func pacingGeneral(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Ease into the session", "Войдите в сессию плавно"),
            assessment: bi(
                "The session just started — let the body settle before pushing.",
                "Сессия только началась — дайте телу успокоиться до нагрузки."
            ),
            situation: bi("Use the opening to find rhythm, not to prove fitness.", "Начало — для ритма, а не для проверки формы."),
            primary: action(
                .controlIntensity,
                "Keep the next 10 minutes easy",
                "Build only when control feels solid",
                "Следующие 10 минут держите легко",
                "Наращивайте, когда контроль стабилен"
            ),
            avoidance: bi(
                "A hard opening is hard to undo.",
                "Жёсткий старт потом трудно откатить."
            ),
            extras: []
        )
    }

    // MARK: - Sustainable

    private static func sustainableCycling(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Hold a steady rhythm", "Держите ровный ритм"),
            assessment: bi(
                longSession ? "You are into the long ride — fuel and pace matter more than surges." : "The opening is done — now keep the effort repeatable.",
                longSession ? "Вы уже в длинной поездке — питание и темп важнее рывков." : "Старт позади — теперь держите усилие повторяемым."
            ),
            situation: bi("Eat and drink on a schedule, not when hunger hits.", "Ешьте и пейте по графику, а не когда проголодаетесь."),
            primary: action(
                .sustainEnergy,
                "Take carbs every 20-30 minutes",
                "Start the next block before energy dips",
                "Углеводы каждые 20-30 минут",
                "Следующий приём — до просадки энергии"
            ),
            avoidance: bi(
                "Do not skip the next fueling block because you feel fine.",
                "Не пропускайте следующий приём только потому, что пока хорошо."
            ),
            extras: []
        )
    }

    private static func sustainableRunning(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Hold a steady rhythm", "Держите ровный темп"),
            assessment: bi(
                longSession ? "You are into the long run — fuel and pace beat surges." : "The opening is done — keep the effort repeatable.",
                longSession ? "Вы уже в длинной пробежке — питание и темп важнее рывков." : "Старт позади — держите усилие повторяемым."
            ),
            situation: bi("Small fuel regularly beats one big catch-up later.", "Небольшие порции регулярно лучше, чем догонять потом."),
            primary: action(
                .sustainEnergy,
                "Take carbs every 20-30 minutes",
                "Gels, chews, or sports drink on schedule",
                "Углеводы каждые 20-30 минут",
                "Гель, батончик или изотоник по графику"
            ),
            avoidance: bi(
                "Do not wait until you feel empty to eat.",
                "Не ждите, пока «опустошит», чтобы поесть."
            ),
            extras: []
        )
    }

    private static func sustainableGeneral(longSession: Bool) -> WindowCopy {
        sustainableRunning(longSession: longSession)
    }

    // MARK: - Fueling / hydration

    private static func fuelingCycling() -> WindowCopy {
        WindowCopy(
            hero: bi("Refuel now", "Подкрепитесь сейчас"),
            assessment: bi("Energy out is ahead of energy in.", "Расход энергии опережает поступление."),
            situation: bi("A carb block now protects the next hour on the bike.", "Блок углеводов сейчас защитит следующий час на велосипеде."),
            primary: action(
                .sustainEnergy,
                "Take 30-60 g carbohydrates",
                "Within the next 15 minutes",
                "Примите 30-60 г углеводов",
                "В течение ближайших 15 минут"
            ),
            avoidance: bi("Waiting for hunger is already too late.", "Ждать голода уже поздно."),
            extras: []
        )
    }

    private static func fuelingRunning() -> WindowCopy {
        WindowCopy(
            hero: bi("Refuel now", "Подкрепитесь сейчас"),
            assessment: bi("Energy out is ahead of energy in.", "Расход энергии опережает поступление."),
            situation: bi("A carb block now protects the next hour of running.", "Блок углеводов сейчас защитит следующий час бега."),
            primary: action(
                .sustainEnergy,
                "Take 30-60 g carbohydrates",
                "Within the next 15 minutes",
                "Примите 30-60 г углеводов",
                "В течение ближайших 15 минут"
            ),
            avoidance: bi("Waiting for hunger is already too late.", "Ждать голода уже поздно."),
            extras: []
        )
    }

    private static func fuelingGeneral() -> WindowCopy {
        fuelingRunning()
    }

    private static func hydrationGeneral() -> WindowCopy {
        WindowCopy(
            hero: bi("Drink on schedule", "Пейте по графику"),
            assessment: bi("You are drinking less than this workload needs.", "Вы пьёте меньше, чем требует нагрузка."),
            situation: bi("A controlled bottle block now beats catching up later.", "Контролируемый блок воды сейчас лучше, чем догонять потом."),
            primary: action(
                .steadyHydration,
                "Drink 300-500 ml",
                "Over the next 20 minutes",
                "Выпейте 300-500 мл",
                "В течение ближайших 20 минут"
            ),
            avoidance: bi("Do not chug everything at once.", "Не выпивайте всё залпом."),
            extras: []
        )
    }

    // MARK: - Post

    private static func postLongCycling(timing: PostTiming, context: PostContext?) -> WindowCopy {
        postLongEndurance(
            timing: timing,
            context: context,
            modalityEN: "ride",
            modalityRU: "поездка",
            heroImmediate: bi("Ride done — recover", "Поездка позади — восстановление")
        )
    }

    private static func postLongRunning(timing: PostTiming, context: PostContext?) -> WindowCopy {
        postLongEndurance(
            timing: timing,
            context: context,
            modalityEN: "run",
            modalityRU: "пробежка",
            heroImmediate: bi("Run done — recover", "Пробежка позади — восстановление")
        )
    }

    private static func postLongGeneral(timing: PostTiming, context: PostContext?) -> WindowCopy {
        postLongEndurance(
            timing: timing,
            context: context,
            modalityEN: "session",
            modalityRU: "сессия",
            heroImmediate: bi("Session done — recover", "Сессия позади — восстановление")
        )
    }

    private static func postLongEndurance(
        timing: PostTiming,
        context: PostContext?,
        modalityEN: String,
        modalityRU: String,
        heroImmediate: BilingualText
    ) -> WindowCopy {
        let timePhase = context?.timePhase ?? .afternoon
        let staleHero = CoachTimeOfDayFraming.postStaleHero(
            timePhase: timePhase,
            modalityEN: modalityEN,
            modalityRU: modalityRU,
            longSession: true
        )
        let settledHero = CoachTimeOfDayFraming.postSettledHero(
            timePhase: timePhase,
            modalityEN: modalityEN,
            modalityRU: modalityRU
        )
        let hero: BilingualText
        let assessment: BilingualText
        let situation: BilingualText
        let primary: ActionCopy

        switch timing {
        case .immediate:
            hero = heroImmediate
            assessment = holisticPostAssessment(
                timing: timing,
                context: context,
                modalityEN: modalityEN,
                modalityRU: modalityRU,
                longSession: true
            )
            situation = postRecoverySituation(timePhase: timePhase, timing: timing)
            primary = action(
                .recoveryMeal,
                "Eat 25-40 g protein and 60-100 g carbs",
                "In your next meal",
                "25-40 г белка и 60-100 г углеводов",
                "В ближайшем приёме пищи"
            )
        case .settled:
            hero = bi(settledHero.english, settledHero.russian)
            assessment = holisticPostAssessment(
                timing: timing,
                context: context,
                modalityEN: modalityEN,
                modalityRU: modalityRU,
                longSession: true
            )
            situation = postRecoverySituation(timePhase: timePhase, timing: timing)
            primary = action(
                .sleepPriority,
                "Keep the rest of the day easy",
                "Food is likely covered — sleep matters more now",
                "Остаток дня сделайте лёгким",
                "Еда, скорее всего, уже есть — сон важнее"
            )
        case .stale:
            hero = bi(staleHero.english, staleHero.russian)
            assessment = holisticPostAssessment(
                timing: timing,
                context: context,
                modalityEN: modalityEN,
                modalityRU: modalityRU,
                longSession: true
            )
            situation = postRecoverySituation(timePhase: timePhase, timing: timing)
            primary = action(
                .sleepPriority,
                "Protect sleep tonight",
                "That is where today's work pays off",
                "Выспитесь сегодня",
                "Именно ночью закрепляется сегодняшняя работа"
            )
        }

        return WindowCopy(
            hero: hero,
            assessment: assessment,
            situation: situation,
            primary: primary,
            avoidance: bi("Do not add another hard session today.", "Не добавляйте сегодня ещё одну тяжёлую сессию."),
            extras: []
        )
    }

    private static func postMediumGeneral(timing: PostTiming, context: PostContext?) -> WindowCopy {
        let timePhase = context?.timePhase ?? .afternoon
        let hero: BilingualText
        let assessment: BilingualText
        let primary: ActionCopy

        switch timing {
        case .immediate:
            hero = bi("Session done — refuel", "Сессия позади — восполните ресурс")
            assessment = holisticPostAssessment(
                timing: timing,
                context: context,
                modalityEN: "session",
                modalityRU: "сессия",
                longSession: false
            )
            primary = action(
                .recoveryMeal,
                "Add 25-40 g protein",
                "In your next meal",
                "Добавьте 25-40 г белка",
                "В ближайшем приёме пищи"
            )
        case .settled:
            let settled = CoachTimeOfDayFraming.postSettledHero(
                timePhase: timePhase,
                modalityEN: "session",
                modalityRU: "сессия"
            )
            hero = bi(settled.english, settled.russian)
            assessment = holisticPostAssessment(
                timing: timing,
                context: context,
                modalityEN: "session",
                modalityRU: "сессия",
                longSession: false
            )
            primary = action(
                .sleepPriority,
                "Keep the rest of the day easy",
                "No need to keep acting like the session just ended",
                "Остаток дня сделайте лёгким",
                "Не нужно жить так, будто сессия только что закончилась"
            )
        case .stale:
            let stale = CoachTimeOfDayFraming.postStaleHero(
                timePhase: timePhase,
                modalityEN: "session",
                modalityRU: "сессия",
                longSession: false
            )
            hero = bi(stale.english, stale.russian)
            assessment = holisticPostAssessment(
                timing: timing,
                context: context,
                modalityEN: "session",
                modalityRU: "сессия",
                longSession: false
            )
            primary = action(
                .sleepPriority,
                "Protect sleep tonight",
                "Let recovery finish overnight",
                "Хорошо поспите сегодня",
                "Дайте восстановлению завершиться ночью"
            )
        }

        return WindowCopy(
            hero: hero,
            assessment: assessment,
            situation: postRecoverySituation(timePhase: timePhase, timing: timing),
            primary: primary,
            avoidance: bi("Do not stack extra intensity on top of this session.", "Не накладывайте интенсивность поверх этой сессии."),
            extras: []
        )
    }

    private static func postShortGeneral(timing: PostTiming, context: PostContext?) -> WindowCopy {
        let timePhase = context?.timePhase ?? .afternoon
        if timing == .stale {
            let stale = CoachTimeOfDayFraming.postStaleHero(
                timePhase: timePhase,
                modalityEN: "session",
                modalityRU: "сессия",
                longSession: false
            )
            return WindowCopy(
                hero: bi(stale.english, stale.russian),
                assessment: holisticPostAssessment(
                    timing: timing,
                    context: context,
                    modalityEN: "session",
                    modalityRU: "сессия",
                    longSession: false
                ),
                situation: postRecoverySituation(timePhase: timePhase, timing: timing),
                primary: action(
                    .sleepPriority,
                    "Keep the rest of the day calm",
                    "No extra protocol needed",
                    "Остаток дня сделайте спокойным",
                    "Дополнительный протокол не нужен"
                ),
                avoidance: bi("Do not add volume just because it felt easy.", "Не добавляйте объём только потому, что было легко."),
                extras: []
            )
        }

        return WindowCopy(
            hero: bi("Wrap up cleanly", "Спокойно завершите"),
            assessment: holisticPostAssessment(
                timing: .immediate,
                context: context,
                modalityEN: "session",
                modalityRU: "сессия",
                longSession: false
            ),
            situation: bi("A brief cooldown and normal eating are enough.", "Короткой заминки и обычной еды достаточно."),
            primary: action(
                .cooldown,
                "Cool down 5-10 minutes easy",
                "Let heart rate come down",
                "5-10 минут лёгкой заминки",
                "Дайте пульсу снизиться"
            ),
            avoidance: bi("Do not add volume just because it felt easy.", "Не добавляйте объём только потому, что было легко."),
            extras: []
        )
    }

    private static func holisticPostAssessment(
        timing: PostTiming,
        context: PostContext?,
        modalityEN: String,
        modalityRU: String,
        longSession: Bool
    ) -> BilingualText {
        let heavyDay = (context?.caloriesBurned ?? 0) >= 700
        let lowRecovery = (context?.recoveryPercent ?? 100) < 75
        let protectTomorrow = context?.shouldProtectTomorrow == true
        let timePhase = context?.timePhase ?? .afternoon
        let evening = isEveningPhase(timePhase)

        switch timing {
        case .immediate:
            if heavyDay && lowRecovery {
                return bi(
                    "The \(modalityEN) landed on an already heavy day, and recovery is limited — refuel, do not add work.",
                    "После \(modalityRU) день и так тяжёлый, а восстановление ограничено — восполняйте ресурс, а не добавляйте работу."
                )
            }
            if heavyDay {
                return bi(
                    longSession
                        ? "The long \(modalityEN) added to an already demanding day — recovery beats more work now."
                        : "Today's load is adding up — support recovery instead of stacking more work.",
                    longSession
                        ? "Длинная \(modalityRU) добавилась к и без того насыщенному дню — сейчас важнее восстановление, а не ещё нагрузка."
                        : "Нагрузка за день уже складывается — поддержите восстановление, а не добавляйте работу."
                )
            }
            if protectTomorrow {
                return bi(
                    "The \(modalityEN) is done, but tomorrow still has demand — recover without draining the evening.",
                    "\(modalityRU.capitalized) позади, но завтра ещё есть нагрузка — восстанавливайтесь, не выжигая вечер."
                )
            }
            return bi(
                longSession
                    ? "A long \(modalityEN) takes recovery, not more work today."
                    : "Solid work is done — keep the rest of the day controlled.",
                longSession
                    ? "После длинной \(modalityRU) нужно восстановление, а не ещё работа."
                    : "Хорошая тренировка закончена — остаток дня держите под контролем."
            )

        case .settled:
            if protectTomorrow {
                return bi(
                    "Main work for today is done, and tomorrow still matters — ease into the rest of the day.",
                    "Главная тренировка на сегодня сделана, а завтра ещё важно — входите в остаток дня спокойно."
                )
            }
            if heavyDay {
                return bi(
                    "The \(modalityEN) is behind you and the day already cost a lot — protect the evening, not another session.",
                    "\(modalityRU.capitalized) уже позади, а день стоил много энергии — берегите вечер, а не добавляйте сессию."
                )
            }
            return bi(
                "Training is done for now — the rest of the day should stay easy.",
                "Тренировка на сегодня сделана — остаток дня лучше держать лёгким."
            )

        case .stale:
            if protectTomorrow {
                return bi(
                    "Today's main work is done and tomorrow has demand — a calm evening protects both.",
                    "Главная тренировка на сегодня сделана, а завтра есть нагрузка — спокойный вечер защитит и то, и другое."
                )
            }
            if heavyDay || evening {
                return bi(
                    timePhase == .morning || timePhase == .midday
                        ? "The heavy work is behind you — keep the rest of the day controlled."
                        : "The heavy work is hours behind you now — what matters is protecting sleep and keeping the evening calm.",
                    timePhase == .morning || timePhase == .midday
                        ? "Тяжёлая тренировка уже позади — держите остаток дня под контролем."
                        : "Тяжёлая тренировка уже несколько часов позади — сейчас важнее сон и спокойный вечер."
                )
            }
            return bi(
                "The session is well behind you — nothing urgent remains except an easy finish to the day.",
                "Сессия уже давно позади — срочного ничего не осталось, кроме спокойного завершения дня."
            )
        }
    }

    private static func postRecoverySituation(
        timePhase: CoachFinalDecisionTimeOfDay,
        timing: PostTiming
    ) -> BilingualText {
        switch timing {
        case .immediate:
            switch timePhase {
            case .morning, .midday:
                return bi(
                    "Food and fluids now — keep the rest of the day controlled.",
                    "Еда и вода сейчас — остаток дня держите под контролем."
                )
            case .afternoon:
                return bi(
                    "Food and fluids now — protect the rest of the afternoon.",
                    "Еда и вода сейчас — берегите остаток дня."
                )
            case .evening, .lateEvening, .night:
                return bi(
                    "Food, fluids, and a calm evening do the real work now.",
                    "Еда, вода и спокойный вечер сейчас важнее нагрузки."
                )
            }
        case .settled:
            return bi(
                "The training window has passed — protect the rest of the day.",
                "Окно тренировки прошло — берегите остаток дня."
            )
        case .stale:
            switch timePhase {
            case .morning, .midday, .afternoon:
                return bi(
                    "Nothing urgent remains from the session itself.",
                    "От самой сессии срочного уже ничего не осталось."
                )
            case .evening, .lateEvening, .night:
                return bi(
                    "Nothing urgent remains — sleep and a calm evening matter most.",
                    "Срочного ничего не осталось — сон и спокойный вечер сейчас важнее всего."
                )
            }
        }
    }

    private static func isEveningPhase(_ phase: CoachFinalDecisionTimeOfDay) -> Bool {
        switch phase {
        case .evening, .lateEvening, .night:
            return true
        default:
            return false
        }
    }
}
