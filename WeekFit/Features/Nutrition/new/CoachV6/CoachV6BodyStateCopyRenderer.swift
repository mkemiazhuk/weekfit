import Foundation

/// Applies athlete body state to copy for Phase 2A target scenarios. `normal` preserves base text.
enum CoachV6BodyStateCopyRenderer {

    struct BasePack: Equatable {
        let assessment: CoachV6CopySection
        let recommendation: CoachV6CopySection
        let avoid: CoachV6CopySection
        let nextAction: CoachV6CopySection
    }

    private static let phase2AScenarios: Set<CoachV6ScenarioKey> = [
        .morningReadiness,
        .stableDay,
        .activeEndurance,
        .duringEndurance,
        .postEnduranceImmediate,
        .walkLightDay,
        .walkAfterHeavyLoad,
        .walkEveningWindDown,
        .walkRecoveryAction
    ]

    static func applies(to scenario: CoachV6ScenarioKey) -> Bool {
        phase2AScenarios.contains(scenario)
    }

    static func apply(
        base: BasePack,
        scenario: CoachV6ScenarioKey,
        activityType: CoachV6ActivityType,
        bodyState: CoachV6BodyState
    ) -> BasePack {
        guard applies(to: scenario), bodyState != .normal, bodyState != .fresh else {
            return base
        }

        switch scenario {
        case .morningReadiness:
            return applyMorningReadiness(base: base, bodyState: bodyState)
        case .stableDay:
            return applyStableDay(base: base, bodyState: bodyState)
        case .activeEndurance:
            return applyActiveEndurance(base: base, activityType: activityType, bodyState: bodyState)
        case .duringEndurance:
            return applyDuringEndurance(base: base, bodyState: bodyState)
        case .postEnduranceImmediate:
            return applyPostEnduranceImmediate(base: base, bodyState: bodyState)
        case .walkLightDay:
            return applyWalkLightDay(base: base, bodyState: bodyState)
        case .walkAfterHeavyLoad:
            return applyWalkAfterHeavyLoad(base: base, bodyState: bodyState)
        case .walkEveningWindDown:
            return applyWalkEveningWindDown(base: base, bodyState: bodyState)
        case .walkRecoveryAction:
            return applyWalkRecoveryAction(base: base, bodyState: bodyState)
        default:
            return base
        }
    }

    // MARK: - morningReadiness

    private static func applyMorningReadiness(
        base: BasePack,
        bodyState: CoachV6BodyState
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

    private static func applyStableDay(base: BasePack, bodyState: CoachV6BodyState) -> BasePack {
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
        activityType: CoachV6ActivityType,
        bodyState: CoachV6BodyState
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
        activityType: CoachV6ActivityType
    ) -> CoachV6BilingualText {
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
        activityType: CoachV6ActivityType
    ) -> CoachV6BilingualText {
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
        bodyState: CoachV6BodyState
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

    private static func applyWalkLightDay(base: BasePack, bodyState: CoachV6BodyState) -> BasePack {
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

    private static func applyWalkAfterHeavyLoad(base: BasePack, bodyState: CoachV6BodyState) -> BasePack {
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

    private static func applyWalkEveningWindDown(base: BasePack, bodyState: CoachV6BodyState) -> BasePack {
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

    private static func applyWalkRecoveryAction(base: BasePack, bodyState: CoachV6BodyState) -> BasePack {
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
        bodyState: CoachV6BodyState
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
}
