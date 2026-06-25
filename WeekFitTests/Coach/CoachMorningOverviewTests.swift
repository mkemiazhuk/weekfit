import XCTest
@testable import WeekFit

final class CoachMorningOverviewTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    override func setUp() {
        super.setUp()
        CoachSessionTracker.resetForTests()
    }

    override func tearDown() {
        CoachSessionTracker.resetForTests()
        super.tearDown()
    }

    func testIdleMorningZeroNutritionSuppressesHydrationAndFuel() throws {
        let morning = date(hour: 7, minute: 30)
        let nutrition = emptyNutrition()

        let result = CoachEngine.evaluate(
            input: makeInput(now: morning, activities: [], nutrition: nutrition, brainHour: 7)
        )
        let pack = try XCTUnwrap(result.copyPack)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.context.conversationPhase, .morningOverview)
        XCTAssertEqual(result.scenario, .morningReadiness)
        XCTAssertFalse(result.modifiers.fuelBehind)
        XCTAssertFalse(result.modifiers.hydrationBehind)
        XCTAssertEqual(result.todayInsight.alertSeverity, .none)
        XCTAssertTrue(pack.supportingSignals.lines.isEmpty)
        XCTAssertFalse(whyRowsMentionNutrition(bridge.coach.whyRows))
    }

    func testUpcomingWalkMorningSuppressesNutritionWhyRows() throws {
        let morning = date(hour: 7, minute: 30)
        let walkStart = morning.addingTimeInterval(45 * 60)
        let walk = walkActivity(start: walkStart)

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: morning,
                activities: [walk],
                nutrition: emptyNutrition(),
                brainHour: 7
            )
        )
        let pack = try XCTUnwrap(result.copyPack)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.context.conversationPhase, .morningOverview)
        XCTAssertEqual(result.scenario, .walkLightDay)
        XCTAssertFalse(result.modifiers.hydrationBehind)
        XCTAssertFalse(result.modifiers.fuelBehind)
        XCTAssertFalse(whyRowsMentionNutrition(bridge.coach.whyRows))

        let supportText = pack.supportingSignals.lines
            .flatMap { [$0.english.lowercased(), $0.russian.lowercased()] }
            .joined(separator: " ")
        XCTAssertTrue(
            supportText.contains("walk") || supportText.contains("прогул") ||
                supportText.contains("plan") || supportText.contains("план")
        )
    }

    func testMorningOverviewEndsAfterFirstDrink() throws {
        let morning = date(hour: 7, minute: 30)
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 0,
            caloriesGoal: 2_800,
            proteinCurrent: 0,
            proteinGoal: 140,
            waterCurrent: 0.3,
            waterGoal: 2.5
        )

        let result = CoachEngine.evaluate(
            input: makeInput(now: morning, activities: [], nutrition: nutrition, brainHour: 7)
        )

        XCTAssertEqual(result.context.conversationPhase, .steady)
    }

    func testMorningOverviewEndsAfterFirstMeal() {
        let morning = date(hour: 8, minute: 0)
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 420,
            caloriesGoal: 2_800,
            proteinCurrent: 18,
            proteinGoal: 140,
            waterCurrent: 0,
            waterGoal: 2.5,
            mealsCount: 1
        )

        let result = CoachEngine.evaluate(
            input: makeInput(now: morning, activities: [], nutrition: nutrition, brainHour: 8)
        )

        XCTAssertEqual(result.context.conversationPhase, .steady)
    }

    func testMorningOverviewEndsAfterFirstCompletedActivity() {
        let morning = date(hour: 7, minute: 45)
        let completedWalk = walkActivity(
            start: morning.addingTimeInterval(-40 * 60),
            completed: true
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: morning,
                activities: [completedWalk],
                nutrition: emptyNutrition(),
                brainHour: 7
            ),
            focusActivity: completedWalk
        )

        XCTAssertEqual(result.context.conversationPhase, .steady)
    }

    func testMorningOverviewEndsAfterMorningWindow() {
        let lateMorning = date(hour: 10, minute: 15)
        let nutrition = behindNutrition()

        let result = CoachEngine.evaluate(
            input: makeInput(now: lateMorning, activities: [], nutrition: nutrition, brainHour: 10)
        )

        XCTAssertEqual(result.context.conversationPhase, .steady)
        XCTAssertTrue(result.modifiers.fuelBehind || result.modifiers.hydrationBehind)
    }

    func testLiveMorningWorkoutDoesNotSuppressSessionSafety() {
        let morning = date(hour: 7, minute: 30)
        let rideStart = morning.addingTimeInterval(-30 * 60)
        let ride = cyclingActivity(start: rideStart, durationMinutes: 120)

        let nutrition = CoachNutritionContext(
            caloriesCurrent: 200,
            caloriesGoal: 3_000,
            proteinCurrent: 10,
            proteinGoal: 150,
            waterCurrent: 0.2,
            waterGoal: 2.5
        )

        let result = CoachEngine.evaluate(
            input: makeInput(now: morning, activities: [ride], nutrition: nutrition, brainHour: 7),
            focusActivity: ride
        )

        XCTAssertEqual(result.context.conversationPhase, .steady)
        XCTAssertTrue(
            result.context.conversationPhaseReason == "duringWorkoutOwner" ||
                result.context.conversationPhaseReason == "activeWorkoutOwner"
        )
        XCTAssertEqual(result.scenario, .duringEndurance)
    }

    func testImminentPreSessionStaysInMorningOverview() {
        let morning = date(hour: 7, minute: 0)
        let rideStart = morning.addingTimeInterval(45 * 60)
        let ride = cyclingActivity(start: rideStart, durationMinutes: 90)

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: morning,
                activities: [ride],
                nutrition: emptyNutrition(),
                brainHour: 7
            )
        )

        XCTAssertEqual(result.context.conversationPhase, .morningOverview)
        XCTAssertEqual(result.scenario, .activeEndurance)
        XCTAssertFalse(result.modifiers.fuelBehind)
        XCTAssertFalse(result.modifiers.hydrationBehind)
    }

    // MARK: - Helpers

    private func whyRowsMentionNutrition(_ rows: [CoachPresentationWhyRow]) -> Bool {
        let text = rows.map(\.title).joined(separator: " ").lowercased()
        return text.contains("water") || text.contains("вод") ||
            text.contains("fuel") || text.contains("калор") ||
            text.contains("meal") || text.contains("поеш") ||
            text.contains("маловато") || text.contains("behind")
    }

    private func emptyNutrition() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 0,
            caloriesGoal: 2_800,
            proteinCurrent: 0,
            proteinGoal: 140,
            waterCurrent: 0,
            waterGoal: 2.5
        )
    }

    private func behindNutrition() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 2_800,
            proteinCurrent: 25,
            proteinGoal: 140,
            waterCurrent: 0,
            waterGoal: 2.5
        )
    }

    private func makeInput(
        now: Date,
        activities: [PlannedActivity],
        nutrition: CoachNutritionContext? = nil,
        brainHour: Int = 14
    ) -> CoachInputSnapshot {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = brainHour

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities,
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 200,
                exerciseMinutes: 20,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 0.4
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutritionContext: nutrition ?? emptyNutrition(),
            source: "CoachMorningOverviewTests"
        )
    }

    private func cyclingActivity(
        start: Date,
        durationMinutes: Int = 90
    ) -> PlannedActivity {
        PlannedActivity(
            date: start,
            type: "workout",
            title: "Morning Ride",
            durationMinutes: durationMinutes,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            calories: 900,
            isCompleted: false
        )
    }

    private func walkActivity(start: Date, completed: Bool = false) -> PlannedActivity {
        PlannedActivity(
            date: start,
            type: "recovery",
            title: "Morning Walk",
            durationMinutes: 45,
            icon: "figure.walk",
            colorRed: 0.3,
            colorGreen: 0.7,
            colorBlue: 0.4,
            calories: 150,
            isCompleted: completed
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
