import XCTest
@testable import WeekFit

final class CoachDayReadinessRouterTests: XCTestCase {

    func testProtectTomorrowFreshRequiresGoodRecoveryAndHardTomorrow() {
        let context = idleContext(
            recoveryBand: .good,
            tomorrowDemand: .hard,
            timeOfDay: .morning
        )
        XCTAssertEqual(CoachDayReadinessRouter.idleScenario(for: context), .protectTomorrowFresh)
    }

    func testProtectTomorrowFreshDoesNotApplyWithLowRecovery() {
        let context = idleContext(
            recoveryBand: .low,
            tomorrowDemand: .hard,
            timeOfDay: .morning
        )
        XCTAssertNotEqual(CoachDayReadinessRouter.idleScenario(for: context), .protectTomorrowFresh)
    }

    func testRecoveryAfterHeavyYesterdayRequiresBadRecovery() {
        let context = idleContext(
            recoveryBand: .low,
            hadHeavyYesterday: true,
            timeOfDay: .morning
        )
        XCTAssertEqual(
            CoachDayReadinessRouter.idleScenario(for: context),
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
            CoachDayReadinessRouter.lowRecoveryPreSessionScenario(for: pre),
            .lowRecoveryPrep
        )

        let during = activityContext(
            family: .endurance,
            phase: .during,
            state: .active,
            recoveryBand: .low
        )
        XCTAssertNil(CoachDayReadinessRouter.lowRecoveryPreSessionScenario(for: during))
    }

    private func idleContext(
        recoveryBand: CoachRecoveryBand,
        hadHeavyYesterday: Bool = false,
        tomorrowDemand: CoachTomorrowDemand = .none,
        timeOfDay: CoachTimeOfDay = .morning,
        dayLoad: CoachDayLoadBand = .fresh
    ) -> CoachContext {
        CoachContext(
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
            dayReadiness: CoachDayReadiness(
                recoveryPercent: recoveryBand == .good ? 90 : 35,
                sleepHours: recoveryBand == .good ? 8 : 4.5,
                recoveryBand: recoveryBand,
                hadHeavyYesterday: hadHeavyYesterday,
                sleepIsLow: recoveryBand != .good
            ),
            lastCompletedSeriousActivityType: .none
        )
    }

    private func activityContext(
        family: CoachActivityFamily,
        phase: CoachSessionPhase,
        state: CoachActivityState,
        recoveryBand: CoachRecoveryBand
    ) -> CoachContext {
        CoachContext(
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
            dayReadiness: CoachDayReadiness(
                recoveryPercent: recoveryBand == .good ? 90 : 35,
                sleepHours: recoveryBand == .good ? 8 : 4.5,
                recoveryBand: recoveryBand,
                hadHeavyYesterday: false,
                sleepIsLow: recoveryBand != .good
            ),
            lastCompletedSeriousActivityType: .none
        )
    }
}
