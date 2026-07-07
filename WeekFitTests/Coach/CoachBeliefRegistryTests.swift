import XCTest
@testable import WeekFit

final class CoachBeliefRegistryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        super.tearDown()
    }

    func testRegistryEvaluatesAllRegisteredBeliefs() {
        let results = CoachBeliefRegistry.evaluateAll(observations: [])
        XCTAssertEqual(results.count, 7)
        XCTAssertEqual(Set(results.map(\.beliefID)), Set([
            .sleepConsistencyRecovery,
            .sleepDurationRecovery,
            .lateBedtimeRecovery,
            .heavyLoadRecoveryLag,
            .recoveryAfterRestDay,
            .consecutiveHardDaysFatigue,
            .underfuelingRecovery,
        ]))
    }
}
