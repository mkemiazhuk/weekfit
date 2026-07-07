import XCTest
@testable import WeekFit

final class SleepConsistencyBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenConsistentSleepImprovesRecovery() {
        let observations = sampleObservations(
            consistentBedtime: 23 * 60,
            consistentRecovery: 84,
            inconsistentBedtime: (1 * 60) + (24 * 60),
            inconsistentRecovery: 68,
            consistentCount: 5,
            inconsistentCount: 3
        )

        let evaluation = SleepConsistencyBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThan(evaluation?.recoveryDelta ?? 0, 8)

        let result = SleepConsistencyBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.change, .emerged)

        let extendedObservations = sampleObservations(
            consistentBedtime: 23 * 60,
            consistentRecovery: 84,
            inconsistentBedtime: (1 * 60) + (24 * 60),
            inconsistentRecovery: 68,
            consistentCount: 8,
            inconsistentCount: 5
        )
        let extendedEvaluation = SleepConsistencyBeliefEvaluator.analyze(observations: extendedObservations)
        XCTAssertTrue(extendedEvaluation?.hasEstablishedSamples ?? false)
    }

    func testInsufficientSamplesRemainWatching() {
        let observations = sampleObservations(
            consistentBedtime: 23 * 60,
            consistentRecovery: 84,
            inconsistentBedtime: (1 * 60) + (24 * 60),
            inconsistentRecovery: 68,
            consistentCount: 2,
            inconsistentCount: 1
        )

        let result = SleepConsistencyBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    // MARK: - Helpers

    private func sampleObservations(
        consistentBedtime: Int,
        consistentRecovery: Int,
        inconsistentBedtime: Int,
        inconsistentRecovery: Int,
        consistentCount: Int,
        inconsistentCount: Int
    ) -> [CoachDailyObservation] {
        var observations: [CoachDailyObservation] = []
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference

        var dayOffset = 1
        for index in 0..<consistentCount {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) else { continue }
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: 450,
                    recoveryPercent: consistentRecovery + (index % 2),
                    bedStartNormalizedMinutes: consistentBedtime + (index % 2) * 10
                )
            )
            dayOffset += 1
        }

        for index in 0..<inconsistentCount {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) else { continue }
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: 420,
                    recoveryPercent: inconsistentRecovery - (index % 2),
                    bedStartNormalizedMinutes: inconsistentBedtime
                )
            )
            dayOffset += 1
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }
}
