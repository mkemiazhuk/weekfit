import XCTest
@testable import WeekFit

final class CoachTabPresentationBridgeTests: XCTestCase {

    func testBridgeReturnsNilWhenCopyPackMissing() {
        let modifiers = CoachScenarioModifiers(
            dayLoad: .moderate,
            fuelBehind: false,
            hydrationBehind: false,
            tomorrowDemand: .none,
            activityType: .fullBody,
            durationBand: .medium,
            completedSeriousActivities: .none,
            timeOfDay: .afternoon,
            stackedDayActiveRisk: false,
            lastCompletedActivityType: .none
        )
        let context = CoachContext(
            activityFamily: .strength,
            activityType: .fullBody,
            activityState: .active,
            sessionPhase: .during,
            durationBand: .medium,
            dayLoadBand: .moderate,
            completedSeriousActivities: .none,
            fuelState: .adequate,
            hydrationState: .adequate,
            tomorrowDemand: .none,
            timeOfDay: .afternoon,
            tomorrowWorkout: nil,
            focusActivityID: "strength",
            focusSource: .active,
            minutesUntilStart: nil,
            minutesSinceEnd: nil,
            dayReadiness: .unknown,
            lastCompletedSeriousActivityType: .none
        )
        let resolution = CoachScenarioResolution(
            scenario: .duringStrength,
            modifiers: modifiers,
            safetyAlert: nil
        )
        let insight = CoachTodayInsight(
            scenario: .duringStrength,
            modifiers: modifiers,
            semanticColor: .live,
            alertSeverity: .none,
            safetyAlert: nil,
            icon: "dumbbell.fill",
            urgencyLevel: .live
        )
        let result = CoachEngine.Result(
            context: context,
            resolution: resolution,
            todayInsight: insight,
            copyPack: nil
        )

        XCTAssertNil(CoachTabPresentationBridge.build(from: result))
    }

    func testBridgeMapsStableDayCopyToTabPresentations() throws {
        let now = CoachTestClock.reference
        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [], brainHour: 14)
        )
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertFalse(bridge.today.title.isEmpty)
        XCTAssertFalse(bridge.today.message.isEmpty)
        XCTAssertEqual(bridge.today.icon, result.todayInsight.icon)
        XCTAssertEqual(bridge.coach.message, bridge.ui.assessment)
        XCTAssertEqual(bridge.coach.recommendation, bridge.ui.recommendation)
        XCTAssertEqual(bridge.coach.avoidNotes, [bridge.ui.avoid])
        XCTAssertEqual(bridge.coach.whyRows.count, bridge.ui.supportingSignals.count)
    }

    func testBridgeTodayCopyIsConcise() throws {
        let now = CoachTestClock.reference
        let result = CoachEngine.evaluate(
            input: makeInput(now: now, activities: [], brainHour: 14)
        )
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertLessThanOrEqual(bridge.today.title.count, 27)
        XCTAssertLessThanOrEqual(bridge.today.message.count, 89)
    }

    func testBridgeTomorrowProtectionTodayTitleIsShortWithoutTomorrow() throws {
        let evening = date(hour: 22, minute: 23)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!

        let completedRide = PlannedActivityBuilder.workout(
            title: "Long Ride",
            at: CoachTestClock.offset(hours: -10, from: evening),
            durationMinutes: 180,
            completed: true
        )
        let tomorrowCore = PlannedActivity(
            date: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: tomorrow)!,
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: evening,
                activities: [completedRide, tomorrowCore],
                actualLoad: heavyActualLoad(),
                brainHour: 22
            ),
            focusActivity: completedRide
        )
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertTrue(
            bridge.today.title.localizedCaseInsensitiveContains("достаточно") ||
                bridge.today.title.localizedCaseInsensitiveContains("protect")
        )
        XCTAssertFalse(bridge.today.title.lowercased().contains("tomorrow"))
        XCTAssertFalse(bridge.today.title.contains("завтра"))
        XCTAssertFalse(bridge.today.title.contains("Core"))
        XCTAssertLessThanOrEqual(bridge.today.title.count, 22)
        XCTAssertTrue(bridge.today.message.contains("сон") || bridge.today.message.contains("sleep"))
    }

    func testBridgeWhyRowsUsePerSignalColorsWhenFuelAndHydrationBehind() throws {
        let evening = date(hour: 22, minute: 0)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!
        let completedRide = PlannedActivityBuilder.workout(
            title: "Long Ride",
            at: CoachTestClock.offset(hours: -10, from: evening),
            durationMinutes: 180,
            completed: true
        )
        let tomorrowCore = PlannedActivity(
            date: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: tomorrow)!,
            type: "workout",
            title: "Core",
            durationMinutes: 55,
            icon: "figure.core.training",
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )
        let nutrition = CoachNutritionContext(
            caloriesCurrent: 900,
            caloriesGoal: 2_800,
            proteinCurrent: 40,
            proteinGoal: 140,
            waterCurrent: 0.9,
            waterGoal: 2.5
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: evening,
                activities: [completedRide, tomorrowCore],
                nutrition: nutrition,
                actualLoad: heavyActualLoad(),
                brainHour: 22
            ),
            focusActivity: completedRide
        )
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertGreaterThanOrEqual(bridge.coach.whyRows.count, 2)
        XCTAssertEqual(bridge.coach.whyRows[0].icon, "drop.fill")
        XCTAssertEqual(bridge.coach.whyRows[1].icon, "fork.knife")
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
            source: "CoachTabPresentationBridgeTests"
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
}
