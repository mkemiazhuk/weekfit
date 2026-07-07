import Foundation

enum CoachCopyRegistry {

    static func resolve(_ input: CoachCopyBuildInput) -> CoachCopyPack? {
        guard let base = basePack(for: input.scenario, input: input) else {
            return nil
        }

        let shaped = applyBodyState(base: base, input: input)
        let profile = CoachStableDayProfile.resolve(for: input)
        let final = CoachDayClosingCopyPolicy.apply(
            to: shaped,
            input: input,
            profile: profile
        )

        return CoachCopyPack(
            scenario: input.scenario,
            assessment: final.assessment,
            recommendation: final.recommendation,
            avoid: final.avoid,
            nextAction: final.nextAction,
            supportingSignals: supportingSignals(for: input),
            warningLayer: warningLayer(for: input)
        )
    }

    private static func applyBodyState(
        base: BasePack,
        input: CoachCopyBuildInput
    ) -> CoachBodyStateCopyRenderer.BasePack {
        let profile = CoachStableDayProfile.resolve(for: input)
        return CoachBodyStateCopyRenderer.apply(
            base: CoachBodyStateCopyRenderer.BasePack(
                assessment: base.assessment,
                recommendation: base.recommendation,
                avoid: base.avoid,
                nextAction: base.nextAction
            ),
            scenario: input.scenario,
            activityType: profile == .workBanked
                ? input.modifiers.lastCompletedActivityType
                : input.activityType,
            bodyState: input.athleteState.bodyState,
            stableDayProfile: profile,
            sessionPhase: input.sessionPhase
        )
    }

    static func resolve(from result: CoachEngine.Result) -> CoachCopyPack? {
        resolve(CoachCopyBuildInput.from(result: result))
    }

    // MARK: - Scenario packs (all 30 keys)

    private struct BasePack {
        let assessment: CoachCopySection
        let recommendation: CoachCopySection
        let avoid: CoachCopySection
        let nextAction: CoachCopySection
    }

    private static func basePack(
        for scenario: CoachScenarioKey,
        input: CoachCopyBuildInput
    ) -> BasePack? {
        switch scenario {
        case .morningReadiness:
            return morningReadinessPack(input: input)
        case .stableDay:
            return stableDayPack(input: input)
        case .duringEndurance:
            return duringEndurancePack(input: input)
        case .walkAfterHeavyLoad:
            return walkAfterHeavyLoadPack(input: input)
        case .tomorrowProtection:
            return tomorrowProtectionPack(input: input)
        case .protectTomorrowFresh:
            return protectTomorrowFreshPack(input: input)
        case .recoveryAfterHeavyYesterday:
            return recoveryAfterHeavyYesterdayPack(input: input)
        case .lowRecoveryPrep:
            return lowRecoveryPrepPack(input: input)
        default:
            guard let draft = CoachCopyRegistryScenarios.draft(for: scenario, input: input) else {
                return nil
            }
            return basePack(from: draft)
        }
    }

    private static func basePack(from draft: CoachCopyRegistryScenarios.Draft) -> BasePack {
        BasePack(
            assessment: .single(draft.assessment),
            recommendation: .single(draft.recommendation),
            avoid: .single(draft.avoid),
            nextAction: .single(draft.nextAction)
        )
    }

    private static func morningReadinessPack(input: CoachCopyBuildInput) -> BasePack {
        let facts = input.morningBriefFacts ?? CoachMorningBriefFactsBuilder.synthetic(
            dayReadiness: input.dayReadiness,
            tomorrowWorkout: input.tomorrowWorkout
        )
        let pack = CoachMorningBriefCopyPolicy.morningReadinessPack(for: facts)
        return BasePack(
            assessment: .single(pack.assessment),
            recommendation: .single(pack.recommendation),
            avoid: .single(pack.avoid),
            nextAction: .single(pack.nextAction)
        )
    }

    private static func stableDayPack(input: CoachCopyBuildInput) -> BasePack {
        let profilePack = CoachStableDayCopy.basePack(for: input)
        return BasePack(
            assessment: profilePack.assessment,
            recommendation: profilePack.recommendation,
            avoid: profilePack.avoid,
            nextAction: profilePack.nextAction
        )
    }

    private static func duringEndurancePack(input: CoachCopyBuildInput) -> BasePack {
        let heavyDay = input.dayLoad == .moderate ||
            input.dayLoad == .heavy ||
            input.dayLoad == .extreme

        let assessment: CoachBilingualText
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

        let recommendation: CoachBilingualText
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

    private static func walkAfterHeavyLoadPack(input: CoachCopyBuildInput) -> BasePack {
        let draft = CoachWalkAfterHeavyLoadCopy.draft(for: input)
        return BasePack(
            assessment: .single(draft.assessment),
            recommendation: .single(draft.recommendation),
            avoid: .single(draft.avoid),
            nextAction: .single(draft.nextAction)
        )
    }

    private static func tomorrowProtectionPack(input: CoachCopyBuildInput) -> BasePack {
        let windDown = CoachCopyNutritionTiming.isWindDown(input.timeOfDay)
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

    private static func tomorrowProtectionAssessment(input: CoachCopyBuildInput) -> CoachBilingualText {
        if CoachCopyClosureTiming.allowsDayClosurePhrasing(
            timeOfDay: input.timeOfDay,
            conversationPhase: input.conversationPhase
        ) {
            return .en(
                "Heavy load is banked — hold the line tonight.",
                "На сегодня нагрузки уже достаточно."
            )
        }

        if input.sessionPhase == .tomorrowProtection,
           input.timeOfDay == .evening || input.timeOfDay == .lateEvening {
            return .en(
                "Heavy load is banked — hold the line tonight.",
                "Серьёзная работа уже сделана — берегите силы на завтра."
            )
        }

        return .en(
            "Heavy load is banked — hold reserve for tomorrow.",
            "Серьёзная работа уже сделана — берегите силы на завтра."
        )
    }

    private static func tomorrowProtectionRecommendation(
        input: CoachCopyBuildInput,
        windDown: Bool
    ) -> CoachBilingualText {
        if windDown {
            return .en(
                "Wind down now — sleep is the work.",
                "Заканчивайте день спокойно — сейчас важнее сон."
            )
        }

        if CoachCopyClosureTiming.allowsRestOfDayPhrasing(input.timeOfDay) {
            return .en(
                "Keep the rest of today easy, then protect sleep.",
                "Остаток дня спокойный — сон потом важнее."
            )
        }

        return .en(
            "Keep today easy, then protect sleep tonight.",
            "Держите сегодня легко — к ночи важнее сон."
        )
    }

    private static func tomorrowProtectionNextAction(
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

    private static func protectTomorrowFreshPack(input: CoachCopyBuildInput) -> BasePack {
        let assessment: CoachBilingualText
        if input.timeOfDay == .morning, let facts = input.morningBriefFacts {
            assessment = CoachMorningBriefCopyPolicy.protectTomorrowFreshAssessment(
                facts: facts,
                tomorrowWorkout: input.tomorrowWorkout
            )
        } else if let workout = input.tomorrowWorkout {
            let copy = CoachWorkoutTitleLocalization.recoverySolidTomorrowScheduled(rawTitle: workout.title)
            if !copy.english.isEmpty {
                assessment = .en(copy.english, copy.russian)
            } else {
                assessment = protectTomorrowFreshDefaultAssessment
            }
        } else {
            assessment = protectTomorrowFreshDefaultAssessment
        }

        let nextAction: CoachBilingualText
        if let workout = input.tomorrowWorkout,
           !workout.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nextAction = .en(
                "Keep meals steady and leave hard blocks for tomorrow's session.",
                "Ешьте ровно и оставьте тяжёлые блоки на завтрашнюю сессию."
            )
        } else {
            nextAction = .en(
                "Keep meals steady and leave hard blocks for tomorrow.",
                "Ешьте ровно и оставьте тяжёлые блоки на завтра."
            )
        }

        return BasePack(
            assessment: .single(assessment),
            recommendation: .single(.en(
                "Spend today calmly so tomorrow's session still has room to breathe.",
                "Проведите сегодня спокойно — завтра должно хватить сил."
            )),
            avoid: .single(.en(
                "Don't burn the good recovery on optional intensity today.",
                "Не тратьте хорошее восстановление на лишнюю интенсивность."
            )),
            nextAction: .single(nextAction)
        )
    }

    private static let protectTomorrowFreshDefaultAssessment = CoachBilingualText.en(
        "Recovery looks solid — tomorrow already has real work on the calendar.",
        "Восстановление в порядке — завтра в календаре серьёзная работа."
    )

    private static func recoveryAfterHeavyYesterdayPack(input: CoachCopyBuildInput) -> BasePack {
        let facts = input.morningBriefFacts ?? CoachMorningBriefFactsBuilder.synthetic(
            dayReadiness: input.dayReadiness,
            tomorrowWorkout: input.tomorrowWorkout
        )
        let assessment = input.timeOfDay == .morning
            ? CoachMorningBriefCopyPolicy.recoveryAfterHeavyYesterdayAssessment(for: facts)
            : CoachBilingualText.en(
                "Yesterday's load is still in the legs — today needs a softer line.",
                "Вчерашняя нагрузка ещё чувствуется — сегодня мягче."
            )
        let nextAction = input.timeOfDay == .morning
            ? CoachMorningBriefCopyPolicy.recoveryAfterHeavyYesterdayNextAction(for: facts)
            : CoachBilingualText.en(
                "Walk, stretch, or nap before anything demanding.",
                "Прогулка, растяжка или короткий отдых — перед нагрузкой."
            )

        return BasePack(
            assessment: .single(assessment),
            recommendation: .single(.en(
                "Treat today as recovery first, training second.",
                "Сначала восстановление, потом тренировка."
            )),
            avoid: .single(.en(
                "Don't chase yesterday's numbers or stack hard blocks early.",
                "Не гонитесь за вчерашними цифрами и не добавляйте тяжести с утра."
            )),
            nextAction: .single(nextAction)
        )
    }

    private static func lowRecoveryPrepPack(input: CoachCopyBuildInput) -> BasePack {
        if let imminent = CoachImminentSessionCopyPolicy.basePack(for: input, protective: true) {
            return BasePack(
                assessment: imminent.assessment,
                recommendation: imminent.recommendation,
                avoid: imminent.avoid,
                nextAction: imminent.nextAction
            )
        }

        let activityHint: CoachBilingualText
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

    private static func supportingSignals(for input: CoachCopyBuildInput) -> CoachCopySection {
        var lines: [CoachBilingualText] = []

        if shouldSurfaceNutritionSignals(for: input) {
            let progress = RelativeProgressPolicy.evaluate(input: input)

            if progress.shouldSurfaceHydrationWhyRow,
               input.safetyAlert != .hydrationCritical {
                lines.append(CoachCopyNutritionTiming.hydrationBehindSignal(for: input))
            }

            if progress.shouldSurfaceFuelWhyRow, input.safetyAlert != .fuelCritical {
                lines.append(CoachCopyNutritionTiming.fuelBehindSignal(for: input))
            } else if !input.mealWindowOpen,
                      input.modifiers.fuelBehind || input.fuelState.isBehind,
                      input.safetyAlert != .fuelCritical,
                      lines.count < 3 {
                lines.append(CoachCopyNutritionTiming.firstMealAheadSignal())
            }
        }

        if let morningWhy = CoachMorningOverviewPolicy.upcomingActivityWhySignal(for: input),
           lines.count < 3,
           !overlapsDedicatedRecoveryWhySignal(for: input) {
            lines.append(morningWhy)
        }

        if shouldMentionStackedDayRiskSignal(input), lines.count < 3 {
            lines.append(stackedDayRiskSignal(for: input))
        }

        if shouldMentionLowRecoveryPrepSignal(input), lines.count < 3 {
            lines.append(lowRecoveryPrepWhySignal(for: input))
        }

        if shouldMentionStableDayLowRecoverySignal(input), lines.count < 3 {
            lines.append(stableDayLowRecoveryWhySignal(for: input))
        }

        if shouldMentionStableDayTomorrowWorkoutSignal(input), lines.count < 3 {
            lines.append(tomorrowWorkoutSignal(for: input))
        } else if shouldMentionStableDayTomorrowDemandSignal(input), lines.count < 3 {
            lines.append(stableDayTomorrowDemandSignal(for: input))
        }

        if shouldMentionTomorrowWorkoutSignal(input), lines.count < 3 {
            lines.append(tomorrowWorkoutSignal(for: input))
        }

        if shouldMentionWorkBankedDayLoadSignal(input), lines.count < 3 {
            lines.append(workBankedDayLoadSignal(for: input))
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

        return CoachCopySection(lines: dedupeSupportingSignals(Array(lines.prefix(3))))
    }

    private static func overlapsDedicatedRecoveryWhySignal(for input: CoachCopyBuildInput) -> Bool {
        if input.scenario == .lowRecoveryPrep, shouldMentionLowRecoveryPrepSignal(input) {
            return true
        }
        if shouldMentionStableDayLowRecoverySignal(input) {
            return true
        }
        return false
    }

    private static func dedupeSupportingSignals(_ lines: [CoachBilingualText]) -> [CoachBilingualText] {
        var seenTopics: Set<String> = []
        var result: [CoachBilingualText] = []

        for line in lines {
            let topic = supportingSignalTopicKey(line)
            guard !seenTopics.contains(topic) else { continue }
            seenTopics.insert(topic)
            result.append(line)
        }

        return result
    }

    private static func supportingSignalTopicKey(_ line: CoachBilingualText) -> String {
        let candidates = [line.russian, line.english]
        for text in candidates {
            if let separator = text.range(of: " —") ?? text.range(of: " -") {
                return String(text[..<separator.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
            }
        }
        return line.russian.lowercased()
    }

    private static func shouldMentionHeavyYesterdayRecoveredSignal(_ input: CoachCopyBuildInput) -> Bool {
        guard input.dayReadiness.hadHeavyYesterday else { return false }
        guard input.dayReadiness.isGoodRecovery else { return false }
        switch input.scenario {
        case .morningReadiness, .protectTomorrowFresh:
            return true
        case .stableDay:
            return CoachStableDayProfile.resolve(for: input) == .emptyDay
        default:
            return false
        }
    }

    private static func shouldMentionLowRecoveryLiveSignal(_ input: CoachCopyBuildInput) -> Bool {
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
    private static func shouldSurfaceNutritionSignals(for input: CoachCopyBuildInput) -> Bool {
        if input.conversationPhase == .morningOverview || input.conversationPhase == .dayClosing {
            return false
        }
        switch input.scenario {
        case .morningReadiness, .protectTomorrowFresh, .lowRecoveryPrep:
            return false
        case .recoveryAfterHeavyYesterday:
            return input.timeOfDay != .morning
        default:
            return true
        }
    }

    private static func shouldMentionLowRecoveryPrepSignal(_ input: CoachCopyBuildInput) -> Bool {
        guard input.scenario == .lowRecoveryPrep else { return false }
        return input.dayReadiness.sleepIsLow || input.dayReadiness.isLowRecovery
    }

    private static func lowRecoveryPrepWhySignal(for input: CoachCopyBuildInput) -> CoachBilingualText {
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

    private static func shouldMentionStackedTomorrowSignal(_ input: CoachCopyBuildInput) -> Bool {
        guard input.modifiers.stackedDayActiveRisk else { return false }
        return input.tomorrowDemand == .hard || input.tomorrowDemand == .moderate
    }

    private static func shouldMentionWorkBankedDayLoadSignal(_ input: CoachCopyBuildInput) -> Bool {
        guard CoachStableDayProfile.resolve(for: input) == .workBanked else { return false }
        guard input.dayLoad == .moderate else { return false }
        return true
    }

    private static func shouldMentionStableDayLowRecoverySignal(_ input: CoachCopyBuildInput) -> Bool {
        guard CoachStableDayProfile.resolve(for: input) == .lowRecoveryRest else { return false }
        return input.dayReadiness.isLowRecovery || input.dayReadiness.sleepIsLow
    }

    private static func stableDayLowRecoveryWhySignal(for input: CoachCopyBuildInput) -> CoachBilingualText {
        if input.dayReadiness.sleepIsLow {
            return .en(
                "Sleep was short — keep today easy.",
                "Сон был коротким — сегодня лучше без лишней нагрузки."
            )
        }
        return .en(
            "Recovery is lagging — rest is the plan.",
            "Восстановление отстаёт — отдых сегодня в приоритете."
        )
    }

    private static func shouldMentionStableDayTomorrowDemandSignal(_ input: CoachCopyBuildInput) -> Bool {
        CoachStableDayProfile.resolve(for: input) == .tomorrowReserve
            && !shouldMentionStableDayTomorrowWorkoutSignal(input)
    }

    private static func shouldMentionStableDayTomorrowWorkoutSignal(_ input: CoachCopyBuildInput) -> Bool {
        guard CoachStableDayProfile.resolve(for: input) == .tomorrowReserve else { return false }
        guard let title = input.tomorrowWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return false }
        return true
    }

    private static func shouldMentionTomorrowWorkoutSignal(_ input: CoachCopyBuildInput) -> Bool {
        guard input.scenario == .tomorrowProtection else { return false }
        guard let title = input.tomorrowWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return false }
        return true
    }

    private static func tomorrowWorkoutSignal(for input: CoachCopyBuildInput) -> CoachBilingualText {
        let copy = CoachWorkoutTitleLocalization.tomorrowCalendarSignal(
            rawTitle: input.tomorrowWorkout?.title ?? ""
        )
        return .en(copy.english, copy.russian)
    }

    private static func stableDayTomorrowDemandSignal(for input: CoachCopyBuildInput) -> CoachBilingualText {
        switch input.modifiers.tomorrowDemand {
        case .hard:
            return .en(
                "Hard session is on the plan tomorrow.",
                "Завтра в плане серьёзная тренировка."
            )
        case .moderate:
            return .en(
                "Tomorrow has real work on the calendar.",
                "Завтра в календаре заметная нагрузка."
            )
        default:
            return .en(
                "Tomorrow still needs fresh legs.",
                "Завтра нужны свежие ноги."
            )
        }
    }

    private static func workBankedDayLoadSignal(for input: CoachCopyBuildInput) -> CoachBilingualText {
        .en(
            "Serious work is already on the books today.",
            "Сегодня уже была серьёзная работа."
        )
    }

    private static func shouldMentionDayLoadInSignals(_ input: CoachCopyBuildInput) -> Bool {
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

    private static func shouldMentionLongSessionSignal(_ input: CoachCopyBuildInput) -> Bool {
        guard input.scenario == .duringEndurance else { return false }
        guard input.durationBand == .long || input.durationBand == .extended else { return false }
        return !input.modifiers.fuelBehind && !input.modifiers.hydrationBehind
    }

    // MARK: - Warning layer (safety-critical only)

    private static func warningLayer(for input: CoachCopyBuildInput) -> CoachWarningLayer? {
        guard let alert = input.safetyAlert else { return nil }

        let message: CoachBilingualText
        switch alert {
        case .hydrationCritical:
            message = CoachCopyNutritionTiming.hydrationCriticalWarning(
                isActiveSession: isActiveHydrationSession(input.scenario),
                timeOfDay: input.timeOfDay
            )
        case .fuelCritical:
            message = CoachCopyNutritionTiming.fuelCriticalWarning(
                isActiveSession: input.scenario == .duringEndurance
            )
        }

        return CoachWarningLayer(alert: alert, message: message)
    }

    private static func shouldMentionStackedDayRiskSignal(_ input: CoachCopyBuildInput) -> Bool {
        input.modifiers.stackedDayActiveRisk
    }

    private static func stackedDayRiskSignal(for input: CoachCopyBuildInput) -> CoachBilingualText {
        let windDown = CoachCopyNutritionTiming.isWindDown(input.timeOfDay)
        if windDown {
            return .en(
                "Stacked day — stopping now protects tomorrow.",
                "День на пределе — остановка сейчас сохранит завтра."
            )
        }
        if input.tomorrowDemand == .hard {
            return .en(
                "Heavy day stacked with hard work tomorrow.",
                "Сегодня уже много — завтра серьёзная нагрузка."
            )
        }
        return .en(
            "Load is already high — ease this session.",
            "Нагрузка уже высокая — смягчите эту тренировку."
        )
    }

    private static func isActiveHydrationSession(_ scenario: CoachScenarioKey) -> Bool {
        switch scenario {
        case .duringEndurance, .duringRacket, .saunaActive:
            return true
        default:
            return false
        }
    }
}

private extension CoachCopyBuildInput {
    var durationBand: CoachDurationBand { modifiers.durationBand }
}
