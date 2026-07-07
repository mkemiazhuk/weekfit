import XCTest
@testable import WeekFit

final class CoachImminentSessionCopyPolicyTests: XCTestCase {

    func testLowRecoveryPrepImminentCyclingMentionsTimeDurationAndFuel() throws {
        let pack = try XCTUnwrap(
            CoachCopyRegistry.resolve(
                makeInput(
                    scenario: .lowRecoveryPrep,
                    activityType: .cycling,
                    minutesUntilStart: 25,
                    durationMinutes: 210,
                    title: "Cycling",
                    sleepIsLow: true
                )
            )
        )

        let assessment = pack.assessment.lines[0].russian
        XCTAssertTrue(assessment.contains("25"), assessment)
        XCTAssertTrue(assessment.contains("3,5 ч") || assessment.contains("3 ч"), assessment)
        XCTAssertTrue(
            assessment.lowercased().contains("велосесс") || assessment.contains("Cycling"),
            assessment
        )

        let nextAction = pack.nextAction.lines[0].russian
        XCTAssertTrue(
            nextAction.lowercased().contains("вод") || nextAction.lowercased().contains("перекус"),
            nextAction
        )
        XCTAssertTrue(nextAction.contains("размин"), nextAction)
    }

    func testActiveEnduranceImminentUsesConcreteStartTime() throws {
        let pack = try XCTUnwrap(
            CoachCopyRegistry.resolve(
                makeInput(
                    scenario: .activeEndurance,
                    activityType: .cycling,
                    minutesUntilStart: 25,
                    durationMinutes: 210,
                    title: "Cycling",
                    sleepIsLow: false,
                    recoveryPercent: 82
                )
            )
        )

        let assessment = pack.assessment.lines[0].russian
        XCTAssertTrue(assessment.contains("25"), assessment)
        XCTAssertTrue(assessment.contains("настро"), assessment)
    }

    private func makeInput(
        scenario: CoachScenarioKey,
        activityType: CoachActivityType,
        minutesUntilStart: Int,
        durationMinutes: Int,
        title: String,
        sleepIsLow: Bool,
        recoveryPercent: Int = 58
    ) -> CoachCopyBuildInput {
        let dayReadiness = CoachDayReadiness(
            recoveryPercent: recoveryPercent,
            sleepHours: sleepIsLow ? 5.0 : 7.5,
            recoveryBand: recoveryPercent >= 80 ? .good : .moderate,
            hadHeavyYesterday: false,
            sleepIsLow: sleepIsLow,
            recoveryDataAvailable: true
        )
        let focusActivity = CoachPlannedActivitySummary(
            title: title,
            startHour: 9,
            startMinute: 0,
            durationMinutes: durationMinutes,
            activityType: activityType
        )
        let modifiers = CoachScenarioModifiers(
            dayLoad: .fresh,
            fuelBehind: false,
            hydrationBehind: false,
            tomorrowDemand: .none,
            activityType: activityType,
            durationBand: CoachDurationBand.from(minutes: durationMinutes),
            completedSeriousActivities: .none,
            timeOfDay: .morning,
            stackedDayActiveRisk: false,
            lastCompletedActivityType: .none
        )

        return CoachCopyBuildInput(
            scenario: scenario,
            modifiers: modifiers,
            athleteState: .normal,
            fuelState: .adequate,
            hydrationState: .adequate,
            safetyAlert: nil,
            semanticColor: .protection,
            alertSeverity: .none,
            tomorrowWorkout: nil,
            dayReadiness: dayReadiness,
            focusSource: .upcoming,
            sessionPhase: .pre,
            activityState: .upcoming,
            minutesUntilStart: minutesUntilStart,
            focusActivity: focusActivity
        )
    }
}
