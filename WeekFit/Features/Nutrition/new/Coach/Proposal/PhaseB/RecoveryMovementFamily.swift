import Foundation

/// Behavioral identity for Morning Adjustments personalization.
/// Never use proposal `changeId` as the scoring key.
enum RecoveryMovementFamily: String, Codable, CaseIterable, Sendable, Equatable {
    case walk
    case mobility
    case yoga
    case breathing
    case easyRun
    case otherTraining
}

enum MovementBehaviorOrigin: String, Codable, Sendable, Equatable {
    case morningAdjustment
    case userPlanned
    case historical
}

enum ProposalTimeBucket: String, Codable, Sendable, Equatable {
    case morning
    case midday
    case afternoon

    static func from(date: Date, calendar: Calendar = .current) -> ProposalTimeBucket {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .midday
        default: return .afternoon
        }
    }
}

enum PreviousDayLoadLabel: String, Codable, Sendable, Equatable {
    case rest
    case normal
    case heavy
    case unknown
}

enum RecoveryMovementFamilyResolver {

    static func family(for option: RecoveryMovementProvider.LightOption) -> RecoveryMovementFamily {
        switch option {
        case .walk: return .walk
        case .stretch: return .mobility
        case .yoga: return .yoga
        case .breathing: return .breathing
        case .easyRun: return .easyRun
        }
    }

    static func lightOption(for family: RecoveryMovementFamily) -> RecoveryMovementProvider.LightOption? {
        switch family {
        case .walk: return .walk
        case .mobility: return .stretch
        case .yoga: return .yoga
        case .breathing: return .breathing
        case .easyRun: return .easyRun
        case .otherTraining: return nil
        }
    }

    static func family(for activityType: CoachActivityType) -> RecoveryMovementFamily {
        switch activityType {
        case .walk: return .walk
        case .stretching: return .mobility
        case .yoga: return .yoga
        case .breathing: return .breathing
        case .running, .cycling, .swimming, .hiit,
             .tennis, .squash,
             .upperBody, .lowerBody, .core, .fullBody,
             .sauna, .none:
            if CoachActivityClassifier.family(forType: activityType) == .recovery {
                return .mobility
            }
            return .otherTraining
        }
    }

    static func family(for snapshot: CoachPlannedActivitySnapshot) -> RecoveryMovementFamily {
        family(for: CoachActivityClassifier.type(for: snapshot))
    }

    static func family(for aggregate: HistoricalActivityAggregate) -> RecoveryMovementFamily {
        let snapshot = CoachPlannedActivitySnapshot(
            id: aggregate.id,
            date: Date(),
            type: aggregate.activityType,
            title: aggregate.title,
            durationMinutes: aggregate.medianDurationMinutes,
            icon: aggregate.icon,
            imageName: aggregate.imageName,
            colorRed: aggregate.colorRed,
            colorGreen: aggregate.colorGreen,
            colorBlue: aggregate.colorBlue,
            isCompleted: false,
            isSkipped: false,
            source: "history"
        )
        return family(for: snapshot)
    }

    static func family(for change: CoachProposedChange) -> RecoveryMovementFamily? {
        family(for: change.kind, payload: change.payload, source: change.candidateSource)
    }

    static func family(
        for candidate: ProposalCandidate
    ) -> RecoveryMovementFamily? {
        family(for: candidate.kind, payload: candidate.payload, source: candidate.source)
    }

    static func family(
        for kind: CoachChangeKind,
        payload: CoachChangePayload,
        source: CandidateSource?
    ) -> RecoveryMovementFamily? {
        switch (kind, payload) {
        case (.createRecoveryWalk, _):
            return .walk
        case (.createPlannedActivity, .createPlannedActivity(let payload)):
            return family(forActivityTypeRaw: payload.activityType, title: payload.title)
        default:
            return nil
        }
    }

    static func origin(for source: CandidateSource?) -> MovementBehaviorOrigin? {
        switch source {
        case .recoveryMovement: return .morningAdjustment
        case .historicalActivity: return .historical
        case .existingPlanAdjustment, .mealLibrary, .guidance, .none:
            return nil
        }
    }

    static func originForUserPlannedActivity(_ snapshot: CoachPlannedActivitySnapshot) -> MovementBehaviorOrigin {
        .userPlanned
    }

    static func family(forActivityTypeRaw raw: String, title: String) -> RecoveryMovementFamily {
        let snapshot = CoachPlannedActivitySnapshot(
            id: "resolve",
            date: Date(),
            type: raw,
            title: title,
            durationMinutes: 20,
            icon: "",
            imageName: "",
            isCompleted: false,
            isSkipped: false,
            source: "planner"
        )
        let resolved = family(for: snapshot)
        if resolved == .otherTraining {
            let blob = "\(title) \(raw)".lowercased()
            if blob.contains("yoga") { return .yoga }
            if blob.contains("stretch") || blob.contains("mobil") { return .mobility }
            if blob.contains("breath") { return .breathing }
            if blob.contains("walk") { return .walk }
            if blob.contains("easy") && blob.contains("run") { return .easyRun }
        }
        return resolved
    }
}

#if DEBUG
extension RecoveryMovementFamily {
    var debugDisplayName: String {
        switch self {
        case .walk: return "walk"
        case .mobility: return "mobility"
        case .yoga: return "yoga"
        case .breathing: return "breathing"
        case .easyRun: return "easyRun"
        case .otherTraining: return "otherTraining"
        }
    }
}
#endif

// Reconciler uses the shared raw-type resolver above.

private extension CoachActivityClassifier {
    static func family(forType type: CoachActivityType) -> CoachActivityFamily {
        switch type {
        case .walk, .stretching, .yoga, .breathing, .sauna:
            return .recovery
        case .running, .cycling, .swimming, .hiit, .tennis, .squash:
            return .endurance
        case .upperBody, .lowerBody, .core, .fullBody:
            return .strength
        case .none:
            return .none
        }
    }
}
