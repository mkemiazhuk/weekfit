import XCTest
@testable import WeekFit

final class CoachWalkRecoveryActionCopyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.russian)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    func testUpcomingWalkRecoveryActionUsesFutureCopy() throws {
        let input = makeInput(sessionPhase: .pre, focusSource: .upcoming)
        XCTAssertEqual(CoachWalkRecoveryActionCopy.phase(for: input), .upcoming)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let russian = joinedRussian(pack)

        XCTAssertTrue(russian.contains("разогнать ноги"), russian)
        XCTAssertTrue(russian.contains("используйте прогулку"), russian)
        XCTAssertFalse(russian.contains("прогулка уже"), russian)
        XCTAssertFalse(russian.contains("прогулка завершена"), russian)
        XCTAssertFalse(russian.contains("остаток дня"), russian)
    }

    func testActiveWalkRecoveryActionUsesLiveCopy() throws {
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(makeInput(sessionPhase: .during, focusSource: .active)))
        let russian = joinedRussian(pack)

        XCTAssertTrue(russian.contains("держите легко"))
        XCTAssertTrue(russian.contains("разговаривать"))
        XCTAssertFalse(russian.contains("прогулка завершена"))
        XCTAssertFalse(russian.contains("прогулка уже"))
    }

    func testCompletedWalkRecoveryActionUsesPostCopy() throws {
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(
            makeInput(
                sessionPhase: .immediatePost,
                focusSource: .recentCompleted,
                activityState: .justFinished,
                minutesSinceEnd: 51
            )
        ))
        let russian = joinedRussian(pack)

        XCTAssertTrue(russian.contains("прогулка уже"))
        XCTAssertTrue(russian.contains("остаток дня"))
        XCTAssertTrue(russian.contains("отдыха"))
        XCTAssertFalse(russian.contains("10–20 минут спокойно"))
        XCTAssertFalse(russian.lowercased().contains("идите"))
    }

    func testCompletedWalkRecoveryActionRegressionDoesNotUseFutureWalkLanguage() throws {
        let readiness = CoachDayReadiness(
            recoveryPercent: 75,
            sleepHours: 5,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: true
        )
        let input = makeInput(
            sessionPhase: .immediatePost,
            focusSource: .recentCompleted,
            activityState: .justFinished,
            minutesSinceEnd: 51,
            dayReadiness: readiness
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let bridge = try XCTUnwrap(CoachTabPresentationBridge.build(from: makeEngineResult(input: input, pack: pack)))

        let russian = joinedRussian(pack)
        let forbidden = ["10–20 минут спокойно", "идите", "разогнать ноги"]
        for phrase in forbidden {
            XCTAssertFalse(russian.lowercased().contains(phrase.lowercased()), "Unexpected phrase: \(phrase)")
        }

        XCTAssertTrue(russian.contains("прогулка уже"))
        XCTAssertTrue(russian.contains("остаток дня"))
        XCTAssertTrue(russian.contains("отдыха"))
        XCTAssertEqual(bridge.todayTitle, "Прогулка завершена")
        XCTAssertEqual(bridge.coachTitle, "Прогулка завершена")
    }

    // MARK: - Helpers

    private func makeInput(
        sessionPhase: CoachSessionPhase,
        focusSource: CoachFocusSource,
        activityState: CoachActivityState = .upcoming,
        minutesSinceEnd: Int? = nil,
        dayReadiness: CoachDayReadiness? = nil
    ) -> CoachCopyBuildInput {
        let readiness = dayReadiness ?? CoachDayReadiness(
            recoveryPercent: 82,
            sleepHours: 7.5,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        return CoachCopyBuildInput(
            scenario: .walkRecoveryAction,
            modifiers: CoachScenarioModifiers(
                dayLoad: .heavy,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: .walk,
                durationBand: .short,
                completedSeriousActivities: .one,
                timeOfDay: .afternoon,
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
            focusActivityID: "walk-recovery-test",
            focusSource: input.focusSource,
            minutesUntilStart: input.sessionPhase == .pre ? 25 : nil,
            minutesSinceEnd: input.minutesSinceEnd,
            dayReadiness: input.dayReadiness,
            lastCompletedSeriousActivityType: input.modifiers.lastCompletedActivityType
        )
        let resolution = CoachScenarioResolution(
            scenario: .walkRecoveryAction,
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
            copyPack: pack
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
