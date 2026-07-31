import Foundation
import SwiftData
import XCTest
@testable import WeekFit

@MainActor
final class CoachPlanApplyServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private let dayKey = "2026-07-29"

    override func setUpWithError() throws {
        try super.setUpWithError()
        container = try ModelContainer(
            for: PlannedActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
        resetStores()
    }

    override func tearDownWithError() throws {
        resetStores()
        context = nil
        container = nil
        try super.tearDownWithError()
    }

    private func resetStores() {
        MorningProposalStore.resetAllForTests()
        CoachAdjustmentProvenanceStore.resetAllForTests()
        CoachDecisionHistoryStore.resetAllForTests()
        CoachApplyJournalStore.resetAllForTests()
        CoachProvenanceLookupCache.resetAllForTests()
        UserDefaults.standard.removeObject(forKey: MorningProposalPresenter.acknowledgmentShownKeyPrefix + dayKey)
    }

    func testApplySingleModifyDuration() throws {
        let activity = makeWorkout(id: "run-1", minutes: 75)
        context.insert(activity)
        try context.save()

        let proposal = makeProposal(changes: [
            modifyChange(id: "c1", activityId: activity.id, from: 75, to: 55, selected: true)
        ])
        MorningProposalStore.upsert(proposal)

        let summary = try apply(proposal: proposal, activities: [activity])
        XCTAssertEqual(summary.appliedChangeIds, ["c1"])
        XCTAssertTrue(summary.failedChangeIds.isEmpty)
        XCTAssertEqual(activity.durationMinutes, 55)
        XCTAssertEqual(MorningProposalStore.proposal(for: dayKey)?.status, .applied)

        let provenance = CoachAdjustmentProvenanceStore.adjustment(forActivityId: activity.id)
        XCTAssertEqual(provenance?.kind, .modifyDuration)
        XCTAssertEqual(provenance?.originalSnapshot?.durationMinutes, 75)
        XCTAssertEqual(provenance?.appliedSnapshot.durationMinutes, 55)
    }

    func testApplyMultipleSelectedChanges() throws {
        let run = makeWorkout(id: "run-1", minutes: 75)
        context.insert(run)
        try context.save()

        let proposal = makeProposal(changes: [
            modifyChange(id: "c1", activityId: run.id, from: 75, to: 55, selected: true),
            createWalkChange(id: "c2", selected: true),
            guidanceChange(id: "c3", selected: true)
        ])
        MorningProposalStore.upsert(proposal)

        let summary = try apply(proposal: proposal, activities: [run])
        XCTAssertEqual(Set(summary.appliedChangeIds), Set(["c1", "c2", "c3"]))
        XCTAssertEqual(run.durationMinutes, 55)
        XCTAssertEqual(summary.createdActivityIds.count, 1)

        let history = CoachDecisionHistoryStore.entries(forDayKey: dayKey)
        XCTAssertEqual(history.filter(\.accepted).count, 3)
    }

    func testUnselectedChangesAreNotApplied() throws {
        let run = makeWorkout(id: "run-1", minutes: 75)
        let ride = makeWorkout(id: "ride-1", minutes: 60, hour: 19)
        context.insert(run)
        context.insert(ride)
        try context.save()

        let proposal = makeProposal(changes: [
            modifyChange(id: "c1", activityId: run.id, from: 75, to: 55, selected: true),
            modifyChange(id: "c2", activityId: ride.id, from: 60, to: 40, selected: false)
        ])
        MorningProposalStore.upsert(proposal)

        _ = try apply(proposal: proposal, activities: [run, ride])
        XCTAssertEqual(run.durationMinutes, 55)
        XCTAssertEqual(ride.durationMinutes, 60)

        let history = CoachDecisionHistoryStore.entries(forDayKey: dayKey)
        XCTAssertEqual(history.filter { !$0.accepted }.map(\.changeId), ["c2"])
        XCTAssertNil(CoachAdjustmentProvenanceStore.adjustment(forActivityId: ride.id))
    }

    func testValidChangesOnlyWhenOneTargetMissing() throws {
        let run = makeWorkout(id: "run-1", minutes: 75)
        context.insert(run)
        try context.save()

        let proposal = makeProposal(changes: [
            modifyChange(id: "c1", activityId: run.id, from: 75, to: 55, selected: true),
            modifyChange(id: "c2", activityId: "missing", from: 60, to: 40, selected: true)
        ])
        MorningProposalStore.upsert(proposal)

        let summary = try apply(proposal: proposal, activities: [run])
        XCTAssertEqual(summary.appliedChangeIds, ["c1"])
        XCTAssertEqual(summary.failedChangeIds, ["c2"])
        XCTAssertEqual(run.durationMinutes, 55)
        XCTAssertEqual(MorningProposalStore.proposal(for: dayKey)?.status, .applied)
    }

    func testCompletedTargetIsSkippedAsUnavailable() throws {
        let run = makeWorkout(id: "run-1", minutes: 75, completed: true)
        context.insert(run)
        try context.save()

        let proposal = makeProposal(changes: [
            modifyChange(id: "c1", activityId: run.id, from: 75, to: 55, selected: true)
        ])
        MorningProposalStore.upsert(proposal)

        XCTAssertThrowsError(try apply(proposal: proposal, activities: [run])) { error in
            XCTAssertEqual(error as? CoachPlanApplyService.ApplyError, .noValidMutations)
        }
        XCTAssertEqual(MorningProposalStore.proposal(for: dayKey)?.status, .failed)
        XCTAssertEqual(run.durationMinutes, 75)
    }

    func testStaleProposalRejectsApply() throws {
        let run = makeWorkout(id: "run-1", minutes: 75)
        context.insert(run)
        try context.save()

        let proposal = MorningPlanProposal(
            id: "proposal-1",
            dayKey: dayKey,
            generatedAt: date(7, 0),
            status: .proposalReady,
            fingerprint: ProposalInputFingerprint(
                dayKey: dayKey,
                planSignature: "old",
                tomorrowPlanSignature: "",
                recoveryBand: .low,
                sleepPresence: .present,
                scenarioKey: "lowRecoveryPrep",
                yesterdayHeavy: true,
                schemaVersion: 1
            ),
            changes: [
                modifyChange(id: "c1", activityId: run.id, from: 75, to: 55, selected: true)
            ],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            schemaVersion: 1
        )
        MorningProposalStore.upsert(proposal)

        let live = ProposalInputFingerprint(
            dayKey: dayKey,
            planSignature: "new",
            tomorrowPlanSignature: "",
            recoveryBand: .low,
            sleepPresence: .present,
            scenarioKey: "lowRecoveryPrep",
            yesterdayHeavy: true,
            schemaVersion: 1
        )

        XCTAssertThrowsError(
            try CoachPlanApplyService.applySelected(
                proposalId: proposal.id,
                dayKey: dayKey,
                liveFingerprint: live,
                activities: [run],
                modelContext: context,
                dependencies: .init(
                    activityRemindersEnabled: true,
                    completionCheckInsEnabled: true,
                    planViewModel: PlanViewModel()
                )
            )
        ) { error in
            XCTAssertEqual(error as? CoachPlanApplyService.ApplyError, .staleFingerprint)
        }
        XCTAssertEqual(MorningProposalStore.proposal(for: dayKey)?.status, .stale)
        XCTAssertEqual(run.durationMinutes, 75)
    }

    func testDuplicateApplyIsIdempotent() throws {
        let run = makeWorkout(id: "run-1", minutes: 75)
        context.insert(run)
        try context.save()

        let proposal = makeProposal(changes: [
            modifyChange(id: "c1", activityId: run.id, from: 75, to: 55, selected: true),
            createWalkChange(id: "c2", selected: true)
        ])
        MorningProposalStore.upsert(proposal)

        let first = try apply(proposal: proposal, activities: [run])
        let walksAfterFirst = try fetchWorkouts().filter { $0.title.localizedCaseInsensitiveContains("walk") }
        XCTAssertEqual(walksAfterFirst.count, 1)

        let historyCount = CoachDecisionHistoryStore.entries(forDayKey: dayKey).count
        let provenanceCount = CoachAdjustmentProvenanceStore.adjustments(forDayKey: dayKey).count

        let second = try apply(proposal: proposal, activities: try fetchWorkouts())
        XCTAssertEqual(second.outcomes, [.skippedAlreadyMatched])

        let walksAfterSecond = try fetchWorkouts().filter { $0.title.localizedCaseInsensitiveContains("walk") }
        XCTAssertEqual(walksAfterSecond.count, 1)
        XCTAssertEqual(CoachDecisionHistoryStore.entries(forDayKey: dayKey).count, historyCount)
        XCTAssertEqual(CoachAdjustmentProvenanceStore.adjustments(forDayKey: dayKey).count, provenanceCount)
        XCTAssertEqual(first.createdActivityIds.count, 1)
    }

    func testApplyAfterRelaunchUsesPersistedProposal() throws {
        let run = makeWorkout(id: "run-1", minutes: 75)
        context.insert(run)
        try context.save()

        let proposal = makeProposal(changes: [
            modifyChange(id: "c1", activityId: run.id, from: 75, to: 55, selected: true)
        ])
        MorningProposalStore.upsert(proposal)

        // Simulate relaunch by reading back from store only.
        let reloaded = MorningProposalStore.proposal(for: dayKey)
        XCTAssertNotNil(reloaded)
        let summary = try apply(proposal: reloaded!, activities: [run])
        XCTAssertEqual(summary.appliedChangeIds, ["c1"])
        XCTAssertEqual(MorningProposalStore.proposal(for: dayKey)?.status, .applied)
    }

    func testJournalClearedAfterSuccessfulApply() throws {
        let run = makeWorkout(id: "run-1", minutes: 75)
        context.insert(run)
        try context.save()

        let proposal = makeProposal(changes: [
            modifyChange(id: "c1", activityId: run.id, from: 75, to: 55, selected: true)
        ])
        MorningProposalStore.upsert(proposal)
        _ = try apply(proposal: proposal, activities: [run])
        XCTAssertNil(CoachApplyJournalStore.current())
    }

    func testManualPlanChangeDuringReviewMarksStale() {
        let proposal = makeProposal(changes: [
            modifyChange(id: "c1", activityId: "run-1", from: 75, to: 55, selected: true)
        ])
        MorningProposalStore.upsert(proposal)

        let live = ProposalInputFingerprint(
            dayKey: dayKey,
            planSignature: "changed-during-review",
            tomorrowPlanSignature: "",
            recoveryBand: .low,
            sleepPresence: .present,
            scenarioKey: "lowRecoveryPrep",
            yesterdayHeavy: true,
            schemaVersion: 1
        )
        MorningProposalService.markStaleIfNeeded(dayKey: dayKey, liveFingerprint: live)
        XCTAssertEqual(MorningProposalStore.proposal(for: dayKey)?.status, .stale)
    }

    func testProvenanceLookupCacheAvoidsMissesAfterInvalidate() {
        let adjustment = AppliedCoachAdjustment(
            id: "adj-1",
            dayKey: dayKey,
            proposalId: "p1",
            changeId: "c1",
            kind: .modifyDuration,
            activityId: "run-1",
            reasonCode: .lowRecoveryLoadProtection,
            originalSnapshot: nil,
            appliedSnapshot: CoachActivitySnapshot(
                activityId: "run-1",
                date: date(18, 0),
                type: "workout",
                title: "Run",
                durationMinutes: 55,
                isCompleted: false,
                isSkipped: false,
                source: "planner"
            ),
            appliedAt: Date(),
            userManuallyEditedAfterApply: false,
            terminalOutcome: nil
        )
        CoachAdjustmentProvenanceStore.upsert(adjustment)
        XCTAssertEqual(
            CoachProvenanceLookupCache.adjustment(forActivityId: "run-1", dayKey: dayKey)?.id,
            "adj-1"
        )
        CoachProvenanceLookupCache.invalidate()
        XCTAssertEqual(
            CoachProvenanceLookupCache.adjustment(forActivityId: "run-1", dayKey: dayKey)?.id,
            "adj-1"
        )
    }

    func testDayKeyTimezoneStableForSameCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 2 * 3600)!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 7, day: 29, hour: 0, minute: 30))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 7, day: 29, hour: 23, minute: 30))!
        XCTAssertEqual(
            ProposalInputFingerprintBuilder.dayKey(for: morning, calendar: calendar),
            ProposalInputFingerprintBuilder.dayKey(for: evening, calendar: calendar)
        )
    }

    func testMidnightExpiryLeavesAppliedIntact() {
        let appliedProposal = MorningPlanProposal(
            id: "old-applied",
            dayKey: "2026-07-28",
            generatedAt: Date(),
            status: .applied,
            fingerprint: fingerprint(signature: "x"),
            changes: [],
            appliedAt: Date(),
            dismissedAt: nil,
            lastErrorCode: nil,
            schemaVersion: 1
        )
        MorningProposalStore.upsert(appliedProposal)
        MorningProposalStore.expireBefore(dayKey: dayKey)
        XCTAssertEqual(MorningProposalStore.proposal(for: "2026-07-28")?.status, .applied)

        let pendingProposal = MorningPlanProposal(
            id: "old-pending",
            dayKey: "2026-07-27",
            generatedAt: Date(),
            status: .proposalReady,
            fingerprint: fingerprint(signature: "y"),
            changes: [],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            schemaVersion: 1
        )
        MorningProposalStore.upsert(pendingProposal)
        MorningProposalStore.expireBefore(dayKey: dayKey)
        XCTAssertEqual(MorningProposalStore.proposal(for: "2026-07-27")?.status, .expired)
        XCTAssertEqual(MorningProposalStore.proposal(for: "2026-07-28")?.status, .applied)
    }

    func testAcknowledgmentSummaryUsesAcceptedOnly() {
        let base = makeProposal(changes: [
            modifyChange(id: "c1", activityId: "run-1", from: 75, to: 55, selected: true),
            createWalkChange(id: "c2", selected: false)
        ])
        let applied = MorningPlanProposal(
            id: base.id,
            dayKey: dayKey,
            generatedAt: base.generatedAt,
            status: .applied,
            fingerprint: base.fingerprint,
            changes: base.changes,
            appliedAt: Date(),
            dismissedAt: nil,
            lastErrorCode: nil,
            schemaVersion: 1
        )
        MorningProposalStore.upsert(applied)
        CoachDecisionHistoryStore.append([
            CoachDecisionHistoryEntry(
                id: "h1",
                dayKey: dayKey,
                proposalId: applied.id,
                changeId: "c1",
                kind: .modifyDuration,
                reasonCode: .lowRecoveryLoadProtection,
                accepted: true,
                applyOutcome: .applied,
                recordedAt: Date()
            ),
            CoachDecisionHistoryEntry(
                id: "h2",
                dayKey: dayKey,
                proposalId: applied.id,
                changeId: "c2",
                kind: .createRecoveryWalk,
                reasonCode: .recoveryWalkSupport,
                accepted: false,
                applyOutcome: nil,
                recordedAt: Date()
            )
        ])

        let summary = CoachAppliedAcknowledgmentCopy.summary(proposal: applied, dayKey: dayKey)
        XCTAssertEqual(summary.acceptedKinds, [.modifyDuration])
        XCTAssertFalse(summary.guidanceOnly)

        let rec = CoachAppliedAcknowledgmentCopy.recommendation(for: summary)
        XCTAssertTrue(rec.english.lowercased().contains("shortened"))
        XCTAssertFalse(rec.english.lowercased().contains("recovery movement"))
    }

    // MARK: - Helpers

    private func apply(
        proposal: MorningPlanProposal,
        activities: [PlannedActivity]
    ) throws -> CoachApplySummary {
        try CoachPlanApplyService.applySelected(
            proposalId: proposal.id,
            dayKey: dayKey,
            liveFingerprint: proposal.fingerprint,
            activities: activities,
            modelContext: context,
            dependencies: .init(
                activityRemindersEnabled: true,
                completionCheckInsEnabled: true,
                planViewModel: PlanViewModel()
            )
        )
    }

    private func makeWorkout(
        id: String,
        minutes: Int,
        hour: Int = 18,
        completed: Bool = false
    ) -> PlannedActivity {
        let activity = PlannedActivityBuilder.workout(
            title: id == "ride-1" ? "Ride" : "Evening Run",
            at: date(hour, 0),
            durationMinutes: minutes,
            completed: completed
        )
        activity.id = id
        return activity
    }

    private func makeProposal(changes: [CoachProposedChange]) -> MorningPlanProposal {
        MorningPlanProposal(
            id: "proposal-1",
            dayKey: dayKey,
            generatedAt: date(7, 0),
            status: .proposalReady,
            fingerprint: fingerprint(signature: PlannedActivityRefreshSignature.make(from: [])),
            changes: changes,
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            schemaVersion: 1
        )
    }

    private func fingerprint(signature: String) -> ProposalInputFingerprint {
        ProposalInputFingerprint(
            dayKey: dayKey,
            planSignature: signature,
            tomorrowPlanSignature: "",
            recoveryBand: .low,
            sleepPresence: .present,
            scenarioKey: "lowRecoveryPrep",
            yesterdayHeavy: true,
            schemaVersion: 1
        )
    }

    private func modifyChange(
        id: String,
        activityId: String,
        from: Int,
        to: Int,
        selected: Bool
    ) -> CoachProposedChange {
        CoachProposedChange(
            id: id,
            kind: .modifyDuration,
            reasonCode: .lowRecoveryLoadProtection,
            payload: .modifyDuration(
                ModifyDurationPayload(
                    activityId: activityId,
                    originalDurationMinutes: from,
                    proposedDurationMinutes: to
                )
            ),
            defaultSelected: selected,
            isSelected: selected,
            sortTime: date(18, 0),
            evidenceScenarioKey: CoachScenarioKey.lowRecoveryPrep.rawValue
        )
    }

    private func createWalkChange(id: String, selected: Bool) -> CoachProposedChange {
        CoachProposedChange(
            id: id,
            kind: .createRecoveryWalk,
            reasonCode: .recoveryWalkSupport,
            payload: .createRecoveryWalk(
                CreateRecoveryWalkPayload(
                    proposedDate: date(12, 0),
                    durationMinutes: 25,
                    title: "Walk",
                    activityType: "recovery"
                )
            ),
            defaultSelected: selected,
            isSelected: selected,
            sortTime: date(12, 0),
            evidenceScenarioKey: nil
        )
    }

    private func guidanceChange(id: String, selected: Bool) -> CoachProposedChange {
        CoachProposedChange(
            id: id,
            kind: .guidanceOnly,
            reasonCode: .insufficientConfidence,
            payload: .guidanceOnly(
                GuidanceOnlyPayload(guidanceCode: .easeIntoFirstEffort, relatedActivityId: nil)
            ),
            defaultSelected: selected,
            isSelected: selected,
            sortTime: date(7, 30),
            evidenceScenarioKey: nil
        )
    }

    private func date(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: 29, hour: hour, minute: minute))!
    }

    private func fetchWorkouts() throws -> [PlannedActivity] {
        try context.fetch(FetchDescriptor<PlannedActivity>())
    }
}
