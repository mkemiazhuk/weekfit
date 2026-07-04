import XCTest
@testable import WeekFit

final class BeliefMaturityResolverTests: XCTestCase {

    func testUpgradePathPreservesExistingThresholds() {
        XCTAssertEqual(
            BeliefMaturityResolver.resolve(
                current: .watching,
                effectSize: 9,
                hasMinimumSamples: true,
                hasEstablishedSamples: false,
                emergedThreshold: 8,
                establishedThreshold: 6
            ),
            .emerging
        )

        XCTAssertEqual(
            BeliefMaturityResolver.resolve(
                current: .emerging,
                effectSize: 7,
                hasMinimumSamples: true,
                hasEstablishedSamples: true,
                emergedThreshold: 8,
                establishedThreshold: 6
            ),
            .established
        )
    }

    func testEstablishedDowngradesToWeakeningWhenEffectWeakens() {
        XCTAssertEqual(
            BeliefMaturityResolver.resolve(
                current: .established,
                effectSize: 3,
                hasMinimumSamples: true,
                hasEstablishedSamples: true,
                emergedThreshold: 8,
                establishedThreshold: 6
            ),
            .weakening
        )
    }

    func testWeakeningDowngradesToRetiredWhenEffectDisappears() {
        XCTAssertEqual(
            BeliefMaturityResolver.resolve(
                current: .weakening,
                effectSize: 1,
                hasMinimumSamples: true,
                hasEstablishedSamples: true,
                emergedThreshold: 8,
                establishedThreshold: 6
            ),
            .retired
        )
    }

    func testEmergingDowngradesToWatchingBelowEmergenceThreshold() {
        XCTAssertEqual(
            BeliefMaturityResolver.resolve(
                current: .emerging,
                effectSize: 5,
                hasMinimumSamples: true,
                hasEstablishedSamples: false,
                emergedThreshold: 8,
                establishedThreshold: 6
            ),
            .watching
        )
    }

    func testDowngradeDoesNotProduceUpgradeEvent() {
        let event = BeliefUpgradeEventFactory.makeEvent(
            beliefID: .sleepDurationRecovery,
            previousMaturity: .established,
            nextMaturity: .weakening
        )
        XCTAssertNil(event)
    }
}
