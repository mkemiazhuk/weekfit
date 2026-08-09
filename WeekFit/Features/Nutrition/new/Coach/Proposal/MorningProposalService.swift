import Foundation
import WeekFitPlanner

/// Orchestrates gate → generate → persist for the current day.
@MainActor
enum MorningProposalService {

    struct EvaluateContext {
        let now: Date
        let dayRolloverCompleted: Bool
        let healthRefreshCompleted: Bool
        let healthRefreshTimedOut: Bool
        let isHealthAccessGranted: Bool
        let sleepHours: Double
        let readiness: CoachDayReadiness
        let scenarioKey: CoachScenarioKey?
        let tomorrowDemand: CoachTomorrowDemand
        let stackedLoad: ProposalStackedLoadToken
        let yesterdayHeavy: Bool
        let completedWalkToday: Bool
        let todayActivities: [CoachPlannedActivitySnapshot]
        let tomorrowActivities: [CoachPlannedActivitySnapshot]
        let isMorningWindow: Bool
        let hasCompletedPlannedItemToday: Bool
        let recentDayTemplates: [SimilarDayTemplate]
        let mealLibrary: [ProposalMealCandidate]
        let observationContextRevision: String
        let mealLibraryRevision: String
        let behavioralGeneration: Int
        let walkRejectPenalty: Int
        let stronglyRejectsWalk: Bool
        let weatherRiskToken: ProposalWeatherRiskToken
    }

    @discardableResult
    static func evaluateAndPersist(context: EvaluateContext) -> MorningPlanProposal? {
        let calendar = Calendar.current
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: context.now, calendar: calendar)
        MorningProposalStore.expireBefore(dayKey: dayKey)
        CoachAdjustmentProvenanceStore.purgeOlderThan(referenceDate: context.now, calendar: calendar)
        CoachDecisionHistoryStore.purgeOlderThan(referenceDate: context.now, calendar: calendar)
        ProposalOfferHistoryStore.purgeOlderThan(referenceDate: context.now, calendar: calendar)

        var existing = MorningProposalStore.proposal(for: dayKey)
        // Non-destructive expire of incompatible drafts (schema < current).
        if let draft = existing,
           draft.schemaVersion < MorningPlanProposal.currentSchemaVersion,
           draft.status != .applied {
            draftExpireIncompatible(draft)
            existing = MorningProposalStore.proposal(for: dayKey)
        }

        let openCount = context.todayActivities.filter {
            !$0.isCompleted && !$0.isSkipped && CoachActivityClassifier.type(for: $0) != .none
        }.count
        let generationMode = MorningProposalGenerationModeResolver.resolve(
            openCount: openCount,
            hasCompletedOrPartialToday: context.hasCompletedPlannedItemToday,
            isMorningWindow: context.isMorningWindow
        )

        let gateInput = MorningProposalGateInput(
            now: context.now,
            dayRolloverCompleted: context.dayRolloverCompleted,
            healthRefreshCompleted: context.healthRefreshCompleted,
            healthRefreshTimedOut: context.healthRefreshTimedOut,
            isHealthAccessGranted: context.isHealthAccessGranted,
            sleepHours: context.sleepHours,
            recoveryDataAvailable: context.readiness.recoveryDataAvailable,
            todayPlanLoaded: true,
            tomorrowPlanLoaded: true,
            yesterdayContextLoaded: true,
            isMorningWindow: context.isMorningWindow,
            hasCompletedPlannedItemToday: context.hasCompletedPlannedItemToday,
            existingStatus: existing?.status
        )

        switch MorningProposalGate.decide(input: gateInput) {
        case .gatheringData:
            let gatheringStartedAt = existing?.status == .gatheringData
                ? existing?.generatedAt ?? context.now
                : context.now
            let gathering = MorningPlanProposal(
                id: existing?.id ?? UUID().uuidString,
                dayKey: dayKey,
                generatedAt: gatheringStartedAt,
                status: .gatheringData,
                fingerprint: existing?.fingerprint ?? emptyFingerprint(dayKey: dayKey),
                changes: existing?.changes ?? [],
                appliedAt: nil,
                dismissedAt: nil,
                lastErrorCode: nil,
                schemaVersion: MorningPlanProposal.currentSchemaVersion
            )
            MorningProposalStore.upsert(gathering)
            return gathering

        case .unavailable(let reason):
            let unavailable = MorningPlanProposal(
                id: existing?.id ?? UUID().uuidString,
                dayKey: dayKey,
                generatedAt: context.now,
                status: .unavailable,
                fingerprint: existing?.fingerprint ?? emptyFingerprint(dayKey: dayKey),
                changes: [],
                appliedAt: nil,
                dismissedAt: nil,
                lastErrorCode: reason,
                schemaVersion: MorningPlanProposal.currentSchemaVersion
            )
            MorningProposalStore.upsert(unavailable)
            MorningProposalAnalytics.proposalUnavailable(reason: reason)
            return unavailable

        case .keepExisting(let status):
            guard var proposal = existing else { return nil }
            if proposal.status != status {
                proposal.status = status
                if status == .expired {
                    proposal.lastErrorCode = "expired"
                }
                MorningProposalStore.upsert(proposal)
            }
            return proposal

        case .allowGeneration:
            break
        }

        if generationMode == .closed {
            // Preserve applied/reviewing applied history; otherwise mark unavailable closed.
            if let existing, [.applied, .applying].contains(existing.status) {
                return existing
            }
        }

        let recoveryBand = ProposalInputFingerprintBuilder.recoveryBand(from: context.readiness)
        let sleepPresence = MorningProposalGate.sleepPresence(from: gateInput)
        let physiologyRevision = ProposalInputFingerprintBuilder.physiologyRevision(
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresence,
            yesterdayHeavy: context.yesterdayHeavy,
            stackedLoad: context.stackedLoad
        )
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: dayKey,
            todaySnapshots: context.todayActivities,
            tomorrowSnapshots: context.tomorrowActivities,
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresence,
            scenarioKey: context.scenarioKey?.rawValue ?? "none",
            yesterdayHeavy: context.yesterdayHeavy,
            observationContextRevision: context.observationContextRevision,
            behavioralGeneration: context.behavioralGeneration,
            stackedLoad: context.stackedLoad,
            generationMode: generationMode,
            mealLibraryRevision: context.mealLibraryRevision,
            physiologyContextRevision: physiologyRevision,
            weatherRiskToken: context.weatherRiskToken
        )

        if let existing,
           [.proposalReady, .reviewing, .failed, .stale].contains(existing.status),
           existing.schemaVersion >= MorningPlanProposal.currentSchemaVersion,
           !existing.fingerprint.materialDifference(from: fingerprint),
           existing.status != .stale {
            return existing
        }

        let canMutate = recoveryBand != .unavailable
            && generationMode != .closed

        let engineInput = MorningProposalEngineInput(
            now: context.now,
            dayKey: dayKey,
            fingerprint: fingerprint,
            scenarioKey: context.scenarioKey,
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresence,
            yesterdayHeavy: context.yesterdayHeavy,
            tomorrowDemand: context.tomorrowDemand,
            stackedLoad: context.stackedLoad,
            generationMode: generationMode,
            todayActivities: context.todayActivities,
            tomorrowActivities: context.tomorrowActivities,
            completedWalkToday: context.completedWalkToday,
            canMutate: canMutate,
            recentDayTemplates: context.recentDayTemplates,
            mealLibrary: context.mealLibrary,
            walkRejectPenalty: context.walkRejectPenalty,
            stronglyRejectsWalk: context.stronglyRejectsWalk,
            weatherRiskToken: context.weatherRiskToken
        )

        let proposal = MorningProposalEngine.generate(input: engineInput)
        MorningProposalStore.upsert(proposal)
        switch proposal.status {
        case .proposalReady:
            ProposalOfferHistoryStore.recordOffers(
                dayKey: dayKey,
                changes: proposal.changes,
                now: context.now
            )
            let mutating = proposal.changes.filter { $0.kind != CoachChangeKind.guidanceOnly }.count
            let guidance = proposal.changes.filter { $0.kind == CoachChangeKind.guidanceOnly }.count
            MorningProposalAnalytics.proposalGenerated(
                changeCount: mutating,
                guidanceCount: guidance,
                strategy: proposal.strategy,
                generationMode: generationMode,
                contextConfidence: proposal.contextConfidence
            )
        case .noChangesNeeded:
            MorningProposalAnalytics.proposalNoChanges()
        default:
            break
        }
        return proposal
    }

    static func markStaleIfNeeded(
        dayKey: String,
        liveFingerprint: ProposalInputFingerprint
    ) {
        guard var proposal = MorningProposalStore.proposal(for: dayKey) else { return }
        guard [.proposalReady, .reviewing].contains(proposal.status) else { return }
        // Never invalidate an in-review draft solely because preference counters moved;
        // plan/physiology/meal/day changes still stale correctly via planStaleDifference.
        guard proposal.fingerprint.planStaleDifference(from: liveFingerprint)
            || proposal.schemaVersion < MorningPlanProposal.currentSchemaVersion else { return }
        proposal.status = .stale
        MorningProposalStore.upsert(proposal)
        MorningProposalAnalytics.proposalStale()
    }

    static func dismiss(dayKey: String) {
        MorningProposalStore.update(dayKey) { proposal in
            proposal.status = .dismissed
            proposal.dismissedAt = Date()
        }
        ProposalBehavioralPreferences.recordSoftDismiss()
        MorningProposalAnalytics.proposalDismissed()
        MorningProposalNotificationService.shared.cancel(dayKey: dayKey)
        MorningProposalNotificationService.shared.markHandled(dayKey: dayKey)
    }

    static func setSelection(dayKey: String, changeId: String, isSelected: Bool) {
        guard let proposal = MorningProposalStore.proposal(for: dayKey),
              let change = proposal.changes.first(where: { $0.id == changeId }) else {
            return
        }
        // Guidance is never Apply-selectable.
        if change.kind == .guidanceOnly {
            return
        }

        MorningProposalStore.update(dayKey) { proposal in
            guard let index = proposal.changes.firstIndex(where: { $0.id == changeId }) else { return }
            let wasSelected = proposal.changes[index].isSelected
            proposal.changes[index].isSelected = isSelected
            if proposal.status == .proposalReady {
                proposal.status = .reviewing
            }

            if wasSelected && !isSelected {
                ProposalBehavioralPreferences.recordDeselect(
                    kind: proposal.changes[index].kind,
                    reason: proposal.changes[index].reasonCode
                )
            }
            if !wasSelected && isSelected && proposal.changes[index].kind == .createRecoveryWalk {
                ProposalBehavioralPreferences.recordWalkAccept()
            }
        }
    }

    private static func draftExpireIncompatible(_ proposal: MorningPlanProposal) {
        // Preserve applied history / provenance; only drop incompatible unapplied drafts.
        guard proposal.status != .applied, proposal.status != .applying else { return }
        MorningProposalStore.remove(dayKey: proposal.dayKey)
    }

    private static func emptyFingerprint(dayKey: String) -> ProposalInputFingerprint {
        ProposalInputFingerprint(
            dayKey: dayKey,
            planSignature: "",
            tomorrowPlanSignature: "",
            recoveryBand: .unavailable,
            sleepPresence: .unavailable,
            scenarioKey: "none",
            yesterdayHeavy: false,
            schemaVersion: ProposalInputFingerprint.currentSchemaVersion
        )
    }
}
