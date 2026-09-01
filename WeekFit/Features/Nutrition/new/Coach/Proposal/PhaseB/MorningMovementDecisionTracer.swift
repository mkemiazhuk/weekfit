import Foundation

#if DEBUG

enum MorningMovementDecisionTracer {

    struct PickState {
        let initialEligible: [RecoveryMovementProvider.LightOption]
        var ranked: [RecoveryMovementProvider.LightOption]
        let walkRejectFiltered: Set<RecoveryMovementProvider.LightOption>
        let weatherFiltered: Set<RecoveryMovementProvider.LightOption>
        let lowRecoveryFiltered: Set<RecoveryMovementProvider.LightOption>
        let cooloffFiltered: Set<RecoveryMovementProvider.LightOption>
        let rankedBeforeAffinity: [RecoveryMovementProvider.LightOption]
        let rankedAfterAffinity: [RecoveryMovementProvider.LightOption]
        let affinities: [RecoveryMovementFamilyAffinity]
        let similarDays: SimilarDayAffinityDiagnostics
        let preferHabitFamily: Bool
        let habitWinner: RecoveryMovementProvider.LightOption?
        let phaseAWinner: RecoveryMovementProvider.LightOption?
        let finalWinner: RecoveryMovementProvider.LightOption?
    }

    static func record(
        context: DailyContext,
        strategy: DailyStrategy,
        state: PickState
    ) {
        let affinityByFamily = Dictionary(uniqueKeysWithValues: state.affinities.map { ($0.family, $0) })
        let familyDiagByFamily = Dictionary(uniqueKeysWithValues: state.similarDays.families.map { ($0.family, $0) })

        let eligibleFamilies = state.initialEligible.map { RecoveryMovementFamilyResolver.family(for: $0) }
        let phaseABaseOrder = state.rankedBeforeAffinity.enumerated().reduce(into: [RecoveryMovementFamily: Int]()) {
            $0[RecoveryMovementFamilyResolver.family(for: $1.element)] = $1.offset + 1
        }

        let candidates = RecoveryMovementFamily.allCases
            .filter { $0 != .otherTraining }
            .map { family -> MorningMovementDecisionTrace.CandidateDiagnostic in
                let option = RecoveryMovementFamilyResolver.lightOption(for: family)
                let eligible = option.map { state.initialEligible.contains($0) } ?? false
                let affinity = affinityByFamily[family]
                let diag = familyDiagByFamily[family]
                var notes: [String] = []
                if let diag {
                    notes.append("completedSimilarDays=\(diag.completedSimilarDays)")
                    notes.append("rejectedSimilarDays=\(diag.rejectedSimilarDays)")
                    notes.append("offeredOnlySimilarDays=\(diag.offeredOnlySimilarDays)")
                }
                if context.outdoorSuitability == .adverse || context.outdoorSuitability == .unsafe,
                   family == .walk || family == .easyRun {
                    notes.append("weather=negative for outdoor family")
                }
                return MorningMovementDecisionTrace.CandidateDiagnostic(
                    family: family,
                    displayName: family.debugDisplayName,
                    eligible: eligible,
                    filteredByWalkReject: option.map { state.walkRejectFiltered.contains($0) } ?? false,
                    filteredByWeather: option.map { state.weatherFiltered.contains($0) } ?? false,
                    filteredByLowRecovery: option.map { state.lowRecoveryFiltered.contains($0) } ?? false,
                    filteredByCooloff: option.map { state.cooloffFiltered.contains($0) } ?? false,
                    similarDayBonus: diag?.appliedBonus ?? 0,
                    similarDayRawAffinity: affinity?.score ?? 0,
                    similarDaySampleCount: affinity?.sampleCount ?? 0,
                    similarDayConfidence: affinity?.confidence ?? .none,
                    habitBoosted: option.map { state.habitWinner == $0 } ?? false,
                    phaseABaseRank: phaseABaseOrder[family],
                    notes: notes
                )
            }

        let winnerFamily = state.finalWinner.map { RecoveryMovementFamilyResolver.family(for: $0) }
        let phaseAFamily = state.phaseAWinner.map { RecoveryMovementFamilyResolver.family(for: $0) }
        let phaseBFamily = state.finalWinner.map { RecoveryMovementFamilyResolver.family(for: $0) }
        let historyChanged = phaseAFamily != nil && phaseBFamily != nil && phaseAFamily != phaseBFamily

        let reason = winReason(
            winner: state.finalWinner,
            phaseAWinner: state.phaseAWinner,
            context: context,
            similarDays: state.similarDays,
            habitWinner: state.habitWinner,
            affinities: state.affinities
        )

        MorningProposalDebugTrace.lastMovementDecision = MorningMovementDecisionTrace(
            context: MorningMovementDecisionTrace.ContextSnapshot(
                dayKey: context.dayKey,
                recoveryPercent: context.recoveryPercent,
                recoveryBand: context.recoveryBand,
                strategy: strategy,
                outdoorSuitability: context.outdoorSuitability,
                weatherRiskToken: context.weatherRiskToken,
                yesterdayHeavy: context.yesterdayHeavy,
                existingPlanSuitability: context.existingPlanMovementSuitability,
                proposalTimeBucket: ProposalTimeBucket.from(date: context.now)
            ),
            eligibleFamilies: eligibleFamilies,
            candidates: candidates,
            similarDays: state.similarDays,
            winner: MorningMovementDecisionTrace.WinnerDiagnostic(
                family: winnerFamily ?? .mobility,
                displayName: winnerFamily?.debugDisplayName ?? "none",
                phaseAWinner: phaseAFamily,
                phaseBWinner: phaseBFamily,
                historyChangedWinner: historyChanged,
                reason: reason
            )
        )
    }

    private static func winReason(
        winner: RecoveryMovementProvider.LightOption?,
        phaseAWinner: RecoveryMovementProvider.LightOption?,
        context: DailyContext,
        similarDays: SimilarDayAffinityDiagnostics,
        habitWinner: RecoveryMovementProvider.LightOption?,
        affinities: [RecoveryMovementFamilyAffinity]
    ) -> String {
        guard let winner else { return "no eligible movement" }
        if similarDays.fallbackToPhaseA {
            if habitWinner == winner { return "Phase A fallback with habit boost" }
            if winner == .walk { return "Phase A walk preference" }
            return "Phase A rotation (history had no effect)"
        }
        if let phaseAWinner, phaseAWinner != winner {
            let family = RecoveryMovementFamilyResolver.family(for: winner)
            let bonus = SimilarDayAffinityScorer.bonus(for: family, affinities: affinities)
            return "Phase B shifted winner from \(phaseAWinner.rawValue) to \(winner.rawValue) (+\(bonus) similar-day affinity)"
        }
        if context.outdoorSuitability == .adverse || context.outdoorSuitability == .unsafe {
            return "adverse outdoor + strongest similar-day affinity"
        }
        if habitWinner == winner { return "habit boost within eligible set" }
        return "similar-day affinity + Phase A tie-break"
    }
}

#endif
