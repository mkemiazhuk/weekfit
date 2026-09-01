import Foundation

enum SimilarDayAffinityConfidence: String, Codable, Sendable, Equatable {
    case none
    case weak
    case moderate
    case strong
}

struct RecoveryMovementFamilyAffinity: Sendable, Equatable {
    let family: RecoveryMovementFamily
    let score: Double
    let sampleCount: Int
    let confidence: SimilarDayAffinityConfidence
}

enum SimilarDayAffinityScorer {

    static let similarityThreshold = 35
    static let maxBonus = 10
    static let lookbackDays = 90
    static let positiveSaturationCap = 40.0
    static let rejectionHalfLifeDays = 30.0

    static func affinities(
        for context: DailyContext,
        strategy: DailyStrategy
    ) -> [RecoveryMovementFamilyAffinity] {
        compute(for: context, strategy: strategy).affinities
    }

    static func diagnostics(
        for context: DailyContext,
        strategy: DailyStrategy
    ) -> SimilarDayAffinityDiagnostics {
        compute(for: context, strategy: strategy).diagnostics
    }

    private struct AffinityComputationResult {
        let affinities: [RecoveryMovementFamilyAffinity]
        let diagnostics: SimilarDayAffinityDiagnostics
    }

    private static func compute(
        for context: DailyContext,
        strategy: DailyStrategy
    ) -> AffinityComputationResult {
        let history = MorningAdjustmentDayHistoryStore.allRecords(excludingDayKey: context.dayKey)
        let emptyFamilies = RecoveryMovementFamily.allCases.filter { $0 != .otherTraining }

        guard !history.isEmpty else {
            let affinities = emptyFamilies.map {
                RecoveryMovementFamilyAffinity(
                    family: $0,
                    score: 0,
                    sampleCount: 0,
                    confidence: .none
                )
            }
            let diagnostics = SimilarDayAffinityDiagnostics(
                recordsScanned: 0,
                recordsPassingThreshold: 0,
                overallConfidence: .none,
                fallbackToPhaseA: true,
                topMatchingDays: [],
                families: emptyFamilies.map {
                    FamilyAffinityDiagnostic(
                        family: $0,
                        sampleCount: 0,
                        rawAffinity: 0,
                        confidence: .none,
                        appliedBonus: 0,
                        completedSimilarDays: 0,
                        rejectedSimilarDays: 0,
                        offeredOnlySimilarDays: 0
                    )
                }
            )
            return AffinityComputationResult(affinities: affinities, diagnostics: diagnostics)
        }

        let calendar = Calendar.current
        guard let todayDate = dayDate(from: context.dayKey, calendar: calendar) else {
            return AffinityComputationResult(affinities: [], diagnostics: SimilarDayAffinityDiagnostics(
                recordsScanned: history.count,
                recordsPassingThreshold: 0,
                overallConfidence: .none,
                fallbackToPhaseA: true,
                topMatchingDays: [],
                families: []
            ))
        }

        var familyTotals: [RecoveryMovementFamily: Double] = [:]
        var familySamples: [RecoveryMovementFamily: Int] = [:]
        var familyCompleted: [RecoveryMovementFamily: Int] = [:]
        var familyRejected: [RecoveryMovementFamily: Int] = [:]
        var familyOfferedOnly: [RecoveryMovementFamily: Int] = [:]
        var usableDayCount = 0
        var matchDiagnostics: [SimilarDayMatchDiagnostic] = []

        for record in history {
            guard let recordDate = dayDate(from: record.dayKey, calendar: calendar) else { continue }
            let daysAgo = max(0, calendar.dateComponents([.day], from: recordDate, to: todayDate).day ?? 0)
            guard daysAgo <= lookbackDays else { continue }

            let similarity = daySimilarity(record: record, context: context, strategy: strategy)
            let recency = recencyWeight(daysAgo: daysAgo)
            guard similarity >= similarityThreshold else { continue }

            usableDayCount += 1
            let weight = Double(similarity) / 100.0 * recency
            var daySignals: [String] = []

            for family in emptyFamilies {
                guard let outcome = record.movementOutcomes[family] else { continue }
                let signal = outcomeSignal(outcome, daysAgo: daysAgo)
                guard signal != 0 else { continue }
                familyTotals[family, default: 0] += weight * signal
                familySamples[family, default: 0] += 1
                if outcome.completed { familyCompleted[family, default: 0] += 1 }
                if outcome.explicitlyRejected { familyRejected[family, default: 0] += 1 }
                if outcome.offered && !outcome.applied && !outcome.completed && !outcome.explicitlyRejected {
                    familyOfferedOnly[family, default: 0] += 1
                }
                daySignals.append("\(family.rawValue):\(outcomeLabel(outcome))")
            }

            matchDiagnostics.append(
                SimilarDayMatchDiagnostic(
                    dayKey: record.dayKey,
                    similarityScore: similarity,
                    recencyWeight: recency,
                    strategy: record.strategy,
                    recoveryBand: record.recoveryBand,
                    outdoorSuitability: record.outdoorSuitability,
                    familySignals: daySignals
                )
            )
        }

        let confidence = overallConfidence(
            usableDayCount: usableDayCount,
            familyTotals: familyTotals
        )

        let affinities = emptyFamilies.map { family in
            let raw = min(positiveSaturationCap, max(-positiveSaturationCap, familyTotals[family, default: 0]))
            return RecoveryMovementFamilyAffinity(
                family: family,
                score: raw,
                sampleCount: familySamples[family, default: 0],
                confidence: confidence
            )
        }

        let familyDiagnostics = affinities.map { affinity in
            FamilyAffinityDiagnostic(
                family: affinity.family,
                sampleCount: affinity.sampleCount,
                rawAffinity: affinity.score,
                confidence: affinity.confidence,
                appliedBonus: bonus(for: affinity.family, affinities: affinities),
                completedSimilarDays: familyCompleted[affinity.family, default: 0],
                rejectedSimilarDays: familyRejected[affinity.family, default: 0],
                offeredOnlySimilarDays: familyOfferedOnly[affinity.family, default: 0]
            )
        }

        let fallback = confidence == .none || !affinities.contains { $0.sampleCount > 0 && $0.confidence != .none }
        let diagnostics = SimilarDayAffinityDiagnostics(
            recordsScanned: history.count,
            recordsPassingThreshold: usableDayCount,
            overallConfidence: confidence,
            fallbackToPhaseA: fallback,
            topMatchingDays: matchDiagnostics.sorted {
                if $0.similarityScore != $1.similarityScore { return $0.similarityScore > $1.similarityScore }
                return $0.recencyWeight > $1.recencyWeight
            },
            families: familyDiagnostics
        )

        return AffinityComputationResult(affinities: affinities, diagnostics: diagnostics)
    }

    private static func outcomeLabel(_ outcome: MovementFamilyOutcome) -> String {
        if outcome.explicitlyRejected { return "rejected" }
        if outcome.completed { return outcome.partialCompletion ? "partial" : "completed" }
        if outcome.applied { return "applied" }
        if outcome.selectedAtSettle { return "selected" }
        if outcome.offered { return "offered" }
        return "none"
    }

    static func bonus(
        for family: RecoveryMovementFamily,
        affinities: [RecoveryMovementFamilyAffinity]
    ) -> Int {
        guard let affinity = affinities.first(where: { $0.family == family }),
              affinity.confidence != .none else {
            return 0
        }

        let cap: Int
        switch affinity.confidence {
        case .none: return 0
        case .weak: cap = 3
        case .moderate: cap = 6
        case .strong: cap = maxBonus
        }

        guard affinity.sampleCount > 0 else { return 0 }

        let normalized = affinity.score / positiveSaturationCap
        let scaled = Int((normalized * Double(cap)).rounded())
        return min(cap, max(-cap, scaled))
    }

    static func rankedOptions(
        _ options: [RecoveryMovementProvider.LightOption],
        affinities: [RecoveryMovementFamilyAffinity]
    ) -> [RecoveryMovementProvider.LightOption] {
        guard affinities.contains(where: { $0.confidence != .none && $0.sampleCount > 0 }) else {
            return options
        }

        let scored = options.map { option -> (RecoveryMovementProvider.LightOption, Int) in
            let family = RecoveryMovementFamilyResolver.family(for: option)
            return (option, bonus(for: family, affinities: affinities))
        }

        let maxBonusValue = scored.map(\.1).max() ?? 0
        if maxBonusValue <= 0 {
            return options
        }

        let top = scored.filter { $0.1 == maxBonusValue }.map(\.0)
        return top.isEmpty ? options : top
    }

    // MARK: - Similarity

    static func daySimilarity(
        record: MorningAdjustmentDayRecord,
        context: DailyContext,
        strategy: DailyStrategy
    ) -> Int {
        var score = 0

        if record.strategy == strategy { score += 20 }
        if record.recoveryBand == context.recoveryBand { score += 15 }
        score += recoveryDistanceScore(record: record, context: context)
        if record.outdoorSuitability == context.outdoorSuitability { score += 12 }

        let todayPreviousLoad = PreviousDayLoadResolver.resolve(forDayKey: context.dayKey)
        if record.previousDayLoad == todayPreviousLoad, todayPreviousLoad != .unknown { score += 8 }
        if context.yesterdayHeavy == record.yesterdayHeavy { score += 4 }

        if record.stackedLoad == context.stackedLoad { score += 6 }
        if record.tomorrowDemand == context.tomorrowDemand { score += 4 }

        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: context.now)
        if record.isWeekend == (todayWeekday == 1 || todayWeekday == 7) { score += 3 }
        if record.weekday == todayWeekday { score += 2 }

        let todayBucket = ProposalTimeBucket.from(date: context.now, calendar: calendar)
        if record.proposalTimeBucket == todayBucket { score += 4 }

        if record.existingPlanSuitability == context.existingPlanMovementSuitability { score += 3 }

        return score
    }

    private static func recoveryDistanceScore(
        record: MorningAdjustmentDayRecord,
        context: DailyContext
    ) -> Int {
        let todayPercent = context.recoveryPercent ?? bandMidpoint(context.recoveryBand)
        let recordPercent = record.recoveryPercent ?? bandMidpoint(record.recoveryBand)
        let delta = abs(todayPercent - recordPercent)
        return max(0, 15 - min(15, delta / 4))
    }

    private static func bandMidpoint(_ band: ProposalRecoveryBandToken) -> Int {
        switch band {
        case .good: return 85
        case .moderate: return 65
        case .low: return 40
        case .unavailable: return 50
        }
    }

    private static func recencyWeight(daysAgo: Int) -> Double {
        max(0.2, 1.0 - (Double(daysAgo) / Double(lookbackDays)))
    }

    // MARK: - Outcome signals

    static func outcomeSignal(_ outcome: MovementFamilyOutcome, daysAgo: Int) -> Double {
        if outcome.explicitlyRejected {
            return decayed(-8, daysAgo: daysAgo, halfLife: rejectionHalfLifeDays)
        }
        if outcome.completed {
            let base: Double
            switch outcome.origin {
            case .morningAdjustment: base = 10
            case .historical: base = 8
            case .userPlanned: base = 7
            case .none: base = 8
            }
            if outcome.partialCompletion {
                return base * 0.5
            }
            return base
        }
        if outcome.applied { return 6 }
        if outcome.selectedAtSettle { return 2 }
        if outcome.offered { return 0.5 }
        return 0
    }

    private static func decayed(_ value: Double, daysAgo: Int, halfLife: Double) -> Double {
        guard daysAgo > 0 else { return value }
        let factor = pow(0.5, Double(daysAgo) / halfLife)
        return value * factor
    }

    private static func overallConfidence(
        usableDayCount: Int,
        familyTotals: [RecoveryMovementFamily: Double]
    ) -> SimilarDayAffinityConfidence {
        switch usableDayCount {
        case 0: return .none
        case 1...2: return .weak
        case 3...5: return .moderate
        default:
            if isConsistent(familyTotals) { return .strong }
            return .moderate
        }
    }

    private static func isConsistent(_ totals: [RecoveryMovementFamily: Double]) -> Bool {
        let ranked = totals.sorted { $0.value > $1.value }
        guard let top = ranked.first, top.value > 0 else { return false }
        let second = ranked.dropFirst().first?.value ?? 0
        if second <= 0 { return true }
        return top.value >= second * 2
    }

    private static func dayDate(from dayKey: String, calendar: Calendar) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)
    }
}
