import XCTest
@testable import WeekFit

final class CoachDayClosingCopyPolicyTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.russian)
        CoachSessionTracker.resetForTests()
    }

    override func tearDown() {
        CoachSessionTracker.resetForTests()
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    // MARK: - 1. Low recovery, heavy day, 22:00 idle

    func testLateEveningLowRecoveryRestUsesWindDownCopy() throws {
        let lateEvening = date(hour: 22, minute: 0)
        let nutrition = behindNutrition()

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: lateEvening,
                activities: [],
                recovery: CoachRecoveryContext(recoveryPercent: 48, sleepHours: 5.0),
                actualLoad: heavyActualLoad(),
                nutrition: nutrition,
                brainHour: 22
            )
        )
        let pack = try XCTUnwrap(result.copyPack)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertEqual(result.context.conversationPhase, .dayClosing)
        XCTAssertEqual(resolveProfile(for: result), .lowRecoveryRest)

        XCTAssertEqual(bridge.todayTitle, "Завершаем день")
        XCTAssertTrue(pack.assessment.lines.first?.russian.contains("коротк") == true
            || pack.assessment.lines.first?.russian.contains("Сон") == true)
        XCTAssertFalse(pack.assessment.lines.first?.russian.contains("нагрузка за день") == true)
        XCTAssertTrue(pack.recommendation.lines.first?.russian.contains("дойти до сна") == true)
        XCTAssertFalse(allPackText(pack).containsDaytimeRecoveryTasks)
        XCTAssertFalse(allPackText(pack).mentionsNutritionCatchUp)
        XCTAssertFalse(result.modifiers.fuelBehind)
        XCTAssertFalse(result.modifiers.hydrationBehind)
    }

    // MARK: - 2. Serious work >180 min ago — stableDay/workBanked, wind-down

    func testLateEveningWorkBankedAfterExpiredPostWindowUsesWindDownCopy() throws {
        let lateEvening = date(hour: 22, minute: 0)
        let rideStart = date(hour: 14, minute: 0)
        let completedRide = PlannedActivity(
            date: rideStart,
            type: "workout",
            title: "Afternoon Ride",
            durationMinutes: 90,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            calories: 900,
            isCompleted: true
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: lateEvening,
                activities: [completedRide],
                actualLoad: heavyActualLoad(),
                brainHour: 22
            )
        )
        let pack = try XCTUnwrap(result.copyPack)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertEqual(result.context.focusSource, .idle)
        XCTAssertEqual(resolveProfile(for: result), .workBanked)
        XCTAssertEqual(result.context.conversationPhase, .dayClosing)

        XCTAssertEqual(bridge.todayTitle, "Завершаем день")
        XCTAssertTrue(pack.assessment.lines.first?.russian.contains("закрываем день") == true)
        XCTAssertFalse(allPackText(pack).containsDaytimeRecoveryTasks)
        XCTAssertFalse(allPackText(pack).contains("ещё один тяжёлый блок"))
    }

    // MARK: - 4. Completed evening walk at 23:23 — day closing, not another walk

    func testLateNightAfterCompletedEveningWalkUsesDayClosingNotEveningWalk() throws {
        let lateNight = date(hour: 23, minute: 23)
        let morningWalk = PlannedActivity(
            date: date(hour: 8, minute: 29),
            type: "recovery",
            title: "Walk",
            durationMinutes: 48,
            icon: "figure.walk",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: true
        )
        let eveningWalk = PlannedActivity(
            date: date(hour: 20, minute: 30),
            type: "recovery",
            title: "Walk",
            durationMinutes: 57,
            icon: "figure.walk",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: true
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: lateNight,
                activities: [morningWalk, eveningWalk],
                actualLoad: moderateActualLoad(),
                brainHour: 23
            )
        )
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertEqual(result.context.focusSource, .idle)
        XCTAssertEqual(result.context.conversationPhase, .dayClosing)
        XCTAssertEqual(result.context.timeOfDay, .night)
        XCTAssertNotEqual(result.scenario, .walkEveningWindDown)
        XCTAssertEqual(bridge.todayTitle, "Пора спать")
        XCTAssertTrue(bridge.todayMessage.lowercased().contains("сп"))
        let pack = try XCTUnwrap(result.copyPack)
        XCTAssertTrue(pack.nextAction.lines.first?.russian.contains("кроват") == true)
        XCTAssertFalse(pack.nextAction.lines.first?.russian.contains("ритуал") == true)
    }

    func testLateEveningBeforeMidnightStillUsesWindDownNotSleepNow() throws {
        let lateEvening = date(hour: 22, minute: 45)
        let eveningWalk = PlannedActivity(
            date: date(hour: 20, minute: 30),
            type: "recovery",
            title: "Walk",
            durationMinutes: 57,
            icon: "figure.walk",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            isCompleted: true
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: lateEvening,
                activities: [eveningWalk],
                actualLoad: moderateActualLoad(),
                brainHour: 22
            )
        )
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(result.context.timeOfDay, .lateEvening)
        XCTAssertEqual(bridge.todayTitle, "Завершаем день")
        XCTAssertTrue(pack.nextAction.lines.first?.russian.contains("ритуал") == true)
    }

    // MARK: - 3. Tomorrow reserve + today load — sleep-first

    func testLateEveningTomorrowReserveUsesSleepFirstFraming() throws {
        let lateEvening = date(hour: 22, minute: 0)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: lateEvening)!

        let completedRide = PlannedActivity(
            date: date(hour: 10, minute: 0),
            type: "workout",
            title: "Morning Ride",
            durationMinutes: 120,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            calories: 1_000,
            isCompleted: true
        )
        let tomorrowRun = PlannedActivity(
            date: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow)!,
            type: "workout",
            title: "Long Run",
            durationMinutes: 90,
            icon: "figure.run",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            calories: 800
        )

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: lateEvening,
                activities: [completedRide, tomorrowRun],
                actualLoad: moderateActualLoad(),
                brainHour: 22
            )
        )
        let pack = try XCTUnwrap(result.copyPack)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertEqual(resolveProfile(for: result), .tomorrowReserve)
        XCTAssertEqual(result.context.conversationPhase, .dayClosing)

        XCTAssertTrue(pack.recommendation.lines.first?.russian.contains("сон сейчас даст больше") == true)
        XCTAssertFalse(pack.recommendation.lines.first?.russian.contains("берегите силы на завтра") == true)
        XCTAssertTrue(bridge.todayMessage.contains("сон") || bridge.recommendation.contains("сон"))
    }

    // MARK: - 4. Afternoon stableDay — no overlay

    func testAfternoonStableDayKeepsDaytimeCopy() throws {
        let afternoon = date(hour: 14, minute: 0)

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: afternoon,
                activities: [],
                recovery: CoachRecoveryContext(recoveryPercent: 48, sleepHours: 5.0),
                brainHour: 14
            )
        )
        let pack = try XCTUnwrap(result.copyPack)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))

        XCTAssertEqual(result.context.conversationPhase, .steady)
        XCTAssertEqual(bridge.todayTitle, "Спокойный день восстановле…")
        XCTAssertTrue(pack.nextAction.lines.first?.russian.contains("прогул") == true
            || pack.nextAction.lines.first?.russian.contains("растяж") == true)
    }

    // MARK: - 5. Short sleep, no activity — sleep-specific wind-down, not load

    func testLateEveningShortSleepNoActivityUsesSleepNotLoadCopy() throws {
        let lateEvening = date(hour: 22, minute: 59)

        let result = CoachEngine.evaluate(
            input: makeInput(
                now: lateEvening,
                activities: [],
                recovery: CoachRecoveryContext(recoveryPercent: 72, sleepHours: 5.0),
                actualLoad: CoachActualLoadSnapshot(
                    source: .healthKitSamplesWithAppGoalEstimate,
                    activeCalories: 120,
                    exerciseMinutes: 5,
                    standHours: nil,
                    activityGoalCalories: 600,
                    activityProgress: 0.2
                ),
                brainHour: 22
            )
        )
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertEqual(result.context.conversationPhase, .dayClosing)
        XCTAssertEqual(resolveProfile(for: result), .lowRecoveryRest)

        XCTAssertTrue(pack.assessment.lines.first?.russian.contains("Сон был коротким") == true)
        XCTAssertFalse(allPackText(pack).localizedCaseInsensitiveContains("нагрузка за день"))
    }

    // MARK: - Helpers

    private func resolveProfile(for result: CoachEngine.Result) -> CoachStableDayProfile? {
        CoachStableDayProfile.resolve(
            scenario: result.scenario,
            modifiers: result.modifiers,
            dayReadiness: result.context.dayReadiness
        )
    }

    private func allPackText(_ pack: CoachCopyPack) -> String {
        let sections = [
            pack.assessment,
            pack.recommendation,
            pack.avoid,
            pack.nextAction,
            pack.supportingSignals
        ]
        return sections
            .flatMap(\.lines)
            .flatMap { [$0.english.lowercased(), $0.russian.lowercased()] }
            .joined(separator: " ")
    }

    private func behindNutrition() -> CoachNutritionContext {
        CoachNutritionContext(
            caloriesCurrent: 600,
            caloriesGoal: 2_800,
            proteinCurrent: 25,
            proteinGoal: 140,
            waterCurrent: 0.4,
            waterGoal: 2.5
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

    private func moderateActualLoad() -> CoachActualLoadSnapshot {
        CoachActualLoadSnapshot(
            source: .healthKitSamplesWithAppGoalEstimate,
            activeCalories: 520,
            exerciseMinutes: 75,
            standHours: nil,
            activityGoalCalories: 600,
            activityProgress: 1.1
        )
    }

    private func makeInput(
        now: Date,
        activities: [PlannedActivity],
        recovery: CoachRecoveryContext = CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
        actualLoad: CoachActualLoadSnapshot? = nil,
        nutrition: CoachNutritionContext? = nil,
        brainHour: Int
    ) -> CoachInputSnapshot {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = brainHour

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities.coachSnapshots(),
            actualLoad: actualLoad ?? CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 200,
                exerciseMinutes: 20,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 0.4
            ),
            recoveryContext: recovery,
            nutritionContext: nutrition ?? CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_800,
                proteinCurrent: 90,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            source: "CoachDayClosingCopyPolicyTests"
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}

private extension String {
    var containsDaytimeRecoveryTasks: Bool {
        let forbidden = [
            "walk", "stretch", "mobility", "recovery activity",
            "прогул", "растяж", "мобил", "восстановительн"
        ]
        return forbidden.contains { localizedCaseInsensitiveContains($0) }
    }

    var mentionsNutritionCatchUp: Bool {
        let forbidden = [
            "catch up", "eat now", "log food", "proper meal",
            "поеш", "догон", "калор", "normально поеш"
        ]
        return forbidden.contains { localizedCaseInsensitiveContains($0) }
    }
}
