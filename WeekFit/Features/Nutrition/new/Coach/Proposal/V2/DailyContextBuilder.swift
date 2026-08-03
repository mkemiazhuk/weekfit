import Foundation

enum DailyContextBuilder {

    /// Builds immutable DailyContext from the Phase 1.5 engine input bag.
    static func build(from input: MorningProposalEngineInput) -> DailyContext {
        let todayOpen = input.todayActivities.filter {
            !$0.isCompleted && !$0.isSkipped && CoachActivityClassifier.type(for: $0) != .none
        }
        let todaySerious = todayOpen.filter { CoachActivityClassifier.isSeriousTraining($0) }
        let hasMovement = todayOpen.contains {
            let family = CoachActivityClassifier.family(for: $0)
            let type = CoachActivityClassifier.type(for: $0)
            return family == .endurance || family == .recovery || type == .walk || type == .cycling || type == .running || type == .hiit
        }
        let hasCompletedOrPartial = input.todayActivities.contains {
            ($0.isCompleted || $0.isPartialCompletion || ($0.actualDurationMinutes ?? 0) > 0) && !$0.isSkipped
        }
        let totalDuration = todayOpen.reduce(0) { $0 + max(0, $1.durationMinutes) }

        let recoveryAvailable = input.recoveryBand != .unavailable
        let observationAvailable = input.recentDayTemplates.contains(where: \.observationAvailable)
        let freshness = contextFreshness(
            recoveryBand: input.recoveryBand,
            sleepPresence: input.sleepPresence,
            observationAvailable: input.recentDayTemplates.isEmpty ? nil : observationAvailable,
            walkRejectPenalty: input.walkRejectPenalty
        )

        let behavioral = ProposalBehavioralPreferences.load()

        return DailyContext(
            now: input.now,
            dayKey: input.dayKey,
            isMorningEligible: input.generationMode != .closed && !hasCompletedOrPartial,
            hasCompletedOrPartialToday: hasCompletedOrPartial,
            generationMode: input.generationMode,
            contextFreshness: freshness,
            recoveryBand: input.recoveryBand,
            recoveryPercent: nil,
            recoveryAvailable: recoveryAvailable,
            sleepPresence: input.sleepPresence,
            sleepHours: nil,
            yesterdayHeavy: input.yesterdayHeavy,
            stackedLoad: input.stackedLoad,
            tomorrowDemand: input.tomorrowDemand,
            scenarioKey: input.scenarioKey,
            todayActivities: input.todayActivities,
            tomorrowActivities: input.tomorrowActivities,
            todayOpen: todayOpen,
            todaySeriousOpen: todaySerious,
            hasExistingMovement: hasMovement,
            completedWalkToday: input.completedWalkToday,
            totalPlannedDurationMinutes: totalDuration,
            recentDayTemplates: input.recentDayTemplates,
            historicalObservationRevision: input.fingerprint.observationContextRevision,
            behavioralGeneration: input.fingerprint.behavioralGeneration,
            walkRejectPenalty: input.walkRejectPenalty,
            stronglyRejectsWalk: input.stronglyRejectsWalk,
            softDismissCount: behavioral.softDismissCount,
            softNegativePenalty: ProposalBehavioralPreferences.softNegativePenalty(from: behavioral),
            mealLibrary: input.mealLibrary,
            mealLibraryRevision: input.fingerprint.mealLibraryRevision,
            weatherRiskToken: input.weatherRiskToken,
            canMutate: input.canMutate && input.generationMode != .closed,
            fingerprint: input.fingerprint
        )
    }

    static func contextFreshness(
        recoveryBand: ProposalRecoveryBandToken,
        sleepPresence: ProposalSleepPresenceToken,
        observationAvailable: Bool?,
        walkRejectPenalty: Int
    ) -> ProposalContextConfidence {
        if recoveryBand == .unavailable || sleepPresence != .present {
            return .low
        }
        if walkRejectPenalty >= 8 {
            return .medium
        }
        if observationAvailable == false {
            return .medium
        }
        return .high
    }
}
