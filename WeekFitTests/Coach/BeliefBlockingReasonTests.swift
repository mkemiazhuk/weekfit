import XCTest
@testable import WeekFit

final class BeliefBlockingReasonTests: XCTestCase {

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

    func testInsufficientObservationsReason() {
        let evaluation = SleepDurationBeliefEvaluator.evaluate(
            observations: [],
            currentMaturity: .watching
        )

        let reason = SleepDurationBeliefEvaluator.blockingReason(
            observations: [],
            currentMaturity: .watching,
            evaluation: evaluation
        )

        XCTAssertEqual(reason, .insufficientObservations(required: 8, actual: 0))
        XCTAssertTrue(reason?.debugDescription.contains("Need 8+") ?? false)
    }

    func testInsufficientGroupSplitReason() {
        let observations = sampleSleepDurationObservations(
            sufficientCount: 8,
            insufficientCount: 0,
            sufficientRecovery: 84,
            insufficientRecovery: 68
        )

        let evaluation = SleepDurationBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )

        let reason = SleepDurationBeliefEvaluator.blockingReason(
            observations: observations,
            currentMaturity: .watching,
            evaluation: evaluation
        )

        XCTAssertEqual(
            reason,
            .insufficientGroupSamples(
                primaryRequired: 4,
                primaryActual: 8,
                comparisonRequired: 2,
                comparisonActual: 0
            )
        )
        XCTAssertTrue(reason?.debugDescription.contains("comparison groups") ?? false)
    }

    func testWeakEffectWithEnoughDataReason() {
        let observations = sampleSleepDurationObservations(
            sufficientCount: 5,
            insufficientCount: 3,
            sufficientRecovery: 80,
            insufficientRecovery: 78
        )

        let evaluation = SleepDurationBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )

        let reason = SleepDurationBeliefEvaluator.blockingReason(
            observations: observations,
            currentMaturity: .watching,
            evaluation: evaluation
        )

        if case .weakEffect = reason {
            XCTAssertEqual(reason?.debugDescription, "Enough data, but no stable pattern detected yet.")
        } else {
            XCTFail("Expected weakEffect, got \(String(describing: reason))")
        }
    }

    func testInverseEffectReason() {
        let observations = sampleSleepDurationObservations(
            sufficientCount: 5,
            insufficientCount: 3,
            sufficientRecovery: 70,
            insufficientRecovery: 85
        )

        let evaluation = SleepDurationBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )

        let reason = SleepDurationBeliefEvaluator.blockingReason(
            observations: observations,
            currentMaturity: .watching,
            evaluation: evaluation
        )

        if case .inverseOrConflictingEffect = reason {
            XCTAssertEqual(reason?.debugDescription, "Current data points in the opposite direction.")
        } else {
            XCTFail("Expected inverseOrConflictingEffect, got \(String(describing: reason))")
        }
    }

    func testEstablishedPatternReason() {
        CoachUnderstandingStore.seedForTests(
            beliefs: [
                CoachBelief(id: .sleepDurationRecovery, maturity: .established, lastUpdated: Date()),
            ]
        )

        let observations = sampleSleepDurationObservations(
            sufficientCount: 8,
            insufficientCount: 5,
            sufficientRecovery: 84,
            insufficientRecovery: 68
        )

        let evaluation = SleepDurationBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .established
        )

        let reason = SleepDurationBeliefEvaluator.blockingReason(
            observations: observations,
            currentMaturity: .established,
            evaluation: evaluation
        )

        XCTAssertEqual(reason, .alreadyEstablished)
    }

    func testDebugInspectorUsesStructuredBlockingReason() {
        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))
        let sleepDuration = snapshot.beliefs.first { $0.beliefID == .sleepDurationRecovery }

        XCTAssertNotNil(sleepDuration?.blockingReason)
        XCTAssertFalse(sleepDuration?.noEventReason.isEmpty ?? true)
        XCTAssertTrue(sleepDuration?.noEventReason.contains("Need 8+") ?? false)
    }

    #if DEBUG
    func testDomainSummaryDistinguishesMissingDataFromWeakSignal() {
        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))
        let training = CoachUnderstandingInspectorPresentation.domainSummaries(from: snapshot)
            .first { $0.domain == .trainingLoad }

        XCTAssertEqual(training?.status, .missingData)
        XCTAssertTrue(training?.headline.contains("needs more training") ?? false)
    }

    func testEstablishedSleepDomainSummaryHeadline() {
        CoachUnderstandingStore.seedForTests(
            beliefs: [
                CoachBelief(id: .sleepDurationRecovery, maturity: .established, lastUpdated: Date()),
            ]
        )
        CoachObservationStore.seedForTests(SleepBeliefIntegrationFixtures.observationsSupportingAllThreeBeliefs())

        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))
        let sleep = CoachUnderstandingInspectorPresentation.domainSummaries(from: snapshot)
            .first { $0.domain == .sleep }

        XCTAssertEqual(sleep?.status, .establishedPattern)
        XCTAssertTrue(sleep?.headline.contains("established") ?? false)
    }
    #endif

    // MARK: - Helpers

    private func sampleSleepDurationObservations(
        sufficientCount: Int,
        insufficientCount: Int,
        sufficientRecovery: Int,
        insufficientRecovery: Int
    ) -> [CoachDailyObservation] {
        var observations: [CoachDailyObservation] = []
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference
        var dayOffset = 1

        for index in 0..<sufficientCount {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) else { continue }
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: 450,
                    recoveryPercent: sufficientRecovery + (index % 2),
                    bedStartNormalizedMinutes: 23 * 60
                )
            )
            dayOffset += 1
        }

        for index in 0..<insufficientCount {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) else { continue }
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: 360,
                    recoveryPercent: insufficientRecovery - (index % 2),
                    bedStartNormalizedMinutes: (1 * 60) + (24 * 60)
                )
            )
            dayOffset += 1
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }
}
