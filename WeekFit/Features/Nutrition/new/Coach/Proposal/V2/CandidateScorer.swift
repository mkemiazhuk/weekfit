import Foundation

enum CandidateScorer {

    static let inclusionThreshold = 45
    static let defaultSelectionScoreThreshold = 65
    static let defaultSelectionConfidenceThreshold = 0.6

    static func score(
        _ candidate: ProposalCandidate,
        context: DailyContext,
        strategy: DailyStrategy
    ) -> ScoredCandidate? {
        // Hard rejects
        if candidate.physiologicalFit == .incompatible { return nil }
        if !candidate.compatibleStrategies.contains(strategy) { return nil }
        if candidate.conflicts.contains(.staleTarget) { return nil }
        if candidate.conflicts.contains(.missingLibraryMeal) { return nil }
        if candidate.conflicts.contains(.duplicateMovement) { return nil }
        if candidate.kind == .createPlannedActivity,
           (strategy == .recover
            || strategy == .protectTomorrow
            || context.recoveryBand == .low
            || context.yesterdayHeavy),
           isElevatedLoad(candidate) {
            return nil
        }
        if candidate.kind == .createPlannedActivity,
           strategy == .recover || strategy == .protectTomorrow,
           isSerious(candidate) {
            return nil
        }

        let phys: Int = {
            switch candidate.physiologicalFit {
            case .strong: return 22
            case .moderate: return 14
            case .weak: return 6
            case .incompatible: return 0
            }
        }()

        let strategyFit: Int = candidate.compatibleStrategies.contains(strategy) ? 18 : 0

        // Safety-oriented existing-plan adjustments and recovery movement get a floor so
        // they are not dropped by missing historical components.
        let safetyFloor: Int = {
            switch candidate.kind {
            case .modifyDuration, .moveActivity, .skipActivity:
                return 20
            case .createRecoveryWalk:
                return 16
            case .createMealFromLibrary:
                // Meals lack historical components; without a floor they often miss inclusion.
                return 12
            case .createPlannedActivity:
                // Habitual light recovery (yoga/stretch) needs room to outrank generic Walk.
                if candidate.source == .historicalActivity,
                   strategy == .recover || strategy == .maintain {
                    return 10
                }
                return 0
            case .guidanceOnly:
                return 12
            }
        }()

        let historical: Int = {
            guard candidate.source == .historicalActivity else { return 0 }
            return Int((candidate.confidence * 14).rounded())
        }()

        let behavioral: Int = {
            if candidate.kind == .createRecoveryWalk, context.stronglyRejectsWalk {
                return 0
            }
            return min(10, Int((candidate.confidence * 10).rounded()))
        }()

        let tomorrow: Int = {
            if strategy == .protectTomorrow {
                switch candidate.kind {
                case .modifyDuration, .moveActivity, .skipActivity, .guidanceOnly, .createMealFromLibrary:
                    return 8
                case .createPlannedActivity, .createRecoveryWalk:
                    return isSerious(candidate) ? 0 : 4
                }
            }
            return 0
        }()

        let usualTime: Int = {
            guard candidate.source == .historicalActivity else { return 0 }
            return 6
        }()

        let rejection: Int = {
            if candidate.kind == .createRecoveryWalk {
                return -min(12, context.walkRejectPenalty)
            }
            return 0
        }()

        // Soft dismiss/empty-Apply drag applies only to optional creates — never safety dial-backs.
        let softNegative: Int = {
            switch candidate.kind {
            case .createPlannedActivity, .createRecoveryWalk, .createMealFromLibrary:
                return -min(6, context.softNegativePenalty)
            case .modifyDuration, .moveActivity, .skipActivity, .guidanceOnly:
                return 0
            }
        }()

        let confidencePenalty: Int = {
            let base: Int
            switch context.contextFreshness {
            case .high: base = 0
            case .medium: base = -8
            case .low: base = -15
            }
            return base + softNegative
        }()

        let conflict: Int = candidate.conflicts.isEmpty ? 0 : -10
        let fatigue: Int = {
            var penalty = 0
            if context.yesterdayHeavy, isSerious(candidate) {
                penalty -= 8
            }
            if context.preferAvoidHardLoadOnLowRecovery,
               candidate.kind == .createPlannedActivity,
               isElevatedLoad(candidate) || isSerious(candidate) {
                penalty -= 6
            }
            return max(penalty, -12)
        }()

        let breakdown = CandidateScoreBreakdown(
            physiologicalFit: phys + safetyFloor,
            strategyFit: strategyFit,
            historicalSuccess: historical,
            behavioralLikelihood: behavioral,
            tomorrowProtection: tomorrow,
            usualTimeFit: usualTime,
            rejectionPenalty: rejection,
            confidencePenalty: confidencePenalty,
            conflictPenalty: conflict,
            fatiguePenalty: fatigue
        )

        // Guidance always survives scoring for assembly (overlay suppressed if no mutations).
        if candidate.kind == .guidanceOnly {
            return ScoredCandidate(candidate: candidate, breakdown: breakdown)
        }

        if breakdown.total < inclusionThreshold {
            return nil
        }

        return ScoredCandidate(candidate: candidate, breakdown: breakdown)
    }

    static func rank(_ scored: [ScoredCandidate]) -> [ScoredCandidate] {
        scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.breakdown.physiologicalFit != rhs.breakdown.physiologicalFit {
                return lhs.breakdown.physiologicalFit > rhs.breakdown.physiologicalFit
            }
            let lb = burdenRank(lhs.candidate.burden)
            let rb = burdenRank(rhs.candidate.burden)
            if lb != rb { return lb < rb }
            if lhs.breakdown.historicalSuccess != rhs.breakdown.historicalSuccess {
                return lhs.breakdown.historicalSuccess > rhs.breakdown.historicalSuccess
            }
            return lhs.candidate.id < rhs.candidate.id
        }
    }

    static func shouldDefaultSelect(
        _ scored: ScoredCandidate,
        context: DailyContext,
        strategy: DailyStrategy
    ) -> Bool {
        let candidate = scored.candidate
        if candidate.defaultSelectionEligibility == .notSelectable { return false }
        if candidate.kind == .guidanceOnly { return false }

        switch candidate.kind {
        case .modifyDuration, .moveActivity:
            return true
        case .skipActivity:
            return candidate.defaultSelectionEligibility == .eligible
                && scored.score >= defaultSelectionScoreThreshold
                && candidate.confidence >= defaultSelectionConfidenceThreshold
        case .createRecoveryWalk:
            return candidate.defaultSelectionEligibility == .eligible
                && scored.score >= defaultSelectionScoreThreshold
                && candidate.confidence >= defaultSelectionConfidenceThreshold
                && !context.stronglyRejectsWalk
        case .createPlannedActivity:
            // High-evidence habitual creates on train days start selected (user can deselect).
            if context.preferAvoidHardLoadOnLowRecovery,
               isElevatedLoad(candidate) || isSerious(candidate) {
                return false
            }
            return candidate.defaultSelectionEligibility == .eligible
                && strategy == .train
                && context.contextFreshness == .high
                && scored.score >= defaultSelectionScoreThreshold
                && candidate.confidence >= defaultSelectionConfidenceThreshold
        case .createMealFromLibrary:
            return candidate.defaultSelectionEligibility == .eligible
                && context.contextFreshness == .high
                && scored.score >= defaultSelectionScoreThreshold
                && strategy != .continueExistingPlan
        case .guidanceOnly:
            return false
        }
    }

    private static func isSerious(_ candidate: ProposalCandidate) -> Bool {
        if case .createPlannedActivity(let payload) = candidate.payload {
            return CoachActivityClassifier.isSeriousTraining(
                CoachPlannedActivitySnapshot(
                    id: candidate.id,
                    date: payload.proposedDate,
                    type: payload.activityType,
                    title: payload.title,
                    durationMinutes: payload.durationMinutes,
                    icon: payload.icon,
                    imageName: payload.imageName,
                    isCompleted: false,
                    isSkipped: false,
                    source: "history"
                )
            )
        }
        return false
    }

    private static func isElevatedLoad(_ candidate: ProposalCandidate) -> Bool {
        if case .createPlannedActivity(let payload) = candidate.payload {
            return CoachActivityClassifier.isElevatedTrainingLoad(
                CoachPlannedActivitySnapshot(
                    id: candidate.id,
                    date: payload.proposedDate,
                    type: payload.activityType,
                    title: payload.title,
                    durationMinutes: payload.durationMinutes,
                    icon: payload.icon,
                    imageName: payload.imageName,
                    isCompleted: false,
                    isSkipped: false,
                    source: "history"
                )
            )
        }
        return false
    }

    private static func burdenRank(_ burden: CandidateBurden) -> Int {
        switch burden {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
}
