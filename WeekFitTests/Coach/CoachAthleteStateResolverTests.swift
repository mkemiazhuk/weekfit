import XCTest
@testable import WeekFit

final class CoachAthleteStateResolverTests: XCTestCase {

    func testFreshRequiresGoodRecoverySleepAndNoHeavyYesterday() {
        let readiness = CoachDayReadiness(
            recoveryPercent: 90,
            sleepHours: 8,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        XCTAssertEqual(CoachAthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .fresh)
    }

    func testNormalForModerateRecoveryWithoutFatigueSignals() {
        let readiness = CoachDayReadiness(
            recoveryPercent: 62,
            sleepHours: 7,
            recoveryBand: .moderate,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        XCTAssertEqual(CoachAthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .normal)
    }

    func testFatiguedForLowRecovery() {
        let readiness = CoachDayReadiness(
            recoveryPercent: 48,
            sleepHours: 7,
            recoveryBand: .low,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        XCTAssertEqual(CoachAthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .fatigued)
    }

    func testFatiguedForShortSleepWithModerateRecovery() {
        let readiness = CoachDayReadiness(
            recoveryPercent: 65,
            sleepHours: 5,
            recoveryBand: .moderate,
            hadHeavyYesterday: false,
            sleepIsLow: true
        )
        XCTAssertEqual(CoachAthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .fatigued)
    }

    func testFatiguedForHeavyYesterdayWithModerateRecovery() {
        let readiness = CoachDayReadiness(
            recoveryPercent: 65,
            sleepHours: 7.5,
            recoveryBand: .moderate,
            hadHeavyYesterday: true,
            sleepIsLow: false
        )
        XCTAssertEqual(CoachAthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .fatigued)
    }

    func testVeryFatiguedForLowRecoveryAndShortSleep() {
        let readiness = CoachDayReadiness(
            recoveryPercent: 38,
            sleepHours: 4.5,
            recoveryBand: .low,
            hadHeavyYesterday: true,
            sleepIsLow: true
        )
        XCTAssertEqual(CoachAthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .veryFatigued)
    }

    func testVeryFatiguedForVeryLowRecoveryPercent() {
        let readiness = CoachDayReadiness(
            recoveryPercent: 35,
            sleepHours: 7,
            recoveryBand: .low,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        XCTAssertEqual(CoachAthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .veryFatigued)
    }

    func testUnknownDayReadinessMapsToNormal() {
        XCTAssertEqual(
            CoachAthleteStateResolver.resolve(dayReadiness: .unknown).bodyState,
            .normal
        )
    }
}
