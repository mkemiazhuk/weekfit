import Foundation

/// Coarse morning stacked-load token from existing readiness signals only.
/// Prefer `.unavailable` over inventing false certainty (session-phase CoachStackedDayRisk is not morning-safe).
enum ProposalStackedLoadResolver {

    static func resolve(
        yesterdayHeavy: Bool,
        tomorrowDemand: CoachTomorrowDemand,
        recoveryBand: ProposalRecoveryBandToken,
        todaySeriousOpenCount: Int
    ) -> ProposalStackedLoadToken {
        // Clear elevated only when yesterday load + tomorrow demand + soft recovery + open serious work coincide.
        if yesterdayHeavy,
           (tomorrowDemand == .hard || tomorrowDemand == .moderate),
           recoveryBand == .low || recoveryBand == .moderate,
           todaySeriousOpenCount >= 1 {
            return .elevated
        }

        // Explicitly clear only when both flanks are quiet and recovery is known.
        if !yesterdayHeavy,
           tomorrowDemand == .none || tomorrowDemand == .easy,
           recoveryBand == .good || recoveryBand == .moderate {
            return .clear
        }

        return .unavailable
    }
}

/// Stable revision token for observation-backed similar-day inputs (no health raw values).
enum ProposalObservationContextRevision {

    static func make(from templates: [SimilarDayTemplate]) -> String {
        let parts = templates
            .map { template in
                let band = template.recoveryBand.rawValue
                let obs = template.observationAvailable ? "1" : "0"
                let sleep = template.sleepPresence.rawValue
                return "\(template.dayKey):\(obs):\(band):\(sleep)"
            }
            .sorted()
        guard !parts.isEmpty else { return "none" }
        return parts.joined(separator: "|")
    }
}
