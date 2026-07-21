import Foundation

/// Read-only snapshot of belief and reflection pipeline state for developer inspection.
enum CoachBeliefDebugInspector {

    struct BeliefRow: Identifiable, Equatable, Sendable {
        let beliefID: CoachBeliefID
        let maturity: CoachBeliefMaturity
        let lastTransition: String
        let confidence: Double
        let effectSize: Double
        let sampleSize: String
        let evidenceWindow: String
        let hasPendingEvent: Bool
        let hasSpokenEvent: Bool
        let lifecycleState: String?
        let blockingReason: BeliefNoEventReason?
        let noEventReason: String

        var id: String { beliefID.rawValue }
    }

    struct QueuedEventRow: Identifiable, Equatable, Sendable {
        let id: String
        let beliefID: CoachBeliefID
        let change: UnderstandingChange
        let maturity: CoachBeliefMaturity
        let isSpoken: Bool
        let isNextUnspoken: Bool
    }

    struct ReflectionState: Equatable, Sendable {
        let pause: Bool
        let pauseReason: String
        let blockedBy: String?
        let nextUnspokenEventID: String?
        let nextUnspokenBeliefID: CoachBeliefID?
        let reflectionOfferID: String?
        let reflectionOfferBeliefID: String?
        let isReflectionOfferDisplayed: Bool
        let noReflectionReason: String?
    }

    struct Snapshot: Equatable, Sendable {
        let beliefs: [BeliefRow]
        let eventQueue: [QueuedEventRow]
        let reflection: ReflectionState
        let understandingSummary: CoachBeliefSynthesisAudit.Result
        let observationCount: Int
        let nutritionCoverage: ObservationNutritionCoverage
        let capturedAt: Date
    }

    struct ObservationNutritionCoverage: Equatable, Sendable {
        let populatedCount: Int
        let missingCount: Int
        let latestDayKey: String?
        let latestNutritionStatus: String
    }

    static func build(coachState: CoachState, capturedAt: Date = Date()) -> Snapshot {
        let observations = CoachObservationStore.allObservations()
        let evaluations = CoachBeliefRegistry.evaluateAll(observations: observations)
        let evaluationByID = Dictionary(uniqueKeysWithValues: evaluations.map { ($0.beliefID, $0) })
        let pendingEvents = CoachUnderstandingStore.pendingEventsSnapshot()
        let spokenEventIDs = CoachUnderstandingStore.spokenEventIDsSnapshot()
        let nextUnspoken = CoachUnderstandingStore.nextUnspokenEvent()

        let beliefs = CoachBeliefRegistry.registeredBeliefIDs.map { beliefID in
            makeBeliefRow(
                beliefID: beliefID,
                observations: observations,
                evaluation: evaluationByID[beliefID],
                pendingEvents: pendingEvents,
                spokenEventIDs: spokenEventIDs
            )
        }

        let eventQueue = pendingEvents.map { event in
            QueuedEventRow(
                id: event.id,
                beliefID: event.beliefID,
                change: event.change,
                maturity: event.maturity,
                isSpoken: spokenEventIDs.contains(event.id),
                isNextUnspoken: nextUnspoken?.id == event.id
            )
        }

        return Snapshot(
            beliefs: beliefs,
            eventQueue: eventQueue,
            reflection: makeReflectionState(
                coachState: coachState,
                nextUnspoken: nextUnspoken,
                spokenEventIDs: spokenEventIDs
            ),
            understandingSummary: CoachBeliefSynthesisAudit.synthesize(evaluationResults: evaluations),
            observationCount: observations.count,
            nutritionCoverage: makeNutritionCoverage(observations: observations),
            capturedAt: capturedAt
        )
    }

    private static func makeNutritionCoverage(
        observations: [CoachDailyObservation]
    ) -> ObservationNutritionCoverage {
        let populated = observations.filter(\.hasPopulatedNutritionFieldsResolved)
        let latest = observations.last

        return ObservationNutritionCoverage(
            populatedCount: populated.count,
            missingCount: observations.count - populated.count,
            latestDayKey: latest?.dayKey,
            latestNutritionStatus: nutritionStatus(for: latest)
        )
    }

    private static func nutritionStatus(for observation: CoachDailyObservation?) -> String {
        guard let observation else { return "no observations" }
        guard observation.hasPopulatedNutritionFieldsResolved else { return "missing" }

        var parts = [
            "protein=\(observation.proteinGrams ?? 0)g",
            "calories=\(observation.caloriesEaten ?? 0)",
            "meals=\(observation.mealsLoggedCount ?? 0)",
            "water=\(String(format: "%.1f", observation.hydrationLiters ?? 0.0))L"
        ]
        if let deficit = observation.calorieDeficit {
            parts.append("deficit=\(deficit)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Belief rows

    private static func makeBeliefRow(
        beliefID: CoachBeliefID,
        observations: [CoachDailyObservation],
        evaluation: BeliefEvaluationResult?,
        pendingEvents: [UnderstandingEvent],
        spokenEventIDs: Set<String>
    ) -> BeliefRow {
        let stored = CoachUnderstandingStore.belief(for: beliefID)
        let beliefEvents = pendingEvents.filter { $0.beliefID == beliefID }
        let hasPendingEvent = beliefEvents.contains { !spokenEventIDs.contains($0.id) }
        let hasSpokenEvent = beliefEvents.contains { spokenEventIDs.contains($0.id) }

        let evaluation = evaluation ?? BeliefEvaluationResult(
            beliefID: beliefID,
            previousMaturity: stored.maturity,
            nextMaturity: stored.maturity,
            evidence: nil,
            confidence: 0,
            effectSize: 0,
            event: nil
        )

        let blockingReason = BeliefBlockingReasonRegistry.resolve(
            beliefID: beliefID,
            observations: observations,
            currentMaturity: stored.maturity,
            evaluation: evaluation,
            hasPendingEvent: hasPendingEvent,
            hasSpokenEvent: hasSpokenEvent
        )

        return BeliefRow(
            beliefID: beliefID,
            maturity: stored.maturity,
            lastTransition: formatLastTransition(stored),
            confidence: evaluation.confidence,
            effectSize: evaluation.effectSize,
            sampleSize: formatSampleSize(evaluation.evidence),
            evidenceWindow: formatEvidenceWindow(evaluation.evidence, beliefID: beliefID, observations: observations),
            hasPendingEvent: hasPendingEvent,
            hasSpokenEvent: hasSpokenEvent,
            lifecycleState: lifecycleState(for: stored.maturity),
            blockingReason: blockingReason,
            noEventReason: BeliefBlockingReasonRegistry.noEventReasonText(
                blockingReason: blockingReason,
                evaluation: evaluation,
                hasPendingEvent: hasPendingEvent,
                hasSpokenEvent: hasSpokenEvent
            )
        )
    }

    private static func formatLastTransition(_ belief: CoachBelief) -> String {
        guard belief.lastUpdated != .distantPast else {
            return "never"
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return "\(belief.maturity.rawValue) @ \(formatter.string(from: belief.lastUpdated))"
    }

    private static func formatSampleSize(_ evidence: BeliefEvidence?) -> String {
        guard let evidence else { return "n/a" }
        return "primary=\(evidence.primaryGroupSampleCount) comparison=\(evidence.comparisonGroupSampleCount)"
    }

    private static func formatEvidenceWindow(
        _ evidence: BeliefEvidence?,
        beliefID: CoachBeliefID,
        observations: [CoachDailyObservation]
    ) -> String {
        if let evidence {
            return "\(evidence.eligibleDayCount) eligible days"
        }
        return "\(eligibleObservationCount(for: beliefID, observations: observations)) signal days (insufficient)"
    }

    private static func lifecycleState(for maturity: CoachBeliefMaturity) -> String? {
        switch maturity {
        case .retired:
            return "retired"
        case .weakening:
            return "weakening (downgrade path)"
        case .watching, .emerging, .established:
            return nil
        }
    }

    // MARK: - Reflection

    private static func makeReflectionState(
        coachState: CoachState,
        nextUnspoken: UnderstandingEvent?,
        spokenEventIDs: Set<String>
    ) -> ReflectionState {
        guard let input = coachState.input else {
            return ReflectionState(
                pause: false,
                pauseReason: "coachInputUnavailable",
                blockedBy: "coachInputUnavailable",
                nextUnspokenEventID: nextUnspoken?.id,
                nextUnspokenBeliefID: nextUnspoken?.beliefID,
                reflectionOfferID: coachState.reflectionOffer?.id,
                reflectionOfferBeliefID: coachState.reflectionOffer?.beliefID,
                isReflectionOfferDisplayed: coachState.reflectionOffer.map { spokenEventIDs.contains($0.id) } ?? false,
                noReflectionReason: "Coach input unavailable — cannot resolve pause gate."
            )
        }

        let engineResult = CoachEngine.evaluate(input: input)
        let pause = ConversationPauseResolver.resolve(
            ConversationPauseResolver.Input(
                snapshot: input,
                context: engineResult.context,
                urgencyLevel: engineResult.todayInsight.urgencyLevel,
                safetyAlert: engineResult.todayInsight.safetyAlert,
                alertSeverity: engineResult.todayInsight.alertSeverity
            )
        )

        let offer = coachState.reflectionOffer
        let noReflectionReason = explainNoReflection(
            pause: pause,
            nextUnspoken: nextUnspoken,
            offer: offer
        )

        return ReflectionState(
            pause: pause.isPaused,
            pauseReason: pause.reason,
            blockedBy: pause.blockedBy?.rawValue,
            nextUnspokenEventID: nextUnspoken?.id,
            nextUnspokenBeliefID: nextUnspoken?.beliefID,
            reflectionOfferID: offer?.id,
            reflectionOfferBeliefID: offer?.beliefID,
            isReflectionOfferDisplayed: offer.map { spokenEventIDs.contains($0.id) } ?? false,
            noReflectionReason: noReflectionReason
        )
    }

    private static func explainNoReflection(
        pause: ConversationPauseResolution,
        nextUnspoken: UnderstandingEvent?,
        offer: ReflectionOffer?
    ) -> String? {
        if let offer {
            return nil
        }

        if !pause.isPaused {
            let blocker = pause.blockedBy?.rawValue ?? "unknown"
            return "Pause blocked by \(blocker)."
        }

        guard nextUnspoken != nil else {
            return "Pause active but no unspoken understanding events in queue."
        }

        return "Pause active with unspoken event, but ReflectionComposer returned nil."
    }

    private static func eligibleObservationCount(
        for beliefID: CoachBeliefID,
        observations: [CoachDailyObservation]
    ) -> Int {
        switch beliefID {
        case .sleepConsistencyRecovery, .sleepDurationRecovery, .lateBedtimeRecovery:
            return observations.filter(\.hasSleepSignal).filter(\.hasRecoverySignal).count
        case .heavyLoadRecoveryLag, .recoveryAfterRestDay, .consecutiveHardDaysFatigue:
            return observations.filter(\.hasTrainingAndRecoverySignal).count
        case .underfuelingRecovery:
            return observations
                .filter(\.hasPopulatedNutritionFieldsResolved)
                .filter(\.hasRecoverySignal)
                .filter { $0.calorieDeficit != nil }
                .count
        }
    }
}
