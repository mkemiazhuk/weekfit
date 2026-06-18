import HealthKit
import XCTest
@testable import WeekFitWorkoutMetrics

final class WorkoutElevationGainResolverTests: XCTestCase {

    func testUsesWorkoutMetadataWhenAvailable() {
        let metadata: [String: Any] = [
            HKMetadataKeyElevationAscended: HKQuantity(unit: .meter(), doubleValue: 18)
        ]

        let gain = WorkoutElevationGainResolver.fromWorkoutMetadata(metadata)

        XCTAssertEqual(gain, 18)
    }

    func testIgnoresMissingOrZeroMetadata() {
        XCTAssertNil(WorkoutElevationGainResolver.fromWorkoutMetadata(nil))
        XCTAssertNil(
            WorkoutElevationGainResolver.fromWorkoutMetadata([
                HKMetadataKeyElevationAscended: HKQuantity(unit: .meter(), doubleValue: 0)
            ])
        )
    }
}
