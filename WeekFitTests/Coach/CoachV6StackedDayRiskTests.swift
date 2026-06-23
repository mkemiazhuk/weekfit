import XCTest
@testable import WeekFit

final class CoachV6StackedDayRiskTests: XCTestCase {

    private let defaultColors = (r: 0.2, g: 0.6, b: 0.9)

    func testActiveStrengthOnHeavyDayWithTomorrowUsesStackedRiskPresentation() throws {
        let lateEvening = date(hour: 22, minute: 30)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: lateEvening)!

        let completedRide = PlannedActivityBuilder.workout(
            title: "Long Ride",
            at: CoachTestClock.offset(hours: -10, from: lateEvening),
            durationMinutes: 180,
            completed: true
        )
        let tomorrowCore = PlannedActivity(
            date: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: tomorrow)!,
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b
        )
        let activeCore = PlannedActivity(
            date: CoachTestClock.offset(minutes: -8, from: lateEvening),
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b
        )

        let result = CoachV6Engine.evaluate(
            input: makeInput(
                now: lateEvening,
                activities: [completedRide, activeCore, tomorrowCore],
                actualLoad: heavyActualLoad(),
                brainHour: 22
            ),
            focusActivity: activeCore
        )

        XCTAssertEqual(result.scenario, .duringStrength)
        XCTAssertTrue(result.modifiers.stackedDayActiveRisk)
        XCTAssertEqual(result.todayInsight.semanticColor, .risk)
        XCTAssertEqual(result.todayInsight.alertSeverity, .critical)
        XCTAssertEqual(result.todayInsight.urgencyLevel, .critical)

        let pack = try XCTUnwrap(result.copyPack)
        XCTAssertTrue(pack.recommendation.lines.first?.english.contains("stop") == true)
        XCTAssertTrue(pack.nextAction.lines.first?.english.contains("15") == true)

        let bridge = try XCTUnwrap(CoachV6TabPresentationBridge.build(from: result))
        XCTAssertTrue(
            bridge.today.title.localizedCaseInsensitiveContains("нагрузка") ||
                bridge.today.title.localizedCaseInsensitiveContains("Too much")
        )
        XCTAssertTrue(
            bridge.today.message.localizedCaseInsensitiveContains("закончить") ||
                bridge.today.message.localizedCaseInsensitiveContains("stop")
        )
    }

    func testMiddayEnduranceWithoutTomorrowDemandIsNotStackedRisk() {
        let now = CoachTestClock.reference
        let cycling = PlannedActivity(
            date: CoachTestClock.offset(minutes: -30, from: now),
            type: "workout",
            title: "100 km Cycling",
            durationMinutes: 360,
            icon: "figure.outdoor.cycle",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b,
            calories: 900
        )

        let result = CoachV6Engine.evaluate(
            input: makeInput(
                now: now,
                activities: [cycling],
                actualLoad: heavyActualLoad(),
                brainHour: 14
            ),
            focusActivity: cycling
        )

        XCTAssertEqual(result.scenario, .duringEndurance)
        XCTAssertFalse(result.modifiers.stackedDayActiveRisk)
        XCTAssertEqual(result.todayInsight.semanticColor, .live)
    }

    func testStackedRiskCopyAuditIsClean() throws {
        let lateEvening = date(hour: 22, minute: 30)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: lateEvening)!

        let completedRide = PlannedActivityBuilder.workout(
            title: "Long Ride",
            at: CoachTestClock.offset(hours: -10, from: lateEvening),
            durationMinutes: 180,
            completed: true
        )
        let tomorrowCore = PlannedActivity(
            date: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: tomorrow)!,
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b
        )
        let activeCore = PlannedActivity(
            date: CoachTestClock.offset(minutes: -8, from: lateEvening),
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b
        )

        let result = CoachV6Engine.evaluate(
            input: makeInput(
                now: lateEvening,
                activities: [completedRide, activeCore, tomorrowCore],
                actualLoad: heavyActualLoad(),
                brainHour: 22
            ),
            focusActivity: activeCore
        )

        let pack = try XCTUnwrap(result.copyPack)
        let input = CoachV6CopyBuildInput.from(result: result)
        let report = CoachV6CopyQualityAudit.audit(pack: pack, input: input)
        XCTAssertTrue(report.isClean, report.violations.joined(separator: "; "))
    }

    // MARK: - Helpers

    private func heavyActualLoad() -> CoachActualLoadSnapshot {
        CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 2_758,
            exerciseMinutes: 282,
            standHours: 11,
            activityGoalCalories: 700,
            activityProgress: 3.94
        )
    }

    private func makeInput(
        now: Date,
        activities: [PlannedActivity],
        actualLoad: CoachActualLoadSnapshot,
        brainHour: Int
    ) -> CoachInputSnapshot {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = brainHour

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities,
            actualLoad: actualLoad,
            recoveryContext: CoachRecoveryContext(recoveryPercent: 80, sleepHours: 7.0),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 1_019,
                caloriesGoal: 2_800,
                proteinCurrent: 75,
                proteinGoal: 153,
                waterCurrent: 2.5,
                waterGoal: 4.9
            ),
            source: "CoachV6StackedDayRiskTests"
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
