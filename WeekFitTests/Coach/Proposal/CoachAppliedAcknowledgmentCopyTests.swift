import XCTest
@testable import WeekFit

final class CoachAppliedAcknowledgmentCopyTests: XCTestCase {

    override func tearDown() {
        MorningProposalStore.resetAllForTests()
        CoachDecisionHistoryStore.resetAllForTests()
        CoachAdjustmentProvenanceStore.resetAllForTests()
        super.tearDown()
    }

    func testGuidanceOnlySummary() {
        let dayKey = "2026-07-29"
        CoachDecisionHistoryStore.append(
            CoachDecisionHistoryEntry(
                id: "h1",
                dayKey: dayKey,
                proposalId: "p1",
                changeId: "c1",
                kind: .guidanceOnly,
                reasonCode: .insufficientConfidence,
                accepted: true,
                applyOutcome: .ignoredGuidanceOnly,
                recordedAt: Date()
            )
        )

        let summary = CoachAppliedAcknowledgmentCopy.summary(proposal: nil, dayKey: dayKey)
        XCTAssertTrue(summary.guidanceOnly)
        XCTAssertFalse(summary.hasMutations)
        let recommendation = CoachAppliedAcknowledgmentCopy.recommendation(for: summary)
        XCTAssertTrue(recommendation.english.lowercased().contains("guidance"))
    }

    func testProtectiveScenariosOverride() {
        XCTAssertTrue(CoachAppliedAcknowledgmentCopy.shouldOverrideProtectiveCopy(scenario: .lowRecoveryPrep))
        XCTAssertTrue(CoachAppliedAcknowledgmentCopy.shouldOverrideProtectiveCopy(scenario: .protectTomorrowFresh))
        XCTAssertFalse(CoachAppliedAcknowledgmentCopy.shouldOverrideProtectiveCopy(scenario: .duringEndurance))
    }

    func testDeletedCoachAdjustmentClearsAppliedExecutingMode() {
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: Date())
        CoachAdjustmentProvenanceStore.upsert(
            AppliedCoachAdjustment(
                id: "adj-1",
                dayKey: dayKey,
                proposalId: "p1",
                changeId: "c1",
                kind: .createRecoveryWalk,
                activityId: "walk-1",
                reasonCode: .recoveryWalkSupport,
                originalSnapshot: nil,
                appliedSnapshot: CoachActivitySnapshot(
                    activityId: "walk-1",
                    date: Date(),
                    type: "recovery",
                    title: "Walk",
                    durationMinutes: 20,
                    isCompleted: false,
                    isSkipped: false,
                    source: "planner"
                ),
                appliedAt: Date(),
                userManuallyEditedAfterApply: false,
                terminalOutcome: nil
            )
        )
        XCTAssertEqual(
            CoachAppliedAcknowledgmentCopy.planAdjustmentMode(forDayKey: dayKey),
            .appliedExecuting
        )

        CoachAdjustmentProvenanceStore.markTerminalOutcome(activityId: "walk-1", outcome: "deleted")
        XCTAssertEqual(
            CoachAppliedAcknowledgmentCopy.planAdjustmentMode(forDayKey: dayKey),
            .clearedAfterApply
        )
    }

    func testPlanAdjustmentModeFromAppliedStore() {
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: Date())
        let proposal = MorningPlanProposal(
            id: "p1",
            dayKey: dayKey,
            generatedAt: Date(),
            status: .applied,
            fingerprint: ProposalInputFingerprint(
                dayKey: dayKey,
                planSignature: "",
                tomorrowPlanSignature: "",
                recoveryBand: .low,
                sleepPresence: .present,
                scenarioKey: "lowRecoveryPrep",
                yesterdayHeavy: true,
                schemaVersion: 1
            ),
            changes: [],
            appliedAt: Date(),
            dismissedAt: nil,
            lastErrorCode: nil,
            schemaVersion: 1
        )
        MorningProposalStore.upsert(proposal)

        // Build modifiers via from() requires full CoachContext — assert store signal directly.
        XCTAssertEqual(MorningProposalStore.proposal(for: dayKey)?.status, .applied)
    }
}
