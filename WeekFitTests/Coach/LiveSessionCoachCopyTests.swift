import XCTest
@testable import WeekFit

final class LiveSessionCoachCopyTests: XCTestCase {

    func testRecoveryWalkDoesNotRepeatZoneOneDashboardCopy() throws {
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(makeWalkInput(zone: 1)))
        let english = joinedEnglish(pack)

        XCTAssertTrue(english.contains("walk"))
        XCTAssertTrue(english.contains("recovery") || english.contains("easy"))
        XCTAssertFalse(english.contains("Zone 1"))
        XCTAssertFalse(english.contains("recovery effort"))
        XCTAssertFalse(english.contains("Easy pace is fine"))

        let report = CoachCopyQualityAudit.audit(pack: pack, input: makeWalkInput(zone: 1))
        XCTAssertTrue(report.isClean, report.violations.joined(separator: "; "))
    }

    func testRecoveryWalkWhyExplainsHydrationDecision() throws {
        var input = makeWalkInput(zone: 1)
        input = withHydrationBehind(input)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let why = pack.supportingSignals.lines.map(\.english).joined(separator: " ")

        XCTAssertTrue(why.contains("hydration") || why.contains("Water"))
        XCTAssertTrue(why.contains("easy") || why.contains("intensity"))
        XCTAssertFalse(why.contains("Water is running behind today"))
        XCTAssertFalse(why.contains("First meal is still ahead"))
    }

    func testAerobicRunInZoneFourAsksToEaseBackWithoutZoneJargon() throws {
        let input = makeInput(
            scenario: .duringEndurance,
            activityType: .running,
            zone: 4,
            sessionPhase: .during,
            activityState: .active
        )
        XCTAssertEqual(LiveSessionCoachCopy.intent(for: input), .enduranceAerobic)

        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let english = joinedEnglish(pack).lowercased()
        XCTAssertTrue(english.contains("run") || english.contains("ease") || english.contains("drifting"))
        XCTAssertFalse(joinedEnglish(pack).contains("Zone 4"))
        XCTAssertFalse(english.contains("recovery effort"))
    }

    func testHIITAllowsHighHeartRate() throws {
        let input = makeInput(
            scenario: .duringEndurance,
            activityType: .hiit,
            zone: 4,
            sessionPhase: .during,
            activityState: .active
        )
        XCTAssertEqual(LiveSessionCoachCopy.intent(for: input), .enduranceHard)
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let english = joinedEnglish(pack)
        XCTAssertTrue(english.lowercased().contains("hiit") || english.lowercased().contains("interval"))
        XCTAssertFalse(english.contains("Ease back until breathing is conversational"))
    }

    func testStrengthKeepsSessionCopyInsteadOfHeartRateZones() throws {
        let input = makeInput(
            scenario: .duringStrength,
            activityType: .fullBody,
            zone: 2,
            sessionPhase: .during,
            activityState: .active,
            dayLoad: .heavy
        )
        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let english = joinedEnglish(pack)
        XCTAssertTrue(english.lowercased().contains("strength") || english.lowercased().contains("rep"))
        XCTAssertFalse(english.contains("Zone 2"))
        XCTAssertFalse(english.contains("aerobic"))
    }

    func testLowRecoveryLiveRunKeepsEnduranceCopyNotWalk() throws {
        let input = makeInput(
            scenario: .duringEndurance,
            activityType: .running,
            zone: 2,
            sessionPhase: .during,
            activityState: .active,
            recoveryBand: .low,
            recoveryPercent: 42,
            sleepHours: 5.5,
            sleepIsLow: true
        )
        XCTAssertEqual(LiveSessionCoachCopy.intent(for: input), .enduranceAerobic)

        let pack = try XCTUnwrap(CoachCopyRegistry.resolve(input))
        let english = joinedEnglish(pack).lowercased()
        XCTAssertFalse(english.contains("walk"))
        XCTAssertFalse(english.contains("power walk"))
        XCTAssertTrue(english.contains("run") || english.contains("effort") || english.contains("aerobic"))
    }

    private func makeWalkInput(zone: Int?) -> CoachCopyBuildInput {
        makeInput(
            scenario: .walkRecoveryAction,
            activityType: .walk,
            zone: zone,
            sessionPhase: .during,
            activityState: .active,
            dayLoad: .heavy,
            durationMinutes: 20
        )
    }

    private func withHydrationBehind(_ input: CoachCopyBuildInput) -> CoachCopyBuildInput {
        CoachCopyBuildInput(
            scenario: input.scenario,
            modifiers: CoachScenarioModifiers(
                dayLoad: input.modifiers.dayLoad,
                fuelBehind: input.modifiers.fuelBehind,
                hydrationBehind: true,
                tomorrowDemand: input.modifiers.tomorrowDemand,
                activityType: input.activityType,
                durationBand: input.modifiers.durationBand,
                completedSeriousActivities: input.modifiers.completedSeriousActivities,
                timeOfDay: input.modifiers.timeOfDay,
                stackedDayActiveRisk: false,
                lastCompletedActivityType: input.modifiers.lastCompletedActivityType
            ),
            athleteState: input.athleteState,
            fuelState: input.fuelState,
            hydrationState: .behind,
            safetyAlert: nil,
            semanticColor: input.semanticColor,
            alertSeverity: input.alertSeverity,
            tomorrowWorkout: nil,
            dayReadiness: input.dayReadiness,
            focusSource: input.focusSource,
            sessionPhase: input.sessionPhase,
            activityState: input.activityState,
            focusDurationMinutes: input.focusDurationMinutes,
            mealWindowOpen: true,
            liveHeartRateZone: input.liveHeartRateZone
        )
    }

    private func makeInput(
        scenario: CoachScenarioKey,
        activityType: CoachActivityType,
        zone: Int?,
        sessionPhase: CoachSessionPhase,
        activityState: CoachActivityState,
        dayLoad: CoachDayLoadBand = .fresh,
        durationMinutes: Int = 45,
        recoveryBand: CoachRecoveryBand = .good,
        recoveryPercent: Int = 82,
        sleepHours: Double = 7.5,
        sleepIsLow: Bool = false
    ) -> CoachCopyBuildInput {
        let readiness = CoachDayReadiness(
            recoveryPercent: recoveryPercent,
            sleepHours: sleepHours,
            recoveryBand: recoveryBand,
            hadHeavyYesterday: false,
            sleepIsLow: sleepIsLow
        )
        return CoachCopyBuildInput(
            scenario: scenario,
            modifiers: CoachScenarioModifiers(
                dayLoad: dayLoad,
                fuelBehind: false,
                hydrationBehind: false,
                tomorrowDemand: .none,
                activityType: activityType,
                durationBand: .medium,
                completedSeriousActivities: dayLoad == .heavy ? .one : .none,
                timeOfDay: .afternoon,
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
            sessionPhase: sessionPhase,
            activityState: activityState,
            focusDurationMinutes: durationMinutes,
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
