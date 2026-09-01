import Foundation

/// Normalized similar-day diagnostics for DEBUG tooling. No raw Health data.
struct SimilarDayMatchDiagnostic: Sendable, Equatable {
    let dayKey: String
    let similarityScore: Int
    let recencyWeight: Double
    let strategy: DailyStrategy
    let recoveryBand: ProposalRecoveryBandToken
    let outdoorSuitability: OutdoorSuitability
    let familySignals: [String]
}

struct FamilyAffinityDiagnostic: Sendable, Equatable {
    let family: RecoveryMovementFamily
    let sampleCount: Int
    let rawAffinity: Double
    let confidence: SimilarDayAffinityConfidence
    let appliedBonus: Int
    let completedSimilarDays: Int
    let rejectedSimilarDays: Int
    let offeredOnlySimilarDays: Int
}

struct SimilarDayAffinityDiagnostics: Sendable, Equatable {
    let recordsScanned: Int
    let recordsPassingThreshold: Int
    let overallConfidence: SimilarDayAffinityConfidence
    let fallbackToPhaseA: Bool
    let topMatchingDays: [SimilarDayMatchDiagnostic]
    let families: [FamilyAffinityDiagnostic]

    var summaryLine: String {
        if fallbackToPhaseA {
            return "SimilarDays: confidence=\(overallConfidence.rawValue) bonus=0 fallback=Phase A"
        }
        let top = families.max { $0.appliedBonus < $1.appliedBonus }
        return "SimilarDays: confidence=\(overallConfidence.rawValue) topBonus=\(top?.appliedBonus ?? 0)"
    }
}
