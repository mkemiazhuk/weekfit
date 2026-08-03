import XCTest
@testable import WeekFitWorkoutMetrics

final class WorkoutRouteMaxSpeedCalculatorTests: XCTestCase {

    func testRejectsGPSSpikeOnCasualRide() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var points: [WorkoutRoutePoint] = []

        // 1 Hz GPS at ~25 km/h (~6.94 m/s).
        for index in 0..<40 {
            let meters = Double(index) * 6.94
            points.append(
                point(
                    latitude: 52.0 + meters / 111_320.0,
                    longitude: 13.0,
                    date: base.addingTimeInterval(Double(index))
                )
            )
        }

        // GPS jump: ~21 m in 1s ≈ 75 km/h
        let last = points[points.count - 1]
        points.append(
            point(
                latitude: last.latitude + 21.0 / 111_320.0,
                longitude: last.longitude,
                date: last.timestamp.addingTimeInterval(1)
            )
        )

        let maxSpeed = WorkoutRouteMaxSpeedCalculator.maxSpeedKmh(
            from: points,
            averageSpeedKmh: 25,
            absoluteCeilingKmh: WorkoutRouteMaxSpeedCalculator.AbsoluteCeilingKmh.cycling
        )

        XCTAssertNotNil(maxSpeed)
        XCTAssertLessThan(maxSpeed ?? 999, 55, "Spike ~75 km/h must not surface as max")
        XCTAssertGreaterThanOrEqual(maxSpeed ?? 0, 24, "Peak should stay near real ride pace")
    }

    func testMaxNeverBelowAverage() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        // Mostly stopped / creeping GPS drift (~6–8 km/h), but overall average is higher.
        var points: [WorkoutRoutePoint] = []
        for index in 0..<20 {
            let meters = Double(index) * 2.0 // 2 m/s wait no — 2m per 1s = 7.2 km/h
            points.append(
                point(
                    latitude: 52.0 + meters / 111_320.0,
                    longitude: 13.0,
                    date: base.addingTimeInterval(Double(index))
                )
            )
        }

        let maxSpeed = WorkoutRouteMaxSpeedCalculator.maxSpeedKmh(
            from: points,
            averageSpeedKmh: 15.5,
            absoluteCeilingKmh: WorkoutRouteMaxSpeedCalculator.AbsoluteCeilingKmh.cycling
        )

        XCTAssertNotNil(maxSpeed)
        XCTAssertGreaterThanOrEqual(maxSpeed ?? 0, 15.5, "Max must not undercut average")
    }

    func testAllowsHardEffortBelowCeiling() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var points: [WorkoutRoutePoint] = []

        // Steady ~40 km/h at 1 Hz (~11.11 m/s)
        for index in 0..<30 {
            let meters = Double(index) * 11.11
            points.append(
                point(
                    latitude: 52.0 + meters / 111_320.0,
                    longitude: 13.0,
                    date: base.addingTimeInterval(Double(index))
                )
            )
        }

        let maxSpeed = WorkoutRouteMaxSpeedCalculator.maxSpeedKmh(
            from: points,
            averageSpeedKmh: 38,
            absoluteCeilingKmh: WorkoutRouteMaxSpeedCalculator.AbsoluteCeilingKmh.cycling
        )

        XCTAssertNotNil(maxSpeed)
        XCTAssertGreaterThan(maxSpeed ?? 0, 35)
        XCTAssertLessThanOrEqual(maxSpeed ?? 999, 65)
    }

    func testIgnoresSubSecondTeleport() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let points = [
            point(latitude: 52.0, longitude: 13.0, date: base),
            // 20 m in 0.3s ≈ 240 km/h
            point(latitude: 52.0 + 20.0 / 111_320.0, longitude: 13.0, date: base.addingTimeInterval(0.3)),
        ]

        let maxSpeed = WorkoutRouteMaxSpeedCalculator.maxSpeedKmh(
            from: points,
            averageSpeedKmh: 15,
            absoluteCeilingKmh: WorkoutRouteMaxSpeedCalculator.AbsoluteCeilingKmh.cycling
        )
        // No valid segments → fall back to average.
        XCTAssertEqual(maxSpeed ?? -1, 15, accuracy: 0.01)
    }

    private func point(latitude: Double, longitude: Double, date: Date) -> WorkoutRoutePoint {
        WorkoutRoutePoint(
            latitude: latitude,
            longitude: longitude,
            altitude: 40,
            verticalAccuracy: 4,
            timestamp: date
        )
    }
}
