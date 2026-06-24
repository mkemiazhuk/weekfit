import XCTest
@testable import WeekFit

final class CoachV6DayReadinessRouterTests: XCTestCase {

    func testProtectTomorrowFreshRequiresGoodRecoveryAndHardTomorrow() {
        let context = idleContext(
            recoveryBand: .good,
            tomorrowDemand: .hard,
            timeOfDay: .morning
        )
        XCTAssertEqual(CoachV6DayReadinessRouter.idleScenario(for: context), .protectTomorrowFresh)
    }

    func testProtectTomorrowFreshDoesNotApplyWithLowRecovery() {
        let context = idleContext(
            recoveryBand: .low,
            tomorrowDemand: .hard,
            timeOfDay: .morning
        )
        XCTAssertNotEqual(CoachV6DayReadinessRouter.idleScenario(for: context), .protectTomorrowFresh)
    }

    func testRecoveryAfterHeavyYesterdayRequiresBadRecovery() {
        let context = idleContext(
            recoveryBand: .low,
            hadHeavyYesterday: true,
            timeOfDay: .morning
        )
        XCTAssertEqual(
            CoachV6DayReadinessRouter.idleScenario(for: context),
            .recoveryAfterHeavyYesterday
        )
    }

    func testLowRecoveryPrepAppliesOnlyToPreSeriousTraining() {
        let pre = activityContext(
            family: .endurance,
            phase: .pre,
            state: .upcoming,
            recoveryBand: .low
        )
        XCTAssertEqual(
            CoachV6DayReadinessRouter.lowRecoveryPreSessionScenario(for: pre),
            .lowRecoveryPrep
        )

        let during = activityContext(
            family: .endurance,
            phase: .during,
            state: .active,
            recoveryBand: .low
        )
        XCTAssertNil(CoachV6DayReadinessRouter.lowRecoveryPreSessionScenario(for: during))
    }

    private func idleContext(
        recoveryBand: CoachV6RecoveryBand,
        hadHeavyYesterday: Bool = false,
        tomorrowDemand: CoachV6TomorrowDemand = .none,
        timeOfDay: CoachV6TimeOfDay = .morning,
        dayLoad: CoachV6DayLoadBand = .fresh
    ) -> CoachV6Context {
        CoachV6Context(
            activityFamily: .none,
            activityType: .none,
            activityState: .none,
            sessionPhase: .idle,
            durationBand: .short,
            dayLoadBand: dayLoad,
            completedSeriousActivities: .none,
            fuelState: .adequate,
            hydrationState: .adequate,
            tomorrowDemand: tomorrowDemand,
            timeOfDay: timeOfDay,
            tomorrowWorkout: nil,
            focusActivityID: nil,
            focusSource: .idle,
            minutesUntilStart: nil,
            minutesSinceEnd: nil,
            dayReadiness: CoachV6DayReadiness(
                recoveryPercent: recoveryBand == .good ? 90 : 35,
                sleepHours: recoveryBand == .good ? 8 : 4.5,
                recoveryBand: recoveryBand,
                hadHeavyYesterday: hadHeavyYesterday,
                sleepIsLow: recoveryBand != .good
            )
        )
    }

    private func activityContext(
        family: CoachV6ActivityFamily,
        phase: CoachV6SessionPhase,
        state: CoachV6ActivityState,
        recoveryBand: CoachV6RecoveryBand
    ) -> CoachV6Context {
        CoachV6Context(
            activityFamily: family,
            activityType: family == .endurance ? .cycling : .none,
            activityState: state,
            sessionPhase: phase,
            durationBand: .long,
            dayLoadBand: .fresh,
            completedSeriousActivities: .none,
            fuelState: .adequate,
            hydrationState: .adequate,
            tomorrowDemand: .none,
            timeOfDay: .afternoon,
            tomorrowWorkout: nil,
            focusActivityID: "test",
            focusSource: .upcoming,
            minutesUntilStart: 45,
            minutesSinceEnd: nil,
            dayReadiness: CoachV6DayReadiness(
                recoveryPercent: recoveryBand == .good ? 90 : 35,
                sleepHours: recoveryBand == .good ? 8 : 4.5,
                recoveryBand: recoveryBand,
                hadHeavyYesterday: false,
                sleepIsLow: recoveryBand != .good
            )
        )
    }
}
