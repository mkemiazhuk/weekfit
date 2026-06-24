import Foundation

// MARK: - Athlete state (Phase 2A: body only)

/// How recovered the athlete's body is right now — not a copy concept.
enum CoachV6BodyState: String, Equatable, Sendable, CaseIterable {
    case fresh
    case normal
    case fatigued
    case veryFatigued
}

/// Normalized athlete snapshot for copy rendering. Scenario ownership stays external.
struct CoachV6AthleteState: Equatable, Sendable {
    let bodyState: CoachV6BodyState

    static let normal = CoachV6AthleteState(bodyState: .normal)
}
