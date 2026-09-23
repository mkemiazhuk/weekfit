import HealthKit
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

    func testSecondsInZoneDoesNotDoubleCountOverlappingActiveIntervals() {
        let start = Date(timeIntervalSince1970: 4_000)
        let end = start.addingTimeInterval(59 * 60)
        // Dense-ish samples mostly in zone 1, matching the ~2x bug on Fitness-synced workouts.
        var samples: [WorkoutHeartRateSample] = []
        for offset in stride(from: 0, through: 59 * 60, by: 30) {
            let bpm: Double = offset < 45 * 60 ? 117 : 150
            samples.append(
                WorkoutHeartRateSample(
                    timestamp: start.addingTimeInterval(TimeInterval(offset)),
                    beatsPerMinute: bpm
                )
            )
        }

        // Two overlapping windows covering the same workout (seen with HKWorkoutActivity).
        let overlapping = [
            DateInterval(start: start, end: end),
            DateInterval(start: start, end: end)
        ]

        let zone1 = WorkoutHeartRateAnalytics.secondsInZone(
            samples: samples,
            activeIntervals: overlapping
        ) { $0 < 130 }
        let zoneHigher = WorkoutHeartRateAnalytics.secondsInZone(
            samples: samples,
            activeIntervals: overlapping
        ) { $0 >= 130 }

        XCTAssertEqual(zone1, 45 * 60, accuracy: 1)
        XCTAssertEqual(zoneHigher, 14 * 60, accuracy: 1)
        XCTAssertEqual(zone1 + zoneHigher, 59 * 60, accuracy: 1)
        XCTAssertLessThan(zone1, 60 * 60)
    }

    func testCoalesceMergesOverlappingIntervals() {
        let start = Date(timeIntervalSince1970: 5_000)
        let coalesced = WorkoutHeartRateAnalytics.coalesce([
            DateInterval(start: start, end: start.addingTimeInterval(60)),
            DateInterval(start: start.addingTimeInterval(30), end: start.addingTimeInterval(90)),
            DateInterval(start: start.addingTimeInterval(200), end: start.addingTimeInterval(260))
        ])

        XCTAssertEqual(coalesced.count, 2)
        XCTAssertEqual(coalesced[0].duration, 90, accuracy: 0.1)
        XCTAssertEqual(coalesced[1].duration, 60, accuracy: 0.1)
    }

    func testFitnessHikePaceMatchesMovingTimeNotElapsed() {
        // 6:13:06 moving / 19.81 km = 18'50" /km
        let minutesPerKm = (6 * 3600 + 13 * 60 + 6) / 60.0 / 19.81
        XCTAssertEqual(minutesPerKm, 18 + 50.0 / 60.0, accuracy: 0.05)
    }

    func testDurationsPreferFitnessWorkoutTimeOverElapsedWhenPaused() {
        let start = Date(timeIntervalSince1970: 10_000)
        let end = start.addingTimeInterval(3 * 3600 + 20 * 60)
        let workoutSeconds = TimeInterval(1 * 3600 + 17 * 60 + 1)

        // Simulate Fitness: duration excludes pause, wall clock does not.
        let fitnessWorkout = workoutSeconds
        let elapsed = end.timeIntervalSince(start)
        XCTAssertGreaterThan(elapsed - fitnessWorkout, 60)

        // Mirrors ActivitySessionDetailSnapshot.shouldShowElapsedTime.
        XCTAssertTrue(elapsed > fitnessWorkout + 60)

        // Speed must use workout time, not elapsed (17.01 km example).
        let distanceKm = 17.01
        let speed = distanceKm / (fitnessWorkout / 3600.0)
        let wrongSpeed = distanceKm / (elapsed / 3600.0)
        XCTAssertEqual(speed, 13.2, accuracy: 0.2)
        XCTAssertLessThan(wrongSpeed, speed)
    }

    func testDistanceIdentifierUsesCyclingQuantity() {
        XCTAssertEqual(
            WorkoutFitnessMetrics.distanceIdentifier(for: .cycling),
            .distanceCycling
        )
        XCTAssertEqual(
            WorkoutFitnessMetrics.distanceIdentifier(for: .running),
            .distanceWalkingRunning
        )
    }
}
