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

    func testWalkLikeDetectsRussianTitleWithoutEnglishTokens() {
        let activity = CoachActivityDescriptor(
            type: "workout",
            title: "Прогулка",
            icon: "figure.walk",
            imageName: "figure.walk"
        )
        XCTAssertTrue(CoachActivityClassification.isWalkLike(activity))
        XCTAssertTrue(CoachActivityClassification.isRecoveryTier(activity))
        XCTAssertFalse(CoachActivityClassification.isSignificantWorkout(activity))
    }

    func testWalkLikeDetectsEnglishWalkingType() {
        let activity = CoachActivityDescriptor(
            type: "walking",
            title: "Morning Walk",
            icon: "figure.walk",
            imageName: "figure.walk"
        )
        XCTAssertTrue(CoachActivityClassification.isWalkLike(activity))
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
