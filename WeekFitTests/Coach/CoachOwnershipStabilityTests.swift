import XCTest
@testable import WeekFit

/// Ownership + phase stability fixes (audit P1–P3).
final class CoachOwnershipStabilityTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    // MARK: - P1: premature HealthKit completion

    func testPrematureHealthKitCompletionStaysDuringEndurance() {
        let start = date(hour: 14, minute: 0)
        let now = date(hour: 14, minute: 20)
        let ride = cyclingActivity(
            title: "Ride",
            start: start,
            durationMinutes: 90,
            completed: true
        )
        ride.source = "appleWorkout"

        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [ride], brainHour: 14),
            focusActivity: ride
        )

        XCTAssertEqual(result.scenario, .duringEndurance)
        XCTAssertEqual(result.context.sessionPhase, .during)
        XCTAssertEqual(result.context.activityState, .active)
    }

    func testPrematureHealthKitCompletionStaysDuringRecoveryYoga() {
        let start = date(hour: 18, minute: 0)
        let now = start.addingTimeInterval(25 * 60)
        let yoga = PlannedActivity(
            date: start,
            type: "recovery",
            title: "Yoga",
            durationMinutes: 60,
            icon: "figure.yoga",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: true,
            source: "healthKit"
        )

        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [yoga], brainHour: 18),
            focusActivity: yoga
        )

        XCTAssertEqual(result.scenario, .duringRecovery)
        XCTAssertEqual(result.context.sessionPhase, .during)
    }

    func testPrematureHealthKitCompletionTransitionsAfterGraceWindow() {
        let start = date(hour: 14, minute: 0)
        let now = start.addingTimeInterval(96 * 60)
        let ride = cyclingActivity(
            title: "Ride",
            start: start,
            durationMinutes: 90,
            completed: true
        )
        ride.source = "appleWorkout"

        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [ride], brainHour: Calendar.current.component(.hour, from: now)),
            focusActivity: ride
        )

        XCTAssertEqual(result.scenario, .postEnduranceImmediate)
        XCTAssertEqual(result.context.sessionPhase, .immediatePost)
    }

    func testCompletedStrengthAfterPlannedEndDoesNotUseStabilityGrace() {
        let start = date(hour: 14, minute: 0)
        let now = date(hour: 16, minute: 10)
        let core = PlannedActivity(
            date: start,
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: true,
            source: "appleWorkout"
        )

        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [core], brainHour: 16),
            focusActivity: core
        )

        XCTAssertEqual(result.scenario, .postStrengthSettled)
        XCTAssertNotEqual(result.context.sessionPhase, .during)
    }

    // MARK: - P2: upcoming today beats tomorrow protection

    func testUpcomingEveningYogaBlocksTomorrowProtectionOnCompletedFocus() {
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
        let upcomingYoga = PlannedActivity(
            date: evening.addingTimeInterval(45 * 60),
            type: "recovery",
            title: "Yoga",
            durationMinutes: 45,
            icon: "figure.yoga",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: evening,
                activities: [completedRide, upcomingYoga, tomorrowRun],
                actualLoad: heavyActualLoad(),
                brainHour: 20
            ),
            focusActivity: completedRide
        )

        XCTAssertNotEqual(result.scenario, .tomorrowProtection)
        XCTAssertEqual(result.scenario, .eveningAfterEndurance)
    }

    func testUpcomingEveningWalkAutoFocusBeatsTomorrowProtection() {
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
        let upcomingWalk = PlannedActivity(
            date: evening.addingTimeInterval(30 * 60),
            type: "recovery",
            title: "Evening Walk",
            durationMinutes: 30,
            icon: "figure.walk",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: evening,
                activities: [completedRide, upcomingWalk, tomorrowRun],
                actualLoad: heavyActualLoad(),
                brainHour: 20
            )
        )

        XCTAssertNotEqual(result.scenario, .tomorrowProtection)
        XCTAssertEqual(result.scenario, .walkEveningWindDown)
    }

    func testUpcomingEveningStrengthAutoFocusBeatsTomorrowProtection() {
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
        let upcomingCore = PlannedActivity(
            date: evening.addingTimeInterval(30 * 60),
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: evening,
                activities: [completedRide, upcomingCore, tomorrowRun],
                actualLoad: heavyActualLoad(),
                brainHour: 20
            )
        )

        XCTAssertNotEqual(result.scenario, .tomorrowProtection)
        XCTAssertEqual(result.scenario, .activeStrength)
        XCTAssertTrue(result.modifiers.stackedDayActiveRisk)
    }

    // MARK: - P3: stacked overlay keeps scenario chrome

    func testStackedOverlayKeepsDuringStrengthTitleAndScenarioCopy() throws {
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
            date: CoachTestClock.offset(minutes: -8, from: lateEvening),
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        let result = CoachEngine.evaluate(
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
        XCTAssertEqual(result.todayInsight.semanticColor, .live)

        let pack = try XCTUnwrap(result.copyPack)
        XCTAssertTrue(
            pack.assessment.lines.first?.english.localizedCaseInsensitiveContains("core") == true ||
                pack.assessment.lines.first?.english.localizedCaseInsensitiveContains("live") == true
        )
        XCTAssertTrue(pack.supportingSignals.lines.contains {
            $0.english.localizedCaseInsensitiveContains("stacked") ||
                $0.russian.localizedCaseInsensitiveContains("предел")
        })

        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))
        XCTAssertTrue(
            bridge.todayTitle.localizedCaseInsensitiveContains("силовая") ||
                bridge.todayTitle.localizedCaseInsensitiveContains("Lifting")
        )
        XCTAssertTrue(
            bridge.coachTitle.localizedCaseInsensitiveContains("load") ||
                bridge.coachTitle.localizedCaseInsensitiveContains("нагрузкой")
        )
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
        actualLoad: CoachActualLoadSnapshot? = nil,
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
                caloriesCurrent: 1_800,
                caloriesGoal: 2_800,
                proteinCurrent: 90,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            source: "CoachOwnershipStabilityTests"
        )
    }

    private func cyclingActivity(
        title: String,
        start: Date,
        durationMinutes: Int,
        completed: Bool
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

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
