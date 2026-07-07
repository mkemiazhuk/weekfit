import XCTest
@testable import WeekFit

final class CoachNutritionPaceTests: XCTestCase {

    func testMorningProgressOnPaceDoesNotFlagFuelOrHydrationBehind() {
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 630,
            caloriesGoal: 2_030,
            proteinCurrent: 32,
            proteinGoal: 153,
            waterCurrent: 0.5,
            waterGoal: 3.2
        )

        XCTAssertEqual(
            CoachNutritionPace.fuelState(
                nutrition: nutrition,
                hour: 9,
                activityFamily: .strength,
                durationBand: .short
            ),
            .adequate
        )
        XCTAssertEqual(
            CoachNutritionPace.hydrationState(
                nutrition: nutrition,
                hour: 9,
                activityFamily: .strength,
                durationBand: .short,
                activityState: .upcoming
            ),
            .adequate
        )
    }

    func testLowRecoveryPrepMorningSuppressesNutritionWhyRows() throws {
        let now = date(hour: 9, minute: 30)
        let core = PlannedActivityBuilder.workout(
            title: "Core",
            at: now.addingTimeInterval(60 * 60),
            durationMinutes: 45,
            completed: false
        )
        let walk = PlannedActivityBuilder.workout(
            title: "Walk",
            at: now.addingTimeInterval(-58 * 60),
            durationMinutes: 55,
            completed: true
        )

        let result = CoachEngine.evaluate(
            input: CoachInputSnapshot(
                selectedDate: now,
                now: now,
                brain: {
                    var config = HumanBrainStateBuilder.Configuration()
                    config.currentHour = 9
                    return HumanBrainStateBuilder.make(config)
                }(),
                plannedActivities: [walk, core].coachSnapshots(),
                actualLoad: CoachActualLoadSnapshot(
                    source: .healthKitSamplesWithAppGoalEstimate,
                    activeCalories: 342,
                    exerciseMinutes: 55,
                    standHours: nil,
                    activityGoalCalories: 560,
                    activityProgress: 0.61
                ),
                recoveryContext: CoachRecoveryContext(recoveryPercent: 75, sleepHours: 5.0),
                nutritionContext: CoachNutritionContext(
                    caloriesCurrent: 630,
                    caloriesGoal: 2_030,
                    proteinCurrent: 32,
                    proteinGoal: 153,
                    waterCurrent: 0.5,
                    waterGoal: 3.2
                ),
                source: "CoachNutritionPaceTests"
            )
        )
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(result.scenario, .lowRecoveryPrep)
        XCTAssertFalse(result.modifiers.fuelBehind)
        XCTAssertFalse(result.modifiers.hydrationBehind)

        let whyText = pack.supportingSignals.lines
            .flatMap { [$0.english.lowercased(), $0.russian.lowercased()] }
            .joined(separator: " ")
        XCTAssertFalse(whyText.contains("fuel") || whyText.contains("water") || whyText.contains("ед"))
        XCTAssertFalse(whyText.contains("вод"))
        XCTAssertTrue(whyText.contains("sleep") || whyText.contains("сон"))
    }

    func testAfternoonLowFuelStillFlagsBehind() {
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 2_800,
            proteinCurrent: 25,
            proteinGoal: 140,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )

        XCTAssertEqual(
            CoachNutritionPace.fuelState(
                nutrition: nutrition,
                hour: 14,
                activityFamily: .none,
                durationBand: .short
            ),
            .behind
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
