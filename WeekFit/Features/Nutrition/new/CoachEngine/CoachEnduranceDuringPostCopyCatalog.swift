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
        case opening
        case establish
        case maintain
        case protect
        case recoveryWindow
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
        postContext: PostContext? = nil,
        referenceNow: Date? = nil
    ) -> WindowCopy {
        let modality = CoachSessionPrepCopyCatalog.modality(for: activity)
        let postTiming = PostTiming.from(minutesSinceEnd: minutesSinceEnd)
        let resolveNow = referenceNow ?? Date()
        let remaining = remainingMinutes(activity: activity, now: resolveNow)
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
        case (.opening, .cycling):
            return openingCycling(longSession: longSession)
        case (.opening, .running):
            return openingRunning(longSession: longSession)
        case (.opening, _):
            return openingGeneral(longSession: longSession)
        case (.establish, .cycling):
            return establishCycling(longSession: longSession)
        case (.establish, .running):
            return establishRunning(longSession: longSession)
        case (.establish, _):
            return establishGeneral(longSession: longSession)
        case (.maintain, .cycling):
            return maintainCycling(longSession: longSession)
        case (.maintain, .running):
            return maintainRunning(longSession: longSession)
        case (.maintain, _):
            return maintainGeneral(longSession: longSession)
        case (.protect, .cycling):
            return protectCycling(longSession: longSession, remainingMinutes: remaining)
        case (.protect, .running):
            return protectRunning(longSession: longSession, remainingMinutes: remaining)
        case (.protect, _):
            return protectGeneral(longSession: longSession, remainingMinutes: remaining)
        case (.recoveryWindow, .cycling):
            return recoveryWindowCycling()
        case (.recoveryWindow, .running):
            return recoveryWindowRunning()
        case (.recoveryWindow, _):
            return recoveryWindowGeneral()
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

    /// Protection-track copy for day-cap / survival coaching jobs — same chapter clock, different semantics.
    static func protectionWindow(
        for phase: Phase,
        activity: PlannedActivity?,
        coachingJob: CoachDayLoadCoachingJob,
        longSession: Bool,
        shouldProtectTomorrow: Bool,
        referenceNow: Date? = nil
    ) -> WindowCopy {
        let modality = CoachSessionPrepCopyCatalog.modality(for: activity)
        let remaining = remainingMinutes(activity: activity, now: referenceNow ?? Date())
        switch (phase, modality) {
        case (.opening, .cycling):
            return protectionOpeningCycling(
                coachingJob: coachingJob,
                shouldProtectTomorrow: shouldProtectTomorrow
            )
        case (.opening, .running):
            return protectionOpeningRunning(
                coachingJob: coachingJob,
                shouldProtectTomorrow: shouldProtectTomorrow
            )
        case (.opening, _):
            return protectionOpeningGeneral(
                coachingJob: coachingJob,
                shouldProtectTomorrow: shouldProtectTomorrow
            )
        case (.establish, .cycling):
            return protectionEstablishCycling(shouldProtectTomorrow: shouldProtectTomorrow)
        case (.establish, .running):
            return protectionEstablishRunning(shouldProtectTomorrow: shouldProtectTomorrow)
        case (.establish, _):
            return protectionEstablishGeneral(shouldProtectTomorrow: shouldProtectTomorrow)
        case (.maintain, .cycling):
            return protectionMaintainCycling(shouldProtectTomorrow: shouldProtectTomorrow)
        case (.maintain, .running):
            return protectionMaintainRunning(shouldProtectTomorrow: shouldProtectTomorrow)
        case (.maintain, _):
            return protectionMaintainGeneral(shouldProtectTomorrow: shouldProtectTomorrow)
        case (.protect, .cycling):
            return protectionCapCycling(
                longSession: longSession,
                remainingMinutes: remaining,
                shouldProtectTomorrow: shouldProtectTomorrow
            )
        case (.protect, .running):
            return protectionCapRunning(
                longSession: longSession,
                remainingMinutes: remaining,
                shouldProtectTomorrow: shouldProtectTomorrow
            )
        case (.protect, _):
            return protectionCapGeneral(
                longSession: longSession,
                remainingMinutes: remaining,
                shouldProtectTomorrow: shouldProtectTomorrow
            )
        case (.pacing, .cycling):
            return protectionOpeningCycling(
                coachingJob: coachingJob,
                shouldProtectTomorrow: shouldProtectTomorrow
            )
        case (.pacing, .running):
            return protectionOpeningRunning(
                coachingJob: coachingJob,
                shouldProtectTomorrow: shouldProtectTomorrow
            )
        case (.pacing, _):
            return protectionOpeningGeneral(
                coachingJob: coachingJob,
                shouldProtectTomorrow: shouldProtectTomorrow
            )
        case (.sustainable, .cycling):
            return protectionMaintainCycling(shouldProtectTomorrow: shouldProtectTomorrow)
        case (.sustainable, .running):
            return protectionMaintainRunning(shouldProtectTomorrow: shouldProtectTomorrow)
        case (.sustainable, _):
            return protectionMaintainGeneral(shouldProtectTomorrow: shouldProtectTomorrow)
        default:
            return protectionMaintainGeneral(shouldProtectTomorrow: shouldProtectTomorrow)
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
        minutesSinceEnd: Int = 0,
        timePhase: CoachFinalDecisionTimeOfDay? = nil,
        coachingJob: CoachDayLoadCoachingJob? = nil
    ) -> [ReasonCopy] {
        if let coachingJob, coachingJob != .optimizeExecution {
            return protectionReasons(
                for: phase,
                coachingJob: coachingJob,
                shouldProtectTomorrow: shouldProtectTomorrow,
                caloriesBurned: caloriesBurned
            )
        }

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
                    kind: .training,
                    english: recoveryPercent >= 75
                        ? "There is still a long session ahead — ease in first."
                        : "Recovery is limited — keep the opening conservative.",
                    russian: recoveryPercent >= 75
                        ? "Впереди длинная сессия — сначала разогрейтесь."
                        : "Восстановление ограничено — старт лучше держать консервативным.",
                    icon: "figure.outdoor.cycle",
                    colorFamily: .ready
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

        case .opening:
            var items: [ReasonCopy] = []
            if let remainingMinutes, remainingMinutes > 0 {
                items.append(
                    ReasonCopy(
                        kind: .time,
                        english: "About \(remainingMinutes) minutes of work remain after this opening block.",
                        russian: "После этого блока впереди ещё около \(remainingMinutes) минут работы.",
                        icon: "clock.fill",
                        colorFamily: .ready
                    )
                )
            }
            items.append(
                ReasonCopy(
                    kind: .training,
                    english: "A calm opening keeps the whole session more repeatable.",
                    russian: "Спокойный старт делает всю сессию более ровной.",
                    icon: "figure.outdoor.cycle",
                    colorFamily: .ready
                )
            )
            return Array(items.prefix(2))

        case .establish:
            return [
                ReasonCopy(
                    kind: .fuel,
                    english: "Regular fuel now keeps the second half steadier.",
                    russian: "Регулярное питание сейчас сделает вторую половину ровнее.",
                    icon: "bolt.fill",
                    colorFamily: .fuel
                ),
                ReasonCopy(
                    kind: .time,
                    english: elapsedMinutes > 0
                        ? "You are \(elapsedMinutes) minutes in — time to set the fuel rhythm."
                        : "The opening is done — time to set the fuel rhythm.",
                    russian: elapsedMinutes > 0
                        ? "Вы уже \(elapsedMinutes) минут в работе — пора задать ритм питания."
                        : "Старт позади — пора задать ритм питания.",
                    icon: "clock.fill",
                    colorFamily: .ready
                )
            ]

        case .maintain:
            var items: [ReasonCopy] = []
            if elapsedMinutes > 0 {
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
                    kind: .training,
                    english: "The middle is about repeating what already works.",
                    russian: "Середина — про повторение того, что уже работает.",
                    icon: "figure.outdoor.cycle",
                    colorFamily: .ready
                )
            )
            return Array(items.prefix(2))

        case .protect:
            return [
                ReasonCopy(
                    kind: .time,
                    english: remainingMinutes.map { "About \($0) minutes remain to the finish." } ?? "The finish is getting close.",
                    russian: remainingMinutes.map { "До финиша около \($0) минут." } ?? "Финиш уже близко.",
                    icon: "clock.fill",
                    colorFamily: .ready
                ),
                ReasonCopy(
                    kind: .training,
                    english: "Protect the finish — no extra surges now.",
                    russian: "Берегите финиш — лишних рывков сейчас не нужно.",
                    icon: "flag.checkered",
                    colorFamily: .ready
                )
            ]

        case .recoveryWindow:
            return [
                ReasonCopy(
                    kind: .recovery,
                    english: "The first hour after a long session is the main recovery window.",
                    russian: "Первый час после длинной сессии — главное окно восстановления.",
                    icon: "bed.double.fill",
                    colorFamily: .recovery
                ),
                ReasonCopy(
                    kind: .fuel,
                    english: "Protein and carbs now refill what the session took out.",
                    russian: "Белок и углеводы сейчас восполняют то, что забрала сессия.",
                    icon: "bolt.fill",
                    colorFamily: .fuel
                )
            ]

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
            return postSettledStaleReasons(
                timing: PostTiming.from(minutesSinceEnd: minutesSinceEnd),
                shouldProtectTomorrow: shouldProtectTomorrow,
                timePhase: timePhase
            )

        }
    }

    private static func postSettledStaleReasons(
        timing: PostTiming,
        shouldProtectTomorrow: Bool,
        timePhase: CoachFinalDecisionTimeOfDay?
    ) -> [ReasonCopy] {
        guard timing == .settled || timing == .stale else { return [] }

        var items: [ReasonCopy] = [
            ReasonCopy(
                kind: .training,
                english: "The main useful work is already done.",
                russian: "Основная полезная работа уже сделана.",
                icon: "checkmark.circle.fill",
                colorFamily: .activity
            )
        ]

        let isEveningWindDown = timePhase == .evening ||
            timePhase == .lateEvening ||
            timePhase == .night

        if isEveningWindDown || timing == .stale {
            items.append(
                ReasonCopy(
                    kind: .constraint,
                    english: "Sleep tonight matters more than adding another effort.",
                    russian: "Сон сегодня важнее, чем ещё одна нагрузка.",
                    icon: "moon.fill",
                    colorFamily: .recovery
                )
            )
        } else if shouldProtectTomorrow {
            items.append(
                ReasonCopy(
                    kind: .tomorrow,
                    english: "Tomorrow has training — save margin for tonight.",
                    russian: "Завтра тренировка — сегодня сохраните силы.",
                    icon: "calendar",
                    colorFamily: .activity
                )
            )
        } else {
            items.append(
                ReasonCopy(
                    kind: .constraint,
                    english: "Extra intensity now is unlikely to add benefit.",
                    russian: "Дополнительная интенсивность сейчас вряд ли поможет.",
                    icon: "exclamationmark.triangle.fill",
                    colorFamily: .warning
                )
            )
        }

        return Array(items.prefix(2))
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
        case .opening:
            let modality = CoachSessionPrepCopyCatalog.modality(for: activity)
            if modality == .cycling {
                return [
                    action(.steadyHydration, "Sip from your bottle", "Small mouthfuls only", "Глоток из бутылки", "Только маленькими глотками")
                ]
            }
            return [
                action(.steadyHydration, "Sip if thirsty", "No need to drink a lot now", "Глоток при жажде", "Много пить сейчас не нужно")
            ]
        case .establish:
            return [
                action(.sustainEnergy, "Take carbs every 20-30 minutes", "Start the next block before energy dips", "Углеводы каждые 20-30 минут", "Следующий приём — до просадки энергии")
            ]
        case .maintain:
            return [
                action(.steadyHydration, "Drink with each fueling block", "Small sips, not a full bottle at once", "Пейте с каждым приёмом пищи", "Маленькими глотками, не залпом")
            ]
        case .protect:
            return [
                action(.controlIntensity, "Hold the current effort", "No attacks or surges to the finish", "Держите текущее усилие", "Без атак и рывков до финиша")
            ]
        case .recoveryWindow:
            return [
                action(.rehydrateGradually, "Drink 500-750 ml over the next hour", "Spread it out, not all at once", "500-750 мл в течение часа", "Растяните, не залпом"),
                action(.sleepPriority, "Protect sleep tonight", "That is where endurance recovery happens", "Берегите сон сегодня", "Там идёт основное восстановление")
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

    // MARK: - Session chapters (Opening → Establish → Maintain → Protect)

    private static func openingCycling(longSession: Bool) -> WindowCopy {
        pacingCycling(longSession: longSession)
    }

    private static func openingRunning(longSession: Bool) -> WindowCopy {
        pacingRunning(longSession: longSession)
    }

    private static func openingGeneral(longSession: Bool) -> WindowCopy {
        pacingGeneral(longSession: longSession)
    }

    private static func establishCycling(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Set your fuel rhythm", "Задайте ритм питания"),
            assessment: bi(
                longSession
                    ? "The opening is done — now regular fuel matters more than pace changes."
                    : "The easy start is behind you — time to eat and drink on a schedule.",
                longSession
                    ? "Старт позади — теперь регулярное питание важнее смены темпа."
                    : "Лёгкий старт позади — пора есть и пить по графику."
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

    private static func establishRunning(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Set your fuel rhythm", "Задайте ритм питания"),
            assessment: bi(
                longSession
                    ? "The opening is done — regular fuel beats pace changes from here."
                    : "The easy start is behind you — time to fuel on a schedule.",
                longSession
                    ? "Старт позади — регулярное питание важнее смены темпа."
                    : "Лёгкий старт позади — пора питаться по графику."
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

    private static func establishGeneral(longSession: Bool) -> WindowCopy {
        establishRunning(longSession: longSession)
    }

    private static func maintainCycling(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Hold the steady middle", "Держите ровную середину"),
            assessment: bi(
                longSession
                    ? "You are into the long middle — repeat fuel, pace, and hydration."
                    : "You are in the working middle — keep repeating what already works.",
                longSession
                    ? "Вы в длинной середине — повторяйте питание, темп и гидратацию."
                    : "Вы в рабочей середине — повторяйте то, что уже работает."
            ),
            situation: bi("Same rhythm, same blocks — no need to change the plan now.", "Тот же ритм, те же блоки — менять план сейчас не нужно."),
            primary: action(
                .sustainEnergy,
                "Take carbs every 20-30 minutes",
                "Keep the next block on schedule",
                "Углеводы каждые 20-30 минут",
                "Следующий приём — по графику"
            ),
            avoidance: bi(
                "Do not chase groups or surges just because you still feel good.",
                "Не гонитесь за группой или рывками только потому, что пока хорошо."
            ),
            extras: []
        )
    }

    private static func maintainRunning(longSession: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Hold the steady middle", "Держите ровную середину"),
            assessment: bi(
                longSession
                    ? "You are into the long middle — repeat fuel, pace, and hydration."
                    : "You are in the working middle — keep repeating what already works.",
                longSession
                    ? "Вы в длинной середине — повторяйте питание, темп и гидратацию."
                    : "Вы в рабочей середине — повторяйте то, что уже работает."
            ),
            situation: bi("Same rhythm, same blocks — no need to change the plan now.", "Тот же ритм, те же блоки — менять план сейчас не нужно."),
            primary: action(
                .sustainEnergy,
                "Take carbs every 20-30 minutes",
                "Keep the next block on schedule",
                "Углеводы каждые 20-30 минут",
                "Следующий приём — по графику"
            ),
            avoidance: bi(
                "Do not speed up just because the finish still feels far away.",
                "Не ускоряйтесь только потому, что финиш ещё кажется далёким."
            ),
            extras: []
        )
    }

    private static func maintainGeneral(longSession: Bool) -> WindowCopy {
        maintainRunning(longSession: longSession)
    }

    private static func protectCycling(longSession: Bool, remainingMinutes: Int?) -> WindowCopy {
        let remainingPhraseEN = remainingMinutes.map { "About \($0) minutes remain — " } ?? ""
        let remainingPhraseRU = remainingMinutes.map { "До финиша около \($0) минут — " } ?? ""
        return WindowCopy(
            hero: bi("Protect the finish", "Берегите финиш"),
            assessment: bi(
                "\(remainingPhraseEN)keep effort controlled to the line.",
                "\(remainingPhraseRU)держите усилие под контролем до линии."
            ),
            situation: bi("Fuel if needed, but do not add intensity for the finish.", "Подкрепитесь при необходимости, но не добавляйте интенсивности ради финиша."),
            primary: action(
                .controlIntensity,
                "Hold the current effort",
                "No attacks or surges to the finish",
                "Держите текущее усилие",
                "Без атак и рывков до финиша"
            ),
            avoidance: bi(
                longSession
                    ? "Do not spend the last hour trying to make up time."
                    : "Do not sprint the last stretch just because the finish is close.",
                longSession
                    ? "Не тратьте последний час, пытаясь наверстать время."
                    : "Не рваните на финиш только потому, что он близко."
            ),
            extras: []
        )
    }

    private static func protectRunning(longSession: Bool, remainingMinutes: Int?) -> WindowCopy {
        protectCycling(longSession: longSession, remainingMinutes: remainingMinutes)
    }

    private static func protectGeneral(longSession: Bool, remainingMinutes: Int?) -> WindowCopy {
        protectCycling(longSession: longSession, remainingMinutes: remainingMinutes)
    }

    private static func recoveryWindowCycling() -> WindowCopy {
        WindowCopy(
            hero: bi("Recovery window is open", "Окно восстановления открыто"),
            assessment: bi(
                "The long ride is done — the next hour matters most for recovery.",
                "Длинная поездка позади — следующий час важнее всего для восстановления."
            ),
            situation: bi("Eat, drink, and keep the rest of the day calm.", "Поешьте, попейте и держите остаток дня спокойным."),
            primary: action(
                .recoveryMeal,
                "Eat 25-40 g protein and 60-100 g carbs",
                "In your next meal",
                "25-40 г белка и 60-100 г углеводов",
                "В ближайшем приёме пищи"
            ),
            avoidance: bi(
                "Do not add training load in the recovery window.",
                "Не добавляйте нагрузку в окне восстановления."
            ),
            extras: []
        )
    }

    private static func recoveryWindowRunning() -> WindowCopy {
        WindowCopy(
            hero: bi("Recovery window is open", "Окно восстановления открыто"),
            assessment: bi(
                "The long run is done — the next hour matters most for recovery.",
                "Длинная пробежка позади — следующий час важнее всего для восстановления."
            ),
            situation: bi("Eat, drink, and keep the rest of the day calm.", "Поешьте, попейте и держите остаток дня спокойным."),
            primary: action(
                .recoveryMeal,
                "Eat 25-40 g protein and 60-100 g carbs",
                "In your next meal",
                "25-40 г белка и 60-100 г углеводов",
                "В ближайшем приёме пищи"
            ),
            avoidance: bi(
                "Do not add training load in the recovery window.",
                "Не добавляйте нагрузку в окне восстановления."
            ),
            extras: []
        )
    }

    private static func recoveryWindowGeneral() -> WindowCopy {
        recoveryWindowRunning()
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

    // MARK: - Protection track (day-cap / survival)

    private static func protectionReasons(
        for phase: Phase,
        coachingJob: CoachDayLoadCoachingJob,
        shouldProtectTomorrow: Bool,
        caloriesBurned: Double
    ) -> [ReasonCopy] {
        var items: [ReasonCopy] = []

        if coachingJob == .dayCap {
            items.append(
                ReasonCopy(
                    kind: .training,
                    english: "The main workout for today is already done.",
                    russian: "Главная тренировка на сегодня уже была.",
                    icon: "checkmark.circle.fill",
                    colorFamily: .activity
                )
            )
            items.append(
                ReasonCopy(
                    kind: .constraint,
                    english: "This session should not repeat the first one.",
                    russian: "Этот заезд не должен копировать первый.",
                    icon: "shield.fill",
                    colorFamily: .warning
                )
            )
        } else {
            items.append(
                ReasonCopy(
                    kind: .constraint,
                    english: "Today's energy spend is already very high.",
                    russian: "Расход энергии за день уже очень высокий.",
                    icon: "flame.fill",
                    colorFamily: .warning
                )
            )
            items.append(
                ReasonCopy(
                    kind: .training,
                    english: "The goal is to finish without breaking the day.",
                    russian: "Цель — закрыть без срыва дня.",
                    icon: "shield.fill",
                    colorFamily: .warning
                )
            )
        }

        if shouldProtectTomorrow, items.count < 2 {
            items.append(
                ReasonCopy(
                    kind: .tomorrow,
                    english: "Tomorrow's training matters more than squeezing more out of today.",
                    russian: "Завтрашняя тренировка важнее, чем выжать больше из сегодня.",
                    icon: "calendar",
                    colorFamily: .activity
                )
            )
        }

        if caloriesBurned >= 700, items.count < 2 {
            items.append(
                ReasonCopy(
                    kind: .constraint,
                    english: "The day already carries a heavy energy cost.",
                    russian: "День уже несёт большой энергетический расход.",
                    icon: "flame.fill",
                    colorFamily: .warning
                )
            )
        }

        return Array(items.prefix(2))
    }

    private static func protectionOpeningCycling(
        coachingJob: CoachDayLoadCoachingJob,
        shouldProtectTomorrow: Bool
    ) -> WindowCopy {
        let hero: BilingualText
        let assessment: BilingualText
        if coachingJob == .dayCap {
            hero = bi("Second ride — don't push the day again", "Вторая поездка — не разгоняйте день снова")
            assessment = bi(
                shouldProtectTomorrow
                    ? "After a long ride today, this one should close the day — not add to it — and tomorrow still matters."
                    : "After a long ride today, this one should close the day — not add to it.",
                shouldProtectTomorrow
                    ? "После длинной поездки сегодня этот заезд должен закрыть день, а не добавить к нему — завтра тоже важно."
                    : "После длинной поездки сегодня этот заезд должен закрыть день, а не добавить к нему."
            )
        } else {
            hero = bi("The day is already heavy — hold the cap", "День уже тяжёлый — держите потолок")
            assessment = bi(
                shouldProtectTomorrow
                    ? "Energy is already high today — finish without costing tomorrow."
                    : "Energy is already high today — finish without adding more load.",
                shouldProtectTomorrow
                    ? "Энергия сегодня уже высокая — закройте без ущерба для завтра."
                    : "Энергия сегодня уже высокая — закройте без добавки нагрузки."
            )
        }
        return WindowCopy(
            hero: hero,
            assessment: assessment,
            situation: bi(
                "This ride is about protecting the day, not opening fresh legs.",
                "Эта поездка — про защиту дня, а не про разгон с нуля."
            ),
            primary: action(
                .controlIntensity,
                "Keep the whole ride light",
                "No chasing the first session",
                "Держите весь заезд лёгким",
                "Не гонитесь с первой поездкой"
            ),
            avoidance: bi(
                "Do not ease in like a fresh start.",
                "Не входите в поездку как в первую."
            ),
            extras: []
        )
    }

    private static func protectionOpeningRunning(
        coachingJob: CoachDayLoadCoachingJob,
        shouldProtectTomorrow: Bool
    ) -> WindowCopy {
        let hero: BilingualText
        if coachingJob == .dayCap {
            hero = bi("Second run — don't push the day again", "Вторая пробежка — не разгоняйте день снова")
        } else {
            hero = bi("The day is already heavy — hold the cap", "День уже тяжёлый — держите потолок")
        }
        return WindowCopy(
            hero: hero,
            assessment: bi(
                shouldProtectTomorrow
                    ? "Today's legs already did serious work — keep this run capped and protect tomorrow."
                    : "Today's legs already did serious work — keep this run capped.",
                shouldProtectTomorrow
                    ? "Ноги сегодня уже сделали серьёзную работу — держите этот заход в рамках и берегите завтра."
                    : "Ноги сегодня уже сделали серьёзную работу — держите этот заход в рамках."
            ),
            situation: bi("Quiet stride, low ceiling — not a fresh start.", "Тихий шаг, низкий потолок — не чистый старт."),
            primary: action(
                .controlIntensity,
                "Keep the whole run light",
                "No chasing earlier work",
                "Держите всю пробежку лёгкой",
                "Не гонитесь с прошлой работой"
            ),
            avoidance: bi("Do not open like the first run of the day.", "Не начинайте как первую пробежку дня."),
            extras: []
        )
    }

    private static func protectionOpeningGeneral(
        coachingJob: CoachDayLoadCoachingJob,
        shouldProtectTomorrow: Bool
    ) -> WindowCopy {
        protectionOpeningRunning(coachingJob: coachingJob, shouldProtectTomorrow: shouldProtectTomorrow)
    }

    private static func protectionEstablishCycling(shouldProtectTomorrow: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Minimum fuel — not a fuel race", "Минимум еды — не гонка с голодом"),
            assessment: bi(
                shouldProtectTomorrow
                    ? "Eat and drink on schedule, but don't chase the first session with food."
                    : "Eat and drink on schedule — small amounts, not a catch-up.",
                shouldProtectTomorrow
                    ? "Ешьте и пейте по графику, но не догоняйте первую сессию едой."
                    : "Ешьте и пейте по графику — малые порции, не догон."
            ),
            situation: bi("Fuel to avoid a bonk, not to optimize pace.", "Еда чтобы не сорваться, а не чтобы ускориться."),
            primary: action(
                .sustainEnergy,
                "Small fuel on schedule",
                "Avoid bonk, not hunger chasing",
                "Малые порции по графику",
                "Без гонки с голодом"
            ),
            avoidance: bi("Do not fuel like the first session of the day.", "Не питайтесь как в первой сессии дня."),
            extras: []
        )
    }

    private static func protectionEstablishRunning(shouldProtectTomorrow: Bool) -> WindowCopy {
        protectionEstablishCycling(shouldProtectTomorrow: shouldProtectTomorrow)
    }

    private static func protectionEstablishGeneral(shouldProtectTomorrow: Bool) -> WindowCopy {
        protectionEstablishCycling(shouldProtectTomorrow: shouldProtectTomorrow)
    }

    private static func protectionMaintainCycling(shouldProtectTomorrow: Bool) -> WindowCopy {
        WindowCopy(
            hero: bi("Hold the floor, not the ceiling", "Держите дно, а не потолок"),
            assessment: bi(
                shouldProtectTomorrow
                    ? "Repeat only what keeps you steady — don't add to today's load before tomorrow."
                    : "Repeat only what keeps you steady — don't add to today's load.",
                shouldProtectTomorrow
                    ? "Повторяйте только то, что держит ровно — не добавляйте к сегодняшней нагрузке перед завтра."
                    : "Повторяйте только то, что держит ровно — не добавляйте к сегодняшней нагрузке."
            ),
            situation: bi("Same easy rhythm — no surges.", "Тот же лёгкий ритм — без рывков."),
            primary: action(
                .controlIntensity,
                "Hold current effort",
                "No adding to the first session",
                "Держите текущее усилие",
                "Не добавляйте к первой сессии"
            ),
            avoidance: bi("Do not speed up because you still feel okay.", "Не ускоряйтесь только потому, что пока нормально."),
            extras: []
        )
    }

    private static func protectionMaintainRunning(shouldProtectTomorrow: Bool) -> WindowCopy {
        protectionMaintainCycling(shouldProtectTomorrow: shouldProtectTomorrow)
    }

    private static func protectionMaintainGeneral(shouldProtectTomorrow: Bool) -> WindowCopy {
        protectionMaintainCycling(shouldProtectTomorrow: shouldProtectTomorrow)
    }

    private static func protectionCapCycling(
        longSession: Bool,
        remainingMinutes: Int?,
        shouldProtectTomorrow: Bool
    ) -> WindowCopy {
        let remainingPhraseEN = remainingMinutes.map { "About \($0) minutes remain — " } ?? ""
        let remainingPhraseRU = remainingMinutes.map { "До финиша около \($0) минут — " } ?? ""
        return WindowCopy(
            hero: bi("Close without costing the day", "Закройте без ущерба для дня"),
            assessment: bi(
                shouldProtectTomorrow
                    ? "\(remainingPhraseEN)finish easy — tomorrow's work matters more than today's extra effort."
                    : "\(remainingPhraseEN)finish easy — the day is already full.",
                shouldProtectTomorrow
                    ? "\(remainingPhraseRU)дожмите легко — завтрашняя работа важнее сегодняшнего усилия."
                    : "\(remainingPhraseRU)дожмите легко — день уже насыщен."
            ),
            situation: bi("No finish heroics — protect what's left of the day.", "Без героизма на финише — берегите остаток дня."),
            primary: action(
                .controlIntensity,
                "Hold or reduce effort",
                "Finish calmly, not fast",
                "Держите или снижайте усилие",
                "Дожмите спокойно, не быстро"
            ),
            avoidance: bi(
                longSession
                    ? "Do not spend the last block trying to make up for the first session."
                    : "Do not sprint the finish because the day already cost enough.",
                longSession
                    ? "Не тратьте последний блок, пытаясь наверстать первую сессию."
                    : "Не рваните на финиш — день уже стоил достаточно."
            ),
            extras: []
        )
    }

    private static func protectionCapRunning(
        longSession: Bool,
        remainingMinutes: Int?,
        shouldProtectTomorrow: Bool
    ) -> WindowCopy {
        protectionCapCycling(
            longSession: longSession,
            remainingMinutes: remainingMinutes,
            shouldProtectTomorrow: shouldProtectTomorrow
        )
    }

    private static func protectionCapGeneral(
        longSession: Bool,
        remainingMinutes: Int?,
        shouldProtectTomorrow: Bool
    ) -> WindowCopy {
        protectionCapCycling(
            longSession: longSession,
            remainingMinutes: remainingMinutes,
            shouldProtectTomorrow: shouldProtectTomorrow
        )
    }
}
