import XCTest
@testable import WeekFit

final class CoachMindfulRecoveryPresentationTests: XCTestCase {

    func testLiveStateBadgeDoesNotSayRecoveryWalkForBreathing() {
        let english = CoachMindfulRecoveryPresentation.liveStateBadge(
            activityType: .breathing,
            russian: false
        )
        let russian = CoachMindfulRecoveryPresentation.liveStateBadge(
            activityType: .breathing,
            russian: true
        )

        XCTAssertEqual(english, "Breath work")
        XCTAssertEqual(russian, "Дыхание")
        XCTAssertFalse(english.localizedCaseInsensitiveContains("walk"))
        XCTAssertFalse(russian.localizedCaseInsensitiveContains("прогул"))
    }

    func testLiveSessionBreathingCopyIsBreathSpecificNotZoneOrWalk() throws {
        let input = makeBreathingLiveInput(zone: 1)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let english = [
            pack.assessment,
            pack.recommendation,
            pack.avoid,
            pack.nextAction
        ]
        .flatMap(\.lines)
        .map(\.english)
        .joined(separator: " ")
        .lowercased()

        let teaser = try XCTUnwrap(LiveSessionCoachCopy.teaser(for: input)?.english.lowercased())

        XCTAssertTrue(english.contains("breath"))
        XCTAssertTrue(english.contains("soft") || english.contains("quiet") || english.contains("unforced"))
        XCTAssertEqual(teaser, "keep the breath soft.")
        XCTAssertFalse(english.contains("walk"))
        XCTAssertFalse(english.contains("power walk"))
        XCTAssertFalse(english.contains("errands"))
        XCTAssertFalse(english.contains("easy range"))
        XCTAssertFalse(english.contains("zone"))
        XCTAssertFalse(english.contains("bpm"))
        XCTAssertFalse(CoachMindfulRecoveryPresentation.usesHeartRateZoneChrome(.breathing))
        XCTAssertTrue(CoachMindfulRecoveryPresentation.usesHeartRateZoneChrome(.walk))
    }

    func testYogaAndStretchBadgesStayActivitySpecific() {
        XCTAssertEqual(
            CoachMindfulRecoveryPresentation.liveStateBadge(activityType: .yoga, russian: false),
            "Yoga"
        )
        XCTAssertEqual(
            CoachMindfulRecoveryPresentation.liveStateBadge(activityType: .stretching, russian: false),
            "Stretching"
        )
        XCTAssertEqual(
            CoachMindfulRecoveryPresentation.coachHeadline(activityType: .yoga, russian: false),
            "Yoga session"
        )
        XCTAssertFalse(CoachMindfulRecoveryPresentation.usesHeartRateZoneChrome(.yoga))
        XCTAssertFalse(CoachMindfulRecoveryPresentation.usesHeartRateZoneChrome(.stretching))
    }

    func testLiveSessionYogaCopyAvoidsWalkAndZoneLanguage() throws {
        let input = makeMindfulLiveInput(activityType: .yoga, zone: 2)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let english = joinedEnglish(pack).lowercased()
        XCTAssertTrue(english.contains("yoga") || english.contains("pose"))
        XCTAssertFalse(english.contains("walk"))
        XCTAssertFalse(english.contains("bpm"))
        XCTAssertFalse(english.contains("easy range"))
    }

    func testLiveSessionStretchCopyAvoidsWalkLanguage() throws {
        let input = makeMindfulLiveInput(activityType: .stretching, zone: 1)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let english = joinedEnglish(pack).lowercased()
        XCTAssertTrue(english.contains("stretch") || english.contains("hold"))
        XCTAssertFalse(english.contains("walk"))
        XCTAssertFalse(english.contains("power walk"))
    }

    private func makeBreathingLiveInput(zone: Int?) -> CoachCopyBuildInput {
        makeMindfulLiveInput(activityType: .breathing, zone: zone)
    }

    private func makeMindfulLiveInput(
        activityType: CoachActivityType,
        zone: Int?
    ) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: 78,
            sleepHours: 7.2,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        return CoachCopyBuildInput(
            scenario: .duringRecovery,
            modifiers: CoachScenarioModifiers(
                dayLoad: .moderate,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: activityType,
                durationBand: .short,
                completedSeriousActivities: .one,
                timeOfDay: .evening,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: .fullBody
            ),
            athleteState: CoachAthleteStateResolver.resolve(dayReadiness: readiness),
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .live,
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: readiness,
            focusSource: .active,
            sessionPhase: .during,
            activityState: .active,
            focusDurationMinutes: 10,
            liveHeartRateZone: zone
        )
    }

    private func joinedEnglish(_ pack: CoachCopyPack) -> String {
        [
            pack.assessment,
            pack.recommendation,
            pack.avoid,
            pack.nextAction
        ]
        .flatMap(\.lines)
        .map(\.english)
        .joined(separator: " ")
    }
}
