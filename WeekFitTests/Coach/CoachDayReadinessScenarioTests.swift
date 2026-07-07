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

    func testLowRecoveryPrepMorningDoesNotDuplicateShortSleepWhyRows() throws {
        CoachSessionTracker.resetForTests()
        CoachSessionTracker.setTestFirstOpen(true)

        let morning = date(hour: 8, minute: 0)
        let ride = PlannedActivity(
            date: morning.addingTimeInterval(60 * 60),
            type: "workout",
            title: "Cycling",
            durationMinutes: 210,
            icon: "figure.outdoor.cycle",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )

        let result = evaluate(
            now: morning,
            activities: [ride],
            recovery: CoachRecoveryContext(recoveryPercent: 58, sleepHours: 5.0),
            brainHour: 8,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 0,
                caloriesGoal: 2_800,
                proteinCurrent: 0,
                proteinGoal: 140,
                waterCurrent: 0,
                waterGoal: 2.5
            )
        )
        let pack = try XCTUnwrap(result.copyPack)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.scenario, .lowRecoveryPrep)
        XCTAssertEqual(result.context.conversationPhase, .morningOverview)

        let sleepSignals = pack.supportingSignals.lines.filter {
            $0.russian.hasPrefix("Сон был коротким")
                || $0.english.lowercased().hasPrefix("sleep was short")
        }
        XCTAssertEqual(sleepSignals.count, 1, sleepSignals.map(\.russian).joined(separator: " | "))

        let sleepWhyRows = bridge.whyRows.filter {
            $0.title.hasPrefix("Сон был коротким")
                || $0.title.lowercased().hasPrefix("sleep was short")
        }
        XCTAssertEqual(sleepWhyRows.count, 1, sleepWhyRows.map(\.title).joined(separator: " | "))
        XCTAssertEqual(sleepWhyRows.first?.icon, "moon.zzz.fill")
    }

    func testLowRecoveryPrepTwentyFiveMinutesBeforeLongRideUsesConcreteCopy() throws {
        CoachSessionTracker.resetForTests()
        CoachSessionTracker.setTestFirstOpen(true)

        let now = date(hour: 8, minute: 35)
        let ride = PlannedActivity(
            date: date(hour: 9, minute: 0),
            type: "workout",
            title: "Cycling",
            durationMinutes: 210,
            icon: "figure.outdoor.cycle",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )

        let result = evaluate(
            now: now,
            activities: [ride],
            recovery: CoachRecoveryContext(recoveryPercent: 58, sleepHours: 5.0),
            brainHour: 8,
            nutrition: CoachNutritionContext(
                caloriesCurrent: 0,
                caloriesGoal: 2_800,
                proteinCurrent: 0,
                proteinGoal: 140,
                waterCurrent: 0,
                waterGoal: 2.5
            )
        )
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(result.scenario, .lowRecoveryPrep)

        let assessmentRU = pack.assessment.lines[0].russian
        XCTAssertTrue(assessmentRU.contains("25"), assessmentRU)
        XCTAssertTrue(assessmentRU.contains("мин"), assessmentRU)

        let nextActionRU = pack.nextAction.lines[0].russian
        XCTAssertTrue(
            nextActionRU.lowercased().contains("вод") || nextActionRU.contains("перекус"),
            nextActionRU
        )
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
        focus: PlannedActivity? = nil,
        nutrition: CoachNutritionContext? = nil
    ) -> CoachEngine.Result {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = brainHour
        let resolvedNutrition = nutrition ?? CoachNutritionContext(
            caloriesCurrent: 1_800,
            caloriesGoal: 2_800,
            proteinCurrent: 90,
            proteinGoal: 140,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )
        let input = CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities.coachSnapshots(),
            recoveryContext: recovery,
            nutritionContext: resolvedNutrition,
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
