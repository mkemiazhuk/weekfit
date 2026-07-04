import XCTest
@testable import WeekFit

final class CoachDayReadinessScenarioTests: XCTestCase {

    func testGoodRecoveryHardTomorrowMorningUsesProtectTomorrowFresh() {
        let morning = date(hour: 7, minute: 30)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: morning)!
        let tomorrowRun = PlannedActivityBuilder.workout(
            title: "Long Run",
            at: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!,
            durationMinutes: 90
        )

        let result = evaluate(
            now: morning,
            activities: [tomorrowRun],
            recovery: CoachRecoveryContext(recoveryPercent: 90, sleepHours: 8),
            brainHour: 7
        )

        XCTAssertEqual(result.scenario, .protectTomorrowFresh)
        XCTAssertNotNil(result.copyPack)
    }

    func testLowRecoveryUpcomingRideUsesLowRecoveryPrep() {
        let now = date(hour: 13, minute: 0)
        let ride = PlannedActivity(
            date: now.addingTimeInterval(60 * 60),
            type: "workout",
            title: "Afternoon Ride",
            durationMinutes: 90,
            icon: "figure.outdoor.cycle",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )

        let result = evaluate(
            now: now,
            activities: [ride],
            recovery: CoachRecoveryContext(recoveryPercent: 35, sleepHours: 4.5),
            brainHour: 13
        )

        XCTAssertEqual(result.scenario, .lowRecoveryPrep)
    }

    func testLowRecoveryDuringRideKeepsDuringEndurance() {
        let now = date(hour: 14, minute: 0)
        let ride = PlannedActivity(
            date: now.addingTimeInterval(-25 * 60),
            type: "workout",
            title: "Ride",
            durationMinutes: 90,
            icon: "figure.outdoor.cycle",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )

        let result = evaluate(
            now: now,
            activities: [ride],
            recovery: CoachRecoveryContext(recoveryPercent: 35, sleepHours: 4.5),
            brainHour: 14,
            focus: ride
        )

        XCTAssertEqual(result.scenario, .duringEndurance)
    }

    private func evaluate(
        now: Date,
        activities: [PlannedActivity],
        recovery: CoachRecoveryContext,
        brainHour: Int,
        focus: PlannedActivity? = nil
    ) -> CoachEngine.Result {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = brainHour
        let input = CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities.coachSnapshots(),
            recoveryContext: recovery,
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_800,
                proteinCurrent: 90,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            source: "CoachDayReadinessScenarioTests"
        )
        return CoachEngine.evaluate(input: input, focusActivity: focus)
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
