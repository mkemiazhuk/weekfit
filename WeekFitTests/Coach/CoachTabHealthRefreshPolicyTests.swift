import XCTest
@testable import WeekFit

final class CoachTabHealthRefreshPolicyTests: XCTestCase {

    private let tokenA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let tokenB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testAppleWatchSyncHealthRefreshEventReloadsImmediately() {
        let decision = CoachTabHealthRefreshPolicy.evaluate(
            CoachTabHealthRefreshPolicy.Input(
                trigger: .healthRefreshEvent(sources: ["root.onChange.completedWorkoutsBatch"]),
                healthRefreshToken: tokenB,
                acknowledgedHealthRefreshToken: tokenA,
                lastHealthKitSyncTime: now.addingTimeInterval(-10),
                isHealthAccessRequested: true,
                now: now
            )
        )

        XCTAssertTrue(decision.shouldReloadHealth)
        XCTAssertTrue(decision.bypassesThrottle)
        XCTAssertTrue(decision.reason.contains("healthRefreshEvent"))
    }

    func testManualForceBypassesThrottle() {
        let decision = CoachTabHealthRefreshPolicy.evaluate(
            CoachTabHealthRefreshPolicy.Input(
                trigger: .manualForce(source: "manualRefresh"),
                healthRefreshToken: tokenA,
                acknowledgedHealthRefreshToken: tokenA,
                lastHealthKitSyncTime: now.addingTimeInterval(-5),
                isHealthAccessRequested: true,
                now: now
            )
        )

        XCTAssertTrue(decision.shouldReloadHealth)
        XCTAssertTrue(decision.bypassesThrottle)
        XCTAssertEqual(decision.reason, "manualForce:manualRefresh")
    }

    func testAppForegroundHealthRefreshEventReloadsImmediately() {
        let decision = CoachTabHealthRefreshPolicy.evaluate(
            CoachTabHealthRefreshPolicy.Input(
                trigger: .healthRefreshEvent(sources: ["appForeground"]),
                healthRefreshToken: tokenB,
                acknowledgedHealthRefreshToken: tokenA,
                lastHealthKitSyncTime: now.addingTimeInterval(-30),
                isHealthAccessRequested: true,
                now: now
            )
        )

        XCTAssertTrue(decision.shouldReloadHealth)
        XCTAssertTrue(decision.bypassesThrottle)
    }

    func testCoachTabActivationWithinThrottleWindowSkipsReload() {
        let decision = CoachTabHealthRefreshPolicy.evaluate(
            CoachTabHealthRefreshPolicy.Input(
                trigger: .coachTabActivation,
                healthRefreshToken: tokenA,
                acknowledgedHealthRefreshToken: tokenA,
                lastHealthKitSyncTime: now.addingTimeInterval(-30),
                isHealthAccessRequested: true,
                now: now
            )
        )

        XCTAssertFalse(decision.shouldReloadHealth)
        XCTAssertFalse(decision.bypassesThrottle)
        XCTAssertTrue(decision.reason.contains("tabActivationNoise"))
    }

    func testCoachTabActivationAfterThrottleWindowReloads() {
        let decision = CoachTabHealthRefreshPolicy.evaluate(
            CoachTabHealthRefreshPolicy.Input(
                trigger: .coachTabActivation,
                healthRefreshToken: tokenA,
                acknowledgedHealthRefreshToken: tokenA,
                lastHealthKitSyncTime: now.addingTimeInterval(-200),
                isHealthAccessRequested: true,
                now: now
            )
        )

        XCTAssertTrue(decision.shouldReloadHealth)
        XCTAssertFalse(decision.bypassesThrottle)
        XCTAssertTrue(decision.reason.contains("staleHealthKitSync"))
    }

    func testPendingHealthRefreshTokenOnCoachTabActivationReloadsImmediately() {
        let decision = CoachTabHealthRefreshPolicy.evaluate(
            CoachTabHealthRefreshPolicy.Input(
                trigger: .coachTabActivation,
                healthRefreshToken: tokenB,
                acknowledgedHealthRefreshToken: tokenA,
                lastHealthKitSyncTime: now.addingTimeInterval(-10),
                isHealthAccessRequested: true,
                now: now
            )
        )

        XCTAssertTrue(decision.shouldReloadHealth)
        XCTAssertTrue(decision.bypassesThrottle)
        XCTAssertEqual(decision.reason, "pendingHealthRefreshToken")
    }

    func testDataEventSourceDetectionIncludesWatchSync() {
        XCTAssertTrue(
            CoachTabHealthRefreshPolicy.isDataEventSource("root.onChange.completedWorkoutsBatch")
        )
        XCTAssertTrue(CoachTabHealthRefreshPolicy.isDataEventSource("appForeground"))
        XCTAssertTrue(CoachTabHealthRefreshPolicy.isDataEventSource("manualRefresh"))
    }

    func testTabSwitchAloneIsNotADataEventSource() {
        XCTAssertFalse(CoachTabHealthRefreshPolicy.isDataEventSource("tabChange.coach"))
        XCTAssertFalse(CoachTabHealthRefreshPolicy.isDataEventSource("rootTask"))
    }
}
