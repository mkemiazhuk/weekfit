import Foundation

enum RecoveryMovementProvider {

    static func generate(context: DailyContext, strategy: DailyStrategy) -> [ProposalCandidate] {
        guard context.canMutate else { return [] }
        guard strategy == .recover || strategy == .maintain || strategy == .protectTomorrow else {
            return []
        }

        // Prefer the person's habitual yoga / stretch over inventing a Walk.
        if HabitualLightRecoveryDetector.hasWeekdayHabit(in: context) {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .omit
            MorningProposalDebugTrace.lastNoProposalReason = "prefer_habitual_light_recovery"
            #endif
            return []
        }

        // Cold start: offer an optional Walk so the first morning isn't meals-only.
        // No Plan rhythm yet — keep it unselected and skip habit/weekday gates.
        if context.isColdStart {
            return coldStartOptionalWalk(context: context)
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

        switch decision {
        case .omit:
            return []
        case .guidance:
            return [
                GuidanceCandidateProvider.make(
                    code: .hydrateThroughMorning,
                    reason: .openDayMovementSupport,
                    at: context.now.addingTimeInterval(75),
                    context: context
                )
            ]
        case .selected, .unselected:
            break
        }

        // Do not invent a speculative Walk on a weekday without walk history.
        // Empty workday + low recovery → guidance only (habits come from history).
        let hasWalkHabit = habitualWalkDate(context: context, calendar: .current) != nil
        if isWeekdayWorkday(context.now), !hasWalkHabit {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .guidance
            MorningProposalDebugTrace.lastNoProposalReason = "no_weekday_walk_habit"
            #endif
            return [
                GuidanceCandidateProvider.make(
                    code: .easeIntoFirstEffort,
                    reason: .openDayMovementSupport,
                    at: context.now.addingTimeInterval(75),
                    context: context
                )
            ]
        }

        guard let walkDate = recoveryWalkSlot(context: context) else { return [] }
        // On weekday workdays, never auto-select a speculative Walk — leave it optional.
        let selectedEligible = decision == .selected && !isWeekdayWorkday(context.now)

        return [
            ProposalCandidate(
                id: "walk-recovery",
                source: .recoveryMovement,
                kind: .createRecoveryWalk,
                payload: .createRecoveryWalk(
                    CreateRecoveryWalkPayload(
                        proposedDate: walkDate,
                        durationMinutes: context.recoveryBand == .low ? 20 : 25,
                        title: "Walk",
                        activityType: "recovery"
                    )
                ),
                compatibleStrategies: [.recover, .maintain, .protectTomorrow],
                physiologicalFit: context.recoveryBand == .low ? .strong : .moderate,
                confidence: selectedEligible ? 0.8 : 0.55,
                burden: .low,
                reasonCodes: [
                    context.recoveryBand == .low || context.yesterdayHeavy
                        ? .recoveryWalkSupport
                        : .openDayMovementSupport
                ],
                conflicts: [],
                defaultSelectionEligibility: selectedEligible ? .eligible : .ineligible,
                sortTime: walkDate,
                evidenceScenarioKey: context.scenarioKey?.rawValue,
                identityKey: "walk:recovery"
            )
        ]
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

    /// First morning with no Plan history: suggest a gentle Walk the user can opt into.
    private static func coldStartOptionalWalk(context: DailyContext) -> [ProposalCandidate] {
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
        guard !context.completedWalkToday, !context.hasExistingMovement else {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .omit
            MorningProposalDebugTrace.lastNoProposalReason = "cold_start_movement_exists"
            #endif
            return []
        }
        if context.stronglyRejectsWalk {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .omit
            MorningProposalDebugTrace.lastNoProposalReason = "cold_start_rejects_walk"
            #endif
            return []
        }
        guard let walkDate = recoveryWalkSlot(context: context) else {
            #if DEBUG
            MorningProposalDebugTrace.lastWalkDecision = .omit
            MorningProposalDebugTrace.lastNoProposalReason = "cold_start_no_slot"
            #endif
            return []
        }

        #if DEBUG
        MorningProposalDebugTrace.lastWalkDecision = .unselected
        MorningProposalDebugTrace.lastNoProposalReason = "cold_start_optional_walk"
        #endif

        return [
            ProposalCandidate(
                id: "walk-recovery",
                source: .recoveryMovement,
                kind: .createRecoveryWalk,
                payload: .createRecoveryWalk(
                    CreateRecoveryWalkPayload(
                        proposedDate: walkDate,
                        durationMinutes: context.recoveryBand == .low ? 20 : 25,
                        title: "Walk",
                        activityType: "recovery"
                    )
                ),
                compatibleStrategies: [.recover, .maintain, .protectTomorrow],
                physiologicalFit: context.recoveryBand == .low ? .strong : .moderate,
                confidence: 0.55,
                burden: .low,
                reasonCodes: [.openDayMovementSupport],
                conflicts: [],
                defaultSelectionEligibility: .ineligible,
                sortTime: walkDate,
                evidenceScenarioKey: context.scenarioKey?.rawValue,
                identityKey: "walk:recovery"
            )
        ]
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
            preferredTypes = ["preworkout", "balanced", "highprotein", "endurance"]
        case .protectTomorrow:
            preferredTypes = ["balanced", "recovery", "highprotein"]
        case .continueExistingPlan:
            preferredTypes = ["balanced"]
        }

        let picks = pickMeals(from: context.mealLibrary, preferredTypes: preferredTypes, limit: 3)
        let slots = defaultMealSlots(now: context.now, library: picks)
        return picks.enumerated().map { index, meal in
            let slot = slots[min(index, slots.count - 1)]
            let highConfidence = context.contextFreshness == .high
            return ProposalCandidate(
                id: "meal-\(meal.id)",
                source: .mealLibrary,
                kind: .createMealFromLibrary,
                payload: .createMealFromLibrary(
                    CreateMealFromLibraryPayload(
                        mealId: meal.id,
                        title: meal.title,
                        proposedDate: slot,
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
                reasonCodes: [.libraryMealSupport],
                conflicts: [],
                defaultSelectionEligibility: highConfidence ? .eligible : .ineligible,
                sortTime: slot,
                evidenceScenarioKey: context.scenarioKey?.rawValue,
                identityKey: "meal:\(meal.id)"
            )
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

    private static func defaultMealSlots(now: Date, library: [ProposalMealCandidate]) -> [Date] {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: now)
        let earliest = now.addingTimeInterval(25 * 60)

        let parsed = library
            .compactMap { parseSuggestedTime($0.suggestedTime, on: base, calendar: calendar) }
            .filter { $0 >= earliest }
            .sorted()
        if parsed.count >= 2 {
            return parsed
        }

        // Full-day fuel: breakfast → lunch → dinner (skip slots already past).
        let breakfast = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: base) ?? now
        let lunch = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: base) ?? now
        let dinner = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: base) ?? now

        var slots = [breakfast, lunch, dinner]
            .map { max($0, earliest) }
            .filter { $0 >= earliest }

        // De-dupe when early morning bumps multiple slots to the same window.
        var unique: [Date] = []
        for slot in slots {
            if unique.contains(where: { abs($0.timeIntervalSince(slot)) < 40 * 60 }) { continue }
            unique.append(slot)
        }
        if unique.isEmpty {
            unique = [earliest.addingTimeInterval(20 * 60)]
        }

        if let first = parsed.first {
            unique[0] = max(first, earliest)
        }
        return unique
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
        if context.recoveryBand == .low || strategy == .recover {
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
