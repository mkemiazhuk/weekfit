import Foundation

enum HistoricalActivityProvider {

    static func generate(context: DailyContext, strategy: DailyStrategy) -> [ProposalCandidate] {
        guard context.canMutate else { return [] }
        guard strategy == .train || strategy == .maintain || strategy == .recover else { return [] }
        guard context.generationMode == .compose || context.generationMode == .optimize else { return [] }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: context.now)
        let aggregates = HistoricalActivityAggregator.aggregate(
            templates: context.recentDayTemplates,
            todayWeekday: weekday,
            calendar: calendar
        )

        let existingTitles = Set(context.todayOpen.map { $0.title.lowercased() })
        var result: [ProposalCandidate] = []

        for aggregate in aggregates {
            if existingTitles.contains(aggregate.title.lowercased()) { continue }
            // One-off occurrences must not dominate.
            guard aggregate.occurrenceCount >= 1 else { continue }
            let snapshot = makeSnapshot(from: aggregate, on: context.now)
            let isSerious = CoachActivityClassifier.isSeriousTraining(snapshot)
            let isElevatedLoad = CoachActivityClassifier.isElevatedTrainingLoad(snapshot)

            // Low recovery / recover days: never invent bike, run, HIIT, or strength.
            if context.recoveryBand == .low || strategy == .recover || strategy == .protectTomorrow,
               isElevatedLoad {
                continue
            }
            if strategy == .maintain, isSerious {
                continue
            }
            if strategy == .train, !isSerious {
                // Prefer serious for train; still allow light supporting only after a serious pick at compose.
                continue
            }
            if (strategy == .recover || strategy == .maintain),
               CoachActivityClassifier.type(for: snapshot) == .walk,
               context.hasExistingMovement || context.completedWalkToday {
                continue
            }

            let activityType = CoachActivityClassifier.type(for: snapshot)
            let isLightRecoveryHabit = HabitualLightRecoveryDetector.isLightRecoveryHabit(
                aggregate,
                on: context.now
            )

            let completionRate = Double(aggregate.completionCount) / Double(max(aggregate.occurrenceCount, 1))
            let confidence = min(0.95, 0.35
                + completionRate * 0.35
                + (aggregate.completionCount >= 2 ? 0.15 : 0)
                + (aggregate.observationBackedCount > 0 ? 0.1 : -0.1)
                + (aggregate.weekdayMatchCount > 0 ? 0.08 : 0)
                + (isLightRecoveryHabit ? 0.15 : 0))

            guard confidence >= 0.4 || isLightRecoveryHabit else { continue }
            // Sparse / never completed → skip inventing workouts,
            // but keep weekday light-recovery habits (yoga / stretch).
            if aggregate.completionCount == 0, !isLightRecoveryHabit { continue }

            // On recover days, skip inventing historical Walk — RecoveryMovementProvider owns that.
            if strategy == .recover || strategy == .maintain,
               activityType == .walk {
                continue
            }

            guard let proposedDate = remapHabitualTime(aggregate: aggregate, context: context, calendar: calendar) else {
                continue
            }
            let fit: CandidateFit = {
                if aggregate.completionCount >= 2 && aggregate.observationBackedCount > 0 { return .strong }
                if aggregate.completionCount >= 1 { return .moderate }
                return .weak
            }()

            let defaultEligibility: DefaultSelectionEligibility = {
                // Only high-evidence weekday habits on train days start selected.
                if strategy == .train,
                   isSerious,
                   aggregate.completionCount >= 2,
                   aggregate.observationBackedCount > 0,
                   aggregate.weekdayMatchCount > 0 {
                    return .eligible
                }
                return .ineligible
            }()

            result.append(
                ProposalCandidate(
                    id: "hist-\(aggregate.signature)",
                    source: .historicalActivity,
                    kind: .createPlannedActivity,
                    payload: .createPlannedActivity(
                        CreatePlannedActivityPayload(
                            proposedDate: proposedDate,
                            durationMinutes: aggregate.medianDurationMinutes,
                            title: aggregate.title,
                            activityType: aggregate.activityType,
                            icon: aggregate.icon,
                            imageName: aggregate.imageName,
                            colorRed: aggregate.colorRed,
                            colorGreen: aggregate.colorGreen,
                            colorBlue: aggregate.colorBlue,
                            sourceTemplateDayKey: nil
                        )
                    ),
                    compatibleStrategies: isSerious ? [.train] : [.maintain, .recover, .train],
                    physiologicalFit: fit,
                    confidence: max(0.2, confidence),
                    burden: isSerious ? .high : .medium,
                    reasonCodes: [.similarDaySupport],
                    conflicts: aggregate.skipCount > aggregate.completionCount ? [.excessiveLoad] : [],
                    defaultSelectionEligibility: defaultEligibility,
                    sortTime: proposedDate,
                    evidenceScenarioKey: context.scenarioKey?.rawValue,
                    identityKey: "hist:\(aggregate.signature)"
                )
            )
        }

        return Array(result.prefix(6))
    }

    private static func makeSnapshot(
        from aggregate: HistoricalActivityAggregate,
        on date: Date
    ) -> CoachPlannedActivitySnapshot {
        CoachPlannedActivitySnapshot(
            id: aggregate.id,
            date: date,
            type: aggregate.activityType,
            title: aggregate.title,
            durationMinutes: aggregate.medianDurationMinutes,
            icon: aggregate.icon,
            imageName: aggregate.imageName,
            isCompleted: false,
            isSkipped: false,
            source: "history"
        )
    }

    /// Exact habitual clock for today. Returns nil if that slot already passed —
    /// never invent a different clock (e.g. 12:30) over the person's habit.
    private static func remapHabitualTime(
        aggregate: HistoricalActivityAggregate,
        context: DailyContext,
        calendar: Calendar
    ) -> Date? {
        var comps = calendar.dateComponents([.year, .month, .day], from: context.now)
        comps.hour = aggregate.habitualHour
        comps.minute = aggregate.habitualMinute
        comps.second = 0
        guard let proposed = calendar.date(from: comps) else { return nil }
        guard proposed >= context.now.addingTimeInterval(15 * 60) else { return nil }
        return proposed
    }
}
