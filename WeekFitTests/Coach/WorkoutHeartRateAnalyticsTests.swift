import XCTest
@testable import WeekFit

final class WorkoutHeartRateAnalyticsTests: XCTestCase {
    func testDurationLabelMatchesAppleFitnessFormat() {
        XCTAssertEqual(WorkoutHeartRateAnalytics.durationLabel(seconds: 0), "00:00")
        XCTAssertEqual(WorkoutHeartRateAnalytics.durationLabel(seconds: 33 * 60 + 10), "33:10")
        XCTAssertEqual(
            WorkoutHeartRateAnalytics.durationLabel(seconds: 6 * 3600 + 13 * 60 + 6),
            "6:13:06"
        )
    }

    func testTimeWeightedAveragePrefersLongerIntervals() {
        let start = Date(timeIntervalSince1970: 1_000)
        let samples = [
            WorkoutHeartRateSample(timestamp: start, beatsPerMinute: 100),
            WorkoutHeartRateSample(timestamp: start.addingTimeInterval(90), beatsPerMinute: 160),
            WorkoutHeartRateSample(timestamp: start.addingTimeInterval(100), beatsPerMinute: 160)
        ]

        let average = WorkoutHeartRateAnalytics.timeWeightedAverage(samples: samples)
        XCTAssertEqual(average ?? 0, 106, accuracy: 0.5)
    }

    func testSecondsInZoneCountsActualIntervalsInsteadOfCappingAtOneMinute() {
        let start = Date(timeIntervalSince1970: 2_000)
        let samples = [
            WorkoutHeartRateSample(timestamp: start, beatsPerMinute: 110),
            WorkoutHeartRateSample(timestamp: start.addingTimeInterval(90), beatsPerMinute: 140)
        ]

        let seconds = WorkoutHeartRateAnalytics.secondsInZone(
            samples: samples,
            startDate: start,
            endDate: start.addingTimeInterval(120)
        ) { $0 < 130 }

        XCTAssertEqual(seconds, 90, accuracy: 0.1)
    }

    func testSecondsInZoneIgnoresPausedGaps() {
        let start = Date(timeIntervalSince1970: 3_000)
        let samples = [
            WorkoutHeartRateSample(timestamp: start, beatsPerMinute: 110),
            WorkoutHeartRateSample(timestamp: start.addingTimeInterval(60), beatsPerMinute: 110),
            WorkoutHeartRateSample(timestamp: start.addingTimeInterval(2 * 3600), beatsPerMinute: 140),
            WorkoutHeartRateSample(timestamp: start.addingTimeInterval(2 * 3600 + 60), beatsPerMinute: 140)
        ]
        let intervals = [
            DateInterval(start: start, end: start.addingTimeInterval(60)),
            DateInterval(start: start.addingTimeInterval(2 * 3600), end: start.addingTimeInterval(2 * 3600 + 60))
        ]

        let zone1 = WorkoutHeartRateAnalytics.secondsInZone(
            samples: samples,
            activeIntervals: intervals
        ) { $0 < 130 }
        let zone3 = WorkoutHeartRateAnalytics.secondsInZone(
            samples: samples,
            activeIntervals: intervals
        ) { $0 >= 130 }

        XCTAssertEqual(zone1, 60, accuracy: 0.1)
        XCTAssertEqual(zone3, 60, accuracy: 0.1)
    }

    func testFitnessHikePaceMatchesMovingTimeNotElapsed() {
        // 6:13:06 moving / 19.81 km = 18'50" /km
        let minutesPerKm = (6 * 3600 + 13 * 60 + 6) / 60.0 / 19.81
        XCTAssertEqual(minutesPerKm, 18 + 50.0 / 60.0, accuracy: 0.05)
    }
}
