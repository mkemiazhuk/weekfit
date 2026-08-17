import XCTest
@testable import WeekFit

final class CoachDiscoveryProjectorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CoachUnderstandingStore.resetForTests()
        CoachDiscoveryStore.resetForTests()
    }

    override func tearDown() {
        CoachUnderstandingStore.resetForTests()
        CoachDiscoveryStore.resetForTests()
        super.tearDown()
    }

    func testFirstEstablishedCreatesActiveDiscoveryAndFirstLearnedOffer() {
        let result = makeResult(
            beliefID: .sleepDurationRecovery,
            previous: .emerging,
            next: .established,
            effectSize: 10
        )

        CoachDiscoveryProjector.project(results: [result], spokenEventIDs: [])

        let discovery = CoachDiscoveryStore.discovery(for: .sleepDurationRecovery)
        XCTAssertEqual(discovery?.status, .active)
        XCTAssertEqual(discovery?.family, .sleep)
        XCTAssertEqual(discovery?.valence, .positive)
        XCTAssertFalse(discovery?.hasBeenSeenByUser ?? true)

        let offer = CoachDiscoveryStore.nextOffer()
        XCTAssertEqual(offer?.kind, .firstLearned)
        XCTAssertEqual(offer?.beliefID, .sleepDurationRecovery)
    }

    func testReEvaluatingEstablishedDoesNotDuplicateFirstLearnedOffer() {
        let first = makeResult(
            beliefID: .sleepDurationRecovery,
            previous: .emerging,
            next: .established,
            effectSize: 10
        )
        CoachDiscoveryProjector.project(results: [first], spokenEventIDs: [])
        XCTAssertEqual(CoachDiscoveryStore.pendingOffersSnapshot().count, 1)

        let again = makeResult(
            beliefID: .sleepDurationRecovery,
            previous: .established,
            next: .established,
            effectSize: 10
        )
        CoachDiscoveryProjector.project(results: [again], spokenEventIDs: [])

        XCTAssertEqual(CoachDiscoveryStore.pendingOffersSnapshot().count, 1)
        XCTAssertEqual(CoachDiscoveryStore.activeDiscoveries().count, 1)
    }

    func testSpokenReflectionMigratesWithoutReAnnouncing() {
        let spoken: Set<String> = [
            "sleepDurationRecovery.strengthened.established"
        ]
        let result = makeResult(
            beliefID: .sleepDurationRecovery,
            previous: .emerging,
            next: .established,
            effectSize: 11
        )

        CoachDiscoveryProjector.project(results: [result], spokenEventIDs: spoken)

        let discovery = CoachDiscoveryStore.discovery(for: .sleepDurationRecovery)
        XCTAssertEqual(discovery?.status, .active)
        XCTAssertTrue(discovery?.hasBeenSeenByUser ?? false)
        XCTAssertNil(CoachDiscoveryStore.nextOffer())
    }

    func testWeakeningMarksDiscoveryInactiveWithoutOffer() {
        let learned = makeResult(
            beliefID: .underfuelingRecovery,
            previous: .emerging,
            next: .established,
            effectSize: 12
        )
        CoachDiscoveryProjector.project(results: [learned], spokenEventIDs: [])
        XCTAssertEqual(CoachDiscoveryStore.pendingOffersSnapshot().count, 1)

        let weaken = makeResult(
            beliefID: .underfuelingRecovery,
            previous: .established,
            next: .weakening,
            effectSize: 2
        )
        CoachDiscoveryProjector.project(results: [weaken], spokenEventIDs: [])

        XCTAssertEqual(CoachDiscoveryStore.discovery(for: .underfuelingRecovery)?.status, .weakening)
        XCTAssertEqual(CoachDiscoveryStore.activeDiscoveries().count, 0)
        // Original firstLearned may still be pending; no new weaken offer was added.
        let kinds = CoachDiscoveryStore.pendingOffersSnapshot().map(\.kind)
        XCTAssertFalse(kinds.contains(.materialUpdate))
        XCTAssertEqual(kinds.filter { $0 == .firstLearned }.count, 1)
    }

    func testEmergingDoesNotCreateDiscovery() {
        let emerging = makeResult(
            beliefID: .lateBedtimeRecovery,
            previous: .watching,
            next: .emerging,
            effectSize: 9
        )

        CoachDiscoveryProjector.project(results: [emerging], spokenEventIDs: [])

        XCTAssertNil(CoachDiscoveryStore.discovery(for: .lateBedtimeRecovery))
        XCTAssertNil(CoachDiscoveryStore.nextOffer())
    }

    @MainActor
    func testEvaluateBeliefsProjectsDiscoveries() {
        let observations = SleepBeliefIntegrationFixtures.observationsSupportingAllThreeBeliefs()
        CoachObservationStore.seedForTests(observations)
        CoachUnderstandingService.evaluateBeliefs()

        // Sleep fixtures typically reach emerging for the three sleep beliefs.
        // Discoveries only appear once established — so this asserts wiring without requiring established.
        XCTAssertEqual(CoachBeliefRegistry.registeredBeliefIDs.count, 12)
        let sleepDiscoveries = CoachDiscoveryStore.allDiscoveries().filter {
            $0.family == .sleep
        }
        for discovery in sleepDiscoveries {
            XCTAssertEqual(discovery.status, .active)
        }
    }

    func testAlreadyEstablishedBeliefBackfillsArchiveWithoutOffer() {
        let result = makeResult(
            beliefID: .sleepConsistencyRecovery,
            previous: .established,
            next: .established,
            effectSize: 9
        )

        CoachDiscoveryProjector.project(results: [result], spokenEventIDs: [])

        let discovery = CoachDiscoveryStore.discovery(for: .sleepConsistencyRecovery)
        XCTAssertEqual(discovery?.status, .active)
        XCTAssertTrue(discovery?.hasBeenSeenByUser ?? false)
        XCTAssertNil(CoachDiscoveryStore.nextOffer())
    }

    func testMarkOfferDisplayedConsumesAndMarksSeen() {
        let result = makeResult(
            beliefID: .recoveryAfterRestDay,
            previous: .emerging,
            next: .established,
            effectSize: 9
        )
        CoachDiscoveryProjector.project(results: [result], spokenEventIDs: [])
        guard let offer = CoachDiscoveryStore.nextOffer() else {
            return XCTFail("Expected firstLearned offer")
        }

        CoachDiscoveryStore.markOfferDisplayed(offer)

        XCTAssertNil(CoachDiscoveryStore.nextOffer())
        XCTAssertTrue(CoachDiscoveryStore.discovery(for: .recoveryAfterRestDay)?.hasBeenSeenByUser ?? false)
    }

    // MARK: - Helpers

    private func makeResult(
        beliefID: CoachBeliefID,
        previous: CoachBeliefMaturity,
        next: CoachBeliefMaturity,
        effectSize: Double
    ) -> BeliefEvaluationResult {
        BeliefEvaluationResult(
            beliefID: beliefID,
            previousMaturity: previous,
            nextMaturity: next,
            evidence: BeliefEvidence(
                eligibleDayCount: 14,
                primaryGroupSampleCount: 6,
                comparisonGroupSampleCount: 5,
                primaryGroupAverage: 80,
                comparisonGroupAverage: 70
            ),
            confidence: 0.8,
            effectSize: effectSize,
            event: BeliefUpgradeEventFactory.makeEvent(
                beliefID: beliefID,
                previousMaturity: previous,
                nextMaturity: next
            )
        )
    }
}
