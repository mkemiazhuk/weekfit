import Foundation
import SwiftData
import SwiftUI
import WeekFitPlanner

@MainActor
enum CoachPlanApplyService {

    struct Dependencies {
        var activityRemindersEnabled: Bool
        var completionCheckInsEnabled: Bool
        /// Optional host PlanViewModel for move; created on-demand on the MainActor when nil.
        var planViewModel: PlanViewModel?

        static var `default`: Dependencies {
            Dependencies(
                activityRemindersEnabled: true,
                completionCheckInsEnabled: true,
                planViewModel: nil
            )
        }
    }

    enum ApplyError: Error, Equatable {
        case proposalMissing
        case invalidStatus(CoachProposalStatus)
        case staleFingerprint
        case noValidMutations
        case saveFailed
    }

    static func applySelected(
        proposalId: String,
        dayKey: String,
        liveFingerprint: ProposalInputFingerprint,
        activities: [PlannedActivity],
        modelContext: ModelContext,
        dependencies: Dependencies = .default
    ) throws -> CoachApplySummary {
        guard var proposal = MorningProposalStore.proposal(for: dayKey),
              proposal.id == proposalId else {
            throw ApplyError.proposalMissing
        }

        // Idempotent success path
        if proposal.status == .applied {
            return CoachApplySummary(
                proposalId: proposal.id,
                appliedChangeIds: proposal.changes.filter(\.isSelected).map(\.id),
                failedChangeIds: [],
                outcomes: [.skippedAlreadyMatched],
                createdActivityIds: []
            )
        }

        guard proposal.status == .proposalReady
            || proposal.status == .reviewing
            || proposal.status == .failed else {
            throw ApplyError.invalidStatus(proposal.status)
        }

        if proposal.fingerprint.planStaleDifference(from: liveFingerprint) {
            proposal.status = .stale
            MorningProposalStore.upsert(proposal)
            MorningProposalAnalytics.proposalStale()
            throw ApplyError.staleFingerprint
        }

        let selected = proposal.changes.filter(\.isSelected)
        var journal = CoachApplyJournal(
            proposalId: proposal.id,
            dayKey: dayKey,
            startedAt: Date(),
            finishedAt: nil,
            selectedChangeIds: selected.map(\.id),
            itemOutcomes: [:],
            phase: "validating"
        )
        CoachApplyJournalStore.save(journal)

        proposal.status = .applying
        MorningProposalStore.upsert(proposal)

        var activitiesById = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
        var outcomes: [String: CoachApplyItemOutcome] = [:]
        var appliedIds: [String] = []
        var failedIds: [String] = []
        var createdIds: [String] = []
        var provenance: [AppliedCoachAdjustment] = []
        var history: [CoachDecisionHistoryEntry] = []

        let ordered = selected.sorted(by: applySort)

        journal.phase = "mutating"
        CoachApplyJournalStore.save(journal)

        for change in ordered {
            let outcome: CoachApplyItemOutcome
            switch change.kind {
            case .skipActivity:
                outcome = applySkip(
                    change: change,
                    activitiesById: &activitiesById,
                    modelContext: modelContext,
                    proposal: proposal,
                    provenance: &provenance
                )
            case .modifyDuration:
                outcome = applyModifyDuration(
                    change: change,
                    activitiesById: &activitiesById,
                    modelContext: modelContext,
                    proposal: proposal,
                    dependencies: dependencies,
                    provenance: &provenance
                )
            case .moveActivity:
                outcome = applyMove(
                    change: change,
                    activitiesById: &activitiesById,
                    allActivities: activities,
                    modelContext: modelContext,
                    proposal: proposal,
                    dependencies: dependencies,
                    provenance: &provenance
                )
            case .createRecoveryWalk:
                let result = applyCreateWalk(
                    change: change,
                    activities: activities + Array(activitiesById.values),
                    modelContext: modelContext,
                    proposal: proposal,
                    dependencies: dependencies,
                    provenance: &provenance
                )
                outcome = result.outcome
                if let id = result.createdId {
                    createdIds.append(id)
                    if let created = try? PlannedActivityPersistenceService.fetchActivity(
                        id: id,
                        in: modelContext
                    ) {
                        activitiesById[id] = created
                    }
                }
            case .createPlannedActivity:
                let result = applyCreatePlannedActivity(
                    change: change,
                    activities: activities + Array(activitiesById.values),
                    modelContext: modelContext,
                    proposal: proposal,
                    dependencies: dependencies,
                    provenance: &provenance
                )
                outcome = result.outcome
                if let id = result.createdId {
                    createdIds.append(id)
                    if let created = try? PlannedActivityPersistenceService.fetchActivity(
                        id: id,
                        in: modelContext
                    ) {
                        activitiesById[id] = created
                    }
                }
            case .createMealFromLibrary:
                let result = applyCreateMeal(
                    change: change,
                    activities: activities + Array(activitiesById.values),
                    modelContext: modelContext,
                    proposal: proposal,
                    dependencies: dependencies,
                    provenance: &provenance
                )
                outcome = result.outcome
                if let id = result.createdId {
                    createdIds.append(id)
                    if let created = try? PlannedActivityPersistenceService.fetchActivity(
                        id: id,
                        in: modelContext
                    ) {
                        activitiesById[id] = created
                    }
                }
            case .guidanceOnly:
                outcome = .ignoredGuidanceOnly
            }

            outcomes[change.id] = outcome
            journal.itemOutcomes[change.id] = outcome
            CoachApplyJournalStore.save(journal)

            switch outcome {
            case .applied, .skippedAlreadyMatched, .ignoredGuidanceOnly:
                appliedIds.append(change.id)
            case .failedTargetUnavailable, .failedConflictUnresolved, .failedValidation:
                failedIds.append(change.id)
            }

            history.append(
                CoachDecisionHistoryEntry(
                    id: UUID().uuidString,
                    dayKey: dayKey,
                    proposalId: proposal.id,
                    changeId: change.id,
                    kind: change.kind,
                    reasonCode: change.reasonCode,
                    accepted: true,
                    applyOutcome: outcome,
                    recordedAt: Date()
                )
            )
        }

        // Record rejected (deselected) choices
        for change in proposal.changes where !change.isSelected {
            history.append(
                CoachDecisionHistoryEntry(
                    id: UUID().uuidString,
                    dayKey: dayKey,
                    proposalId: proposal.id,
                    changeId: change.id,
                    kind: change.kind,
                    reasonCode: change.reasonCode,
                    accepted: false,
                    applyOutcome: nil,
                    recordedAt: Date()
                )
            )
        }

        let selectedMutations = selected.filter { $0.kind != .guidanceOnly }
        let successfulMutations = selectedMutations.filter { change in
            guard let outcome = outcomes[change.id] else { return false }
            return outcome == .applied || outcome == .skippedAlreadyMatched
        }

        if !selectedMutations.isEmpty && successfulMutations.isEmpty {
            proposal.status = .failed
            proposal.lastErrorCode = "no_valid_mutations"
            MorningProposalStore.upsert(proposal)
            journal.phase = "failed"
            journal.finishedAt = Date()
            CoachApplyJournalStore.save(journal)
            CoachDecisionHistoryStore.append(history)
            throw ApplyError.noValidMutations
        }

        journal.phase = "persistingProvenance"
        CoachApplyJournalStore.save(journal)

        for item in provenance {
            CoachAdjustmentProvenanceStore.upsert(item)
        }
        CoachDecisionHistoryStore.append(history)

        proposal.status = .applied
        proposal.appliedAt = Date()
        proposal.lastErrorCode = nil
        MorningProposalStore.upsert(proposal)
        MorningProposalNotificationService.shared.cancel(dayKey: proposal.dayKey)
        MorningProposalNotificationService.shared.markHandled(dayKey: proposal.dayKey)

        journal.phase = "done"
        journal.finishedAt = Date()
        CoachApplyJournalStore.save(journal)
        CoachApplyJournalStore.clear()

        return CoachApplySummary(
            proposalId: proposal.id,
            appliedChangeIds: appliedIds,
            failedChangeIds: failedIds,
            outcomes: ordered.compactMap { outcomes[$0.id] },
            createdActivityIds: createdIds
        )
    }

    // MARK: - Kind handlers

    private static func applySkip(
        change: CoachProposedChange,
        activitiesById: inout [String: PlannedActivity],
        modelContext: ModelContext,
        proposal: MorningPlanProposal,
        provenance: inout [AppliedCoachAdjustment]
    ) -> CoachApplyItemOutcome {
        guard case .skipActivity(let payload) = change.payload,
              let activity = activitiesById[payload.activityId] else {
            return .failedTargetUnavailable
        }
        if activity.isCompleted {
            return .failedTargetUnavailable
        }
        if activity.isSkipped {
            return .skippedAlreadyMatched
        }
        let before = snapshot(activity)
        do {
            try PlannedActivityNotificationConfirmationService.markSkipped(
                activity,
                modelContext: modelContext
            )
        } catch {
            return .failedValidation
        }
        let after = snapshot(activity)
        provenance.append(
            adjustment(
                proposal: proposal,
                change: change,
                activityId: activity.id,
                before: before,
                after: after
            )
        )
        return .applied
    }

    private static func applyModifyDuration(
        change: CoachProposedChange,
        activitiesById: inout [String: PlannedActivity],
        modelContext: ModelContext,
        proposal: MorningPlanProposal,
        dependencies: Dependencies,
        provenance: inout [AppliedCoachAdjustment]
    ) -> CoachApplyItemOutcome {
        guard case .modifyDuration(let payload) = change.payload,
              let activity = activitiesById[payload.activityId] else {
            return .failedTargetUnavailable
        }
        if activity.isCompleted || activity.isSkipped {
            return .failedTargetUnavailable
        }
        if activity.terminalState(now: Date()) == .active {
            return .failedTargetUnavailable
        }
        if activity.durationMinutes == payload.proposedDurationMinutes {
            return .skippedAlreadyMatched
        }

        let before = snapshot(activity)
        let previous = activity.durationMinutes
        activity.durationMinutes = payload.proposedDurationMinutes
        do {
            try modelContext.save()
            ActivityNotificationService.shared.cancelNotifications(for: activity)
            ActivityNotificationService.shared.syncNotifications(
                for: activity,
                activityRemindersEnabled: dependencies.activityRemindersEnabled,
                completionCheckInsEnabled: dependencies.completionCheckInsEnabled
            )
        } catch {
            activity.durationMinutes = previous
            return .failedValidation
        }

        provenance.append(
            adjustment(
                proposal: proposal,
                change: change,
                activityId: activity.id,
                before: before,
                after: snapshot(activity)
            )
        )
        return .applied
    }

    private static func applyMove(
        change: CoachProposedChange,
        activitiesById: inout [String: PlannedActivity],
        allActivities: [PlannedActivity],
        modelContext: ModelContext,
        proposal: MorningPlanProposal,
        dependencies: Dependencies,
        provenance: inout [AppliedCoachAdjustment]
    ) -> CoachApplyItemOutcome {
        guard case .moveActivity(let payload) = change.payload,
              let activity = activitiesById[payload.activityId] else {
            return .failedTargetUnavailable
        }
        if activity.isCompleted || activity.isSkipped {
            return .failedTargetUnavailable
        }
        if activity.terminalState(now: Date()) == .active {
            return .failedTargetUnavailable
        }

        let before = snapshot(activity)
        let planVM = dependencies.planViewModel ?? PlanViewModel()
        let previousDate = activity.date
        planVM.moveActivity(
            activity,
            to: payload.proposedDate,
            activities: allActivities,
            modelContext: modelContext,
            activityRemindersEnabled: dependencies.activityRemindersEnabled,
            completionCheckInsEnabled: dependencies.completionCheckInsEnabled
        )

        // moveActivity may abort on conflict without throwing
        if abs(activity.date.timeIntervalSince(payload.proposedDate)) > 60 {
            // Conflict / no-op
            if abs(activity.date.timeIntervalSince(previousDate)) < 1 {
                return .failedConflictUnresolved
            }
        }

        provenance.append(
            adjustment(
                proposal: proposal,
                change: change,
                activityId: activity.id,
                before: before,
                after: snapshot(activity)
            )
        )
        return .applied
    }

    private static func applyCreateWalk(
        change: CoachProposedChange,
        activities: [PlannedActivity],
        modelContext: ModelContext,
        proposal: MorningPlanProposal,
        dependencies: Dependencies,
        provenance: inout [AppliedCoachAdjustment]
    ) -> (outcome: CoachApplyItemOutcome, createdId: String?) {
        guard case .createRecoveryWalk(let payload) = change.payload else {
            return (.failedValidation, nil)
        }

        // Idempotency: existing walk near same time
        let duplicate = activities.first { activity in
            !activity.isSkipped
                && CoachActivityClassifier.type(for: CoachPlannedActivitySnapshot(from: activity)) == .walk
                && abs(activity.date.timeIntervalSince(payload.proposedDate)) < 15 * 60
                && activity.title.localizedCaseInsensitiveContains("walk")
        }
        if let duplicate {
            return (.skippedAlreadyMatched, duplicate.id)
        }

        var slot = payload.proposedDate
        for _ in 0..<4 {
            let conflict = activities.contains { activity in
                guard !activity.isSkipped else { return false }
                return abs(activity.date.timeIntervalSince(slot)) < 30 * 60
            }
            if !conflict { break }
            slot = slot.addingTimeInterval(15 * 60)
        }

        let icon = WeekFitActivityIconResolver.preferredIcon(
            storedIcon: "figure.walk",
            title: payload.title,
            type: payload.activityType,
            imageName: "recovery-walk"
        )
        let recoveryColors = PlannerType.recovery.colorComponents

        // Match catalog Walk under Recovery (title/type/colors/image).
        let activity = PlannedActivity(
            date: slot,
            type: payload.activityType,
            title: payload.title,
            durationMinutes: payload.durationMinutes,
            icon: icon,
            imageName: "recovery-walk",
            colorRed: recoveryColors.red,
            colorGreen: recoveryColors.green,
            colorBlue: recoveryColors.blue,
            source: "planner"
        )

        modelContext.insert(activity)
        do {
            try modelContext.save()
            ActivityNotificationService.shared.syncNotifications(
                for: activity,
                activityRemindersEnabled: dependencies.activityRemindersEnabled,
                completionCheckInsEnabled: dependencies.completionCheckInsEnabled
            )
        } catch {
            modelContext.delete(activity)
            return (.failedValidation, nil)
        }

        provenance.append(
            adjustment(
                proposal: proposal,
                change: change,
                activityId: activity.id,
                before: nil,
                after: snapshot(activity)
            )
        )
        return (.applied, activity.id)
    }

    private static func applyCreatePlannedActivity(
        change: CoachProposedChange,
        activities: [PlannedActivity],
        modelContext: ModelContext,
        proposal: MorningPlanProposal,
        dependencies: Dependencies,
        provenance: inout [AppliedCoachAdjustment]
    ) -> (outcome: CoachApplyItemOutcome, createdId: String?) {
        guard case .createPlannedActivity(let payload) = change.payload else {
            return (.failedValidation, nil)
        }

        let duplicate = activities.first { activity in
            !activity.isSkipped
                && activity.title.localizedCaseInsensitiveCompare(payload.title) == .orderedSame
                && abs(activity.date.timeIntervalSince(payload.proposedDate)) < 20 * 60
        }
        if let duplicate {
            return (.skippedAlreadyMatched, duplicate.id)
        }

        var slot = payload.proposedDate
        for _ in 0..<4 {
            let conflict = activities.contains { activity in
                guard !activity.isSkipped else { return false }
                return abs(activity.date.timeIntervalSince(slot)) < 25 * 60
            }
            if !conflict { break }
            slot = slot.addingTimeInterval(15 * 60)
        }

        let icon = WeekFitActivityIconResolver.preferredIcon(
            storedIcon: payload.icon.isEmpty ? "figure.mixed.cardio" : payload.icon,
            title: payload.title,
            type: payload.activityType,
            imageName: payload.imageName
        )

        let activity = PlannedActivity(
            date: slot,
            type: payload.activityType,
            title: payload.title,
            durationMinutes: payload.durationMinutes,
            icon: icon,
            imageName: payload.imageName,
            colorRed: payload.colorRed,
            colorGreen: payload.colorGreen,
            colorBlue: payload.colorBlue,
            source: "planner"
        )

        modelContext.insert(activity)
        do {
            try modelContext.save()
            ActivityNotificationService.shared.syncNotifications(
                for: activity,
                activityRemindersEnabled: dependencies.activityRemindersEnabled,
                completionCheckInsEnabled: dependencies.completionCheckInsEnabled
            )
        } catch {
            modelContext.delete(activity)
            return (.failedValidation, nil)
        }

        provenance.append(
            adjustment(
                proposal: proposal,
                change: change,
                activityId: activity.id,
                before: nil,
                after: snapshot(activity)
            )
        )
        return (.applied, activity.id)
    }

    private static func applyCreateMeal(
        change: CoachProposedChange,
        activities: [PlannedActivity],
        modelContext: ModelContext,
        proposal: MorningPlanProposal,
        dependencies: Dependencies,
        provenance: inout [AppliedCoachAdjustment]
    ) -> (outcome: CoachApplyItemOutcome, createdId: String?) {
        guard case .createMealFromLibrary(let payload) = change.payload else {
            return (.failedValidation, nil)
        }

        let duplicate = activities.first { activity in
            !activity.isSkipped
                && activity.type.lowercased() == "meal"
                && activity.title.localizedCaseInsensitiveCompare(payload.title) == .orderedSame
                && abs(activity.date.timeIntervalSince(payload.proposedDate)) < 30 * 60
        }
        if let duplicate {
            return (.skippedAlreadyMatched, duplicate.id)
        }

        var slot = payload.proposedDate
        for _ in 0..<4 {
            let conflict = activities.contains { activity in
                guard !activity.isSkipped else { return false }
                return abs(activity.date.timeIntervalSince(slot)) < 20 * 60
            }
            if !conflict { break }
            slot = slot.addingTimeInterval(15 * 60)
        }

        let mealColors = PlannerType.meal.colorComponents
        let activity = PlannedActivity(
            date: slot,
            type: "meal",
            title: payload.title,
            durationMinutes: max(10, payload.durationMinutes),
            icon: "fork.knife",
            imageName: payload.imageName,
            colorRed: mealColors.red,
            colorGreen: mealColors.green,
            colorBlue: mealColors.blue,
            calories: payload.calories,
            protein: payload.protein,
            carbs: payload.carbs,
            fats: payload.fats,
            fiber: payload.fiber,
            source: "planner"
        )

        modelContext.insert(activity)
        do {
            try modelContext.save()
            ActivityNotificationService.shared.syncNotifications(
                for: activity,
                activityRemindersEnabled: dependencies.activityRemindersEnabled,
                completionCheckInsEnabled: dependencies.completionCheckInsEnabled
            )
        } catch {
            modelContext.delete(activity)
            return (.failedValidation, nil)
        }

        provenance.append(
            adjustment(
                proposal: proposal,
                change: change,
                activityId: activity.id,
                before: nil,
                after: snapshot(activity)
            )
        )
        return (.applied, activity.id)
    }

    // MARK: - Helpers

    private static func applySort(_ lhs: CoachProposedChange, _ rhs: CoachProposedChange) -> Bool {
        applyRank(lhs.kind) < applyRank(rhs.kind)
    }

    private static func applyRank(_ kind: CoachChangeKind) -> Int {
        switch kind {
        case .skipActivity: return 0
        case .modifyDuration: return 1
        case .moveActivity: return 2
        case .createRecoveryWalk: return 3
        case .createPlannedActivity: return 4
        case .createMealFromLibrary: return 5
        case .guidanceOnly: return 6
        }
    }

    private static func snapshot(_ activity: PlannedActivity) -> CoachActivitySnapshot {
        CoachActivitySnapshot(
            activityId: activity.id,
            date: activity.date,
            type: activity.type,
            title: activity.title,
            durationMinutes: activity.durationMinutes,
            isCompleted: activity.isCompleted,
            isSkipped: activity.isSkipped,
            source: activity.source
        )
    }

    private static func adjustment(
        proposal: MorningPlanProposal,
        change: CoachProposedChange,
        activityId: String,
        before: CoachActivitySnapshot?,
        after: CoachActivitySnapshot
    ) -> AppliedCoachAdjustment {
        AppliedCoachAdjustment(
            id: UUID().uuidString,
            dayKey: proposal.dayKey,
            proposalId: proposal.id,
            changeId: change.id,
            kind: change.kind,
            activityId: activityId,
            reasonCode: change.reasonCode,
            originalSnapshot: before,
            appliedSnapshot: after,
            appliedAt: Date(),
            userManuallyEditedAfterApply: false,
            terminalOutcome: after.isSkipped ? "skipped" : nil
        )
    }
}
