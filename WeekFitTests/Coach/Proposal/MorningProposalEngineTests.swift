import Foundation
import WeekFitPlanner
import XCTest
@testable import WeekFit

final class MorningProposalEngineTests: XCTestCase {

    override func tearDown() {
        MorningProposalStore.resetAllForTests()
        CoachAdjustmentProvenanceStore.resetAllForTests()
        CoachDecisionHistoryStore.resetAllForTests()
        CoachApplyJournalStore.resetAllForTests()
        ProposalBehavioralPreferences.resetAllForTests()
        super.tearDown()
    }

    func testGenerateShortensLongRunOnLowRecovery() {
        let now = date(2026, 7, 29, 7, 0)
        let run = snapshot(
            id: "run-1",
            date: date(2026, 7, 29, 18, 0),
            title: "Evening Run",
            type: "workout",
            duration: 75
        )

        let proposal = MorningProposalEngine.generate(
            input: engineInput(
                now: now,
                recoveryBand: .low,
                scenarioKey: .lowRecoveryPrep,
                yesterdayHeavy: true,
                tomorrowDemand: .moderate,
                stackedLoad: .unavailable,
                todayActivities: [run]
            )
        )

        XCTAssertEqual(proposal.status, .proposalReady)
        let shorten = proposal.changes.first { $0.kind == .modifyDuration }
        XCTAssertNotNil(shorten)
        XCTAssertTrue(shorten?.defaultSelected == true)
        if case .modifyDuration(let payload) = shorten?.payload {
            XCTAssertEqual(payload.activityId, "run-1")
            XCTAssertLessThan(payload.proposedDurationMinutes, 75)
            XCTAssertGreaterThanOrEqual(payload.proposedDurationMinutes, 15)
        } else {
            XCTFail("Expected modifyDuration payload")
        }
    }

    func testStableDayProducesNoMutations() {
        let now = date(2026, 7, 29, 7, 0)
        let walk = snapshot(
            id: "walk-1",
            date: date(2026, 7, 29, 12, 0),
            title: "Walk",
            type: "workout",
            duration: 30
        )

        let proposal = MorningProposalEngine.generate(
            input: engineInput(
                now: now,
                recoveryBand: .good,
                scenarioKey: .stableDay,
                todayActivities: [walk]
            )
        )

        XCTAssertEqual(proposal.status, .noChangesNeeded)
        XCTAssertTrue(proposal.changes.filter { $0.kind != .guidanceOnly }.isEmpty)
    }

    func testEmptyGoodRecoveryMayProposeUnselectedWalkOrGuidance() {
        let now = date(2026, 7, 29, 7, 0)

        let proposal = MorningProposalEngine.generate(
            input: engineInput(
                now: now,
                recoveryBand: .good,
                scenarioKey: .stableDay,
                todayActivities: []
            )
        )

        // Empty Plan alone must not force a selected Walk; a proposalReady Walk (unselected)
        // or noChangesNeeded (omit / guidance suppressed) are both valid production outcomes.
        let walks = proposal.changes.filter { $0.kind == .createRecoveryWalk }
        if proposal.status == .proposalReady {
            XCTAssertFalse(walks.isEmpty, "proposalReady without a Walk create is unexpected for empty good day")
            XCTAssertTrue(walks.allSatisfy { !$0.defaultSelected })
            XCTAssertTrue(proposal.changes.contains { $0.kind != .guidanceOnly })
        } else {
            XCTAssertEqual(proposal.status, .noChangesNeeded)
            XCTAssertTrue(proposal.changes.isEmpty)
        }
    }

    func testSeriousSessionGetsFuelGuidance() {
        let now = date(2026, 7, 29, 7, 0)
        let ride = snapshot(
            id: "ride-1",
            date: date(2026, 7, 29, 9, 45),
            title: "Cycling",
            type: "workout",
            duration: 60
        )

        let proposal = MorningProposalEngine.generate(
            input: engineInput(
                now: now,
                recoveryBand: .good,
                scenarioKey: .stableDay,
                todayActivities: [ride]
            )
        )

        // Guidance-only days do not surface proposalReady overlay chrome or dead payloads.
        XCTAssertEqual(proposal.status, .noChangesNeeded)
        XCTAssertTrue(proposal.changes.isEmpty)
    }

    func testUnavailableDataUsesNoChangesWhenCannotMutate() {
        let now = date(2026, 7, 29, 7, 0)

        let proposal = MorningProposalEngine.generate(
            input: engineInput(
                now: now,
                recoveryBand: .unavailable,
                sleepPresence: .unavailable,
                scenarioKey: nil,
                todayActivities: [],
                canMutate: false
            )
        )

        XCTAssertEqual(proposal.status, .noChangesNeeded)
        XCTAssertTrue(proposal.changes.isEmpty)
        XCTAssertEqual(proposal.strategy, .continueExistingPlan)
    }

    func testFingerprintMaterialDifferenceTracksSchemaAndObservation() {
        let a = ProposalInputFingerprint(
            dayKey: "2026-07-29",
            planSignature: "a",
            tomorrowPlanSignature: "b",
            recoveryBand: .low,
            sleepPresence: .present,
            scenarioKey: "lowRecoveryPrep",
            yesterdayHeavy: true,
            schemaVersion: 2,
            observationContextRevision: "none"
        )
        let b = ProposalInputFingerprint(
            dayKey: "2026-07-29",
            planSignature: "a",
            tomorrowPlanSignature: "b",
            recoveryBand: .low,
            sleepPresence: .present,
            scenarioKey: "lowRecoveryPrep",
            yesterdayHeavy: true,
            schemaVersion: 2,
            observationContextRevision: "none"
        )
        let c = ProposalInputFingerprint(
            dayKey: "2026-07-29",
            planSignature: "changed",
            tomorrowPlanSignature: "b",
            recoveryBand: .low,
            sleepPresence: .present,
            scenarioKey: "lowRecoveryPrep",
            yesterdayHeavy: true,
            schemaVersion: 2
        )
        let d = ProposalInputFingerprint(
            dayKey: "2026-07-29",
            planSignature: "a",
            tomorrowPlanSignature: "b",
            recoveryBand: .low,
            sleepPresence: .present,
            scenarioKey: "lowRecoveryPrep",
            yesterdayHeavy: true,
            schemaVersion: 2,
            observationContextRevision: "2026-07-20:1:low:present"
        )

        XCTAssertFalse(a.materialDifference(from: b))
        XCTAssertTrue(a.materialDifference(from: c))
        XCTAssertTrue(a.materialDifference(from: d))
    }

    func testProposalStoreRoundTrip() {
        let fingerprint = ProposalInputFingerprint(
            dayKey: "2026-07-29",
            planSignature: "sig",
            tomorrowPlanSignature: "",
            recoveryBand: .moderate,
            sleepPresence: .present,
            scenarioKey: "stableDay",
            yesterdayHeavy: false,
            schemaVersion: 2
        )
        let proposal = MorningPlanProposal(
            id: "p1",
            dayKey: "2026-07-29",
            generatedAt: Date(),
            status: .proposalReady,
            fingerprint: fingerprint,
            changes: [
                CoachProposedChange(
                    id: "c1",
                    kind: .guidanceOnly,
                    reasonCode: .insufficientConfidence,
                    payload: .guidanceOnly(
                        GuidanceOnlyPayload(guidanceCode: .easeIntoFirstEffort, relatedActivityId: nil)
                    ),
                    defaultSelected: false,
                    isSelected: false,
                    sortTime: Date(),
                    evidenceScenarioKey: nil
                )
            ],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: nil,
            schemaVersion: 2
        )

        MorningProposalStore.upsert(proposal)
        let loaded = MorningProposalStore.proposal(for: "2026-07-29")
        XCTAssertEqual(loaded?.id, "p1")
        XCTAssertEqual(loaded?.changes.count, 1)
        XCTAssertEqual(loaded?.changes.first?.kind, .guidanceOnly)
    }

    func testGateBlocksOutsideMorningWindow() {
        let decision = MorningProposalGate.decide(
            input: MorningProposalGateInput(
                now: Date(),
                dayRolloverCompleted: true,
                healthRefreshCompleted: true,
                healthRefreshTimedOut: false,
                isHealthAccessGranted: true,
                sleepHours: 7,
                recoveryDataAvailable: true,
                todayPlanLoaded: true,
                tomorrowPlanLoaded: true,
                yesterdayContextLoaded: true,
                isMorningWindow: false,
                hasCompletedPlannedItemToday: false,
                existingStatus: nil
            )
        )
        XCTAssertEqual(decision, .unavailable(reason: "outside_window"))
    }

    func testGateKeepsGatheringUntilHealthSettlesOrTimesOut() {
        let gathering = MorningProposalGate.decide(
            input: MorningProposalGateInput(
                now: Date(),
                dayRolloverCompleted: true,
                healthRefreshCompleted: false,
                healthRefreshTimedOut: false,
                isHealthAccessGranted: true,
                sleepHours: 0,
                recoveryDataAvailable: false,
                todayPlanLoaded: true,
                tomorrowPlanLoaded: true,
                yesterdayContextLoaded: true,
                isMorningWindow: true,
                hasCompletedPlannedItemToday: false,
                existingStatus: .gatheringData
            )
        )
        XCTAssertEqual(gathering, .gatheringData)

        let timedOut = MorningProposalGate.decide(
            input: MorningProposalGateInput(
                now: Date(),
                dayRolloverCompleted: true,
                healthRefreshCompleted: false,
                healthRefreshTimedOut: true,
                isHealthAccessGranted: true,
                sleepHours: 0,
                recoveryDataAvailable: false,
                todayPlanLoaded: true,
                tomorrowPlanLoaded: true,
                yesterdayContextLoaded: true,
                isMorningWindow: true,
                hasCompletedPlannedItemToday: false,
                existingStatus: .gatheringData
            )
        )
        XCTAssertEqual(timedOut, .allowGeneration)
    }

    func testMoveProposedWhenTwoSeriousSessionsAndTomorrowOpen() {
        let now = date(2026, 7, 29, 7, 0)
        let run = snapshot(
            id: "run-1",
            date: date(2026, 7, 29, 9, 0),
            title: "Long Run",
            type: "workout",
            duration: 90
        )
        let strength = snapshot(
            id: "str-1",
            date: date(2026, 7, 29, 18, 0),
            title: "Upper Body",
            type: "workout",
            duration: 60
        )

        let proposal = MorningProposalEngine.generate(
            input: engineInput(
                now: now,
                recoveryBand: .low,
                scenarioKey: .tomorrowProtection,
                tomorrowDemand: .easy,
                stackedLoad: .elevated,
                todayActivities: [run, strength]
            )
        )

        XCTAssertTrue(proposal.changes.contains { $0.kind == .moveActivity })
    }

    // MARK: - Helpers

    private func engineInput(
        now: Date,
        dayKey: String = "2026-07-29",
        recoveryBand: ProposalRecoveryBandToken = .good,
        sleepPresence: ProposalSleepPresenceToken = .present,
        scenarioKey: CoachScenarioKey? = .stableDay,
        yesterdayHeavy: Bool = false,
        tomorrowDemand: CoachTomorrowDemand = .none,
        stackedLoad: ProposalStackedLoadToken = .unavailable,
        generationMode: MorningProposalGenerationMode? = nil,
        todayActivities: [CoachPlannedActivitySnapshot],
        tomorrowActivities: [CoachPlannedActivitySnapshot] = [],
        completedWalkToday: Bool = false,
        canMutate: Bool = true,
        recentDayTemplates: [SimilarDayTemplate] = [],
        mealLibrary: [ProposalMealCandidate] = [],
        walkRejectPenalty: Int = 0,
        stronglyRejectsWalk: Bool = false
    ) -> MorningProposalEngineInput {
        let openCount = todayActivities.filter {
            !$0.isCompleted && !$0.isSkipped && CoachActivityClassifier.type(for: $0) != .none
        }.count
        let mode = generationMode ?? MorningProposalGenerationModeResolver.resolve(
            openCount: openCount,
            hasCompletedOrPartialToday: todayActivities.contains { $0.isCompleted || $0.isPartialCompletion },
            isMorningWindow: true
        )
        let fingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: dayKey,
            todaySnapshots: todayActivities,
            tomorrowSnapshots: tomorrowActivities,
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresence,
            scenarioKey: scenarioKey?.rawValue ?? "none",
            yesterdayHeavy: yesterdayHeavy,
            stackedLoad: stackedLoad,
            generationMode: mode
        )
        return MorningProposalEngineInput(
            now: now,
            dayKey: dayKey,
            fingerprint: fingerprint,
            scenarioKey: scenarioKey,
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresence,
            yesterdayHeavy: yesterdayHeavy,
            tomorrowDemand: tomorrowDemand,
            stackedLoad: stackedLoad,
            generationMode: mode,
            todayActivities: todayActivities,
            tomorrowActivities: tomorrowActivities,
            completedWalkToday: completedWalkToday,
            canMutate: canMutate && mode != .closed,
            recentDayTemplates: recentDayTemplates,
            mealLibrary: mealLibrary,
            walkRejectPenalty: walkRejectPenalty,
            stronglyRejectsWalk: stronglyRejectsWalk
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        return Calendar.current.date(from: comps) ?? Date()
    }

    private func snapshot(
        id: String,
        date: Date,
        title: String,
        type: String,
        duration: Int,
        isCompleted: Bool = false,
        isSkipped: Bool = false,
        actualDurationMinutes: Int? = nil
    ) -> CoachPlannedActivitySnapshot {
        CoachPlannedActivitySnapshot(
            id: id,
            date: date,
            type: type,
            title: title,
            durationMinutes: duration,
            icon: "figure.run",
            imageName: "",
            isCompleted: isCompleted,
            isSkipped: isSkipped,
            source: "planner",
            actualDurationMinutes: actualDurationMinutes
        )
    }
}
