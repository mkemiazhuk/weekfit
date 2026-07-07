import XCTest
@testable import WeekFit

/// Locks `CoachActivityClassifier` as the single taxonomy source and verifies
/// legacy `CoachActivityKind` bridge parity for edge cases called out in the audit.
final class CoachActivityClassifierParityTests: XCTestCase {

    func testContextResolverDelegatesToClassifier() {
        let tennis = makeActivity(title: "Tennis Match", type: "workout", icon: "figure.tennis")
        XCTAssertEqual(
            CoachActivityContextResolver.kind(for: tennis),
            CoachActivityClassifier.coachKind(for: tennis)
        )
        XCTAssertEqual(
            CoachActivityContextResolver.load(for: tennis),
            CoachActivityClassifier.coachLoad(for: tennis)
        )
    }

    func testTennisMapsToRacketTypeAndWorkoutKind() {
        let tennis = makeActivity(title: "Tennis", type: "workout", icon: "figure.tennis")

        XCTAssertEqual(CoachActivityClassifier.type(for: tennis), .tennis)
        XCTAssertEqual(CoachActivityClassifier.family(for: tennis), .racket)
        XCTAssertEqual(CoachActivityClassifier.coachKind(for: tennis), .workout)
        XCTAssertTrue(CoachActivityClassifier.isSeriousTraining(tennis))
    }

    func testSquashMapsToRacketTypeAndWorkoutKind() {
        let squash = makeActivity(title: "Squash Session", type: "workout")

        XCTAssertEqual(CoachActivityClassifier.type(for: squash), .squash)
        XCTAssertEqual(CoachActivityClassifier.family(for: squash), .racket)
        XCTAssertEqual(CoachActivityClassifier.coachKind(for: squash), .workout)
    }

    func testWalkMapsToRecoveryTypeAndKind() {
        let walk = makeActivity(title: "Evening Walk", type: "recovery", icon: "figure.walk")

        XCTAssertEqual(CoachActivityClassifier.type(for: walk), .walk)
        XCTAssertEqual(CoachActivityClassifier.family(for: walk), .recovery)
        XCTAssertEqual(CoachActivityClassifier.coachKind(for: walk), .recovery)
        XCTAssertFalse(CoachActivityClassifier.isSeriousTraining(walk))
    }

    func testHikeMapsToWalkTypeAndRecoveryKind() {
        let hike = makeActivity(title: "Mountain Hike", type: "workout", icon: "figure.hiking")

        XCTAssertEqual(CoachActivityClassifier.type(for: hike), .walk)
        XCTAssertEqual(CoachActivityClassifier.coachKind(for: hike), .recovery)
    }

    func testSaunaMapsToHeatTypeAndKind() {
        var sauna = makeActivity(title: "Sauna", type: "recovery", icon: "flame.fill")
        sauna.type = "sauna"

        XCTAssertEqual(CoachActivityClassifier.type(for: sauna), .sauna)
        XCTAssertEqual(CoachActivityClassifier.family(for: sauna), .heat)
        XCTAssertEqual(CoachActivityClassifier.coachKind(for: sauna), .heat)
    }

    func testHotYogaMapsToHeatKindDespiteYogaType() {
        let hotYoga = makeActivity(title: "Hot Yoga", type: "recovery")

        XCTAssertEqual(CoachActivityClassifier.type(for: hotYoga), .yoga)
        XCTAssertEqual(CoachActivityClassifier.coachKind(for: hotYoga), .heat)
    }

    func testSwimMapsToEnduranceKindWithoutPollutingActivityType() {
        let swim = makeActivity(title: "Pool Swimming", type: "workout", icon: "figure.pool.swim")

        XCTAssertEqual(CoachActivityClassifier.type(for: swim), .none)
        XCTAssertEqual(CoachActivityClassifier.coachKind(for: swim), .endurance)
        XCTAssertTrue(CoachTomorrowDemandResolver.isTraining(swim))
    }

    func testCyclingMapsConsistentlyAcrossTaxonomies() {
        let ride = makeActivity(title: "Long Ride", type: "workout", icon: "figure.outdoor.cycle", durationMinutes: 120)

        XCTAssertEqual(CoachActivityClassifier.type(for: ride), .cycling)
        XCTAssertEqual(CoachActivityClassifier.family(for: ride), .endurance)
        XCTAssertEqual(CoachActivityClassifier.coachKind(for: ride), .endurance)
        XCTAssertEqual(CoachActivityClassifier.coachLoad(for: ride), .high)
    }

    func testActivityCaloriesUsesStoredValue() {
        var activity = makeActivity(title: "Ride", type: "workout")
        activity.calories = 842

        XCTAssertEqual(CoachActivityClassifier.activityCalories(for: activity), 842)
        XCTAssertEqual(CoachActivityContextResolver.activityCalories(activity), 842)
    }

    // MARK: - Helpers

    private func makeActivity(
        title: String,
        type: String,
        icon: String = "figure.run",
        durationMinutes: Int = 60
    ) -> PlannedActivity {
        PlannedActivity(
            date: CoachTestClock.reference,
            type: type,
            title: title,
            durationMinutes: durationMinutes,
            icon: icon,
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )
    }
}
