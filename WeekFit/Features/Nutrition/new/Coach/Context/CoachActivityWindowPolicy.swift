import Foundation

/// Shared prep and post-activity time windows for focus, scenario routing, and future Today UI.
enum CoachActivityWindowPolicy {

    // MARK: - Focus windows (CoachFocusResolver)

    static let immediatePostFocusWindowMinutes = 60
    static let defaultRecentCompletedFocusWindowMinutes = 180

    /// Concrete “Before session” / gear-prep copy window (minutes until start).
    /// Caps preparation lead so a dinner hours away never becomes workout prep.
    static let beforeSessionCopyWindowMinutes = 90

    static var heatRecoveryWindowMinutes: Int {
        CoachHeatRecoveryPolicy.focusWindowMinutes
    }

    static func recentCompletedFocusWindowMinutes(for activity: CoachPlannedActivitySnapshot) -> Int {
        if CoachActivityClassifier.family(for: activity) == .heat {
            return heatRecoveryWindowMinutes
        }
        return defaultRecentCompletedFocusWindowMinutes
    }

    static func isWithinImmediatePostFocusWindow(minutesSinceEnd: Int) -> Bool {
        minutesSinceEnd <= immediatePostFocusWindowMinutes
    }

    // MARK: - Scenario windows (CoachScenarioResolver)

    static func isWithinHeatRecoveryWindow(
        minutesSinceEnd: Int?,
        sessionPhase: CoachSessionPhase
    ) -> Bool {
        guard let minutesSinceEnd else {
            return sessionPhase == .immediatePost
        }
        return minutesSinceEnd <= heatRecoveryWindowMinutes
    }

    // MARK: - Prep / Before-session windows

    /// Lead time before start when Coach may enter `.pre` / Before-session focus.
    static func preparationLeadMinutes(for activity: CoachPlannedActivitySnapshot) -> Int {
        let kind = CoachActivityContextResolver.kind(for: activity)
        let load = CoachActivityContextResolver.load(for: activity)

        if kind == .heat {
            return 90
        }

        if kind == .recovery {
            return CoachActivityClassification.isWalkLike(activity) ? 15 : 30
        }

        if kind == .endurance {
            return 120
        }

        switch load {
        case .extreme, .high:
            return 120
        case .moderate, .low:
            return 90
        }
    }

    /// True when an incomplete session-eligible activity is close enough for prep focus/copy.
    static func isWithinBeforeSessionWindow(
        activity: CoachPlannedActivitySnapshot,
        minutesUntilStart: Int
    ) -> Bool {
        guard minutesUntilStart >= 0 else { return false }
        let lead = min(preparationLeadMinutes(for: activity), beforeSessionCopyWindowMinutes)
        return minutesUntilStart <= lead
    }

    static func minutesUntilStart(activity: CoachPlannedActivitySnapshot, now: Date) -> Int {
        max(0, Int(activity.date.timeIntervalSince(now) / 60))
    }

    static func recoveryHoldMinutes(for activity: CoachPlannedActivitySnapshot) -> Int {
        let kind = CoachActivityContextResolver.kind(for: activity)
        let load = CoachActivityContextResolver.load(for: activity)

        if kind == .recovery {
            return CoachActivityClassification.isWalkLike(activity) ? 8 : 15
        }

        if kind == .heat {
            return heatRecoveryWindowMinutes
        }

        switch load {
        case .extreme, .high, .moderate:
            return 120
        case .low:
            return (kind == .workout || kind == .endurance) ? 90 : 20
        }
    }
}
