import Foundation

/// Product-engagement actions that count toward review eligibility.
/// Intentionally excludes any HealthKit-derived health condition values.
enum MeaningfulAction: String, Codable, CaseIterable, Sendable {
    case foodLogged
    case drinkLogged
    case activityLoggedOrCompleted
    case planCreatedOrUpdated
    case coachRecommendationOpened
    case recoveryDetailsViewed
    /// Fired once the user completes all 7 Recovery Challenge days.
    case recoveryChallengeCompleted
    case otherPositiveAction

    var analyticsName: String { rawValue }
}
