import Foundation

/// Applies athlete body state to copy for Phase 2A target scenarios. `normal` preserves base text.
enum CoachBodyStateCopyRenderer {

    struct BasePack: Equatable {
        let assessment: CoachCopySection
        let recommendation: CoachCopySection
        let avoid: CoachCopySection
        let nextAction: CoachCopySection
    }

    private static let phase2AScenarios: Set<CoachScenarioKey> = [
        .stableDay,
        .activeEndurance,
        .duringEndurance,
        .postEnduranceImmediate,
        .activeStrength,
        .duringStrength,
        .activeRacket,
        .duringRacket,
        .walkLightDay,
        .walkAfterHeavyLoad,
        .walkEveningWindDown,
        .walkRecoveryAction
    ]

    static func applies(to scenario: CoachScenarioKey) -> Bool {
        phase2AScenarios.contains(scenario)
    }

    static func apply(
        base: BasePack,
        scenario: CoachScenarioKey,
        activityType: CoachActivityType,
        bodyState: CoachBodyState,
        stableDayProfile: CoachStableDayProfile? = nil,
        sessionPhase: CoachSessionPhase = .idle
    ) -> BasePack {
        guard applies(to: scenario), bodyState != .normal, bodyState != .fresh else {
            return base
        }

        switch scenario {
        case .morningReadiness:
            return applyMorningReadiness(base: base, bodyState: bodyState)
        case .stableDay:
            switch stableDayProfile {
            case .workBanked:
                return applyWorkBankedStableDay(base: base, bodyState: bodyState)
            case .lowRecoveryRest:
                return applyLowRecoveryRestStableDay(base: base, bodyState: bodyState)
            default:
                return applyStableDay(base: base, bodyState: bodyState)
            }
        case .activeEndurance:
            return applyActiveEndurance(base: base, activityType: activityType, bodyState: bodyState)
        case .duringEndurance:
            return applyDuringEndurance(base: base, bodyState: bodyState)
        case .postEnduranceImmediate:
            return applyPostEnduranceImmediate(base: base, bodyState: bodyState)
        case .activeStrength:
            return applyActiveStrength(base: base, activityType: activityType, bodyState: bodyState)
        case .duringStrength:
            return applyDuringStrength(base: base, bodyState: bodyState)
        case .activeRacket:
            return applyActiveRacket(base: base, activityType: activityType, bodyState: bodyState)
        case .duringRacket:
            return applyDuringRacket(base: base, bodyState: bodyState)
        case .walkLightDay:
            return applyWalkLightDay(base: base, bodyState: bodyState)
        case .walkAfterHeavyLoad:
            if sessionPhase == .during {
                return applyWalkAfterHeavyLoadLive(base: base, bodyState: bodyState)
            }
            return base
        case .walkEveningWindDown:
            return applyWalkEveningWindDown(base: base, bodyState: bodyState)
        case .walkRecoveryAction:
            if sessionPhase == .immediatePost {
                return base
            }
            if sessionPhase == .pre {
                return base
            }
            return applyWalkRecoveryActionLive(base: base, bodyState: bodyState)
        default:
            return base
        }
    }

    // MARK: - morningReadiness

    private static func applyMorningReadiness(
        base: BasePack,
        bodyState: CoachBodyState
    ) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: .single(.en(
                    "It's morning — and the body is still catching up.",
                    "Утро — а тело ещё не полностью проснулось."
                )),
                recommendation: .single(.en(
                    "Start slower than the calendar suggests — feel first.",
                    "Начните медленнее, чем подсказывает календарь — сначала ощущения."
                )),
                avoid: .single(.en(
                    "Don't match yesterday's pace from the first hour.",
                    "Не повторяйте вчерашний темп с первого часа."
                )),
                nextAction: base.nextAction
            )
        case .veryFatigued:
            return BasePack(
                assessment: .single(.en(
                    "It's morning — sleep and recovery haven't fully landed yet.",
                    "Утро — сон и восстановление ещё не полностью вернулись."
                )),
                recommendation: .single(.en(
                    "Keep the first block gentle — no intensity before you feel ready.",
                    "Первый блок мягко — без интенсивности, пока не почувствуете готовность."
                )),
                avoid: .single(.en(
                    "Don't stack demands before the body wakes up.",
                    "Не нагружайте себя, пока тело не проснулось."
                )),
                nextAction: .single(.en(
                    "Ten quiet minutes, then pick one priority.",
                    "Десять минут тишины — потом одна главная задача."
                ))
            )
        }
    }

    // MARK: - stableDay

    private static func applyWorkBankedStableDay(base: BasePack, bodyState: CoachBodyState) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: .single(.en(
                    "Training is banked — energy is softer than usual.",
                    "Тренировка сделана — энергии чуть меньше обычного."
                )),
                recommendation: .single(.en(
                    "Keep optional intensity off the table for the rest of today.",
                    "Оставьте необязательную интенсивность на остаток дня."
                )),
                avoid: base.avoid,
                nextAction: base.nextAction
            )
        case .veryFatigued:
            return BasePack(
                assessment: .single(.en(
                    "Training is done — the body is asking for margin, not more load.",
                    "Тренировка сделана — телу нужен запас, а не ещё нагрузка."
                )),
                recommendation: .single(.en(
                    "Treat recovery as the plan for the rest of today.",
                    "Восстановление — план на остаток дня."
                )),
                avoid: base.avoid,
                nextAction: .single(.en(
                    "Rest or walk briefly before anything demanding.",
                    "Отдых или короткая прогулка — перед чем-то серьёзным."
                ))
            )
        }
    }

    private static func applyLowRecoveryRestStableDay(base: BasePack, bodyState: CoachBodyState) -> BasePack {
        // Profile-specific packs already own recovery timing; body state must not replace them.
        base
    }

    private static func applyStableDay(base: BasePack, bodyState: CoachBodyState) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: .single(.en(
                    "Nothing urgent — though energy is softer than usual.",
                    "Ничего срочного — но энергии чуть меньше обычного."
                )),
                recommendation: .single(.en(
                    "Keep optional intensity off the table today.",
                    "Оставьте необязательную интенсивность на сегодня."
                )),
                avoid: base.avoid,
                nextAction: base.nextAction
            )
        case .veryFatigued:
            return BasePack(
                assessment: .single(.en(
                    "Quiet day — the body is asking for margin, not more load.",
                    "Спокойный день — телу нужен запас, а не ещё нагрузка."
                )),
                recommendation: .single(.en(
                    "Treat small tasks as enough — recovery is part of the plan.",
                    "Мелких дел достаточно — восстановление тоже часть плана."
                )),
                avoid: .single(.en(
                    "Don't borrow effort from tomorrow to fill today.",
                    "Не занимайте силы у завтрашнего дня."
                )),
                nextAction: .single(.en(
                    "Rest or walk briefly before anything demanding.",
                    "Отдых или короткая прогулка — перед чем-то серьёзным."
                ))
            )
        }
    }

    // MARK: - activeEndurance

    private static func applyActiveEndurance(
        base: BasePack,
        activityType: CoachActivityType,
        bodyState: CoachBodyState
    ) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: .single(activeEnduranceFatiguedAssessment(activityType: activityType)),
                recommendation: .single(.en(
                    "Treat the first 20 minutes as a systems check — start easier than usual.",
                    "Первые 20 минут — проверка систем: начните легче обычного."
                )),
                avoid: .single(.en(
                    "Don't open at yesterday's pace or planned power.",
                    "Не стартуйте на вчерашнем темпе или запланированной мощности."
                )),
                nextAction: base.nextAction
            )
        case .veryFatigued:
            return BasePack(
                assessment: .single(activeEnduranceVeryFatiguedAssessment(activityType: activityType)),
                recommendation: .single(.en(
                    "Start easier than planned and reassess after warming up.",
                    "Начните легче плана и переоцените после разминки."
                )),
                avoid: .single(.en(
                    "Don't commit to the full plan before you feel the legs.",
                    "Не берите полный план, пока не почувствуете ноги."
                )),
                nextAction: .single(.en(
                    "Easy warm-up first — shorten if legs stay heavy.",
                    "Сначала лёгкая разминка — сократите, если ноги тяжёлые."
                ))
            )
        }
    }

    private static func activeEnduranceFatiguedAssessment(
        activityType: CoachActivityType
    ) -> CoachBilingualText {
        switch activityType {
        case .cycling:
            return .en(
                "Ride is ahead — recovery isn't fully back yet.",
                "Заезд впереди — восстановление ещё не полное."
            )
        case .running:
            return .en(
                "Run is ahead — recovery isn't fully back yet.",
                "Пробежка впереди — восстановление ещё не полное."
            )
        default:
            return .en(
                "Session is ahead — recovery isn't fully back yet.",
                "Тренировка впереди — восстановление ещё не полное."
            )
        }
    }

    private static func activeEnduranceVeryFatiguedAssessment(
        activityType: CoachActivityType
    ) -> CoachBilingualText {
        switch activityType {
        case .cycling:
            return .en(
                "Ride is ahead — legs aren't topped up, so ease in.",
                "Заезд впереди — ноги не восстановились, заходите мягко."
            )
        case .running:
            return .en(
                "Run is ahead — legs aren't topped up, so ease in.",
                "Пробежка впереди — ноги не восстановились, заходите мягко."
            )
        default:
            return .en(
                "Session is ahead — the body isn't topped up, so ease in.",
                "Тренировка впереди — тело не восстановилось, заходите мягко."
            )
        }
    }

    // MARK: - duringEndurance

    private static func applyDuringEndurance(
        base: BasePack,
        bodyState: CoachBodyState
    ) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: base.assessment,
                recommendation: .single(.en(
                    "Hold conversational effort — keep it honest, not heroic.",
                    "Держите разговорный темп — честно, без героизма."
                )),
                avoid: .single(.en(
                    "No hero intervals on tired legs.",
                    "Без героических интервалов на уставших ногах."
                )),
                nextAction: base.nextAction
            )
        case .veryFatigued:
            return BasePack(
                assessment: base.assessment,
                recommendation: .single(.en(
                    "Ease off now — finishing easy beats pushing through.",
                    "Сбавьте сейчас — лёгкий финиш лучше, чем давить."
                )),
                avoid: .single(.en(
                    "Don't chase pace or power — cut it short if needed.",
                    "Не гонитесь за темпом — сократите, если нужно."
                )),
                nextAction: .single(.en(
                    "Check breathing in five minutes — downshift if it's labored.",
                    "Через пять минут проверьте дыхание — сбавьте, если тяжело."
                ))
            )
        }
    }

    // MARK: - Walk

    private static func applyWalkLightDay(base: BasePack, bodyState: CoachBodyState) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: .single(.en(
                    "Easy walk — a soft start after short sleep.",
                    "Лёгкая прогулка — мягкий вход в день после короткого сна."
                )),
                recommendation: .single(.en(
                    "Keep it conversational: the goal is to wake up, not add load.",
                    "Держите темп разговорным: цель — проснуться, а не набрать нагрузку."
                )),
                avoid: .single(.en(
                    "Do not turn the walk into a fast march or an errands sprint.",
                    "Не превращайте прогулку в быстрый марш или список дел."
                )),
                nextAction: .single(.en(
                    "Twenty easy minutes — no pushing and no target.",
                    "Двадцать минут легко — без ускорений и без цели."
                ))
            )
        case .veryFatigued:
            return BasePack(
                assessment: .single(.en(
                    "Easy walk — gentle movement only if the body wants to wake up.",
                    "Лёгкая прогулка — только мягкое движение, если тело просится проснуться."
                )),
                recommendation: .single(.en(
                    "Go slower than usual and shorten it if heaviness stays.",
                    "Идите медленнее обычного и сократите прогулку, если тяжесть не уходит."
                )),
                avoid: .single(.en(
                    "Do not force steps just to close a number.",
                    "Не добирайте шаги через силу."
                )),
                nextAction: .single(.en(
                    "10–15 calm minutes — stopping early is fine.",
                    "10–15 минут спокойно — можно закончить раньше."
                ))
            )
        }
    }

    private static func applyWalkAfterHeavyLoadLive(base: BasePack, bodyState: CoachBodyState) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued, .veryFatigued:
            return BasePack(
                assessment: .single(.en(
                    "Recovery walk — yesterday's or today's load still lingers.",
                    "Восстановительная прогулка — вчерашняя или сегодняшняя нагрузка ещё чувствуется."
                )),
                recommendation: .single(.en(
                    "Let the walk release tension, not add another block.",
                    "Пусть прогулка снимет напряжение, а не добавит новый блок."
                )),
                avoid: .single(.en(
                    "Don't speed up if the legs feel heavy.",
                    "Не ускоряйтесь, если ноги тяжёлые."
                )),
                nextAction: .single(.en(
                    "15–20 easy minutes — slower pace than usual.",
                    "15–20 минут легко, темп ниже обычного."
                ))
            )
        }
    }

    private static func applyWalkEveningWindDown(base: BasePack, bodyState: CoachBodyState) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued, .veryFatigued:
            return BasePack(
                assessment: .single(.en(
                    "Evening walk — a gentle way to let the day settle.",
                    "Вечерняя прогулка — способ мягко опустить день."
                )),
                recommendation: .single(.en(
                    "Keep it calm: sleep matters more than steps right now.",
                    "Держите её спокойной: сон сейчас важнее шагов."
                )),
                avoid: .single(.en(
                    "Don't turn the evening into extra training.",
                    "Не превращайте вечер в дополнительную тренировку."
                )),
                nextAction: .single(.en(
                    "One short loop, then home — no surges.",
                    "Короткий круг и домой — без ускорений."
                ))
            )
        }
    }

    private static func applyWalkRecoveryActionLive(base: BasePack, bodyState: CoachBodyState) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued, .veryFatigued:
            return BasePack(
                assessment: .single(.en(
                    "Recovery walk — the body needs a soft reset.",
                    "Прогулка для восстановления — телу нужен мягкий сброс нагрузки."
                )),
                recommendation: .single(.en(
                    "Walk so you feel lighter after, not heavier.",
                    "Идите так, чтобы после стало легче, а не тяжелее."
                )),
                avoid: .single(.en(
                    "Don't test fitness on a recovery walk.",
                    "Не проверяйте форму на восстановительной прогулке."
                )),
                nextAction: .single(.en(
                    "10–20 calm minutes, then water and rest.",
                    "10–20 минут спокойно, затем вода и отдых."
                ))
            )
        }
    }

    // MARK: - postEnduranceImmediate

    private static func applyPostEnduranceImmediate(
        base: BasePack,
        bodyState: CoachBodyState
    ) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: base.assessment,
                recommendation: .single(.en(
                    "Extend cooldown — fifteen easy minutes before you stop.",
                    "Подлиннее заминка — пятнадцать лёгких минут, прежде чем остановиться."
                )),
                avoid: base.avoid,
                nextAction: base.nextAction
            )
        case .veryFatigued:
            return BasePack(
                assessment: base.assessment,
                recommendation: .single(.en(
                    "Keep moving easy — let heart rate settle before you sit.",
                    "Двигаетесь легко — пусть пульс успокоится, прежде чем сесть."
                )),
                avoid: .single(.en(
                    "Don't skip cooldown to rush the next thing.",
                    "Не пропускайте заминку ради следующего дела."
                )),
                nextAction: .single(.en(
                    "Walk ten minutes, then rest.",
                    "Десять минут пройдитесь — потом отдых."
                ))
            )
        }
    }

    // MARK: - Strength

    private static func applyActiveStrength(
        base: BasePack,
        activityType: CoachActivityType,
        bodyState: CoachBodyState
    ) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: .single(activeStrengthFatiguedAssessment(activityType: activityType)),
                recommendation: .single(.en(
                    "Open lighter than planned — first sets are a readiness check.",
                    "Начните легче плана — первые подходы как проверка готовности."
                )),
                avoid: .single(.en(
                    "Don't chase max loads before the body feels awake.",
                    "Не гонитесь за максимумом, пока тело не проснулось."
                )),
                nextAction: base.nextAction
            )
        case .veryFatigued:
            return BasePack(
                assessment: .single(activeStrengthVeryFatiguedAssessment(activityType: activityType)),
                recommendation: .single(.en(
                    "Cut volume early — quality beats quantity on tired days.",
                    "Сократите объём заранее — качество важнее количества."
                )),
                avoid: .single(.en(
                    "Don't force the full program if joints feel stiff.",
                    "Не форсируйте полную программу, если суставы зажаты."
                )),
                nextAction: .single(.en(
                    "Mobility first — skip a heavy opener if needed.",
                    "Сначала мобильность — пропустите тяжёлый старт, если нужно."
                ))
            )
        }
    }

    private static func activeStrengthFatiguedAssessment(activityType: CoachActivityType) -> CoachBilingualText {
        switch activityType {
        case .core:
            return .en(
                "Core block is next — recovery isn't fully back yet.",
                "Кор впереди — восстановление ещё не полное."
            )
        case .lowerBody:
            return .en(
                "Leg day is next — legs aren't fully topped up.",
                "День ног впереди — ноги ещё не восстановились."
            )
        default:
            return .en(
                "Strength is next — recovery isn't fully back yet.",
                "Силовая впереди — восстановление ещё не полное."
            )
        }
    }

    private static func activeStrengthVeryFatiguedAssessment(activityType: CoachActivityType) -> CoachBilingualText {
        switch activityType {
        case .lowerBody:
            return .en(
                "Leg day is next — ease in before you load heavy.",
                "День ног впереди — заходите мягко, прежде чем грузить."
            )
        default:
            return .en(
                "Strength is next — the body isn't topped up, so ease in.",
                "Силовая впереди — тело не восстановилось, заходите мягко."
            )
        }
    }

    private static func applyDuringStrength(
        base: BasePack,
        bodyState: CoachBodyState
    ) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: base.assessment,
                recommendation: .single(.en(
                    "Keep reps clean — drop weight before form slips.",
                    "Держите повторы чистыми — сбросьте вес, прежде чем форма поплывёт."
                )),
                avoid: .single(.en(
                    "No grinding reps on tired stabilizers.",
                    "Без гринда на уставших стабилизаторах."
                )),
                nextAction: base.nextAction
            )
        case .veryFatigued:
            return BasePack(
                assessment: base.assessment,
                recommendation: .single(.en(
                    "Cut a set or two now — finishing strong beats finishing wrecked.",
                    "Уберите пару подходов сейчас — сильный финиш лучше разбитого."
                )),
                avoid: .single(.en(
                    "Don't chase PRs on a depleted day.",
                    "Не гонитесь за рекордами на опустошённый день."
                )),
                nextAction: .single(.en(
                    "After this set — decide whether to trim the rest.",
                    "После этого подхода — решите, сокращать ли остальное."
                ))
            )
        }
    }

    // MARK: - Racket

    private static func applyActiveRacket(
        base: BasePack,
        activityType: CoachActivityType,
        bodyState: CoachBodyState
    ) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: .single(activeRacketFatiguedAssessment(activityType: activityType)),
                recommendation: .single(.en(
                    "Longer warm-up — first games at half speed.",
                    "Длиннее разминка — первые геймы на половине скорости."
                )),
                avoid: .single(.en(
                    "Don't open with explosive rallies.",
                    "Не начинайте со взрывных розыгрышей."
                )),
                nextAction: base.nextAction
            )
        case .veryFatigued:
            return BasePack(
                assessment: .single(.en(
                    "Match is close — legs and focus aren't fully topped up.",
                    "Игра скоро — ноги и концентрация ещё не на пике."
                )),
                recommendation: .single(.en(
                    "Play for position, not power — shorten points when you can.",
                    "Играйте на позицию, не на силу — укорачивайте розыгрыши."
                )),
                avoid: .single(.en(
                    "Don't sprint for every ball in the first set.",
                    "Не бегайте за каждым мячом в первом сете."
                )),
                nextAction: .single(.en(
                    "Extra five minutes warm-up before the first point.",
                    "Ещё пять минут разминки перед первым очком."
                ))
            )
        }
    }

    private static func activeRacketFatiguedAssessment(activityType: CoachActivityType) -> CoachBilingualText {
        switch activityType {
        case .squash:
            return .en(
                "Squash is close — recovery isn't fully back yet.",
                "Сквош скоро — восстановление ещё не полное."
            )
        default:
            return .en(
                "Match is close — recovery isn't fully back yet.",
                "Игра скоро — восстановление ещё не полное."
            )
        }
    }

    private static func applyDuringRacket(
        base: BasePack,
        bodyState: CoachBodyState
    ) -> BasePack {
        switch bodyState {
        case .fresh, .normal:
            return base
        case .fatigued:
            return BasePack(
                assessment: base.assessment,
                recommendation: .single(.en(
                    "Pick your battles — not every ball needs a sprint.",
                    "Выбирайте бои — не за каждым мячом нужен рывок."
                )),
                avoid: .single(.en(
                    "No hero dives on tired legs.",
                    "Без героических нырков на уставших ногах."
                )),
                nextAction: base.nextAction
            )
        case .veryFatigued:
            return BasePack(
                assessment: base.assessment,
                recommendation: .single(.en(
                    "Shorten points — let the opponent make mistakes.",
                    "Укорачивайте розыгрыши — пусть ошибается соперник."
                )),
                avoid: .single(.en(
                    "Don't chase pace you can't sustain.",
                    "Не гонитесь за темпом, который не удержите."
                )),
                nextAction: .single(.en(
                    "Use the next changeover to reset breathing.",
                    "На следующей паузе — восстановите дыхание."
                ))
            )
        }
    }
}
