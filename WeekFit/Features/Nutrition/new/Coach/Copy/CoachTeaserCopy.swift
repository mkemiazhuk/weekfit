import Foundation

/// Bilingual Today teaser + Coach headline chrome — lives next to `CoachCopyRegistry`.
enum CoachTeaserCopy {

    struct Content: Equatable, Sendable {
        let todayTitle: CoachBilingualText
        let todayMessage: CoachBilingualText
        let coachHeadline: CoachBilingualText
    }

    static func resolve(
        from result: CoachEngine.Result,
        localizedAssessment: String
    ) -> Content {
        if let overlay = CoachDayClosingCopyPolicy.teaserOverlay(for: result) {
            return Content(
                todayTitle: overlay.todayTitle,
                todayMessage: overlay.todayMessage,
                coachHeadline: overlay.coachHeadline
            )
        }

        let scenario = result.scenario
        let assessmentFallback = bi(localizedAssessment, localizedAssessment)

        let todayTitle = todayTitleContent(
            scenario: scenario,
            assessmentFallback: assessmentFallback,
            result: result
        )
        let todayMessage = todayMessageContent(scenario: scenario, result: result)
        let coachHeadline = coachHeadlineContent(scenario: scenario, result: result)

        return Content(
            todayTitle: todayTitle,
            todayMessage: todayMessage,
            coachHeadline: coachHeadline
        )
    }

    // MARK: - Today title

    private static func todayTitleContent(
        scenario: CoachScenarioKey,
        assessmentFallback: CoachBilingualText,
        result: CoachEngine.Result
    ) -> CoachBilingualText {
        switch scenario {
        case .tomorrowProtection:
            return bi("Protect your energy", "Сегодня уже достаточно")
        case .protectTomorrowFresh:
            return bi("Save it for tomorrow", "Сохраните запас на завтра")
        case .recoveryAfterHeavyYesterday:
            return bi("Recovery day", "День восстановления")
        case .lowRecoveryPrep:
            return bi("Check readiness first", "Проверьте готовность")
        case .morningReadiness:
            return bi("Set your pace", "С чего начать")
        case .stableDay:
            if let profile = stableDayProfile(from: result) {
                return bi(
                    CoachStableDayPresentation.todayTitle(for: profile, russian: false),
                    CoachStableDayPresentation.todayTitle(for: profile, russian: true)
                )
            }
            return bi("Steady day", "Спокойный день")
        case .duringEndurance:
            switch result.modifiers.activityType {
            case .running:
                return bi("On the run", "На пробежке")
            case .cycling:
                return bi("On the ride", "На заезде")
            default:
                return bi("In session", "В тренировке")
            }
        case .walkAfterHeavyLoad:
            let walkPhase = CoachWalkAfterHeavyLoadPresentation.phase(for: result.context)
            let hasSeriousWork = result.modifiers.completedSeriousActivities != .none
            return bi(
                CoachWalkAfterHeavyLoadPresentation.todayTitle(
                    for: walkPhase,
                    hasSeriousWork: hasSeriousWork,
                    russian: false
                ),
                CoachWalkAfterHeavyLoadPresentation.todayTitle(
                    for: walkPhase,
                    hasSeriousWork: hasSeriousWork,
                    russian: true
                )
            )
        case .activeEndurance:
            return activeEnduranceTitle(activityType: result.modifiers.activityType)
        case .duringRacket:
            return bi("In the match", "В игре")
        case .duringStrength:
            return bi("Lifting now", "Силовая идёт")
        case .duringRecovery:
            return bi("Recovery time", "Восстановление")
        case .postEnduranceImmediate:
            return postEnduranceImmediateTitle(activityType: result.modifiers.activityType)
        case .postRacketImmediate:
            return bi("Match done", "Игра позади")
        case .postStrengthImmediate:
            return bi("Last set done", "Последний подход")
        case .postRecoveryImmediate:
            return bi("Nice work", "Хорошая работа")
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled:
            return bi("Recovering now", "Восстанавливаемся")
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            return bi("Evening recovery", "Вечер после нагрузки")
        case .walkLightDay:
            return bi("Easy walk", "Лёгкая прогулка")
        case .walkEveningWindDown:
            return bi("Evening walk", "Вечерняя прогулка")
        case .walkRecoveryAction:
            let walkPhase = CoachWalkRecoveryActionPresentation.phase(for: result.context)
            return bi(
                CoachWalkRecoveryActionPresentation.todayTitle(for: walkPhase, russian: false),
                CoachWalkRecoveryActionPresentation.todayTitle(for: walkPhase, russian: true)
            )
        case .activeRacket:
            return bi("Match soon", "Игра скоро")
        case .activeStrength:
            return bi("Strength next", "Силовая впереди")
        case .activeRecovery:
            return bi("Recovery ahead", "Время восстановить")
        case .saunaPreparation:
            return bi("Before sauna", "Перед баней")
        case .saunaActive:
            return bi("In sauna", "В бане")
        case .saunaRecovery:
            return bi("After heat", "После сауны")
        default:
            return assessmentFallback
        }
    }

    private static func activeEnduranceTitle(activityType: CoachActivityType) -> CoachBilingualText {
        switch activityType {
        case .cycling:
            return bi("Preparing to ride", "Готовимся к заезду")
        case .running:
            return bi("Preparing to run", "Готовимся к бегу")
        default:
            return bi("Before session", "Перед тренировкой")
        }
    }

    // MARK: - Today message

    private static func todayMessageContent(
        scenario: CoachScenarioKey,
        result: CoachEngine.Result
    ) -> CoachBilingualText {
        switch scenario {
        case .tomorrowProtection:
            if CoachCopyNutritionTiming.isWindDown(result.context.timeOfDay) {
                return bi(
                    "Wind down — sleep is the priority.",
                    "Сбавьте обороты — сейчас важнее сон."
                )
            }
            return bi("Keep the evening easy.", "Остаток дня спокойный.")
        case .protectTomorrowFresh:
            return bi(
                "Good recovery — spend today with tomorrow in mind.",
                "Восстановление хорошее — берегите силы на завтра."
            )
        case .recoveryAfterHeavyYesterday:
            return bi(
                "Yesterday still counts — go easier today.",
                "Вчера ещё в теле — сегодня мягче."
            )
        case .lowRecoveryPrep:
            return bi(
                "Start lighter than the plan says.",
                "Начните легче, чем в плане."
            )
        case .morningReadiness:
            return bi(
                "Lead with how you feel.",
                "Слушайте тело, не только календарь."
            )
        case .stableDay:
            if let profile = stableDayProfile(from: result) {
                return bi(
                    CoachStableDayPresentation.teaserMessage(for: profile, russian: false),
                    CoachStableDayPresentation.teaserMessage(for: profile, russian: true)
                )
            }
            return bi(
                "Small steps beat a late catch-up.",
                "Маленькие шаги лучше, чем догонять вечером."
            )
        case .duringEndurance:
            return bi("Hold effort flat.", "Держите темп ровным.")
        case .walkAfterHeavyLoad:
            let walkPhase = CoachWalkAfterHeavyLoadPresentation.phase(for: result.context)
            let hasSeriousWork = result.modifiers.completedSeriousActivities != .none
            return bi(
                CoachWalkAfterHeavyLoadPresentation.teaserMessage(
                    for: walkPhase,
                    hasSeriousWork: hasSeriousWork,
                    russian: false
                ),
                CoachWalkAfterHeavyLoadPresentation.teaserMessage(
                    for: walkPhase,
                    hasSeriousWork: hasSeriousWork,
                    russian: true
                )
            )
        case .activeEndurance:
            return bi(
                "Set your pace — don't chase from the gun.",
                "Настройте темп — не гонитесь с порога."
            )
        case .activeRacket:
            return bi(
                "Warm up — first games under control.",
                "Разогрейтесь — первые геймы спокойно."
            )
        case .activeStrength:
            return bi(
                "First sets light — form over weight.",
                "Первые подходы легко — форма важнее."
            )
        case .activeRecovery:
            return bi(
                "Soft from minute one — no pressure.",
                "Мягко с первой минуты — без давления."
            )
        case .duringRacket:
            return bi("Reset between points.", "Между очками успевайте сброс.")
        case .duringStrength:
            return bi(
                "Form beats rushed reps.",
                "Форма важнее торопливых повторов."
            )
        case .duringRecovery:
            return bi(
                "Stay soft — nothing to push.",
                "Мягко — тут нечего выжимать."
            )
        case .postEnduranceImmediate:
            return bi(
                "Cooldown first, then refuel.",
                "Сначала заминка — потом еда и вода."
            )
        case .postRacketImmediate:
            return bi(
                "Cooldown on court — then water and stretch.",
                "Заминка на корте — потом вода и растяжка."
            )
        case .postStrengthImmediate:
            return bi(
                "Let muscles cool — then protein and water.",
                "Дайте мышцам остыть — потом белок и вода."
            )
        case .postRecoveryImmediate:
            return bi(
                "Stay quiet a few more minutes.",
                "Побудьте в тишине ещё несколько минут."
            )
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled:
            return bi(
                "Keep the next hour unhurried.",
                "Следующий час без спешки."
            )
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            if CoachCopyNutritionTiming.isWindDown(result.context.timeOfDay) {
                return bi(
                    "Wind down — sleep is the work.",
                    "Сбавьте обороты — сон важнее."
                )
            }
            return bi(
                "Keep the evening easy.",
                "Вечер лёгкий — без лишней нагрузки."
            )
        case .walkLightDay:
            return bi("Easy pace — no goal to hit.", "Лёгкий темп — без цели.")
        case .walkEveningWindDown:
            return bi("Slow pace before bed.", "Медленный темп перед сном.")
        case .walkRecoveryAction:
            let walkPhase = CoachWalkRecoveryActionPresentation.phase(for: result.context)
            return bi(
                CoachWalkRecoveryActionPresentation.teaserMessage(for: walkPhase, russian: false),
                CoachWalkRecoveryActionPresentation.teaserMessage(for: walkPhase, russian: true)
            )
        case .saunaPreparation:
            return bi("Hydrate before the heat.", "Выпейте воды перед жаром.")
        case .saunaActive:
            return bi("Short rounds, cool breaks.", "Короткие заходы — паузы на прохладу.")
        case .saunaRecovery:
            return bi("Cool down slowly.", "Остывайте постепенно.")
        default:
            return bi("", "")
        }
    }

    // MARK: - Coach headline

    private static func coachHeadlineContent(
        scenario: CoachScenarioKey,
        result: CoachEngine.Result
    ) -> CoachBilingualText {
        let context = result.context
        let modifiers = result.modifiers
        let activityType = modifiers.activityType

        switch scenario {
        case .morningReadiness:
            return bi("Morning reset", "С чего начать день")
        case .stableDay:
            if let profile = CoachStableDayProfile.resolve(
                scenario: scenario,
                modifiers: modifiers,
                dayReadiness: context.dayReadiness
            ) {
                return bi(
                    CoachStableDayPresentation.coachHeadline(for: profile, russian: false),
                    CoachStableDayPresentation.coachHeadline(for: profile, russian: true)
                )
            }
            return bi("Steady day", "Спокойный день")
        case .duringEndurance:
            switch activityType {
            case .running:
                return bi("On the run", "На пробежке")
            case .cycling:
                return bi("On the ride", "На заезде")
            default:
                return bi("In session", "В тренировке")
            }
        case .walkAfterHeavyLoad:
            let walkPhase = CoachWalkAfterHeavyLoadPresentation.phase(for: context)
            let hasSeriousWork = modifiers.completedSeriousActivities != .none
            return bi(
                CoachWalkAfterHeavyLoadPresentation.coachHeadline(
                    for: walkPhase,
                    hasSeriousWork: hasSeriousWork,
                    russian: false
                ),
                CoachWalkAfterHeavyLoadPresentation.coachHeadline(
                    for: walkPhase,
                    hasSeriousWork: hasSeriousWork,
                    russian: true
                )
            )
        case .tomorrowProtection:
            return bi("Recovery mode", "Режим восстановления")
        case .protectTomorrowFresh:
            return bi("Save for tomorrow", "Запас на завтра")
        case .recoveryAfterHeavyYesterday:
            return bi("Recovery day", "День восстановления")
        case .lowRecoveryPrep:
            return bi("Check readiness", "Проверьте готовность")
        case .activeEndurance:
            return activeEnduranceHeadline(activityType: activityType)
        case .duringRacket:
            return bi("In the match", "В игре")
        case .duringStrength:
            return bi("Under load", "Под нагрузкой")
        case .duringRecovery:
            return bi("Recovery session", "Сессия восстановления")
        case .postEnduranceImmediate:
            return postEnduranceImmediateHeadline(activityType: activityType)
        case .postRacketImmediate:
            return bi("After the match", "После игры")
        case .postStrengthImmediate:
            return bi("After lifting", "После силовой")
        case .postRecoveryImmediate:
            return bi("Session complete", "Сессия завершена")
        case .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled:
            return bi("Recovering", "Восстанавливаемся")
        case .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            return bi("Day's end", "Завершение дня")
        case .walkLightDay:
            return bi("Easy walk", "Лёгкая прогулка")
        case .walkEveningWindDown:
            return bi("Evening walk", "Вечерняя прогулка")
        case .walkRecoveryAction:
            let walkPhase = CoachWalkRecoveryActionPresentation.phase(for: context)
            return bi(
                CoachWalkRecoveryActionPresentation.coachHeadline(for: walkPhase, russian: false),
                CoachWalkRecoveryActionPresentation.coachHeadline(for: walkPhase, russian: true)
            )
        case .activeRacket:
            return bi("Before the match", "Перед игрой")
        case .activeStrength:
            return bi("Before lifting", "Перед силовой")
        case .activeRecovery:
            return bi("Before recovery", "Перед восстановлением")
        case .saunaPreparation:
            return bi("Before sauna", "Перед баней")
        case .saunaActive:
            return bi("In the heat", "В жаре")
        case .saunaRecovery:
            return bi("After sauna", "После сауны")
        default:
            return bi("Coach", "Коуч")
        }
    }

    private static func activeEnduranceHeadline(activityType: CoachActivityType) -> CoachBilingualText {
        switch activityType {
        case .cycling:
            return bi("Before the ride", "Перед заездом")
        case .running:
            return bi("Before the run", "Перед пробежкой")
        default:
            return bi("Before session", "Перед тренировкой")
        }
    }

    private static func postEnduranceImmediateTitle(activityType: CoachActivityType) -> CoachBilingualText {
        switch activityType {
        case .cycling:
            return bi("Ride done", "Заезд завершён")
        case .running:
            return bi("Run done", "Пробежка завершена")
        default:
            return bi("Session done", "Тренировка завершена")
        }
    }

    private static func postEnduranceImmediateHeadline(activityType: CoachActivityType) -> CoachBilingualText {
        switch activityType {
        case .cycling:
            return bi("After the ride", "После заезда")
        case .running:
            return bi("After the run", "После пробежки")
        default:
            return bi("After session", "После тренировки")
        }
    }

    // MARK: - Helpers

    private static func stableDayProfile(from result: CoachEngine.Result) -> CoachStableDayProfile? {
        CoachStableDayProfile.resolve(
            scenario: result.scenario,
            modifiers: result.modifiers,
            dayReadiness: result.context.dayReadiness
        )
    }

    private static func bi(_ english: String, _ russian: String) -> CoachBilingualText {
        CoachBilingualText.en(english, russian)
    }
}
