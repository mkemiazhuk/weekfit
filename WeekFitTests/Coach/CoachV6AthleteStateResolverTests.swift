import XCTest
@testable import WeekFit

final class CoachV6AthleteStateResolverTests: XCTestCase {

    func testFreshRequiresGoodRecoverySleepAndNoHeavyYesterday() {
        let readiness = CoachV6DayReadiness(
            recoveryPercent: 90,
            sleepHours: 8,
            recoveryBand: .good,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        XCTAssertEqual(CoachV6AthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .fresh)
    }

    func testNormalForModerateRecoveryWithoutFatigueSignals() {
        let readiness = CoachV6DayReadiness(
            recoveryPercent: 62,
            sleepHours: 7,
            recoveryBand: .moderate,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        XCTAssertEqual(CoachV6AthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .normal)
    }

    func testFatiguedForLowRecovery() {
        let readiness = CoachV6DayReadiness(
            recoveryPercent: 48,
            sleepHours: 7,
            recoveryBand: .low,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        XCTAssertEqual(CoachV6AthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .fatigued)
    }

    func testFatiguedForShortSleepWithModerateRecovery() {
        let readiness = CoachV6DayReadiness(
            recoveryPercent: 65,
            sleepHours: 5,
            recoveryBand: .moderate,
            hadHeavyYesterday: false,
            sleepIsLow: true
        )
        XCTAssertEqual(CoachV6AthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .fatigued)
    }

    func testFatiguedForHeavyYesterdayWithModerateRecovery() {
        let readiness = CoachV6DayReadiness(
            recoveryPercent: 65,
            sleepHours: 7.5,
            recoveryBand: .moderate,
            hadHeavyYesterday: true,
            sleepIsLow: false
        )
        XCTAssertEqual(CoachV6AthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .fatigued)
    }

    func testVeryFatiguedForLowRecoveryAndShortSleep() {
        let readiness = CoachV6DayReadiness(
            recoveryPercent: 38,
            sleepHours: 4.5,
            recoveryBand: .low,
            hadHeavyYesterday: true,
            sleepIsLow: true
        )
        XCTAssertEqual(CoachV6AthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .veryFatigued)
    }

    func testVeryFatiguedForVeryLowRecoveryPercent() {
        let readiness = CoachV6DayReadiness(
            recoveryPercent: 35,
            sleepHours: 7,
            recoveryBand: .low,
            hadHeavyYesterday: false,
            sleepIsLow: false
        )
        XCTAssertEqual(CoachV6AthleteStateResolver.resolve(dayReadiness: readiness).bodyState, .veryFatigued)
    }

    func testUnknownDayReadinessMapsToNormal() {
        XCTAssertEqual(
            CoachV6AthleteStateResolver.resolve(dayReadiness: .unknown).bodyState,
            .normal
        )
    }
}
