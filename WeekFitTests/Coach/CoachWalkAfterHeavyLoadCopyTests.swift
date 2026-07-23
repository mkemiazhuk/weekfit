import XCTest
@testable import WeekFit

final class CoachWalkAfterHeavyLoadCopyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.russian)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testUpcomingWalkAfterHeavyLoadUsesFutureCopy() throws {
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(makeInput(sessionPhase: .pre, focusSource: .upcoming)))
        let russian = joinedRussian(pack)

        XCTAssertTrue(russian.contains("после нагрузки"))
        XCTAssertTrue(russian.contains("успокоиться"))
        XCTAssertFalse(russian.contains("день позади"))
        XCTAssertFalse(russian.contains("основная работа"))
    }

    func testActiveWalkAfterHeavyLoadUsesLiveCopy() throws {
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(makeInput(sessionPhase: .during, focusSource: .active)))
        let russian = joinedRussian(pack)

        XCTAssertTrue(russian.contains("держите прогулку лёгкой"))
        XCTAssertFalse(russian.contains("основная работа"))
    }

    func testCompletedWalkAfterHeavyLoadWithSeriousWorkUsesRestOfDayCopyAtEvening() throws {
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(
            makeInput(
                sessionPhase: .settledPost,
                focusSource: .recentCompleted,
                activityState: .finished,
                minutesSinceEnd: 88,
                timeOfDay: .evening
            )
        ))
        let russian = joinedRussian(pack)

        XCTAssertTrue(russian.contains("основная работа"))
        XCTAssertTrue(russian.contains("остаток дня"))
        XCTAssertTrue(russian.contains("отдых"))
        XCTAssertFalse(russian.contains("15–20"))
        XCTAssertFalse(russian.lowercased().contains("идите"))
    }

    func testCompletedWalkAfterHeavyLoadWithSeriousWorkUsesDaytimeCopyAfternoon() throws {
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(
            makeInput(
                sessionPhase: .settledPost,
                focusSource: .recentCompleted,
                activityState: .finished,
                minutesSinceEnd: 88,
                timeOfDay: .afternoon
            )
        ))
        let russian = joinedRussian(pack)

        XCTAssertTrue(russian.contains("основная работа"))
        XCTAssertTrue(russian.contains("дальше без спешки") || russian.contains("без нового тяжёлого"))
        XCTAssertFalse(russian.contains("остаток дня"))
        XCTAssertFalse(russian.contains("завершить"))
    }

    func testCompletedWalkAfterHeavyLoadRegressionAfterCoreAndWalk() throws {
        let readiness = CoachDayReadiness(
            recoveryPercent: 75,
            sleepHours: 5,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: true
        )
        let input = makeInput(
            sessionPhase: .settledPost,
            focusSource: .recentCompleted,
            activityState: .finished,
            minutesSinceEnd: 88,
            dayReadiness: readiness
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: makeEngineResult(input: input, pack: pack)))
        let russian = joinedRussian(pack)

        XCTAssertEqual(bridge.todayTitle, "Восстанавливаемся")
        XCTAssertEqual(bridge.coachTitle, "Восстанавливаемся")
        XCTAssertTrue(russian.contains("основная работа сделана"))
        XCTAssertFalse(russian.contains("15–20 минут"))
        XCTAssertFalse(russian.contains("восстановительная прогулка"))
    }

    func testCompletedWalkAfterHeavyLoadWithCriticalHydrationAsksForWaterNotByFeel() throws {
        var input = makeInput(
            sessionPhase: .settledPost,
            focusSource: .recentCompleted,
            activityState: .finished,
            minutesSinceEnd: 88,
            timeOfDay: .midday
        )
        input = CoachCopyBuildInput(
            scenario: input.scenario,
            modifiers: CoachScenarioModifiers(
                dayLoad: input.modifiers.dayLoad,
                fuelBehind: true,
                hydrationBehind: true,
                tomorrowDemand: input.modifiers.tomorrowDemand,
                activityType: input.modifiers.activityType,
                durationBand: input.modifiers.durationBand,
                completedSeriousActivities: input.modifiers.completedSeriousActivities,
                timeOfDay: input.modifiers.timeOfDay,
                stackedDayActiveRisk: input.modifiers.stackedDayActiveRisk,
                lastCompletedActivityType: input.modifiers.lastCompletedActivityType
            ),
            athleteState: input.athleteState,
            fuelState: .behind,
            hydrationState: .critical,
            safetyAlert: nil,
            semanticColor: input.semanticColor,
            alertSeverity: .elevated,
            tomorrowWorkout: input.tomorrowWorkout,
            dayReadiness: input.dayReadiness,
            focusSource: input.focusSource,
            sessionPhase: input.sessionPhase,
            activityState: input.activityState,
            minutesSinceEnd: input.minutesSinceEnd,
            mealWindowOpen: false,
            dehydrationRisk: true
        )

        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let nextEN = pack.nextAction.lines.first?.english ?? ""
        let nextRU = pack.nextAction.lines.first?.russian ?? ""

        XCTAssertTrue(
            nextEN.lowercased().contains("drink") || nextEN.lowercased().contains("water"),
            "Expected explicit drink guidance; got: \(nextEN)"
        )
        XCTAssertFalse(nextEN.contains("Water by feel"))
        XCTAssertTrue(nextRU.lowercased().contains("вод") || nextRU.lowercased().contains("стакан"))
        XCTAssertFalse(nextRU.contains("по самочувствию"))

        let report = CoachConversationSemanticTimingAudit.audit(pack: pack, input: input)
        XCTAssertTrue(report.isClean, report.findings.map(\.reason).joined(separator: "; "))
    }

    func testCompletedWalkAfterHeavyLoadWithFuelBehindAsksForProteinMeal() throws {
        var input = makeInput(
            sessionPhase: .settledPost,
            focusSource: .recentCompleted,
            activityState: .finished,
            minutesSinceEnd: 88,
            timeOfDay: .midday
        )
        input = CoachCopyBuildInput(
            scenario: input.scenario,
            modifiers: CoachScenarioModifiers(
                dayLoad: input.modifiers.dayLoad,
                fuelBehind: true,
                hydrationBehind: false,
                tomorrowDemand: input.modifiers.tomorrowDemand,
                activityType: input.modifiers.activityType,
                durationBand: input.modifiers.durationBand,
                completedSeriousActivities: .one,
                timeOfDay: input.modifiers.timeOfDay,
                stackedDayActiveRisk: input.modifiers.stackedDayActiveRisk,
                lastCompletedActivityType: input.modifiers.lastCompletedActivityType
            ),
            athleteState: input.athleteState,
            fuelState: .behind,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: input.semanticColor,
            alertSeverity: .elevated,
            tomorrowWorkout: input.tomorrowWorkout,
            dayReadiness: input.dayReadiness,
            focusSource: input.focusSource,
            sessionPhase: input.sessionPhase,
            activityState: input.activityState,
            minutesSinceEnd: input.minutesSinceEnd,
            mealWindowOpen: true
        )

        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let nextEN = pack.nextAction.lines.first?.english ?? ""
        let nextRU = pack.nextAction.lines.first?.russian ?? ""

        XCTAssertTrue(nextEN.lowercased().contains("protein") || nextEN.lowercased().contains("meal"))
        XCTAssertTrue(nextRU.lowercased().contains("белк") || nextRU.lowercased().contains("приём"))
        XCTAssertFalse(nextEN.contains("Water by feel"))
        XCTAssertFalse(nextRU.contains("по самочувствию"))

        let report = CoachConversationSemanticTimingAudit.audit(pack: pack, input: input)
        XCTAssertTrue(report.isClean, report.findings.map(\.reason).joined(separator: "; "))
    }

    // MARK: - Helpers

    private func makeInput(
        sessionPhase: CoachSessionPhase,
        focusSource: CoachFocusSource,
        activityState: CoachActivityState = .upcoming,
        minutesSinceEnd: Int? = nil,
        dayReadiness: CoachDayReadiness? = nil,
        completedSerious: CoachCompletedSeriousActivities = .one,
        timeOfDay: CoachTimeOfDay = .afternoon
    ) -> CoachCopyBuildInput {
        let readiness = dayReadiness ?? CoachDayReadiness(
            recoveryPercent: 82,
            sleepHours: 7.5,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        return CoachCopyBuildInput(
            scenario: .walkAfterHeavyLoad,
            modifiers: CoachScenarioModifiers(
                dayLoad: .heavy,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: .walk,
                durationBand: .short,
                completedSeriousActivities: completedSerious,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .fullBody
            ),
            athleteState: CoachAthleteStateResolver.resolve(dayReadiness: readiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .recovery,
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: readiness,
            focusSource: focusSource,
            sessionPhase: sessionPhase,
            activityState: activityState,
            minutesSinceEnd: minutesSinceEnd
        )
    }

    private func makeEngineResult(
        input: CoachCopyBuildInput,
        pack: CoachCopyPack
    ) -> CoachEngine.Result {
        let context = CoachContext(
            activityFamily: .recovery,
            activityType: .walk,
            activityState: input.activityState,
            sessionPhase: input.sessionPhase,
            durationBand: input.modifiers.durationBand,
            dayLoadBand: input.modifiers.dayLoad,
            completedSeriousActivities: input.modifiers.completedSeriousActivities,
            fuelState: input.fuelState,
            hydrationState: input.hydrationState,
            tomorrowDemand: input.modifiers.tomorrowDemand,
            timeOfDay: input.modifiers.timeOfDay,
            tomorrowWorkout: input.tomorrowWorkout,
            focusActivityID: "walk-heavy-test",
            focusSource: input.focusSource,
            minutesUntilStart: nil,
            minutesSinceEnd: input.minutesSinceEnd,
            dayReadiness: input.dayReadiness,
            lastCompletedSeriousActivityType: input.modifiers.lastCompletedActivityType
        )
        let resolution = CoachScenarioResolution(
            scenario: .walkAfterHeavyLoad,
            modifiers: input.modifiers,
            safetyAlert: nil
        )
        let insight = CoachPresentationResolver.todayInsight(
            resolution: resolution,
            context: context
        )
        return CoachEngine.Result(
            context: context,
            resolution: resolution,
            todayInsight: insight,
            copyPack: pack,
            morningBriefFacts: nil
        )
    }

    private func joinedRussian(_ pack: CoachCopyPack) -> String {
        [
            pack.assessment,
            pack.recommendation,
            pack.avoid,
            pack.nextAction
        ]
        .flatMap(\.lines)
        .map(\.russian)
        .joined(separator: " ")
        .lowercased()
    }
}
