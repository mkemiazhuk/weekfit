#if DEBUG
import XCTest
@testable import WeekFit

final class CoachUnderstandingInspectorPresentationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
        CoachObservationStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        CoachObservationStore.resetForTests()
        super.tearDown()
    }

    func testExecutiveSummaryUsesAthleteCentricHeadlines() {
        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))
        let summary = CoachUnderstandingInspectorPresentation.executiveSummary(from: snapshot)

        XCTAssertEqual(summary.domainHeadlines.count, 3)
        XCTAssertTrue(summary.domainHeadlines.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(summary.confidenceLabel, "low")
    }

    func testDomainSummariesGroupAllThreeDomains() {
        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))
        let domains = CoachUnderstandingInspectorPresentation.domainSummaries(from: snapshot)

        XCTAssertEqual(domains.map(\.title), ["Sleep", "Training", "Nutrition"])
        XCTAssertTrue(domains.allSatisfy { !$0.missingKnowledge.isEmpty })
    }

    func testEstablishedSleepBeliefProducesWellUnderstoodHeadline() {
        CoachUnderstandingStore.seedForTests(
            beliefs: [
                CoachBelief(id: .sleepDurationRecovery, maturity: .established, lastUpdated: Date()),
            ]
        )
        CoachObservationStore.seedForTests(SleepBeliefIntegrationFixtures.observationsSupportingAllThreeBeliefs())

        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))
        let sleep = CoachUnderstandingInspectorPresentation.domainSummaries(from: snapshot).first { $0.domain == .sleep }

        XCTAssertEqual(sleep?.status, .establishedPattern)
        XCTAssertTrue(sleep?.headline.contains("established") ?? false)
        XCTAssertFalse(sleep?.establishedBeliefs.isEmpty ?? true)
    }
}
#endif
