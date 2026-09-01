import Foundation

enum RecoveryMovementProvider {

    /// Invented light-movement catalog for morning adjustments (Planner recovery + easy run).
    enum LightOption: String, CaseIterable, Equatable {
        case walk
        case stretch
        case yoga
        case breathing
        case easyRun
    }

    static func generate(context: DailyContext, strategy: DailyStrategy) -> [ProposalCandidate] {
        guard context.canMutate else { return [] }
        guard strategy == .recover || strategy == .maintain || strategy == .protectTomorrow else {
            return []
        }

        let planSuitability = ExistingPlanMovementSuitabilityClassifier.classify(
            todayOpen: context.todayOpen,
            strategy: strategy
        )
        // Suitable light already planned → never invent a duplicate.
        if planSuitability == .suitableLight {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .omit
            MorningProposalDebugTrace.lastNoProposalReason = "suitable_light_already_planned"
            #endif
            return []
        }
        if context.completedWalkToday {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .omit
            MorningProposalDebugTrace.lastNoProposalReason = "walk_already_completed"
            #endif
            return []
        }

        let needsRecoveryMovement = context.yesterdayHeavy
            || strategy == .recover
            || context.recoveryBand == .low

        // Habit is a ranking boost only — never an early empty return.
        let hasLightHabit = HabitualLightRecoveryDetector.hasWeekdayHabit(in: context)

        if context.isColdStart {
            return coldStartOptionalMovement(context: context, strategy: strategy)
        }

        let decision = MorningProposalWalkPolicy.decide(
            mode: context.generationMode,
            recoveryBand: context.recoveryBand,
            sleepPresence: context.sleepPresence,
            todayOpen: context.todayOpen,
            completedWalkToday: context.completedWalkToday,
            alreadyProposedMovement: false,
            yesterdayHeavyEndurance: context.yesterdayHeavy,
            confidence: mapConfidence(context.contextFreshness),
            stronglyRejectsWalk: context.stronglyRejectsWalk
        )

        #if DEBUG
        MorningProposalDebugTrace.lastWalkDecision = decision
        #endif

        // Walk-policy omit is hard only for sleep/mode safety — not for inappropriate hard plans.
        if decision == .omit {
            let omitForSafety = context.sleepPresence != .present
                || (context.generationMode != .compose && context.generationMode != .optimize)
            if omitForSafety {
                return []
            }
            if !needsRecoveryMovement && planSuitability != .none {
                return []
            }
        }

        if decision == .guidance, !needsRecoveryMovement, !context.stronglyRejectsWalk {
            return [
                GuidanceCandidateProvider.make(
                    code: .hydrateThroughMorning,
                    reason: .openDayMovementSupport,
                    at: context.now.addingTimeInterval(75),
                    context: context
                )
            ]
        }

        let hasWalkHabit = habitualWalkDate(context: context, calendar: .current) != nil
        var allowWalk = !(isWeekdayWorkday(context.now) && !hasWalkHabit && !needsRecoveryMovement)
        allowWalk = allowWalk && !context.stronglyRejectsWalk
        if !context.outdoorSuitability.allowsOutdoorCreate {
            allowWalk = false
        }

        let selectedEligible = (decision == .selected || strategy == .recover)
            && needsRecoveryMovement
            && !context.stronglyRejectsWalk

        return inventLightMovement(
            context: context,
            strategy: strategy,
            allowWalk: allowWalk,
            selectedEligible: selectedEligible,
            preferHabitFamily: hasLightHabit,
            debugReason: "catalog_pick"
        )
    }

    /// Builds one invented light-movement candidate from the recovery catalog.
    static func inventLightMovement(
        context: DailyContext,
        strategy: DailyStrategy,
        allowWalk: Bool,
        selectedEligible: Bool,
        preferHabitFamily: Bool = false,
        debugReason: String
    ) -> [ProposalCandidate] {
        guard context.generationMode == .compose || context.generationMode == .optimize else {
            return []
        }
        let planSuitability = ExistingPlanMovementSuitabilityClassifier.classify(
            todayOpen: context.todayOpen,
            strategy: strategy
        )
        guard planSuitability != .suitableLight, !context.completedWalkToday else { return [] }
        let preferredDate = recoveryWalkSlot(context: context)
            ?? context.now.addingTimeInterval(60 * 60)

        let eligible = eligibleOptions(
            context: context,
            strategy: strategy,
            allowWalk: allowWalk
        )
        guard let option = pickOption(
            eligible,
            dayKey: context.dayKey,
            context: context,
            strategy: strategy,
            preferHabitFamily: preferHabitFamily
        ) else {
            return []
        }

        let duration = durationMinutes(for: option, recoveryBand: context.recoveryBand)
        guard let proposedDate = ProposalPlanScheduleResolver.resolveCreateStart(
            preferred: preferredDate,
            durationMinutes: duration,
            against: context.todayActivities,
            now: context.now,
            maxSlideFromPreferredMinutes: 180,
            calendar: .current
        ) else {
            return []
        }

        #if DEBUG
        MorningProposalDebugTrace.lastWalkDecision = selectedEligible ? .selected : .unselected
        MorningProposalDebugTrace.lastNoProposalReason = "\(debugReason):\(option.rawValue)"
        #endif

        // On recover, default-select movement so it leads the hero over meals.
        let select = selectedEligible || strategy == .recover
        return [makeCandidate(
            option: option,
            proposedDate: proposedDate,
            context: context,
            strategy: strategy,
            selectedEligible: select
        )]
    }

    static func eligibleOptions(
        context: DailyContext,
        strategy: DailyStrategy,
        allowWalk: Bool
    ) -> [LightOption] {
        var options: [LightOption] = [.stretch, .yoga, .breathing]
        let outdoorOK = allowWalk && context.outdoorSuitability.allowsOutdoorCreate
        if outdoorOK {
            options.insert(.walk, at: 0)
        }
        if strategy == .maintain,
           context.recoveryBand == .good,
           !context.yesterdayHeavy,
           outdoorOK {
            options.append(.easyRun)
        }
        return options
    }

    static func pickOption(
        _ eligible: [LightOption],
        dayKey: String,
        context: DailyContext,
        strategy: DailyStrategy,
        preferHabitFamily: Bool = false
    ) -> LightOption? {
        guard !eligible.isEmpty else { return nil }

        var ranked = eligible
        #if DEBUG
        let initialEligible = eligible
        var walkRejectFiltered = Set<LightOption>()
        var weatherFiltered = Set<LightOption>()
        var lowRecoveryFiltered = Set<LightOption>()
        var cooloffFiltered = Set<LightOption>()
        #endif

        if context.stronglyRejectsWalk || context.walkRejectPenalty >= 4 {
            let indoor = ranked.filter { $0 != .walk && $0 != .easyRun }
            #if DEBUG
            walkRejectFiltered = Set(ranked.filter { $0 == .walk || $0 == .easyRun })
            #endif
            if !indoor.isEmpty { ranked = indoor }
        }

        if context.outdoorSuitability == .adverse || context.outdoorSuitability == .unsafe {
            let indoor = ranked.filter { $0 != .walk && $0 != .easyRun }
            #if DEBUG
            weatherFiltered = Set(ranked.filter { $0 == .walk || $0 == .easyRun })
            #endif
            if !indoor.isEmpty { ranked = indoor }
        }

        if context.recoveryBand == .low {
            let gentle = ranked.filter { $0 == .breathing || $0 == .stretch || $0 == .yoga }
            #if DEBUG
            lowRecoveryFiltered = Set(ranked.filter { !gentle.contains($0) })
            #endif
            if !gentle.isEmpty { ranked = gentle }
        }

        let notRecentlyOffered = ranked.filter { option in
            let changeId = option == .walk ? "walk-recovery" : "\(option.rawValue)-recovery"
            return !ProposalOfferHistoryStore.wasRecentlyOffered(
                changeId: changeId,
                excludingDayKey: context.dayKey,
                lookingBackDays: ProposalRepetitionGuard.cooloffDays,
                referenceDate: context.now
            )
        }
        if !notRecentlyOffered.isEmpty {
            #if DEBUG
            cooloffFiltered = Set(ranked.filter { !notRecentlyOffered.contains($0) })
            #endif
            ranked = notRecentlyOffered
        }

        let rankedBeforeAffinity = ranked
        let affinities = SimilarDayAffinityScorer.affinities(for: context, strategy: strategy)
        ranked = SimilarDayAffinityScorer.rankedOptions(ranked, affinities: affinities)
        let rankedAfterAffinity = ranked

        if preferHabitFamily {
            let habitPrefs: [LightOption] = HabitualLightRecoveryDetector.candidates(in: context).compactMap { aggregate in
                let blob = "\(aggregate.title) \(aggregate.activityType)".lowercased()
                if blob.contains("yoga") { return .yoga }
                if blob.contains("stretch") { return .stretch }
                if blob.contains("breath") { return .breathing }
                return nil
            }
            if let preferred = habitPrefs.first(where: { ranked.contains($0) }) {
                #if DEBUG
                recordMovementDecisionTrace(
                    context: context,
                    strategy: strategy,
                    state: .init(
                        initialEligible: initialEligible,
                        ranked: ranked,
                        walkRejectFiltered: walkRejectFiltered,
                        weatherFiltered: weatherFiltered,
                        lowRecoveryFiltered: lowRecoveryFiltered,
                        cooloffFiltered: cooloffFiltered,
                        rankedBeforeAffinity: rankedBeforeAffinity,
                        rankedAfterAffinity: rankedAfterAffinity,
                        affinities: affinities,
                        similarDays: SimilarDayAffinityScorer.diagnostics(for: context, strategy: strategy),
                        preferHabitFamily: preferHabitFamily,
                        habitWinner: preferred,
                        phaseAWinner: RecoveryMovementProvider.finishPick(
                            ranked: rankedBeforeAffinity,
                            dayKey: dayKey,
                            context: context,
                            preferHabitFamily: false
                        ),
                        finalWinner: preferred
                    )
                )
                #endif
                return preferred
            }
        }

        if ranked.contains(.walk),
           (context.outdoorSuitability == .good || context.outdoorSuitability == .acceptable),
           context.recoveryBand != .low,
           (context.isColdStart || context.yesterdayHeavy) {
            if !context.isColdStart, dayBucket(dayKey) % 4 == 0 {
                let indoor = ranked.filter { $0 == .stretch || $0 == .yoga || $0 == .breathing }
                if let pick = rotate(indoor, dayKey: dayKey) {
                    #if DEBUG
                    recordMovementDecisionTrace(
                        context: context,
                        strategy: strategy,
                        state: movementPickTraceState(
                            initialEligible: initialEligible,
                            ranked: ranked,
                            walkRejectFiltered: walkRejectFiltered,
                            weatherFiltered: weatherFiltered,
                            lowRecoveryFiltered: lowRecoveryFiltered,
                            cooloffFiltered: cooloffFiltered,
                            rankedBeforeAffinity: rankedBeforeAffinity,
                            rankedAfterAffinity: rankedAfterAffinity,
                            affinities: affinities,
                            context: context,
                            strategy: strategy,
                            preferHabitFamily: preferHabitFamily,
                            habitWinner: nil,
                            phaseAWinner: RecoveryMovementProvider.finishPick(
                                ranked: rankedBeforeAffinity,
                                dayKey: dayKey,
                                context: context,
                                preferHabitFamily: false
                            ),
                            finalWinner: pick
                        )
                    )
                    #endif
                    return pick
                }
            }
            #if DEBUG
            recordMovementDecisionTrace(
                context: context,
                strategy: strategy,
                state: movementPickTraceState(
                    initialEligible: initialEligible,
                    ranked: ranked,
                    walkRejectFiltered: walkRejectFiltered,
                    weatherFiltered: weatherFiltered,
                    lowRecoveryFiltered: lowRecoveryFiltered,
                    cooloffFiltered: cooloffFiltered,
                    rankedBeforeAffinity: rankedBeforeAffinity,
                    rankedAfterAffinity: rankedAfterAffinity,
                    affinities: affinities,
                    context: context,
                    strategy: strategy,
                    preferHabitFamily: preferHabitFamily,
                    habitWinner: nil,
                    phaseAWinner: RecoveryMovementProvider.finishPick(
                        ranked: rankedBeforeAffinity,
                        dayKey: dayKey,
                        context: context,
                        preferHabitFamily: false
                    ),
                    finalWinner: .walk
                )
            )
            #endif
            return .walk
        }

        let rotated = rotate(ranked, dayKey: dayKey)
        #if DEBUG
        recordMovementDecisionTrace(
            context: context,
            strategy: strategy,
            state: movementPickTraceState(
                initialEligible: initialEligible,
                ranked: ranked,
                walkRejectFiltered: walkRejectFiltered,
                weatherFiltered: weatherFiltered,
                lowRecoveryFiltered: lowRecoveryFiltered,
                cooloffFiltered: cooloffFiltered,
                rankedBeforeAffinity: rankedBeforeAffinity,
                rankedAfterAffinity: rankedAfterAffinity,
                affinities: affinities,
                context: context,
                strategy: strategy,
                preferHabitFamily: preferHabitFamily,
                habitWinner: nil,
                phaseAWinner: RecoveryMovementProvider.finishPick(
                    ranked: rankedBeforeAffinity,
                    dayKey: dayKey,
                    context: context,
                    preferHabitFamily: false
                ),
                finalWinner: rotated
            )
        )
        #endif
        return rotated
    }

    /// Shared Phase A finish path (habit → walk preference → rotation).
    static func finishPick(
        ranked: [LightOption],
        dayKey: String,
        context: DailyContext,
        preferHabitFamily: Bool
    ) -> LightOption? {
        if preferHabitFamily {
            let habitPrefs: [LightOption] = HabitualLightRecoveryDetector.candidates(in: context).compactMap { aggregate in
                let blob = "\(aggregate.title) \(aggregate.activityType)".lowercased()
                if blob.contains("yoga") { return .yoga }
                if blob.contains("stretch") { return .stretch }
                if blob.contains("breath") { return .breathing }
                return nil
            }
            if let preferred = habitPrefs.first(where: { ranked.contains($0) }) {
                return preferred
            }
        }

        if ranked.contains(.walk),
           (context.outdoorSuitability == .good || context.outdoorSuitability == .acceptable),
           context.recoveryBand != .low,
           (context.isColdStart || context.yesterdayHeavy) {
            if !context.isColdStart, dayBucket(dayKey) % 4 == 0 {
                let indoor = ranked.filter { $0 == .stretch || $0 == .yoga || $0 == .breathing }
                if let pick = rotate(indoor, dayKey: dayKey) { return pick }
            }
            return .walk
        }

        return rotate(ranked, dayKey: dayKey)
    }

    #if DEBUG
    private static func recordMovementDecisionTrace(
        context: DailyContext,
        strategy: DailyStrategy,
        state: MorningMovementDecisionTracer.PickState
    ) {
        MorningMovementDecisionTracer.record(context: context, strategy: strategy, state: state)
    }

    private static func movementPickTraceState(
        initialEligible: [LightOption],
        ranked: [LightOption],
        walkRejectFiltered: Set<LightOption>,
        weatherFiltered: Set<LightOption>,
        lowRecoveryFiltered: Set<LightOption>,
        cooloffFiltered: Set<LightOption>,
        rankedBeforeAffinity: [LightOption],
        rankedAfterAffinity: [LightOption],
        affinities: [RecoveryMovementFamilyAffinity],
        context: DailyContext,
        strategy: DailyStrategy,
        preferHabitFamily: Bool,
        habitWinner: LightOption?,
        phaseAWinner: LightOption?,
        finalWinner: LightOption?
    ) -> MorningMovementDecisionTracer.PickState {
        MorningMovementDecisionTracer.PickState(
            initialEligible: initialEligible,
            ranked: ranked,
            walkRejectFiltered: walkRejectFiltered,
            weatherFiltered: weatherFiltered,
            lowRecoveryFiltered: lowRecoveryFiltered,
            cooloffFiltered: cooloffFiltered,
            rankedBeforeAffinity: rankedBeforeAffinity,
            rankedAfterAffinity: rankedAfterAffinity,
            affinities: affinities,
            similarDays: SimilarDayAffinityScorer.diagnostics(for: context, strategy: strategy),
            preferHabitFamily: preferHabitFamily,
            habitWinner: habitWinner,
            phaseAWinner: phaseAWinner,
            finalWinner: finalWinner
        )
    }
    #endif


    private static func rotate(_ options: [LightOption], dayKey: String) -> LightOption? {
        guard !options.isEmpty else { return nil }
        return options[dayBucket(dayKey) % options.count]
    }

    private static func dayBucket(_ dayKey: String) -> Int {
        abs(dayKey.utf8.reduce(0) { partial, byte in
            Int(truncatingIfNeeded: (UInt64(partial) &* 31) &+ UInt64(byte))
        })
    }

    private static func makeCandidate(
        option: LightOption,
        proposedDate: Date,
        context: DailyContext,
        strategy: DailyStrategy,
        selectedEligible: Bool
    ) -> ProposalCandidate {
        let duration = durationMinutes(for: option, recoveryBand: context.recoveryBand)
        let recoverySupport = context.yesterdayHeavy
            || context.recoveryBand == .low
            || strategy == .recover

        switch option {
        case .walk:
            return ProposalCandidate(
                id: "walk-recovery",
                source: .recoveryMovement,
                kind: .createRecoveryWalk,
                payload: .createRecoveryWalk(
                    CreateRecoveryWalkPayload(
                        proposedDate: proposedDate,
                        durationMinutes: duration,
                        title: "Walk",
                        activityType: "recovery"
                    )
                ),
                compatibleStrategies: [.recover, .maintain, .protectTomorrow],
                physiologicalFit: context.recoveryBand == .low ? .strong : .moderate,
                confidence: selectedEligible ? 0.8 : 0.55,
                burden: .low,
                reasonCodes: [recoverySupport ? .recoveryWalkSupport : .openDayMovementSupport],
                conflicts: [],
                defaultSelectionEligibility: selectedEligible ? .eligible : .ineligible,
                sortTime: proposedDate,
                evidenceScenarioKey: context.scenarioKey?.rawValue,
                identityKey: "walk:recovery"
            )

        case .stretch, .yoga, .breathing, .easyRun:
            let spec = plannedSpec(for: option)
            let reason: CoachProposalReasonCode = {
                switch option {
                case .stretch, .yoga, .breathing:
                    return .recoveryStretchSupport
                case .easyRun:
                    return .openDayMovementSupport
                case .walk:
                    return .recoveryWalkSupport
                }
            }()
            return ProposalCandidate(
                id: "\(option.rawValue)-recovery",
                source: .recoveryMovement,
                kind: .createPlannedActivity,
                payload: .createPlannedActivity(
                    CreatePlannedActivityPayload(
                        proposedDate: proposedDate,
                        durationMinutes: duration,
                        title: spec.title,
                        activityType: spec.activityType,
                        icon: spec.icon,
                        imageName: spec.imageName,
                        colorRed: 0.45,
                        colorGreen: 0.72,
                        colorBlue: 0.62,
                        sourceTemplateDayKey: nil
                    )
                ),
                compatibleStrategies: [.recover, .maintain, .protectTomorrow],
                physiologicalFit: option == .easyRun ? .moderate : .strong,
                confidence: selectedEligible ? 0.72 : 0.58,
                burden: .low,
                reasonCodes: [reason],
                conflicts: [],
                defaultSelectionEligibility: selectedEligible ? .eligible : .ineligible,
                sortTime: proposedDate,
                evidenceScenarioKey: context.scenarioKey?.rawValue,
                identityKey: "\(option.rawValue):recovery"
            )
        }
    }

    private static func plannedSpec(
        for option: LightOption
    ) -> (title: String, activityType: String, icon: String, imageName: String) {
        switch option {
        case .walk:
            return ("Walk", "recovery", "figure.walk", "recovery-walk")
        case .stretch:
            return ("Stretch", "stretching", "figure.cooldown", "recovery-stretch")
        case .yoga:
            return ("Yoga", "yoga", "figure.yoga", "recovery-yoga")
        case .breathing:
            return ("Breathing", "breathing", "wind", "recovery-breathing")
        case .easyRun:
            return ("Easy Run", "running", "figure.run", "workout-running")
        }
    }

    private static func durationMinutes(
        for option: LightOption,
        recoveryBand: ProposalRecoveryBandToken
    ) -> Int {
        switch option {
        case .walk:
            return recoveryBand == .low ? 20 : 25
        case .stretch:
            return 12
        case .yoga:
            return 20
        case .breathing:
            return 10
        case .easyRun:
            return recoveryBand == .good ? 25 : 20
        }
    }

    private static func mapConfidence(
        _ freshness: ProposalContextConfidence
    ) -> MorningProposalDefaultSelection.ConfidenceBucket {
        switch freshness {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    /// First morning with no Plan history: optional light movement from the catalog.
    private static func coldStartOptionalMovement(
        context: DailyContext,
        strategy: DailyStrategy
    ) -> [ProposalCandidate] {
        guard context.generationMode == .compose || context.generationMode == .optimize else {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .omit
            MorningProposalDebugTrace.lastNoProposalReason = "cold_start_mode"
            #endif
            return []
        }
        guard context.sleepPresence == .present else {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .omit
            MorningProposalDebugTrace.lastNoProposalReason = "cold_start_no_sleep"
            #endif
            return []
        }
        guard context.recoveryBand == .low
            || context.recoveryBand == .moderate
            || context.recoveryBand == .good
        else {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .omit
            MorningProposalDebugTrace.lastNoProposalReason = "cold_start_recovery_unavailable"
            #endif
            return []
        }
        guard !context.completedWalkToday,
              ExistingPlanMovementSuitabilityClassifier.classify(
                todayOpen: context.todayOpen,
                strategy: strategy
              ) != .suitableLight else {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .omit
            MorningProposalDebugTrace.lastNoProposalReason = "cold_start_movement_exists"
            #endif
            return []
        }

        return inventLightMovement(
            context: context,
            strategy: strategy,
            allowWalk: !context.stronglyRejectsWalk,
            selectedEligible: false,
            debugReason: "cold_start_optional"
        )
    }

    /// Workday-aware slot: prefer habitual walk time from history; otherwise
    /// weekday evenings (after typical work), weekend midday.
    static func recoveryWalkSlot(context: DailyContext, calendar: Calendar = .current) -> Date? {
        if let habitual = habitualWalkDate(context: context, calendar: calendar) {
            return habitual
        }

        var comps = calendar.dateComponents([.year, .month, .day], from: context.now)
        if isWeekdayWorkday(context.now, calendar: calendar) {
            // Avoid inventing a 12:30 lunch Walk on a working weekday.
            comps.hour = 18
            comps.minute = 0
        } else {
            comps.hour = 12
            comps.minute = 30
        }
        guard var proposed = calendar.date(from: comps) else { return nil }
        if proposed < context.now.addingTimeInterval(30 * 60) {
            proposed = context.now.addingTimeInterval(60 * 60)
        }
        let hour = calendar.component(.hour, from: proposed)
        if isWeekdayWorkday(context.now, calendar: calendar), hour >= 21 {
            return nil
        }
        return proposed
    }

    private static func habitualWalkDate(
        context: DailyContext,
        calendar: Calendar
    ) -> Date? {
        let weekday = calendar.component(.weekday, from: context.now)
        let aggregates = HistoricalActivityAggregator.aggregate(
            templates: context.recentDayTemplates,
            todayWeekday: weekday,
            calendar: calendar
        )
        guard let walk = aggregates.first(where: { aggregate in
            let snap = CoachPlannedActivitySnapshot(
                id: aggregate.id,
                date: context.now,
                type: aggregate.activityType,
                title: aggregate.title,
                durationMinutes: aggregate.medianDurationMinutes,
                icon: aggregate.icon,
                imageName: aggregate.imageName,
                isCompleted: false,
                isSkipped: false,
                source: "history"
            )
            return CoachActivityClassifier.type(for: snap) == .walk
                && aggregate.occurrenceCount >= 1
        }) else {
            return nil
        }

        var comps = calendar.dateComponents([.year, .month, .day], from: context.now)
        comps.hour = walk.habitualHour
        comps.minute = walk.habitualMinute
        comps.second = 0
        guard let proposed = calendar.date(from: comps) else { return nil }
        // Keep the exact habitual clock — don't invent a different midday slot.
        guard proposed >= context.now.addingTimeInterval(15 * 60) else { return nil }
        return proposed
    }

    static func isWeekdayWorkday(_ date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        // Calendar: 1 = Sunday … 7 = Saturday
        return weekday >= 2 && weekday <= 6
    }
}

/// Shared detector: yoga / stretch / breathing habits for today's weekday.
enum HabitualLightRecoveryDetector {

    static func hasWeekdayHabit(in context: DailyContext, calendar: Calendar = .current) -> Bool {
        !candidates(in: context, calendar: calendar).isEmpty
    }

    static func candidates(
        in context: DailyContext,
        calendar: Calendar = .current
    ) -> [HistoricalActivityAggregate] {
        let weekday = calendar.component(.weekday, from: context.now)
        let aggregates = HistoricalActivityAggregator.aggregate(
            templates: context.recentDayTemplates,
            todayWeekday: weekday,
            calendar: calendar
        )
        return aggregates.filter { isLightRecoveryHabit($0, on: context.now) }
    }

    static func isLightRecoveryHabit(
        _ aggregate: HistoricalActivityAggregate,
        on date: Date
    ) -> Bool {
        let snapshot = CoachPlannedActivitySnapshot(
            id: aggregate.id,
            date: date,
            type: aggregate.activityType,
            title: aggregate.title,
            durationMinutes: aggregate.medianDurationMinutes,
            icon: aggregate.icon,
            imageName: aggregate.imageName,
            isCompleted: false,
            isSkipped: false,
            source: "history"
        )
        guard !CoachActivityClassifier.isSeriousTraining(snapshot) else { return false }
        let type = CoachActivityClassifier.type(for: snapshot)
        guard type == .yoga || type == .stretching || type == .breathing else { return false }
        // One same-weekday occurrence is enough — don't invent Walk over a known habit.
        return aggregate.weekdayMatchCount >= 1 && aggregate.occurrenceCount >= 1
    }
}

enum MealLibraryProvider {

    static func generate(context: DailyContext, strategy: DailyStrategy) -> [ProposalCandidate] {
        guard context.canMutate else { return [] }
        guard !context.mealLibrary.isEmpty else { return [] }
        guard strategy != .continueExistingPlan else { return [] }
        guard context.generationMode == .compose || context.generationMode == .optimize else { return [] }

        let preferredTypes: [String]
        switch strategy {
        case .recover:
            preferredTypes = ["recovery", "sleepsupport", "highprotein", "balanced"]
        case .train, .maintain:
            preferredTypes = context.yesterdayHeavy
                ? ["recovery", "highprotein", "balanced", "preworkout"]
                : ["preworkout", "balanced", "highprotein", "endurance"]
        case .protectTomorrow:
            preferredTypes = ["balanced", "recovery", "highprotein"]
        case .continueExistingPlan:
            preferredTypes = ["balanced"]
        }

        let excludedTitles = yesterdayMealTitles(context: context)
            .union(todayMealTitles(context: context))
            .union(recentlyOfferedMealTitles(context: context))
        let includeSnack = strategy == .train || !context.todaySeriousOpen.isEmpty
        let slots = remainingSlots(
            now: context.now,
            strategy: strategy,
            includeSnack: includeSnack,
            library: context.mealLibrary,
            excludedTitles: excludedTitles,
            hasLoggedMealToday: hasLoggedMealToday(context: context),
            occupiedSlots: occupiedMealSlots(context: context)
        )
        let highConfidence = context.contextFreshness == .high

        var usedIds = Set<String>()
        var result: [ProposalCandidate] = []
        for slot in slots {
            guard let meal = pickMeal(
                for: slot,
                from: context.mealLibrary,
                preferredTypes: preferredTypes,
                excludedTitles: excludedTitles,
                usedIds: usedIds
            ) else { continue }
            usedIds.insert(meal.id)
            let proposedDate = slotDate(slot, now: context.now, meal: meal)
            result.append(
                ProposalCandidate(
                    id: "meal-\(slot.rawValue)-\(meal.id)",
                    source: .mealLibrary,
                    kind: .createMealFromLibrary,
                    payload: .createMealFromLibrary(
                        CreateMealFromLibraryPayload(
                            mealId: meal.id,
                            title: meal.title,
                            proposedDate: proposedDate,
                            durationMinutes: 15,
                            calories: meal.calories,
                            protein: meal.protein,
                            carbs: meal.carbs,
                            fats: meal.fats,
                            fiber: meal.fiber,
                            imageName: meal.imageName
                        )
                    ),
                    compatibleStrategies: [.recover, .maintain, .train, .protectTomorrow],
                    physiologicalFit: highConfidence ? .moderate : .weak,
                    confidence: highConfidence ? 0.7 : 0.45,
                    burden: .low,
                    reasonCodes: [mealReason(
                        slot: slot,
                        strategy: strategy,
                        yesterdayHeavy: context.yesterdayHeavy
                    )],
                    conflicts: [],
                    defaultSelectionEligibility: highConfidence ? .eligible : .ineligible,
                    sortTime: proposedDate,
                    evidenceScenarioKey: context.scenarioKey?.rawValue,
                    identityKey: "meal:\(slot.rawValue):\(meal.id)"
                )
            )
        }
        return result
    }

    static func mealReason(
        slot: ProposalMealSlot,
        strategy: DailyStrategy,
        yesterdayHeavy: Bool
    ) -> CoachProposalReasonCode {
        let rebuild = strategy == .recover || yesterdayHeavy
        switch slot {
        case .breakfast:
            return rebuild ? .libraryMealRecoveryBreakfast : .libraryMealSteadyBreakfast
        case .lunch:
            return rebuild ? .libraryMealRecoveryLunch : .libraryMealSteadyLunch
        case .dinner:
            return rebuild ? .libraryMealRecoveryDinner : .libraryMealSteadyDinner
        case .snack:
            return .libraryMealSupport
        }
    }

    /// Strict type matching — `"balanced"` only matches meals whose type contains balanced.
    static func pickMeals(
        from library: [ProposalMealCandidate],
        preferredTypes: [String],
        limit: Int
    ) -> [ProposalMealCandidate] {
        var picks: [ProposalMealCandidate] = []
        var seen = Set<String>()
        for type in preferredTypes {
            for meal in library where !seen.contains(meal.id) {
                if meal.mealsTypeRaw.lowercased().contains(type) {
                    picks.append(meal)
                    seen.insert(meal.id)
                    if picks.count >= limit { return picks }
                    break
                }
            }
        }
        // True fallback only when no preferred type matched.
        if picks.isEmpty {
            for meal in library where !seen.contains(meal.id) {
                picks.append(meal)
                seen.insert(meal.id)
                if picks.count >= limit { break }
            }
        }
        return picks
    }

    static func remainingSlots(
        now: Date,
        strategy: DailyStrategy,
        includeSnack: Bool,
        library: [ProposalMealCandidate] = [],
        excludedTitles: Set<String> = [],
        hasLoggedMealToday: Bool = false,
        occupiedSlots: Set<ProposalMealSlot> = [],
        calendar: Calendar = .current
    ) -> [ProposalMealSlot] {
        let hour = calendar.component(.hour, from: now)
        var ordered: [ProposalMealSlot] = []
        // Don't invent breakfast before the user has eaten anything today.
        if hour < 10, hasLoggedMealToday { ordered.append(.breakfast) }
        if hour < 14 { ordered.append(.lunch) }
        if hour < 21 { ordered.append(.dinner) }
        if includeSnack, hour < 17 { ordered.append(.snack) }

        ordered = ordered.filter { !occupiedSlots.contains($0) }

        let maxCount: Int
        switch strategy {
        case .continueExistingPlan:
            maxCount = 0
        default:
            maxCount = 2
        }

        let matched = ordered.filter { slot in
            library.contains { meal in
                !excludedTitles.contains(normalizedTitle(meal.title))
                    && ProposalMealSlot.from(suggestedTime: meal.suggestedTime) == slot
            }
        }
        let source = matched.isEmpty ? ordered : matched
        return Array(source.prefix(maxCount))
    }

    static func pickMeal(
        for slot: ProposalMealSlot,
        from library: [ProposalMealCandidate],
        preferredTypes: [String],
        excludedTitles: Set<String>,
        usedIds: Set<String>
    ) -> ProposalMealCandidate? {
        func isAvailable(_ meal: ProposalMealCandidate) -> Bool {
            !usedIds.contains(meal.id) && !excludedTitles.contains(normalizedTitle(meal.title))
        }

        let slotMeals = library.filter { meal in
            isAvailable(meal) && (ProposalMealSlot.from(suggestedTime: meal.suggestedTime) == slot)
        }
        if let typed = firstPreferred(in: slotMeals, preferredTypes: preferredTypes) {
            return typed
        }
        if let first = slotMeals.first {
            return first
        }
        // Don't dump a dinner plate into breakfast just to fill the list.
        return nil
    }

    private static func firstPreferred(
        in meals: [ProposalMealCandidate],
        preferredTypes: [String]
    ) -> ProposalMealCandidate? {
        for type in preferredTypes {
            if let match = meals.first(where: { $0.mealsTypeRaw.lowercased().contains(type) }) {
                return match
            }
        }
        return nil
    }

    private static func slotDate(
        _ slot: ProposalMealSlot,
        now: Date,
        meal: ProposalMealCandidate,
        calendar: Calendar = .current
    ) -> Date {
        let base = calendar.startOfDay(for: now)
        let earliest = now.addingTimeInterval(25 * 60)
        if let suggested = meal.suggestedTime,
           ProposalMealSlot.from(suggestedTime: suggested) == slot,
           let parsed = parseSuggestedTime(suggested, on: base, calendar: calendar) {
            return max(parsed, earliest)
        }
        let proposed = calendar.date(
            bySettingHour: slot.defaultHour,
            minute: slot.defaultMinute,
            second: 0,
            of: base
        ) ?? now
        return max(proposed, earliest)
    }

    private static func yesterdayMealTitles(
        context: DailyContext,
        calendar: Calendar = .current
    ) -> Set<String> {
        guard let yesterday = calendar.date(
            byAdding: .day,
            value: -1,
            to: calendar.startOfDay(for: context.now)
        ) else {
            return []
        }
        let key = ProposalInputFingerprintBuilder.dayKey(for: yesterday, calendar: calendar)
        let activities = context.recentDayTemplates.first { $0.dayKey == key }?.activities ?? []
        return Set(
            activities
                .filter { !$0.isSkipped && CoachCanonicalDayState.isNutritionLog($0) }
                .map { normalizedTitle($0.title) }
        )
    }

    private static func todayMealTitles(context: DailyContext) -> Set<String> {
        Set(
            context.todayActivities
                .filter { !$0.isSkipped && CoachCanonicalDayState.isNutritionLog($0) }
                .map { normalizedTitle($0.title) }
        )
    }

    private static func hasLoggedMealToday(context: DailyContext) -> Bool {
        context.todayActivities.contains { activity in
            guard !activity.isSkipped, CoachCanonicalDayState.isNutritionLog(activity) else {
                return false
            }
            return activity.isCompleted
                || activity.isPartialCompletion
                || activity.calories > 0
        }
    }

    private static func occupiedMealSlots(
        context: DailyContext,
        calendar: Calendar = .current
    ) -> Set<ProposalMealSlot> {
        Set(
            context.todayActivities.compactMap { activity -> ProposalMealSlot? in
                guard !activity.isSkipped, CoachCanonicalDayState.isNutritionLog(activity) else {
                    return nil
                }
                let hour = calendar.component(.hour, from: activity.date)
                let minute = calendar.component(.minute, from: activity.date)
                return ProposalMealSlot.from(totalMinutes: hour * 60 + minute)
            }
        )
    }

    private static func recentlyOfferedMealTitles(context: DailyContext) -> Set<String> {
        var titles: Set<String> = []
        for meal in context.mealLibrary {
            let offered = ProposalMealSlot.allCases.contains { slot in
                ProposalOfferHistoryStore.wasRecentlyOffered(
                    changeId: "meal-\(slot.rawValue)-\(meal.id)",
                    excludingDayKey: context.dayKey,
                    lookingBackDays: 2,
                    referenceDate: context.now
                )
            }
            if offered {
                titles.insert(normalizedTitle(meal.title))
            }
        }
        return titles
    }

    private static func normalizedTitle(_ title: String) -> String {
        title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseSuggestedTime(
        _ raw: String?,
        on dayStart: Date,
        calendar: Calendar
    ) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw.split(separator: ":")
        guard parts.count >= 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)
    }
}

enum GuidanceCandidateProvider {

    static func generate(context: DailyContext, strategy: DailyStrategy) -> [ProposalCandidate] {
        if context.isColdStart {
            return coldStartGuidance(context: context, strategy: strategy)
        }

        var result: [ProposalCandidate] = []

        // Empty meal library → lead with a useful morning fuel tip (no plan mutation).
        if context.mealLibrary.isEmpty,
           context.generationMode == .compose || context.generationMode == .optimize {
            result.append(
                make(
                    code: morningFuelCode(context: context, strategy: strategy),
                    reason: .libraryMealSupport,
                    at: context.now.addingTimeInterval(30),
                    context: context
                )
            )
        }

        if context.contextFreshness == .low || context.recoveryBand == .unavailable {
            result.append(make(code: .listenToBodyOnLowReadiness, reason: .insufficientConfidence, at: context.now, context: context))
        } else if strategy == .recover {
            result.append(make(code: .easeIntoFirstEffort, reason: .lowRecoveryLoadProtection, at: context.now.addingTimeInterval(60), context: context))
        }

        if !context.todaySeriousOpen.isEmpty || strategy == .train {
            let time = context.todaySeriousOpen.map(\.date).min() ?? context.now
            result.append(make(code: .fuelBeforeSession, reason: .planAlreadyAppropriate, at: time, context: context))
        } else if strategy == .maintain || strategy == .recover {
            result.append(make(code: .hydrateThroughMorning, reason: .openDayMovementSupport, at: context.now.addingTimeInterval(90), context: context))
        }

        if strategy == .protectTomorrow || context.tomorrowDemand == .hard || context.tomorrowDemand == .moderate {
            result.append(make(code: .protectTomorrowFreshness, reason: .tomorrowDemandProtection, at: context.now.addingTimeInterval(120), context: context))
        }

        // Deduplicate by identity key while preserving order.
        var seen = Set<String>()
        var unique: [ProposalCandidate] = []
        for item in result where seen.insert(item.identityKey).inserted {
            unique.append(item)
        }
        // Prefer keeping the morning-fuel tip when the library is empty.
        if context.mealLibrary.isEmpty,
           let fuel = unique.first(where: {
               if case .guidanceOnly(let p) = $0.payload {
                   return p.guidanceCode == .morningFuelWithoutLibrary
                       || p.guidanceCode == .morningFuelGentleRecovery
                       || p.guidanceCode == .morningFuelSteadyEnergy
               }
               return false
           }) {
            var prioritized = [fuel]
            prioritized.append(contentsOf: unique.filter { $0.id != fuel.id })
            return Array(prioritized.prefix(2))
        }
        return Array(unique.prefix(2))
    }

    /// First mornings without history: one body tip + optional fuel tip — never tip soup.
    private static func coldStartGuidance(
        context: DailyContext,
        strategy: DailyStrategy
    ) -> [ProposalCandidate] {
        var tips: [ProposalCandidate] = []

        if context.mealLibrary.isEmpty,
           context.generationMode == .compose || context.generationMode == .optimize {
            tips.append(
                make(
                    code: morningFuelCode(context: context, strategy: strategy),
                    reason: .libraryMealSupport,
                    at: context.now.addingTimeInterval(30),
                    context: context
                )
            )
        }

        let bodyCode: CoachGuidanceCode
        let bodyReason: CoachProposalReasonCode
        if context.contextFreshness == .low || context.recoveryBand == .unavailable {
            bodyCode = .listenToBodyOnLowReadiness
            bodyReason = .insufficientConfidence
        } else if strategy == .recover || context.recoveryBand == .low {
            bodyCode = .easeIntoFirstEffort
            bodyReason = .lowRecoveryLoadProtection
        } else if !context.todaySeriousOpen.isEmpty || strategy == .train {
            bodyCode = .fuelBeforeSession
            bodyReason = .planAlreadyAppropriate
        } else {
            bodyCode = .hydrateThroughMorning
            bodyReason = .openDayMovementSupport
        }

        tips.append(
            make(
                code: bodyCode,
                reason: bodyReason,
                at: context.now.addingTimeInterval(60),
                context: context
            )
        )

        var seen = Set<String>()
        var unique: [ProposalCandidate] = []
        for tip in tips where seen.insert(tip.identityKey).inserted {
            unique.append(tip)
        }
        return Array(unique.prefix(2))
    }

    private static func morningFuelCode(
        context: DailyContext,
        strategy: DailyStrategy
    ) -> CoachGuidanceCode {
        if context.recoveryBand == .low || strategy == .recover || context.yesterdayHeavy {
            return .morningFuelGentleRecovery
        }
        if strategy == .train || !context.todaySeriousOpen.isEmpty {
            return .morningFuelSteadyEnergy
        }
        return .morningFuelWithoutLibrary
    }

    static func make(
        code: CoachGuidanceCode,
        reason: CoachProposalReasonCode,
        at time: Date,
        context: DailyContext
    ) -> ProposalCandidate {
        ProposalCandidate(
            id: "guidance-\(code.rawValue)",
            source: .guidance,
            kind: .guidanceOnly,
            payload: .guidanceOnly(GuidanceOnlyPayload(guidanceCode: code, relatedActivityId: nil)),
            compatibleStrategies: Set(DailyStrategy.allCases),
            physiologicalFit: .moderate,
            confidence: 0.6,
            burden: .low,
            reasonCodes: [reason],
            conflicts: [],
            defaultSelectionEligibility: .notSelectable,
            sortTime: time,
            evidenceScenarioKey: context.scenarioKey?.rawValue,
            identityKey: "guidance:\(code.rawValue)"
        )
    }
}
