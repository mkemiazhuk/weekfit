import XCTest
@testable import WeekFit

final class TodayFirstPaintGateTests: XCTestCase {
    func testStaysHiddenUntilHealthMayaAndProposalHaveSettled() {
        var gate = TodayFirstPaintGate(
            healthFirstPassDone: false,
            mayaAccessResolved: false,
            proposalDebounceSettled: false,
            timedOut: false,
            bypass: false
        )
        XCTAssertFalse(gate.shouldReveal)

        gate.healthFirstPassDone = true
        XCTAssertFalse(gate.shouldReveal)

        gate.mayaAccessResolved = true
        XCTAssertFalse(gate.shouldReveal)

        gate.proposalDebounceSettled = true
        XCTAssertTrue(gate.shouldReveal)
    }

    func testTimeoutAndBypassRevealWithoutWaiting() {
        let timedOut = TodayFirstPaintGate(
            healthFirstPassDone: false,
            mayaAccessResolved: false,
            proposalDebounceSettled: false,
            timedOut: true,
            bypass: false
        )
        XCTAssertTrue(timedOut.shouldReveal)

        let bypassed = TodayFirstPaintGate(
            healthFirstPassDone: false,
            mayaAccessResolved: false,
            proposalDebounceSettled: false,
            timedOut: false,
            bypass: true
        )
        XCTAssertTrue(bypassed.shouldReveal)
    }
}
