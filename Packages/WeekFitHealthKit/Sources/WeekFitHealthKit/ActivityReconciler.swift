import Foundation
import HealthKit
import OSLog
import WeekFitPlanner

public enum ActivityReconciler {
    public static let pastMatchingWindow: TimeInterval = 60 * 60
    /// Prefer leaving unresolved over auto-completing a distant planned slot.
    public static let startProximityWindow: TimeInterval = 30 * 60

    /// Only an explicitly live Watch session may treat a HealthKit sample as
    /// still in progress. A workout whose `endDate` is "now" is the normal
    /// completion event from Apple Watch — treating that as live left the
    /// planned slot unfinished and blocked later sync.
    public static func isLikelyInProgress(
        _ workout: HKWorkout,
        now: Date = Date(),
        liveSessionActive: Bool = false
    ) -> Bool {
        guard liveSessionActive else { return false }
        return now.timeIntervalSince(workout.endDate) <= 90
            && workout.endDate >= workout.startDate
    }

    public static func sameFamily(_ lhs: PlannedActivity, _ rhs: PlannedActivity) -> Bool {
        guard let left = normalizedFamily(for: lhs),
              let right = normalizedFamily(for: rhs) else {
            return false
        }
        return familiesAreCompatible(left, right)
    }

    public static func bestMatch(
        for workout: HKWorkout,
        in activities: [PlannedActivity],
        calendar: Calendar = .current,
        now: Date = Date(),
        liveSessionActive: Bool = false
    ) -> PlannedActivity? {
        let workoutTitle = title(for: workout.workoutActivityType)
        let workoutStart = workout.startDate
        let workoutEnd = workout.endDate
        let allPlanned = activities.filter { activity in
            samePlannedWorkoutDay(activity.date, workout: workout, calendar: calendar) &&
            !activity.isSkipped &&
            activity.healthKitWorkoutUUID == nil
        }

        let plannedBeforeEnd = allPlanned.filter { $0.date <= workoutEnd }
        let plannedAfterEnd = allPlanned.filter { $0.date > workoutEnd }

        let eligible = allPlanned.compactMap { activity -> MatchCandidate? in
            guard matches(activity: activity, workoutType: workout.workoutActivityType) else {
                return nil
            }

            guard durationIsCompatible(
                activity: activity,
                workout: workout,
                now: now,
                liveSessionActive: liveSessionActive
            ) else {
                return nil
            }

            guard let timing = timingMatch(activity: activity, workout: workout) else {
                return nil
            }

            return MatchCandidate(
                activity: activity,
                score: matchScore(activity: activity, workout: workout, timing: timing)
            )
        }

        let selected = eligible.min { $0.score < $1.score }?.activity

        ActivityReconciliationDebug.log(
            syncedActivityTitle: workoutTitle,
            syncedStart: workoutStart,
            syncedEnd: workoutEnd,
            plannedCandidatesBeforeEnd: plannedBeforeEnd.map(\.title),
            plannedCandidatesAfterEnd: plannedAfterEnd.map(\.title),
            selectedMatch: selected?.title,
            ignoredFutureCandidates: plannedAfterEnd.map(\.title),
            reason: selected == nil ? noMatchReason(
                eligibleCount: eligible.count,
                beforeEndCount: plannedBeforeEnd.count,
                afterEndCount: plannedAfterEnd.count
            ) : "selected nearest eligible past planned activity"
        )

        return selected
    }

    public static func importedActivity(for workout: HKWorkout) -> PlannedActivity {
        let imported = PlannedActivity(
            healthKitWorkoutUUID: workout.uuid.uuidString,
            date: workout.startDate,
            type: "workout",
            title: title(for: workout.workoutActivityType),
            durationMinutes: max(1, Int(workout.duration / 60)),
            icon: icon(for: workout.workoutActivityType),
            colorRed: 0.46,
            colorGreen: 0.72,
            colorBlue: 0.82,
            isCompleted: true,
            isSkipped: false,
            source: "appleWorkout"
        )
        imported.actualDurationMinutes = max(1, Int((workout.endDate.timeIntervalSince(workout.startDate) / 60).rounded()))
        imported.id = workout.uuid.uuidString
        return imported
    }

    public static func importedLiveActivity(for workout: HKWorkout) -> PlannedActivity {
        let imported = importedActivity(for: workout)
        imported.isCompleted = false
        return imported
    }

    /// Attach a still-running workout to a planned slot without completing it.
    public static func applyLiveWorkout(_ workout: HKWorkout, to activity: PlannedActivity) {
        let elapsedMinutes = max(1, Int((workout.endDate.timeIntervalSince(workout.startDate) / 60).rounded()))
        activity.date = workout.startDate
        activity.actualDurationMinutes = elapsedMinutes
        activity.isCompleted = false
        activity.isSkipped = false
        activity.healthKitWorkoutUUID = workout.uuid.uuidString
    }

    public static func applySyncedWorkout(_ workout: HKWorkout, to activity: PlannedActivity) {
        let actualMinutes = max(1, Int((workout.endDate.timeIntervalSince(workout.startDate) / 60).rounded()))

        activity.date = workout.startDate
        activity.durationMinutes = actualMinutes
        activity.actualDurationMinutes = actualMinutes
        activity.isCompleted = true
        activity.isSkipped = false
        activity.healthKitWorkoutUUID = workout.uuid.uuidString
        activity.source = "appleWorkout"
        activity.type = "workout"
        activity.title = title(for: workout.workoutActivityType)
        activity.icon = icon(for: workout.workoutActivityType)
    }

    public static func title(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .cycling:
            return "Cycling"
        case .running:
            return "Running"
        case .walking:
            return "Walk"
        case .hiking:
            return "Hiking"
        case .traditionalStrengthTraining,
             .functionalStrengthTraining:
            return "Strength Workout"
        case .highIntensityIntervalTraining:
            return "HIIT Workout"
        case .yoga:
            return "Yoga"
        case .swimming:
            return "Swimming"
        case .coreTraining:
            return "Core Training"
        case .tennis:
            return "Tennis"
        case .squash:
            return "Squash"
        case .snowboarding:
            return "Snowboarding"
        default:
            return "Workout"
        }
    }

    public static func icon(for type: HKWorkoutActivityType) -> String {
        WeekFitActivityIconResolver.resolve(
            storedIcon: nil,
            title: title(for: type),
            type: "workout"
        )
    }

    public static func matches(
        activity: PlannedActivity,
        workoutType: HKWorkoutActivityType
    ) -> Bool {
        guard let activityFamily = normalizedFamily(for: activity),
              let workoutFamily = normalizedFamily(for: workoutType) else {
            return false
        }

        return familiesAreCompatible(activityFamily, workoutFamily)
    }

    private static func durationIsCompatible(
        activity: PlannedActivity,
        workout: HKWorkout,
        now: Date,
        liveSessionActive: Bool
    ) -> Bool {
        if isLikelyInProgress(workout, now: now, liveSessionActive: liveSessionActive) {
            return true
        }

        let plannedMinutes = max(activity.durationMinutes, 1)
        let actualMinutes = max(1, Int((workout.endDate.timeIntervalSince(workout.startDate) / 60).rounded()))

        // Short auto-detected strolls must not close a much longer planned slot.
        // Going longer than planned is the normal Watch case ("I kept walking").
        if actualMinutes < plannedMinutes {
            let shortTolerance = max(20, plannedMinutes / 2)
            return (plannedMinutes - actualMinutes) <= shortTolerance
        }

        return true
    }

    private struct MatchCandidate {
        let activity: PlannedActivity
        let score: Double
    }

    private struct TimingMatch {
        let overlapSeconds: TimeInterval
        let startDeltaSeconds: TimeInterval
    }

    private enum NormalizedActivityFamily {
        case cycling
        case running
        case walking
        case hiking
        case strength
        case core
        case yoga
        case stretching
        case mobility
        case sauna
        case breathing
        case recovery
        case tennis
        case squash
        case swimming
        case snowboarding
        case hiit
    }

    private static func samePlannedWorkoutDay(
        _ plannedDate: Date,
        workout: HKWorkout,
        calendar: Calendar
    ) -> Bool {
        calendar.isDate(plannedDate, inSameDayAs: workout.startDate) ||
        calendar.isDate(plannedDate, inSameDayAs: workout.endDate)
    }

    private static func timingMatch(activity: PlannedActivity, workout: HKWorkout) -> TimingMatch? {
        let plannedStart = activity.date
        let plannedEnd = plannedStart.addingTimeInterval(TimeInterval(max(activity.durationMinutes, 1) * 60))
        let actualStart = workout.startDate
        let actualEnd = workout.endDate
        let overlapSeconds = max(
            0,
            min(plannedEnd, actualEnd).timeIntervalSince(max(plannedStart, actualStart))
        )
        let startDeltaSeconds = abs(actualStart.timeIntervalSince(plannedStart))

        guard overlapSeconds > 0 || startDeltaSeconds <= startProximityWindow else {
            return nil
        }

        return TimingMatch(overlapSeconds: overlapSeconds, startDeltaSeconds: startDeltaSeconds)
    }

    private static func matchScore(
        activity: PlannedActivity,
        workout: HKWorkout,
        timing: TimingMatch
    ) -> Double {
        let overlapBonus = min(timing.overlapSeconds / 60, 60)
        let completedPenalty = activity.isCompleted ? 40.0 : 0
        // Duration is a hard gate in bestMatch; score is timing-only.
        return (timing.startDeltaSeconds / 60) - overlapBonus + completedPenalty
    }

    private static func familiesAreCompatible(
        _ planned: NormalizedActivityFamily,
        _ workout: NormalizedActivityFamily
    ) -> Bool {
        if planned == workout {
            return true
        }

        // Core ↔ strength share the same training family; HIIT stays distinct.
        switch (planned, workout) {
        case (.core, .strength),
             (.strength, .core):
            return true
        default:
            return false
        }
    }

    private static func normalizedFamily(for activity: PlannedActivity) -> NormalizedActivityFamily? {
        let text = [
            activity.title,
            activity.type,
            activity.imageName
        ]
            .joined(separator: " ")
            .lowercased()

        if containsAny(text, ["sauna", "баня", "сауна"]) {
            return .sauna
        }

        if containsAny(text, ["breath", "breathing", "meditation", "mind and body", "дых", "медитац"]) {
            return .breathing
        }

        if containsAny(text, ["yoga", "йога"]) {
            return .yoga
        }

        if containsAny(text, ["stretch", "stretching", "flexibility", "растяж"]) {
            return .stretching
        }

        if containsAny(text, ["mobility", "мобил"]) {
            return .mobility
        }

        if containsAny(text, ["cycle", "cycling", "bike", "ride", "bicycle", "вел", "вело"]) {
            return .cycling
        }

        if containsAny(text, ["run", "running", "бег"]) {
            return .running
        }

        if containsAny(text, ["walk", "walking", "ходь", "прогул"]) {
            return .walking
        }

        if containsAny(text, ["hike", "hiking"]) {
            return .hiking
        }

        if containsAny(text, ["core", "abs", "abdominal", "кор", "пресс"]) {
            return .core
        }

        if containsAny(text, ["full body", "full-body", "upper body", "lower body", "strength", "gym", "dumbbell", "functional strength", "traditional strength", "сил"]) {
            return .strength
        }

        if containsAny(text, ["hiit", "high intensity"]) {
            return .hiit
        }

        if containsAny(text, ["tennis", "теннис"]) {
            return .tennis
        }

        if containsAny(text, ["squash", "сквош"]) {
            return .squash
        }

        if containsAny(text, ["swim", "swimming", "pool", "плав"]) {
            return .swimming
        }

        if containsAny(text, ["snowboard", "snowboarding", "сноуборд"]) {
            return .snowboarding
        }

        if containsAny(text, ["recovery", "cooldown", "cool down", "восстанов", "заминка"]) {
            return .recovery
        }

        return nil
    }

    private static func normalizedFamily(for type: HKWorkoutActivityType) -> NormalizedActivityFamily? {
        switch type {
        case .walking:
            return .walking
        case .running:
            return .running
        case .cycling:
            return .cycling
        case .hiking:
            return .hiking
        case .yoga:
            return .yoga
        case .coreTraining:
            return .core
        case .tennis:
            return .tennis
        case .squash:
            return .squash
        case .swimming:
            return .swimming
        case .snowboarding:
            return .snowboarding
        case .traditionalStrengthTraining,
             .functionalStrengthTraining:
            return .strength
        case .highIntensityIntervalTraining,
             .crossTraining:
            return .hiit
        case .flexibility:
            return .stretching
        default:
            return nil
        }
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func noMatchReason(
        eligibleCount: Int,
        beforeEndCount: Int,
        afterEndCount: Int
    ) -> String {
        if eligibleCount > 0 {
            return "eligible candidates existed but no selection was made"
        }

        if beforeEndCount == 0 && afterEndCount > 0 {
            return "only future planned candidates found; leaving them untouched"
        }

        if beforeEndCount == 0 {
            return "no planned candidates before synced end"
        }

        return "no past planned candidate passed type/title/duration matching"
    }
}

enum ActivityReconciliationDebug {
    private static let logger = Logger(subsystem: "WeekFit", category: "ActivityReconciliation")
    /// Set to `true` temporarily when diagnosing HealthKit ↔ plan matching.
    private static let loggingEnabled = false

    static func log(
        syncedActivityTitle: String,
        syncedStart: Date,
        syncedEnd: Date,
        plannedCandidatesBeforeEnd: [String],
        plannedCandidatesAfterEnd: [String],
        selectedMatch: String?,
        ignoredFutureCandidates: [String],
        reason: String
    ) {
        guard loggingEnabled else { return }
        logger.debug(
            "syncedActivityTitle=\"\(syncedActivityTitle, privacy: .public)\" syncedStart=\(syncedStart, privacy: .public) syncedEnd=\(syncedEnd, privacy: .public) plannedCandidatesBeforeEnd=\(plannedCandidatesBeforeEnd, privacy: .public) plannedCandidatesAfterEnd=\(plannedCandidatesAfterEnd, privacy: .public) selectedMatch=\(selectedMatch ?? "nil", privacy: .public) ignoredFutureCandidates=\(ignoredFutureCandidates, privacy: .public) reason=\"\(reason, privacy: .public)\""
        )
    }
}
