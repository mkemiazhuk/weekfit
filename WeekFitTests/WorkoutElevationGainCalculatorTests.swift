import Foundation
import XCTest
@testable import WeekFit

final class WorkoutElevationGainCalculatorTests: XCTestCase {

    func testFlatNoisyWalkProducesLittleOrNoGain() {
        let gain = WorkoutElevationGainCalculator.calculate(from: makeNoisyFlatWalkPoints())

        XCTAssertLessThan(gain ?? 0, 10)
    }

    func testNaivePositiveDeltaSumWouldOverReportFlatWalk() {
        let points = makeNoisyFlatWalkPoints()

        var naiveGain = 0.0
        for index in 1..<points.count {
            let delta = points[index].altitude - points[index - 1].altitude
            if delta > 0 {
                naiveGain += delta
            }
        }

        let filteredGain = WorkoutElevationGainCalculator.calculate(from: points) ?? 0

        XCTAssertGreaterThan(naiveGain, filteredGain)
        XCTAssertLessThan(filteredGain, 15)
    }

    func testSteadyClimbReportsFullGain() {
        let altitudes = stride(from: 0.0, through: 50.0, by: 2.5).map { $0 }
        let gain = WorkoutElevationGainCalculator.calculate(from: makePoints(altitudes: altitudes))

        XCTAssertEqual(gain ?? 0, 50, accuracy: 8)
    }

    func testIgnoresUnreliableAltitudeSamples() {
        let points = [
            makePoint(altitude: 100.0, verticalAccuracy: 4),
            makePoint(altitude: 130.0, verticalAccuracy: 40),
            makePoint(altitude: 100.5, verticalAccuracy: 4),
            makePoint(altitude: 101.0, verticalAccuracy: 4)
        ]

        let gain = WorkoutElevationGainCalculator.calculate(from: points)

        XCTAssertLessThan(gain ?? 0, 5)
    }

    private func makeNoisyFlatWalkPoints() -> [WorkoutRoutePoint] {
        let altitudes = (0..<240).map { index -> Double in
            let wave = sin(Double(index) / 6.0) * 1.4
            let ripple = cos(Double(index) / 11.0) * 0.9
            return 118.0 + wave + ripple
        }

        return makePoints(altitudes: altitudes)
    }

    private func makePoints(
        altitudes: [Double],
        verticalAccuracy: Double? = 4
    ) -> [WorkoutRoutePoint] {
        altitudes.enumerated().map { index, altitude in
            makePoint(
                altitude: altitude,
                verticalAccuracy: verticalAccuracy,
                index: index
            )
        }
    }

    private func makePoint(
        altitude: Double,
        verticalAccuracy: Double?,
        index: Int = 0
    ) -> WorkoutRoutePoint {
        WorkoutRoutePoint(
            latitude: 48.85 + Double(index) * 0.00001,
            longitude: 2.35 + Double(index) * 0.00001,
            altitude: altitude,
            verticalAccuracy: verticalAccuracy,
            timestamp: Date(timeIntervalSince1970: Double(index))
        )
    }
}
