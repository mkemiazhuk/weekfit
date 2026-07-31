import Foundation

/// Evidence bag bridging service → v2 DailyContextBuilder.
struct MorningProposalEngineInput: Sendable, Equatable {
    let now: Date
    let dayKey: String
    let fingerprint: ProposalInputFingerprint
    let scenarioKey: CoachScenarioKey?
    let recoveryBand: ProposalRecoveryBandToken
    let sleepPresence: ProposalSleepPresenceToken
    let yesterdayHeavy: Bool
    let tomorrowDemand: CoachTomorrowDemand
    let stackedLoad: ProposalStackedLoadToken
    let generationMode: MorningProposalGenerationMode
    let todayActivities: [CoachPlannedActivitySnapshot]
    let tomorrowActivities: [CoachPlannedActivitySnapshot]
    let completedWalkToday: Bool
    let canMutate: Bool
    let recentDayTemplates: [SimilarDayTemplate]
    let mealLibrary: [ProposalMealCandidate]
    let walkRejectPenalty: Int
    let stronglyRejectsWalk: Bool
    var weatherRiskToken: ProposalWeatherRiskToken = .unavailable
}

/// Thin orchestrator over the deterministic v2 proposal stages.
enum MorningProposalEngine {

    static func generate(input: MorningProposalEngineInput) -> MorningPlanProposal {
        let context = DailyContextBuilder.build(from: input)

        #if DEBUG
        MorningProposalDebugTrace.lastMode = context.generationMode
        MorningProposalDebugTrace.lastConfidence = context.contextFreshness
        MorningProposalDebugTrace.lastNoProposalReason = nil
        MorningProposalDebugTrace.lastCandidateScores = []
        MorningProposalDebugTrace.lastStrategy = nil
        #endif

        if context.generationMode == .closed {
            #if DEBUG
            MorningProposalDebugTrace.lastNoProposalReason = "generation_mode_closed"
            MorningProposalDebugTrace.lastStrategy = .continueExistingPlan
            #endif
            return empty(
                context: context,
                status: .unavailable,
                strategy: .continueExistingPlan,
                error: "closed"
            )
        }

        let strategy = DailyStrategyResolver.resolve(context: context)
        #if DEBUG
        MorningProposalDebugTrace.lastStrategy = strategy
        #endif

        if strategy == .continueExistingPlan, context.contextFreshness == .low {
            #if DEBUG
            MorningProposalDebugTrace.lastNoProposalReason = "continue_existing_low_confidence"
            #endif
            // Still allow guidance candidates for low-confidence days, but assembler
            // suppresses overlay when there are no mutations.
            let guidance = GuidanceCandidateProvider.generate(context: context, strategy: strategy)
                + WeatherAdjustmentProvider.generate(context: context, strategy: strategy)
            let scored = guidance.compactMap { CandidateScorer.score($0, context: context, strategy: strategy) }
            let composed = PlanComposer.compose(scored: scored, context: context, strategy: strategy)
            let validated = PlanValidator.validate(composed: composed, context: context)
            return MorningProposalAssembler.assemble(validated: validated, context: context)
        }

        let rawCandidates = ProposalCandidateProviderHub.generate(context: context, strategy: strategy)
        let scored: [ScoredCandidate] = rawCandidates.compactMap {
            CandidateScorer.score($0, context: context, strategy: strategy)
        }
        #if DEBUG
        MorningProposalDebugTrace.lastCandidateScores = scored.map(\.breakdown)
        #endif

        let composed = PlanComposer.compose(scored: scored, context: context, strategy: strategy)
        let validated = PlanValidator.validate(composed: composed, context: context)
        let proposal = MorningProposalAssembler.assemble(validated: validated, context: context)

        #if DEBUG
        if proposal.status == .noChangesNeeded {
            MorningProposalDebugTrace.lastNoProposalReason = validated.abortReason ?? "no_changes_needed"
        }
        #endif

        return proposal
    }

    private static func empty(
        context: DailyContext,
        status: CoachProposalStatus,
        strategy: DailyStrategy,
        error: String?
    ) -> MorningPlanProposal {
        MorningPlanProposal(
            id: UUID().uuidString,
            dayKey: context.dayKey,
            generatedAt: context.now,
            status: status,
            fingerprint: context.fingerprint,
            changes: [],
            appliedAt: nil,
            dismissedAt: nil,
            lastErrorCode: error,
            schemaVersion: MorningPlanProposal.currentSchemaVersion,
            strategy: strategy,
            contextConfidence: context.contextFreshness,
            scorerVersion: MorningProposalAssembler.scorerVersion
        )
    }
}
