import Foundation

/// Deterministic strategy selection for the morning proposal.
///
/// Decision table (first match wins):
/// 1. generationMode.closed → continueExistingPlan
/// 2. unavailable Recovery OR low context confidence without mutate → continueExistingPlan
/// 3. low Recovery → recover
/// 4. moderate Recovery + (yesterdayHeavy OR stacked elevated OR serious overload) → recover
/// 5. good Recovery + yesterdayHeavy → recover (post long hike / hard day; don't "stay steady")
/// 6. tomorrow hard/moderate → protectTomorrow
///    (protect mode with no serious opens still protects tomorrow rather than maintain)
/// 7. good Recovery + sleep + no fatigue + quiet tomorrow + mode allows adds
///    + observation-backed repeated serious success → train
/// 8. protect mode with coherent packed plan → continueExistingPlan
/// 9. moderate/good with no strong train/recover signal → maintain
/// 10. fallback → continueExistingPlan
enum DailyStrategyResolver {

    static func resolve(context: DailyContext) -> DailyStrategy {
        if context.generationMode == .closed {
            return .continueExistingPlan
        }

        if !context.recoveryAvailable || context.recoveryBand == .unavailable {
            return .continueExistingPlan
        }

        if context.contextFreshness == .low && !context.canMutate {
            return .continueExistingPlan
        }

        // 3–5 recover
        if context.recoveryBand == .low {
            return .recover
        }
        if context.recoveryBand == .moderate,
           context.yesterdayHeavy || context.stackedLoad.isElevated || seriousLoadInappropriate(context) {
            return .recover
        }
        // Even with good recovery, a heavy prior day should stay lighter —
        // habitual Saturday workouts after a 6h hike feel wrong.
        if context.recoveryBand == .good, context.yesterdayHeavy {
            return .recover
        }

        // 6 protectTomorrow — good Recovery must not auto-override a demanding tomorrow
        if context.tomorrowDemand == .hard || context.tomorrowDemand == .moderate {
            return .protectTomorrow
        }

        // 7 train
        if context.recoveryBand == .good,
           context.sleepPresence == .present,
           !context.yesterdayHeavy,
           !context.stackedLoad.isElevated,
           context.tomorrowDemand == .none || context.tomorrowDemand == .easy,
           context.generationMode == .compose || context.generationMode == .optimize,
           context.contextFreshness != .low,
           hasHighQualityTrainCandidate(context) {
            return .train
        }

        // 8 protect / packed day with no necessary mutation → continue
        if context.generationMode == .protect {
            return .continueExistingPlan
        }
        if context.contextFreshness == .low, context.todayOpen.count >= 2 {
            return .continueExistingPlan
        }

        // 9 maintain
        if context.recoveryBand == .moderate || context.recoveryBand == .good {
            return .maintain
        }

        return .continueExistingPlan
    }

    private static func seriousLoadInappropriate(_ context: DailyContext) -> Bool {
        let minutes = context.todaySeriousOpen.reduce(0) { $0 + $1.durationMinutes }
        return minutes >= 90 || context.todaySeriousOpen.count >= 2
    }

    private static func hasHighQualityTrainCandidate(_ context: DailyContext) -> Bool {
        let aggregates = HistoricalActivityAggregator.aggregate(
            templates: context.recentDayTemplates,
            todayWeekday: Calendar.current.component(.weekday, from: context.now)
        )
        return aggregates.contains {
            $0.completionCount >= 2
                && $0.observationBackedCount > 0
                && $0.skipCount <= $0.completionCount
                && CoachActivityClassifier.isSeriousTraining(
                    CoachPlannedActivitySnapshot(
                        id: $0.id,
                        date: context.now,
                        type: $0.activityType,
                        title: $0.title,
                        durationMinutes: $0.medianDurationMinutes,
                        icon: $0.icon,
                        imageName: $0.imageName,
                        isCompleted: false,
                        isSkipped: false,
                        source: "history"
                    )
                )
        }
    }
}
