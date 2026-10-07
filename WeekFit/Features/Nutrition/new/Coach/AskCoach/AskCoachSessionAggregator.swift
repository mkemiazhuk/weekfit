import Foundation

/// Deduplicates HealthKit workouts and completed local sessions using linked UUID ownership.
///
/// Policy (matches Activity Log / reconciler ownership):
/// - HealthKit workouts are canonical.
/// - Local completed sessions count only when `healthKitWorkoutUUID` is nil/empty.
/// - Unfinished local sessions are excluded.
/// - No speculative time-based deduplication.
enum AskCoachSessionAggregator {

    struct LocalCompletedCandidate: Equatable, Sendable {
        let id: String
        let startDate: Date
        let durationMinutes: Int
        let healthKitWorkoutUUID: UUID?
        let isCompleted: Bool
        let isSkipped: Bool
        let source: String
        let type: String
    }

    struct HealthKitCandidate: Equatable, Sendable {
        let uuid: UUID
        let startDate: Date
        let durationMinutes: Int
        let isRecoveryActivity: Bool
    }

    static func aggregate(
        healthKit: [HealthKitCandidate],
        local: [LocalCompletedCandidate],
        calendar: Calendar = .current
    ) -> [AskCoachCompletedSession] {
        let hkSessions: [AskCoachCompletedSession] = healthKit.map { workout in
            AskCoachCompletedSession(
                id: workout.uuid.uuidString,
                startDate: workout.startDate,
                durationMinutes: max(1, workout.durationMinutes),
                healthKitWorkoutUUID: workout.uuid,
                source: .healthKit,
                isPlannerSourced: false,
                isRecoveryActivity: workout.isRecoveryActivity
            )
        }

        let linkedUUIDs = Set(healthKit.map(\.uuid))

        let localSessions: [AskCoachCompletedSession] = local.compactMap { activity in
            guard activity.isCompleted, !activity.isSkipped else { return nil }
            guard isWorkoutOrRecovery(activity.type) else { return nil }

            if let linked = activity.healthKitWorkoutUUID, linkedUUIDs.contains(linked) {
                return nil
            }
            if activity.healthKitWorkoutUUID != nil {
                return nil
            }

            let sourceNormalized = activity.source
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let isPlanner = sourceNormalized == "planner"
            let isRecovery = activity.type
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == "recovery"

            return AskCoachCompletedSession(
                id: activity.id,
                startDate: activity.startDate,
                durationMinutes: max(1, activity.durationMinutes),
                healthKitWorkoutUUID: nil,
                source: .localCompleted,
                isPlannerSourced: isPlanner,
                isRecoveryActivity: isRecovery
            )
        }

        return (hkSessions + localSessions).sorted { $0.startDate < $1.startDate }
    }

    /// Planner workout/recovery slots in range (for planned-vs-completed, not Quick Start).
    static func plannerSlots(
        from local: [LocalCompletedCandidate]
    ) -> (planned: Int, completed: Int) {
        var planned = 0
        var completed = 0
        for activity in local {
            let source = activity.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard source == "planner" else { continue }
            guard isWorkoutOrRecovery(activity.type) else { continue }
            guard !activity.isSkipped else { continue }
            planned += 1
            if activity.isCompleted || activity.healthKitWorkoutUUID != nil {
                completed += 1
            }
        }
        return (planned, completed)
    }

    static func sessions(
        _ sessions: [AskCoachCompletedSession],
        on dayStart: Date,
        calendar: Calendar = .current
    ) -> [AskCoachCompletedSession] {
        sessions.filter { calendar.isDate($0.startDate, inSameDayAs: dayStart) }
    }

    private static func isWorkoutOrRecovery(_ type: String) -> Bool {
        switch type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "workout", "recovery":
            return true
        default:
            return false
        }
    }
}
