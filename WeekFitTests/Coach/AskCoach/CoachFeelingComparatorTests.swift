import XCTest
@testable import WeekFit

final class CoachFeelingComparatorTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testTiredWithShortSleepIsSupporting() {
        let checkInAt = date(2026, 4, 15, hour: 9)
        let observations = baselineObservations(
            endingBefore: checkInAt,
            sleep: 450,
            recovery: 70,
            count: 10
        ) + [
            observation(day: date(2026, 4, 15), sleep: 360, recovery: 62)
        ]

        let result = compare(
            feeling: .tired,
            checkInAt: checkInAt,
            observations: observations
        )

        XCTAssertEqual(result.outcome, .supporting)
        XCTAssertEqual(result.analysisVersion, CoachFeelingEvidenceRules.analysisVersion)
        XCTAssertNotNil(result.evidence.sleepMinutes)
        XCTAssertNotNil(result.evidence.sleepBaselineMinutes)
        let headline = CoachFeelingCopy.resolve(result.headline)
        XCTAssertTrue(headline.contains("similar signals") || headline.contains("похожие"))
    }

    func testTiredWithNearBaselineIsMixed() {
        let checkInAt = date(2026, 4, 15, hour: 9)
        let observations = baselineObservations(
            endingBefore: checkInAt,
            sleep: 450,
            recovery: 70,
            count: 10
        ) + [
            observation(day: date(2026, 4, 15), sleep: 445, recovery: 68)
        ]

        let result = compare(
            feeling: .tired,
            checkInAt: checkInAt,
            observations: observations
        )

        XCTAssertEqual(result.outcome, .mixed)
        let headline = CoachFeelingCopy.resolve(result.headline)
        XCTAssertTrue(headline.contains("don’t fully explain") || headline.contains("не полностью"))
    }

    func testInsufficientWithoutBaseline() {
        let checkInAt = date(2026, 4, 15, hour: 9)
        let observations = [
            observation(day: date(2026, 4, 14), sleep: 420, recovery: 65),
            observation(day: date(2026, 4, 15), sleep: 400, recovery: 60)
        ]

        let result = compare(
            feeling: .okay,
            checkInAt: checkInAt,
            observations: observations
        )

        XCTAssertEqual(result.outcome, .insufficient)
        XCTAssertNil(result.evidence.sleepBaselineMinutes)
    }

    func testStaleSleepIsNotUsedAsCurrent() {
        let checkInAt = date(2026, 4, 15, hour: 18)
        // Sleep from 3 days earlier → stale under 36h freshness.
        var observations = baselineObservations(
            endingBefore: date(2026, 4, 12),
            sleep: 450,
            recovery: 70,
            count: 10
        )
        observations.append(observation(day: date(2026, 4, 12), sleep: 300, recovery: 50))

        let result = compare(
            feeling: .tired,
            checkInAt: checkInAt,
            observations: observations
        )

        XCTAssertTrue(result.evidence.sleepIsStale || result.evidence.sleepMinutes == nil)
        XCTAssertEqual(result.outcome, .insufficient)
    }

    func testHistoricalCheckInIgnoresLaterObservations() {
        let checkInAt = date(2026, 4, 10, hour: 9)
        let observations = baselineObservations(
            endingBefore: checkInAt,
            sleep: 450,
            recovery: 70,
            count: 10
        ) + [
            observation(day: date(2026, 4, 10), sleep: 360, recovery: 55),
            // Later day must not affect the historical comparison.
            observation(day: date(2026, 4, 15), sleep: 520, recovery: 90)
        ]

        let result = compare(
            feeling: .tired,
            checkInAt: checkInAt,
            observations: observations
        )

        XCTAssertEqual(result.evidence.sleepMinutes, 360)
        XCTAssertEqual(result.outcome, .supporting)
    }

    func testOkayNearBaselineIsSupporting() {
        let checkInAt = date(2026, 4, 15, hour: 9)
        let observations = baselineObservations(
            endingBefore: checkInAt,
            sleep: 450,
            recovery: 70,
            count: 10
        ) + [
            observation(day: date(2026, 4, 15), sleep: 440, recovery: 72)
        ]

        let result = compare(
            feeling: .okay,
            checkInAt: checkInAt,
            observations: observations
        )
        XCTAssertEqual(result.outcome, .supporting)
    }

    // MARK: - Helpers

    private func compare(
        feeling: CoachFeelingKind,
        checkInAt: Date,
        observations: [CoachDailyObservation]
    ) -> CoachFeelingComparisonResult {
        CoachFeelingComparator.compare(
            .init(
                feeling: feeling,
                clarification: nil,
                checkInAt: checkInAt,
                observations: observations,
                recentActivityDayKeys: [],
                recentActivityCount: 0
            ),
            calendar: calendar
        )
    }

    private func baselineObservations(
        endingBefore checkInAt: Date,
        sleep: Int,
        recovery: Int,
        count: Int
    ) -> [CoachDailyObservation] {
        let endDay = calendar.startOfDay(for: checkInAt)
        return (1...count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: endDay) else {
                return nil
            }
            return observation(day: day, sleep: sleep, recovery: recovery)
        }
    }

    private func observation(day: Date, sleep: Int, recovery: Int) -> CoachDailyObservation {
        CoachDailyObservation(
            dayKey: CoachDailyObservation.dayKey(for: day, calendar: calendar),
            sleepMinutes: sleep,
            recoveryPercent: recovery
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
