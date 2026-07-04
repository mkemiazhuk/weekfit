import XCTest
@testable import WeekFit

final class CoachBeliefSynthesisAuditTests: XCTestCase {

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

    func testAllWatchingStateReportsUnknownDriverAndIsolatedProfile() {
        let result = CoachBeliefSynthesisAudit.synthesize(
            signals: CoachBeliefRegistry.registeredBeliefIDs.map {
                CoachBeliefSynthesisAudit.BeliefSignal(
                    beliefID: $0,
                    maturity: .watching,
                    confidence: 0,
                    effectSize: 0,
                    hasAnalyzableEvidence: false
                )
            }
        )

        XCTAssertEqual(result.dominantRecoveryDriver, .unknown)
        XCTAssertNil(result.strongestEstablishedPattern)
        XCTAssertNil(result.strongestEmergingPattern)
        XCTAssertTrue(result.conflictingPatterns.isEmpty)
        XCTAssertEqual(Set(result.insufficientDomains), Set([
            .sleep,
            .trainingLoad,
            .nutrition,
        ]))
        XCTAssertFalse(result.formsCoherentProfile)
        XCTAssertTrue(result.diagnostics.contains(where: { $0.contains("all beliefs are still watching") }))
        XCTAssertTrue(result.diagnostics.contains(where: { $0.contains("beliefs remain isolated") || $0.contains("all beliefs remain in watching") }))
        XCTAssertEqual(result.understandingConfidence.understandingConfidenceLabel, .low)
        XCTAssertEqual(result.understandingConfidence.understandingCoverageByDomain.sleep, 0)
        XCTAssertEqual(result.understandingConfidence.understandingCoverageByDomain.trainingLoad, 0)
        XCTAssertEqual(result.understandingConfidence.understandingCoverageByDomain.nutrition, 0)
    }

    func testOneEstablishedSleepBeliefIdentifiesSleepAsDominantDriver() {
        let signals = allWatchingSignals().map { signal in
            guard signal.beliefID == .sleepDurationRecovery else { return signal }
            return CoachBeliefSynthesisAudit.BeliefSignal(
                beliefID: signal.beliefID,
                maturity: .established,
                confidence: 0.82,
                effectSize: 12.4,
                hasAnalyzableEvidence: true
            )
        }

        let result = CoachBeliefSynthesisAudit.synthesize(signals: signals)

        XCTAssertEqual(result.dominantRecoveryDriver, .sleep)
        XCTAssertEqual(result.strongestEstablishedPattern, .sleepDurationRecovery)
        XCTAssertFalse(result.formsCoherentProfile)
        XCTAssertTrue(result.diagnostics.contains(where: { $0.contains("Sleep appears to be the strongest confirmed recovery driver") }))
        XCTAssertTrue(result.diagnostics.contains(where: { $0.contains("Training-load patterns are still watching") }))
        XCTAssertTrue(result.diagnostics.contains(where: { $0.contains("Nutrition has insufficient confirmed signal") }))
        XCTAssertTrue(result.diagnostics.contains(where: { $0.contains("beliefs remain isolated") }))
        XCTAssertTrue(
            result.understandingConfidence.understandingConfidenceLabel == .low
                || result.understandingConfidence.understandingConfidenceLabel == .medium
        )
        XCTAssertGreaterThan(result.understandingConfidence.understandingCoverageByDomain.sleep, 0)
        XCTAssertEqual(result.understandingConfidence.understandingCoverageByDomain.trainingLoad, 0)
        XCTAssertEqual(result.understandingConfidence.understandingCoverageByDomain.nutrition, 0)
        XCTAssertTrue(result.understandingConfidence.diagnosticExplanation.contains("Nutrition remains uncovered"))
    }

    func testConflictingSignalsBlockCoherentProfile() {
        let signals = [
            CoachBeliefSynthesisAudit.BeliefSignal(
                beliefID: .sleepDurationRecovery,
                maturity: .established,
                confidence: 0.9,
                effectSize: 10.0,
                hasAnalyzableEvidence: true
            ),
            CoachBeliefSynthesisAudit.BeliefSignal(
                beliefID: .heavyLoadRecoveryLag,
                maturity: .established,
                confidence: 0.88,
                effectSize: -9.0,
                hasAnalyzableEvidence: true
            ),
            CoachBeliefSynthesisAudit.BeliefSignal(
                beliefID: .underfuelingRecovery,
                maturity: .watching,
                confidence: 0,
                effectSize: 0,
                hasAnalyzableEvidence: false
            ),
            CoachBeliefSynthesisAudit.BeliefSignal(
                beliefID: .sleepConsistencyRecovery,
                maturity: .watching,
                confidence: 0.2,
                effectSize: 3.0,
                hasAnalyzableEvidence: false
            ),
            CoachBeliefSynthesisAudit.BeliefSignal(
                beliefID: .lateBedtimeRecovery,
                maturity: .watching,
                confidence: 0.2,
                effectSize: 2.0,
                hasAnalyzableEvidence: false
            ),
            CoachBeliefSynthesisAudit.BeliefSignal(
                beliefID: .recoveryAfterRestDay,
                maturity: .watching,
                confidence: 0.2,
                effectSize: 1.0,
                hasAnalyzableEvidence: false
            ),
            CoachBeliefSynthesisAudit.BeliefSignal(
                beliefID: .consecutiveHardDaysFatigue,
                maturity: .watching,
                confidence: 0.2,
                effectSize: 1.0,
                hasAnalyzableEvidence: false
            ),
        ]

        let result = CoachBeliefSynthesisAudit.synthesize(signals: signals)

        XCTAssertFalse(result.conflictingPatterns.isEmpty)
        XCTAssertFalse(result.formsCoherentProfile)
        XCTAssertTrue(result.diagnostics.contains(where: { $0.contains("Conflicting patterns") }))
        XCTAssertTrue(result.diagnostics.contains(where: { $0.contains("established patterns conflict") }))
        XCTAssertTrue(result.understandingConfidence.diagnosticExplanation.contains("Conflicting patterns reduced confidence"))
    }

    func testEstablishedSleepAndTrainingYieldsMediumOrHighConfidence() {
        let signals = allWatchingSignals().map { signal in
            switch signal.beliefID {
            case .sleepDurationRecovery:
                return CoachBeliefSynthesisAudit.BeliefSignal(
                    beliefID: signal.beliefID,
                    maturity: .established,
                    confidence: 0.9,
                    effectSize: 11.0,
                    hasAnalyzableEvidence: true
                )
            case .heavyLoadRecoveryLag:
                return CoachBeliefSynthesisAudit.BeliefSignal(
                    beliefID: signal.beliefID,
                    maturity: .established,
                    confidence: 0.88,
                    effectSize: 9.5,
                    hasAnalyzableEvidence: true
                )
            default:
                return signal
            }
        }

        let result = CoachBeliefSynthesisAudit.synthesize(signals: signals)

        XCTAssertTrue(
            result.understandingConfidence.understandingConfidenceLabel == .medium
                || result.understandingConfidence.understandingConfidenceLabel == .high
        )
        XCTAssertGreaterThan(result.understandingConfidence.understandingCoverageByDomain.sleep, 0.35)
        XCTAssertGreaterThan(result.understandingConfidence.understandingCoverageByDomain.trainingLoad, 0.35)
        XCTAssertEqual(result.understandingConfidence.understandingCoverageByDomain.nutrition, 0)
    }

    func testConflictingSignalsReduceConfidenceScore() {
        let baseSignals = allWatchingSignals().map { signal in
            switch signal.beliefID {
            case .sleepDurationRecovery:
                return CoachBeliefSynthesisAudit.BeliefSignal(
                    beliefID: signal.beliefID,
                    maturity: .established,
                    confidence: 0.9,
                    effectSize: 10.0,
                    hasAnalyzableEvidence: true
                )
            case .heavyLoadRecoveryLag:
                return CoachBeliefSynthesisAudit.BeliefSignal(
                    beliefID: signal.beliefID,
                    maturity: .established,
                    confidence: 0.88,
                    effectSize: 9.0,
                    hasAnalyzableEvidence: true
                )
            default:
                return signal
            }
        }

        let aligned = CoachBeliefSynthesisAudit.synthesize(signals: baseSignals)

        let conflicting = CoachBeliefSynthesisAudit.synthesize(
            signals: baseSignals.map { signal in
                guard signal.beliefID == .heavyLoadRecoveryLag else { return signal }
                return CoachBeliefSynthesisAudit.BeliefSignal(
                    beliefID: signal.beliefID,
                    maturity: .established,
                    confidence: 0.88,
                    effectSize: -9.0,
                    hasAnalyzableEvidence: true
                )
            }
        )

        XCTAssertLessThan(
            conflicting.understandingConfidence.understandingConfidenceScore,
            aligned.understandingConfidence.understandingConfidenceScore
        )
    }

    func testCoherentProfileWhenMultipleEstablishedBeliefsAlign() {
        let signals = allWatchingSignals().map { signal in
            switch signal.beliefID {
            case .sleepDurationRecovery:
                return CoachBeliefSynthesisAudit.BeliefSignal(
                    beliefID: signal.beliefID,
                    maturity: .established,
                    confidence: 0.9,
                    effectSize: 11.0,
                    hasAnalyzableEvidence: true
                )
            case .sleepConsistencyRecovery:
                return CoachBeliefSynthesisAudit.BeliefSignal(
                    beliefID: signal.beliefID,
                    maturity: .established,
                    confidence: 0.85,
                    effectSize: 8.5,
                    hasAnalyzableEvidence: true
                )
            default:
                return signal
            }
        }

        let result = CoachBeliefSynthesisAudit.synthesize(signals: signals)

        XCTAssertEqual(result.dominantRecoveryDriver, .sleep)
        XCTAssertTrue(result.formsCoherentProfile)
        XCTAssertTrue(result.diagnostics.contains(where: { $0.contains("coherent athlete profile") }))
    }

    func testDebugInspectorSnapshotIncludesUnderstandingSummary() {
        let snapshot = CoachBeliefDebugInspector.build(coachState: .unavailable(reason: "test"))

        XCTAssertEqual(snapshot.understandingSummary.dominantRecoveryDriver, .unknown)
        XCTAssertFalse(snapshot.understandingSummary.diagnostics.isEmpty)
        XCTAssertEqual(snapshot.understandingSummary.understandingConfidence.understandingConfidenceLabel, .low)
    }

    func testSynthesizeFromEvaluationResultsUsesStoredMaturity() {
        CoachUnderstandingStore.seedForTests(
            beliefs: [
                CoachBelief(id: .sleepDurationRecovery, maturity: .established, lastUpdated: Date()),
            ]
        )

        let observations = SleepBeliefIntegrationFixtures.observationsSupportingAllThreeBeliefs()
        let evaluations = CoachBeliefRegistry.evaluateAll(observations: observations)
        let result = CoachBeliefSynthesisAudit.synthesize(evaluationResults: evaluations)

        XCTAssertNotNil(result.strongestEstablishedPattern)
        XCTAssertFalse(result.diagnostics.isEmpty)
    }

    // MARK: - Fixtures

    private func allWatchingSignals() -> [CoachBeliefSynthesisAudit.BeliefSignal] {
        CoachBeliefRegistry.registeredBeliefIDs.map {
            CoachBeliefSynthesisAudit.BeliefSignal(
                beliefID: $0,
                maturity: .watching,
                confidence: 0,
                effectSize: 0,
                hasAnalyzableEvidence: false
            )
        }
    }
}
