import XCTest
@testable import WeekFit

@MainActor
final class HealthManagerIntegrationTests: XCTestCase {

    private let healthAccessRequestedKey = "weekfit.healthAccessRequested"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: healthAccessRequestedKey)
    }

    func testLoadHealthDataSkipsWhenAccessNotRequested() async {
        let manager = HealthManager()

        await manager.loadHealthData(for: Date(), plannedActivities: [])

        XCTAssertFalse(manager.isHealthAccessRequested)
        XCTAssertFalse(manager.isHealthAccessGranted)
        XCTAssertTrue(manager.hasCompletedHealthAccessCheck)
        XCTAssertEqual(manager.recoveryPercent, 0)
    }

    func testPrepareForDisplayDayClearsDayScopedTotals() {
        let manager = HealthManager()
        manager.activeCalories = 820
        manager.recoveryBreakdown = RecoveryScoreBreakdown(
            sleepDuration: 80,
            sleepContinuity: 70,
            sleepQuality: 75,
            hrv: 70,
            restingHeartRate: 75,
            total: 75
        )
        manager.hrvSDNN = 62
        manager.restingHeartRate = 54
        manager.sleepMinutes = 420

        let dayStart = Calendar.current.startOfDay(for: Date())
        manager.prepareForDisplayDay(dayStart)

        XCTAssertEqual(manager.activeCalories, 0)
        XCTAssertEqual(manager.recoveryPercent, 0)
        XCTAssertEqual(manager.hrvSDNN, 0)
        XCTAssertEqual(manager.restingHeartRate, 0)
        XCTAssertEqual(manager.sleepMinutes, 0)
    }

    func testActivityMetricsSnapshotRecoveryPercentMatchesBreakdown() {
        let snapshot = ActivityMetricsSnapshot(
            activeCalories: 420,
            steps: 8_500,
            exerciseMinutes: 42,
            sleepMinutes: 420,
            timeInBedMinutes: 480,
            awakeMinutes: 35,
            awakeningsCount: 2,
            distanceKm: 6.2,
            standHours: 10,
            vo2Max: 41.5,
            deepSleepMinutes: 75,
            remSleepMinutes: 95,
            coreSleepMinutes: 250,
            restingHeartRate: 54,
            hrvSDNN: 62
        )

        XCTAssertEqual(snapshot.recoveryPercent, snapshot.recoveryBreakdown.total)
        XCTAssertGreaterThan(snapshot.recoveryPercent, 0)
        XCTAssertGreaterThan(snapshot.sleepScore, 0)
    }

    func testActivityMetricsSnapshotSleepScoreIsZeroWithoutSleep() {
        let snapshot = ActivityMetricsSnapshot(
            activeCalories: 0,
            steps: 0,
            exerciseMinutes: 0,
            sleepMinutes: 0,
            timeInBedMinutes: 0,
            awakeMinutes: 0,
            awakeningsCount: 0,
            distanceKm: 0,
            standHours: 0,
            vo2Max: 0,
            deepSleepMinutes: 0,
            remSleepMinutes: 0,
            coreSleepMinutes: 0,
            restingHeartRate: 0,
            hrvSDNN: 0
        )

        XCTAssertEqual(snapshot.sleepScore, 0)
        XCTAssertEqual(snapshot.recoveryPercent, snapshot.recoveryBreakdown.total)
    }
}
