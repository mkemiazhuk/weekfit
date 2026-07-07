import Foundation

// MARK: - Athlete state (Phase 2A: body only)

/// How recovered the athlete's body is right now — not a copy concept.
enum CoachBodyState: String, Equatable, Sendable, CaseIterable {
    case fresh
    case normal
    case fatigued
    case veryFatigued
}

/// Normalized athlete snapshot for copy rendering. Scenario ownership stays external.
struct CoachAthleteState: Equatable, Sendable {
    let bodyState: CoachBodyState

    static let normal = CoachAthleteState(bodyState: .normal)
}
