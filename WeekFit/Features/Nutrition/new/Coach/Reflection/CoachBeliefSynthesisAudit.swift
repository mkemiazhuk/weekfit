import Foundation

/// Read-only synthesis of belief evaluation results for developer inspection.
/// Does not mutate beliefs, emit events, or affect Coach routing.
enum CoachBeliefSynthesisAudit {

    enum RecoveryDriverDomain: String, Equatable, Sendable, CaseIterable {
        case sleep
        case trainingLoad
        case nutrition
        case unknown
    }

    struct BeliefSignal: Equatable, Sendable {
        let beliefID: CoachBeliefID
        let maturity: CoachBeliefMaturity
        let confidence: Double
        let effectSize: Double
        let hasAnalyzableEvidence: Bool
    }

    struct PatternConflict: Equatable, Sendable {
        let first: CoachBeliefID
        let second: CoachBeliefID
        let reason: String
    }

    enum UnderstandingConfidenceLabel: String, Equatable, Sendable {
        case low
        case medium
        case high
    }

    struct DomainCoverageSnapshot: Equatable, Sendable {
        let sleep: Double
        let trainingLoad: Double
        let nutrition: Double
    }

    struct CoachUnderstandingConfidence: Equatable, Sendable {
        let understandingConfidenceScore: Double
        let understandingConfidenceLabel: UnderstandingConfidenceLabel
        let understandingCoverageByDomain: DomainCoverageSnapshot
        let diagnosticExplanation: String
    }

    struct Result: Equatable, Sendable {
        let dominantRecoveryDriver: RecoveryDriverDomain
        let strongestEstablishedPattern: CoachBeliefID?
        let strongestEmergingPattern: CoachBeliefID?
        let conflictingPatterns: [PatternConflict]
        let insufficientDomains: [RecoveryDriverDomain]
        let formsCoherentProfile: Bool
        let understandingConfidence: CoachUnderstandingConfidence
        let diagnostics: [String]
    }

    static func synthesize(signals: [BeliefSignal]) -> Result {
        let domainScores = scoreByDomain(signals)
        let dominant = resolveDominantDriver(domainScores: domainScores, signals: signals)
        let strongestEstablished = strongestPattern(in: signals, maturity: .established)
        let strongestEmerging = strongestPattern(in: signals, maturity: .emerging)
        let conflicts = detectConflicts(in: signals)
        let insufficientDomains = insufficientDomains(in: signals)
        let formsCoherentProfile = resolvesCoherentProfile(
            signals: signals,
            dominant: dominant,
            conflicts: conflicts
        )
        let diagnostics = makeDiagnostics(
            dominant: dominant,
            domainScores: domainScores,
            strongestEstablished: strongestEstablished,
            strongestEmerging: strongestEmerging,
            conflicts: conflicts,
            insufficientDomains: insufficientDomains,
            formsCoherentProfile: formsCoherentProfile,
            signals: signals
        )
        let understandingConfidence = makeUnderstandingConfidence(
            signals: signals,
            conflicts: conflicts,
            insufficientDomains: insufficientDomains
        )

        return Result(
            dominantRecoveryDriver: dominant,
            strongestEstablishedPattern: strongestEstablished,
            strongestEmergingPattern: strongestEmerging,
            conflictingPatterns: conflicts,
            insufficientDomains: insufficientDomains,
            formsCoherentProfile: formsCoherentProfile,
            understandingConfidence: understandingConfidence,
            diagnostics: diagnostics
        )
    }

    static func synthesize(evaluationResults: [BeliefEvaluationResult]) -> Result {
        let signals = evaluationResults.map { result in
            BeliefSignal(
                beliefID: result.beliefID,
                maturity: CoachUnderstandingStore.belief(for: result.beliefID).maturity,
                confidence: result.confidence,
                effectSize: result.effectSize,
                hasAnalyzableEvidence: result.evidence != nil
            )
        }
        return synthesize(signals: signals)
    }

    // MARK: - Domain mapping

    static func recoveryDomain(for beliefID: CoachBeliefID) -> RecoveryDriverDomain {
        switch beliefID {
        case .sleepConsistencyRecovery, .sleepDurationRecovery, .lateBedtimeRecovery:
            return .sleep
        case .heavyLoadRecoveryLag, .recoveryAfterRestDay, .consecutiveHardDaysFatigue:
            return .trainingLoad
        case .underfuelingRecovery:
            return .nutrition
        }
    }

    static func beliefs(in domain: RecoveryDriverDomain) -> [CoachBeliefID] {
        CoachBeliefRegistry.registeredBeliefIDs.filter { recoveryDomain(for: $0) == domain }
    }

    // MARK: - Scoring

    private static func signalStrength(for signal: BeliefSignal) -> Double {
        guard signal.hasAnalyzableEvidence || signal.maturity >= .emerging else { return 0 }

        let maturityWeight: Double = switch signal.maturity {
        case .established: 1.0
        case .emerging: 0.7
        case .weakening: 0.4
        case .watching: 0.15
        case .retired: 0
        }

        return maturityWeight * signal.confidence * abs(signal.effectSize)
    }

    private static func scoreByDomain(_ signals: [BeliefSignal]) -> [RecoveryDriverDomain: Double] {
        var scores: [RecoveryDriverDomain: Double] = [
            .sleep: 0,
            .trainingLoad: 0,
            .nutrition: 0,
        ]

        for signal in signals {
            let beliefDomain = recoveryDomain(for: signal.beliefID)
            scores[beliefDomain, default: 0] += signalStrength(for: signal)
        }

        return scores
    }

    private static func resolveDominantDriver(
        domainScores: [RecoveryDriverDomain: Double],
        signals: [BeliefSignal]
    ) -> RecoveryDriverDomain {
        let establishedDomains = Set(
            signals
                .filter { $0.maturity == .established && $0.hasAnalyzableEvidence }
                .map { recoveryDomain(for: $0.beliefID) }
        )

        if establishedDomains.count == 1, let only = establishedDomains.first {
            return only
        }

        let ranked = domainScores
            .filter { $0.key != .unknown }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.rawValue < rhs.key.rawValue
                }
                return lhs.value > rhs.value
            }

        guard let top = ranked.first, top.value >= 3.0 else {
            return .unknown
        }

        if ranked.count > 1, ranked[1].value >= top.value * 0.85 {
            return .unknown
        }

        return top.key
    }

    private static func strongestPattern(
        in signals: [BeliefSignal],
        maturity: CoachBeliefMaturity
    ) -> CoachBeliefID? {
        signals
            .filter { $0.maturity == maturity && ($0.hasAnalyzableEvidence || maturity >= .emerging) }
            .max { signalStrength(for: $0) < signalStrength(for: $1) }?
            .beliefID
    }

    private static func detectConflicts(in signals: [BeliefSignal]) -> [PatternConflict] {
        let candidates = signals.filter {
            $0.maturity >= .emerging
                && $0.hasAnalyzableEvidence
                && abs($0.effectSize) >= 4.0
        }

        guard candidates.count >= 2 else { return [] }

        var conflicts: [PatternConflict] = []

        for index in candidates.indices {
            for otherIndex in candidates.index(after: index)..<candidates.endIndex {
                let first = candidates[index]
                let second = candidates[otherIndex]

                let oppositeSign = (first.effectSize > 0) != (second.effectSize > 0)
                guard oppositeSign else { continue }

                conflicts.append(
                    PatternConflict(
                        first: first.beliefID,
                        second: second.beliefID,
                        reason: "Opposite recovery deltas (\(formatEffect(first.effectSize)) vs \(formatEffect(second.effectSize)))."
                    )
                )
            }
        }

        return conflicts
    }

    private static func insufficientDomains(in signals: [BeliefSignal]) -> [RecoveryDriverDomain] {
        RecoveryDriverDomain.allCases
            .filter { $0 != .unknown }
            .filter { domain in
                let domainSignals = signals.filter { recoveryDomain(for: $0.beliefID) == domain }
                guard !domainSignals.isEmpty else { return true }

                let hasConfirmed = domainSignals.contains {
                    $0.maturity >= .emerging && $0.hasAnalyzableEvidence
                }
                return !hasConfirmed
            }
    }

    private static func resolvesCoherentProfile(
        signals: [BeliefSignal],
        dominant: RecoveryDriverDomain,
        conflicts: [PatternConflict]
    ) -> Bool {
        guard conflicts.isEmpty, dominant != .unknown else { return false }

        let active = signals.filter { $0.maturity >= .emerging && $0.hasAnalyzableEvidence }
        let established = active.filter { $0.maturity == .established }

        guard !established.isEmpty else { return false }

        let activeInDominant = active.filter { recoveryDomain(for: $0.beliefID) == dominant }
        return activeInDominant.count >= 2 || established.count >= 2
    }

    // MARK: - Understanding confidence

    private static func makeUnderstandingConfidence(
        signals: [BeliefSignal],
        conflicts: [PatternConflict],
        insufficientDomains: [RecoveryDriverDomain]
    ) -> CoachUnderstandingConfidence {
        let active = signals.filter { $0.maturity >= .emerging && $0.hasAnalyzableEvidence }
        let established = active.filter { $0.maturity == .established }
        let emerging = active.filter { $0.maturity == .emerging }

        let establishedContribution = min(1.0, Double(established.count) / 3.0)
            * averageConfidence(established)
        let emergingContribution = min(0.5, Double(emerging.count) / 4.0)
            * averageConfidence(emerging)
            * 0.5
        let maturityScore = min(1.0, establishedContribution + emergingContribution)

        let coverageByDomain = makeDomainCoverageSnapshot(signals: signals)
        let coverageScore = (coverageByDomain.sleep + coverageByDomain.trainingLoad + coverageByDomain.nutrition) / 3.0

        var score = (maturityScore * 0.55) + (coverageScore * 0.45)
        if !conflicts.isEmpty {
            score *= 1.0 - min(0.35, Double(conflicts.count) * 0.15)
        }
        score = min(max(score, 0), 1)

        let label = confidenceLabel(for: score)
        let explanation = confidenceExplanation(
            score: score,
            label: label,
            establishedCount: established.count,
            emergingCount: emerging.count,
            coverageByDomain: coverageByDomain,
            conflicts: conflicts,
            insufficientDomains: insufficientDomains
        )

        return CoachUnderstandingConfidence(
            understandingConfidenceScore: score,
            understandingConfidenceLabel: label,
            understandingCoverageByDomain: coverageByDomain,
            diagnosticExplanation: explanation
        )
    }

    private static func makeDomainCoverageSnapshot(signals: [BeliefSignal]) -> DomainCoverageSnapshot {
        DomainCoverageSnapshot(
            sleep: domainCoverageScore(for: .sleep, signals: signals),
            trainingLoad: domainCoverageScore(for: .trainingLoad, signals: signals),
            nutrition: domainCoverageScore(for: .nutrition, signals: signals)
        )
    }

    private static func domainCoverageScore(
        for domain: RecoveryDriverDomain,
        signals: [BeliefSignal]
    ) -> Double {
        let domainSignals = signals.filter { recoveryDomain(for: $0.beliefID) == domain }
        guard !domainSignals.isEmpty else { return 0 }

        let confirmed = domainSignals.filter { $0.maturity >= .emerging && $0.hasAnalyzableEvidence }
        guard !confirmed.isEmpty else { return 0 }

        let bestMaturity = confirmed.map(\.maturity).max() ?? .watching
        let bestConfidence = confirmed.map(\.confidence).max() ?? 0

        switch bestMaturity {
        case .established:
            return min(1.0, 0.7 + (bestConfidence * 0.3))
        case .emerging:
            return min(0.75, 0.35 + (bestConfidence * 0.25))
        case .weakening:
            return min(0.45, 0.2 + (bestConfidence * 0.15))
        case .watching, .retired:
            return min(0.2, bestConfidence * 0.15)
        }
    }

    private static func averageConfidence(_ signals: [BeliefSignal]) -> Double {
        guard !signals.isEmpty else { return 0 }
        return signals.map(\.confidence).reduce(0, +) / Double(signals.count)
    }

    private static func confidenceLabel(for score: Double) -> UnderstandingConfidenceLabel {
        switch score {
        case ..<0.40:
            return .low
        case ..<0.70:
            return .medium
        default:
            return .high
        }
    }

    private static func confidenceExplanation(
        score: Double,
        label: UnderstandingConfidenceLabel,
        establishedCount: Int,
        emergingCount: Int,
        coverageByDomain: DomainCoverageSnapshot,
        conflicts: [PatternConflict],
        insufficientDomains: [RecoveryDriverDomain]
    ) -> String {
        var parts: [String] = []

        if establishedCount == 0, emergingCount == 0 {
            parts.append("No established or emerging beliefs yet.")
        } else {
            parts.append("\(establishedCount) established and \(emergingCount) emerging belief(s) contribute to maturity.")
        }

        let coveredDomains = [
            coverageByDomain.sleep >= 0.35 ? "sleep" : nil,
            coverageByDomain.trainingLoad >= 0.35 ? "training" : nil,
            coverageByDomain.nutrition >= 0.35 ? "nutrition" : nil,
        ].compactMap { $0 }

        if coveredDomains.isEmpty {
            parts.append("Domain coverage is minimal across sleep, training, and nutrition.")
        } else {
            parts.append("Coverage is present in \(coveredDomains.joined(separator: " and ")).")
        }

        if insufficientDomains.contains(.nutrition), !insufficientDomains.isEmpty {
            parts.append("Nutrition remains uncovered and lowers overall coverage.")
        }

        if !conflicts.isEmpty {
            parts.append("Conflicting patterns reduced confidence.")
        }

        parts.append("Overall \(label.rawValue) confidence (\(Int((score * 100).rounded()))%).")
        return parts.joined(separator: " ")
    }

    // MARK: - Diagnostics

    private static func makeDiagnostics(
        dominant: RecoveryDriverDomain,
        domainScores: [RecoveryDriverDomain: Double],
        strongestEstablished: CoachBeliefID?,
        strongestEmerging: CoachBeliefID?,
        conflicts: [PatternConflict],
        insufficientDomains: [RecoveryDriverDomain],
        formsCoherentProfile: Bool,
        signals: [BeliefSignal]
    ) -> [String] {
        var lines: [String] = []

        lines.append(dominantDriverLine(dominant: dominant, signals: signals))

        if let strongestEstablished {
            lines.append(
                "\(displayName(for: strongestEstablished)) is the strongest established pattern (\(formatEffect(signal(for: strongestEstablished, in: signals)?.effectSize ?? 0)) recovery delta)."
            )
        }

        if let strongestEmerging {
            lines.append(
                "\(displayName(for: strongestEmerging)) is the strongest emerging pattern (\(formatEffect(signal(for: strongestEmerging, in: signals)?.effectSize ?? 0)) recovery delta)."
            )
        }

        for conflict in conflicts {
            lines.append(
                "Conflicting patterns: \(displayName(for: conflict.first)) vs \(displayName(for: conflict.second)) — \(conflict.reason)"
            )
        }

        for domain in insufficientDomains.sorted(by: { $0.rawValue < $1.rawValue }) {
            lines.append(insufficientDomainLine(domain: domain, signals: signals))
        }

        if formsCoherentProfile {
            lines.append("Beliefs form a coherent athlete profile around \(domainLabel(dominant).lowercased()).")
        } else if signals.allSatisfy({ $0.maturity == .watching }) {
            lines.append("No coherent profile yet — all beliefs remain in watching state.")
        } else if !conflicts.isEmpty {
            lines.append("No coherent profile yet — established patterns conflict.")
        } else {
            lines.append("No coherent profile yet — beliefs remain isolated.")
        }

        return lines
    }

    private static func dominantDriverLine(
        dominant: RecoveryDriverDomain,
        signals: [BeliefSignal]
    ) -> String {
        switch dominant {
        case .sleep:
            return "Sleep appears to be the strongest confirmed recovery driver."
        case .trainingLoad:
            return "Training load appears to be the strongest confirmed recovery driver."
        case .nutrition:
            return "Nutrition appears to be the strongest confirmed recovery driver."
        case .unknown:
            if signals.contains(where: { $0.maturity >= .emerging && recoveryDomain(for: $0.beliefID) == .sleep }) {
                return "Sleep signals are emerging but no domain is confirmed as the recovery driver yet."
            }
            if signals.allSatisfy({ $0.maturity == .watching }) {
                return "Recovery driver unknown — all beliefs are still watching."
            }
            return "Recovery driver unknown — no domain has a confirmed pattern yet."
        }
    }

    private static func insufficientDomainLine(
        domain: RecoveryDriverDomain,
        signals: [BeliefSignal]
    ) -> String {
        let domainSignals = signals.filter { recoveryDomain(for: $0.beliefID) == domain }
        let allWatching = domainSignals.allSatisfy { $0.maturity == .watching }

        switch domain {
        case .sleep:
            return allWatching
                ? "Sleep patterns are still watching; not enough confirmed sleep-recovery evidence."
                : "Sleep has insufficient confirmed signal."
        case .trainingLoad:
            return allWatching
                ? "Training-load patterns are still watching; not enough hard training evidence."
                : "Training load has insufficient confirmed signal."
        case .nutrition:
            return "Nutrition has insufficient confirmed signal."
        case .unknown:
            return "Unknown domain has insufficient signal."
        }
    }

    private static func signal(for beliefID: CoachBeliefID, in signals: [BeliefSignal]) -> BeliefSignal? {
        signals.first { $0.beliefID == beliefID }
    }

    private static func displayName(for beliefID: CoachBeliefID) -> String {
        switch beliefID {
        case .sleepConsistencyRecovery:
            return "Sleep consistency"
        case .sleepDurationRecovery:
            return "Sleep duration"
        case .lateBedtimeRecovery:
            return "Late bedtime"
        case .heavyLoadRecoveryLag:
            return "Heavy load recovery lag"
        case .recoveryAfterRestDay:
            return "Recovery after rest day"
        case .consecutiveHardDaysFatigue:
            return "Consecutive hard days"
        case .underfuelingRecovery:
            return "Underfueling"
        }
    }

    private static func domainLabel(_ domain: RecoveryDriverDomain) -> String {
        switch domain {
        case .sleep: return "Sleep"
        case .trainingLoad: return "Training load"
        case .nutrition: return "Nutrition"
        case .unknown: return "Unknown"
        }
    }

    private static func formatEffect(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
