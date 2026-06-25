import Foundation

/// Render profile for `stableDay` — does not change `CoachScenarioKey`.
enum CoachStableDayProfile: String, Equatable, Sendable, CaseIterable {
    case emptyDay
    case lowRecoveryRest
    case tomorrowReserve
    case workBanked

    static func resolve(for input: CoachCopyBuildInput) -> CoachStableDayProfile? {
        resolve(
            scenario: input.scenario,
            modifiers: input.modifiers,
            dayReadiness: input.dayReadiness
        )
    }

    static func resolve(
        scenario: CoachScenarioKey,
        modifiers: CoachScenarioModifiers,
        dayReadiness: CoachDayReadiness
    ) -> CoachStableDayProfile? {
        guard scenario == .stableDay else { return nil }

        if modifiers.completedSeriousActivities == .none,
           dayReadiness.isLowRecovery || dayReadiness.sleepIsLow {
            return .lowRecoveryRest
        }

        if modifiers.tomorrowDemand == .moderate || modifiers.tomorrowDemand == .hard {
            return .tomorrowReserve
        }

        if modifiers.completedSeriousActivities != .none {
            return .workBanked
        }

        return .emptyDay
    }

    var isProtective: Bool {
        self == .lowRecoveryRest || self == .tomorrowReserve
    }
}

// MARK: - Presentation chrome

enum CoachStableDayPresentation {

    static func todayTitle(for profile: CoachStableDayProfile, russian: Bool) -> String {
        switch profile {
        case .emptyDay:
            return russian ? "Спокойный день" : "Steady day"
        case .lowRecoveryRest:
            return russian ? "День восстановления" : "Recovery day"
        case .tomorrowReserve:
            return russian ? "Запас на завтра" : "Save for tomorrow"
        case .workBanked:
            return russian ? "Восстанавливаемся" : "Recovering now"
        }
    }

    static func coachHeadline(for profile: CoachStableDayProfile, russian: Bool) -> String {
        switch profile {
        case .emptyDay:
            return russian ? "Спокойный день" : "Steady day"
        case .lowRecoveryRest:
            return russian ? "День восстановления" : "Recovery day"
        case .tomorrowReserve:
            return russian ? "Запас на завтра" : "Save for tomorrow"
        case .workBanked:
            return russian ? "Восстанавливаемся" : "Recovering now"
        }
    }

    static func teaserMessage(for profile: CoachStableDayProfile, russian: Bool) -> String {
        switch profile {
        case .emptyDay:
            return russian
                ? "Маленькие шаги лучше, чем догонять вечером."
                : "Small steps beat a late catch-up."
        case .lowRecoveryRest:
            return russian
                ? "Сегодня лучше без лишней интенсивности."
                : "Keep optional intensity off the table today."
        case .tomorrowReserve:
            return russian
                ? "Берегите силы на завтра."
                : "Hold reserve for tomorrow's session."
        case .workBanked:
            return russian
                ? "Остаток дня — восстановление."
                : "Recovery is the job for the rest of today."
        }
    }

    static func semanticColor(for profile: CoachStableDayProfile) -> CoachSemanticColor {
        switch profile {
        case .emptyDay, .workBanked:
            return .stable
        case .lowRecoveryRest:
            return .recovery
        case .tomorrowReserve:
            return .protection
        }
    }

    static func icon(for profile: CoachStableDayProfile, lastCompletedActivityType: CoachActivityType) -> String {
        switch profile {
        case .emptyDay:
            return "checkmark.circle"
        case .lowRecoveryRest:
            return "bed.double.fill"
        case .tomorrowReserve:
            return "moon.stars.fill"
        case .workBanked:
            return CoachPresentationResolver.activityTypeIcon(lastCompletedActivityType)
                ?? "figure.cooldown"
        }
    }

    static func urgencyLevel(for profile: CoachStableDayProfile) -> CoachUrgencyLevel {
        profile.isProtective ? .protective : .calm
    }
}

// MARK: - Profile copy

enum CoachStableDayCopy {

    struct BasePack: Equatable {
        let assessment: CoachCopySection
        let recommendation: CoachCopySection
        let avoid: CoachCopySection
        let nextAction: CoachCopySection
    }

    static func basePack(for input: CoachCopyBuildInput) -> BasePack {
        switch CoachStableDayProfile.resolve(for: input) {
        case .lowRecoveryRest:
            return lowRecoveryRestPack()
        case .tomorrowReserve:
            return tomorrowReservePack(input: input)
        case .workBanked:
            return workBankedPack(input: input)
        case .emptyDay, .none:
            return emptyDayPack()
        }
    }

    private static func emptyDayPack() -> BasePack {
        BasePack(
            assessment: .single(.en(
                "Nothing urgent is pulling the day off balance.",
                "День идёт спокойно — ничего срочного."
            )),
            recommendation: .single(.en(
                "Small, steady moves beat a late catch-up.",
                "Лучше маленькие шаги, чем догонять вечером."
            )),
            avoid: .single(.en(
                "Don't borrow effort from tonight without a reason.",
                "Не тратьте вечерние силы без необходимости."
            )),
            nextAction: .single(.en(
                "Take five quiet minutes before your next block.",
                "Перед следующим делом — пять минут тишины."
            ))
        )
    }

    private static func lowRecoveryRestPack() -> BasePack {
        BasePack(
            assessment: .single(.en(
                "Recovery hasn't caught up after recent strain.",
                "Организм ещё не успел восстановиться после недавней нагрузки."
            )),
            recommendation: .single(.en(
                "A quieter day now will help you return stronger tomorrow.",
                "Спокойный день сейчас поможет быстрее вернуться к нормальной нагрузке завтра."
            )),
            avoid: .single(.en(
                "A hard workout today is likely to add fatigue instead of fitness.",
                "Интенсивная тренировка сегодня скорее добавит усталости, чем принесёт пользу."
            )),
            nextAction: .single(.en(
                "Choose an easy walk, gentle stretching, or simply give yourself more time to recover.",
                "Выберите спокойную прогулку, лёгкую растяжку или просто дайте организму больше времени на восстановление."
            ))
        )
    }

    private static func tomorrowReservePack(input: CoachCopyBuildInput) -> BasePack {
        if input.modifiers.completedSeriousActivities != .none {
            return tomorrowReserveAfterWorkPack(input: input)
        }
        return tomorrowReserveFreshPack()
    }

    private static func tomorrowReserveFreshPack() -> BasePack {
        BasePack(
            assessment: .single(.en(
                "Tomorrow brings your biggest effort — today is about arriving ready.",
                "Завтра вас ждёт основная нагрузка — сегодня важно подойти к ней свежим."
            )),
            recommendation: .single(.en(
                "Focus on recovery instead of trying to fit in one more workout.",
                "Сегодня лучше сосредоточиться на восстановлении, а не пытаться успеть ещё одну тренировку."
            )),
            avoid: .single(.en(
                "Extra intensity now could take away from tomorrow's performance.",
                "Лишняя интенсивность сегодня может ухудшить завтрашнюю тренировку."
            )),
            nextAction: .single(.en(
                "Eat well, hydrate, and finish the day early.",
                "Нормально поешьте, восполните воду и завершите день пораньше."
            ))
        )
    }
    
    private static func tomorrowReserveAfterWorkPack(input: CoachCopyBuildInput) -> BasePack {
        let windDown = CoachCopyNutritionTiming.isWindDown(input.timeOfDay)

        return BasePack(
            assessment: .single(.en(
                "Today already has enough work in it — tomorrow needs fresh legs.",
                "На сегодня нагрузки уже достаточно — завтра нужны свежие ноги."
            )),
            recommendation: .single(windDown
                ? .en(
                    "Switch to recovery mode now; sleep will do more than another effort.",
                    "Сейчас лучше перейти в режим восстановления: сон даст больше, чем ещё одна нагрузка."
                )
                : .en(
                    "Keep the rest of the day light so tomorrow's session still has quality.",
                    "Оставьте остаток дня лёгким, чтобы завтрашняя тренировка прошла качественно."
                )),
            avoid: .single(.en(
                "Extra intensity tonight is more likely to steal from tomorrow than improve today.",
                "Лишняя интенсивность сегодня скорее заберёт силы у завтра, чем улучшит сегодняшний день."
            )),
            nextAction: .single(tomorrowReserveNextAction(input: input, windDown: windDown))
        )
    }
    
    private static func tomorrowReserveNextAction(
        input: CoachCopyBuildInput,
        windDown: Bool
    ) -> CoachBilingualText {
        if windDown {
            return .en(
                "Sip some water if thirsty, then rest.",
                "Если хочется пить — немного воды и отдых."
            )
        }
        if input.modifiers.fuelBehind || input.fuelState.isBehind {
            return CoachCopyNutritionTiming.fuelCatchUpNextAction(for: input)
        }
        if input.modifiers.hydrationBehind || input.hydrationState.isBehind {
            return CoachCopyNutritionTiming.hydrationCatchUpNextAction(for: input)
        }
        return .en(
            "Take twenty quiet minutes — walk, stretch, or lie down.",
            "Двадцать минут тишины — прогулка или растяжка."
        )
    }

    private static func workBankedPack(input: CoachCopyBuildInput) -> BasePack {
        if input.modifiers.completedSeriousActivities == .twoOrMore {
            return stackedWorkBankedPack(input: input)
        }
        if input.timeOfDay == .midday {
            return earlyDoneWorkBankedPack(input: input)
        }
        return standardWorkBankedPack(input: input)
    }

    private static func standardWorkBankedPack(input: CoachCopyBuildInput) -> BasePack {
        BasePack(
            assessment: .single(workBankedAssessment(for: input.modifiers.lastCompletedActivityType)),
            recommendation: .single(.en(
                "Keep the rest of the day unhurried.",
                "Остаток дня без спешки."
            )),
            avoid: .single(.en(
                "Don't stack another hard block on tired legs.",
                "Не добавляйте ещё один тяжёлый блок."
            )),
            nextAction: .single(workBankedNextAction(input: input))
        )
    }

    private static func earlyDoneWorkBankedPack(input: CoachCopyBuildInput) -> BasePack {
        BasePack(
            assessment: .single(.en(
                "Morning work is done — the afternoon can stay easy.",
                "Утренняя работа сделана — день можно провести легко."
            )),
            recommendation: .single(.en(
                "Leave hard blocks off the calendar until tomorrow.",
                "Тяжёлые блоки — не сегодня."
            )),
            avoid: .single(.en(
                "Don't stack another hard block on tired legs.",
                "Не добавляйте ещё один тяжёлый блок."
            )),
            nextAction: .single(workBankedNextAction(input: input))
        )
    }

    private static func stackedWorkBankedPack(input: CoachCopyBuildInput) -> BasePack {
        BasePack(
            assessment: .single(.en(
                "A full day of training — now it's about landing softly.",
                "Насыщенный день — сейчас важно спокойно приземлиться."
            )),
            recommendation: .single(.en(
                "Keep the rest of the day unhurried.",
                "Остаток дня без спешки."
            )),
            avoid: .single(.en(
                "Don't stack another hard block on tired legs.",
                "Не добавляйте ещё один тяжёлый блок."
            )),
            nextAction: .single(workBankedNextAction(input: input))
        )
    }

    private static func workBankedAssessment(for activityType: CoachActivityType) -> CoachBilingualText {
        switch activityType {
        case .cycling:
            return .en(
                "Ride is banked — recovery is the job now.",
                "Заезд сделан — сейчас задача восстановиться."
            )
        case .running:
            return .en(
                "Run is banked — recovery is the job now.",
                "Пробежка сделана — сейчас задача восстановиться."
            )
        case .tennis, .squash:
            return .en(
                "Match is over — recovery comes first.",
                "Игра позади — восстановление в приоритете."
            )
        case .upperBody, .lowerBody, .core, .fullBody:
            return .en(
                "Strength work is banked — muscles need quiet now.",
                "Силовая сделана — мышцам нужен отдых."
            )
        default:
            return .en(
                "Training is banked — recovery is the job now.",
                "Тренировка сделана — сейчас задача восстановиться."
            )
        }
    }

    private static func workBankedNextAction(input: CoachCopyBuildInput) -> CoachBilingualText {
        if input.modifiers.fuelBehind || input.fuelState.isBehind {
            return CoachCopyNutritionTiming.fuelCatchUpNextAction(for: input)
        }
        if input.modifiers.hydrationBehind || input.hydrationState.isBehind {
            return CoachCopyNutritionTiming.hydrationCatchUpNextAction(for: input)
        }
        return .en(
            "Stretch or walk briefly, then refuel if needed.",
            "Растяжка или прогулка — потом еда, если нужно."
        )
    }
}
