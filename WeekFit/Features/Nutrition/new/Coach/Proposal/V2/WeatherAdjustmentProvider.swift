import Foundation

/// Weather-aware adjustments for outdoor sessions (move earlier / shorten + guidance).
enum WeatherAdjustmentProvider {

    private static let minShortenOriginalMinutes = 45
    private static let minShortenDeltaMinutes = 15

    static func generate(context: DailyContext, strategy: DailyStrategy) -> [ProposalCandidate] {
        guard strategy != .continueExistingPlan else {
            return guidanceOnly(context: context)
        }
        guard context.weatherRiskToken.isAdverse else { return [] }

        let outdoorOpen = context.todayOpen
            .filter { ProposalOutdoorClassifier.isOutdoorLikely($0) }
            .sorted { $0.date < $1.date }

        var result: [ProposalCandidate] = []

        if context.canMutate,
           context.generationMode != .protect,
           let target = outdoorOpen.first {
            switch context.weatherRiskToken {
            case .precip, .storm, .wind:
                if let earlier = earlierSameDaySlot(for: target, context: context) {
                    result.append(moveEarlierCandidate(activity: target, proposed: earlier, context: context))
                } else if let shortened = proposedShortenedDuration(original: target.durationMinutes),
                          target.durationMinutes >= minShortenOriginalMinutes {
                    result.append(shortenCandidate(activity: target, proposed: shortened, context: context, heat: false))
                }
            case .heat:
                if let shortened = proposedShortenedDuration(original: target.durationMinutes),
                   target.durationMinutes >= minShortenOriginalMinutes {
                    result.append(shortenCandidate(activity: target, proposed: shortened, context: context, heat: true))
                }
            case .cold, .calm, .unavailable:
                break
            }
        }

        result.append(contentsOf: guidanceOnly(context: context))
        return result
    }

    private static func guidanceOnly(context: DailyContext) -> [ProposalCandidate] {
        guard let code = guidanceCode(for: context.weatherRiskToken) else { return [] }
        let reason: CoachProposalReasonCode = context.weatherRiskToken == .heat
            ? .weatherHeatLoad
            : .weatherOutdoorConflict
        return [
            GuidanceCandidateProvider.make(
                code: code,
                reason: reason,
                at: context.now.addingTimeInterval(90),
                context: context
            )
        ]
    }

    private static func guidanceCode(for risk: ProposalWeatherRiskToken) -> CoachGuidanceCode? {
        switch risk {
        case .precip, .storm:
            return .preferIndoorOrEarlier
        case .heat:
            return .easeOutdoorHeat
        case .wind:
            return .shelteredRoutesWind
        case .cold:
            return .warmUpInCold
        case .calm, .unavailable:
            return nil
        }
    }

    private static func moveEarlierCandidate(
        activity: CoachPlannedActivitySnapshot,
        proposed: Date,
        context: DailyContext
    ) -> ProposalCandidate {
        ProposalCandidate(
            id: "weather-move-\(activity.id)",
            source: .existingPlanAdjustment,
            kind: .moveActivity,
            payload: .moveActivity(
                MoveActivityPayload(
                    activityId: activity.id,
                    originalDate: activity.date,
                    proposedDate: proposed,
                    activityTitle: activity.title
                )
            ),
            compatibleStrategies: [.recover, .maintain, .train, .protectTomorrow],
            physiologicalFit: .strong,
            confidence: 0.82,
            burden: .medium,
            reasonCodes: [.weatherOutdoorConflict],
            conflicts: [],
            defaultSelectionEligibility: .eligible,
            sortTime: activity.date,
            evidenceScenarioKey: context.scenarioKey?.rawValue,
            identityKey: "weather-move:\(activity.id)"
        )
    }

    private static func shortenCandidate(
        activity: CoachPlannedActivitySnapshot,
        proposed: Int,
        context: DailyContext,
        heat: Bool
    ) -> ProposalCandidate {
        ProposalCandidate(
            id: "weather-shorten-\(activity.id)",
            source: .existingPlanAdjustment,
            kind: .modifyDuration,
            payload: .modifyDuration(
                ModifyDurationPayload(
                    activityId: activity.id,
                    originalDurationMinutes: activity.durationMinutes,
                    proposedDurationMinutes: proposed,
                    activityTitle: activity.title
                )
            ),
            compatibleStrategies: [.recover, .maintain, .train, .protectTomorrow],
            physiologicalFit: .strong,
            confidence: 0.8,
            burden: .low,
            reasonCodes: [heat ? .weatherHeatLoad : .weatherOutdoorConflict],
            conflicts: [],
            defaultSelectionEligibility: .eligible,
            sortTime: activity.date,
            evidenceScenarioKey: context.scenarioKey?.rawValue,
            identityKey: "weather-shorten:\(activity.id)"
        )
    }

    private static func proposedShortenedDuration(original: Int) -> Int? {
        let byPercent = Int((Double(original) * 0.75).rounded())
        let byFloor = original - minShortenDeltaMinutes
        let proposed = min(byPercent, byFloor)
        let clamped = max(15, proposed)
        guard clamped <= original - minShortenDeltaMinutes else { return nil }
        return clamped
    }

    /// Move afternoon outdoor work into a morning window when weather turns.
    private static func earlierSameDaySlot(
        for activity: CoachPlannedActivitySnapshot,
        context: DailyContext
    ) -> Date? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: activity.date)
        guard hour >= 12 else { return nil }

        var comps = calendar.dateComponents([.year, .month, .day], from: activity.date)
        comps.hour = 9
        comps.minute = 0
        guard var proposed = calendar.date(from: comps), proposed > context.now else { return nil }

        for _ in 0..<5 {
            if !hasConflict(
                proposed: proposed,
                duration: activity.durationMinutes,
                excludingId: activity.id,
                in: context.todayActivities
            ) {
                return proposed
            }
            proposed = proposed.addingTimeInterval(20 * 60)
        }
        return nil
    }

    private static func hasConflict(
        proposed: Date,
        duration: Int,
        excludingId: String,
        in activities: [CoachPlannedActivitySnapshot]
    ) -> Bool {
        let proposedEnd = proposed.addingTimeInterval(TimeInterval(duration * 60))
        for activity in activities where activity.id != excludingId && !activity.isSkipped {
            let start = activity.date
            let end = start.addingTimeInterval(TimeInterval(max(activity.durationMinutes, 1) * 60))
            if proposed < end && proposedEnd > start { return true }
            if abs(proposed.timeIntervalSince(start)) < 30 * 60 { return true }
        }
        return false
    }
}
