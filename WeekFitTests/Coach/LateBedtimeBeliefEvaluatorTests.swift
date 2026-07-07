import XCTest
@testable import WeekFit

final class LateBedtimeBeliefEvaluatorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testDetectsEmergingBeliefWhenLateBedtimeReducesRecovery() {
        let observations = sampleObservations(
            normalBedtime: (22 * 60) + 45,
            normalRecovery: 84,
            lateBedtime: (1 * 60) + (24 * 60),
            lateRecovery: 68,
            normalCount: 5,
            lateCount: 3
        )

        let evaluation = LateBedtimeBeliefEvaluator.analyze(observations: observations)
        XCTAssertNotNil(evaluation)
        XCTAssertGreaterThan(evaluation?.recoveryDrop ?? 0, 8)

        let result = LateBedtimeBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .emerging)
        XCTAssertEqual(result.event?.beliefID, .lateBedtimeRecovery)
        XCTAssertEqual(result.event?.change, .emerged)
    }

    func testPromotesToEstablishedWhenLateBedtimePatternRemainsStable() {
        let emergingObservations = sampleObservations(
            normalBedtime: (22 * 60) + 45,
            normalRecovery: 84,
            lateBedtime: (1 * 60) + (24 * 60),
            lateRecovery: 68,
            normalCount: 5,
            lateCount: 3
        )

        let emerging = LateBedtimeBeliefEvaluator.evaluate(
            observations: emergingObservations,
            currentMaturity: .watching
        )
        XCTAssertEqual(emerging.maturity, .emerging)

        let establishedObservations = sampleObservations(
            normalBedtime: (22 * 60) + 45,
            normalRecovery: 82,
            lateBedtime: (1 * 60) + (24 * 60),
            lateRecovery: 72,
            normalCount: 8,
            lateCount: 5
        )

        let established = LateBedtimeBeliefEvaluator.evaluate(
            observations: establishedObservations,
            currentMaturity: .emerging
        )
        XCTAssertEqual(established.maturity, .established)
        XCTAssertEqual(established.event?.change, .strengthened)
    }

    func testInsufficientSamplesRemainWatching() {
        let observations = sampleObservations(
            normalBedtime: (22 * 60) + 45,
            normalRecovery: 84,
            lateBedtime: (1 * 60) + (24 * 60),
            lateRecovery: 68,
            normalCount: 2,
            lateCount: 1
        )

        let result = LateBedtimeBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    func testNoEventWhenLateBedtimeDoesNotMeaningfullyReduceRecovery() {
        let observations = sampleObservations(
            normalBedtime: (22 * 60) + 45,
            normalRecovery: 80,
            lateBedtime: (1 * 60) + (24 * 60),
            lateRecovery: 78,
            normalCount: 5,
            lateCount: 3
        )

        let result = LateBedtimeBeliefEvaluator.evaluate(
            observations: observations,
            currentMaturity: .watching
        )
        XCTAssertEqual(result.maturity, .watching)
        XCTAssertNil(result.event)
    }

    // MARK: - Helpers

    private func sampleObservations(
        normalBedtime: Int,
        normalRecovery: Int,
        lateBedtime: Int,
        lateRecovery: Int,
        normalCount: Int,
        lateCount: Int
    ) -> [CoachDailyObservation] {
        var observations: [CoachDailyObservation] = []
        let calendar = Calendar.current
        let anchor = CoachTestClock.reference

        var dayOffset = 1
        for index in 0..<normalCount {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) else { continue }
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: 450,
                    recoveryPercent: normalRecovery + (index % 2),
                    bedStartNormalizedMinutes: normalBedtime + (index % 2) * 5
                )
            )
            dayOffset += 1
        }

        for index in 0..<lateCount {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: anchor) else { continue }
            observations.append(
                CoachDailyObservation(
                    dayKey: CoachDailyObservation.dayKey(for: date),
                    sleepMinutes: 420,
                    recoveryPercent: lateRecovery - (index % 2),
                    bedStartNormalizedMinutes: lateBedtime
                )
            )
            dayOffset += 1
        }

        return observations.sorted { $0.dayKey < $1.dayKey }
    }
}
