import XCTest
@testable import WeekFit

final class SleepDurationBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenSufficientSleepImprovesRecovery() {
        let observations = sampleObservations(
            sufficientSleepMinutes: 450,
            sufficientRecovery: 84,
            insufficientSleepMinutes: 360,
            insufficientRecovery: 68,
            sufficientCount: 5,
            insufficientCount: 3
        )

        let evaluation = SleepDurationBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThan(evaluation?.recoveryDelta ?? 0, 8)

        let result = SleepDurationBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .sleepDurationRecovery)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testPromotesToEstablishedWhenPatternRemainsStableWithMoreData() {
        let emergingObservations = sampleObservations(
            sufficientSleepMinutes: 450,
            sufficientRecovery: 84,
            insufficientSleepMinutes: 360,
            insufficientRecovery: 68,
            sufficientCount: 5,
            insufficientCount: 3
        )

        let emerging = SleepDurationBeliefEvaluator.evaluate(
            observations: emergingObservations,
            currentMaturity: .watching
        )
        XCTAssertEqual(emerging.maturity, .emerging)

        let establishedObservations = sampleObservations(
            sufficientSleepMinutes: 450,
            sufficientRecovery: 82,
            insufficientSleepMinutes: 360,
            insufficientRecovery: 72,
            sufficientCount: 8,
            insufficientCount: 5
        )

        let established = SleepDurationBeliefEvaluator.evaluate(
            observations: establishedObservations,
            currentMaturity: .emerging
        )
        XCTAssertEqual(established.maturity, .established)
        XCTAssertEqual(established.event?.change, .strengthened)
    }

    func testInsufficientSamplesRemainWatching() {
        let observations = sampleObservations(
            sufficientSleepMinutes: 450,
            sufficientRecovery: 84,
            insufficientSleepMinutes: 360,
            insufficientRecovery: 68,
            sufficientCount: 2,
            insufficientCount: 1
        )

        let result = SleepDurationBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testMissingRecoverySignalIsExcluded() {
        let observations = sampleObservations(
            sufficientSleepMinutes: 450,
            sufficientRecovery: 84,
            insufficientSleepMinutes: 360,
            insufficientRecovery: 68,
            sufficientCount: 5,
            insufficientCount: 3
        ) + [
            CoachDailyObservation(
                dayKey: "2099-01-01",
                sleepMinutes: 450,
                recoveryPercent: 0,
                bedStartNormalizedMinutes: 23 * 60
            )
        ]

        let evaluation = SleepDurationBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertEqual(
            (evaluation?.sufficientSampleCount ?? 0) + (evaluation?.insufficientSampleCount ?? 0),
            8
        )
    }

    // MARK: - Helpers

    private func sampleObservations(
        sufficientSleepMinutes: Int,
        sufficientRecovery: Int,
        insufficientSleepMinutes: Int,
        insufficientRecovery: Int,
        sufficientCount: Int,
        insufficientCount: Int
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
                    sleepMinutes: sufficientSleepMinutes + (index % 2) * 15,
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
                    sleepMinutes: insufficientSleepMinutes,
                    recoveryPercent: insufficientRecovery - (index % 2),
                    bedStartNormalizedMinutes: (1 * 60) + (24 * 60)
                )
            )
            dayOffset += 1
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }
}
