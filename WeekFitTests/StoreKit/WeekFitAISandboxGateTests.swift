import XCTest
@testable import WeekFit

final class WeekFitAISandboxGateTests: XCTestCase {
    private let origin = URL(string: "https://weekfit-food-photo.onrender.com")!

    func testDeviceSandboxBuildUsesSandboxAndEnablesBilling() {
        let decision = WeekFitAISandboxDecision.decide(
            usageEnabled: true,
            sandboxRequested: true,
            sandboxURL: origin,
            compiledSandboxAllowed: true
        )
        XCTAssertEqual(decision.route, .sandbox(origin))
        XCTAssertTrue(decision.billingEnabled)
        XCTAssertEqual(decision.environmentHeader, "Sandbox")
    }

    func testReleasePlistWithoutCompilationFlagRefusesProduction() {
        let decision = WeekFitAISandboxDecision.decide(
            usageEnabled: true,
            sandboxRequested: true,
            sandboxURL: origin,
            compiledSandboxAllowed: false
        )
        XCTAssertEqual(decision.route, .refused)
        XCTAssertFalse(decision.billingEnabled)
        XCTAssertNotEqual(decision.environmentHeader, "Production")
    }

    func testMissingUsageFlagOrBadURLRefusesProduction() {
        let missingUsage = WeekFitAISandboxDecision.decide(
            usageEnabled: false,
            sandboxRequested: true,
            sandboxURL: origin,
            compiledSandboxAllowed: true
        )
        XCTAssertEqual(missingUsage.route, .refused)

        let badURL = WeekFitAISandboxDecision.decide(
            usageEnabled: true,
            sandboxRequested: true,
            sandboxURL: URL(string: "https://weekfit-food-photo.onrender.com/v2"),
            compiledSandboxAllowed: true
        )
        XCTAssertEqual(badURL.route, .refused)
        XCTAssertEqual(
            WeekFitAISandboxDecision.refusedBaseURL.host,
            "invalid.weekfit-sandbox.invalid"
        )
    }

    func testAppStoreBuildStaysOnProductionWithoutSandboxFlags() {
        let decision = WeekFitAISandboxDecision.decide(
            usageEnabled: false,
            sandboxRequested: false,
            sandboxURL: nil,
            compiledSandboxAllowed: false
        )
        XCTAssertEqual(decision.route, .production)
        XCTAssertFalse(decision.billingEnabled)
        XCTAssertEqual(decision.environmentHeader, "Production")
    }
}
