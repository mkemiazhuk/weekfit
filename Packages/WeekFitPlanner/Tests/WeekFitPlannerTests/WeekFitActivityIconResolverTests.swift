import XCTest
@testable import WeekFitPlanner

final class WeekFitActivityIconResolverTests: XCTestCase {

    func testStoredSpecificIconKeptWhenNoStrongerCatalogMatch() {
        let activity = PlannedActivity(
            date: Date(),
            type: "custom",
            title: "Mystery Block",
            durationMinutes: 60,
            icon: "star.fill",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9
        )

        XCTAssertEqual(WeekFitActivityIconResolver.resolve(for: activity), "star.fill")
    }

    func testGenericWorkoutIconDoesNotOverrideCyclingTitle() {
        XCTAssertEqual(
            WeekFitActivityIconResolver.resolve(
                storedIcon: "dumbbell.fill",
                title: "Cycling",
                type: "workout",
                imageName: "workout-cycling"
            ),
            "figure.outdoor.cycle"
        )
    }

    func testGenericWorkoutIconDoesNotOverrideCyclingImageNameAlone() {
        XCTAssertEqual(
            WeekFitActivityIconResolver.resolve(
                storedIcon: "dumbbell.fill",
                title: "Endurance Session",
                type: "workout",
                imageName: "workout-cycling"
            ),
            "figure.outdoor.cycle"
        )
    }

    func testAllPlannerWorkoutImageNamesResolve() {
        let expected: [(String, String)] = [
            ("workout-cycling", "figure.outdoor.cycle"),
            ("workout-running", "figure.run"),
            ("workout-swimming", "figure.pool.swim"),
            ("workout-hiking", "figure.hiking"),
            ("workout-strength", "dumbbell.fill"),
            ("workout-core", "figure.core.training"),
            ("workout-lowerbody", "figure.strengthtraining.traditional"),
            ("workout-fullbody", "figure.strengthtraining.functional"),
            ("workout-tennis", "figure.tennis"),
            ("workout-squash", "figure.squash"),
            ("recovery-stretch", "figure.cooldown"),
            ("recovery-walk", "figure.walk"),
            ("recovery-sauna", "flame.fill"),
            ("recovery-yoga", "figure.yoga"),
            ("recovery-breathing", "wind"),
            ("habit-water", "drop.fill"),
            ("habit-sleep", "moon.stars.fill"),
            ("habit-noscreens", "iphone.slash"),
            ("habit-morning", "sun.max.fill")
        ]

        for (imageName, icon) in expected {
            XCTAssertEqual(
                WeekFitActivityIconResolver.preferredIcon(
                    storedIcon: "dumbbell.fill",
                    title: "Anything",
                    type: "workout",
                    imageName: imageName
                ),
                icon,
                "imageName \(imageName)"
            )
        }
    }

    func testCyclingCanonicalUsesOutdoorCycleSymbol() {
        XCTAssertEqual(
            WeekFitActivityIconResolver.canonical(title: "Cycling", type: "workout"),
            "figure.outdoor.cycle"
        )
    }

    func testYogaCanonicalUsesYogaSymbol() {
        XCTAssertEqual(
            WeekFitActivityIconResolver.canonical(title: "Yoga", type: "recovery"),
            "figure.yoga"
        )
    }

    func testStretchingCanonicalUsesCooldownSymbol() {
        XCTAssertEqual(
            WeekFitActivityIconResolver.canonical(title: "Stretching", type: "recovery"),
            "figure.cooldown"
        )
    }

    func testEmptyStoredIconFallsBackThroughResolver() {
        let activity = PlannedActivity(
            date: Date(),
            type: "workout",
            title: "Running",
            durationMinutes: 30,
            icon: "",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9
        )

        XCTAssertEqual(WeekFitActivityIconResolver.resolve(for: activity), "figure.run")
    }

    func testUnknownActivityFallsBackToSparkles() {
        XCTAssertEqual(
            WeekFitActivityIconResolver.resolve(
                storedIcon: nil,
                title: "Mystery Block",
                type: "custom"
            ),
            "sparkles"
        )
    }

    func testHabitUsesCheckmarkCircleWithoutFill() {
        XCTAssertEqual(
            WeekFitActivityIconResolver.canonical(title: "Evening Wind Down", type: "habit"),
            "checkmark.circle"
        )
    }

    func testWaterUsesDropFill() {
        XCTAssertEqual(
            WeekFitActivityIconResolver.canonical(title: "Water", type: "drink"),
            "drop.fill"
        )
    }

    func testStrengthUsesDumbbellFill() {
        XCTAssertEqual(
            WeekFitActivityIconResolver.canonical(title: "Strength Workout", type: "workout"),
            "dumbbell.fill"
        )
    }

    func testRepairRewritesGenericCyclingIcon() {
        let activity = PlannedActivity(
            date: Date(),
            type: "workout",
            title: "Cycling",
            durationMinutes: 60,
            icon: "dumbbell.fill",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )
        activity.imageName = "workout-cycling"

        let repaired = WeekFitActivityIconRepair.repairIcons(in: [activity])

        XCTAssertEqual(repaired, 1)
        XCTAssertEqual(activity.icon, "figure.outdoor.cycle")
    }

    func testRepairIsIdempotentWhenAlreadyCorrect() {
        let activity = PlannedActivity(
            date: Date(),
            type: "workout",
            title: "Running",
            durationMinutes: 40,
            icon: "figure.run",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )
        activity.imageName = "workout-running"

        let repaired = WeekFitActivityIconRepair.repairIcons(in: [activity])

        XCTAssertEqual(repaired, 0)
        XCTAssertEqual(activity.icon, "figure.run")
    }
}
