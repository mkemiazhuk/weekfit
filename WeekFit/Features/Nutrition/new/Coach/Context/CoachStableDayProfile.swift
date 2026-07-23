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
           modifiers.tomorrowDemand != .none {
            return .tomorrowReserve
        }

        if modifiers.completedSeriousActivities == .none,
           dayReadiness.recoveryDataAvailable,
           dayReadiness.isLowRecovery || dayReadiness.sleepIsLow {
            return .lowRecoveryRest
        }

        if modifiers.completedSeriousActivities != .none,
           modifiers.tomorrowDemand == .moderate || modifiers.tomorrowDemand == .hard {
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

    static func todayTitle(
        for profile: CoachStableDayProfile,
        hadHeavyYesterday: Bool = false,
        russian: Bool
    ) -> String {
        switch profile {
        case .emptyDay:
            return russian ? "Спокойный день" : "Steady day"
        case .lowRecoveryRest:
            if hadHeavyYesterday {
                return russian ? "После вчерашней нагрузки" : "After yesterday's load"
            }
            return russian ? "Спокойный день восстановления" : "Calm recovery day"
        case .tomorrowReserve:
            return russian ? "Запас на завтра" : "Save for tomorrow"
        case .workBanked:
            return russian ? "Восстанавливаемся" : "Recovering now"
        }
    }

    static func coachHeadline(
        for profile: CoachStableDayProfile,
        hadHeavyYesterday: Bool = false,
        russian: Bool
    ) -> String {
        todayTitle(for: profile, hadHeavyYesterday: hadHeavyYesterday, russian: russian)
    }

    static func teaserMessage(
        for profile: CoachStableDayProfile,
        timeOfDay: CoachTimeOfDay,
        hadHeavyYesterday: Bool = false,
        completedRecoveryWalkToday: Bool = false,
        tomorrowWorkoutTitle: String? = nil,
        russian: Bool
    ) -> String {
        switch profile {
        case .emptyDay:
            if completedRecoveryWalkToday,
               CoachCopyClosureTiming.allowsRestOfDayPhrasing(timeOfDay) {
                return russian
                    ? "Прогулка уже была — вечер можно провести спокойно."
                    : "Walk is already in — keep the evening calm."
            }
            return russian
                ? "Маленькие шаги лучше, чем наверстывать позже."
                : "Small steps beat a late catch-up."
        case .lowRecoveryRest:
            if hadHeavyYesterday,
               completedRecoveryWalkToday,
               !CoachCopyClosureTiming.allowsRestOfDayPhrasing(timeOfDay) {
                return russian
                    ? "Прогулка уже была — дальше спокойный ритм."
                    : "Walk is already in — keep a calm rhythm from here."
            }
            if hadHeavyYesterday, !CoachCopyClosureTiming.allowsRestOfDayPhrasing(timeOfDay) {
                return russian
                    ? "Сегодня мягче — без лишней интенсивности."
                    : "Go easier today — no extra intensity."
            }
            return russian
                ? "Без дополнительной интенсивности — сегодня она не нужна."
                : "Keep optional intensity off the table today."
        case .tomorrowReserve:
            return CoachWorkoutTitleLocalization.tomorrowReserveTeaser(
                rawTitle: tomorrowWorkoutTitle ?? "",
                russian: russian
            )
        case .workBanked:
            if CoachCopyClosureTiming.allowsRestOfDayPhrasing(timeOfDay) {
                return russian
                    ? "Остаток дня — восстановление."
                    : "Recovery is the job for the rest of today."
            }
            return russian
                ? "Без дополнительной интенсивности — сегодня она не нужна."
                : "Keep optional intensity off the table today."
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
            return lowRecoveryRestPack(input: input)
        case .tomorrowReserve:
            return tomorrowReservePack(input: input)
        case .workBanked:
            return workBankedPack(input: input)
        case .emptyDay, .none:
            return emptyDayPack(input: input)
        }
    }

    private static func emptyDayPack(input: CoachCopyBuildInput) -> BasePack {
        if CoachConversationSemanticTimingAudit.Context.completedRecoveryWalkToday(input),
           CoachCopyClosureTiming.allowsRestOfDayPhrasing(input.timeOfDay) {
            return BasePack(
                assessment: .single(.en(
                    "The walk is already in — the day can settle calmly.",
                    "Прогулка уже была — день можно завершить спокойно."
                )),
                recommendation: .single(.en(
                    "Keep the rest of the day unhurried — sleep matters more than extra steps.",
                    "Остаток дня без спешки — сон важнее лишних шагов."
                )),
                avoid: .single(.en(
                    "Do not force another walk just to chase the activity ring.",
                    "Не выходите на ещё одну прогулку только ради кольца активности."
                )),
                nextAction: .single(CoachCopyNutritionTiming.fastingAwareRecoveryNextAction(for: input))
            )
        }

        return BasePack(
            assessment: .single(.en(
                "Nothing urgent is pulling the day off balance.",
                "День идёт спокойно — ничего срочного."
            )),
            recommendation: .single(.en(
                "Small, steady moves beat catching up later.",
                "Лучше маленькие шаги, чем наверстывать позже."
            )),
            avoid: .single(CoachPresentationHorizonPhrasing.avoidBorrowingEveningEffort(input: input)),
            nextAction: .single(.en(
                "Take five quiet minutes before your next block.",
                "Перед следующим делом — пять минут тишины."
            ))
        )
    }

    private static func lowRecoveryRestPack(input: CoachCopyBuildInput) -> BasePack {
        if input.dayReadiness.hadHeavyYesterday {
            return heavyYesterdayLowRecoveryPack(input: input)
        }
        return standardLowRecoveryRestPack()
    }

    private static func heavyYesterdayLowRecoveryPack(input: CoachCopyBuildInput) -> BasePack {
        let hasWalk = CoachConversationSemanticTimingAudit.Context.completedRecoveryWalkToday(input)

        let assessment: CoachBilingualText
        if CoachCopyClosureTiming.allowsDayClosurePhrasing(
            timeOfDay: input.timeOfDay,
            conversationPhase: input.conversationPhase
        ) {
            assessment = .en(
                "Yesterday's load landed — let today close calmly.",
                "Вчерашняя нагрузка отозвалась — день можно завершить спокойно."
            )
        } else if CoachCopyClosureTiming.allowsRestOfDayPhrasing(input.timeOfDay) {
            assessment = .en(
                "Yesterday's load is still in the legs — keep the evening easy.",
                "Вчерашняя нагрузка ещё чувствуется — вечер без спешки."
            )
        } else {
            assessment = .en(
                "After yesterday's load — don't force it today.",
                "После вчерашней нагрузки сегодня лучше не форсировать."
            )
        }

        let recommendation: CoachBilingualText
        if hasWalk {
            recommendation = .en(
                "Walk is already in — keep a calm ordinary rhythm from here.",
                "Прогулка уже была — дальше держите обычный спокойный ритм."
            )
        } else if CoachCopyClosureTiming.allowsRestOfDayPhrasing(input.timeOfDay) {
            recommendation = .en(
                "Keep the rest of the day unhurried.",
                "Остаток дня без спешки."
            )
        } else {
            recommendation = .en(
                "Today is for recovery — keep the morning easy.",
                "Сегодня для восстановления — утро держите лёгким."
            )
        }

        return BasePack(
            assessment: .single(assessment),
            recommendation: .single(recommendation),
            avoid: .single(.en(
                "Don't chase steps or calories for the numbers alone.",
                "Не добирайте шаги или калории только ради цифр."
            )),
            nextAction: .single(
                CoachCopyNutritionTiming.fastingAwareRecoveryNextAction(for: input)
            )
        )
    }

    private static func standardLowRecoveryRestPack() -> BasePack {
        BasePack(
            assessment: .single(.en(
                "Recovery hasn't caught up after recent strain.",
                "Вы ещё не восстановились после недавней нагрузки."
            )),
            recommendation: .single(.en(
                "A quieter day now will help you return stronger tomorrow.",
                "Спокойный день сейчас — и завтра вернётесь сильнее."
            )),
            avoid: .single(.en(
                "A hard workout today is likely to add fatigue instead of fitness.",
                "Интенсивная тренировка сегодня скорее добавит усталости, чем принесёт пользу."
            )),
            nextAction: .single(.en(
                "Choose an easy walk, gentle stretching, or simply give yourself more time to recover.",
                "Выберите спокойную прогулку, лёгкую растяжку или просто дайте себе больше времени на восстановление."
            ))
        )
    }

    private static func tomorrowReservePack(input: CoachCopyBuildInput) -> BasePack {
        if input.modifiers.completedSeriousActivities != .none {
            return tomorrowReserveAfterWorkPack(input: input)
        }
        return tomorrowReserveFreshPack(input: input)
    }

    private static func tomorrowReserveFreshPack(input: CoachCopyBuildInput) -> BasePack {
        let workoutTitle = input.tomorrowWorkout?
            .title
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let assessment: CoachBilingualText
        if !workoutTitle.isEmpty {
            let copy = CoachWorkoutTitleLocalization.tomorrowMainSessionAssessment(
                rawTitle: workoutTitle,
                quietDayEmphasis: input.dayReadiness.sleepIsLow || input.dayReadiness.isLowRecovery
            )
            assessment = .en(copy.english, copy.russian)
        } else {
            assessment = .en(
                "Tomorrow brings your biggest effort — today is about arriving ready.",
                "Завтра вас ждёт основная нагрузка — сегодня важно подойти к ней свежим."
            )
        }

        return BasePack(
            assessment: .single(assessment),
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
                "Поешьте как следует, выпейте воды и закончите день пораньше."
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
                    "Сон сейчас даст больше, чем ещё одна нагрузка — сегодня время для восстановления."
                )
                : CoachCopyClosureTiming.allowsRestOfDayPhrasing(input.timeOfDay)
                    ? .en(
                        "Keep the rest of the day light so tomorrow's session still has quality.",
                        "Оставьте остаток дня лёгким, чтобы завтрашняя тренировка прошла качественно."
                    )
                    : .en(
                        "Keep today light so tomorrow's session still has quality.",
                        "Держите сегодня легко — завтрашняя тренировка должна пройти качественно."
                    )),
            avoid: .single(.en(
                "Extra intensity tonight is more likely to steal from tomorrow than improve today.",
                "Лишняя интенсивность сегодня скорее заберёт силы у завтрашнего дня, чем улучшит сегодняшний."
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
            "Двадцать минут тишины — прогулка, растяжка или просто полежите."
        )
    }

    private static func workBankedPack(input: CoachCopyBuildInput) -> BasePack {
        if input.modifiers.completedSeriousActivities == .twoOrMore {
            return stackedWorkBankedPack(input: input)
        }
        if !CoachCopyClosureTiming.allowsRestOfDayPhrasing(input.timeOfDay) {
            return daytimeWorkBankedPack(input: input)
        }
        return standardWorkBankedPack(input: input)
    }

    private static func daytimeWorkBankedPack(input: CoachCopyBuildInput) -> BasePack {
        let assessment: CoachBilingualText
        switch input.timeOfDay {
        case .morning, .midday:
            assessment = .en(
                "Morning work is done — keep the afternoon easy.",
                "Утренняя тренировка сделана — день дальше можно провести легко."
            )
        default:
            assessment = workBankedAssessment(for: input.modifiers.lastCompletedActivityType)
        }

        return BasePack(
            assessment: .single(assessment),
            recommendation: .single(daytimeWorkBankedRecommendation(for: input.timeOfDay)),
            avoid: .single(.en(
                "Don't stack another hard block on tired legs.",
                "Не добавляйте ещё одну интенсивную тренировку на уставшие ноги."
            )),
            nextAction: .single(workBankedNextAction(input: input))
        )
    }

    private static func daytimeWorkBankedRecommendation(for timeOfDay: CoachTimeOfDay) -> CoachBilingualText {
        switch timeOfDay {
        case .morning, .midday:
            return .en(
                "Leave hard blocks off the calendar until tomorrow.",
                "Интенсивные тренировки — не сегодня, а завтра."
            )
        default:
            return .en(
                "Keep today easy — no extra hard blocks.",
                "Сегодня спокойно — ничего доказывать не нужно."
            )
        }
    }

    private static func workBankedRecommendation(input: CoachCopyBuildInput) -> CoachBilingualText {
        if CoachCopyClosureTiming.allowsRestOfDayPhrasing(input.timeOfDay) {
            return .en(
                "Keep the rest of the day unhurried.",
                "Остаток дня без спешки."
            )
        }
        return daytimeWorkBankedRecommendation(for: input.timeOfDay)
    }

    private static func standardWorkBankedPack(input: CoachCopyBuildInput) -> BasePack {
        BasePack(
            assessment: .single(workBankedAssessment(for: input.modifiers.lastCompletedActivityType)),
            recommendation: .single(workBankedRecommendation(input: input)),
            avoid: .single(.en(
                "Don't stack another hard block on tired legs.",
                "Не добавляйте ещё одну интенсивную тренировку на уставшие ноги."
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
            recommendation: .single(workBankedRecommendation(input: input)),
            avoid: .single(.en(
                "Don't stack another hard block on tired legs.",
                "Не добавляйте ещё одну интенсивную тренировку на уставшие ноги."
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
                "Игра позади — сейчас важнее восстановление."
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
        if CoachCopyNutritionTiming.needsHydrationCatchUp(input) {
            return CoachCopyNutritionTiming.hydrationCatchUpNextAction(for: input)
        }
        if CoachCopyNutritionTiming.needsFuelCatchUp(input) {
            return CoachCopyNutritionTiming.fuelCatchUpNextAction(for: input)
        }
        if !input.mealWindowOpen {
            return CoachCopyNutritionTiming.fastingAwareRecoveryNextAction(for: input)
        }
        return .en(
            "Stretch or walk briefly, then refuel if needed.",
            "Растяжка или прогулка — потом еда, если нужно."
        )
    }
}
