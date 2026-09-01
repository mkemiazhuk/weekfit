import Foundation

struct MorningAdjustmentDayHistoryCaptureContext: Sendable, Equatable {
    let now: Date
    let dayKey: String
    let recoveryBand: ProposalRecoveryBandToken
    let recoveryPercent: Int?
    let outdoorSuitability: OutdoorSuitability
    let weatherRiskToken: ProposalWeatherRiskToken
    let yesterdayHeavy: Bool
    let stackedLoad: ProposalStackedLoadToken
    let tomorrowDemand: CoachTomorrowDemand
    let todayOpen: [CoachPlannedActivitySnapshot]
}

enum MorningAdjustmentDayHistoryCapture {

    static func captureProposalReady(
        proposal: MorningPlanProposal,
        context: MorningAdjustmentDayHistoryCaptureContext
    ) {
        guard proposal.status == .proposalReady || proposal.status == .reviewing else { return }
        guard let strategy = proposal.strategy else { return }

        var record = baseRecord(
            proposal: proposal,
            context: context,
            strategy: strategy,
            hadMorningProposal: true
        )

        for change in proposal.changes where isMovementCreate(change) {
            guard let family = RecoveryMovementFamilyResolver.family(for: change),
                  family != .otherTraining else { continue }
            record.mergeOutcome(family) { outcome in
                outcome.offered = true
                outcome.defaultSelected = change.defaultSelected
                outcome.selectedAtSettle = change.isSelected
                outcome.origin = RecoveryMovementFamilyResolver.origin(for: change.candidateSource)
                    ?? .morningAdjustment
                outcome.durationMinutes = movementDurationMinutes(from: change)
                outcome.scheduledHour = scheduledHour(from: change, calendar: .current)
                outcome.provenanceChangeId = change.id
            }
        }

        MorningAdjustmentDayHistoryStore.upsert(record)
    }

    static func captureDismissed(
        proposal: MorningPlanProposal,
        context: MorningAdjustmentDayHistoryCaptureContext
    ) {
        // Card dismiss is NOT rejection — preserve OFFERED-only semantics.
        captureProposalReady(proposal: proposal, context: context)
    }

    static func captureApply(
        proposal: MorningPlanProposal,
        context: MorningAdjustmentDayHistoryCaptureContext,
        appliedOutcomes: [String: CoachApplyItemOutcome],
        provenance: [AppliedCoachAdjustment]
    ) {
        guard let strategy = proposal.strategy else { return }

        var record = MorningAdjustmentDayHistoryStore.record(for: context.dayKey)
            ?? baseRecord(
                proposal: proposal,
                context: context,
                strategy: strategy,
                hadMorningProposal: true
            )

        let provenanceByChangeId = Dictionary(uniqueKeysWithValues: provenance.map { ($0.changeId, $0) })

        for change in proposal.changes where isMovementCreate(change) {
            guard let family = RecoveryMovementFamilyResolver.family(for: change),
                  family != .otherTraining else { continue }

            record.mergeOutcome(family) { outcome in
                outcome.offered = true
                outcome.defaultSelected = change.defaultSelected
                outcome.selectedAtSettle = change.isSelected
                outcome.durationMinutes = movementDurationMinutes(from: change)
                outcome.scheduledHour = scheduledHour(from: change, calendar: .current)
                outcome.provenanceChangeId = change.id

                if change.isSelected {
                    let applyOutcome = appliedOutcomes[change.id]
                    if applyOutcome == .applied || applyOutcome == .skippedAlreadyMatched {
                        outcome.applied = true
                        outcome.origin = RecoveryMovementFamilyResolver.origin(for: change.candidateSource)
                            ?? .morningAdjustment
                        if let adjustment = provenanceByChangeId[change.id] {
                            outcome.provenanceActivityId = adjustment.activityId
                        }
                    }
                } else {
                    outcome.explicitlyRejected = true
                }
            }
        }

        record.recordedAt = context.now
        MorningAdjustmentDayHistoryStore.upsert(record)
    }

    static func makeContextFromProposal(
        proposal: MorningPlanProposal,
        todayActivities: [CoachPlannedActivitySnapshot],
        now: Date = Date()
    ) -> MorningAdjustmentDayHistoryCaptureContext {
        let observation = CoachObservationStore.observation(for: proposal.dayKey)
        let todayOpen = todayActivities.filter {
            !$0.isCompleted && !$0.isSkipped && CoachActivityClassifier.type(for: $0) != .none
        }
        if let existing = MorningAdjustmentDayHistoryStore.record(for: proposal.dayKey) {
            return MorningAdjustmentDayHistoryCaptureContext(
                now: now,
                dayKey: proposal.dayKey,
                recoveryBand: existing.recoveryBand,
                recoveryPercent: existing.recoveryPercent,
                outdoorSuitability: existing.outdoorSuitability,
                weatherRiskToken: existing.weatherRiskToken,
                yesterdayHeavy: existing.yesterdayHeavy,
                stackedLoad: existing.stackedLoad,
                tomorrowDemand: existing.tomorrowDemand,
                todayOpen: todayOpen
            )
        }
        return MorningAdjustmentDayHistoryCaptureContext(
            now: now,
            dayKey: proposal.dayKey,
            recoveryBand: proposal.fingerprint.recoveryBand,
            recoveryPercent: observation?.recoveryPercent,
            outdoorSuitability: .acceptable,
            weatherRiskToken: proposal.fingerprint.weatherRiskToken,
            yesterdayHeavy: proposal.fingerprint.yesterdayHeavy,
            stackedLoad: proposal.fingerprint.stackedLoad,
            tomorrowDemand: .none,
            todayOpen: todayOpen
        )
    }

    static func captureUserPlannedCompletion(
        snapshot: CoachPlannedActivitySnapshot,
        dayKey: String
    ) {
        let family = RecoveryMovementFamilyResolver.family(for: snapshot)
        guard family != .otherTraining else { return }
        guard snapshot.isCompleted || snapshot.isPartialCompletion else { return }

        if CoachAdjustmentProvenanceStore.adjustment(forActivityId: snapshot.id) != nil {
            return
        }

        var record = MorningAdjustmentDayHistoryStore.record(for: dayKey)
            ?? minimalRecord(for: dayKey, snapshot: snapshot)

        record.mergeOutcome(family) { outcome in
            outcome.origin = .userPlanned
            outcome.completed = snapshot.isCompleted
            outcome.partialCompletion = snapshot.isPartialCompletion
            outcome.completedDurationMinutes = snapshot.effectiveDurationMinutes
            outcome.scheduledHour = Calendar.current.component(.hour, from: snapshot.date)
            outcome.provenanceActivityId = snapshot.id
        }
        record.recordedAt = Date()
        MorningAdjustmentDayHistoryStore.upsert(record)
    }

    private static func minimalRecord(
        for dayKey: String,
        snapshot: CoachPlannedActivitySnapshot
    ) -> MorningAdjustmentDayRecord {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: dayKey) ?? snapshot.date
        let weekday = calendar.component(.weekday, from: date)
        let observation = CoachObservationStore.observation(for: dayKey)
        let band = observation.map {
            SimilarDayPlanMiner.recoveryBand(fromPercent: $0.recoveryPercent)
        } ?? .unavailable

        return MorningAdjustmentDayRecord(
            dayKey: dayKey,
            recordedAt: Date(),
            weekday: weekday,
            isWeekend: weekday == 1 || weekday == 7,
            proposalTimeBucket: ProposalTimeBucket.from(date: date, calendar: calendar),
            recoveryPercent: observation?.recoveryPercent,
            recoveryBand: band,
            strategy: .recover,
            outdoorSuitability: .acceptable,
            weatherRiskToken: .unavailable,
            yesterdayHeavy: false,
            previousDayLoad: PreviousDayLoadResolver.resolve(forDayKey: dayKey, calendar: calendar),
            stackedLoad: .unavailable,
            tomorrowDemand: .none,
            existingPlanSuitability: .none,
            hadMorningProposal: false
        )
    }

    static func makeContext(
        from evaluateContext: MorningProposalService.EvaluateContext,
        todayOpen: [CoachPlannedActivitySnapshot]
    ) -> MorningAdjustmentDayHistoryCaptureContext {
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: evaluateContext.now)
        let observation = CoachObservationStore.observation(for: dayKey)
        return MorningAdjustmentDayHistoryCaptureContext(
            now: evaluateContext.now,
            dayKey: dayKey,
            recoveryBand: ProposalInputFingerprintBuilder.recoveryBand(from: evaluateContext.readiness),
            recoveryPercent: observation?.recoveryPercent,
            outdoorSuitability: evaluateContext.outdoorSuitability,
            weatherRiskToken: evaluateContext.weatherRiskToken,
            yesterdayHeavy: evaluateContext.yesterdayHeavy,
            stackedLoad: evaluateContext.stackedLoad,
            tomorrowDemand: evaluateContext.tomorrowDemand,
            todayOpen: todayOpen
        )
    }

    // MARK: - Private

    private static func baseRecord(
        proposal: MorningPlanProposal,
        context: MorningAdjustmentDayHistoryCaptureContext,
        strategy: DailyStrategy,
        hadMorningProposal: Bool
    ) -> MorningAdjustmentDayRecord {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: context.now)
        let isWeekend = weekday == 1 || weekday == 7
        let planSuitability = ExistingPlanMovementSuitabilityClassifier.classify(
            todayOpen: context.todayOpen,
            strategy: strategy
        )

        return MorningAdjustmentDayRecord(
            dayKey: context.dayKey,
            recordedAt: context.now,
            weekday: weekday,
            isWeekend: isWeekend,
            proposalTimeBucket: ProposalTimeBucket.from(date: context.now, calendar: calendar),
            recoveryPercent: context.recoveryPercent,
            recoveryBand: context.recoveryBand,
            strategy: strategy,
            outdoorSuitability: context.outdoorSuitability,
            weatherRiskToken: context.weatherRiskToken,
            yesterdayHeavy: context.yesterdayHeavy,
            previousDayLoad: PreviousDayLoadResolver.resolve(forDayKey: context.dayKey, calendar: calendar),
            stackedLoad: context.stackedLoad,
            tomorrowDemand: context.tomorrowDemand,
            existingPlanSuitability: planSuitability,
            hadMorningProposal: hadMorningProposal
        )
    }

    private static func isMovementCreate(_ change: CoachProposedChange) -> Bool {
        switch change.kind {
        case .createRecoveryWalk, .createPlannedActivity:
            return true
        case .modifyDuration, .moveActivity, .skipActivity, .createMealFromLibrary, .guidanceOnly:
            return false
        }
    }

    private static func movementDurationMinutes(from change: CoachProposedChange) -> Int? {
        switch change.payload {
        case .createRecoveryWalk(let payload):
            return payload.durationMinutes
        case .createPlannedActivity(let payload):
            return payload.durationMinutes
        default:
            return nil
        }
    }

    private static func scheduledHour(from change: CoachProposedChange, calendar: Calendar) -> Int? {
        switch change.payload {
        case .createRecoveryWalk(let payload):
            return calendar.component(.hour, from: payload.proposedDate)
        case .createPlannedActivity(let payload):
            return calendar.component(.hour, from: payload.proposedDate)
        default:
            return nil
        }
    }
}
