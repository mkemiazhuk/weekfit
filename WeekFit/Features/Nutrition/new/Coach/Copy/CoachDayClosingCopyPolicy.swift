import Foundation

/// Evening wind-down copy overlay — shapes tone when the day is effectively done.
/// Does not change scenario routing, focus, or UI model fields beyond copy text.
enum CoachDayClosingCopyPolicy {

    struct TeaserOverlay: Equatable, Sendable {
        let todayTitle: CoachBilingualText
        let todayMessage: CoachBilingualText
        let coachHeadline: CoachBilingualText
    }

    // MARK: - Eligibility

    static func isActive(_ input: CoachCopyBuildInput) -> Bool {
        guard input.conversationPhase == .dayClosing else { return false }
        guard input.sessionPhase == .idle else { return false }
        guard input.focusSource == .idle else { return false }
        guard input.activityState == .none || input.activityState == .finished else { return false }
        guard CoachCopyNutritionTiming.isWindDown(input.timeOfDay) else { return false }
        return isEligibleScenario(input.scenario)
    }

    static func isActive(result: CoachEngine.Result) -> Bool {
        isActive(CoachCopyBuildInput.from(result: result))
    }

    private static func isEligibleScenario(_ scenario: CoachScenarioKey) -> Bool {
        switch scenario {
        case .stableDay, .recoveryAfterHeavyYesterday:
            return true
        default:
            return false
        }
    }

    // MARK: - Pack overlay

    static func apply(
        to base: CoachBodyStateCopyRenderer.BasePack,
        input: CoachCopyBuildInput,
        profile: CoachStableDayProfile?
    ) -> CoachBodyStateCopyRenderer.BasePack {
        guard isActive(input) else { return base }

        if CoachCopyNutritionTiming.isSleepNow(input.timeOfDay) {
            return sleepNowPack(for: input, profile: profile)
        }

        switch input.scenario {
        case .stableDay:
            return applyStableDay(to: base, input: input, profile: profile)
        case .recoveryAfterHeavyYesterday:
            return applyRecoveryAfterHeavyYesterday(to: base)
        default:
            return base
        }
    }

    // MARK: - Teaser overlay

    static func teaserOverlay(for result: CoachEngine.Result) -> TeaserOverlay? {
        let input = CoachCopyBuildInput.from(result: result)
        guard isActive(input) else { return nil }

        let profile = CoachStableDayProfile.resolve(for: input)
        let title = CoachCopyNutritionTiming.isSleepNow(input.timeOfDay) ? sleepNowTitle : windDownTitle
        let headline = title
        let message = CoachCopyNutritionTiming.isSleepNow(input.timeOfDay)
            ? sleepNowTeaserMessage(for: input, profile: profile)
            : teaserMessage(for: input, profile: profile)

        return TeaserOverlay(
            todayTitle: title,
            todayMessage: message,
            coachHeadline: headline
        )
    }

    // MARK: - Stable day profiles

    private static func applyStableDay(
        to base: CoachBodyStateCopyRenderer.BasePack,
        input: CoachCopyBuildInput,
        profile: CoachStableDayProfile?
    ) -> CoachBodyStateCopyRenderer.BasePack {
        switch profile {
        case .lowRecoveryRest:
            return lowRecoveryRestWindDownPack(input: input)
        case .emptyDay, .none:
            return emptyDayWindDownPack()
        case .workBanked:
            return workBankedWindDownPack()
        case .tomorrowReserve:
            return tomorrowReserveWindDownPack()
        }
    }

    private static func applyRecoveryAfterHeavyYesterday(
        to base: CoachBodyStateCopyRenderer.BasePack
    ) -> CoachBodyStateCopyRenderer.BasePack {
        CoachBodyStateCopyRenderer.BasePack(
            assessment: .single(.en(
                "Yesterday's load is still in the legs — recovery matters more now.",
                "Вчерашняя нагрузка ещё в ногах — сейчас важнее восстановление."
            )),
            recommendation: .single(.en(
                "Do not add anything new tonight. Let the body move toward sleep.",
                "Не добавляйте ничего нового вечером — дайте телу дойти до сна."
            )),
            avoid: .single(.en(
                "No late intensity or extra recovery tasks.",
                "Без поздней интенсивности и лишних задач на восстановление."
            )),
            nextAction: windDownNextAction
        )
    }

    private static func lowRecoveryRestWindDownPack(
        input: CoachCopyBuildInput
    ) -> CoachBodyStateCopyRenderer.BasePack {
        CoachBodyStateCopyRenderer.BasePack(
            assessment: .single(lowRecoveryRestWindDownAssessment(for: input)),
            recommendation: .single(.en(
                "Do not add anything new tonight. Let the body move toward sleep.",
                "Не добавляйте ничего нового вечером — дайте телу дойти до сна."
            )),
            avoid: .single(.en(
                "No late intensity or extra recovery tasks.",
                "Без поздней интенсивности и лишних задач на восстановление."
            )),
            nextAction: windDownNextAction
        )
    }

    private static func emptyDayWindDownPack() -> CoachBodyStateCopyRenderer.BasePack {
        CoachBodyStateCopyRenderer.BasePack(
            assessment: .single(.en(
                "Enough for today — wind down calmly.",
                "На сегодня достаточно — спокойно завершаем день."
            )),
            recommendation: .single(.en(
                "Do not add anything new tonight. Let the body move toward sleep.",
                "Не добавляйте ничего нового вечером — дайте телу дойти до сна."
            )),
            avoid: .single(.en(
                "No late intensity or extra recovery tasks.",
                "Без поздней интенсивности и лишних задач на восстановление."
            )),
            nextAction: windDownNextAction
        )
    }

    private static func lowRecoveryRestWindDownAssessment(
        for input: CoachCopyBuildInput
    ) -> CoachBilingualText {
        guard input.dayReadiness.recoveryDataAvailable else {
            return .en(
                "Enough for today — wind down calmly.",
                "На сегодня достаточно — спокойно завершаем день."
            )
        }
        if input.dayReadiness.sleepIsLow {
            return .en(
                "Short night — recovery matters more now.",
                "Сон был коротким — сейчас важнее восстановление."
            )
        }
        return .en(
            "Recovery is lagging — rest matters more now.",
            "Восстановление отстаёт — сейчас важнее отдых."
        )
    }

    private static func workBankedWindDownPack() -> CoachBodyStateCopyRenderer.BasePack {
        CoachBodyStateCopyRenderer.BasePack(
            assessment: .single(.en(
                "The work is banked — now close the day calmly.",
                "Работа за день уже сделана — теперь спокойно закрываем день."
            )),
            recommendation: .single(.en(
                "Do not add anything new tonight. Let the body move toward sleep.",
                "Не добавляйте ничего нового вечером — дайте телу дойти до сна."
            )),
            avoid: .single(.en(
                "No late intensity or extra recovery tasks.",
                "Без поздней интенсивности и лишних задач на восстановление."
            )),
            nextAction: windDownNextAction
        )
    }

    private static func tomorrowReserveWindDownPack() -> CoachBodyStateCopyRenderer.BasePack {
        CoachBodyStateCopyRenderer.BasePack(
            assessment: .single(.en(
                "The work is banked — now close the day calmly.",
                "Работа за день уже сделана — теперь спокойно закрываем день."
            )),
            recommendation: .single(.en(
                "Tomorrow needs fresh legs — sleep gives more than another block.",
                "Завтра нужны свежие ноги — сон сейчас даст больше, чем ещё один блок."
            )),
            avoid: .single(.en(
                "No late intensity or extra recovery tasks.",
                "Без поздней интенсивности и лишних задач на восстановление."
            )),
            nextAction: windDownNextAction
        )
    }

    // MARK: - Shared strings

    private static let windDownTitle = CoachBilingualText.en(
        "Wind the day down",
        "Завершаем день"
    )

    private static let windDownNextAction = CoachCopySection.single(.en(
        "Choose a bedtime and start winding down.",
        "Решите, во сколько ложитесь, и начните вечерний ритуал."
    ))

    private static let sleepNowTitle = CoachBilingualText.en(
        "Time for sleep",
        "Пора спать"
    )

    private static let sleepNowNextAction = CoachCopySection.single(.en(
        "Head to bed — the day is done.",
        "Пора в кровать — день уже закончен."
    ))

    private static func sleepNowPack(
        for input: CoachCopyBuildInput,
        profile: CoachStableDayProfile?
    ) -> CoachBodyStateCopyRenderer.BasePack {
        CoachBodyStateCopyRenderer.BasePack(
            assessment: .single(sleepNowAssessment(for: input, profile: profile)),
            recommendation: .single(.en(
                "Nothing left to optimize tonight — sleep is the move.",
                "Сегодня уже нечего улучшать — следующий шаг только сон."
            )),
            avoid: .single(.en(
                "No screens, no plans, no last-minute load.",
                "Без экранов, планов и нагрузки в последний момент."
            )),
            nextAction: sleepNowNextAction
        )
    }

    private static func sleepNowAssessment(
        for input: CoachCopyBuildInput,
        profile: CoachStableDayProfile?
    ) -> CoachBilingualText {
        if profile == .tomorrowReserve {
            return .en(
                "Tomorrow needs fresh legs — sleep now.",
                "Завтра нужны свежие ноги — пора спать."
            )
        }
        if profile == .workBanked || input.modifiers.completedSeriousActivities != .none {
            return .en(
                "The work is done — sleep is the only job left.",
                "Работа за день сделана — осталась только кровать."
            )
        }
        if profile == .lowRecoveryRest {
            return .en(
                "Recovery needs sleep more than anything else tonight.",
                "Восстановлению сегодня нужен сон больше всего."
            )
        }
        return .en(
            "It's late — the day is closed.",
            "Уже поздно — день можно закрывать."
        )
    }

    private static func sleepNowTeaserMessage(
        for input: CoachCopyBuildInput,
        profile: CoachStableDayProfile?
    ) -> CoachBilingualText {
        if profile == .tomorrowReserve {
            return .en(
                "Sleep now — tomorrow starts fresh.",
                "Спите сейчас — завтра начнётся свежим."
            )
        }
        return .en(
            "Sleep now — nothing else matters tonight.",
            "Пора спать — больше ничего не нужно."
        )
    }

    private static func teaserMessage(
        for input: CoachCopyBuildInput,
        profile: CoachStableDayProfile?
    ) -> CoachBilingualText {
        if profile == .tomorrowReserve {
            return .en(
                "Tomorrow needs fresh legs — sleep first.",
                "Завтра нужны свежие ноги — сначала сон."
            )
        }
        if profile == .workBanked || input.modifiers.completedSeriousActivities != .none {
            return .en(
                "Work is done — protect sleep tonight.",
                "Работа сделана — сегодня вечером берегите сон."
            )
        }
        if profile == .lowRecoveryRest {
            if input.dayReadiness.sleepIsLow {
                return .en(
                    "Short night — protect sleep tonight.",
                    "Короткая ночь — сегодня вечером берегите сон."
                )
            }
            return .en(
                "Recovery is lagging — keep the evening quiet.",
                "Восстановление отстаёт — вечер без лишней нагрузки."
            )
        }
        return .en(
            "Enough for today — keep the evening quiet.",
            "На сегодня достаточно — вечер без лишней нагрузки."
        )
    }
}
