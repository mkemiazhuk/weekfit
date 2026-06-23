import XCTest
@testable import WeekFit

final class CoachV6CopyNutritionTimingTests: XCTestCase {

    func testWindDownFuelSignalIsShortFactOnly() {
        let input = makeInput(timeOfDay: .lateEvening, fuelBehind: true)
        let text = joined(CoachV6CopyNutritionTiming.fuelBehindSignal(for: input))

        XCTAssertTrue(text.lowercased().contains("calories") || text.contains("Калорий"))
        XCTAssertFalse(text.lowercased().contains("breakfast"))
        XCTAssertFalse(text.contains("завтрак"))
    }

    func testDaytimeFuelSignalUsesNeutralLagCopy() {
        let input = makeInput(timeOfDay: .afternoon, fuelBehind: true)
        let text = joined(CoachV6CopyNutritionTiming.fuelBehindSignal(for: input))

        XCTAssertTrue(text.lowercased().contains("lagging") || text.contains("меньше"))
    }

    func testWindDownFuelNextActionPlansBreakfast() {
        let input = makeInput(timeOfDay: .lateEvening, fuelBehind: true)
        let text = joined(CoachV6CopyNutritionTiming.fuelCatchUpNextAction(for: input))

        XCTAssertTrue(text.contains("breakfast") || text.contains("завтрак"))
        XCTAssertFalse(text.lowercased().contains("proper meal"))
    }

    func testDaytimeFuelNextActionMentionsMeal() {
        let input = makeInput(timeOfDay: .afternoon, fuelBehind: true)
        let text = joined(CoachV6CopyNutritionTiming.fuelCatchUpNextAction(for: input))

        XCTAssertTrue(text.lowercased().contains("meal") || text.contains("поеш") || text.contains("Пое"))
    }

    func testWindDownHydrationCriticalWarningAvoidsChuggingBeforeBed() {
        let warning = CoachV6CopyNutritionTiming.hydrationCriticalWarning(
            isActiveSession: false,
            timeOfDay: .lateEvening
        )
        let text = joined(warning)

        XCTAssertTrue(text.lowercased().contains("wind down") || text.contains("отдых"))
        XCTAssertFalse(text.lowercased().contains("sip now, steadily"))
    }

    func testActiveSessionHydrationCriticalStillUrgesSippingNow() {
        let warning = CoachV6CopyNutritionTiming.hydrationCriticalWarning(
            isActiveSession: true,
            timeOfDay: .lateEvening
        )
        let text = joined(warning)

        XCTAssertTrue(text.lowercased().contains("sip now") || text.contains("пейте сейчас"))
    }

    func testTomorrowProtectionLateEveningWithFuelUsesWindDownRecommendation() throws {
        let lateEvening = date(hour: 22, minute: 23)
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
            colorRed: 0.2,
            colorGreen: 0.6,
            colorBlue: 0.9
        )
        let fuelBehind = CoachNutritionContext(
            caloriesCurrent: 900,
            caloriesGoal: 2_800,
            proteinCurrent: 40,
            proteinGoal: 140,
            waterCurrent: 1.2,
            waterGoal: 2.5
        )

        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 22

        let result = CoachV6Engine.evaluate(
            input: CoachInputSnapshot(
                selectedDate: lateEvening,
                now: lateEvening,
                brain: HumanBrainStateBuilder.make(brainConfig),
                plannedActivities: [completedRide, tomorrowCore],
                actualLoad: CoachActualLoadSnapshot(
                    source: .healthKitSamplesWithAppGoalEstimate,
                    activeCalories: 2_758,
                    exerciseMinutes: 282,
                    standHours: 11,
                    activityGoalCalories: 700,
                    activityProgress: 3.94
                ),
                recoveryContext: CoachRecoveryContext(recoveryPercent: 80, sleepHours: 7.2),
                nutritionContext: fuelBehind,
                source: "CoachV6CopyNutritionTimingTests"
            ),
            focusActivity: completedRide
        )

        let pack = try XCTUnwrap(result.copyPack)
        XCTAssertEqual(pack.scenario, .tomorrowProtection)

        let recommendation = pack.recommendation.lines.first?.english.lowercased() ?? ""
        XCTAssertTrue(recommendation.contains("sleep"))
        XCTAssertFalse(recommendation.contains("breakfast"))

        let nextAction = pack.nextAction.lines.first?.english.lowercased() ?? ""
        XCTAssertFalse(nextAction.contains("proper meal"))
    }

    // MARK: - Helpers

    private func makeInput(timeOfDay: CoachV6TimeOfDay, fuelBehind: Bool) -> CoachV6CopyBuildInput {
        CoachV6CopyBuildInput(
            scenario: .tomorrowProtection,
            modifiers: CoachV6ScenarioModifiers(
                dayLoad: .heavy,
                fuelBehind: fuelBehind,
                hydrationBehind: false,
                tomorrowDemand: .hard,
                activityType: .none,
                durationBand: .short,
                completedSeriousActivities: .one,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false
            ),
            fuelState: fuelBehind ? .behind : .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .protection,
            alertSeverity: fuelBehind ? .elevated : .none,
            tomorrowWorkout: CoachV6TomorrowWorkout(
                title: "Core",
                startHour: 10,
                startMinute: 30,
                durationMinutes: 55
            ),
            dayReadiness: .unknown
        )
    }

    private func joined(_ line: CoachV6BilingualText) -> String {
        "\(line.english) \(line.russian)"
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
