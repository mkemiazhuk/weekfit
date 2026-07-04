import Foundation
import WeekFitPlanner

/// Grace rules for session phase — prevents premature HealthKit `isCompleted` flicker.
enum CoachSessionPhaseStability {

    private static let watchSyncedGraceAfterPlannedEndMinutes = 5

    /// Activity should be treated as live for focus + session phase selection.
    static func isCoachLiveSession(_ activity: CoachPlannedActivitySnapshot, now: Date) -> Bool {
        guard !activity.isSkipped else { return false }
        if activity.isActive(at: now) { return true }
        return treatsCompletedAsLive(activity: activity, now: now)
    }

    /// Completed/partial activity still inside the planned window (or short HK grace).
    static func treatsCompletedAsLive(activity: CoachPlannedActivitySnapshot, now: Date) -> Bool {
        guard activity.isCompleted || activity.isPartialCompletion else { return false }
        guard isStabilityEligible(activity) else { return false }

        // Watch-synced workouts with a known actual end are definitive — do not extend
        // "live" through the planned slot or a post-end grace window.
        if activity.isWatchSynced,
           let actualEnd = actualSessionEnd(for: activity),
           now >= actualEnd {
            return false
        }

        let plannedEnd = plannedSessionEnd(for: activity)
        if now <= plannedEnd {
            return true
        }

        guard activity.isWatchSynced, activity.isFullCompletion else { return false }
        let minutesPastPlannedEnd = minutesBetween(plannedEnd, now)
        return minutesPastPlannedEnd <= watchSyncedGraceAfterPlannedEndMinutes
    }

    private static func isStabilityEligible(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        switch CoachActivityClassifier.family(for: activity) {
        case .endurance, .recovery:
            return true
        default:
            return false
        }
    }

    private static func plannedSessionEnd(for activity: CoachPlannedActivitySnapshot) -> Date {
        let calendar = Calendar.current
        let plannedMinutes = max(activity.durationMinutes, 1)
        return calendar.date(
            byAdding: .minute,
            value: plannedMinutes,
            to: activity.date
        ) ?? activity.date
    }

    private static func actualSessionEnd(for activity: CoachPlannedActivitySnapshot) -> Date? {
        guard let actualMinutes = activity.actualDurationMinutes, actualMinutes > 0 else {
            return nil
        }
        return Calendar.current.date(
            byAdding: .minute,
            value: actualMinutes,
            to: activity.date
        )
    }

    private static func minutesBetween(_ start: Date, _ end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) / 60))
    }
}
