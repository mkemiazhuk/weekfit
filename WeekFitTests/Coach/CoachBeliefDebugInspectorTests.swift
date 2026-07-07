import XCTest
@testable import WeekFit

final class CoachBeliefDebugInspectorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
        CoachObservationStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        CoachObservationStore.resetForTests()
        super.tearDown()
    }

    func testSnapshotListsAllSevenRegisteredBeliefs() {
        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))

        XCTAssertEqual(snapshot.beliefs.count, 7)
        XCTAssertEqual(
            Set(snapshot.beliefs.map(\.beliefID)),
            Set(CoachBeliefRegistry.registeredBeliefIDs)
        )
    }

    func testInsufficientDataStatesAreVisible() {
        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))

        XCTAssertTrue(snapshot.beliefs.allSatisfy { !$0.noEventReason.isEmpty })
        XCTAssertTrue(
            snapshot.beliefs.allSatisfy {
                $0.evidenceWindow.contains("insufficient") || $0.sampleSize == "n/a"
            }
        )
    }

    func testPendingAndSpokenQueueIsVisible() {
        let events = [
            UnderstandingEvent.make(beliefID: .sleepConsistencyRecovery, change: .emerged, maturity: .emerging),
            UnderstandingEvent.make(beliefID: .sleepDurationRecovery, change: .emerged, maturity: .emerging),
        ]

        CoachUnderstandingStore.seedForTests(
            beliefs: [
                CoachBelief(id: .sleepConsistencyRecovery, maturity: .emerging, lastUpdated: Date()),
                CoachBelief(id: .sleepDurationRecovery, maturity: .emerging, lastUpdated: Date()),
            ],
            pendingEvents: events,
            spokenEventIDs: [events[0].id]
        )

        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))

        XCTAssertEqual(snapshot.eventQueue.count, 2)
        XCTAssertEqual(snapshot.eventQueue.filter(\.isSpoken).count, 1)
        XCTAssertEqual(snapshot.eventQueue.filter(\.isNextUnspoken).count, 1)
        XCTAssertEqual(snapshot.eventQueue.first(where: \.isNextUnspoken)?.id, events[1].id)

        let consistency = snapshot.beliefs.first { $0.beliefID == .sleepConsistencyRecovery }
        XCTAssertEqual(consistency?.hasSpokenEvent, true)
        XCTAssertEqual(consistency?.hasPendingEvent, false)

        let duration = snapshot.beliefs.first { $0.beliefID == .sleepDurationRecovery }
        XCTAssertEqual(duration?.hasPendingEvent, true)
    }

    @MainActor
    func testReflectionPauseBlockersAreVisibleWhenCoachInputUnavailable() {
        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))

        XCTAssertFalse(snapshot.reflection.pause)
        XCTAssertEqual(snapshot.reflection.blockedBy, "coachInputUnavailable")
        XCTAssertNotNil(snapshot.reflection.noReflectionReason)
    }

    @MainActor
    func testReflectionStateShowsPauseAndOfferWhenReady() {
        CoachObservationStore.seedForTests(SleepBeliefIntegrationFixtures.observationsSupportingAllThreeBeliefs())
        CoachUnderstandingService.evaluateBeliefs()

        let input = makeStablePauseCoachInput()
        let state = CoachState.ready(input: input, fingerprint: CoachInputFingerprint(snapshot: input))

        let snapshot = CoachBeliefDebugInspector.build(coachState: state)

        XCTAssertTrue(snapshot.reflection.pause)
        XCTAssertNil(snapshot.reflection.blockedBy)
        XCTAssertNotNil(snapshot.reflection.nextUnspokenEventID)
        XCTAssertNotNil(snapshot.reflection.reflectionOfferID)
        XCTAssertFalse(snapshot.reflection.isReflectionOfferDisplayed)
    }

    // MARK: - Fixtures

    private func makeStablePauseCoachInput() -> CoachInputSnapshot {
        let now = CoachTestClock.reference
        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(HumanBrainStateBuilder.Configuration(currentHour: 15)),
            plannedActivities: [],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 550,
                exerciseMinutes: 90,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 1.0
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_400,
                proteinCurrent: 110,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            source: "CoachBeliefDebugInspectorTests"
        )
    }
}
