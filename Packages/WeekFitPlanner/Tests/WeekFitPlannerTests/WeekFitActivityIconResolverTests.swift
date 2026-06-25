import XCTest
@testable import WeekFitPlanner

final class WeekFitActivityIconResolverTests: XCTestCase {

    func testStoredIconTakesPriorityOverCanonicalMatch() {
        let activity = PlannedActivity(
            date: Date(),
            type: "workout",
            title: "Cycling",
            durationMinutes: 60,
            icon: "figure.outdoor.cycle",
            colorRed: 0.4,
            colorGreen: 0.7,
            colorBlue: 0.9
        )

        XCTAssertEqual(WeekFitActivityIconResolver.resolve(for: activity), "figure.outdoor.cycle")
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
}
