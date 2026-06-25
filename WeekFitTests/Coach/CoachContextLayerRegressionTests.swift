import XCTest
@testable import WeekFit

/// Locks focus → context → scenario chains after PR2 context audit.
/// Any failure here indicates accidental scenario-routing regression.
final class CoachContextLayerRegressionTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.english)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    // MARK: - Active endurance session

    func testActiveEnduranceSessionRoutesThroughFocusToDuringEndurance() {
        let now = date(hour: 14, minute: 0)
        let ride = PlannedActivity(
            date: now.addingTimeInterval(-25 * 60),
            type: "workout",
            title: "Afternoon Ride",
            durationMinutes: 90,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let input = makeInput(now: now, activities: [ride], brainHour: 14)
        let focus = CoachFocusResolver.resolve(input: input, explicitFocus: ride)
        let result = CoachEngine.evaluate(input: input, focusActivity: ride)

        XCTAssertEqual(focus.source, .active)
        XCTAssertEqual(focus.phase, .during)
        XCTAssertEqual(focus.family, .endurance)
        XCTAssertEqual(result.scenario, .duringEndurance)
        XCTAssertEqual(result.context.sessionPhase, .during)
        XCTAssertTrue(CoachScenarioConsistency.isConsistent(selection: focus, scenario: result.scenario))
    }

    // MARK: - Post-endurance hold

    func testPostEnduranceImmediateWithinSixtyMinuteWindow() {
        let now = date(hour: 14, minute: 0)
        let ride = completedActivity(
            title: "Cycling",
            endedMinutesAgo: 15,
            durationMinutes: 90,
            relativeTo: now,
            icon: "figure.outdoor.cycle"
        )

        let input = makeInput(now: now, activities: [ride], brainHour: 14)
        let focus = CoachFocusResolver.resolve(input: input, explicitFocus: ride)
        let result = CoachEngine.evaluate(input: input, focusActivity: ride)

        XCTAssertEqual(focus.source, .recentCompleted)
        XCTAssertEqual(focus.phase, .immediatePost)
        XCTAssertEqual(result.scenario, CoachScenarioKey.postEnduranceImmediate)
        XCTAssertTrue(CoachScenarioConsistency.isConsistent(selection: focus, scenario: result.scenario))
    }

    func testPostEnduranceImmediateRunningUsesRunChromeNotRide() throws {
        let now = date(hour: 14, minute: 0)
        let run = completedActivity(
            title: "Morning Run",
            endedMinutesAgo: 15,
            durationMinutes: 45,
            relativeTo: now,
            icon: "figure.run"
        )

        let input = makeInput(now: now, activities: [run], brainHour: 14)
        let result = CoachEngine.evaluate(input: input, focusActivity: run)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.scenario, .postEnduranceImmediate)
        XCTAssertEqual(result.modifiers.activityType, .running)
        XCTAssertEqual(bridge.todayTitle, "Пробежка завершена")
        XCTAssertEqual(bridge.coachTitle, "После пробежки")
        XCTAssertFalse(bridge.todayTitle.localizedCaseInsensitiveContains("заезд"))
        XCTAssertFalse(bridge.coachTitle.localizedCaseInsensitiveContains("заезд"))
    }

    // MARK: - Walk after heavy load

    func testWalkAfterHeavyLoadUsesActiveWalkFocusOnHeavyDay() {
        let now = date(hour: 14, minute: 0)
        let walk = PlannedActivity(
            date: now.addingTimeInterval(-5 * 60),
            type: "recovery",
            title: "Afternoon Walk",
            durationMinutes: 30,
            icon: "figure.walk",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let input = makeInput(
            now: now,
            activities: [walk],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 780,
                exerciseMinutes: 95,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 1.4
            ),
            brainHour: 14
        )
        let focus = CoachFocusResolver.resolve(input: input, explicitFocus: walk)
        let result = CoachEngine.evaluate(input: input, focusActivity: walk)

        XCTAssertEqual(focus.source, .active)
        XCTAssertEqual(focus.type, CoachActivityType.walk)
        XCTAssertEqual(result.scenario, CoachScenarioKey.walkAfterHeavyLoad)
        XCTAssertTrue(CoachScenarioConsistency.isConsistent(selection: focus, scenario: result.scenario))
    }

    // MARK: - Sauna / recovery modality

    func testSaunaRecoveryWithinHeatWindow() {
        let now = date(hour: 18, minute: 0)
        var sauna = completedActivity(
            title: "Sauna",
            endedMinutesAgo: 10,
            durationMinutes: 25,
            relativeTo: now
        )
        sauna.type = "sauna"

        let input = makeInput(now: now, activities: [sauna], brainHour: 18)
        let focus = CoachFocusResolver.resolve(input: input, explicitFocus: sauna)
        let result = CoachEngine.evaluate(input: input, focusActivity: sauna)

        XCTAssertEqual(focus.family, CoachActivityFamily.heat)
        XCTAssertEqual(result.scenario, CoachScenarioKey.saunaRecovery)
        XCTAssertEqual(result.context.minutesSinceEnd, 10)
        XCTAssertTrue(CoachScenarioConsistency.isConsistent(selection: focus, scenario: result.scenario))
    }

    func testActiveSaunaRoutesToSaunaActive() {
        let now = date(hour: 18, minute: 0)
        let sauna = PlannedActivity(
            date: now.addingTimeInterval(-10 * 60),
            type: "recovery",
            title: "Sauna",
            durationMinutes: 20,
            icon: "flame.fill",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let input = makeInput(now: now, activities: [sauna], brainHour: 18)
        let focus = CoachFocusResolver.resolve(input: input, explicitFocus: sauna)
        let result = CoachEngine.evaluate(input: input, focusActivity: sauna)

        XCTAssertEqual(focus.source, .active)
        XCTAssertEqual(result.scenario, .saunaActive)
        XCTAssertTrue(CoachScenarioConsistency.isConsistent(selection: focus, scenario: result.scenario))
    }

    // MARK: - Tomorrow long endurance protection

    func testTomorrowLongEnduranceProtectionEveningHeavyDay() {
        let evening = date(hour: 20, minute: 15)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!
        let completedRide = PlannedActivityBuilder.workout(
            title: "Long Ride",
            at: CoachTestClock.offset(hours: -8, from: evening),
            durationMinutes: 180,
            completed: true
        )
        let tomorrowRun = PlannedActivity(
            date: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!,
            type: "workout",
            title: "Long Run",
            durationMinutes: 90,
            icon: "figure.run",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let input = makeInput(
            now: evening,
            activities: [completedRide, tomorrowRun],
            actualLoad: heavyActualLoad(),
            brainHour: 20
        )
        let focus = CoachFocusResolver.resolve(input: input, explicitFocus: completedRide)
        let result = CoachEngine.evaluate(input: input, focusActivity: completedRide)

        XCTAssertEqual(result.scenario, .tomorrowProtection)
        XCTAssertEqual(result.context.sessionPhase, .tomorrowProtection)
        XCTAssertTrue(CoachScenarioConsistency.isConsistent(selection: focus, scenario: result.scenario))
    }

    // MARK: - Stable day: hydration/fuel as support only

    func testStableDayKeepsScenarioWithFuelAndHydrationInSupportingSignalsOnly() throws {
        let now = date(hour: 14, minute: 0)
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 2_800,
            proteinCurrent: 25,
            proteinGoal: 140,
            waterCurrent: 0.9,
            waterGoal: 2.5
        )

        let input = makeInput(now: now, activities: [], nutrition: nutrition, brainHour: 14)
        let focus = CoachFocusResolver.resolve(input: input)
        let result = CoachEngine.evaluate(input: input)
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(focus.source, .idle)
        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertTrue(result.modifiers.fuelBehind)
        XCTAssertTrue(result.modifiers.hydrationBehind)
        XCTAssertNil(result.resolution.safetyAlert)

        let assessmentText = pack.assessment.lines.map(\.english).joined(separator: " ").lowercased()
        XCTAssertFalse(assessmentText.contains("water") && assessmentText.contains("urgent"))
        XCTAssertFalse(assessmentText.contains("calorie") && assessmentText.contains("urgent"))

        let signalsText = pack.supportingSignals.lines.map(\.english).joined(separator: " ").lowercased()
        XCTAssertTrue(signalsText.contains("water") || signalsText.contains("fuel") || signalsText.contains("calorie"))
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

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    private func makeInput(
        now: Date,
        activities: [PlannedActivity],
        nutrition: CoachNutritionContext? = nil,
        actualLoad: CoachActualLoadSnapshot? = nil,
        brainHour: Int = 14
    ) -> CoachInputSnapshot {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = brainHour

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities,
            actualLoad: actualLoad ?? CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 200,
                exerciseMinutes: 20,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 0.4
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutritionContext: nutrition ?? defaultNutrition(),
            source: "CoachContextLayerRegressionTests"
        )
    }

    private func defaultNutrition() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 1_400,
            caloriesGoal: 2_800,
            proteinCurrent: 80,
            proteinGoal: 140,
            waterCurrent: 1.6,
            waterGoal: 2.5
        )
    }

    private func completedActivity(
        title: String,
        endedMinutesAgo: Int,
        durationMinutes: Int,
        relativeTo now: Date,
        type: String = "workout",
        icon: String = "figure.run"
    ) -> PlannedActivity {
        let end = now.addingTimeInterval(-TimeInterval(endedMinutesAgo * 60))
        let start = end.addingTimeInterval(-TimeInterval(durationMinutes * 60))
        return PlannedActivity(
            date: start,
            type: type,
            title: title,
            durationMinutes: durationMinutes,
            icon: icon,
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: true
        )
    }
}
