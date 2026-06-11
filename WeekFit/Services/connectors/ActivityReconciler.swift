import Foundation
import HealthKit

enum ActivityReconciler {
    static let pastMatchingWindow: TimeInterval = 60 * 60

    static func bestMatch(
        for workout: HKWorkout,
        in activities: [PlannedActivity],
        calendar: Calendar = .current
    ) -> PlannedActivity? {
        let workoutTitle = title(for: workout.workoutActivityType)
        let workoutEnd = workout.endDate
        let allPlanned = activities.filter { activity in
            calendar.isDate(activity.date, inSameDayAs: workoutEnd) &&
            !activity.isSkipped &&
            activity.healthKitWorkoutUUID == nil
        }

        let plannedBeforeEnd = allPlanned.filter { $0.date <= workoutEnd }
        let plannedAfterEnd = allPlanned.filter { $0.date > workoutEnd }

        let eligible = plannedBeforeEnd.filter { activity in
            let secondsBeforeEnd = workoutEnd.timeIntervalSince(activity.date)
            return secondsBeforeEnd >= 0 &&
            secondsBeforeEnd <= pastMatchingWindow &&
            matches(activity: activity, workoutType: workout.workoutActivityType) &&
            durationIsCompatible(activity: activity, workout: workout)
        }

        let selected = eligible.min {
            abs($0.date.timeIntervalSince(workoutEnd)) <
            abs($1.date.timeIntervalSince(workoutEnd))
        }

        ActivityReconciliationDebug.log(
            syncedActivityTitle: workoutTitle,
            syncedStart: workout.startDate,
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

    static func importedActivity(for workout: HKWorkout) -> PlannedActivity {
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

    static func title(for type: HKWorkoutActivityType) -> String {
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

    static func icon(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .cycling:
            return "bicycle"
        case .running:
            return "figure.run"
        case .walking:
            return "figure.walk"
        case .hiking:
            return "figure.hiking"
        case .traditionalStrengthTraining,
             .functionalStrengthTraining:
            return "dumbbell.fill"
        case .highIntensityIntervalTraining:
            return "flame.fill"
        case .yoga:
            return "figure.yoga"
        case .swimming:
            return "figure.pool.swim"
        case .coreTraining:
            return "figure.core.training"
        case .tennis:
            return "figure.tennis"
        case .squash:
            return "figure.squash"
        case .snowboarding:
            return "figure.snowboarding"
        default:
            return "figure.run"
        }
    }

    static func matches(
        activity: PlannedActivity,
        workoutType: HKWorkoutActivityType
    ) -> Bool {
        let title = activity.title.lowercased()
        let keywords = normalizedWorkoutKeywords(for: workoutType)

        guard !keywords.isEmpty else {
            return false
        }

        return keywords.contains {
            title.contains($0)
        }
    }

    private static func durationIsCompatible(activity: PlannedActivity, workout: HKWorkout) -> Bool {
        let plannedMinutes = max(activity.durationMinutes, 1)
        let actualMinutes = max(1, Int((workout.endDate.timeIntervalSince(workout.startDate) / 60).rounded()))
        let tolerance = max(20, plannedMinutes / 2)

        return abs(plannedMinutes - actualMinutes) <= tolerance
    }

    private static func normalizedWorkoutKeywords(for type: HKWorkoutActivityType) -> [String] {
        switch type {
        case .walking:
            return ["walk", "walking", "ходь"]
        case .running:
            return ["run", "running", "бег"]
        case .cycling:
            return ["cycle", "cycling", "bike", "ride", "вел", "вело"]
        case .hiking:
            return ["hike", "hiking"]
        case .yoga:
            return ["yoga", "йога"]
        case .coreTraining:
            return ["core", "abs", "abdominal", "кор", "пресс"]
        case .tennis:
            return ["tennis", "теннис"]
        case .squash:
            return ["squash", "сквош"]
        case .swimming:
            return ["swim", "swimming", "pool", "плав"]
        case .snowboarding:
            return ["snowboard", "snowboarding", "сноуборд"]
        case .traditionalStrengthTraining,
             .functionalStrengthTraining,
             .highIntensityIntervalTraining,
             .crossTraining:
            return ["workout", "strength", "gym", "training", "трен", "hiit", "сил"]
        case .flexibility:
            return ["stretch", "stretching", "mobility", "flexibility", "растяж"]
        case .pilates:
            return ["pilates", "пилатес"]
        case .mindAndBody:
            return ["mind", "body", "meditation", "breathing", "breath", "медитац", "дых"]
        case .cooldown:
            return ["cooldown", "cool down", "recovery", "заминка", "восстанов"]
        default:
            return []
        }
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
        CoachLogger.verbose(
            "[ActivityReconciliationDebug]",
            "syncedActivityTitle=\"\(syncedActivityTitle)\" syncedStart=\(syncedStart) syncedEnd=\(syncedEnd) plannedCandidatesBeforeEnd=\(plannedCandidatesBeforeEnd) plannedCandidatesAfterEnd=\(plannedCandidatesAfterEnd) selectedMatch=\(selectedMatch ?? "nil") ignoredFutureCandidates=\(ignoredFutureCandidates) reason=\"\(reason)\""
        )
    }
}
