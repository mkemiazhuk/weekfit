import XCTest
@testable import WeekFit

/// PR1 safety contract — conversation phase must not change routing, presentation, or fingerprint.
final class CoachConversationPhaseSafetyTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    override func setUp() {
        super.setUp()
        CoachSessionTracker.resetForTests()
    }

    override func tearDown() {
        CoachSessionTracker.resetForTests()
        super.tearDown()
    }

    // MARK: - Routing unchanged

    func testActiveWorkoutRoutingUnchanged() {
        let now = date(hour: 14, minute: 20)
        let start = date(hour: 14, minute: 0)
        let ride = cyclingActivity(title: "Ride", start: start, durationMinutes: 90)

        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [ride], brainHour: 14),
            focusActivity: ride
        )

        assertRoutingBaseline(result)
        XCTAssertEqual(result.scenario, .duringEndurance)
        XCTAssertEqual(result.context.sessionPhase, .during)
        XCTAssertEqual(result.context.conversationPhase, .steady)
        XCTAssertTrue(
            result.context.conversationPhaseReason == "activeWorkoutOwner" ||
                result.context.conversationPhaseReason == "duringWorkoutOwner"
        )
    }

    func testDuringWorkoutSafetyCriticalRoutingUnchanged() {
        let now = CoachTestClock.reference
        let cyclingStart = CoachTestClock.offset(minutes: -90, from: now)
        let cycling = cyclingActivity(title: "100 km Cycling", start: cyclingStart, durationMinutes: 360)

        let nutrition = CoachNutritionContext(
            caloriesCurrent: 2_000,
            caloriesGoal: 3_000,
            proteinCurrent: 100,
            proteinGoal: 150,
            waterCurrent: 0.4,
            waterGoal: 2.5
        )

        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [cycling], nutrition: nutrition, brainHour: 14),
            focusActivity: cycling
        )

        assertRoutingBaseline(result)
        XCTAssertEqual(result.scenario, .duringEndurance)
        XCTAssertEqual(result.resolution.safetyAlert, .hydrationCritical)
        XCTAssertEqual(result.todayInsight.alertSeverity, .critical)
        XCTAssertEqual(result.context.conversationPhase, .steady)
    }

    func testImminentPreSessionRoutingUnchanged() {
        let now = date(hour: 7, minute: 0)
        let rideStart = date(hour: 7, minute: 45)
        let ride = cyclingActivity(title: "Morning Ride", start: rideStart, durationMinutes: 90)

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: now,
                activities: [ride],
                nutrition: emptyMorningNutrition(),
                brainHour: 7
            )
        )

        assertRoutingBaseline(result)
        XCTAssertEqual(result.scenario, .activeEndurance)
        XCTAssertEqual(result.context.sessionPhase, .pre)
        XCTAssertEqual(result.context.conversationPhase, .morningOverview)
        XCTAssertEqual(result.context.conversationPhaseReason, "morningWindowUpcomingActivity")
        XCTAssertFalse(result.modifiers.fuelBehind)
        XCTAssertFalse(result.modifiers.hydrationBehind)
    }

    func testLowRecoveryPrepRoutingUnchanged() {
        let now = date(hour: 8, minute: 0)
        let rideStart = date(hour: 8, minute: 45)
        let ride = cyclingActivity(title: "Morning Ride", start: rideStart, durationMinutes: 90)

        let input = makeInput(
            now: now,
            activities: [ride],
            brainHour: 8,
            recoveryPercent: 35,
            sleepHours: 4.5
        )

        let result = CoachEngine.evaluate(input: input)

        assertRoutingBaseline(result)
        XCTAssertEqual(result.scenario, .lowRecoveryPrep)
        XCTAssertEqual(result.context.conversationPhase, .steady)
    }

    func testImmediatePostWorkoutRoutingUnchanged() {
        let start = date(hour: 14, minute: 0)
        let now = start.addingTimeInterval(96 * 60)
        let ride = cyclingActivity(title: "Ride", start: start, durationMinutes: 90, completed: true)
        ride.source = "appleWorkout"

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: now,
                activities: [ride],
                brainHour: Calendar.current.component(.hour, from: now)
            ),
            focusActivity: ride
        )

        assertRoutingBaseline(result)
        XCTAssertEqual(result.scenario, .postEnduranceImmediate)
        XCTAssertEqual(result.context.sessionPhase, .immediatePost)
        XCTAssertEqual(result.context.conversationPhase, .steady)
        XCTAssertEqual(result.context.conversationPhaseReason, "immediatePostOwner")
    }

    func testTomorrowProtectionRoutingUnchanged() {
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

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: evening,
                activities: [completedRide, tomorrowRun],
                actualLoad: heavyActualLoad(),
                brainHour: 19
            )
        )

        assertRoutingBaseline(result)
        XCTAssertEqual(result.scenario, .tomorrowProtection)
        XCTAssertEqual(result.context.sessionPhase, .tomorrowProtection)
        XCTAssertEqual(result.context.conversationPhase, .steady)
        XCTAssertEqual(result.context.conversationPhaseReason, "tomorrowProtectionOwner")
    }

    func testStableDayRoutingUnchanged() {
        let now = date(hour: 14, minute: 0)
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 2_800,
            proteinCurrent: 25,
            proteinGoal: 140,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )

        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [], nutrition: nutrition, brainHour: 14)
        )

        assertRoutingBaseline(result)
        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertTrue(result.modifiers.fuelBehind)
        XCTAssertEqual(result.todayInsight.alertSeverity, .elevated)
        XCTAssertEqual(result.context.conversationPhase, .steady)
    }

    func testMorningReadinessRoutingUnchanged() {
        let morning = date(hour: 7, minute: 30)

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: morning,
                activities: [],
                nutrition: emptyMorningNutrition(),
                brainHour: 7
            )
        )

        assertRoutingBaseline(result)
        XCTAssertEqual(result.scenario, .morningReadiness)
        XCTAssertEqual(result.modifiers.dayLoad, .fresh)
        XCTAssertEqual(result.todayInsight.semanticColor, .ready)
        XCTAssertEqual(result.context.conversationPhase, .morningOverview)
        XCTAssertFalse(result.modifiers.fuelBehind)
        XCTAssertFalse(result.modifiers.hydrationBehind)
    }

    // MARK: - Resolver isolation

    func testScenarioResolverIgnoresConversationPhaseOnContext() {
        let baselineContext = idleMorningContext(conversationPhase: .steady)
        let openingContext = idleMorningContext(conversationPhase: .morningOverview)

        XCTAssertEqual(
            CoachScenarioResolver.resolve(baselineContext).scenario,
            CoachScenarioResolver.resolve(openingContext).scenario
        )
        XCTAssertEqual(
            CoachScenarioResolver.resolve(baselineContext).modifiers,
            CoachScenarioResolver.resolve(openingContext).modifiers
        )
    }

    func testPresentationBridgeUnchangedForStableDay() throws {
        let now = date(hour: 14, minute: 0)
        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [], brainHour: 14)
        )

        let baselineBridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))
        let openingContext = result.context.withConversationPhase(
            CoachConversationPhaseResolution(phase: .morningOverview, reason: "testInjection")
        )
        let injectedResult = CoachEngine.Result(
            context: openingContext,
            resolution: result.resolution,
            todayInsight: result.todayInsight,
            copyPack: result.copyPack
        )
        let injectedBridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: injectedResult))

        XCTAssertEqual(baselineBridge.today.title, injectedBridge.today.title)
        XCTAssertEqual(baselineBridge.today.message, injectedBridge.today.message)
        XCTAssertEqual(baselineBridge.coach.title, injectedBridge.coach.title)
        XCTAssertEqual(baselineBridge.coach.message, injectedBridge.coach.message)
        XCTAssertEqual(baselineBridge.coach.recommendation, injectedBridge.coach.recommendation)
    }

    // MARK: - Fingerprint

    func testCoachInputFingerprintUnchangedByConversationSessionState() {
        let input = makeInput(now: date(hour: 7, minute: 30), activities: [], brainHour: 7)

        CoachSessionTracker.setTestFirstOpen(true)
        let firstOpenFingerprint = CoachInputFingerprint(snapshot: input)

        CoachSessionTracker.setTestFirstOpen(false)
        let repeatOpenFingerprint = CoachInputFingerprint(snapshot: input)

        XCTAssertEqual(firstOpenFingerprint, repeatOpenFingerprint)
        XCTAssertFalse(firstOpenFingerprint.rawValue.localizedCaseInsensitiveContains("conversation"))
        XCTAssertFalse(firstOpenFingerprint.rawValue.localizedCaseInsensitiveContains("firstOpen"))
    }

    func testCoachInputFingerprintUnchangedAfterEngineEvaluate() {
        let input = makeInput(now: date(hour: 7, minute: 30), activities: [], brainHour: 7)
        let fingerprintBefore = CoachInputFingerprint(snapshot: input)

        CoachSessionTracker.setTestFirstOpen(true)
        _ = CoachEngine.evaluate(input: input)

        let fingerprintAfter = CoachInputFingerprint(snapshot: input)
        XCTAssertEqual(fingerprintBefore, fingerprintAfter)
    }

    // MARK: - Conversation phase computation (debug only)

    func testMorningOverviewComputedOnMorningIdle() {
        let result = CoachEngine.evaluate(
            input: makeInput(
                now: date(hour: 7, minute: 0),
                activities: [],
                nutrition: emptyMorningNutrition(),
                brainHour: 7
            )
        )

        XCTAssertEqual(result.context.conversationPhase, .morningOverview)
        XCTAssertEqual(result.context.conversationPhaseReason, "morningWindowIdleDay")
    }

    func testDayClosingComputedOnLateEveningIdleWithoutUpcomingWork() {
        let lateEvening = date(hour: 21, minute: 15)

        let result = CoachEngine.evaluate(
            input: makeInput(now: lateEvening, activities: [], brainHour: 21)
        )

        XCTAssertEqual(result.context.conversationPhase, .dayClosing)
        XCTAssertEqual(result.context.conversationPhaseReason, "bedtimeWindowNoMeaningfulWorkLeft")
    }

    func testDayClosingNotSelectedWhenMeaningfulActivityRemains() {
        let evening = date(hour: 21, minute: 0)
        let upcomingRide = cyclingActivity(
            title: "Late Ride",
            start: evening.addingTimeInterval(30 * 60),
            durationMinutes: 60
        )

        let result = CoachEngine.evaluate(
            input: makeInput(now: evening, activities: [upcomingRide], brainHour: 21)
        )

        XCTAssertEqual(result.scenario, .activeEndurance)
        XCTAssertEqual(result.context.conversationPhase, .steady)
    }

    // MARK: - Helpers

    private func assertRoutingBaseline(_ result: CoachEngine.Result, file: StaticString = #file, line: UInt = #line) {
        XCTAssertNotNil(result.copyPack, file: file, line: line)
        XCTAssertEqual(
            result.scenario,
            CoachScenarioResolver.resolve(result.context).scenario,
            file: file,
            line: line
        )
    }

    private func idleMorningContext(conversationPhase: CoachConversationPhase) -> CoachContext {
        CoachContext(
            activityFamily: .none,
            activityType: .none,
            activityState: .none,
            sessionPhase: .idle,
            durationBand: .short,
            dayLoadBand: .fresh,
            completedSeriousActivities: .none,
            fuelState: .adequate,
            hydrationState: .adequate,
            tomorrowDemand: .none,
            timeOfDay: .morning,
            tomorrowWorkout: nil,
            focusActivityID: nil,
            focusSource: .idle,
            minutesUntilStart: nil,
            minutesSinceEnd: nil,
            dayReadiness: CoachDayReadiness(
                recoveryPercent: 82,
                sleepHours: 7.5,
                recoveryBand: .good,
                hadHeavyYesterday: false,
                sleepIsLow: false
            ),
            lastCompletedSeriousActivityType: .none,
            conversationPhase: conversationPhase,
            conversationPhaseReason: conversationPhase.rawValue
        )
    }

    private func emptyMorningNutrition() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 0,
            caloriesGoal: 2_800,
            proteinCurrent: 0,
            proteinGoal: 140,
            waterCurrent: 0,
            waterGoal: 2.5
        )
    }

    private func makeInput(
        now: Date,
        activities: [PlannedActivity],
        nutrition: CoachNutritionContext? = nil,
        actualLoad: CoachActualLoadSnapshot? = nil,
        brainHour: Int = 14,
        recoveryPercent: Int = 82,
        sleepHours: Double = 7.5
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
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: recoveryPercent,
                sleepHours: sleepHours
            ),
            nutritionContext: nutrition ?? CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_800,
                proteinCurrent: 90,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            source: "CoachConversationPhaseSafetyTests"
        )
    }

    private func cyclingActivity(
        title: String,
        start: Date,
        durationMinutes: Int,
        completed: Bool = false
    ) -> PlannedActivity {
        PlannedActivity(
            date: start,
            type: "workout",
            title: title,
            durationMinutes: durationMinutes,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            calories: 900,
            isCompleted: completed
        )
    }

    private func heavyActualLoad() -> CoachActualLoadSnapshot {
        CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 850,
            exerciseMinutes: 110,
            standHours: nil,
            activityGoalCalories: 600,
            activityProgress: 1.6
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
