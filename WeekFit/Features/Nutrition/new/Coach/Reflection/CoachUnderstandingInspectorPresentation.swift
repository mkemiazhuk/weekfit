#if DEBUG
import Foundation

/// Read-only presentation model for the Coach Understanding Inspector.
enum CoachUnderstandingInspectorPresentation {

    enum DomainUnderstandingStatus: String, Equatable, Sendable {
        case missingData = "missing data"
        case insufficientVariation = "insufficient variation"
        case noStableSignalYet = "no stable signal yet"
        case emergingSignal = "emerging signal"
        case establishedPattern = "established pattern"
    }

    struct DomainSummary: Identifiable, Equatable, Sendable {
        let domain: CoachBeliefSynthesisAudit.RecoveryDriverDomain
        let title: String
        let headline: String
        let status: DomainUnderstandingStatus
        let maturitySummary: String
        let confidenceSummary: String
        let establishedBeliefs: [String]
        let emergingBeliefs: [String]
        let missingKnowledge: [String]
        let coveragePercent: Int

        var id: String { domain.rawValue }
    }

    struct ExecutiveSummary: Equatable, Sendable {
        let domainHeadlines: [String]
        let confidencePercent: Int
        let confidenceLabel: String
        let dominantDriver: String
        let coherentProfile: Bool
        let strongestEstablished: String?
        let strongestEmerging: String?
        let observationCount: Int
        let beliefCount: Int
        let capturedAt: Date
        let conflictSummaries: [String]
    }

    private static let domainOrder: [CoachBeliefSynthesisAudit.RecoveryDriverDomain] = [
        .sleep,
        .trainingLoad,
        .nutrition,
    ]

    static func executiveSummary(from snapshot: CoachBeliefDebugInspector.Snapshot) -> ExecutiveSummary {
        let synthesis = snapshot.understandingSummary
        let confidence = synthesis.understandingConfidence

        return ExecutiveSummary(
            domainHeadlines: domainSummaries(from: snapshot).map(\.headline),
            confidencePercent: Int((confidence.understandingConfidenceScore * 100).rounded()),
            confidenceLabel: confidence.understandingConfidenceLabel.rawValue,
            dominantDriver: formattedDominantDriver(synthesis.dominantRecoveryDriver),
            coherentProfile: synthesis.formsCoherentProfile,
            strongestEstablished: synthesis.strongestEstablishedPattern.map(beliefDisplayName(for:)),
            strongestEmerging: synthesis.strongestEmergingPattern.map(beliefDisplayName(for:)),
            observationCount: snapshot.observationCount,
            beliefCount: snapshot.beliefs.count,
            capturedAt: snapshot.capturedAt,
            conflictSummaries: synthesis.conflictingPatterns.map {
                "\(beliefDisplayName(for: $0.first)) vs \(beliefDisplayName(for: $0.second))"
            }
        )
    }

    static func domainSummaries(from snapshot: CoachBeliefDebugInspector.Snapshot) -> [DomainSummary] {
        let coverage = snapshot.understandingSummary.understandingConfidence.understandingCoverageByDomain

        return domainOrder.map { domain in
            let beliefs = beliefs(in: domain, from: snapshot.beliefs)
            let status = domainStatus(for: beliefs)
            let coverageValue = coverageValue(for: domain, coverage: coverage)

            return DomainSummary(
                domain: domain,
                title: domainTitle(domain),
                headline: domainHeadline(domain: domain, status: status, beliefs: beliefs),
                status: status,
                maturitySummary: maturitySummary(for: beliefs),
                confidenceSummary: confidenceSummary(for: beliefs),
                establishedBeliefs: beliefNames(in: beliefs, maturity: .established),
                emergingBeliefs: beliefNames(in: beliefs, maturity: .emerging),
                missingKnowledge: missingKnowledge(for: domain, beliefs: beliefs, snapshot: snapshot),
                coveragePercent: Int((coverageValue * 100).rounded())
            )
        }
    }

    static func beliefs(
        in domain: CoachBeliefSynthesisAudit.RecoveryDriverDomain,
        from snapshot: CoachBeliefDebugInspector.Snapshot
    ) -> [CoachBeliefDebugInspector.BeliefRow] {
        beliefs(in: domain, from: snapshot.beliefs)
    }

    // MARK: - Domain helpers

    private static func beliefs(
        in domain: CoachBeliefSynthesisAudit.RecoveryDriverDomain,
        from rows: [CoachBeliefDebugInspector.BeliefRow]
    ) -> [CoachBeliefDebugInspector.BeliefRow] {
        rows.filter { CoachBeliefSynthesisAudit.recoveryDomain(for: $0.beliefID) == domain }
    }

    private static func domainStatus(
        for beliefs: [CoachBeliefDebugInspector.BeliefRow]
    ) -> DomainUnderstandingStatus {
        if beliefs.contains(where: { $0.maturity == .established }) {
            return .establishedPattern
        }
        if beliefs.contains(where: { $0.maturity == .emerging }) {
            return .emergingSignal
        }

        let reasons = beliefs.compactMap(\.blockingReason)
        if reasons.isEmpty {
            return .missingData
        }

        if reasons.allSatisfy({
            switch $0 {
            case .insufficientObservations, .missingRequiredFields:
                return true
            default:
                return false
            }
        }) {
            return .missingData
        }

        if reasons.contains(where: {
            if case .insufficientGroupSamples = $0 { return true }
            return false
        }) {
            return .insufficientVariation
        }

        if reasons.contains(where: {
            switch $0 {
            case .weakEffect, .uniformLowBaseline, .inverseOrConflictingEffect:
                return true
            default:
                return false
            }
        }) {
            return .noStableSignalYet
        }

        return .missingData
    }

    private static func domainHeadline(
        domain: CoachBeliefSynthesisAudit.RecoveryDriverDomain,
        status: DomainUnderstandingStatus,
        beliefs: [CoachBeliefDebugInspector.BeliefRow]
    ) -> String {
        switch status {
        case .establishedPattern:
            if let established = beliefs.first(where: { $0.maturity == .established }) {
                return "Coach has established that \(beliefDisplayName(for: established.beliefID).lowercased()) is linked with recovery."
            }
            return "Coach understands \(domainTitle(domain).lowercased()) well."
        case .emergingSignal:
            return "\(domainTitle(domain)) understanding is still emerging."
        case .missingData:
            switch domain {
            case .nutrition:
                return "Coach needs more trusted nutrition/recovery days before it can evaluate underfueling."
            case .trainingLoad:
                return "Coach needs more training and recovery observations in this area."
            case .sleep:
                return "Coach needs more sleep and recovery observations in this area."
            case .unknown:
                return "Coach lacks observations in this area."
            }
        case .insufficientVariation:
            return "Coach has observations in \(domainTitle(domain).lowercased()), but needs more varied examples to compare."
        case .noStableSignalYet:
            switch domain {
            case .trainingLoad:
                return "Coach has enough training observations, but has not found a stable training-related recovery pattern yet."
            case .sleep:
                return "Coach has enough sleep observations, but has not found a stable sleep-related recovery pattern yet."
            case .nutrition:
                return "Coach has enough nutrition observations, but has not found a stable underfueling-recovery pattern yet."
            case .unknown:
                return "Coach has enough observations, but has not found a stable pattern yet."
            }
        }
    }

    private static func maturitySummary(for beliefs: [CoachBeliefDebugInspector.BeliefRow]) -> String {
        let established = beliefs.filter { $0.maturity == .established }.count
        let emerging = beliefs.filter { $0.maturity == .emerging }.count
        let watching = beliefs.filter { $0.maturity == .watching }.count
        let other = beliefs.count - established - emerging - watching

        var parts = [
            "\(established) established",
            "\(emerging) emerging",
            "\(watching) watching",
        ]
        if other > 0 {
            parts.append("\(other) other")
        }
        return parts.joined(separator: ", ")
    }

    private static func confidenceSummary(for beliefs: [CoachBeliefDebugInspector.BeliefRow]) -> String {
        let active = beliefs.filter { $0.maturity >= .emerging || $0.confidence > 0 }
        guard !active.isEmpty else { return "No confirmed confidence yet" }

        let average = active.map(\.confidence).reduce(0, +) / Double(active.count)
        return String(format: "Average confidence %.0f%% across active beliefs", average * 100)
    }

    private static func beliefNames(
        in beliefs: [CoachBeliefDebugInspector.BeliefRow],
        maturity: CoachBeliefMaturity
    ) -> [String] {
        beliefs
            .filter { $0.maturity == maturity }
            .map { beliefDisplayName(for: $0.beliefID) }
    }

    private static func missingKnowledge(
        for domain: CoachBeliefSynthesisAudit.RecoveryDriverDomain,
        beliefs: [CoachBeliefDebugInspector.BeliefRow],
        snapshot: CoachBeliefDebugInspector.Snapshot
    ) -> [String] {
        var gaps: [String] = []

        for belief in beliefs where belief.maturity != .established {
            let prefix = beliefDisplayName(for: belief.beliefID)
            if let blockingReason = belief.blockingReason {
                gaps.append("\(prefix): \(blockingReason.debugDescription)")
            } else if !belief.noEventReason.isEmpty {
                gaps.append("\(prefix): \(belief.noEventReason)")
            }
        }

        if domain == .nutrition {
            let coverage = snapshot.nutritionCoverage
            if coverage.populatedCount == 0 {
                gaps.append("No nutrition observations populated yet.")
            } else if coverage.missingCount > 0 {
                gaps.append("\(coverage.missingCount) day(s) missing nutrition fields.")
            }
        }

        if gaps.isEmpty {
            gaps.append("No major gaps — domain has confirmed signal.")
        }

        return gaps
    }

    private static func coverageValue(
        for domain: CoachBeliefSynthesisAudit.RecoveryDriverDomain,
        coverage: CoachBeliefSynthesisAudit.DomainCoverageSnapshot
    ) -> Double {
        switch domain {
        case .sleep: return coverage.sleep
        case .trainingLoad: return coverage.trainingLoad
        case .nutrition: return coverage.nutrition
        case .unknown: return 0
        }
    }

    private static func domainTitle(_ domain: CoachBeliefSynthesisAudit.RecoveryDriverDomain) -> String {
        switch domain {
        case .sleep: return "Sleep"
        case .trainingLoad: return "Training"
        case .nutrition: return "Nutrition"
        case .unknown: return "Unknown"
        }
    }

    private static func formattedDominantDriver(
        _ driver: CoachBeliefSynthesisAudit.RecoveryDriverDomain
    ) -> String {
        switch driver {
        case .sleep: return "Sleep"
        case .trainingLoad: return "Training load"
        case .nutrition: return "Nutrition"
        case .unknown: return "Unknown"
        }
    }

    private static func beliefDisplayName(for beliefID: CoachBeliefID) -> String {
        switch beliefID {
        case .sleepConsistencyRecovery: return "Sleep consistency"
        case .sleepDurationRecovery: return "Sleep duration"
        case .lateBedtimeRecovery: return "Late bedtime"
        case .heavyLoadRecoveryLag: return "Heavy load recovery lag"
        case .recoveryAfterRestDay: return "Recovery after rest day"
        case .consecutiveHardDaysFatigue: return "Consecutive hard days"
        case .underfuelingRecovery: return "Underfueling"
        }
    }
}
#endif
