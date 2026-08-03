import Foundation

struct SimilarDayTemplate: Sendable, Equatable {
    let dayKey: String
    /// Observation-backed band when available; `.unavailable` when missing.
    let recoveryBand: ProposalRecoveryBandToken
    let observationAvailable: Bool
    let sleepPresence: ProposalSleepPresenceToken
    /// All non-drink activities for the day (including skipped) for quality scoring.
    let activities: [CoachPlannedActivitySnapshot]
}

struct SimilarDayScoreBreakdown: Sendable, Equatable {
    let dayKey: String
    let bandScore: Int
    let qualityScore: Int
    let weekdayBonus: Int
    let confidencePenalty: Int
    let finalScore: Int
    let observationAvailable: Bool
    let recoveryBand: ProposalRecoveryBandToken
    let completedCount: Int
    let skippedCount: Int
    let partialCount: Int
    let meaningfulNonMealCount: Int
}

enum WalkProposalDecision: String, Sendable, Equatable {
    case selected
    case unselected
    case guidance
    case omit
}

/// Mines recent planned days for templates that fit today’s recovery band.
enum SimilarDayPlanMiner {

    static func scoreTemplate(
        _ candidate: SimilarDayTemplate,
        todayBand: ProposalRecoveryBandToken,
        todayWeekday: Int,
        calendar: Calendar = .current
    ) -> SimilarDayScoreBreakdown? {
        guard todayBand != .unavailable else { return nil }
        let usable = filteredActivities(candidate.activities, for: todayBand)
        guard !usable.isEmpty else { return nil }

        let band = bandScore(candidate.recoveryBand, today: todayBand)
        let quality = qualityScore(for: candidate.activities)
        let weekday: Int = {
            if let sample = usable.first {
                let weekday = calendar.component(.weekday, from: sample.date)
                return weekday == todayWeekday ? 4 : 0
            }
            return 0
        }()
        let confidencePenalty = candidate.observationAvailable ? 0 : 6
        // Coarse table: band dominates physiology; quality rewards completion; item count capped inside quality.
        let final = band * 10 + quality + weekday - confidencePenalty

        let completed = candidate.activities.filter(\.isCompleted).count
        let skipped = candidate.activities.filter(\.isSkipped).count
        let partial = candidate.activities.filter(\.isPartialCompletion).count
        let meaningful = candidate.activities.filter {
            !$0.isSkipped && !["meal", "snack", "food", "drink", "water"].contains($0.type.lowercased())
        }.count

        return SimilarDayScoreBreakdown(
            dayKey: candidate.dayKey,
            bandScore: band,
            qualityScore: quality,
            weekdayBonus: weekday,
            confidencePenalty: confidencePenalty,
            finalScore: final,
            observationAvailable: candidate.observationAvailable,
            recoveryBand: candidate.recoveryBand,
            completedCount: completed,
            skippedCount: skipped,
            partialCount: partial,
            meaningfulNonMealCount: meaningful
        )
    }

    static func bestTemplate(
        todayBand: ProposalRecoveryBandToken,
        todayWeekday: Int,
        candidates: [SimilarDayTemplate],
        calendar: Calendar = .current
    ) -> (template: SimilarDayTemplate, breakdown: SimilarDayScoreBreakdown)? {
        let scored: [(SimilarDayTemplate, SimilarDayScoreBreakdown)] = candidates.compactMap { candidate in
            guard let breakdown = scoreTemplate(
                candidate,
                todayBand: todayBand,
                todayWeekday: todayWeekday,
                calendar: calendar
            ) else {
                return nil
            }
            let usable = filteredActivities(candidate.activities, for: todayBand)
            let refined = SimilarDayTemplate(
                dayKey: candidate.dayKey,
                recoveryBand: candidate.recoveryBand,
                observationAvailable: candidate.observationAvailable,
                sleepPresence: candidate.sleepPresence,
                activities: usable
            )
            return (refined, breakdown)
        }

        // Deterministic tie-break: higher score, then observation available, then dayKey.
        return scored.max { lhs, rhs in
            if lhs.1.finalScore != rhs.1.finalScore {
                return lhs.1.finalScore < rhs.1.finalScore
            }
            if lhs.0.observationAvailable != rhs.0.observationAvailable {
                return !lhs.0.observationAvailable && rhs.0.observationAvailable
            }
            return lhs.0.dayKey < rhs.0.dayKey
        }
    }

    /// Coarse quality 0...12 from completion outcomes (not item-count dominated).
    static func qualityScore(for activities: [CoachPlannedActivitySnapshot]) -> Int {
        let relevant = activities.filter {
            !["drink", "water"].contains($0.type.lowercased())
        }
        guard !relevant.isEmpty else { return 0 }

        let completed = relevant.filter(\.isCompleted).count
        let skipped = relevant.filter(\.isSkipped).count
        let partial = relevant.filter(\.isPartialCompletion).count
        let incompleteOpen = relevant.filter { !$0.isCompleted && !$0.isSkipped }.count
        let meaningful = relevant.filter {
            !$0.isSkipped && !["meal", "snack", "food"].contains($0.type.lowercased())
        }.count

        var score = 0
        // Completions matter most.
        score += min(completed, 3) * 3
        // Light credit for having a real day shape (capped).
        score += min(meaningful, 2)
        // Penalties.
        score -= min(skipped, 3) * 2
        score -= min(partial, 2)
        score -= min(incompleteOpen, 2)

        // Title duplicate clutter.
        let titles = relevant.map { $0.title.lowercased() }
        if Set(titles).count < titles.count {
            score -= 1
        }

        return max(0, min(12, score))
    }

    static func filteredActivities(
        _ activities: [CoachPlannedActivitySnapshot],
        for band: ProposalRecoveryBandToken
    ) -> [CoachPlannedActivitySnapshot] {
        activities
            .filter { !$0.isSkipped }
            .filter { activity in
                let type = activity.type.lowercased()
                if type == "drink" || type == "water" { return false }
                return true
            }
            .filter { activity in
                switch band {
                case .low:
                    let family = CoachActivityClassifier.family(for: activity)
                    let type = activity.type.lowercased()
                    return family == .recovery
                        || type == "meal"
                        || type == "habit"
                        || type == "snack"
                case .moderate:
                    return !CoachActivityClassifier.isSeriousTraining(activity)
                        || CoachActivityClassifier.family(for: activity) == .recovery
                        || activity.type.lowercased() == "meal"
                case .good:
                    return true
                case .unavailable:
                    return false
                }
            }
            .sorted { $0.date < $1.date }
    }

    static func bandScore(
        _ candidate: ProposalRecoveryBandToken,
        today: ProposalRecoveryBandToken
    ) -> Int {
        if candidate == .unavailable {
            return 1 // neutral, not pretend-similar
        }
        if candidate == today { return 3 }
        let order: [ProposalRecoveryBandToken] = [.low, .moderate, .good]
        guard let a = order.firstIndex(of: candidate),
              let b = order.firstIndex(of: today) else {
            return 0
        }
        return max(0, 2 - abs(a - b))
    }

    static func recoveryBand(fromPercent percent: Int) -> ProposalRecoveryBandToken {
        if percent >= 70 { return .good }
        if percent >= 55 { return .moderate }
        return .low
    }
}

enum MorningProposalWalkPolicy {

    static func decide(
        mode: MorningProposalGenerationMode,
        recoveryBand: ProposalRecoveryBandToken,
        sleepPresence: ProposalSleepPresenceToken,
        todayOpen: [CoachPlannedActivitySnapshot],
        completedWalkToday: Bool,
        alreadyProposedMovement: Bool,
        yesterdayHeavyEndurance: Bool,
        confidence: MorningProposalDefaultSelection.ConfidenceBucket,
        stronglyRejectsWalk: Bool
    ) -> WalkProposalDecision {
        guard mode == .compose || mode == .optimize else {
            return .omit
        }
        guard sleepPresence == .present else { return .omit }
        guard recoveryBand == .low || recoveryBand == .moderate || recoveryBand == .good else {
            return .omit
        }
        guard !completedWalkToday else { return .omit }
        guard !alreadyProposedMovement else { return .omit }

        let hasMovement = todayOpen.contains {
            let family = CoachActivityClassifier.family(for: $0)
            let type = CoachActivityClassifier.type(for: $0)
            return family == .endurance || family == .recovery || type == .walk || type == .cycling || type == .running || type == .hiit
        }
        if hasMovement { return .omit }

        // Empty Plan alone is not enough when recovery is good and confidence weak.
        if stronglyRejectsWalk {
            return .guidance
        }
        if yesterdayHeavyEndurance && recoveryBand == .good {
            return .guidance
        }

        let purposeOK = recoveryBand == .low || recoveryBand == .moderate
            || (recoveryBand == .good && mode == .compose && confidence == .high)

        guard purposeOK else {
            // Good recovery empty day without strong evidence → omit (no completeness Walk).
            return .omit
        }

        if confidence == .high && (recoveryBand == .low || recoveryBand == .moderate) && !stronglyRejectsWalk {
            return .selected
        }
        if confidence == .medium || recoveryBand == .good {
            return .unselected
        }
        return .guidance
    }
}

enum FullDayProposalComposer {

    static let maxActivityCreatesCompose = 2
    static let maxActivityCreatesOptimize = 1
    static let maxMealCreates = 2

    struct ComposeResult: Sendable {
        let changes: [CoachProposedChange]
        let selectedTemplateDayKey: String?
        let templateBreakdown: SimilarDayScoreBreakdown?
        let scoredTemplates: [SimilarDayScoreBreakdown]
        let walkDecision: WalkProposalDecision
    }

    static func compose(
        now: Date,
        dayKey: String,
        mode: MorningProposalGenerationMode,
        recoveryBand: ProposalRecoveryBandToken,
        sleepPresence: ProposalSleepPresenceToken,
        todayActivities: [CoachPlannedActivitySnapshot],
        recentTemplates: [SimilarDayTemplate],
        mealLibrary: [ProposalMealCandidate],
        scenarioKey: CoachScenarioKey?,
        completedWalkToday: Bool,
        tomorrowDemand: CoachTomorrowDemand,
        walkDecision: WalkProposalDecision,
        confidence: MorningProposalDefaultSelection.ConfidenceBucket
    ) -> ComposeResult {
        let calendar = Calendar.current
        let todayOpen = todayActivities.filter {
            !$0.isCompleted && !$0.isSkipped && CoachActivityClassifier.type(for: $0) != .none
        }

        guard mode == .compose || mode == .optimize else {
            return ComposeResult(
                changes: [],
                selectedTemplateDayKey: nil,
                templateBreakdown: nil,
                scoredTemplates: [],
                walkDecision: walkDecision
            )
        }
        guard sleepPresence == .present else {
            return ComposeResult(
                changes: [],
                selectedTemplateDayKey: nil,
                templateBreakdown: nil,
                scoredTemplates: [],
                walkDecision: walkDecision
            )
        }
        guard recoveryBand == .good || recoveryBand == .moderate || recoveryBand == .low else {
            return ComposeResult(
                changes: [],
                selectedTemplateDayKey: nil,
                templateBreakdown: nil,
                scoredTemplates: [],
                walkDecision: walkDecision
            )
        }

        var changes: [CoachProposedChange] = []
        let weekday = calendar.component(.weekday, from: now)
        let scoredTemplates = recentTemplates.compactMap {
            SimilarDayPlanMiner.scoreTemplate(
                $0,
                todayBand: recoveryBand,
                todayWeekday: weekday,
                calendar: calendar
            )
        }
        .sorted {
            if $0.finalScore != $1.finalScore { return $0.finalScore > $1.finalScore }
            return $0.dayKey > $1.dayKey
        }

        let best = SimilarDayPlanMiner.bestTemplate(
            todayBand: recoveryBand,
            todayWeekday: weekday,
            candidates: recentTemplates,
            calendar: calendar
        )

        let existingTitles = Set(todayOpen.map { $0.title.lowercased() })
        var occupied = todayActivities.map(\.date)
        let maxActivities = mode == .compose ? maxActivityCreatesCompose : maxActivityCreatesOptimize
        let blockSeriousAdds = tomorrowDemand == .hard || tomorrowDemand == .moderate

        if let best, mode == .compose || (mode == .optimize && maxActivities > 0) {
            let activityCreates = best.template.activities
                .filter { $0.type.lowercased() != "meal" && $0.type.lowercased() != "snack" }
                .filter { !existingTitles.contains($0.title.lowercased()) }
                .filter { sample in
                    if blockSeriousAdds && CoachActivityClassifier.isSeriousTraining(sample) {
                        return false
                    }
                    return true
                }
                .prefix(maxActivities)

            for sample in activityCreates {
                if sample.type.lowercased().contains("walk") || CoachActivityClassifier.type(for: sample) == .walk,
                   completedWalkToday {
                    continue
                }
                let proposedDate = remapTime(of: sample.date, onto: now, calendar: calendar, occupied: &occupied)
                changes.append(
                    CoachProposedChange(
                        id: UUID().uuidString,
                        kind: .createPlannedActivity,
                        reasonCode: .similarDaySupport,
                        payload: .createPlannedActivity(
                            CreatePlannedActivityPayload(
                                proposedDate: proposedDate,
                                durationMinutes: max(15, sample.durationMinutes),
                                title: sample.title,
                                activityType: sample.type,
                                icon: sample.icon,
                                imageName: sample.imageName,
                                colorRed: sample.colorRed,
                                colorGreen: sample.colorGreen,
                                colorBlue: sample.colorBlue,
                                sourceTemplateDayKey: best.template.dayKey
                            )
                        ),
                        defaultSelected: false,
                        isSelected: false,
                        sortTime: proposedDate,
                        evidenceScenarioKey: scenarioKey?.rawValue
                    )
                )
            }

            if mode == .compose {
                let mealSamples = best.template.activities
                    .filter { ["meal", "snack", "food"].contains($0.type.lowercased()) }
                    .prefix(maxMealCreates)
                for sample in mealSamples {
                    if let libraryMeal = matchMeal(title: sample.title, in: mealLibrary)
                        ?? mealLibrary.first(where: { $0.title.lowercased() == sample.title.lowercased() }) {
                        let proposedDate = remapTime(of: sample.date, onto: now, calendar: calendar, occupied: &occupied)
                        changes.append(
                            mealChange(
                                from: libraryMeal,
                                at: proposedDate,
                                scenarioKey: scenarioKey,
                                defaultSelected: confidence == .high
                            )
                        )
                    }
                }
            }
        }

        // Library meals when compose and template had none.
        if mode == .compose,
           changes.filter({ $0.kind == .createMealFromLibrary }).isEmpty,
           !mealLibrary.isEmpty {
            let picks = pickMeals(from: mealLibrary, recoveryBand: recoveryBand, limit: maxMealCreates)
            let slots = defaultMealSlots(now: now, calendar: calendar)
            for (index, meal) in picks.enumerated() {
                var slot = slots[min(index, slots.count - 1)]
                while occupied.contains(where: { abs($0.timeIntervalSince(slot)) < 20 * 60 }) {
                    slot = slot.addingTimeInterval(30 * 60)
                }
                occupied.append(slot)
                changes.append(
                    mealChange(
                        from: meal,
                        at: slot,
                        scenarioKey: scenarioKey,
                        defaultSelected: confidence == .high
                    )
                )
            }
        }

        // Optimize: at most supportive meals if clear evidence.
        if mode == .optimize,
           confidence == .high,
           changes.filter({ $0.kind == .createMealFromLibrary }).isEmpty,
           !mealLibrary.isEmpty,
           !todayOpen.isEmpty {
            if let meal = pickMeals(from: mealLibrary, recoveryBand: recoveryBand, limit: 1).first {
                var slot = defaultMealSlots(now: now, calendar: calendar)[0]
                while occupied.contains(where: { abs($0.timeIntervalSince(slot)) < 20 * 60 }) {
                    slot = slot.addingTimeInterval(30 * 60)
                }
                changes.append(
                    mealChange(from: meal, at: slot, scenarioKey: scenarioKey, defaultSelected: false)
                )
            }
        }

        return ComposeResult(
            changes: changes,
            selectedTemplateDayKey: best?.template.dayKey,
            templateBreakdown: best?.breakdown,
            scoredTemplates: scoredTemplates,
            walkDecision: walkDecision
        )
    }

    private static func mealChange(
        from meal: ProposalMealCandidate,
        at date: Date,
        scenarioKey: CoachScenarioKey?,
        defaultSelected: Bool
    ) -> CoachProposedChange {
        CoachProposedChange(
            id: UUID().uuidString,
            kind: .createMealFromLibrary,
            reasonCode: .libraryMealSupport,
            payload: .createMealFromLibrary(
                CreateMealFromLibraryPayload(
                    mealId: meal.id,
                    title: meal.title,
                    proposedDate: date,
                    durationMinutes: 15,
                    calories: meal.calories,
                    protein: meal.protein,
                    carbs: meal.carbs,
                    fats: meal.fats,
                    fiber: meal.fiber,
                    imageName: meal.imageName
                )
            ),
            defaultSelected: defaultSelected,
            isSelected: defaultSelected,
            sortTime: date,
            evidenceScenarioKey: scenarioKey?.rawValue
        )
    }

    private static func matchMeal(title: String, in library: [ProposalMealCandidate]) -> ProposalMealCandidate? {
        let needle = title.lowercased()
        return library.first { $0.title.lowercased() == needle }
            ?? library.first { needle.contains($0.title.lowercased()) || $0.title.lowercased().contains(needle) }
    }

    private static func pickMeals(
        from library: [ProposalMealCandidate],
        recoveryBand: ProposalRecoveryBandToken,
        limit: Int
    ) -> [ProposalMealCandidate] {
        let preferredTypes: [String]
        switch recoveryBand {
        case .low:
            preferredTypes = ["recovery", "sleepsupport", "highprotein", "balanced"]
        case .moderate:
            preferredTypes = ["preworkout", "balanced", "highprotein", "recovery"]
        case .good:
            preferredTypes = ["preworkout", "balanced", "highprotein", "endurance"]
        case .unavailable:
            preferredTypes = ["balanced"]
        }

        var picks: [ProposalMealCandidate] = []
        var seen = Set<String>()
        for type in preferredTypes {
            for meal in library where !seen.contains(meal.id) {
                // Strict match — "balanced" only matches meals whose type contains balanced.
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

    private static func defaultMealSlots(now: Date, calendar: Calendar) -> [Date] {
        let base = calendar.startOfDay(for: now)
        let earliest = now.addingTimeInterval(25 * 60)
        let breakfast = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: base) ?? now
        let lunch = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: base) ?? now
        let dinner = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: base) ?? now
        var unique: [Date] = []
        for slot in [breakfast, lunch, dinner].map({ max($0, earliest) }) where slot >= earliest {
            if unique.contains(where: { abs($0.timeIntervalSince(slot)) < 40 * 60 }) { continue }
            unique.append(slot)
        }
        return unique.isEmpty ? [earliest.addingTimeInterval(20 * 60)] : unique
    }

    private static func remapTime(
        of source: Date,
        onto now: Date,
        calendar: Calendar,
        occupied: inout [Date]
    ) -> Date {
        let parts = calendar.dateComponents([.hour, .minute], from: source)
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = parts.hour ?? 12
        comps.minute = parts.minute ?? 0
        var proposed = calendar.date(from: comps) ?? now.addingTimeInterval(60 * 60)
        if proposed < now.addingTimeInterval(30 * 60) {
            proposed = now.addingTimeInterval(60 * 60)
        }
        for _ in 0..<6 {
            if !occupied.contains(where: { abs($0.timeIntervalSince(proposed)) < 25 * 60 }) {
                occupied.append(proposed)
                return proposed
            }
            proposed = proposed.addingTimeInterval(20 * 60)
        }
        occupied.append(proposed)
        return proposed
    }
}
