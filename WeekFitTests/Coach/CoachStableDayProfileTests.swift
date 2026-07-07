import XCTest
@testable import WeekFit

final class CoachStableDayProfileTests: XCTestCase {

    private let colors = (r: 0.2, g: 0.6, b: 0.9)

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.russian)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    // MARK: - Profile selection

    func testEmptyDayProfileWhenNoSeriousWorkCompleted() {
        let input = makeStableDayInput(completedSerious: .none)
        XCTAssertEqual(CoachStableDayProfile.resolve(for: input), .emptyDay)
    }

    func testWorkBankedProfileWhenSeriousWorkCompleted() {
        let input = makeStableDayInput(
            completedSerious: .one,
            lastCompletedActivityType: .cycling
        )
        XCTAssertEqual(CoachStableDayProfile.resolve(for: input), .workBanked)
    }

    // MARK: - Required example: afternoon idle after morning ride

    func testAfternoonIdleAfterMorningRideUsesWorkBankedStableDay() throws {
        let now = date(hour: 14, minute: 0)
        let rideStart = date(hour: 7, minute: 0)
        let ride = PlannedActivity(
            date: rideStart,
            type: "workout",
            title: "Morning Ride",
            durationMinutes: 120,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            calories: 700,
            isCompleted: true
        )

        let input = makeEngineInput(now: now, activities: [ride])
        let result = CoachEngine.evaluate(input: input)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertEqual(result.context.focusSource, .idle)
        XCTAssertEqual(result.modifiers.completedSeriousActivities, .one)
        XCTAssertEqual(result.modifiers.lastCompletedActivityType, .cycling)
        XCTAssertEqual(resolveProfile(for: result), .workBanked)

        XCTAssertEqual(bridge.todayTitle, "Восстанавливаемся")
        XCTAssertFalse(bridge.assessment.contains("ничего срочного"))
        XCTAssertTrue(pack.assessment.lines.first?.russian.contains("Заезд сделан") == true)
        XCTAssertTrue(pack.recommendation.lines.first?.russian.contains("без лишней") == true)
        XCTAssertTrue(pack.avoid.lines.first?.russian.contains("тяжёлый блок") == true)
    }

    func testEmptyAfternoonStableDayKeepsCalmCopy() throws {
        let now = date(hour: 14, minute: 0)
        let result = CoachEngine.evaluate(input: makeEngineInput(now: now, activities: []))
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertEqual(resolveProfile(for: result), .emptyDay)
        XCTAssertEqual(bridge.todayTitle, "Спокойный день")
        XCTAssertTrue(pack.assessment.lines.first?.russian.contains("ничего срочного") == true)
    }

    func testWorkBankedModerateLoadAddsSupportSignal() throws {
        let input = makeStableDayInput(
            completedSerious: .one,
            dayLoad: .moderate,
            lastCompletedActivityType: .cycling
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let support = pack.supportingSignals.lines.map(\.russian).joined(separator: " ")
        XCTAssertTrue(support.contains("серьёзная работа"))
    }

    func testWorkBankedHeavyLoadAddsHighLoadSupportSignal() throws {
        let input = makeStableDayInput(
            completedSerious: .one,
            dayLoad: .heavy,
            lastCompletedActivityType: .cycling
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let support = pack.supportingSignals.lines.map(\.russian).joined(separator: " ")
        XCTAssertTrue(support.contains("много нагрузки"))
    }

    func testWorkBankedUsesCyclingIconOnStableDay() {
        let input = makeStableDayInput(
            completedSerious: .one,
            lastCompletedActivityType: .cycling
        )
        let dayReadiness = makeDayReadiness()
        let context = idleContext(
            completedSerious: .one,
            lastCompletedActivityType: .cycling,
            dayReadiness: dayReadiness
        )
        let resolution = CoachScenarioResolution(
            scenario: .stableDay,
            modifiers: input.modifiers,
            safetyAlert: nil
        )
        let insight = CoachPresentationResolver.todayInsight(
            resolution: resolution,
            context: context
        )
        XCTAssertEqual(insight.icon, "figure.outdoor.cycle")
    }

    // MARK: - Phase 2 profiles

    func testLowRecoveryRestProfileWhenNoSeriousWorkAndLowRecovery() {
        let input = makeStableDayInput(
            completedSerious: .none,
            dayReadiness: makeDayReadiness(recoveryPercent: 48, recoveryBand: .low)
        )
        XCTAssertEqual(CoachStableDayProfile.resolve(for: input), .lowRecoveryRest)
    }

    func testLowRecoveryRestProfileWhenShortSleepAndNoPlan() throws {
        let input = makeStableDayInput(
            completedSerious: .none,
            dayReadiness: makeDayReadiness(sleepHours: 5.0, sleepIsLow: true)
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let bridge = try XCTUnwrap(
            CoachTabPresentationBridge.build(
                from: makeStableDayEngineResult(input: input)
            )
        )

        XCTAssertEqual(CoachStableDayProfile.resolve(for: input), .lowRecoveryRest)
        XCTAssertTrue(
            bridge.todayTitle.contains("Спокойный") || bridge.todayTitle.contains("восст")
        )
        XCTAssertTrue(pack.assessment.lines.first?.russian.contains("восстанов") == true)
        let support = pack.supportingSignals.lines.map(\.russian).joined(separator: " ")
        XCTAssertTrue(support.contains("коротким"))
    }

    func testTomorrowReserveProfileOnAfternoonIdleWithHardTomorrow() throws {
        let input = makeStableDayInput(
            completedSerious: .none,
            timeOfDay: .afternoon,
            tomorrowDemand: .hard
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let bridge = try XCTUnwrap(
            CoachTabPresentationBridge.build(
                from: makeStableDayEngineResult(input: input)
            )
        )

        XCTAssertEqual(CoachStableDayProfile.resolve(for: input), .tomorrowReserve)
        XCTAssertEqual(bridge.todayTitle, "Запас на завтра")
        XCTAssertTrue(pack.assessment.lines.first?.russian.contains("Завтра") == true)
        let support = pack.supportingSignals.lines.map(\.russian).joined(separator: " ")
        XCTAssertTrue(support.contains("Завтра в плане"))
    }

    func testShortSleepWithTomorrowCyclingUsesTomorrowReserveAndNamesWorkout() throws {
        let now = date(hour: 20, minute: 0)
        guard let tomorrowRideStart = Calendar.current.date(
            byAdding: .day,
            value: 1,
            to: date(hour: 8, minute: 0)
        ) else {
            XCTFail("Missing tomorrow date")
            return
        }

        let cycling = PlannedActivity(
            date: tomorrowRideStart,
            type: "workout",
            title: "Cycling",
            durationMinutes: 210,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b
        )

        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = 20
        brainConfig.metrics = CoachMetricsBuilder.metrics(activeCalories: 636, sleepHours: 5.0)
        brainConfig.sleep = .short
        brainConfig.readiness = .moderate
        brainConfig.recovery = .vulnerable

        let input = CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: [cycling].coachSnapshots(),
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 636,
                exerciseMinutes: 90,
                standHours: nil,
                activityGoalCalories: 430,
                activityProgress: 1.47
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 58, sleepHours: 5.0),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 782,
                caloriesGoal: 1_752,
                proteinCurrent: 40,
                proteinGoal: 120,
                waterCurrent: 1.0,
                waterGoal: 3.4
            ),
            source: "CoachStableDayProfileTests.tomorrowCyclingShortSleep"
        )

        let result = CoachEngine.evaluate(input: input)
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: result))
        let pack = try XCTUnwrap(result.copyPack)

        XCTAssertEqual(result.scenario, .stableDay)
        XCTAssertEqual(resolveProfile(for: result), .tomorrowReserve)
        XCTAssertEqual(bridge.todayTitle, "Запас на завтра")
        XCTAssertTrue(bridge.todayMessage.contains("Завтра велосессия"))
        XCTAssertTrue(bridge.todayMessage.contains("берегите силы"))
        XCTAssertFalse(bridge.todayMessage.contains("перед"))
        XCTAssertFalse(bridge.todayMessage.contains("Cycling"))
        XCTAssertTrue(pack.assessment.lines.first?.russian.contains("Завтра велосессия") == true)
        XCTAssertTrue(pack.assessment.lines.first?.russian.contains("главная нагрузка") == true)
        XCTAssertFalse(pack.assessment.lines.first?.russian.contains("Cycling") == true)
        let support = pack.supportingSignals.lines.map(\.russian).joined(separator: " ")
        XCTAssertTrue(support.contains("Завтра в плане"))
        XCTAssertTrue(support.contains("велосессия"))
        XCTAssertNotEqual(bridge.todayTitle, "День восстановления")
    }

    func testTomorrowReserveWinsOverWorkBankedWhenBothApply() {
        let input = makeStableDayInput(
            completedSerious: .one,
            lastCompletedActivityType: .cycling,
            tomorrowDemand: .hard
        )
        XCTAssertEqual(CoachStableDayProfile.resolve(for: input), .tomorrowReserve)
    }

    func testProtectiveProfilesUseProtectiveBadge() {
        let lowRecoveryInput = makeStableDayInput(
            completedSerious: .none,
            dayReadiness: makeDayReadiness(recoveryPercent: 48, recoveryBand: .low)
        )
        let tomorrowInput = makeStableDayInput(
            completedSerious: .none,
            timeOfDay: .afternoon,
            tomorrowDemand: .hard
        )

        let lowRecoveryInsight = insight(for: lowRecoveryInput)
        let tomorrowInsight = insight(for: tomorrowInput)

        XCTAssertEqual(lowRecoveryInsight.urgencyLevel, CoachUrgencyLevel.protective)
        XCTAssertEqual(tomorrowInsight.urgencyLevel, CoachUrgencyLevel.protective)
        XCTAssertEqual(
            CoachTabPresentationBridge.build(from: makeStableDayEngineResult(input: lowRecoveryInput))?.statusLabel,
            "БЕРЕЖЁМ СИЛЫ"
        )
        XCTAssertEqual(
            CoachTabPresentationBridge.build(from: makeStableDayEngineResult(input: tomorrowInput))?.statusLabel,
            "БЕРЕЖЁМ СИЛЫ"
        )
    }

    func testLowRecoveryRestUsesRecoverySemanticColorAndBedIcon() {
        let input = makeStableDayInput(
            completedSerious: .none,
            dayReadiness: makeDayReadiness(recoveryPercent: 48, recoveryBand: .low)
        )
        let result = insight(for: input)
        XCTAssertEqual(result.semanticColor, CoachSemanticColor.recovery)
        XCTAssertEqual(result.icon, "bed.double.fill")
    }

    func testTomorrowReserveUsesProtectionSemanticColorAndMoonIcon() {
        let input = makeStableDayInput(
            completedSerious: .none,
            timeOfDay: .afternoon,
            tomorrowDemand: .hard
        )
        let result = insight(for: input)
        XCTAssertEqual(result.semanticColor, CoachSemanticColor.protection)
        XCTAssertEqual(result.icon, "moon.stars.fill")
    }

    func testWorkDoneWithTomorrowHardUsesTomorrowReserveIconNotCycling() {
        let input = makeStableDayInput(
            completedSerious: .one,
            lastCompletedActivityType: .cycling,
            tomorrowDemand: .hard
        )
        let result = insight(for: input)
        XCTAssertEqual(result.icon, "moon.stars.fill")
    }

    // MARK: - Snapshot

    func testPrintWorkBankedStableDaySnapshot() throws {
        let now = date(hour: 14, minute: 0)
        let rideStart = date(hour: 7, minute: 0)
        let ride = PlannedActivity(
            date: rideStart,
            type: "workout",
            title: "Morning Ride",
            durationMinutes: 120,
            icon: "figure.outdoor.cycle",
            colorRed: colors.r,
            colorGreen: colors.g,
            colorBlue: colors.b,
            calories: 700,
            isCompleted: true
        )
        let result = CoachEngine.evaluate(input: makeEngineInput(now: now, activities: [ride]))
        let snapshot = CoachStableDayProfileSnapshotPrinter.render(result: result)

        try snapshot.write(
            to: URL(fileURLWithPath: "/tmp/WeekFitCoachWorkBankedStableDay.txt"),
            atomically: true,
            encoding: .utf8
        )
        print(snapshot)
        XCTAssertTrue(snapshot.contains("PROFILE: workBanked"))
        XCTAssertTrue(snapshot.contains("SCENARIO: stableDay"))
        XCTAssertTrue(snapshot.contains("Восстанавливаемся"))
        XCTAssertTrue(snapshot.contains("Заезд сделан"))
    }

    func testPrintLowRecoveryRestStableDaySnapshot() throws {
        let input = makeStableDayInput(
            completedSerious: .none,
            dayReadiness: makeDayReadiness(recoveryPercent: 48, recoveryBand: .low)
        )
        let result = makeStableDayEngineResult(input: input)
        let snapshot = CoachStableDayProfileSnapshotPrinter.render(result: result)

        try snapshot.write(
            to: URL(fileURLWithPath: "/tmp/WeekFitCoachLowRecoveryRestStableDay.txt"),
            atomically: true,
            encoding: .utf8
        )
        print(snapshot)
        XCTAssertTrue(snapshot.contains("PROFILE: lowRecoveryRest"))
        XCTAssertTrue(snapshot.contains("восстановлен"))
    }

    func testPrintTomorrowReserveStableDaySnapshot() throws {
        let input = makeStableDayInput(
            completedSerious: .none,
            timeOfDay: .afternoon,
            tomorrowDemand: .hard
        )
        let result = makeStableDayEngineResult(input: input)
        let snapshot = CoachStableDayProfileSnapshotPrinter.render(result: result)

        try snapshot.write(
            to: URL(fileURLWithPath: "/tmp/WeekFitCoachTomorrowReserveStableDay.txt"),
            atomically: true,
            encoding: .utf8
        )
        print(snapshot)
        XCTAssertTrue(snapshot.contains("PROFILE: tomorrowReserve"))
        XCTAssertTrue(snapshot.contains("Запас на завтра"))
    }

    // MARK: - Helpers

    private func resolveProfile(for result: CoachEngine.Result) -> CoachStableDayProfile? {
        CoachStableDayProfile.resolve(
            scenario: result.scenario,
            modifiers: result.modifiers,
            dayReadiness: result.context.dayReadiness
        )
    }

    private func insight(for input: CoachCopyBuildInput) -> CoachTodayInsight {
        let result = makeStableDayEngineResult(input: input)
        return result.todayInsight
    }

    private func makeStableDayEngineResult(input: CoachCopyBuildInput) -> CoachEngine.Result {
        let context = idleContext(
            completedSerious: input.modifiers.completedSeriousActivities,
            lastCompletedActivityType: input.modifiers.lastCompletedActivityType,
            dayReadiness: input.dayReadiness,
            tomorrowDemand: input.modifiers.tomorrowDemand,
            timeOfDay: input.modifiers.timeOfDay
        )
        let resolution = CoachScenarioResolution(
            scenario: .stableDay,
            modifiers: input.modifiers,
            safetyAlert: nil
        )
        let todayInsight = CoachPresentationResolver.todayInsight(
            resolution: resolution,
            context: context
        )
        return CoachEngine.Result(
            context: context,
            resolution: resolution,
            todayInsight: todayInsight,
            copyPack: CoachCopyRegistry.resolve(input),
            morningBriefFacts: nil
        )
    }

    private func makeDayReadiness(
        recoveryPercent: Int = 82,
        sleepHours: Double = 7.5,
        recoveryBand: CoachRecoveryBand = .good,
        sleepIsLow: Bool = false
    ) -> CoachDayReadiness {
        CoachDayReadiness(
            recoveryPercent: recoveryPercent,
            sleepHours: sleepHours,
            recoveryBand: recoveryBand,
            hadHeavyYesterday: false,
            sleepIsLow: sleepIsLow
        )
    }

    private func makeStableDayInput(
        completedSerious: CoachCompletedSeriousActivities,
        dayLoad: CoachDayLoadBand = .moderate,
        lastCompletedActivityType: CoachActivityType = .none,
        timeOfDay: CoachTimeOfDay = .afternoon,
        tomorrowDemand: CoachTomorrowDemand = .none,
        dayReadiness: CoachDayReadiness? = nil
    ) -> CoachCopyBuildInput {
        let readiness = dayReadiness ?? makeDayReadiness()
        return CoachCopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachScenarioModifiers(
                dayLoad: dayLoad,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: tomorrowDemand,
                activityType: .none,
                durationBand: .short,
                completedSeriousActivities: completedSerious,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: lastCompletedActivityType
            ),
            athleteState: CoachAthleteStateResolver.resolve(dayReadiness: readiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .stable,
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: readiness
        )
    }

    private func makeEngineInput(now: Date, activities: [PlannedActivity]) -> CoachInputSnapshot {
        var brainConfig = HumanBrainStateBuilder.Configuration()
        brainConfig.currentHour = Calendar.current.component(.hour, from: now)

        return CoachInputSnapshot(
            selectedDate: now,
            now: now,
            brain: HumanBrainStateBuilder.make(brainConfig),
            plannedActivities: activities.coachSnapshots(),
            actualLoad: CoachActualLoadSnapshot(
                source: .healthKitSamplesWithAppGoalEstimate,
                activeCalories: 550,
                exerciseMinutes: 120,
                standHours: nil,
                activityGoalCalories: 600,
                activityProgress: 1.1
            ),
            recoveryContext: CoachRecoveryContext(recoveryPercent: 82, sleepHours: 7.5),
            nutritionContext: CoachNutritionContext(
                caloriesCurrent: 1_800,
                caloriesGoal: 2_800,
                proteinCurrent: 90,
                proteinGoal: 140,
                waterCurrent: 1.8,
                waterGoal: 2.5
            ),
            source: "CoachStableDayProfileTests"
        )
    }

    private func idleContext(
        completedSerious: CoachCompletedSeriousActivities,
        lastCompletedActivityType: CoachActivityType,
        dayReadiness: CoachDayReadiness = .unknown,
        tomorrowDemand: CoachTomorrowDemand = .none,
        timeOfDay: CoachTimeOfDay = .afternoon
    ) -> CoachContext {
        CoachContext(
            activityFamily: .none,
            activityType: .none,
            activityState: .none,
            sessionPhase: .idle,
            durationBand: .short,
            dayLoadBand: .moderate,
            completedSeriousActivities: completedSerious,
            fuelState: .adequate,
            hydrationState: .adequate,
            tomorrowDemand: tomorrowDemand,
            timeOfDay: timeOfDay,
            tomorrowWorkout: nil,
            focusActivityID: nil,
            focusSource: .idle,
            minutesUntilStart: nil,
            minutesSinceEnd: nil,
            dayReadiness: dayReadiness,
            lastCompletedSeriousActivityType: lastCompletedActivityType
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: CoachTestClock.reference)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}

// MARK: - Snapshot printer

enum CoachStableDayProfileSnapshotPrinter {

    static func render(result: CoachEngine.Result) -> String {
        let profile = CoachStableDayProfile.resolve(
            scenario: result.scenario,
            modifiers: result.modifiers,
            dayReadiness: result.context.dayReadiness
        )?.rawValue ?? "none"
        let pack = result.copyPack
        let bridge = CoachTabPresentationBridge.build(from: result)

        var lines: [String] = [
            "Coach StableDay Profile Snapshot",
            "SCENARIO: \(result.scenario.rawValue)",
            "PROFILE: \(profile)",
            "focus: \(result.context.focusSource.rawValue)",
            "completedSerious: \(String(describing: result.modifiers.completedSeriousActivities))",
            "lastCompletedType: \(result.modifiers.lastCompletedActivityType.rawValue)",
            "dayLoad: \(result.modifiers.dayLoad.rawValue)",
            "timeOfDay: \(result.modifiers.timeOfDay.rawValue)",
            "---"
        ]

        if let bridge {
            lines.append("TITLE: \(bridge.todayTitle)")
            lines.append("BADGE: \(bridge.statusLabel)")
            lines.append("TEASER: \(bridge.todayMessage)")
            lines.append("ICON: \(bridge.icon)")
        }

        if let pack {
            lines.append("ASSESSMENT: \(pack.assessment.lines.first?.russian ?? "")")
            lines.append("RECOMMENDATION: \(pack.recommendation.lines.first?.russian ?? "")")
            lines.append("AVOID: \(pack.avoid.lines.first?.russian ?? "")")
            lines.append("NEXT: \(pack.nextAction.lines.first?.russian ?? "")")
            if !pack.supportingSignals.isEmpty {
                lines.append("SUPPORT: \(pack.supportingSignals.lines.map(\.russian).joined(separator: " | "))")
            }
        }

        return lines.joined(separator: "\n")
    }
}
