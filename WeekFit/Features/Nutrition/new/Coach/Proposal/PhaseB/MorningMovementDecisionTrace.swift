import Foundation

#if DEBUG

struct MorningMovementDecisionTrace: Sendable, Equatable {
    struct ContextSnapshot: Sendable, Equatable {
        let dayKey: String
        let recoveryPercent: Int?
        let recoveryBand: ProposalRecoveryBandToken
        let strategy: DailyStrategy
        let outdoorSuitability: OutdoorSuitability
        let weatherRiskToken: ProposalWeatherRiskToken
        let yesterdayHeavy: Bool
        let existingPlanSuitability: ExistingPlanMovementSuitability
        let proposalTimeBucket: ProposalTimeBucket
    }

    struct CandidateDiagnostic: Sendable, Equatable {
        let family: RecoveryMovementFamily
        let displayName: String
        let eligible: Bool
        let filteredByWalkReject: Bool
        let filteredByWeather: Bool
        let filteredByLowRecovery: Bool
        let filteredByCooloff: Bool
        let similarDayBonus: Int
        let similarDayRawAffinity: Double
        let similarDaySampleCount: Int
        let similarDayConfidence: SimilarDayAffinityConfidence
        let habitBoosted: Bool
        let phaseABaseRank: Int?
        let notes: [String]
    }

    struct WinnerDiagnostic: Sendable, Equatable {
        let family: RecoveryMovementFamily
        let displayName: String
        let phaseAWinner: RecoveryMovementFamily?
        let phaseBWinner: RecoveryMovementFamily?
        let historyChangedWinner: Bool
        let reason: String
    }

    let context: ContextSnapshot
    let eligibleFamilies: [RecoveryMovementFamily]
    let candidates: [CandidateDiagnostic]
    let similarDays: SimilarDayAffinityDiagnostics
    let winner: WinnerDiagnostic

    func formattedSummary() -> String {
        var lines: [String] = []
        lines.append("Morning Movement Decision")
        lines.append("")
        lines.append("Context")
        lines.append("- dayKey: \(context.dayKey)")
        if let percent = context.recoveryPercent {
            lines.append("- recovery: \(percent) / \(context.recoveryBand.rawValue)")
        } else {
            lines.append("- recovery: unavailable / \(context.recoveryBand.rawValue)")
        }
        lines.append("- strategy: \(context.strategy.rawValue)")
        lines.append("- outdoor: \(context.outdoorSuitability.rawValue)")
        lines.append("- weatherRisk: \(context.weatherRiskToken.rawValue)")
        lines.append("- yesterdayHeavy: \(context.yesterdayHeavy)")
        lines.append("- existingPlan: \(context.existingPlanSuitability.rawValue)")
        lines.append("- timeBucket: \(context.proposalTimeBucket.rawValue)")
        lines.append("")
        lines.append("Eligible")
        for family in eligibleFamilies {
            lines.append("- \(family.debugDisplayName)")
        }
        lines.append("")
        lines.append("SimilarDays")
        lines.append("- recordsScanned: \(similarDays.recordsScanned)")
        lines.append("- passingThreshold: \(similarDays.recordsPassingThreshold)")
        lines.append("- \(similarDays.summaryLine)")
        if !similarDays.topMatchingDays.isEmpty {
            lines.append("- topMatches:")
            for match in similarDays.topMatchingDays.prefix(5) {
                lines.append("  · \(match.dayKey) score=\(match.similarityScore) recency=\(String(format: "%.2f", match.recencyWeight)) signals=[\(match.familySignals.joined(separator: ", "))]")
            }
        }
        lines.append("")
        lines.append("Candidates")
        for candidate in candidates {
            lines.append("")
            lines.append(candidate.displayName)
            lines.append("- eligible: \(candidate.eligible)")
            if candidate.filteredByWalkReject { lines.append("- walkReject: filtered") }
            if candidate.filteredByWeather { lines.append("- weather: filtered") }
            if candidate.filteredByLowRecovery { lines.append("- lowRecovery: filtered") }
            if candidate.filteredByCooloff { lines.append("- cooloff: filtered") }
            lines.append("- similarDays: confidence=\(candidate.similarDayConfidence.rawValue) raw=\(String(format: "%.1f", candidate.similarDayRawAffinity)) bonus=\(candidate.similarDayBonus >= 0 ? "+\(candidate.similarDayBonus)" : "\(candidate.similarDayBonus)") samples=\(candidate.similarDaySampleCount)")
            if candidate.habitBoosted { lines.append("- habit: boosted") }
            if let rank = candidate.phaseABaseRank { lines.append("- phaseABaseRank: \(rank)") }
            for note in candidate.notes { lines.append("- \(note)") }
        }
        lines.append("")
        lines.append("Winner")
        lines.append("- \(winner.displayName)")
        if let phaseA = winner.phaseAWinner {
            lines.append("- phaseAWinner: \(phaseA.debugDisplayName)")
        }
        if let phaseB = winner.phaseBWinner {
            lines.append("- phaseBWinner: \(phaseB.debugDisplayName)")
        }
        if winner.historyChangedWinner {
            lines.append("- historyChangedWinner: true")
        } else if similarDays.fallbackToPhaseA {
            lines.append("- historyChangedWinner: false (Phase A fallback)")
        }
        lines.append("- reason: \(winner.reason)")
        return lines.joined(separator: "\n")
    }
}

#endif
