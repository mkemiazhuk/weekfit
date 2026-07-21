import XCTest
@testable import WeekFit

/// Ownership-conflict matrix for Coach — see `CoachEdgeCaseMatrix.md`.
final class CoachEdgeCaseSnapshotTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    struct Expectation {
        let caseID: String
        let storyOwner: String
        let scenario: CoachScenarioKey
        let badge: String
        let todayTitle: String
        let stackedDayActiveRisk: Bool
        let conflictNote: String?
    }

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.russian)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    // MARK: - 1. Morning → Active

    func testEdgeCase01A_morningIdleBeforeActivity() throws {
        let morning = date(hour: 7, minute: 30)
        let result = evaluate(
            now: morning,
            activities: [],
            brainHour: 7
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "1A",
                storyOwner: "day.idle",
                scenario: .morningReadiness,
                badge: "ВСЁ ХОРОШО",
                todayTitle: "Доброе утро",
                stackedDayActiveRisk: false,
                conflictNote: nil
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase01B_morningUpcomingRideTransitionsToActive() throws {
        let morning = date(hour: 8, minute: 0)
        let ride = cyclingActivity(
            title: "Morning Ride",
            start: morning.addingTimeInterval(45 * 60),
            durationMinutes: 120
        )
        let result = evaluate(
            now: morning,
            activities: [ride],
            brainHour: 8
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "1B",
                storyOwner: "session.activity",
                scenario: .activeEndurance,
                badge: "СЕЙЧАС ВАЖНО",
                todayTitle: "Готовимся к заезду",
                stackedDayActiveRisk: false,
                conflictNote: "day.idle yields once upcoming activity is in focus chain"
            ),
            result: result,
            bridge: bridge
        )
    }

    // MARK: - 2. Active → Post

    func testEdgeCase02A_activeRideDuringSession() throws {
        let now = date(hour: 14, minute: 0)
        let ride = cyclingActivity(
            title: "Ride",
            start: now.addingTimeInterval(-30 * 60),
            durationMinutes: 120
        )
        let result = evaluate(now: now, activities: [ride], brainHour: 14, focus: ride)
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "2A",
                storyOwner: "session.activity",
                scenario: .duringEndurance,
                badge: "СЕЙЧАС",
                todayTitle: "На заезде",
                stackedDayActiveRisk: false,
                conflictNote: nil
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase02B_activeRideJustFinishedImmediatePost() throws {
        let now = date(hour: 14, minute: 15)
        let ride = cyclingActivity(
            title: "Ride",
            start: now.addingTimeInterval(-105 * 60),
            durationMinutes: 90,
            completed: true
        )
        let result = evaluate(now: now, activities: [ride], brainHour: 14, focus: ride)
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "2B",
                storyOwner: "session.activity",
                scenario: .postEnduranceImmediate,
                badge: "СЕЙЧАС ВАЖНО",
                todayTitle: "Заезд завершён",
                stackedDayActiveRisk: false,
                conflictNote: "immediatePost window is 60 minutes since end"
            ),
            result: result,
            bridge: bridge
        )
    }

    // MARK: - 3. Post → Evening

    func testEdgeCase03A_finishedRideEveningStory() throws {
        let evening = date(hour: 21, minute: 30)
        let rideStart = evening.addingTimeInterval(-11 * 3600)
        let ride = cyclingActivity(
            title: "Long Ride",
            start: rideStart,
            durationMinutes: 360,
            completed: true
        )
        let result = evaluate(now: evening, activities: [ride], brainHour: 21, focus: ride)
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "3A",
                storyOwner: "session.activity",
                scenario: .eveningAfterEndurance,
                badge: "БЕРЕЖЁМ СИЛЫ",
                todayTitle: "Вечер после нагрузки",
                stackedDayActiveRisk: false,
                conflictNote: nil
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase03B_eveningClockStillImmediatePostWithin60Minutes() throws {
        let evening = date(hour: 21, minute: 30)
        let ride = cyclingActivity(
            title: "Ride",
            start: evening.addingTimeInterval(-110 * 60),
            durationMinutes: 90,
            completed: true
        )
        let result = evaluate(now: evening, activities: [ride], brainHour: 21, focus: ride)
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "3B",
                storyOwner: "session.activity",
                scenario: .postEnduranceImmediate,
                badge: "СЕЙЧАС ВАЖНО",
                todayTitle: "Заезд завершён",
                stackedDayActiveRisk: false,
                conflictNote: "evening time loses to immediatePost when ≤60m since end"
            ),
            result: result,
            bridge: bridge
        )
    }

    // MARK: - 4. Evening → TomorrowProtection

    func testEdgeCase04A_heavyDayCompletedFocusUsesTomorrowProtection() throws {
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

        let result = evaluate(
            now: evening,
            activities: [completedRide, tomorrowRun],
            actualLoad: heavyActualLoad(),
            brainHour: 20,
            focus: completedRide
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "4A",
                storyOwner: "day.tomorrowProtection",
                scenario: .tomorrowProtection,
                badge: "БЕРЕЖЁМ СИЛЫ",
                todayTitle: "Берегите силы",
                stackedDayActiveRisk: false,
                conflictNote: "protection beats eveningAfter on completed focus"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase04B_upcomingWorkoutTodayBlocksTomorrowProtection() throws {
        let evening = date(hour: 20, minute: 15)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!
        let completedRide = PlannedActivityBuilder.workout(
            title: "Long Ride",
            at: CoachTestClock.offset(hours: -8, from: evening),
            durationMinutes: 180,
            completed: true
        )
        let tomorrowRun = PlannedActivityBuilder.workout(
            title: "Long Run",
            at: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!,
            durationMinutes: 90
        )
        let upcomingEveningCore = PlannedActivity(
            date: evening.addingTimeInterval(30 * 60),
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let result = evaluate(
            now: evening,
            activities: [completedRide, upcomingEveningCore, tomorrowRun],
            actualLoad: heavyActualLoad(),
            brainHour: 20,
            focus: completedRide
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "4B",
                storyOwner: "session.activity",
                scenario: .eveningAfterEndurance,
                badge: "БЕРЕЖЁМ СИЛЫ",
                todayTitle: "Вечер после нагрузки",
                stackedDayActiveRisk: false,
                conflictNote: "upcoming training today blocks tomorrowProtection override on completed focus"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase04BPrime_autoFocusPicksUpcomingCoreOverIdleProtection() throws {
        let evening = date(hour: 20, minute: 15)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!
        let completedRide = PlannedActivityBuilder.workout(
            title: "Long Ride",
            at: CoachTestClock.offset(hours: -8, from: evening),
            durationMinutes: 180,
            completed: true
        )
        let tomorrowRun = PlannedActivityBuilder.workout(
            title: "Long Run",
            at: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!,
            durationMinutes: 90
        )
        let upcomingEveningCore = PlannedActivity(
            date: evening.addingTimeInterval(30 * 60),
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let result = evaluate(
            now: evening,
            activities: [completedRide, upcomingEveningCore, tomorrowRun],
            actualLoad: heavyActualLoad(),
            brainHour: 20
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "4B′",
                storyOwner: "session.activity+overlay.stackedRisk",
                scenario: .activeStrength,
                badge: "ВНИМАНИЕ",
                todayTitle: "Силовая впереди",
                stackedDayActiveRisk: true,
                conflictNote: "auto-focus picks upcoming core; stacked overlay on pre-session heavy day"
            ),
            result: result,
            bridge: bridge
        )
    }

    // MARK: - 5. Multiple activities

    func testEdgeCase05A_activeSessionWinsOverCompletedRide() throws {
        let now = date(hour: 18, minute: 0)
        let completedRide = PlannedActivityBuilder.workout(
            title: "Morning Ride",
            at: date(hour: 8, minute: 0),
            durationMinutes: 120,
            completed: true
        )
        let activeStrength = PlannedActivity(
            date: now.addingTimeInterval(-10 * 60),
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let result = evaluate(
            now: now,
            activities: [completedRide, activeStrength],
            actualLoad: moderateActualLoad(),
            brainHour: 18
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "5A",
                storyOwner: "session.activity",
                scenario: .duringStrength,
                badge: "СЕЙЧАС",
                todayTitle: "Силовая идёт",
                stackedDayActiveRisk: false,
                conflictNote: "live session wins focus over completed work"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase05B_upcomingWinsWhenNothingActive() throws {
        let now = date(hour: 13, minute: 0)
        let completedRide = PlannedActivityBuilder.workout(
            title: "Morning Ride",
            at: date(hour: 8, minute: 0),
            durationMinutes: 90,
            completed: true
        )
        let upcomingTennis = PlannedActivity(
            date: now.addingTimeInterval(30 * 60),
            type: "workout",
            title: "Tennis",
            durationMinutes: 60,
            icon: "figure.tennis",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let result = evaluate(
            now: now,
            activities: [completedRide, upcomingTennis],
            brainHour: 13
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "5B",
                storyOwner: "session.activity",
                scenario: .activeRacket,
                badge: "СЕЙЧАС ВАЖНО",
                todayTitle: "Игра скоро",
                stackedDayActiveRisk: false,
                conflictNote: "next upcoming becomes focus when no active session"
            ),
            result: result,
            bridge: bridge
        )
    }

    // MARK: - 6–8. Active + risk overlays

    func testEdgeCase06_hydrationCriticalDoesNotChangeScenario() throws {
        let now = date(hour: 14, minute: 0)
        let ride = cyclingActivity(
            title: "100 km Cycling",
            start: now.addingTimeInterval(-90 * 60),
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

        let result = evaluate(
            now: now,
            activities: [ride],
            nutrition: nutrition,
            brainHour: 14,
            focus: ride
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "6",
                storyOwner: "session.activity",
                scenario: .duringEndurance,
                badge: "ВАЖНО",
                todayTitle: "На заезде",
                stackedDayActiveRisk: false,
                conflictNote: "hydration critical is warning overlay — scenario unchanged"
            ),
            result: result,
            bridge: bridge
        )
        XCTAssertEqual(result.resolution.safetyAlert, .hydrationCritical)
    }

    func testEdgeCase07_fuelBehindDoesNotChangeScenario() throws {
        let now = date(hour: 14, minute: 0)
        let ride = cyclingActivity(
            title: "Ride",
            start: now.addingTimeInterval(-20 * 60),
            durationMinutes: 59
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 3_000,
            proteinCurrent: 30,
            proteinGoal: 150,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )

        let result = evaluate(
            now: now,
            activities: [ride],
            nutrition: nutrition,
            brainHour: 14,
            focus: ride
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "7",
                storyOwner: "session.activity",
                scenario: .duringEndurance,
                badge: "СЕЙЧАС",
                todayTitle: "На заезде",
                stackedDayActiveRisk: false,
                conflictNote: "fuel behind is modifier only — scenario unchanged"
            ),
            result: result,
            bridge: bridge
        )
        XCTAssertTrue(result.modifiers.fuelBehind)
        XCTAssertNil(result.resolution.safetyAlert)
    }

    func testEdgeCase07B_fuelCriticalDoesNotChangeScenario() throws {
        let now = date(hour: 14, minute: 0)
        let ride = cyclingActivity(
            title: "100 km Cycling",
            start: now.addingTimeInterval(-90 * 60),
            durationMinutes: 360
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 3_000,
            proteinCurrent: 80,
            proteinGoal: 150,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )

        let result = evaluate(
            now: now,
            activities: [ride],
            nutrition: nutrition,
            brainHour: 14,
            focus: ride
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "7B",
                storyOwner: "session.activity",
                scenario: .duringEndurance,
                badge: "ВАЖНО",
                todayTitle: "На заезде",
                stackedDayActiveRisk: false,
                conflictNote: "fuel critical is warning overlay — scenario unchanged"
            ),
            result: result,
            bridge: bridge
        )
        XCTAssertEqual(result.resolution.safetyAlert, .fuelCritical)
    }

    func testEdgeCase08_stackedDayRiskOverridesPresentation() throws {
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
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )
        let activeCore = PlannedActivity(
            date: lateEvening.addingTimeInterval(-8 * 60),
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let result = evaluate(
            now: lateEvening,
            activities: [completedRide, activeCore, tomorrowCore],
            actualLoad: heavyActualLoad(),
            brainHour: 22,
            focus: activeCore
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "8",
                storyOwner: "session.activity+overlay.stackedRisk",
                scenario: .duringStrength,
                badge: "ВНИМАНИЕ",
                todayTitle: "Силовая идёт",
                stackedDayActiveRisk: true,
                conflictNote: "scenario key stays duringStrength — stacked risk in supporting signals only"
            ),
            result: result,
            bridge: bridge
        )
    }

    // MARK: - 9–12. Recovery / empty / cross-day gaps

    func testEdgeCase09_goodRecoveryHardTomorrowStillMorningIdle() throws {
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
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "9",
                storyOwner: "day.readinessProtection",
                scenario: .protectTomorrowFresh,
                badge: "БЕРЕЖЁМ СИЛЫ",
                todayTitle: "Сохраните запас на зав…",
                stackedDayActiveRisk: false,
                conflictNote: "good recovery + hard tomorrow — protect fresh reserve, not empty morning"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase10_badRecoveryStillShowsUpcomingWorkout() throws {
        let now = date(hour: 13, minute: 0)
        let ride = cyclingActivity(
            title: "Afternoon Ride",
            start: now.addingTimeInterval(60 * 60),
            durationMinutes: 90
        )

        let result = evaluate(
            now: now,
            activities: [ride],
            recovery: CoachRecoveryContext(recoveryPercent: 35, sleepHours: 4.5),
            brainHour: 13
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "10",
                storyOwner: "session.activity",
                scenario: .lowRecoveryPrep,
                badge: "БЕРЕЖЁМ СИЛЫ",
                todayTitle: "Сначала проверьте готовнос…",
                stackedDayActiveRisk: false,
                conflictNote: "low recovery pre-session shifts to protective prep, not default activeEndurance"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase11A_emptyMorningDay() throws {
        let morning = date(hour: 7, minute: 30)
        let result = evaluate(now: morning, activities: [], brainHour: 7)
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "11A",
                storyOwner: "day.idle",
                scenario: .morningReadiness,
                badge: "ВСЁ ХОРОШО",
                todayTitle: "Доброе утро",
                stackedDayActiveRisk: false,
                conflictNote: nil
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase11B_emptyAfternoonDay() throws {
        let afternoon = date(hour: 14, minute: 0)
        let result = evaluate(now: afternoon, activities: [], brainHour: 14)
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "11B",
                storyOwner: "day.idle",
                scenario: .stableDay,
                badge: "ВСЁ ХОРОШО",
                todayTitle: "Спокойный день",
                stackedDayActiveRisk: false,
                conflictNote: nil
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase12_heavyYesterdayNotInContextFreshMorning() throws {
        let morning = date(hour: 7, minute: 30)
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 7
        brainConfig.completedWorkoutsCount = 2
        brainConfig.metrics = CoachMetricsBuilder.metrics(activeCalories: 900)

        let result = evaluate(
            now: morning,
            activities: [],
            actualLoad: freshActualLoad(),
            recovery: CoachRecoveryContext(recoveryPercent: 92, sleepHours: 8),
            brainHour: 7,
            brain: HumanBrainStateBuilder.make(brainConfig)
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "12",
                storyOwner: "day.idle",
                scenario: .morningReadiness,
                badge: "ВСЁ ХОРОШО",
                todayTitle: "Доброе утро",
                stackedDayActiveRisk: false,
                conflictNote: "heavy yesterday + good recovery — calm morning, yesterday in support only"
            ),
            result: result,
            bridge: bridge
        )
        assertSupportContains(try XCTUnwrap(result.copyPack), token: "вчера")
    }

    // MARK: - 13. Heavy today + active

    func testEdgeCase13A_heavyTodayActiveRide() throws {
        let now = date(hour: 15, minute: 0)
        let ride = cyclingActivity(
            title: "Ride",
            start: now.addingTimeInterval(-40 * 60),
            durationMinutes: 120
        )
        let result = evaluate(
            now: now,
            activities: [ride],
            actualLoad: heavyActualLoad(),
            brainHour: 15,
            focus: ride
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "13A",
                storyOwner: "session.activity",
                scenario: .duringEndurance,
                badge: "СЕЙЧАС",
                todayTitle: "На заезде",
                stackedDayActiveRisk: false,
                conflictNote: nil
            ),
            result: result,
            bridge: bridge
        )
        XCTAssertTrue(result.modifiers.dayLoad == .heavy || result.modifiers.dayLoad == .extreme)
    }

    func testEdgeCase13B_heavyTodayActiveRidePlusStackedOverlay() throws {
        let lateAfternoon = date(hour: 17, minute: 0)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: lateAfternoon)!
        let completedRide = PlannedActivityBuilder.workout(
            title: "Morning Ride",
            at: date(hour: 8, minute: 0),
            durationMinutes: 150,
            completed: true
        )
        let tomorrowRun = PlannedActivityBuilder.workout(
            title: "Long Run",
            at: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!,
            durationMinutes: 90
        )
        let activeRide = cyclingActivity(
            title: "Second Ride",
            start: lateAfternoon.addingTimeInterval(-50 * 60),
            durationMinutes: 120
        )

        let result = evaluate(
            now: lateAfternoon,
            activities: [completedRide, activeRide, tomorrowRun],
            actualLoad: heavyActualLoad(),
            brainHour: 17,
            focus: activeRide
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "13B",
                storyOwner: "session.activity+overlay.stackedRisk",
                scenario: .duringEndurance,
                badge: "ВНИМАНИЕ",
                todayTitle: "На заезде",
                stackedDayActiveRisk: true,
                conflictNote: "heavy day load + tomorrow demand triggers stacked overlay on live session"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase09D_goodRecoveryAfterHeavyYesterdayStillMorningIdle() throws {
        let morning = date(hour: 7, minute: 30)
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 7
        brainConfig.completedWorkoutsCount = 2
        brainConfig.metrics = CoachMetricsBuilder.metrics(calories: 3200, activeCalories: 900)

        let result = evaluate(
            now: morning,
            activities: [],
            recovery: CoachRecoveryContext(recoveryPercent: 90, sleepHours: 8),
            brainHour: 7,
            brain: HumanBrainStateBuilder.make(brainConfig)
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "9D",
                storyOwner: "day.idle",
                scenario: .morningReadiness,
                badge: "ВСЁ ХОРОШО",
                todayTitle: "Доброе утро",
                stackedDayActiveRisk: false,
                conflictNote: "heavy yesterday + good recovery — calm morning with support, not stuck on load"
            ),
            result: result,
            bridge: bridge
        )
        assertSupportContains(try XCTUnwrap(result.copyPack), token: "вчера")
    }

    func testEdgeCase09C_lowSleepActiveRideDuringSession() throws {
        let now = date(hour: 14, minute: 0)
        let ride = cyclingActivity(
            title: "Ride",
            start: now.addingTimeInterval(-25 * 60),
            durationMinutes: 90
        )
        let result = evaluate(
            now: now,
            activities: [ride],
            recovery: CoachRecoveryContext(recoveryPercent: 55, sleepHours: 4.5),
            brainHour: 14,
            focus: ride
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "9C",
                storyOwner: "session.activity",
                scenario: .duringEndurance,
                badge: "СЕЙЧАС",
                todayTitle: "На заезде",
                stackedDayActiveRisk: false,
                conflictNote: "live session keeps during* — fatigued body state shapes recommendation, not support"
            ),
            result: result,
            bridge: bridge
        )
        let pack = try XCTUnwrap(result.copyPack)
        let athleteState = CoachAthleteStateResolver.resolve(context: result.context)
        XCTAssertEqual(athleteState.bodyState, .fatigued)
        assertRecommendationContains(pack, token: "разговор")
        assertSupportDoesNotContain(pack, token: "восстанов")
    }

    // MARK: - 11. Empty day (expanded)

    func testEdgeCase11C_emptyMorningNoFoodNoWater() throws {
        let morning = date(hour: 7, minute: 30)
        let result = evaluate(
            now: morning,
            activities: [],
            nutrition: emptyNutrition(),
            brainHour: 7
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "11C",
                storyOwner: "day.idle",
                scenario: .morningReadiness,
                badge: "ВСЁ ХОРОШО",
                todayTitle: "Доброе утро",
                stackedDayActiveRisk: false,
                conflictNote: "morning idle — nutrition stays out of main/support copy"
            ),
            result: result,
            bridge: bridge
        )
        assertNoNutritionNarrative(in: try XCTUnwrap(result.copyPack))
    }

    func testEdgeCase11D_emptyAfternoonNoFoodNoWater() throws {
        let afternoon = date(hour: 14, minute: 0)
        let result = evaluate(
            now: afternoon,
            activities: [],
            nutrition: emptyNutrition(),
            brainHour: 14
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "11D",
                storyOwner: "day.idle",
                scenario: .stableDay,
                badge: "ВСЁ ХОРОШО",
                todayTitle: "Спокойный день",
                stackedDayActiveRisk: false,
                conflictNote: "afternoon idle may surface nutrition in supporting signals"
            ),
            result: result,
            bridge: bridge
        )
        XCTAssertTrue(result.modifiers.fuelBehind || result.modifiers.hydrationBehind)
    }

    func testEdgeCase11E_emptyEveningNoFoodNoWater() throws {
        let evening = date(hour: 20, minute: 0)
        let result = evaluate(
            now: evening,
            activities: [],
            nutrition: emptyNutrition(),
            brainHour: 20
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "11E",
                storyOwner: "day.idle",
                scenario: .stableDay,
                badge: "ВСЁ ХОРОШО",
                todayTitle: "Спокойный день",
                stackedDayActiveRisk: false,
                conflictNote: "evening idle without tomorrow demand stays stableDay"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase12B_heavyYesterdayBadRecoveryFreshMorning() throws {
        let morning = date(hour: 7, minute: 30)
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 7
        brainConfig.completedWorkoutsCount = 2
        brainConfig.strain = .high
        brainConfig.recovery = .compromised

        let result = evaluate(
            now: morning,
            activities: [],
            actualLoad: freshActualLoad(),
            recovery: CoachRecoveryContext(recoveryPercent: 38, sleepHours: 4.5),
            brainHour: 7,
            brain: HumanBrainStateBuilder.make(brainConfig)
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "12B",
                storyOwner: "day.idle",
                scenario: .recoveryAfterHeavyYesterday,
                badge: "БЕРЕЖЁМ СИЛЫ",
                todayTitle: "Спокойный день восстановле…",
                stackedDayActiveRisk: false,
                conflictNote: "heavy yesterday + bad recovery — recovery day story"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase12C_heavyYesterdayNoPlanToday() throws {
        let afternoon = date(hour: 14, minute: 0)
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 14
        brainConfig.completedWorkoutsCount = 2
        brainConfig.metrics = CoachMetricsBuilder.metrics(activeCalories: 850)

        let result = evaluate(
            now: afternoon,
            activities: [],
            actualLoad: freshActualLoad(),
            recovery: CoachRecoveryContext(recoveryPercent: 78, sleepHours: 7),
            brainHour: 14,
            brain: HumanBrainStateBuilder.make(brainConfig)
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "12C",
                storyOwner: "day.idle",
                scenario: .stableDay,
                badge: "ВСЁ ХОРОШО",
                todayTitle: "Спокойный день",
                stackedDayActiveRisk: false,
                conflictNote: "heavy yesterday + good recovery afternoon — stable day with support"
            ),
            result: result,
            bridge: bridge
        )
        assertSupportContains(try XCTUnwrap(result.copyPack), token: "вчера")
    }

    // MARK: - 14. Sauna conflicts

    func testEdgeCase14A_saunaAfterLongEnduranceFocusesHeat() throws {
        let evening = date(hour: 18, minute: 30)
        let completedRide = PlannedActivityBuilder.workout(
            title: "Long Ride",
            at: CoachTestClock.offset(hours: -8, from: evening),
            durationMinutes: 180,
            completed: true
        )
        let upcomingSauna = saunaActivity(
            title: "Sauna",
            start: evening.addingTimeInterval(20 * 60),
            durationMinutes: 25
        )
        let result = evaluate(
            now: evening,
            activities: [completedRide, upcomingSauna],
            actualLoad: heavyActualLoad(),
            brainHour: 18
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "14A",
                storyOwner: "session.activity",
                scenario: .saunaPreparation,
                badge: "СЕЙЧАС ВАЖНО",
                todayTitle: "Перед баней",
                stackedDayActiveRisk: false,
                conflictNote: "completed endurance outside 180m window — sauna owns pre-session story"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase14B_saunaActiveWithHydrationCritical() throws {
        let now = date(hour: 16, minute: 0)
        let sauna = saunaActivity(
            title: "Sauna",
            start: now.addingTimeInterval(-10 * 60),
            durationMinutes: 25
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 1_600,
            caloriesGoal: 2_800,
            proteinCurrent: 80,
            proteinGoal: 140,
            waterCurrent: 0.3,
            waterGoal: 2.5
        )
        let result = evaluate(
            now: now,
            activities: [sauna],
            nutrition: nutrition,
            brainHour: 16,
            focus: sauna
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "14B",
                storyOwner: "session.activity+overlay.nutrition",
                scenario: .saunaActive,
                badge: "ВАЖНО",
                todayTitle: "В бане",
                stackedDayActiveRisk: false,
                conflictNote: "hydration critical is warning overlay — sauna scenario unchanged"
            ),
            result: result,
            bridge: bridge
        )
        XCTAssertEqual(result.resolution.safetyAlert, .hydrationCritical)
    }

    func testEdgeCase14C_saunaLateEveningActive() throws {
        let lateEvening = date(hour: 22, minute: 15)
        let sauna = saunaActivity(
            title: "Sauna",
            start: lateEvening.addingTimeInterval(-8 * 60),
            durationMinutes: 25
        )
        let result = evaluate(
            now: lateEvening,
            activities: [sauna],
            brainHour: 22,
            focus: sauna
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "14C",
                storyOwner: "session.activity",
                scenario: .saunaActive,
                badge: "СЕЙЧАС",
                todayTitle: "В бане",
                stackedDayActiveRisk: false,
                conflictNote: "late evening clock does not swap sauna for wind-down idle"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase14D_saunaBeforeTomorrowHardWorkout() throws {
        let evening = date(hour: 19, minute: 30)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!
        let upcomingSauna = saunaActivity(
            title: "Sauna",
            start: evening.addingTimeInterval(25 * 60),
            durationMinutes: 25
        )
        let tomorrowRun = PlannedActivityBuilder.workout(
            title: "Long Run",
            at: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!,
            durationMinutes: 90
        )
        let result = evaluate(
            now: evening,
            activities: [upcomingSauna, tomorrowRun],
            actualLoad: heavyActualLoad(),
            brainHour: 19,
            focus: upcomingSauna
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "14D",
                storyOwner: "session.activity",
                scenario: .saunaPreparation,
                badge: "СЕЙЧАС ВАЖНО",
                todayTitle: "Перед баней",
                stackedDayActiveRisk: false,
                conflictNote: "tomorrow hard session does not override live sauna prep focus"
            ),
            result: result,
            bridge: bridge
        )
    }

    // MARK: - 15. Multi-activity day

    func testEdgeCase15A_walkCyclingStrengthActiveRideWins() throws {
        let now = date(hour: 14, minute: 0)
        let morningWalk = walkActivity(
            title: "Morning Walk",
            start: date(hour: 8, minute: 0),
            durationMinutes: 45,
            completed: true
        )
        let activeRide = cyclingActivity(
            title: "Ride",
            start: now.addingTimeInterval(-20 * 60),
            durationMinutes: 90
        )
        let upcomingStrength = strengthActivity(
            title: "Strength",
            start: now.addingTimeInterval(120 * 60),
            durationMinutes: 55
        )
        let result = evaluate(
            now: now,
            activities: [morningWalk, activeRide, upcomingStrength],
            brainHour: 14
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "15A",
                storyOwner: "session.activity",
                scenario: .duringEndurance,
                badge: "СЕЙЧАС",
                todayTitle: "На заезде",
                stackedDayActiveRisk: false,
                conflictNote: "one primary story — live ride beats walk + upcoming strength"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase15B_cyclingThenSaunaActiveSaunaWins() throws {
        let evening = date(hour: 18, minute: 0)
        let completedRide = cyclingActivity(
            title: "Long Ride",
            start: date(hour: 10, minute: 0),
            durationMinutes: 150,
            completed: true
        )
        let activeSauna = saunaActivity(
            title: "Sauna",
            start: evening.addingTimeInterval(-5 * 60),
            durationMinutes: 25
        )
        let result = evaluate(
            now: evening,
            activities: [completedRide, activeSauna],
            actualLoad: heavyActualLoad(),
            brainHour: 18
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "15B",
                storyOwner: "session.activity",
                scenario: .saunaActive,
                badge: "СЕЙЧАС",
                todayTitle: "В бане",
                stackedDayActiveRisk: false,
                conflictNote: "live sauna beats completed endurance — no split narration"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase15C_strengthThenWalkRecoveryUpcomingWalk() throws {
        let afternoon = date(hour: 15, minute: 30)
        let completedStrength = strengthActivity(
            title: "Strength",
            start: date(hour: 9, minute: 0),
            durationMinutes: 55,
            completed: true
        )
        let upcomingWalk = walkActivity(
            title: "Recovery Walk",
            start: afternoon.addingTimeInterval(25 * 60),
            durationMinutes: 30
        )
        let result = evaluate(
            now: afternoon,
            activities: [completedStrength, upcomingWalk],
            actualLoad: moderateActualLoad(),
            brainHour: 15,
            focus: upcomingWalk
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "15C",
                storyOwner: "session.activity",
                scenario: .walkRecoveryAction,
                badge: "СЕЙЧАС ВАЖНО",
                todayTitle: "Прогулка для ног",
                stackedDayActiveRisk: false,
                conflictNote: "walk after serious work — single recovery story, not strength post"
            ),
            result: result,
            bridge: bridge
        )
    }

    func testEdgeCase15D_racketThenSaunaUpcomingSauna() throws {
        let lateAfternoon = date(hour: 17, minute: 0)
        let completedTennis = racketActivity(
            title: "Tennis",
            start: date(hour: 8, minute: 0),
            durationMinutes: 90,
            completed: true
        )
        let upcomingSauna = saunaActivity(
            title: "Sauna",
            start: lateAfternoon.addingTimeInterval(30 * 60),
            durationMinutes: 25
        )
        let result = evaluate(
            now: lateAfternoon,
            activities: [completedTennis, upcomingSauna],
            actualLoad: moderateActualLoad(),
            brainHour: 17
        )
        let bridge = try requireBridge(result)

        assertExpectation(
            Expectation(
                caseID: "15D",
                storyOwner: "session.activity",
                scenario: .saunaPreparation,
                badge: "СЕЙЧАС ВАЖНО",
                todayTitle: "Перед баней",
                stackedDayActiveRisk: false,
                conflictNote: "completed racket outside 180m — sauna prep is sole story"
            ),
            result: result,
            bridge: bridge
        )
    }

    // MARK: - 16. Transition stability

    func testEdgeCase16A_enduranceActiveToPostNoFlicker() throws {
        let rideStart = date(hour: 13, minute: 30)
        let ride = cyclingActivity(
            title: "Ride",
            start: rideStart,
            durationMinutes: 90,
            completed: false
        )
        let checkpoints: [(hour: Int, minute: Int, scenario: CoachScenarioKey, markComplete: Bool)] = [
            (14, 0, .duringEndurance, false),
            (14, 10, .duringEndurance, false),
            (14, 15, .duringEndurance, false),
            (15, 5, .postEnduranceImmediate, true),
            (15, 12, .postEnduranceImmediate, true),
            (16, 45, .postEnduranceSettled, true),
            (21, 30, .eveningAfterEndurance, true)
        ]

        var previous: CoachScenarioKey?
        for checkpoint in checkpoints {
            ride.isCompleted = checkpoint.markComplete
            let now = date(hour: checkpoint.hour, minute: checkpoint.minute)
            let result = evaluate(
                now: now,
                activities: [ride],
                brainHour: checkpoint.hour,
                focus: ride
            )
            XCTAssertEqual(result.scenario, checkpoint.scenario, "At \(checkpoint.hour):\(checkpoint.minute)")
            if let previous, !isAllowedScenarioTransition(from: previous, to: result.scenario) {
                XCTFail("Disallowed flicker \(previous) → \(result.scenario) at \(checkpoint.hour):\(checkpoint.minute)")
            }
            previous = result.scenario
        }
    }

    func testEdgeCase16B_adjacentMinutesStayOnSameStory() throws {
        let rideStart = date(hour: 14, minute: 0)
        let ride = cyclingActivity(
            title: "Ride",
            start: rideStart,
            durationMinutes: 120
        )
        for minuteOffset in [0, 10, 15] {
            let now = rideStart.addingTimeInterval(TimeInterval(minuteOffset * 60))
            let result = evaluate(
                now: now,
                activities: [ride],
                brainHour: 14,
                focus: ride
            )
            XCTAssertEqual(result.scenario, .duringEndurance, "minute +\(minuteOffset)")
        }
    }

    func testEdgeCase16C_prematureHealthKitCompletionStaysDuringUntilPlannedEnd() throws {
        let rideStart = date(hour: 14, minute: 0)
        var ride = cyclingActivity(
            title: "Ride",
            start: rideStart,
            durationMinutes: 90,
            completed: true
        )
        ride.source = "appleWorkout"

        let duringOffsetsMinutes = [20, 45, 90]
        for offset in duringOffsetsMinutes {
            let now = rideStart.addingTimeInterval(TimeInterval(offset * 60))
            let result = evaluate(
                now: now,
                activities: [ride],
                brainHour: Calendar.current.component(.hour, from: now),
                focus: ride
            )
            XCTAssertEqual(
                result.scenario,
                .duringEndurance,
                "HK complete before planned end + grace at +\(offset)m"
            )
            XCTAssertEqual(result.context.sessionPhase, .during)
        }

        let postNow = rideStart.addingTimeInterval(96 * 60)
        let postResult = evaluate(
            now: postNow,
            activities: [ride],
            brainHour: Calendar.current.component(.hour, from: postNow),
            focus: ride
        )
        XCTAssertEqual(postResult.scenario, .postEnduranceImmediate)
    }

    // MARK: - Matrix printer

    func testPrintEdgeCaseMatrix() {
        print(CoachEdgeCaseMatrixPrinter.renderHeader())
        print("See individual test logs above when running full CoachEdgeCaseSnapshotTests suite.")
        print("Log: \(CoachEdgeCaseMatrixPrinter.logFileURL.path)")
    }

    // MARK: - Assertions

    private func assertExpectation(
        _ expected: Expectation,
        result: CoachEngine.Result,
        bridge: CoachUIPresentation
    ) {
        let row = CoachEdgeCaseMatrixPrinter.format(
            caseID: expected.caseID,
            owner: expected.storyOwner,
            scenario: result.scenario,
            badge: bridge.statusLabel,
            todayTitle: bridge.todayTitle,
            conflict: expected.conflictNote,
            stacked: result.modifiers.stackedDayActiveRisk
        )
        print(row)
        CoachEdgeCaseMatrixPrinter.appendToLog(row)

        XCTAssertEqual(result.scenario, expected.scenario, row)
        XCTAssertEqual(bridge.statusLabel, expected.badge, row)
        XCTAssertEqual(bridge.todayTitle, expected.todayTitle, row)
        XCTAssertEqual(result.modifiers.stackedDayActiveRisk, expected.stackedDayActiveRisk, row)
        XCTAssertNotNil(result.copyPack, row)
    }

    private func requireBridge(_ result: CoachEngine.Result) throws -> CoachUIPresentation {
        try XCTUnwrap(CoachTabPresentationBridge.build(from: result))
    }

    // MARK: - Builders

    private func evaluate(
        now: Date,
        activities: [PlannedActivity],
        nutrition: CoachNutritionContext? = nil,
        actualLoad: CoachActualLoadSnapshot? = nil,
        recovery: CoachRecoveryContext? = nil,
        brainHour: Int,
        focus: PlannedActivity? = nil,
        brain: HumanBrain.State? = nil
    ) -> CoachEngine.Result {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = brainHour

        let input = CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: brain ?? HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities.coachSnapshots(),
            actualLoad: actualLoad ?? freshActualLoad(),
            recoveryContext: recovery ?? CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutritionContext: nutrition ?? defaultNutrition(),
            source: "CoachEdgeCaseSnapshotTests"
        )
        return CoachEngine.evaluate(input: input, focusActivity: focus)
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

    private func saunaActivity(
        title: String,
        start: Date,
        durationMinutes: Int,
        completed: Bool = false
    ) -> PlannedActivity {
        let activity = PlannedActivity(
            date: start,
            type: "sauna",
            title: title,
            durationMinutes: durationMinutes,
            icon: "flame.fill",
            colorRed: 0.9,
            colorGreen: 0.35,
            colorBlue: 0.2,
            isCompleted: completed
        )
        return activity
    }

    private func walkActivity(
        title: String,
        start: Date,
        durationMinutes: Int,
        completed: Bool = false
    ) -> PlannedActivity {
        PlannedActivity(
            date: start,
            type: "walk",
            title: title,
            durationMinutes: durationMinutes,
            icon: "figure.walk",
            colorRed: 0.3,
            colorGreen: 0.7,
            colorBlue: 0.4,
            isCompleted: completed
        )
    }

    private func strengthActivity(
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
            icon: "figure.core.training",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: completed
        )
    }

    private func racketActivity(
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
            icon: "figure.tennis",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: completed
        )
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

    private func assertNoNutritionNarrative(in pack: CoachCopyPack) {
        let banned = ["еда", "вод", "калор", "поест", "пить", "пейте", "завтрак"]
        let sections = [
            joinedRussian(pack.assessment),
            joinedRussian(pack.recommendation),
            joinedRussian(pack.avoid),
            joinedRussian(pack.nextAction)
        ] + pack.supportingSignals.lines.map(\.russian)
        for text in sections {
            let lower = text.lowercased()
            for token in banned {
                XCTAssertFalse(
                    lower.contains(token),
                    "Unexpected nutrition token '\(token)' in: \(text)"
                )
            }
        }
        XCTAssertTrue(pack.supportingSignals.lines.isEmpty)
        XCTAssertNil(pack.warningLayer)
    }

    private func assertSupportContains(_ pack: CoachCopyPack, token: String) {
        let combined = pack.supportingSignals.lines
            .map(\.russian)
            .joined(separator: " ")
            .lowercased()
        XCTAssertTrue(combined.contains(token.lowercased()), "Expected support token '\(token)' in: \(combined)")
    }

    private func assertSupportDoesNotContain(_ pack: CoachCopyPack, token: String) {
        let combined = pack.supportingSignals.lines
            .map(\.russian)
            .joined(separator: " ")
            .lowercased()
        XCTAssertFalse(combined.contains(token.lowercased()), "Unexpected support token '\(token)' in: \(combined)")
    }

    private func assertRecommendationContains(_ pack: CoachCopyPack, token: String) {
        let combined = joinedRussian(pack.recommendation).lowercased()
        XCTAssertTrue(combined.contains(token.lowercased()), "Expected recommendation token '\(token)' in: \(combined)")
    }

    private func joinedRussian(_ section: CoachCopySection) -> String {
        section.lines.map(\.russian).joined(separator: " ")
    }

    private func isAllowedScenarioTransition(
        from previous: CoachScenarioKey,
        to next: CoachScenarioKey
    ) -> Bool {
        if previous == next { return true }
        let forward: Set<CoachScenarioKey> = [
            .duringEndurance, .postEnduranceImmediate, .postEnduranceSettled, .eveningAfterEndurance
        ]
        guard forward.contains(previous), forward.contains(next) else { return true }
        let order: [CoachScenarioKey] = [
            .duringEndurance, .postEnduranceImmediate, .postEnduranceSettled, .eveningAfterEndurance
        ]
        guard let prevIndex = order.firstIndex(of: previous),
              let nextIndex = order.firstIndex(of: next) else {
            return true
        }
        return nextIndex >= prevIndex
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    private func defaultNutrition() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 1_800,
            caloriesGoal: 2_800,
            proteinCurrent: 90,
            proteinGoal: 140,
            waterCurrent: 1.8,
            waterGoal: 2.5
        )
    }

    private func freshActualLoad() -> CoachActualLoadSnapshot {
        CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 200,
            exerciseMinutes: 20,
            standHours: nil,
            activityGoalCalories: 600,
            activityProgress: 0.4
        )
    }

    private func moderateActualLoad() -> CoachActualLoadSnapshot {
        CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 550,
            exerciseMinutes: 70,
            standHours: nil,
            activityGoalCalories: 600,
            activityProgress: 1.1
        )
    }

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
}

// MARK: - Printer

enum CoachEdgeCaseMatrixPrinter {

    static let logFileURL = URL(fileURLWithPath: "/tmp/WeekFitCoachEdgeCaseMatrix.txt")

    static func renderHeader() -> String {
        """
        Coach Edge Case Matrix — ownership snapshot
        Fields: case | owner | scenario | badge | todayTitle | stacked | conflict
        """
    }

    static func format(
        caseID: String,
        owner: String,
        scenario: CoachScenarioKey,
        badge: String,
        todayTitle: String,
        conflict: String?,
        stacked: Bool
    ) -> String {
        let conflictText = conflict ?? "—"
        return """
        CASE \(caseID)
        owner: \(owner)
        scenario: \(scenario.rawValue)
        badge: \(badge)
        todayTitle: \(todayTitle)
        stackedDayActiveRisk: \(stacked)
        conflict: \(conflictText)
        """
    }

    static func appendToLog(_ text: String) {
        let line = text + "\n\n"
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
                try? handle.close()
            }
        } else {
            try? line.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }
}
