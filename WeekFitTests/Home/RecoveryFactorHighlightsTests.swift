import XCTest
@testable import WeekFit

final class RecoveryFactorHighlightsTests: XCTestCase {

    func testLimiterIsTheLargestWeightedShortfallNotTheLowestGrade() {
        let breakdown = makeBreakdown(
            sleepDuration: 22,
            sleepArchitecture: 2,
            hrv: 10,
            restingHeartRate: 9,
            sleepDurationGrade: 8,
            sleepArchitectureGrade: 2,
            hrvGrade: 4,
            restingHeartRateGrade: 9
        )

        let selection = RecoveryFactorHighlights.select(breakdown: breakdown, hasSleep: true)

        XCTAssertEqual(selection.supporting, RecoveryBreakdownSignal.sleepDuration)
        XCTAssertEqual(selection.limiting, RecoveryBreakdownSignal.hrv)
        XCTAssertNotEqual(selection.limiting, RecoveryBreakdownSignal.sleepArchitecture)
    }

    func testStrongNightKeepsSupportAndDoesNotInventALimiter() {
        let breakdown = makeBreakdown(
            sleepDuration: 24,
            sleepConsistency: 12,
            sleepContinuity: 14,
            sleepArchitecture: 8,
            hrv: 20,
            restingHeartRate: 8,
            sleepDurationGrade: 9,
            sleepConsistencyGrade: 9,
            sleepContinuityGrade: 9,
            sleepArchitectureGrade: 8,
            hrvGrade: 8,
            restingHeartRateGrade: 8
        )

        let selection = RecoveryFactorHighlights.select(breakdown: breakdown, hasSleep: true)

        XCTAssertEqual(selection.supporting, RecoveryBreakdownSignal.sleepDuration)
        XCTAssertNil(selection.limiting)
    }

    func testWeakNightDoesNotPromoteTheLeastBadFactorToSupport() {
        let breakdown = makeBreakdown(
            sleepDuration: 10,
            hrv: 8,
            restingHeartRate: 4,
            sleepDurationGrade: 4,
            hrvGrade: 3,
            restingHeartRateGrade: 2
        )

        let selection = RecoveryFactorHighlights.select(breakdown: breakdown, hasSleep: true)

        XCTAssertNil(selection.supporting)
        XCTAssertEqual(selection.limiting, RecoveryBreakdownSignal.hrv)
    }

    func testMissingSleepDoesNotInventFactorsOrAZeroDurationGrade() {
        let selection = RecoveryFactorHighlights.select(breakdown: .empty, hasSleep: false)
        XCTAssertNil(selection.supporting)
        XCTAssertNil(selection.limiting)
        XCTAssertNil(RecoveryFactorCopy.grade(for: .sleepDuration, snapshot: .empty))
        XCTAssertNil(RecoveryFactorCopy.grade(for: .hrv, snapshot: .empty))
    }

    func testUnmeasuredConsistencyIsNotAHighlight() {
        let breakdown = makeBreakdown(
            sleepDuration: 24,
            sleepConsistency: 13,
            sleepDurationGrade: 9,
            sleepConsistencyGrade: nil
        )

        let selection = RecoveryFactorHighlights.select(breakdown: breakdown, hasSleep: true)
        XCTAssertEqual(selection.supporting, RecoveryBreakdownSignal.sleepDuration)
        XCTAssertNil(selection.limiting)
    }

    private func makeBreakdown(
        sleepDuration: Int = 0,
        sleepConsistency: Int = 0,
        sleepContinuity: Int = 0,
        sleepArchitecture: Int = 0,
        hrv: Int = 0,
        restingHeartRate: Int = 0,
        sleepDurationGrade: Int = 0,
        sleepConsistencyGrade: Int? = nil,
        sleepContinuityGrade: Int? = nil,
        sleepArchitectureGrade: Int? = nil,
        hrvGrade: Int? = nil,
        restingHeartRateGrade: Int? = nil
    ) -> RecoveryScoreBreakdown {
        RecoveryScoreBreakdown(
            sleepDuration: sleepDuration,
            sleepConsistency: sleepConsistency,
            sleepContinuity: sleepContinuity,
            sleepArchitecture: sleepArchitecture,
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            trainingLoadModifier: 0,
            total: sleepDuration + sleepConsistency + sleepContinuity + sleepArchitecture + hrv + restingHeartRate,
            confidence: .high,
            baselineContext: .empty,
            unavailableSignals: [],
            sleepDurationQuality: Double(sleepDurationGrade * 10),
            sleepDurationGrade: sleepDurationGrade,
            sleepConsistencyQuality: sleepConsistencyGrade.map { Double($0 * 10) },
            sleepConsistencyGrade: sleepConsistencyGrade,
            sleepContinuityQuality: sleepContinuityGrade.map { Double($0 * 10) },
            sleepContinuityGrade: sleepContinuityGrade,
            sleepArchitectureQuality: sleepArchitectureGrade.map { Double($0 * 10) },
            sleepArchitectureGrade: sleepArchitectureGrade,
            hrvQuality: hrvGrade.map { Double($0 * 10) },
            hrvGrade: hrvGrade,
            restingHeartRateQuality: restingHeartRateGrade.map { Double($0 * 10) },
            restingHeartRateGrade: restingHeartRateGrade
        )
    }
}
