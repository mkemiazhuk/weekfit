import XCTest
@testable import WeekFit

final class DayTrainingTypeClassifierTests: XCTestCase {

    func testWalkIsRecovery() {
        XCTAssertEqual(
            classify([recovery("Walk", imageName: "recovery-walk")]),
            .recovery
        )
    }

    func testWalkPlusSaunaIsRecovery() {
        XCTAssertEqual(
            classify([
                recovery("Walk", imageName: "recovery-walk"),
                recovery("Sauna", imageName: "recovery-sauna")
            ]),
            .recovery
        )
    }

    func testCyclingIsEndurance() {
        XCTAssertEqual(
            classify([workout("Cycling", imageName: "workout-cycling")]),
            .endurance
        )
    }

    func testCyclingPlusWalkIsEndurance() {
        XCTAssertEqual(
            classify([
                workout("Cycling", imageName: "workout-cycling"),
                recovery("Walk", imageName: "recovery-walk")
            ]),
            .endurance
        )
    }

    func testCyclingPlusSaunaIsEndurance() {
        XCTAssertEqual(
            classify([
                workout("Cycling", imageName: "workout-cycling"),
                recovery("Sauna", imageName: "recovery-sauna")
            ]),
            .endurance
        )
    }

    func testFullBodyIsStrength() {
        XCTAssertEqual(
            classify([workout("Full Body", imageName: "workout-fullbody")]),
            .strength
        )
    }

    func testFullBodyPlusWalkIsStrength() {
        XCTAssertEqual(
            classify([
                workout("Full Body", imageName: "workout-fullbody"),
                recovery("Walk", imageName: "recovery-walk")
            ]),
            .strength
        )
    }

    func testCyclingPlusFullBodyIsMixed() {
        XCTAssertEqual(
            classify([
                workout("Cycling", imageName: "workout-cycling"),
                workout("Full Body", imageName: "workout-fullbody")
            ]),
            .mixed
        )
    }

    func testCyclingPlusFullBodyPlusSaunaIsMixed() {
        XCTAssertEqual(
            classify([
                workout("Cycling", imageName: "workout-cycling"),
                workout("Full Body", imageName: "workout-fullbody"),
                recovery("Sauna", imageName: "recovery-sauna")
            ]),
            .mixed
        )
    }

    func testWalkPlusCoreIsStrengthNotMixed() {
        XCTAssertEqual(
            classify([
                recovery("Walk", imageName: "recovery-walk"),
                workout("Core", imageName: "workout-core")
            ]),
            .strength
        )
    }

    func testMealsOnlyReturnsNil() {
        XCTAssertNil(
            DayTrainingTypeClassifier.classify(activities: [
                makeActivity(type: "meal", title: "Lunch", imageName: "")
            ])
        )
    }

    private func classify(_ activities: [PlannedActivity]) -> DayTrainingType? {
        DayTrainingTypeClassifier.classify(activities: activities)
    }

    private func workout(_ title: String, imageName: String) -> PlannedActivity {
        makeActivity(type: "workout", title: title, imageName: imageName)
    }

    private func recovery(_ title: String, imageName: String) -> PlannedActivity {
        makeActivity(type: "recovery", title: title, imageName: imageName)
    }

    private func makeActivity(type: String, title: String, imageName: String) -> PlannedActivity {
        PlannedActivity(
            date: Date(),
            type: type,
            title: title,
            durationMinutes: 30,
            icon: "figure.run",
            imageName: imageName,
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9
        )
    }
}

final class PlanDayKindResolverTests: XCTestCase {

    func testMapsStrengthToLoadForExistingUI() {
        let activities = [
            PlannedActivity(
                date: Date(),
                type: "workout",
                title: "Full Body",
                durationMinutes: 45,
                icon: "dumbbell.fill",
                imageName: "workout-fullbody",
                colorRed: 0.4,
                colorGreen: 0.7,
                colorBlue: 0.9
            )
        ]

        XCTAssertEqual(PlanDayKindResolver.resolve(activities: activities), .load)
    }

    func testEmptyDayIsOpen() {
        XCTAssertEqual(PlanDayKindResolver.resolve(activities: []), .open)
    }

    func testMealsOnlyDayIsOpen() {
        let activities = [
            PlannedActivity(
                date: Date(),
                type: "meal",
                title: "Lunch",
                durationMinutes: 15,
                icon: "fork.knife",
                colorRed: 0.4,
                colorGreen: 0.7,
                colorBlue: 0.9
            )
        ]

        XCTAssertEqual(PlanDayKindResolver.resolve(activities: activities), .open)
    }

    func testMixedMapsToMixedPresentation() {
        let activities = [
            PlannedActivity(
                date: Date(),
                type: "workout",
                title: "Cycling",
                durationMinutes: 60,
                icon: "figure.outdoor.cycle",
                imageName: "workout-cycling",
                colorRed: 0.4,
                colorGreen: 0.7,
                colorBlue: 0.9
            ),
            PlannedActivity(
                date: Date(),
                type: "workout",
                title: "Full Body",
                durationMinutes: 45,
                icon: "dumbbell.fill",
                imageName: "workout-fullbody",
                colorRed: 0.4,
                colorGreen: 0.7,
                colorBlue: 0.9
            )
        ]

        XCTAssertEqual(PlanDayKindResolver.resolve(activities: activities), .mixed)
    }
}
