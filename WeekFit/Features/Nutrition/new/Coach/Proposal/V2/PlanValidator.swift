import Foundation

enum PlanValidator {

    static func validate(
        composed: ComposedPlan,
        context: DailyContext
    ) -> ValidatedPlan {
        var kept = composed.scoredCandidates
        var notes = composed.validationNotes

        // Duplicate Walk
        let walks = kept.filter {
            $0.candidate.kind == .createRecoveryWalk || isWalkCreate($0.candidate)
        }
        if walks.count > 1 {
            let drop = walks.dropFirst().map(\.id)
            kept.removeAll { drop.contains($0.id) }
            notes.append("drop_duplicate_walk")
        }
        if context.hasExistingMovement || context.completedWalkToday {
            let before = kept.count
            kept.removeAll { $0.candidate.kind == .createRecoveryWalk || isWalkCreate($0.candidate) }
            if kept.count != before { notes.append("drop_walk_existing_movement") }
        }

        // Two serious creates
        let seriousCreates = kept.filter { isSeriousCreate($0.candidate) }
        if seriousCreates.count > 1 {
            let keepId = seriousCreates.first?.id
            kept.removeAll { isSeriousCreate($0.candidate) && $0.id != keepId }
            notes.append("drop_extra_serious")
        }

        // protectTomorrow / recover / low recovery / heavy yesterday + elevated create
        if composed.strategy == .protectTomorrow
            || composed.strategy == .recover
            || context.recoveryBand == .low
            || context.yesterdayHeavy {
            let before = kept.count
            kept.removeAll { isElevatedCreate($0.candidate) || isSeriousCreate($0.candidate) }
            if kept.count != before { notes.append("drop_elevated_for_strategy") }
        }

        // Invented sessions never exceed an hour.
        kept.removeAll { item in
            guard case .createPlannedActivity(let payload) = item.candidate.payload else { return false }
            let overCap = payload.durationMinutes > ProposalInventedSessionPolicy.hardCapMinutes
            if overCap { notes.append("drop_over_hour:\(item.id)") }
            return overCap
        }

        // One meal per slot
        var seenMealSlots: Set<ProposalMealSlot> = []
        kept = kept.filter { item in
            guard item.candidate.kind == .createMealFromLibrary else { return true }
            let slot = ProposalMealSlot.from(date: item.candidate.sortTime)
            if seenMealSlots.contains(slot) {
                notes.append("drop_duplicate_meal_slot:\(item.id)")
                return false
            }
            seenMealSlots.insert(slot)
            return true
        }

        // Temporal overlaps among creates
        kept = resolveTimeConflicts(kept, notes: &notes)

        // Meal without supporting strategy / workout coherence
        kept = validateMeals(kept, strategy: composed.strategy, notes: &notes)

        // Weak evidence mass drop for low confidence
        if context.contextFreshness == .low {
            let mutating = kept.filter { $0.candidate.kind != .guidanceOnly }
            if mutating.count > 2 {
                let survivors = Array(CandidateScorer.rank(mutating).prefix(2))
                let survivorIds = Set(survivors.map(\.id))
                kept = kept.filter { $0.candidate.kind == .guidanceOnly || survivorIds.contains($0.id) }
                notes.append("trim_low_confidence")
            }
        }

        // Too many changes
        let mutatingCount = kept.filter { $0.candidate.kind != .guidanceOnly }.count
        if mutatingCount > 6 {
            let ranked = CandidateScorer.rank(kept.filter { $0.candidate.kind != .guidanceOnly })
            let keepIds = Set(ranked.prefix(6).map(\.id))
            kept = kept.filter { $0.candidate.kind == .guidanceOnly || keepIds.contains($0.id) }
            notes.append("cap_mutations")
        }

        let actionable = kept.filter { $0.candidate.kind != .guidanceOnly }
        if actionable.isEmpty, composed.strategy != .continueExistingPlan {
            // Guidance-only is fine for continue; otherwise abort overlay-worthy proposal.
            if composed.strategy == .maintain || composed.strategy == .train {
                return ValidatedPlan(
                    strategy: .continueExistingPlan,
                    candidates: Array(kept.filter { $0.candidate.kind == .guidanceOnly }.prefix(1)),
                    aborted: kept.filter { $0.candidate.kind == .guidanceOnly }.isEmpty,
                    abortReason: kept.isEmpty ? "empty_actionable_set" : nil,
                    notes: notes + ["no_actionable_mutations"]
                )
            }
        }

        if kept.isEmpty {
            return ValidatedPlan(
                strategy: composed.strategy,
                candidates: [],
                aborted: true,
                abortReason: "empty_after_validation",
                notes: notes
            )
        }

        return ValidatedPlan(
            strategy: composed.strategy,
            candidates: kept.sorted { $0.candidate.sortTime < $1.candidate.sortTime },
            aborted: false,
            abortReason: nil,
            notes: notes
        )
    }

    private static func resolveTimeConflicts(
        _ candidates: [ScoredCandidate],
        notes: inout [String]
    ) -> [ScoredCandidate] {
        var result: [ScoredCandidate] = []
        for item in CandidateScorer.rank(candidates) {
            // Existing-plan adjustments keep their native times; only creates/moves collide.
            guard createsOrMovesTime(item.candidate), let time = proposedTime(item.candidate) else {
                result.append(item)
                continue
            }
            let conflict = result.contains { existing in
                guard createsOrMovesTime(existing.candidate),
                      let existingTime = proposedTime(existing.candidate) else { return false }
                return abs(existingTime.timeIntervalSince(time)) < 25 * 60
            }
            if conflict {
                notes.append("drop_time_conflict:\(item.id)")
                continue
            }
            result.append(item)
        }
        return result
    }

    private static func createsOrMovesTime(_ candidate: ProposalCandidate) -> Bool {
        switch candidate.kind {
        case .createPlannedActivity, .createRecoveryWalk, .createMealFromLibrary, .moveActivity:
            return true
        case .modifyDuration, .skipActivity, .guidanceOnly:
            return false
        }
    }

    private static func validateMeals(
        _ candidates: [ScoredCandidate],
        strategy: DailyStrategy,
        notes: inout [String]
    ) -> [ScoredCandidate] {
        let hasWorkout = candidates.contains {
            $0.candidate.kind == .createPlannedActivity || $0.candidate.kind == .createRecoveryWalk
        } || strategy == .train

        return candidates.filter { item in
            guard item.candidate.kind == .createMealFromLibrary else { return true }
            // Avoid meals that only fill slots when strategy is protectTomorrow without workout support.
            if strategy == .protectTomorrow, !hasWorkout, item.score < 60 {
                notes.append("drop_weak_meal:\(item.id)")
                return false
            }
            return true
        }
    }

    private static func proposedTime(_ candidate: ProposalCandidate) -> Date? {
        switch candidate.payload {
        case .modifyDuration, .skipActivity, .guidanceOnly:
            return candidate.sortTime
        case .moveActivity(let p):
            return p.proposedDate
        case .createRecoveryWalk(let p):
            return p.proposedDate
        case .createPlannedActivity(let p):
            return p.proposedDate
        case .createMealFromLibrary(let p):
            return p.proposedDate
        }
    }

    private static func isWalkCreate(_ candidate: ProposalCandidate) -> Bool {
        if candidate.kind == .createRecoveryWalk { return true }
        if case .createPlannedActivity(let p) = candidate.payload {
            return p.title.lowercased().contains("walk") || p.activityType.lowercased().contains("walk")
        }
        return false
    }

    private static func isSeriousCreate(_ candidate: ProposalCandidate) -> Bool {
        guard case .createPlannedActivity(let payload) = candidate.payload else { return false }
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

    private static func isElevatedCreate(_ candidate: ProposalCandidate) -> Bool {
        guard case .createPlannedActivity(let payload) = candidate.payload else { return false }
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
}
