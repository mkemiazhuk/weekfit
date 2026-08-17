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
        let yesterdaySignatures = yesterdayActivitySignatures(context: context, calendar: calendar)
        var result: [ProposalCandidate] = []

        for aggregate in aggregates {
            if existingTitles.contains(aggregate.title.lowercased()) { continue }
            // Don't photocopy yesterday's exact session.
            if yesterdaySignatures.contains(aggregate.signature) { continue }
            // One-off occurrences must not dominate.
            guard aggregate.occurrenceCount >= 1 else { continue }
            let rawSnapshot = makeSnapshot(
                from: aggregate,
                on: context.now,
                durationMinutes: aggregate.medianDurationMinutes
            )
            let isSerious = CoachActivityClassifier.isSeriousTraining(rawSnapshot)
            let isElevatedLoad = CoachActivityClassifier.isElevatedTrainingLoad(rawSnapshot)
            let shapedDuration = ProposalInventedSessionPolicy.durationMinutes(
                raw: aggregate.medianDurationMinutes,
                recoveryBand: context.recoveryBand,
                strategy: strategy
            )

            // Low recovery / recover / post-heavy days: never invent bike, run, HIIT, or strength.
            if context.recoveryBand == .low
                || strategy == .recover
                || strategy == .protectTomorrow
                || context.yesterdayHeavy,
               isElevatedLoad {
                continue
            }
            if strategy == .maintain, isSerious {
                continue
            }
            // Don't invent a hard session from a single one-off.
            if (isElevatedLoad || isSerious),
               aggregate.completionCount < 2,
               aggregate.weekdayMatchCount < 2 {
                continue
            }
            if strategy == .train, !isSerious {
                // Prefer serious for train; still allow light supporting only after a serious pick at compose.
                continue
            }
            if (strategy == .recover || strategy == .maintain),
               CoachActivityClassifier.type(for: rawSnapshot) == .walk,
               context.hasExistingMovement || context.completedWalkToday {
                continue
            }

            let activityType = CoachActivityClassifier.type(for: rawSnapshot)
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
                            durationMinutes: shapedDuration,
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
        on date: Date,
        durationMinutes: Int
    ) -> CoachPlannedActivitySnapshot {
        CoachPlannedActivitySnapshot(
            id: aggregate.id,
            date: date,
            type: aggregate.activityType,
            title: aggregate.title,
            durationMinutes: durationMinutes,
            icon: aggregate.icon,
            imageName: aggregate.imageName,
            isCompleted: false,
            isSkipped: false,
            source: "history"
        )
    }

    /// Habitual clock rounded to :00 / :30. Returns nil if that slot already passed —
    /// never invent a different clock (e.g. 12:30) over the person's habit.
    private static func remapHabitualTime(
        aggregate: HistoricalActivityAggregate,
        context: DailyContext,
        calendar: Calendar
    ) -> Date? {
        let rounded = ProposalInventedSessionPolicy.roundedHalfHour(
            hour: aggregate.habitualHour,
            minute: aggregate.habitualMinute
        )
        var comps = calendar.dateComponents([.year, .month, .day], from: context.now)
        comps.hour = rounded.hour
        comps.minute = rounded.minute
        comps.second = 0
        guard var proposed = calendar.date(from: comps) else { return nil }
        let earliest = context.now.addingTimeInterval(15 * 60)
        if proposed < earliest {
            proposed = proposed.addingTimeInterval(30 * 60)
        }
        guard proposed >= earliest else { return nil }
        // Stay close to the habit — don't slide more than 90 minutes.
        let habitualMinutes = aggregate.habitualHour * 60 + aggregate.habitualMinute
        let proposedMinutes = calendar.component(.hour, from: proposed) * 60
            + calendar.component(.minute, from: proposed)
        guard abs(proposedMinutes - habitualMinutes) <= 90 else { return nil }
        return proposed
    }

    private static func yesterdayActivitySignatures(
        context: DailyContext,
        calendar: Calendar
    ) -> Set<String> {
        guard let yesterday = calendar.date(
            byAdding: .day,
            value: -1,
            to: calendar.startOfDay(for: context.now)
        ) else {
            return []
        }
        let key = ProposalInputFingerprintBuilder.dayKey(for: yesterday, calendar: calendar)
        let activities = context.recentDayTemplates.first { $0.dayKey == key }?.activities ?? []
        return Set(
            activities
                .filter { !$0.isSkipped && !CoachCanonicalDayState.isNutritionLog($0) }
                .map { HistoricalActivityAggregator.makeSignature(title: $0.title, type: $0.type) }
        )
    }
}
