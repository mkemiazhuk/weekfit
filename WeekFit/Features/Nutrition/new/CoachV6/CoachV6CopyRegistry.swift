import Foundation

enum CoachV6CopyRegistry {

    static func resolve(_ input: CoachV6CopyBuildInput) -> CoachV6CopyPack? {
        guard let base = basePack(for: input.scenario, input: input) else {
            return nil
        }

        let shaped = applyBodyState(base: base, input: input)

        return CoachV6CopyPack(
            scenario: input.scenario,
            assessment: shaped.assessment,
            recommendation: shaped.recommendation,
            avoid: shaped.avoid,
            nextAction: shaped.nextAction,
            supportingSignals: supportingSignals(for: input),
            warningLayer: warningLayer(for: input)
        )
    }

    private static func applyBodyState(
        base: BasePack,
        input: CoachV6CopyBuildInput
    ) -> CoachV6BodyStateCopyRenderer.BasePack {
        CoachV6BodyStateCopyRenderer.apply(
            base: CoachV6BodyStateCopyRenderer.BasePack(
                assessment: base.assessment,
                recommendation: base.recommendation,
                avoid: base.avoid,
                nextAction: base.nextAction
            ),
            scenario: input.scenario,
            activityType: input.activityType,
            bodyState: input.athleteState.bodyState
        )
    }

    static func resolve(from result: CoachV6Engine.Result) -> CoachV6CopyPack? {
        resolve(CoachV6CopyBuildInput.from(result: result))
    }

    // MARK: - Scenario packs (all 30 keys)

    private struct BasePack {
        let assessment: CoachV6CopySection
        let recommendation: CoachV6CopySection
        let avoid: CoachV6CopySection
        let nextAction: CoachV6CopySection
    }

    private static func basePack(
        for scenario: CoachV6ScenarioKey,
        input: CoachV6CopyBuildInput
    ) -> BasePack? {
        if input.modifiers.stackedDayActiveRisk {
            return stackedDayActiveSessionPack(input: input)
        }

        switch scenario {
        case .morningReadiness:
            return morningReadinessPack()
        case .stableDay:
            return stableDayPack()
        case .duringEndurance:
            return duringEndurancePack(input: input)
        case .walkAfterHeavyLoad:
            return walkAfterHeavyLoadPack()
        case .tomorrowProtection:
            return tomorrowProtectionPack(input: input)
        case .protectTomorrowFresh:
            return protectTomorrowFreshPack()
        case .recoveryAfterHeavyYesterday:
            return recoveryAfterHeavyYesterdayPack()
        case .lowRecoveryPrep:
            return lowRecoveryPrepPack(input: input)
        default:
            guard let draft = CoachV6CopyRegistryScenarios.draft(for: scenario, input: input) else {
                return nil
            }
            return basePack(from: draft)
        }
    }

    private static func basePack(from draft: CoachV6CopyRegistryScenarios.Draft) -> BasePack {
        BasePack(
            assessment: .single(draft.assessment),
            recommendation: .single(draft.recommendation),
            avoid: .single(draft.avoid),
            nextAction: .single(draft.nextAction)
        )
    }

    private static func morningReadinessPack() -> BasePack {
        BasePack(
            assessment: .single(.en(
                "It's morning — the day hasn't picked a direction yet.",
                "Утро — день ещё не решил, куда повернёт."
            )),
            recommendation: .single(.en(
                "Lead with how you actually feel, not what's loudest on the calendar.",
                "Слушайте тело, а не самое громкое в календаре."
            )),
            avoid: .single(.en(
                "Don't turn the first hour into a race.",
                "Не устраивайте гонку с самого утра."
            )),
            nextAction: .single(.en(
                "Name one thing that matters today.",
                "Выберите одну главную задачу на сегодня."
            ))
        )
    }

    private static func stableDayPack() -> BasePack {
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

    private static func duringEndurancePack(input: CoachV6CopyBuildInput) -> BasePack {
        let heavyDay = input.dayLoad == .moderate ||
            input.dayLoad == .heavy ||
            input.dayLoad == .extreme

        let assessment: CoachV6BilingualText
        switch (input.activityType, heavyDay) {
        case (.cycling, true):
            assessment = .en(
                "Still pedaling after a full day — you're in the thick of it.",
                "Плотный день — а вы всё ещё крутите педали."
            )
        case (.cycling, false):
            assessment = .en(
                "You're on the bike — the ride is live.",
                "Вы на велосипеде — заезд в разгаре."
            )
        case (.running, true):
            assessment = .en(
                "Still running on a stacked day — legs are doing real work.",
                "Насыщенный день — ноги всё ещё в работе."
            )
        case (.running, false):
            assessment = .en(
                "You're in the run — miles are ticking.",
                "Вы в пробежке — километры набираются."
            )
        default:
            assessment = .en(
                heavyDay
                    ? "Session is live on an already full day."
                    : "Session is live — you're in it now.",
                heavyDay
                    ? "Тренировка идёт, а день и без того полный."
                    : "Тренировка идёт — вы в процессе."
            )
        }

        let recommendation: CoachV6BilingualText
        switch input.durationBand {
        case .extended, .long:
            recommendation = .en(
                "Patience in the middle miles — consistency beats spikes.",
                "В середине главное — терпение, не рывки."
            )
        default:
            recommendation = .en(
                "Hold effort flat — speed up only when breathing stays easy.",
                "Держите темп ровным — ускоряйтесь только если дыхание легко."
            )
        }

        return BasePack(
            assessment: .single(assessment),
            recommendation: .single(recommendation),
            avoid: .single(.en(
                "No early surges you'll regret later.",
                "Без ранних рывков — потом пожалеете."
            )),
            nextAction: .single(.en(
                "Check legs and breathing in ten minutes.",
                "Через десять минут проверьте ноги и дыхание."
            ))
        )
    }

    private static func walkAfterHeavyLoadPack() -> BasePack {
        BasePack(
            assessment: .single(.en(
                "Big day behind you — this walk is about settling down.",
                "Плотный день позади — прогулка, чтобы успокоиться."
            )),
            recommendation: .single(.en(
                "Let heart rate and pace drift down; nothing to prove.",
                "Пусть пульс и темп сами снижаются — доказывать нечего."
            )),
            avoid: .single(.en(
                "Don't pick up pace or treat it like cardio.",
                "Не ускоряйтесь — это не кардио."
            )),
            nextAction: .single(.en(
                "Keep it slow enough to speak in full sentences.",
                "Так медленно, чтобы спокойно разговаривать."
            ))
        )
    }

    private static func tomorrowProtectionPack(input: CoachV6CopyBuildInput) -> BasePack {
        let windDown = CoachV6CopyNutritionTiming.isWindDown(input.timeOfDay)
        let assessment = tomorrowProtectionAssessment(input: input)
        let recommendation = tomorrowProtectionRecommendation(input: input, windDown: windDown)
        let nextAction = tomorrowProtectionNextAction(input: input, windDown: windDown)

        return BasePack(
            assessment: .single(assessment),
            recommendation: .single(recommendation),
            avoid: .single(.en(
                "No extra hard blocks tonight.",
                "Не добавляйте ещё нагрузку."
            )),
            nextAction: .single(nextAction)
        )
    }

    private static func tomorrowProtectionAssessment(input: CoachV6CopyBuildInput) -> CoachV6BilingualText {
        .en(
            "Heavy load is banked — hold the line tonight.",
            "На сегодня нагрузки уже достаточно."
        )
    }

    private static func tomorrowProtectionRecommendation(
        input: CoachV6CopyBuildInput,
        windDown: Bool
    ) -> CoachV6BilingualText {
        if windDown {
            return .en(
                "Wind down now — sleep is the work.",
                "Заканчивайте день спокойно — сейчас важнее сон."
            )
        }

        return .en(
            "Keep the rest of today easy, then protect sleep.",
            "Остаток дня спокойный — сон потом важнее."
        )
    }

    private static func tomorrowProtectionNextAction(
        input: CoachV6CopyBuildInput,
        windDown: Bool
    ) -> CoachV6BilingualText {
        if windDown {
            return .en(
                "Sip some water if thirsty, then rest.",
                "Если хочется пить — немного воды и отдых."
            )
        }

        if input.modifiers.fuelBehind || input.fuelState.isBehind {
            return CoachV6CopyNutritionTiming.fuelCatchUpNextAction(for: input)
        }

        if input.modifiers.hydrationBehind || input.hydrationState.isBehind {
            return CoachV6CopyNutritionTiming.hydrationCatchUpNextAction(for: input)
        }

        return .en(
            "Take twenty quiet minutes — walk, stretch, or lie down.",
            "Двадцать минут тишины — прогулка или растяжка."
        )
    }

    private static func protectTomorrowFreshPack() -> BasePack {
        BasePack(
            assessment: .single(.en(
                "Recovery looks solid — tomorrow already has real work on the calendar.",
                "Восстановление в порядке — завтра в календаре серьёзная работа."
            )),
            recommendation: .single(.en(
                "Spend today calmly so tomorrow's session still has room to breathe.",
                "Проведите сегодня спокойно — завтра должно хватить сил."
            )),
            avoid: .single(.en(
                "Don't burn the good recovery on optional intensity today.",
                "Не тратьте хорошее восстановление на лишнюю интенсивность."
            )),
            nextAction: .single(.en(
                "Keep meals steady and leave hard blocks for tomorrow.",
                "Ешьте ровно и оставьте тяжёлые блоки на завтра."
            ))
        )
    }

    private static func recoveryAfterHeavyYesterdayPack() -> BasePack {
        BasePack(
            assessment: .single(.en(
                "Yesterday's load is still in the legs — today needs a softer line.",
                "Вчерашняя нагрузка ещё чувствуется — сегодня мягче."
            )),
            recommendation: .single(.en(
                "Treat today as recovery first, training second.",
                "Сначала восстановление, потом тренировка."
            )),
            avoid: .single(.en(
                "Don't chase yesterday's numbers or stack hard blocks early.",
                "Не гонитесь за вчерашними цифрами и не добавляйте тяжести с утра."
            )),
            nextAction: .single(.en(
                "Walk, stretch, or nap before anything demanding.",
                "Прогулка, растяжка или короткий отдых — перед нагрузкой."
            ))
        )
    }

    private static func lowRecoveryPrepPack(input: CoachV6CopyBuildInput) -> BasePack {
        let activityHint: CoachV6BilingualText
        switch input.activityType {
        case .cycling, .running:
            activityHint = .en(
                "Hard endurance is coming — recovery is not fully there yet.",
                "Впереди серьёзная выносливость — восстановление ещё не полное."
            )
        case .tennis, .squash:
            activityHint = .en(
                "Match demand is real — you are not fully topped up.",
                "Игра потребует сил — восстановление пока не полное."
            )
        default:
            activityHint = .en(
                "Training is on the plan — recovery is lagging.",
                "Тренировка впереди — восстановление отстаёт."
            )
        }

        return BasePack(
            assessment: .single(activityHint),
            recommendation: .single(.en(
                "Start lighter, shorten if needed, and leave room to feel better at the end.",
                "Начните легче, при необходимости сократите — важнее закончить без провала."
            )),
            avoid: .single(.en(
                "Don't force the full plan or race the clock from the start.",
                "Не форсируйте полный план и не гонитесь с первых минут."
            )),
            nextAction: .single(.en(
                "Check legs and sleep once more before you begin.",
                "Перед стартом ещё раз оцените ноги и сон."
            ))
        )
    }

    // MARK: - Supporting signals (why / extra factors — max 3)

    private static func supportingSignals(for input: CoachV6CopyBuildInput) -> CoachV6CopySection {
        var lines: [CoachV6BilingualText] = []

        if shouldSurfaceNutritionSignals(for: input) {
            if input.modifiers.hydrationBehind, input.safetyAlert != .hydrationCritical {
                lines.append(CoachV6CopyNutritionTiming.hydrationBehindSignal(for: input))
            }

            if input.modifiers.fuelBehind, input.safetyAlert != .fuelCritical {
                lines.append(CoachV6CopyNutritionTiming.fuelBehindSignal(for: input))
            }
        }

        if shouldMentionLowRecoveryPrepSignal(input), lines.count < 3 {
            lines.append(lowRecoveryPrepWhySignal(for: input))
        }

        if shouldMentionDayLoadInSignals(input) {
            lines.append(.en(
                "High cumulative load today.",
                "За день уже много нагрузки."
            ))
        }

        if shouldMentionLongSessionSignal(input), lines.count < 3 {
            lines.append(.en(
                "Long session — plan fuel and fluids ahead of time.",
                "Длинная тренировка — еду и воду лучше продумать заранее."
            ))
        }

        if shouldMentionStackedTomorrowSignal(input), lines.count < 3 {
            lines.append(.en(
                "Hard session is on the plan.",
                "Впереди серьёзная тренировка."
            ))
        }

        if shouldMentionHeavyYesterdayRecoveredSignal(input), lines.count < 3 {
            lines.append(.en(
                "Yesterday was heavy — recovery looks normal today.",
                "Вчера была нагрузка, но восстановление выглядит нормально."
            ))
        }

        if shouldMentionLowRecoveryLiveSignal(input), lines.count < 3 {
            lines.append(.en(
                "Recovery is low — keep effort honest, not heroic.",
                "Восстановление низкое — держите усилие честным, не героическим."
            ))
        }

        return CoachV6CopySection(lines: Array(lines.prefix(3)))
    }

    private static func shouldMentionHeavyYesterdayRecoveredSignal(_ input: CoachV6CopyBuildInput) -> Bool {
        guard input.dayReadiness.hadHeavyYesterday else { return false }
        guard input.dayReadiness.isGoodRecovery else { return false }
        switch input.scenario {
        case .morningReadiness, .stableDay, .protectTomorrowFresh:
            return true
        default:
            return false
        }
    }

    private static func shouldMentionLowRecoveryLiveSignal(_ input: CoachV6CopyBuildInput) -> Bool {
        guard input.dayReadiness.isLowRecovery || input.dayReadiness.sleepIsLow else { return false }
        if input.scenario == .duringEndurance,
           input.athleteState.bodyState == .fatigued || input.athleteState.bodyState == .veryFatigued {
            return false
        }
        switch input.scenario {
        case .duringEndurance, .duringStrength, .duringRacket, .duringRecovery, .saunaActive:
            return true
        default:
            return false
        }
    }

    /// Idle morning / protective day stories — nutrition belongs later.
    private static func shouldSurfaceNutritionSignals(for input: CoachV6CopyBuildInput) -> Bool {
        switch input.scenario {
        case .morningReadiness, .protectTomorrowFresh, .lowRecoveryPrep:
            return false
        case .recoveryAfterHeavyYesterday:
            return input.timeOfDay != .morning
        default:
            return true
        }
    }

    private static func shouldMentionLowRecoveryPrepSignal(_ input: CoachV6CopyBuildInput) -> Bool {
        guard input.scenario == .lowRecoveryPrep else { return false }
        return input.dayReadiness.sleepIsLow || input.dayReadiness.isLowRecovery
    }

    private static func lowRecoveryPrepWhySignal(for input: CoachV6CopyBuildInput) -> CoachV6BilingualText {
        if input.dayReadiness.sleepIsLow {
            return .en(
                "Sleep was short — start easier than usual.",
                "Сон был коротким — начните легче обычного."
            )
        }
        return .en(
            "Recovery is lagging — protect the session.",
            "Восстановление отстаёт — берегите тренировку."
        )
    }

    private static func shouldMentionStackedTomorrowSignal(_ input: CoachV6CopyBuildInput) -> Bool {
        guard input.modifiers.stackedDayActiveRisk else { return false }
        return input.tomorrowDemand == .hard || input.tomorrowDemand == .moderate
    }

    private static func shouldMentionDayLoadInSignals(_ input: CoachV6CopyBuildInput) -> Bool {
        guard !input.modifiers.stackedDayActiveRisk else { return false }
        guard input.dayLoad == .heavy || input.dayLoad == .extreme else { return false }
        switch input.scenario {
        case .morningReadiness, .stableDay, .tomorrowProtection,
             .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled,
             .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            return true
        default:
            return false
        }
    }

    private static func shouldMentionLongSessionSignal(_ input: CoachV6CopyBuildInput) -> Bool {
        guard input.scenario == .duringEndurance else { return false }
        guard input.durationBand == .long || input.durationBand == .extended else { return false }
        return !input.modifiers.fuelBehind && !input.modifiers.hydrationBehind
    }

    // MARK: - Warning layer (safety-critical only)

    private static func warningLayer(for input: CoachV6CopyBuildInput) -> CoachV6WarningLayer? {
        guard let alert = input.safetyAlert else { return nil }

        let message: CoachV6BilingualText
        switch alert {
        case .hydrationCritical:
            message = CoachV6CopyNutritionTiming.hydrationCriticalWarning(
                isActiveSession: isActiveHydrationSession(input.scenario),
                timeOfDay: input.timeOfDay
            )
        case .fuelCritical:
            message = CoachV6CopyNutritionTiming.fuelCriticalWarning(
                isActiveSession: input.scenario == .duringEndurance
            )
        }

        return CoachV6WarningLayer(alert: alert, message: message)
    }

    // MARK: - Stacked day active session (heavy day + live training + tomorrow demand)

    private static func stackedDayActiveSessionPack(input: CoachV6CopyBuildInput) -> BasePack {
        let windDown = CoachV6CopyNutritionTiming.isWindDown(input.timeOfDay)
        let preSession = isPreSession(input.scenario)

        return BasePack(
            assessment: .single(stackedAssessment(input: input)),
            recommendation: .single(stackedRecommendation(input: input, windDown: windDown)),
            avoid: .single(.en(
                "No extra sets, pace, or duration.",
                "Не затягивайте тренировку и не добавляйте новые подходы."
            )),
            nextAction: .single(stackedNextAction(input: input, windDown: windDown, preSession: preSession))
        )
    }

    private static func stackedAssessment(input: CoachV6CopyBuildInput) -> CoachV6BilingualText {
        switch input.activityType {
        case .cycling:
            return .en(
                "Stacked day — you're adding more riding on top.",
                "День и так полный — вы добавляете ещё заезд."
            )
        case .running:
            return .en(
                "Stacked day — you're adding more running on top.",
                "День и так полный — вы добавляете ещё бег."
            )
        default:
            return .en(
                "Load is already maxed — this session stacks on top.",
                "Организм уже получил достаточно нагрузки на сегодня."
            )
        }
    }

    private static func stackedRecommendation(
        input: CoachV6CopyBuildInput,
        windDown: Bool
    ) -> CoachV6BilingualText {
        if windDown {
            return .en(
                "Best move: stop — sleep and fresh legs matter more now.",
                "Сейчас разумнее остановиться."
            )
        }
        if input.tomorrowDemand == .hard {
            return .en(
                "Consider stopping — the planned session needs you rested.",
                "Подумайте, стоит ли продолжать — дальше нужны свежие силы."
            )
        }
        return .en(
            "If you continue, keep it easy and cut it short.",
            "Если продолжаете — легко и коротко."
        )
    }

    private static func stackedNextAction(
        input: CoachV6CopyBuildInput,
        windDown: Bool,
        preSession: Bool
    ) -> CoachV6BilingualText {
        if preSession {
            return .en(
                "Skip it or cap at 20 easy minutes.",
                "Лучше пропустить или уложиться в 20 лёгких минут."
            )
        }

        if windDown {
            return .en(
                "End within 15 minutes or stop now.",
                "Если продолжаете — заканчивайте в ближайшие 15 минут."
            )
        }

        if input.modifiers.hydrationBehind || input.hydrationState.isBehind {
            return CoachV6CopyNutritionTiming.hydrationCatchUpNextAction(for: input)
        }

        return .en(
            "Keep effort easy and finish early.",
            "Держите темп лёгким и закончите раньше."
        )
    }

    private static func isPreSession(_ scenario: CoachV6ScenarioKey) -> Bool {
        switch scenario {
        case .activeEndurance, .activeStrength, .activeRacket, .activeRecovery:
            return true
        default:
            return false
        }
    }

    private static func isActiveHydrationSession(_ scenario: CoachV6ScenarioKey) -> Bool {
        switch scenario {
        case .duringEndurance, .duringRacket, .saunaActive:
            return true
        default:
            return false
        }
    }
}

private extension CoachV6CopyBuildInput {
    var durationBand: CoachV6DurationBand { modifiers.durationBand }
}
