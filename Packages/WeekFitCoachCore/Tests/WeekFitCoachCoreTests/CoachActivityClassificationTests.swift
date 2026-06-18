import XCTest
@testable import WeekFitCoachCore

final class CoachActivityClassificationTests: XCTestCase {
    func testRecoveryTierDetectsYoga() {
        let activity = CoachActivityDescriptor(
            type: "workout",
            title: "Morning Yoga",
            icon: "yoga",
            imageName: "yoga"
        )
        XCTAssertTrue(CoachActivityClassification.isRecoveryTier(activity))
        XCTAssertFalse(CoachActivityClassification.isSignificantWorkout(activity))
    }

    func testSignificantWorkoutDetectsRunning() {
        let activity = CoachActivityDescriptor(
            type: "workout",
            title: "Easy Run",
            icon: "run",
            imageName: "running"
        )
        XCTAssertFalse(CoachActivityClassification.isRecoveryTier(activity))
        XCTAssertTrue(CoachActivityClassification.isSignificantWorkout(activity))
    }
}
