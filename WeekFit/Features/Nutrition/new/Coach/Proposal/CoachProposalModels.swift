import Foundation

// MARK: - Status

enum CoachProposalStatus: String, Codable, Sendable, Equatable {
    case gatheringData
    case noChangesNeeded
    case proposalReady
    case reviewing
    case applying
    case applied
    case dismissed
    case stale
    case expired
    case failed
    case unavailable
}

enum CoachChangeKind: String, Codable, Sendable, Equatable {
    case modifyDuration
    case moveActivity
    case skipActivity
    case createRecoveryWalk
    case createPlannedActivity
    case createMealFromLibrary
    case guidanceOnly
}

enum CoachProposalReasonCode: String, Codable, Sendable, Equatable {
    case lowRecoveryLoadProtection
    case heavyYesterdayProtection
    case tomorrowDemandProtection
    case stackedDayRisk
    case recoveryWalkSupport
    case insufficientConfidence
    case planAlreadyAppropriate
    case openDayMovementSupport
    case similarDaySupport
    case libraryMealSupport
    case weatherOutdoorConflict
    case weatherHeatLoad
}

enum CoachGuidanceCode: String, Codable, Sendable, Equatable {
    case easeIntoFirstEffort
    case fuelBeforeSession
    case hydrateThroughMorning
    case protectTomorrowFreshness
    case listenToBodyOnLowReadiness
    /// Empty meal library — general morning fuel tip.
    case morningFuelWithoutLibrary
    /// Empty meal library + low recovery — gentle protein-forward breakfast.
    case morningFuelGentleRecovery
    /// Empty meal library + train day — steady energy before effort.
    case morningFuelSteadyEnergy
    case preferIndoorOrEarlier
    case easeOutdoorHeat
    case shelteredRoutesWind
    case warmUpInCold
}

enum CoachApplyItemOutcome: String, Codable, Sendable, Equatable {
    case applied
    case skippedAlreadyMatched
    case failedTargetUnavailable
    case failedConflictUnresolved
    case failedValidation
    case ignoredGuidanceOnly
}

enum ProposalRecoveryBandToken: String, Codable, Sendable, Equatable {
    case good
    case moderate
    case low
    case unavailable
}

enum ProposalSleepPresenceToken: String, Codable, Sendable, Equatable {
    case present
    case missing
    case unavailable
}

/// Library meal snapshot used by the morning composer (no HealthKit fields).
struct ProposalMealCandidate: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let imageName: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let fiber: Int
    let mealsTypeRaw: String
    let suggestedTime: String?
}

// MARK: - Fingerprint

struct ProposalInputFingerprint: Codable, Sendable, Equatable {
    let dayKey: String
    let planSignature: String
    let tomorrowPlanSignature: String
    let recoveryBand: ProposalRecoveryBandToken
    let sleepPresence: ProposalSleepPresenceToken
    let scenarioKey: String
    let yesterdayHeavy: Bool
    let schemaVersion: Int
    let observationContextRevision: String
    let behavioralGeneration: Int
    let stackedLoad: ProposalStackedLoadToken
    let generationMode: String
    let mealLibraryRevision: String
    let physiologyContextRevision: String
    let scorerVersion: Int
    /// Coarse weather risk; defaults to unavailable for older drafts.
    let weatherRiskToken: ProposalWeatherRiskToken

    static let currentSchemaVersion = 4

    enum CodingKeys: String, CodingKey {
        case dayKey, planSignature, tomorrowPlanSignature, recoveryBand, sleepPresence
        case scenarioKey, yesterdayHeavy, schemaVersion
        case observationContextRevision, behavioralGeneration, stackedLoad, generationMode
        case mealLibraryRevision, physiologyContextRevision, scorerVersion
        case weatherRiskToken
    }

    init(
        dayKey: String,
        planSignature: String,
        tomorrowPlanSignature: String,
        recoveryBand: ProposalRecoveryBandToken,
        sleepPresence: ProposalSleepPresenceToken,
        scenarioKey: String,
        yesterdayHeavy: Bool,
        schemaVersion: Int = ProposalInputFingerprint.currentSchemaVersion,
        observationContextRevision: String = "none",
        behavioralGeneration: Int = 0,
        stackedLoad: ProposalStackedLoadToken = .unavailable,
        generationMode: String = MorningProposalGenerationMode.closed.rawValue,
        mealLibraryRevision: String = "0",
        physiologyContextRevision: String = "none",
        scorerVersion: Int = MorningProposalAssembler.scorerVersion,
        weatherRiskToken: ProposalWeatherRiskToken = .unavailable
    ) {
        self.dayKey = dayKey
        self.planSignature = planSignature
        self.tomorrowPlanSignature = tomorrowPlanSignature
        self.recoveryBand = recoveryBand
        self.sleepPresence = sleepPresence
        self.scenarioKey = scenarioKey
        self.yesterdayHeavy = yesterdayHeavy
        self.schemaVersion = schemaVersion
        self.observationContextRevision = observationContextRevision
        self.behavioralGeneration = behavioralGeneration
        self.stackedLoad = stackedLoad
        self.generationMode = generationMode
        self.mealLibraryRevision = mealLibraryRevision
        self.physiologyContextRevision = physiologyContextRevision
        self.scorerVersion = scorerVersion
        self.weatherRiskToken = weatherRiskToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try container.decode(String.self, forKey: .dayKey)
        planSignature = try container.decode(String.self, forKey: .planSignature)
        tomorrowPlanSignature = try container.decode(String.self, forKey: .tomorrowPlanSignature)
        recoveryBand = try container.decode(ProposalRecoveryBandToken.self, forKey: .recoveryBand)
        sleepPresence = try container.decode(ProposalSleepPresenceToken.self, forKey: .sleepPresence)
        scenarioKey = try container.decode(String.self, forKey: .scenarioKey)
        yesterdayHeavy = try container.decode(Bool.self, forKey: .yesterdayHeavy)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        observationContextRevision = try container.decodeIfPresent(String.self, forKey: .observationContextRevision) ?? "none"
        behavioralGeneration = try container.decodeIfPresent(Int.self, forKey: .behavioralGeneration) ?? 0
        stackedLoad = try container.decodeIfPresent(ProposalStackedLoadToken.self, forKey: .stackedLoad) ?? .unavailable
        generationMode = try container.decodeIfPresent(String.self, forKey: .generationMode)
            ?? MorningProposalGenerationMode.closed.rawValue
        mealLibraryRevision = try container.decodeIfPresent(String.self, forKey: .mealLibraryRevision) ?? "0"
        physiologyContextRevision = try container.decodeIfPresent(String.self, forKey: .physiologyContextRevision) ?? "none"
        scorerVersion = try container.decodeIfPresent(Int.self, forKey: .scorerVersion) ?? 1
        weatherRiskToken = try container.decodeIfPresent(ProposalWeatherRiskToken.self, forKey: .weatherRiskToken)
            ?? .unavailable
    }

    func materialDifference(from other: ProposalInputFingerprint) -> Bool {
        planStaleDifference(from: other)
            || behavioralGeneration != other.behavioralGeneration
    }

    /// Plan / physiology / meal / day inputs that should stale an open draft.
    /// Excludes behavioralGeneration so mid-review toggles cannot orphan Apply.
    func planStaleDifference(from other: ProposalInputFingerprint) -> Bool {
        dayKey != other.dayKey
            || planSignature != other.planSignature
            || tomorrowPlanSignature != other.tomorrowPlanSignature
            || recoveryBand != other.recoveryBand
            || sleepPresence != other.sleepPresence
            || scenarioKey != other.scenarioKey
            || yesterdayHeavy != other.yesterdayHeavy
            || observationContextRevision != other.observationContextRevision
            || stackedLoad != other.stackedLoad
            || generationMode != other.generationMode
            || mealLibraryRevision != other.mealLibraryRevision
            || physiologyContextRevision != other.physiologyContextRevision
            || scorerVersion != other.scorerVersion
            || schemaVersion != other.schemaVersion
            || weatherRiskToken != other.weatherRiskToken
    }
}

// MARK: - Payloads

enum CoachChangePayload: Codable, Sendable, Equatable {
    case modifyDuration(ModifyDurationPayload)
    case moveActivity(MoveActivityPayload)
    case skipActivity(SkipActivityPayload)
    case createRecoveryWalk(CreateRecoveryWalkPayload)
    case createPlannedActivity(CreatePlannedActivityPayload)
    case createMealFromLibrary(CreateMealFromLibraryPayload)
    case guidanceOnly(GuidanceOnlyPayload)

    private enum CodingKeys: String, CodingKey {
        case type
        case modifyDuration
        case moveActivity
        case skipActivity
        case createRecoveryWalk
        case createPlannedActivity
        case createMealFromLibrary
        case guidanceOnly
    }

    private enum PayloadType: String, Codable {
        case modifyDuration
        case moveActivity
        case skipActivity
        case createRecoveryWalk
        case createPlannedActivity
        case createMealFromLibrary
        case guidanceOnly
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .modifyDuration(let payload):
            try container.encode(PayloadType.modifyDuration, forKey: .type)
            try container.encode(payload, forKey: .modifyDuration)
        case .moveActivity(let payload):
            try container.encode(PayloadType.moveActivity, forKey: .type)
            try container.encode(payload, forKey: .moveActivity)
        case .skipActivity(let payload):
            try container.encode(PayloadType.skipActivity, forKey: .type)
            try container.encode(payload, forKey: .skipActivity)
        case .createRecoveryWalk(let payload):
            try container.encode(PayloadType.createRecoveryWalk, forKey: .type)
            try container.encode(payload, forKey: .createRecoveryWalk)
        case .createPlannedActivity(let payload):
            try container.encode(PayloadType.createPlannedActivity, forKey: .type)
            try container.encode(payload, forKey: .createPlannedActivity)
        case .createMealFromLibrary(let payload):
            try container.encode(PayloadType.createMealFromLibrary, forKey: .type)
            try container.encode(payload, forKey: .createMealFromLibrary)
        case .guidanceOnly(let payload):
            try container.encode(PayloadType.guidanceOnly, forKey: .type)
            try container.encode(payload, forKey: .guidanceOnly)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PayloadType.self, forKey: .type)
        switch type {
        case .modifyDuration:
            self = .modifyDuration(try container.decode(ModifyDurationPayload.self, forKey: .modifyDuration))
        case .moveActivity:
            self = .moveActivity(try container.decode(MoveActivityPayload.self, forKey: .moveActivity))
        case .skipActivity:
            self = .skipActivity(try container.decode(SkipActivityPayload.self, forKey: .skipActivity))
        case .createRecoveryWalk:
            self = .createRecoveryWalk(try container.decode(CreateRecoveryWalkPayload.self, forKey: .createRecoveryWalk))
        case .createPlannedActivity:
            self = .createPlannedActivity(try container.decode(CreatePlannedActivityPayload.self, forKey: .createPlannedActivity))
        case .createMealFromLibrary:
            self = .createMealFromLibrary(try container.decode(CreateMealFromLibraryPayload.self, forKey: .createMealFromLibrary))
        case .guidanceOnly:
            self = .guidanceOnly(try container.decode(GuidanceOnlyPayload.self, forKey: .guidanceOnly))
        }
    }
}

struct ModifyDurationPayload: Codable, Sendable, Equatable {
    let activityId: String
    let originalDurationMinutes: Int
    let proposedDurationMinutes: Int
    /// Display title at proposal time (optional for older stored drafts).
    let activityTitle: String

    init(
        activityId: String,
        originalDurationMinutes: Int,
        proposedDurationMinutes: Int,
        activityTitle: String = ""
    ) {
        self.activityId = activityId
        self.originalDurationMinutes = originalDurationMinutes
        self.proposedDurationMinutes = proposedDurationMinutes
        self.activityTitle = activityTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activityId = try container.decode(String.self, forKey: .activityId)
        originalDurationMinutes = try container.decode(Int.self, forKey: .originalDurationMinutes)
        proposedDurationMinutes = try container.decode(Int.self, forKey: .proposedDurationMinutes)
        activityTitle = try container.decodeIfPresent(String.self, forKey: .activityTitle) ?? ""
    }
}

struct MoveActivityPayload: Codable, Sendable, Equatable {
    let activityId: String
    let originalDate: Date
    let proposedDate: Date
    let activityTitle: String

    init(
        activityId: String,
        originalDate: Date,
        proposedDate: Date,
        activityTitle: String = ""
    ) {
        self.activityId = activityId
        self.originalDate = originalDate
        self.proposedDate = proposedDate
        self.activityTitle = activityTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activityId = try container.decode(String.self, forKey: .activityId)
        originalDate = try container.decode(Date.self, forKey: .originalDate)
        proposedDate = try container.decode(Date.self, forKey: .proposedDate)
        activityTitle = try container.decodeIfPresent(String.self, forKey: .activityTitle) ?? ""
    }
}

struct SkipActivityPayload: Codable, Sendable, Equatable {
    let activityId: String
    let originalDate: Date
    let activityTitle: String

    init(
        activityId: String,
        originalDate: Date,
        activityTitle: String = ""
    ) {
        self.activityId = activityId
        self.originalDate = originalDate
        self.activityTitle = activityTitle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activityId = try container.decode(String.self, forKey: .activityId)
        originalDate = try container.decode(Date.self, forKey: .originalDate)
        activityTitle = try container.decodeIfPresent(String.self, forKey: .activityTitle) ?? ""
    }
}

struct CreateRecoveryWalkPayload: Codable, Sendable, Equatable {
    let proposedDate: Date
    let durationMinutes: Int
    let title: String
    let activityType: String
}

struct CreatePlannedActivityPayload: Codable, Sendable, Equatable {
    let proposedDate: Date
    let durationMinutes: Int
    let title: String
    let activityType: String
    let icon: String
    let imageName: String
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
    let sourceTemplateDayKey: String?
}

struct CreateMealFromLibraryPayload: Codable, Sendable, Equatable {
    let mealId: String
    let title: String
    let proposedDate: Date
    let durationMinutes: Int
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let fiber: Int
    let imageName: String
}

struct GuidanceOnlyPayload: Codable, Sendable, Equatable {
    let guidanceCode: CoachGuidanceCode
    let relatedActivityId: String?
}

// MARK: - Change / Proposal

struct CoachProposedChange: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let kind: CoachChangeKind
    let reasonCode: CoachProposalReasonCode
    let payload: CoachChangePayload
    var defaultSelected: Bool
    var isSelected: Bool
    let sortTime: Date
    let evidenceScenarioKey: String?
    let candidateSource: CandidateSource?
    let scoreTotal: Int?

    init(
        id: String,
        kind: CoachChangeKind,
        reasonCode: CoachProposalReasonCode,
        payload: CoachChangePayload,
        defaultSelected: Bool,
        isSelected: Bool,
        sortTime: Date,
        evidenceScenarioKey: String?,
        candidateSource: CandidateSource? = nil,
        scoreTotal: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.reasonCode = reasonCode
        self.payload = payload
        self.defaultSelected = defaultSelected
        self.isSelected = isSelected
        self.sortTime = sortTime
        self.evidenceScenarioKey = evidenceScenarioKey
        self.candidateSource = candidateSource
        self.scoreTotal = scoreTotal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(CoachChangeKind.self, forKey: .kind)
        reasonCode = try container.decode(CoachProposalReasonCode.self, forKey: .reasonCode)
        payload = try container.decode(CoachChangePayload.self, forKey: .payload)
        defaultSelected = try container.decode(Bool.self, forKey: .defaultSelected)
        isSelected = try container.decode(Bool.self, forKey: .isSelected)
        sortTime = try container.decode(Date.self, forKey: .sortTime)
        evidenceScenarioKey = try container.decodeIfPresent(String.self, forKey: .evidenceScenarioKey)
        candidateSource = try container.decodeIfPresent(CandidateSource.self, forKey: .candidateSource)
        scoreTotal = try container.decodeIfPresent(Int.self, forKey: .scoreTotal)
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, reasonCode, payload, defaultSelected, isSelected, sortTime
        case evidenceScenarioKey, candidateSource, scoreTotal
    }
}

struct MorningPlanProposal: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let dayKey: String
    let generatedAt: Date
    var status: CoachProposalStatus
    let fingerprint: ProposalInputFingerprint
    var changes: [CoachProposedChange]
    var appliedAt: Date?
    var dismissedAt: Date?
    var lastErrorCode: String?
    let schemaVersion: Int
    let strategy: DailyStrategy?
    let contextConfidence: ProposalContextConfidence?
    let scorerVersion: Int?

    static let currentSchemaVersion = 4

    var selectedChanges: [CoachProposedChange] {
        changes.filter(\.isSelected)
    }

    var mutatingSelectedChanges: [CoachProposedChange] {
        selectedChanges.filter { $0.kind != .guidanceOnly }
    }

    init(
        id: String,
        dayKey: String,
        generatedAt: Date,
        status: CoachProposalStatus,
        fingerprint: ProposalInputFingerprint,
        changes: [CoachProposedChange],
        appliedAt: Date?,
        dismissedAt: Date?,
        lastErrorCode: String?,
        schemaVersion: Int = MorningPlanProposal.currentSchemaVersion,
        strategy: DailyStrategy? = nil,
        contextConfidence: ProposalContextConfidence? = nil,
        scorerVersion: Int? = nil
    ) {
        self.id = id
        self.dayKey = dayKey
        self.generatedAt = generatedAt
        self.status = status
        self.fingerprint = fingerprint
        self.changes = changes
        self.appliedAt = appliedAt
        self.dismissedAt = dismissedAt
        self.lastErrorCode = lastErrorCode
        self.schemaVersion = schemaVersion
        self.strategy = strategy
        self.contextConfidence = contextConfidence
        self.scorerVersion = scorerVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        dayKey = try container.decode(String.self, forKey: .dayKey)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        status = try container.decode(CoachProposalStatus.self, forKey: .status)
        fingerprint = try container.decode(ProposalInputFingerprint.self, forKey: .fingerprint)
        changes = try container.decode([CoachProposedChange].self, forKey: .changes)
        appliedAt = try container.decodeIfPresent(Date.self, forKey: .appliedAt)
        dismissedAt = try container.decodeIfPresent(Date.self, forKey: .dismissedAt)
        lastErrorCode = try container.decodeIfPresent(String.self, forKey: .lastErrorCode)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        strategy = try container.decodeIfPresent(DailyStrategy.self, forKey: .strategy)
        contextConfidence = try container.decodeIfPresent(ProposalContextConfidence.self, forKey: .contextConfidence)
        scorerVersion = try container.decodeIfPresent(Int.self, forKey: .scorerVersion)
    }

    private enum CodingKeys: String, CodingKey {
        case id, dayKey, generatedAt, status, fingerprint, changes
        case appliedAt, dismissedAt, lastErrorCode, schemaVersion
        case strategy, contextConfidence, scorerVersion
    }
}

struct CoachActivitySnapshot: Codable, Sendable, Equatable {
    let activityId: String
    let date: Date
    let type: String
    let title: String
    let durationMinutes: Int
    let isCompleted: Bool
    let isSkipped: Bool
    let source: String
}

struct AppliedCoachAdjustment: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let dayKey: String
    let proposalId: String
    let changeId: String
    let kind: CoachChangeKind
    let activityId: String
    let reasonCode: CoachProposalReasonCode
    let originalSnapshot: CoachActivitySnapshot?
    let appliedSnapshot: CoachActivitySnapshot
    let appliedAt: Date
    var userManuallyEditedAfterApply: Bool
    var terminalOutcome: String?
}

struct CoachDecisionHistoryEntry: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let dayKey: String
    let proposalId: String
    let changeId: String
    let kind: CoachChangeKind
    let reasonCode: CoachProposalReasonCode
    let accepted: Bool
    let applyOutcome: CoachApplyItemOutcome?
    let recordedAt: Date
}

struct CoachApplyJournal: Codable, Sendable, Equatable {
    let proposalId: String
    let dayKey: String
    let startedAt: Date
    var finishedAt: Date?
    var selectedChangeIds: [String]
    var itemOutcomes: [String: CoachApplyItemOutcome]
    var phase: String
}

struct CoachApplySummary: Sendable, Equatable {
    let proposalId: String
    let appliedChangeIds: [String]
    let failedChangeIds: [String]
    let outcomes: [CoachApplyItemOutcome]
    let createdActivityIds: [String]

    var appliedMutationCount: Int {
        appliedChangeIds.count
    }

    var hasSuccessfulMutations: Bool {
        outcomes.contains { $0 == .applied || $0 == .skippedAlreadyMatched }
    }
}
