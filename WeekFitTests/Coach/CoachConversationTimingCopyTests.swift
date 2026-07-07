import XCTest
@testable import WeekFit

/// P0 conversation-timing guards — copy must not sound like evening closure before 18:00.
final class CoachConversationTimingCopyTests: XCTestCase {

    private enum Snapshot: CaseIterable {
        case morning0830
        case midday1047
        case afternoon1500
        case evening1900
        case night2200

        var timeOfDay: CoachTimeOfDay {
            switch self {
            case .morning0830: return .morning
            case .midday1047: return .midday
            case .afternoon1500: return .afternoon
            case .evening1900: return .evening
            case .night2200: return .lateEvening
            }
        }

        var label: String {
            switch self {
            case .morning0830: return "08:30"
            case .midday1047: return "10:47"
            case .afternoon1500: return "15:00"
            case .evening1900: return "19:00"
            case .night2200: return "22:00"
            }
        }

        static var beforeEvening: [Snapshot] { [.morning0830, .midday1047, .afternoon1500] }
    }

    override func setUp() {
        super.setUp()
        WeekFitSetCurrentLanguage(.russian)
    }

    override func tearDown() {
        WeekFitSetCurrentLanguage(.english)
        super.tearDown()
    }

    // MARK: - walkAfterHeavyLoad

    func testWalkAfterHeavyLoadUpcomingAvoidsPastDayClosure() throws {
        for snapshot in Snapshot.beforeEvening {
            let input = walkInput(
                timeOfDay: snapshot.timeOfDay,
                sessionPhase: .pre,
                focusSource: .upcoming,
                activityState: .upcoming,
                minutesSinceEnd: nil
            )
            let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
            assertTimingAuditClean(pack: pack, input: input, snapshot: snapshot)
            XCTAssertTrue(
                joinedRussian(pack).contains("после нагрузки"),
                "\(snapshot.label): upcoming walk should reference recovery after load"
            )
        }
    }

    func testWalkAfterHeavyLoadCompletedAvoidsDayClosureBeforeEvening() throws {
        for snapshot in Snapshot.beforeEvening {
            let input = walkInput(
                timeOfDay: snapshot.timeOfDay,
                sessionPhase: .settledPost,
                focusSource: .recentCompleted,
                activityState: .finished,
                minutesSinceEnd: 88
            )
            let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
            assertTimingAuditClean(pack: pack, input: input, snapshot: snapshot)
            XCTAssertTrue(
                joinedRussian(pack).contains("основная работа"),
                "\(snapshot.label): completed walk after serious work"
            )
        }
    }

    func testWalkAfterHeavyLoadEveningAllowsRestOfDayButNotClosure() throws {
        let input = walkInput(
            timeOfDay: .evening,
            sessionPhase: .settledPost,
            focusSource: .recentCompleted,
            activityState: .finished,
            minutesSinceEnd: 90
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let russian = joinedRussian(pack)
        assertTimingAuditClean(pack: pack, input: input, snapshot: .evening1900)
        XCTAssertTrue(russian.contains("остаток дня") || russian.contains("вечер"))
        XCTAssertFalse(russian.contains("на сегодня достаточно"))
        XCTAssertFalse(russian.contains("завершить"))
        XCTAssertFalse(russian.contains("плотный день позади"))
    }

    func testWalkAfterHeavyLoadCompletedAllowsClosureAtNight() throws {
        let input = walkInput(
            timeOfDay: .lateEvening,
            sessionPhase: .settledPost,
            focusSource: .recentCompleted,
            activityState: .finished,
            minutesSinceEnd: 120
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let russian = joinedRussian(pack)
        assertTimingAuditClean(pack: pack, input: input, snapshot: .night2200)
        XCTAssertTrue(
            russian.contains("остаток дня") || russian.contains("завершить"),
            "22:00 should allow evening closure copy"
        )
    }

    // MARK: - stableDay workBanked

    func testStableDayWorkBankedAvoidsRestOfDayPhrasingBeforeEvening() throws {
        for snapshot in Snapshot.beforeEvening {
            let input = stableDayWorkBankedInput(timeOfDay: snapshot.timeOfDay)
            let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
            assertTimingAuditClean(pack: pack, input: input, snapshot: snapshot)
        }
    }

    func testStableDayWorkBankedAllowsRestOfDayPhrasingAtNight() throws {
        let input = stableDayWorkBankedInput(timeOfDay: .lateEvening)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        assertTimingAuditClean(pack: pack, input: input, snapshot: .night2200)
        XCTAssertTrue(
            joinedRussian(pack).contains("остаток дня"),
            "22:00 workBanked may use rest-of-day phrasing"
        )
    }

    // MARK: - tomorrowProtection

    func testTomorrowProtectionAvoidsEnoughForTodayBeforeNight() throws {
        for snapshot in Snapshot.beforeEvening + [.evening1900] {
            let input = tomorrowProtectionInput(timeOfDay: snapshot.timeOfDay)
            let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
            assertTimingAuditClean(pack: pack, input: input, snapshot: snapshot)
            let russian = joinedRussian(pack)
            XCTAssertTrue(
                russian.contains("завтра") || russian.contains("берег"),
                "\(snapshot.label): should still protect tomorrow"
            )
        }
    }

    func testTomorrowProtectionAllowsClosureAtNight() throws {
        let input = tomorrowProtectionInput(timeOfDay: .lateEvening)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        assertTimingAuditClean(pack: pack, input: input, snapshot: .night2200)
        let russian = joinedRussian(pack)
        XCTAssertTrue(
            russian.contains("на сегодня достаточно") || russian.contains("заканчивайте день"),
            "22:00 tomorrowProtection may use closure phrasing"
        )
    }

    // MARK: - Helpers

    private func walkInput(
        timeOfDay: CoachTimeOfDay,
        sessionPhase: CoachSessionPhase,
        focusSource: CoachFocusSource,
        activityState: CoachActivityState,
        minutesSinceEnd: Int?
    ) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
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
                completedSeriousActivities: .one,
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

    private func stableDayWorkBankedInput(timeOfDay: CoachTimeOfDay) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 82,
            sleepHours: 7.5,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        return CoachCopyBuildInput(
            scenario: .stableDay,
            modifiers: CoachScenarioModifiers(
                dayLoad: .heavy,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: .cycling,
                durationBand: .long,
                completedSeriousActivities: .one,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .cycling
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

    private func tomorrowProtectionInput(timeOfDay: CoachTimeOfDay) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 80,
            sleepHours: 7.0,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        return CoachCopyBuildInput(
            scenario: .tomorrowProtection,
            modifiers: CoachScenarioModifiers(
                dayLoad: .heavy,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .hard,
                activityType: .none,
                durationBand: .extended,
                completedSeriousActivities: .one,
                timeOfDay: timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .cycling
            ),
            athleteState: CoachAthleteStateResolver.resolve(dayReadiness: readiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .protection,
            alertSeverity: .none,
            tomorrowWorkout: CoachTomorrowWorkout(
                title: "Long Run",
                startHour: 7,
                startMinute: 0,
                durationMinutes: 90
            ),
            dayReadiness: readiness,
            sessionPhase: .tomorrowProtection
        )
    }

    private func assertTimingAuditClean(
        pack: CoachCopyPack,
        input: CoachCopyBuildInput,
        snapshot: Snapshot
    ) {
        let report = CoachConversationTimingAudit.audit(pack: pack, input: input)
        XCTAssertTrue(report.isClean, "\(snapshot.label): \(format(report))")
    }

    private func format(_ report: CoachConversationTimingAudit.Report) -> String {
        report.findings.map { "\($0.section): \($0.phrase) (\($0.reason))" }.joined(separator: "; ")
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
