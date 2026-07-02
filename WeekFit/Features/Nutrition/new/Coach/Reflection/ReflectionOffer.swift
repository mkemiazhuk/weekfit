import Foundation

/// Why Coach is not in a conversational pause — guidance obligations still active.
enum ConversationPauseBlocker: String, Equatable, Sendable {
    case activeWorkout
    case duringWorkout
    case immediatePostRecovery
    case imminentPreparation
    case tomorrowProtection
    case meaningfulWorkRemaining
    case elevatedUrgency
    case safetyAlert
}

/// Read-only gate: guidance obligations for this moment are complete.
struct ConversationPauseResolution: Equatable, Sendable {
    let isPaused: Bool
    let reason: String
    let blockedBy: ConversationPauseBlocker?
}

/// Presentation bundle when Coach shares an understanding change at a conversational pause.
/// Phase 1: never produced — infrastructure placeholder for later phases.
struct ReflectionOffer: Equatable, Sendable, Identifiable {
    let id: String
    let kind: ReflectionKind
    let message: String
    let beliefID: String?
    let pauseReason: String
}

enum ReflectionKind: String, Equatable, Sendable {
    case newDiscovery
    case confirmation
    case revision
    case retired
    case uncertainty
}
