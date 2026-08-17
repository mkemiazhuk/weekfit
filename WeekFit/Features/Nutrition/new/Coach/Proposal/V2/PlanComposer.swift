import Foundation

enum PlanComposer {

    static func compose(
        scored: [ScoredCandidate],
        context: DailyContext,
        strategy: DailyStrategy
    ) -> ComposedPlan {
        if strategy == .continueExistingPlan {
            let guidanceOnly = scored.filter { $0.candidate.kind == .guidanceOnly }
            return ComposedPlan(
                strategy: strategy,
                scoredCandidates: Array(guidanceOnly.prefix(2)),
                droppedCandidateIds: scored.filter { $0.candidate.kind != .guidanceOnly }.map(\.id),
                validationNotes: ["continue_existing_plan"]
            )
        }

        let ranked = CandidateScorer.rank(scored)
        var selected: [ScoredCandidate] = []
        var dropped: [String] = []
        var notes: [String] = []

        let maxItems: Int = {
            switch context.contextFreshness {
            case .low: return 2
            case .medium: return 4
            case .high:
                return context.todayOpen.isEmpty ? 6 : 4
            }
        }()

        let maxAdditions: Int = {
            switch context.generationMode {
            case .compose: return context.todayOpen.isEmpty ? 3 : 2
            case .optimize: return 1
            case .protect, .closed: return 0
            }
        }()

        var addedCreates = 0
        var seriousCreates = 0
        var movementCreates = 0
        var mealCreates = 0
        var occupiedMealSlots: Set<ProposalMealSlot> = []

        for item in ranked {
            if selected.count >= maxItems {
                dropped.append(item.id)
                continue
            }

            let kind = item.candidate.kind
            let isCreate = kind == .createPlannedActivity
                || kind == .createRecoveryWalk
                || kind == .createMealFromLibrary

            if ProposalRepetitionGuard.shouldSuppress(item.candidate, context: context) {
                dropped.append(item.id)
                notes.append("repeat_cooloff:\(item.id)")
                continue
            }

            if context.generationMode == .protect, isCreate, kind != .createMealFromLibrary {
                dropped.append(item.id)
                notes.append("protect_blocks_create:\(item.id)")
                continue
            }

            if isCreate && kind != .createMealFromLibrary {
                if addedCreates >= maxAdditions {
                    dropped.append(item.id)
                    continue
                }
            }

            if kind == .createMealFromLibrary {
                let slot = ProposalMealSlot.from(date: item.candidate.sortTime)
                if occupiedMealSlots.contains(slot) || mealCreates >= 2 {
                    dropped.append(item.id)
                    notes.append("one_meal_slot:\(item.id)")
                    continue
                }
            }

            if kind == .createPlannedActivity, isElevatedLoad(item.candidate) {
                if context.recoveryBand == .low
                    || strategy == .recover
                    || strategy == .protectTomorrow {
                    dropped.append(item.id)
                    notes.append("drop_elevated_for_recovery:\(item.id)")
                    continue
                }
            }

            if kind == .createPlannedActivity, isSerious(item.candidate) {
                if seriousCreates >= 1 {
                    dropped.append(item.id)
                    notes.append("one_serious_max:\(item.id)")
                    continue
                }
                if strategy == .recover || strategy == .protectTomorrow {
                    dropped.append(item.id)
                    continue
                }
            }

            if kind == .createRecoveryWalk {
                // Prefer habitual Friday yoga / stretching over a generic recovery Walk.
                if ranked.contains(where: { isHabitualLightRecovery($0.candidate) })
                    || selected.contains(where: { isHabitualLightRecovery($0.candidate) }) {
                    dropped.append(item.id)
                    notes.append("prefer_habitual_light_recovery:\(item.id)")
                    continue
                }
            }

            if kind == .createRecoveryWalk || isMovementCreate(item.candidate) {
                if movementCreates >= 1 {
                    dropped.append(item.id)
                    notes.append("one_movement_max:\(item.id)")
                    continue
                }
                if selected.contains(where: { isMovementCreate($0.candidate) || $0.candidate.kind == .createRecoveryWalk }) {
                    dropped.append(item.id)
                    continue
                }
            }

            // Prefer existing adjustments over speculative creates when both exist.
            if isCreate,
               kind != .createMealFromLibrary,
               !selected.filter({ isAdjustment($0.candidate.kind) }).isEmpty,
               strategy == .recover || strategy == .protectTomorrow,
               item.score < 70 {
                dropped.append(item.id)
                notes.append("prefer_existing_plan:\(item.id)")
                continue
            }

            selected.append(item)
            if isCreate && kind != .createMealFromLibrary {
                addedCreates += 1
            }
            if kind == .createMealFromLibrary {
                mealCreates += 1
                occupiedMealSlots.insert(ProposalMealSlot.from(date: item.candidate.sortTime))
            }
            if kind == .createPlannedActivity, isSerious(item.candidate) {
                seriousCreates += 1
            }
            if kind == .createRecoveryWalk || isMovementCreate(item.candidate) {
                movementCreates += 1
            }
        }

        // Keep guidance separately capped.
        let guidance = ranked.filter { $0.candidate.kind == .guidanceOnly }.prefix(2)
        for g in guidance where !selected.contains(where: { $0.id == g.id }) {
            if selected.count < maxItems + 2 {
                selected.append(g)
            }
        }

        selected.sort { $0.candidate.sortTime < $1.candidate.sortTime }

        return ComposedPlan(
            strategy: strategy,
            scoredCandidates: selected,
            droppedCandidateIds: dropped,
            validationNotes: notes
        )
    }

    private static func isAdjustment(_ kind: CoachChangeKind) -> Bool {
        kind == .modifyDuration || kind == .moveActivity || kind == .skipActivity
    }

    private static func isMovementCreate(_ candidate: ProposalCandidate) -> Bool {
        guard case .createPlannedActivity(let payload) = candidate.payload else { return false }
        let type = payload.activityType.lowercased()
        let title = payload.title.lowercased()
        return type.contains("walk") || title.contains("walk") || type == "recovery"
            || type.contains("stretch") || title.contains("stretch")
            || type.contains("breath") || title.contains("breath")
            || isHabitualLightRecovery(candidate)
    }

    /// Yoga / stretching / breathing habits — preferred over generic Walk on recover days.
    private static func isHabitualLightRecovery(_ candidate: ProposalCandidate) -> Bool {
        guard candidate.source == .historicalActivity,
              case .createPlannedActivity(let payload) = candidate.payload else { return false }
        let snapshot = CoachPlannedActivitySnapshot(
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
        switch CoachActivityClassifier.type(for: snapshot) {
        case .yoga, .stretching, .breathing:
            return true
        default:
            let title = payload.title.lowercased()
            return title.contains("yoga") || title.contains("stretch") || title.contains("mobility")
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
}
