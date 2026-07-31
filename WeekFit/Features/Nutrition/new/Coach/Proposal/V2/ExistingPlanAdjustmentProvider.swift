import Foundation

enum ProposalCandidateProviderHub {

    static func generate(
        context: DailyContext,
        strategy: DailyStrategy
    ) -> [ProposalCandidate] {
        guard strategy != .continueExistingPlan else {
            var guidance = GuidanceCandidateProvider.generate(context: context, strategy: strategy)
            guidance.append(contentsOf: WeatherAdjustmentProvider.generate(context: context, strategy: strategy))
            return guidance
        }

        var candidates: [ProposalCandidate] = []
        candidates.append(contentsOf: ExistingPlanAdjustmentProvider.generate(context: context, strategy: strategy))
        candidates.append(contentsOf: WeatherAdjustmentProvider.generate(context: context, strategy: strategy))
        candidates.append(contentsOf: HistoricalActivityProvider.generate(context: context, strategy: strategy))
        candidates.append(contentsOf: RecoveryMovementProvider.generate(context: context, strategy: strategy))
        candidates.append(contentsOf: MealLibraryProvider.generate(context: context, strategy: strategy))
        candidates.append(contentsOf: GuidanceCandidateProvider.generate(context: context, strategy: strategy))
        return candidates
    }
}

enum ExistingPlanAdjustmentProvider {

    private static let minShortenOriginalMinutes = 45
    private static let minShortenDeltaMinutes = 15

    static func generate(context: DailyContext, strategy: DailyStrategy) -> [ProposalCandidate] {
        guard context.canMutate else { return [] }
        guard strategy == .recover || strategy == .protectTomorrow else { return [] }
        guard !context.todaySeriousOpen.isEmpty else { return [] }

        var result: [ProposalCandidate] = []
        let serious = context.todaySeriousOpen.sorted { $0.durationMinutes > $1.durationMinutes }

        if let candidate = serious.first(where: { $0.durationMinutes >= minShortenOriginalMinutes }),
           let proposed = proposedShortenedDuration(original: candidate.durationMinutes) {
            result.append(
                ProposalCandidate(
                    id: "adj-shorten-\(candidate.id)",
                    source: .existingPlanAdjustment,
                    kind: .modifyDuration,
                    payload: .modifyDuration(
                        ModifyDurationPayload(
                            activityId: candidate.id,
                            originalDurationMinutes: candidate.durationMinutes,
                            proposedDurationMinutes: proposed,
                            activityTitle: candidate.title
                        )
                    ),
                    compatibleStrategies: [.recover, .protectTomorrow],
                    physiologicalFit: context.recoveryBand == .low ? .strong : .moderate,
                    confidence: context.contextFreshness == .high ? 0.85 : 0.65,
                    burden: .low,
                    reasonCodes: [shortenReason(context: context, strategy: strategy)],
                    conflicts: [],
                    defaultSelectionEligibility: .eligible,
                    sortTime: candidate.date,
                    evidenceScenarioKey: context.scenarioKey?.rawValue,
                    identityKey: "shorten:\(candidate.id)"
                )
            )
        }

        if shouldMove(context: context, strategy: strategy),
           let moveCandidate = secondaryMoveCandidate(serious: serious, excluding: result.compactMap(\.firstActivityId)),
           let proposedDate = tomorrowSlot(for: moveCandidate, context: context) {
            result.append(
                ProposalCandidate(
                    id: "adj-move-\(moveCandidate.id)",
                    source: .existingPlanAdjustment,
                    kind: .moveActivity,
                    payload: .moveActivity(
                        MoveActivityPayload(
                            activityId: moveCandidate.id,
                            originalDate: moveCandidate.date,
                            proposedDate: proposedDate,
                            activityTitle: moveCandidate.title
                        )
                    ),
                    compatibleStrategies: [.recover, .protectTomorrow],
                    physiologicalFit: .moderate,
                    confidence: 0.7,
                    burden: .medium,
                    reasonCodes: [.tomorrowDemandProtection],
                    conflicts: [],
                    defaultSelectionEligibility: .eligible,
                    sortTime: moveCandidate.date,
                    evidenceScenarioKey: context.scenarioKey?.rawValue,
                    identityKey: "move:\(moveCandidate.id)"
                )
            )
        }

        if shouldSkip(context: context, strategy: strategy),
           let skipCandidate = serious.last {
            let strong = context.recoveryBand == .low
                && (context.yesterdayHeavy || context.stackedLoad.isElevated || context.tomorrowDemand == .hard)
            result.append(
                ProposalCandidate(
                    id: "adj-skip-\(skipCandidate.id)",
                    source: .existingPlanAdjustment,
                    kind: .skipActivity,
                    payload: .skipActivity(
                        SkipActivityPayload(
                            activityId: skipCandidate.id,
                            originalDate: skipCandidate.date,
                            activityTitle: skipCandidate.title
                        )
                    ),
                    compatibleStrategies: [.recover, .protectTomorrow],
                    physiologicalFit: strong ? .strong : .weak,
                    confidence: strong ? 0.75 : 0.45,
                    burden: .high,
                    reasonCodes: [skipReason(context: context)],
                    conflicts: strong ? [] : [.excessiveLoad],
                    defaultSelectionEligibility: strong ? .eligible : .ineligible,
                    sortTime: skipCandidate.date,
                    evidenceScenarioKey: context.scenarioKey?.rawValue,
                    identityKey: "skip:\(skipCandidate.id)"
                )
            )
        }

        return result
    }

    private static func shortenReason(
        context: DailyContext,
        strategy: DailyStrategy
    ) -> CoachProposalReasonCode {
        if strategy == .protectTomorrow || context.tomorrowDemand == .hard || context.tomorrowDemand == .moderate {
            return .tomorrowDemandProtection
        }
        if context.stackedLoad.isElevated {
            return .stackedDayRisk
        }
        if context.yesterdayHeavy {
            return .heavyYesterdayProtection
        }
        return .lowRecoveryLoadProtection
    }

    private static func skipReason(context: DailyContext) -> CoachProposalReasonCode {
        if context.tomorrowDemand == .hard {
            return .tomorrowDemandProtection
        }
        if context.stackedLoad.isElevated {
            return .stackedDayRisk
        }
        if context.yesterdayHeavy {
            return .heavyYesterdayProtection
        }
        return .lowRecoveryLoadProtection
    }

    private static func proposedShortenedDuration(original: Int) -> Int? {
        let byPercent = Int((Double(original) * 0.75).rounded())
        let byFloor = original - minShortenDeltaMinutes
        let proposed = min(byPercent, byFloor)
        let clamped = max(15, proposed)
        guard clamped <= original - minShortenDeltaMinutes else { return nil }
        return clamped
    }

    private static func shouldMove(context: DailyContext, strategy: DailyStrategy) -> Bool {
        guard strategy == .recover || strategy == .protectTomorrow else { return false }
        guard context.todaySeriousOpen.count >= 2 else { return false }
        // Don't pile more onto an already hard tomorrow.
        guard context.tomorrowDemand != .hard else { return false }
        return true
    }

    private static func shouldSkip(context: DailyContext, strategy: DailyStrategy) -> Bool {
        guard strategy == .recover else { return false }
        guard context.recoveryBand == .low else { return false }
        return context.yesterdayHeavy || context.stackedLoad.isElevated || context.tomorrowDemand == .hard
    }

    private static func secondaryMoveCandidate(
        serious: [CoachPlannedActivitySnapshot],
        excluding: [String]
    ) -> CoachPlannedActivitySnapshot? {
        let sorted = serious.sorted { $0.date < $1.date }
        return sorted.dropFirst().first { !excluding.contains($0.id) } ?? sorted.last { !excluding.contains($0.id) }
    }

    private static func tomorrowSlot(
        for activity: CoachPlannedActivitySnapshot,
        context: DailyContext
    ) -> Date? {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: context.now)) else {
            return nil
        }
        let time = calendar.dateComponents([.hour, .minute], from: activity.date)
        var comps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = time.hour ?? 10
        comps.minute = time.minute ?? 0
        guard var proposed = calendar.date(from: comps) else { return nil }

        for _ in 0..<6 {
            if !hasConflict(proposed: proposed, duration: activity.durationMinutes, in: context.tomorrowActivities) {
                return proposed
            }
            proposed = proposed.addingTimeInterval(20 * 60)
        }
        return nil
    }

    private static func hasConflict(
        proposed: Date,
        duration: Int,
        in activities: [CoachPlannedActivitySnapshot]
    ) -> Bool {
        let proposedEnd = proposed.addingTimeInterval(TimeInterval(duration * 60))
        for activity in activities where !activity.isSkipped {
            let start = activity.date
            let end = start.addingTimeInterval(TimeInterval(max(activity.durationMinutes, 1) * 60))
            if proposed < end && proposedEnd > start { return true }
            if abs(proposed.timeIntervalSince(start)) < 30 * 60 { return true }
        }
        return false
    }
}

private extension ProposalCandidate {
    var firstActivityId: String? {
        switch payload {
        case .modifyDuration(let p): return p.activityId
        case .moveActivity(let p): return p.activityId
        case .skipActivity(let p): return p.activityId
        default: return nil
        }
    }
}
