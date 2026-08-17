import Foundation

/// Production daily strategy for a morning proposal (one per proposal).
enum DailyStrategy: String, Codable, Sendable, Equatable, CaseIterable {
    case recover
    case maintain
    case train
    case protectTomorrow
    case continueExistingPlan
}

enum ProposalContextConfidence: String, Codable, Sendable, Equatable {
    case high
    case medium
    case low
}

enum CandidateSource: String, Codable, Sendable, Equatable {
    case existingPlanAdjustment
    case historicalActivity
    case recoveryMovement
    case mealLibrary
    case guidance
}

enum CandidateFit: String, Codable, Sendable, Equatable {
    case strong
    case moderate
    case weak
    case incompatible
}

enum CandidateBurden: String, Codable, Sendable, Equatable {
    case low
    case medium
    case high
}

enum DefaultSelectionEligibility: String, Codable, Sendable, Equatable {
    case eligible
    case ineligible
    case notSelectable
}

enum CandidateConflict: String, Codable, Sendable, Equatable {
    case duplicateTarget
    case duplicateMovement
    case timeOverlap
    case strategyIncompatible
    case tomorrowConflict
    case missingLibraryMeal
    case staleTarget
    case excessiveLoad
}

/// Immutable context for all proposal stages.
struct DailyContext: Sendable, Equatable {
    // Time / gate
    let now: Date
    let dayKey: String
    let isMorningEligible: Bool
    let hasCompletedOrPartialToday: Bool
    let generationMode: MorningProposalGenerationMode
    let contextFreshness: ProposalContextConfidence

    // Physiology
    let recoveryBand: ProposalRecoveryBandToken
    let recoveryPercent: Int?
    let recoveryAvailable: Bool
    let sleepPresence: ProposalSleepPresenceToken
    let sleepHours: Double?
    let yesterdayHeavy: Bool
    let stackedLoad: ProposalStackedLoadToken
    let tomorrowDemand: CoachTomorrowDemand
    let scenarioKey: CoachScenarioKey?

    // Plan
    let todayActivities: [CoachPlannedActivitySnapshot]
    let tomorrowActivities: [CoachPlannedActivitySnapshot]
    let todayOpen: [CoachPlannedActivitySnapshot]
    let todaySeriousOpen: [CoachPlannedActivitySnapshot]
    let hasExistingMovement: Bool
    let completedWalkToday: Bool
    let totalPlannedDurationMinutes: Int

    // History
    let recentDayTemplates: [SimilarDayTemplate]
    let historicalObservationRevision: String

    // Behavior
    let behavioralGeneration: Int
    let walkRejectPenalty: Int
    let stronglyRejectsWalk: Bool
    let softDismissCount: Int
    /// Soft confidence drag from dismiss / empty Apply; never overrides safety dial-backs.
    let softNegativePenalty: Int
    /// Soft learned preference: avoid inventing/keeping hard load when recovery is still low.
    let preferAvoidHardLoadOnLowRecovery: Bool

    // Meals
    let mealLibrary: [ProposalMealCandidate]
    let mealLibraryRevision: String

    // Weather (coarse)
    let weatherRiskToken: ProposalWeatherRiskToken

    // Derived
    let canMutate: Bool
    let fingerprint: ProposalInputFingerprint

    /// No similar-day history yet — first mornings before WeekFit has patterns to mine.
    var isColdStart: Bool { recentDayTemplates.isEmpty }
}

struct HistoricalActivityAggregate: Sendable, Equatable, Identifiable {
    let id: String
    let signature: String
    let title: String
    let activityType: String
    let icon: String
    let imageName: String
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
    let medianDurationMinutes: Int
    let habitualHour: Int
    let habitualMinute: Int
    let completionCount: Int
    let skipCount: Int
    let occurrenceCount: Int
    let observationBackedCount: Int
    let weekdayMatchCount: Int
}

struct ProposalCandidate: Identifiable, Sendable, Equatable {
    let id: String
    let source: CandidateSource
    let kind: CoachChangeKind
    let payload: CoachChangePayload
    let compatibleStrategies: Set<DailyStrategy>
    let physiologicalFit: CandidateFit
    let confidence: Double
    let burden: CandidateBurden
    let reasonCodes: [CoachProposalReasonCode]
    let conflicts: [CandidateConflict]
    let defaultSelectionEligibility: DefaultSelectionEligibility
    let sortTime: Date
    let evidenceScenarioKey: String?
    /// Stable signature for aggregation / duplicate detection.
    let identityKey: String
}

struct CandidateScoreBreakdown: Sendable, Equatable {
    let physiologicalFit: Int
    let strategyFit: Int
    let historicalSuccess: Int
    let behavioralLikelihood: Int
    let tomorrowProtection: Int
    let usualTimeFit: Int
    let rejectionPenalty: Int
    let confidencePenalty: Int
    let conflictPenalty: Int
    let fatiguePenalty: Int

    var total: Int {
        max(0, min(100,
            physiologicalFit
                + strategyFit
                + historicalSuccess
                + behavioralLikelihood
                + tomorrowProtection
                + usualTimeFit
                + rejectionPenalty
                + confidencePenalty
                + conflictPenalty
                + fatiguePenalty
        ))
    }
}

struct ScoredCandidate: Sendable, Equatable, Identifiable {
    let candidate: ProposalCandidate
    let breakdown: CandidateScoreBreakdown
    var id: String { candidate.id }
    var score: Int { breakdown.total }
}

struct ComposedPlan: Sendable, Equatable {
    let strategy: DailyStrategy
    let scoredCandidates: [ScoredCandidate]
    let droppedCandidateIds: [String]
    let validationNotes: [String]
}

struct ValidatedPlan: Sendable, Equatable {
    let strategy: DailyStrategy
    let candidates: [ScoredCandidate]
    let aborted: Bool
    let abortReason: String?
    let notes: [String]
}

#if DEBUG
enum MorningProposalDebugTrace {
    static var lastStrategy: DailyStrategy?
    static var lastMode: MorningProposalGenerationMode?
    static var lastWalkDecision: WalkProposalDecision?
    static var lastTemplateScores: [SimilarDayScoreBreakdown] = []
    static var lastSelectedTemplateDayKey: String?
    static var lastNoProposalReason: String?
    static var lastConfidence: ProposalContextConfidence?
    static var lastCandidateScores: [CandidateScoreBreakdown] = []
}
#endif
