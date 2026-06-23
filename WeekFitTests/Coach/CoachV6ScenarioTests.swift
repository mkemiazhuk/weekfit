import XCTest
@testable import WeekFit

final class CoachV6ScenarioTests: XCTestCase {

    private let defaultColors = (r: 0.2, g: 0.6, b: 0.9)

    // MARK: - Guard: nutrition never changes scenario

    func testEnduranceHydrationBehindKeepsEnduranceScenario() {
        let now = CoachTestClock.reference
        let cyclingStart = CoachTestClock.offset(minutes: -90, from: now)
        let cycling = cyclingActivity(
            title: "100 km Cycling",
            start: cyclingStart,
            durationMinutes: 360
        )

        let nutrition = CoachNutritionContext(
            caloriesCurrent: 2_000,
            caloriesGoal: 3_000,
            proteinCurrent: 100,
            proteinGoal: 150,
            waterCurrent: 1.06,
            waterGoal: 2.5
        )

        let input = makeInput(
            now: now,
            activities: [cycling],
            nutrition: nutrition,
            brainHour: 14
        )

        let result = CoachV6Engine.evaluate(input: input, focusActivity: cycling)

        XCTAssertEqual(result.scenario, .duringEndurance)
        XCTAssertEqual(result.modifiers.activityType, .cycling)
        XCTAssertTrue(result.modifiers.hydrationBehind)
        XCTAssertNil(result.resolution.safetyAlert)
        XCTAssertEqual(result.todayInsight.alertSeverity, .elevated)
        XCTAssertEqual(result.todayInsight.semanticColor, .live)
        XCTAssertEqual(
            result.scenario,
            CoachV6ScenarioResolver.primaryScenarioIgnoringNutrition(result.context)
        )
    }

    func testEnduranceHydrationCriticalAddsSafetyAlertWithoutChangingScenario() {
        let now = CoachTestClock.reference
        let cyclingStart = CoachTestClock.offset(minutes: -90, from: now)
        let cycling = cyclingActivity(
            title: "100 km Cycling",
            start: cyclingStart,
            durationMinutes: 360
        )

        let nutrition = CoachNutritionContext(
            caloriesCurrent: 2_000,
            caloriesGoal: 3_000,
            proteinCurrent: 100,
            proteinGoal: 150,
            waterCurrent: 0.4,
            waterGoal: 2.5
        )

        let input = makeInput(
            now: now,
            activities: [cycling],
            nutrition: nutrition,
            brainHour: 14
        )

        let result = CoachV6Engine.evaluate(input: input, focusActivity: cycling)

        XCTAssertEqual(result.scenario, .duringEndurance)
        XCTAssertEqual(result.resolution.safetyAlert, .hydrationCritical)
        XCTAssertEqual(result.todayInsight.alertSeverity, .critical)
        XCTAssertEqual(result.todayInsight.semanticColor, .live)
        XCTAssertEqual(result.todayInsight.urgencyLevel, .critical)
    }

    func testFuelBehindOnStableDayDoesNotBecomeMainScenario() {
        let now = CoachTestClock.reference
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 2_800,
            proteinCurrent: 25,
            proteinGoal: 140,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )

        let input = makeInput(now: now, activities: [], nutrition: nutrition, brainHour: 14)
        let result = CoachV6Engine.evaluate(input: input)

        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertTrue(result.modifiers.fuelBehind)
        XCTAssertEqual(result.todayInsight.semanticColor, .stable)
        XCTAssertEqual(result.todayInsight.alertSeverity, .elevated)
        XCTAssertNil(result.resolution.safetyAlert)
    }

    func testFuelBehindDoesNotChangeScenarioVersusAdequateNutrition() {
        let now = CoachTestClock.reference
        let cyclingStart = CoachTestClock.offset(minutes: -30, from: now)
        let cycling = cyclingActivity(title: "Ride", start: cyclingStart, durationMinutes: 120)

        let adequate = CoachNutritionContext(
            caloriesCurrent: 2_000,
            caloriesGoal: 3_000,
            proteinCurrent: 100,
            proteinGoal: 150,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )
        let behind = CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 3_000,
            proteinCurrent: 30,
            proteinGoal: 150,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )

        let baseline = CoachV6Engine.evaluate(
            input: makeInput(now: now, activities: [cycling], nutrition: adequate, brainHour: 14),
            focusActivity: cycling
        )
        let withFuelBehind = CoachV6Engine.evaluate(
            input: makeInput(now: now, activities: [cycling], nutrition: behind, brainHour: 14),
            focusActivity: cycling
        )

        XCTAssertEqual(baseline.scenario, withFuelBehind.scenario)
        XCTAssertFalse(baseline.modifiers.fuelBehind)
        XCTAssertTrue(withFuelBehind.modifiers.fuelBehind)
    }

    // MARK: - Day-level scenarios

    func testMorningFreshNoActivityReturnsMorningReadiness() {
        let morning = date(hour: 7, minute: 30)
        let input = makeInput(now: morning, activities: [], brainHour: 7)

        let result = CoachV6Engine.evaluate(input: input)

        XCTAssertEqual(result.scenario, .morningReadiness)
        XCTAssertEqual(result.modifiers.dayLoad, .fresh)
        XCTAssertEqual(result.todayInsight.semanticColor, .ready)
    }

    func testHeavyDayEveningHardTomorrowReturnsTomorrowProtection() {
        let evening = date(hour: 19, minute: 15)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!

        let completedRide = PlannedActivityBuilder.workout(
            title: "Morning Ride",
            at: CoachTestClock.offset(hours: -10, from: evening),
            durationMinutes: 120,
            completed: true
        )
        let tomorrowRun = PlannedActivityBuilder.workout(
            title: "Long Run",
            at: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!,
            durationMinutes: 90
        )

        let input = makeInput(
            now: evening,
            activities: [completedRide, tomorrowRun],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 850,
                exerciseMinutes: 110,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 1.6
            ),
            brainHour: 19
        )

        let result = CoachV6Engine.evaluate(input: input)

        XCTAssertEqual(result.scenario, .tomorrowProtection)
        XCTAssertTrue(result.modifiers.dayLoad == .heavy || result.modifiers.dayLoad == .extreme)
        XCTAssertEqual(result.modifiers.tomorrowDemand, .hard)
        XCTAssertEqual(result.todayInsight.semanticColor, .protection)
        XCTAssertEqual(result.todayInsight.urgencyLevel, .protective)
    }

    // MARK: - Walk scenarios

    func testWalkAfterHeavyLoad() {
        let now = CoachTestClock.reference
        let walkStart = CoachTestClock.offset(minutes: -5, from: now)
        let walk = walkActivity(start: walkStart, title: "Afternoon Walk")

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

        let result = CoachV6Engine.evaluate(input: input, focusActivity: walk)

        XCTAssertEqual(result.scenario, .walkAfterHeavyLoad)
        XCTAssertEqual(result.todayInsight.semanticColor, .recovery)
    }

    func testWalkEveningReturnsWalkEveningWindDown() {
        let evening = date(hour: 19, minute: 30)
        let walkStart = CoachTestClock.offset(minutes: -10, from: evening)
        let walk = walkActivity(start: walkStart, title: "Evening Walk")

        let input = makeInput(
            now: evening,
            activities: [walk],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 200,
                exerciseMinutes: 25,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 0.4
            ),
            brainHour: 19
        )

        let result = CoachV6Engine.evaluate(input: input, focusActivity: walk)

        XCTAssertEqual(result.scenario, .walkEveningWindDown)
        XCTAssertEqual(result.todayInsight.semanticColor, .stable)
        XCTAssertEqual(result.todayInsight.icon, "figure.walk")
    }

    func testHeavyDayWithTomorrowMorningWorkoutUsesTomorrowProtection() throws {
        let evening = date(hour: 20, minute: 15)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!

        let completedRide = PlannedActivityBuilder.workout(
            title: "Long Ride",
            at: CoachTestClock.offset(hours: -8, from: evening),
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

        let input = makeInput(
            now: evening,
            activities: [completedRide, tomorrowCore],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 2_758,
                exerciseMinutes: 282,
                standHours: 11,
                activityGoalCalories: 700,
                activityProgress: 3.94
            ),
            brainHour: 20
        )

        let result = CoachV6Engine.evaluate(input: input, focusActivity: completedRide)

        XCTAssertEqual(result.scenario, .tomorrowProtection)
        XCTAssertNotNil(result.copyPack)
        let pack = try XCTUnwrap(result.copyPack)
        XCTAssertFalse(pack.assessment.lines.first?.english.contains("Core") == true)
        XCTAssertFalse(pack.assessment.lines.first?.english.contains("10:30") == true)
        XCTAssertFalse(pack.assessment.lines.first?.english.contains("tomorrow") == true)
        XCTAssertTrue(CoachV6TabPresentationBridge.build(from: result) != nil)
        XCTAssertEqual(result.context.tomorrowWorkout?.title, "Core")
    }

    func testEveningAfterLongRideUsesV6CopyPack() {
        let evening = date(hour: 21, minute: 30)
        let rideStart = Calendar.current.date(byAdding: .hour, value: -11, to: evening)!
        let ride = PlannedActivity(
            date: rideStart,
            type: "workout",
            title: "100 km Cycling",
            durationMinutes: 360,
            icon: "figure.outdoor.cycle",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b,
            calories: 900,
            isCompleted: true
        )

        let input = makeInput(now: evening, activities: [ride], brainHour: 21)
        let result = CoachV6Engine.evaluate(input: input, focusActivity: ride)

        XCTAssertEqual(result.scenario, .eveningAfterEndurance)
        XCTAssertNotNil(result.copyPack)
        XCTAssertNotNil(CoachV6TabPresentationBridge.build(from: result))

        let debug = CoachV6IntegrationDebug.resolve(from: result, usingV6: true)
        XCTAssertTrue(debug.usingV6)
    }

    // MARK: - Heat

    func testSaunaActiveReturnsSaunaActiveScenario() {
        let now = CoachTestClock.reference
        let saunaStart = CoachTestClock.offset(minutes: -10, from: now)
        let sauna = PlannedActivity(
            date: saunaStart,
            type: "sauna",
            title: "Sauna",
            durationMinutes: 20,
            icon: "flame.fill",
            colorRed: 0.9,
            colorGreen: 0.3,
            colorBlue: 0.2
        )

        let input = makeInput(now: now, activities: [sauna], brainHour: 14)
        let result = CoachV6Engine.evaluate(input: input, focusActivity: sauna)

        XCTAssertEqual(result.scenario, .saunaActive)
        XCTAssertEqual(result.modifiers.activityType, .sauna)
        XCTAssertEqual(result.todayInsight.semanticColor, .heat)
        XCTAssertEqual(result.todayInsight.urgencyLevel, .live)
    }

    // MARK: - Guard: dayLoad not in ScenarioKey names

    func testDayLoadLivesOnlyInModifiers() {
        let now = CoachTestClock.reference
        let cyclingStart = CoachTestClock.offset(minutes: -30, from: now)
        let cycling = cyclingActivity(title: "Ride", start: cyclingStart, durationMinutes: 90)

        let freshInput = makeInput(
            now: now,
            activities: [cycling],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 200,
                exerciseMinutes: 20,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 0.4
            ),
            brainHour: 14
        )
        let heavyInput = makeInput(
            now: now,
            activities: [cycling],
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 900,
                exerciseMinutes: 120,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 1.7
            ),
            brainHour: 14
        )

        let fresh = CoachV6Engine.evaluate(input: freshInput, focusActivity: cycling)
        let heavy = CoachV6Engine.evaluate(input: heavyInput, focusActivity: cycling)

        XCTAssertEqual(fresh.scenario, heavy.scenario)
        XCTAssertEqual(fresh.scenario, .duringEndurance)
        XCTAssertEqual(fresh.modifiers.dayLoad, .fresh)
        XCTAssertTrue(heavy.modifiers.dayLoad == .heavy || heavy.modifiers.dayLoad == .extreme)
    }

    // MARK: - Helpers

    private func makeInput(
        now: Date,
        activities: [PlannedActivity],
        nutrition: CoachNutritionContext? = nil,
        actualLoad: CoachActualLoadSnapshot? = nil,
        brainHour: Int = 14
    ) -> CoachInputSnapshot {
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
            nutritionContext: resolvedNutrition,
            source: "CoachV6ScenarioTests"
        )
    }

    private func cyclingActivity(
        title: String,
        start: Date,
        durationMinutes: Int
    ) -> PlannedActivity {
        PlannedActivity(
            date: start,
            type: "workout",
            title: title,
            durationMinutes: durationMinutes,
            icon: "figure.outdoor.cycle",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b,
            calories: 900
        )
    }

    private func walkActivity(start: Date, title: String) -> PlannedActivity {
        PlannedActivity(
            date: start,
            type: "recovery",
            title: title,
            durationMinutes: 30,
            icon: "figure.walk",
            colorRed: defaultColors.r,
            colorGreen: defaultColors.g,
            colorBlue: defaultColors.b
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
