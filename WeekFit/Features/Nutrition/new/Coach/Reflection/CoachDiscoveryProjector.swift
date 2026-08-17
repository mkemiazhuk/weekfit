import Foundation

/// Projects belief evaluation results into durable Discoveries + Tell offers.
enum CoachDiscoveryProjector {

    static func project(
        results: [BeliefEvaluationResult],
        spokenEventIDs: Set<String>,
        now: Date = Date()
    ) {
        for result in results {
            project(result: result, spokenEventIDs: spokenEventIDs, now: now)
        }
    }

    static func project(
        result: BeliefEvaluationResult,
        spokenEventIDs: Set<String>,
        now: Date = Date()
    ) {
        let token = CoachDiscoveryMaterialToken.make(
            maturity: result.nextMaturity,
            effectSize: result.effectSize
        )
        let eligibleDayCount = result.evidence?.eligibleDayCount
        let previouslySeen = hasUserAlreadyHeard(
            beliefID: result.beliefID,
            spokenEventIDs: spokenEventIDs
        )

        switch result.nextMaturity {
        case .established:
            projectEstablished(
                result: result,
                token: token,
                eligibleDayCount: eligibleDayCount,
                previouslySeen: previouslySeen,
                now: now
            )

        case .weakening:
            updateStatus(
                beliefID: result.beliefID,
                status: .weakening,
                result: result,
                token: token,
                now: now
            )

        case .retired:
            updateStatus(
                beliefID: result.beliefID,
                status: .retired,
                result: result,
                token: token,
                now: now
            )

        case .emerging, .watching:
            // Candidate / emerging stay internal — never create a Discovery offer.
            if let existing = CoachDiscoveryStore.discovery(for: result.beliefID) {
                var updated = existing
                updated.lastEvaluatedAt = now
                updated.effectSize = result.effectSize
                updated.confidence = result.confidence
                updated.eligibleDayCount = eligibleDayCount
                updated.materialChangeToken = token
                if result.nextMaturity == .watching {
                    // Keep historical discovery but don't resurrect offers.
                    updated.status = existing.status == .active ? .weakening : existing.status
                }
                CoachDiscoveryStore.upsert(updated)
            }
        }
    }

    // MARK: - Established

    private static func projectEstablished(
        result: BeliefEvaluationResult,
        token: String,
        eligibleDayCount: Int?,
        previouslySeen: Bool,
        now: Date
    ) {
        let existing = CoachDiscoveryStore.discovery(for: result.beliefID)
        let becameLearned = result.nextMaturity.isUpgrade(from: result.previousMaturity)
            && result.nextMaturity == .established

        if var discovery = existing {
            let previousToken = discovery.materialChangeToken
            let previousEffect = discovery.effectSize
            discovery.status = .active
            discovery.lastEvaluatedAt = now
            discovery.effectSize = result.effectSize
            discovery.confidence = result.confidence
            discovery.eligibleDayCount = eligibleDayCount
            discovery.materialChangeToken = token
            if previouslySeen {
                discovery.hasBeenSeenByUser = true
            }
            CoachDiscoveryStore.upsert(discovery)

            if becameLearned {
                enqueueFirstLearnedIfNeeded(
                    discovery: discovery,
                    previouslySeen: previouslySeen || discovery.hasBeenSeenByUser,
                    now: now
                )
            } else if previousToken != token,
                      discovery.hasBeenSeenByUser,
                      abs(result.effectSize - previousEffect) >= 4 {
                let offer = CoachDiscoveryOffer.make(
                    discoveryID: discovery.id,
                    beliefID: discovery.beliefID,
                    kind: .materialUpdate,
                    materialChangeToken: token,
                    createdAt: now
                )
                CoachDiscoveryStore.enqueueOffer(offer)
            }
            return
        }

        let discovery = CoachDiscovery(
            beliefID: result.beliefID,
            status: .active,
            firstLearnedAt: now,
            lastEvaluatedAt: now,
            materialChangeToken: token,
            effectSize: result.effectSize,
            confidence: result.confidence,
            eligibleDayCount: eligibleDayCount,
            // Already-established beliefs backfill silently into the archive.
            hasBeenSeenByUser: previouslySeen || !becameLearned
        )
        CoachDiscoveryStore.upsert(discovery)
        if becameLearned {
            enqueueFirstLearnedIfNeeded(
                discovery: discovery,
                previouslySeen: discovery.hasBeenSeenByUser,
                now: now
            )
        }
    }

    private static func enqueueFirstLearnedIfNeeded(
        discovery: CoachDiscovery,
        previouslySeen: Bool,
        now: Date
    ) {
        if previouslySeen {
            // Migration: archive without re-announcing old reflections.
            return
        }

        let offer = CoachDiscoveryOffer.make(
            discoveryID: discovery.id,
            beliefID: discovery.beliefID,
            kind: .firstLearned,
            materialChangeToken: discovery.materialChangeToken,
            createdAt: now
        )
        CoachDiscoveryStore.enqueueOffer(offer)
    }

    private static func updateStatus(
        beliefID: CoachBeliefID,
        status: CoachDiscoveryStatus,
        result: BeliefEvaluationResult,
        token: String,
        now: Date
    ) {
        guard var discovery = CoachDiscoveryStore.discovery(for: beliefID) else { return }
        discovery.status = status
        discovery.lastEvaluatedAt = now
        discovery.effectSize = result.effectSize
        discovery.confidence = result.confidence
        discovery.eligibleDayCount = result.evidence?.eligibleDayCount
        discovery.materialChangeToken = token
        CoachDiscoveryStore.upsert(discovery)
        // Downgrades never enqueue user-facing offers.
    }

    // MARK: - Migration helpers

    static func hasUserAlreadyHeard(
        beliefID: CoachBeliefID,
        spokenEventIDs: Set<String>
    ) -> Bool {
        spokenEventIDs.contains { eventID in
            eventID.hasPrefix("\(beliefID.rawValue).")
        }
    }
}
