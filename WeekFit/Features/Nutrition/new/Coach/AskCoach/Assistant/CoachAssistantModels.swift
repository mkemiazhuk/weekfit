import Foundation

/// Stable node identifiers for the guided Coach Assistant graph.
enum CoachAssistantNodeID: String, Codable, Sendable, CaseIterable {
    case feelingAsk
    case tiredClarify
    case feelingReflect
    case mindAsk

    case activityGate
    case activityToday
    case activityRecent
    case activityConsistency
    case activityPlanConfirm

    case nutritionGate
    case nutritionMenu
    case nutritionRemaining
    case nutritionChooseMeal
    case nutritionHabits

    case recoveryGate
    case recoveryToday
    case recoveryDuration
    case recoveryPattern
    case recoveryNextStep

    case end
}

enum CoachAssistantArea: String, Codable, Sendable {
    case activity
    case nutrition
    case recovery
}

enum CoachAssistantTurnRole: String, Codable, Sendable {
    case coach
    case user
}

/// One message in the conversation transcript.
struct CoachAssistantTurn: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let role: CoachAssistantTurnRole
    let text: CoachBilingualText
    let nodeID: CoachAssistantNodeID
    let createdAt: Date
    var supportingFacts: [CoachBilingualText]
    var detailFacts: [CoachBilingualText]
    /// Choice that produced this user turn.
    var choiceID: String?
    /// Set when an earlier edit invalidates this turn’s conclusion.
    var isInvalidated: Bool

    init(
        id: String = UUID().uuidString,
        role: CoachAssistantTurnRole,
        text: CoachBilingualText,
        nodeID: CoachAssistantNodeID,
        createdAt: Date = Date(),
        supportingFacts: [CoachBilingualText] = [],
        detailFacts: [CoachBilingualText] = [],
        choiceID: String? = nil,
        isInvalidated: Bool = false
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.nodeID = nodeID
        self.createdAt = createdAt
        self.supportingFacts = supportingFacts
        self.detailFacts = detailFacts
        self.choiceID = choiceID
        self.isInvalidated = isInvalidated
    }
}

/// A reply chip shown in the bottom action area.
struct CoachAssistantChoice: Identifiable, Equatable, Sendable {
    let id: String
    let title: CoachBilingualText
    /// Optional small area label (Activity / Nutrition / Recovery).
    let areaLabel: CoachBilingualText?
    let destination: CoachAssistantNodeID
    /// Optional side effect handled by the view model.
    let action: CoachAssistantChoiceAction?

    init(
        id: String,
        title: CoachBilingualText,
        areaLabel: CoachBilingualText? = nil,
        destination: CoachAssistantNodeID,
        action: CoachAssistantChoiceAction? = nil
    ) {
        self.id = id
        self.title = title
        self.areaLabel = areaLabel
        self.destination = destination
        self.action = action
    }
}

enum CoachAssistantChoiceAction: String, Codable, Equatable, Sendable {
    /// Opens the Meals tab (not a guaranteed Meal Builder deep-link).
    case openMealsTab
    /// Backward-compatible alias decoded from older transcripts.
    case openMealBuilder
    case openGoalSettings
    case proposePlanEase
    case setWeeklyFocus
    case startNewConversation
    case skipCheckIn

    var resolvesToMealsTab: Bool {
        self == .openMealsTab || self == .openMealBuilder
    }
}

/// Snapshot frozen with the conversation so reopen doesn’t swap in today’s metrics.
struct CoachAssistantEvidenceBundle: Codable, Equatable, Sendable {
    var feelingOutcome: CoachFeelingComparisonKind?
    var feelingEvidence: CoachFeelingEvidenceSnapshot
    var reflectionHeadline: CoachBilingualText?
    var reflectionExplanation: CoachBilingualText?
    var reflectionFacts: [CoachBilingualText]
    var periodLabel: CoachBilingualText?
    var hasPlannedWorkoutToday: Bool
    var hasCompletedActivityToday: Bool
    var nutritionCaloriesCurrent: Double?
    var nutritionCaloriesGoal: Double?
    var nutritionProteinCurrent: Double?
    var nutritionProteinGoal: Double?
    var nutritionMealsLogged: Int
    var analysisVersion: Int

    static let empty = CoachAssistantEvidenceBundle(
        feelingOutcome: nil,
        feelingEvidence: .empty,
        reflectionHeadline: nil,
        reflectionExplanation: nil,
        reflectionFacts: [],
        periodLabel: nil,
        hasPlannedWorkoutToday: false,
        hasCompletedActivityToday: false,
        nutritionCaloriesCurrent: nil,
        nutritionCaloriesGoal: nil,
        nutritionProteinCurrent: nil,
        nutritionProteinGoal: nil,
        nutritionMealsLogged: 0,
        analysisVersion: CoachFeelingEvidenceRules.analysisVersion
    )
}

/// Live sleep / autonomic metrics for Recovery — missing stays nil (never coerce 0).
struct CoachAssistantRecoveryVitals: Equatable, Sendable {
    var sleepMinutes: Int?
    var deepSleepMinutes: Int?
    var remSleepMinutes: Int?
    var coreSleepMinutes: Int?
    var hrvSDNN: Double?
    var restingHeartRate: Double?
    /// Median of recent days with HRV when available.
    var hrvBaselineSDNN: Double?
    /// Median of recent days with RHR when available.
    var restingHeartRateBaseline: Double?

    static let empty = CoachAssistantRecoveryVitals(
        sleepMinutes: nil,
        deepSleepMinutes: nil,
        remSleepMinutes: nil,
        coreSleepMinutes: nil,
        hrvSDNN: nil,
        restingHeartRate: nil,
        hrvBaselineSDNN: nil,
        restingHeartRateBaseline: nil
    )

    var hasAnySleepOrAutonomicSignal: Bool {
        (sleepMinutes ?? 0) > 0
            || (deepSleepMinutes ?? 0) > 0
            || (remSleepMinutes ?? 0) > 0
            || (hrvSDNN ?? 0) > 0
            || (restingHeartRate ?? 0) > 0
    }
}

struct CoachAssistantConversation: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var createdAt: Date
    var updatedAt: Date
    var feeling: CoachFeelingKind?
    var clarification: CoachFeelingClarification?
    /// Active topic branch. Navigation-only (“Other topic”) clears this before the next topic choice.
    var area: CoachAssistantArea?
    /// Previous topic before the last explicit topic switch (nil until the first switch).
    var previousArea: CoachAssistantArea?
    var currentNodeID: CoachAssistantNodeID
    /// Node to restore after an external screen action (Meals / Goals / Plan).
    var returnNodeID: CoachAssistantNodeID?
    /// Fingerprint of vitals/plan/meals/activity used for this analysis pass.
    var dataFingerprint: String?
    var turns: [CoachAssistantTurn]
    var choiceIDs: [String]
    /// option_id → answered_at for TTL / skip-repeat policy.
    var answerTimestamps: [String: Date]
    var evidence: CoachAssistantEvidenceBundle
    var previewEnglish: String
    var previewRussian: String
    var ended: Bool

    init(
        id: String,
        createdAt: Date,
        updatedAt: Date,
        feeling: CoachFeelingKind?,
        clarification: CoachFeelingClarification?,
        area: CoachAssistantArea?,
        previousArea: CoachAssistantArea? = nil,
        currentNodeID: CoachAssistantNodeID,
        returnNodeID: CoachAssistantNodeID? = nil,
        dataFingerprint: String? = nil,
        turns: [CoachAssistantTurn],
        choiceIDs: [String],
        answerTimestamps: [String: Date] = [:],
        evidence: CoachAssistantEvidenceBundle,
        previewEnglish: String,
        previewRussian: String,
        ended: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.feeling = feeling
        self.clarification = clarification
        self.area = area
        self.previousArea = previousArea
        self.currentNodeID = currentNodeID
        self.returnNodeID = returnNodeID
        self.dataFingerprint = dataFingerprint
        self.turns = turns
        self.choiceIDs = choiceIDs
        self.answerTimestamps = answerTimestamps
        self.evidence = evidence
        self.previewEnglish = previewEnglish
        self.previewRussian = previewRussian
        self.ended = ended
    }

    enum CodingKeys: String, CodingKey {
        case id, createdAt, updatedAt, feeling, clarification, area, previousArea
        case currentNodeID, returnNodeID, dataFingerprint, turns, choiceIDs
        case answerTimestamps, evidence, previewEnglish, previewRussian, ended
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        feeling = try c.decodeIfPresent(CoachFeelingKind.self, forKey: .feeling)
        clarification = try c.decodeIfPresent(CoachFeelingClarification.self, forKey: .clarification)
        area = try c.decodeIfPresent(CoachAssistantArea.self, forKey: .area)
        previousArea = try c.decodeIfPresent(CoachAssistantArea.self, forKey: .previousArea)
        currentNodeID = try c.decode(CoachAssistantNodeID.self, forKey: .currentNodeID)
        returnNodeID = try c.decodeIfPresent(CoachAssistantNodeID.self, forKey: .returnNodeID)
        dataFingerprint = try c.decodeIfPresent(String.self, forKey: .dataFingerprint)
        turns = try c.decode([CoachAssistantTurn].self, forKey: .turns)
        choiceIDs = try c.decode([String].self, forKey: .choiceIDs)
        answerTimestamps = try c.decodeIfPresent([String: Date].self, forKey: .answerTimestamps) ?? [:]
        evidence = try c.decode(CoachAssistantEvidenceBundle.self, forKey: .evidence)
        previewEnglish = try c.decode(String.self, forKey: .previewEnglish)
        previewRussian = try c.decode(String.self, forKey: .previewRussian)
        ended = try c.decode(Bool.self, forKey: .ended)
    }

    func dayKey(calendar: Calendar = .current) -> String {
        CoachDailyObservation.dayKey(for: createdAt, calendar: calendar)
    }

    var preview: CoachBilingualText {
        .en(previewEnglish, previewRussian)
    }

    /// Explicit topic state — never infer from the last assistant message.
    var currentTopic: CoachAssistantArea? { area }

    /// Record a stable answer for TTL / skip-repeat. Editing feeling clears dependent keys.
    mutating func recordAnswer(_ optionID: String, at date: Date = Date()) {
        answerTimestamps[optionID] = date
        if !choiceIDs.contains(optionID) {
            choiceIDs.append(optionID)
        }
    }

    mutating func invalidateAnswers(prefix: String) {
        answerTimestamps = answerTimestamps.filter { !$0.key.hasPrefix(prefix) }
        choiceIDs.removeAll { $0.hasPrefix(prefix) }
    }
}

/// Runtime payload returned by the flow when advancing a node.
struct CoachAssistantNodeOutput: Equatable, Sendable {
    var coachTurns: [CoachAssistantTurn]
    var choices: [CoachAssistantChoice]
    var updatedEvidence: CoachAssistantEvidenceBundle?
    var feeling: CoachFeelingKind?
    var clarification: CoachFeelingClarification?
    var area: CoachAssistantArea?
    /// When true, clear `conversation.area` even if `area` is nil (topic picker / Other topic).
    var clearsArea: Bool = false
    /// Always applied to `conversation.currentNodeID`, including when `coachTurns` is empty.
    var nextNodeID: CoachAssistantNodeID? = nil
    var ended: Bool
    var preview: CoachBilingualText?
    /// Stable ID for anti-repetition across days.
    var questionID: String? = nil
    var recommendationID: String? = nil
    var followUp: CoachAssistantFollowUpKind? = nil
    var clearPriorFollowUp: Bool = false
    /// Terminal navigations should skip the typing beat after persist.
    var skipTypingDelay: Bool = false
    /// Fired by the view model only after turns are persisted.
    var navigationAction: CoachAssistantChoiceAction? = nil
}
