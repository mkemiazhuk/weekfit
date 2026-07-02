import XCTest
@testable import WeekFit

final class TodayAtmosphereResolverTests: XCTestCase {

    func testDefaultsToReadyOnNeutralDay() {
        let snapshot = TodayAtmosphereResolver.resolve(
            recoveryPercent: 72,
            hasRecoverySignals: true,
            sleepHours: 7.5,
            activeCalories: 320,
            activityGoal: 600,
            completedTrainingCount: 0,
            hour: 14
        )

        XCTAssertEqual(snapshot.mode, .ready)
        XCTAssertEqual(snapshot.timePhase, .day)
    }

    func testProtectTakesPriorityOverLoad() {
        let snapshot = TodayAtmosphereResolver.resolve(
            recoveryPercent: 42,
            hasRecoverySignals: true,
            sleepHours: 7,
            activeCalories: 900,
            activityGoal: 600,
            completedTrainingCount: 2,
            hour: 18
        )

        XCTAssertEqual(snapshot.mode, .protect)
    }

    func testLowSleepTriggersProtectWithoutRecoveryScore() {
        let snapshot = TodayAtmosphereResolver.resolve(
            recoveryPercent: 0,
            hasRecoverySignals: false,
            sleepHours: 4.8,
            activeCalories: 200,
            activityGoal: 600,
            completedTrainingCount: 0,
            hour: 7
        )

        XCTAssertEqual(snapshot.mode, .protect)
        XCTAssertEqual(snapshot.timePhase, .morning)
    }

    func testHighActiveEnergyTriggersLoad() {
        let snapshot = TodayAtmosphereResolver.resolve(
            recoveryPercent: 78,
            hasRecoverySignals: true,
            sleepHours: 7,
            activeCalories: 700,
            activityGoal: 600,
            completedTrainingCount: 0,
            hour: 16
        )

        XCTAssertEqual(snapshot.mode, .load)
    }

    func testActivityGoalProgressCanTriggerLoad() {
        let snapshot = TodayAtmosphereResolver.resolve(
            recoveryPercent: 80,
            hasRecoverySignals: true,
            sleepHours: 7,
            activeCalories: 520,
            activityGoal: 600,
            completedTrainingCount: 1,
            hour: 20
        )

        XCTAssertEqual(snapshot.mode, .load)
        XCTAssertEqual(snapshot.timePhase, .evening)
    }
}
