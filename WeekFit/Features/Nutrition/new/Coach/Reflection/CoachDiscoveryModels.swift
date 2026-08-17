import Foundation

enum CoachDiscoveryFamily: String, Codable, Equatable, Sendable {
    case sleep
    case training
    case nutrition
    case timing
}

enum CoachDiscoveryValence: String, Codable, Equatable, Sendable {
    case positive
    case caution
    case neutral
}

enum CoachDiscoveryStatus: String, Codable, Equatable, Sendable {
    case active
    case weakening
    case retired

    static func from(maturity: CoachBeliefMaturity) -> CoachDiscoveryStatus? {
        switch maturity {
        case .established:
            return .active
        case .weakening:
            return .weakening
        case .retired:
            return .retired
        case .watching, .emerging:
            return nil
        }
    }
}

enum CoachDiscoveryOfferKind: String, Codable, Equatable, Sendable {
    case firstLearned
    case materialUpdate
}

/// Durable user-facing projection of a learned belief.
struct CoachDiscovery: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let beliefID: CoachBeliefID
    var family: CoachDiscoveryFamily
    var valence: CoachDiscoveryValence
    var status: CoachDiscoveryStatus
    var firstLearnedAt: Date
    var lastEvaluatedAt: Date
    var lastSurfacedAt: Date?
    var lastSeenByUserAt: Date?
    var timesSurfaced: Int
    var hasBeenSeenByUser: Bool
    var materialChangeToken: String
    var effectSize: Double
    var confidence: Double
    var eligibleDayCount: Int?

    init(
        beliefID: CoachBeliefID,
        status: CoachDiscoveryStatus,
        firstLearnedAt: Date,
        lastEvaluatedAt: Date,
        materialChangeToken: String,
        effectSize: Double,
        confidence: Double,
        eligibleDayCount: Int?,
        hasBeenSeenByUser: Bool = false,
        lastSurfacedAt: Date? = nil,
        lastSeenByUserAt: Date? = nil,
        timesSurfaced: Int = 0
    ) {
        id = beliefID.rawValue
        self.beliefID = beliefID
        family = beliefID.discoveryFamily
        valence = beliefID.discoveryValence
        self.status = status
        self.firstLearnedAt = firstLearnedAt
        self.lastEvaluatedAt = lastEvaluatedAt
        self.lastSurfacedAt = lastSurfacedAt
        self.lastSeenByUserAt = lastSeenByUserAt
        self.timesSurfaced = timesSurfaced
        self.hasBeenSeenByUser = hasBeenSeenByUser
        self.materialChangeToken = materialChangeToken
        self.effectSize = effectSize
        self.confidence = confidence
        self.eligibleDayCount = eligibleDayCount
    }
}

/// Queued Tell moment for Coach. Not a debug event.
struct CoachDiscoveryOffer: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let discoveryID: String
    let beliefID: CoachBeliefID
    let kind: CoachDiscoveryOfferKind
    let createdAt: Date

    static func make(
        discoveryID: String,
        beliefID: CoachBeliefID,
        kind: CoachDiscoveryOfferKind,
        materialChangeToken: String,
        createdAt: Date = Date()
    ) -> CoachDiscoveryOffer {
        CoachDiscoveryOffer(
            id: "\(discoveryID).\(kind.rawValue).\(materialChangeToken)",
            discoveryID: discoveryID,
            beliefID: beliefID,
            kind: kind,
            createdAt: createdAt
        )
    }
}

extension CoachBeliefID {
    var discoveryFamily: CoachDiscoveryFamily {
        switch self {
        case .sleepConsistencyRecovery, .sleepDurationRecovery, .lateBedtimeRecovery:
            return .sleep
        case .heavyLoadRecoveryLag, .recoveryAfterRestDay, .consecutiveHardDaysFatigue, .hardTrainingLowRecoveryCost:
            return .training
        case .underfuelingRecovery, .proteinTrainingDayRecovery, .carbsTrainingDayRecovery:
            return .nutrition
        case .postWorkoutProteinRecovery, .lateHardTrainingSleep:
            return .timing
        }
    }

    var discoveryValence: CoachDiscoveryValence {
        switch self {
        case .sleepConsistencyRecovery, .sleepDurationRecovery, .recoveryAfterRestDay,
             .proteinTrainingDayRecovery, .postWorkoutProteinRecovery, .carbsTrainingDayRecovery:
            return .positive
        case .lateBedtimeRecovery, .heavyLoadRecoveryLag, .consecutiveHardDaysFatigue,
             .underfuelingRecovery, .hardTrainingLowRecoveryCost, .lateHardTrainingSleep:
            return .caution
        }
    }
}

enum CoachDiscoveryMaterialToken {
    static func make(maturity: CoachBeliefMaturity, effectSize: Double) -> String {
        "\(maturity.rawValue).\(Int(effectSize.rounded()))"
    }
}
