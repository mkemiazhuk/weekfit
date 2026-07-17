import Foundation
import WeekFitPlanner

/// Value snapshot of planner activity data for coach pipelines.
/// Coach snapshots must not retain live SwiftData `@Model` instances.
struct CoachPlannedActivitySnapshot: Equatable, Hashable, Sendable, Identifiable {
    let id: String
    let healthKitWorkoutUUID: String?
    let date: Date
    let type: String
    let title: String
    let durationMinutes: Int
    let icon: String
    let imageName: String
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let fiber: Int
    let isCompleted: Bool
    let isSkipped: Bool
    let source: String
    let actualDurationMinutes: Int?

    init(from activity: PlannedActivity) {
        id = activity.id
        healthKitWorkoutUUID = activity.healthKitWorkoutUUID
        date = activity.date
        type = activity.type
        title = activity.title
        durationMinutes = activity.durationMinutes
        icon = activity.icon
        imageName = activity.imageName
        colorRed = activity.colorRed
        colorGreen = activity.colorGreen
        colorBlue = activity.colorBlue
        calories = activity.calories
        protein = activity.protein
        carbs = activity.carbs
        fats = activity.fats
        fiber = activity.fiber
        isCompleted = activity.isCompleted
        isSkipped = activity.isSkipped
        source = activity.source
        actualDurationMinutes = activity.actualDurationMinutes
    }

    init(
        id: String = UUID().uuidString,
        healthKitWorkoutUUID: String? = nil,
        date: Date,
        type: String,
        title: String,
        durationMinutes: Int,
        icon: String = "",
        imageName: String = "",
        colorRed: Double = 0.2,
        colorGreen: Double = 0.6,
        colorBlue: Double = 0.9,
        calories: Int = 0,
        protein: Int = 0,
        carbs: Int = 0,
        fats: Int = 0,
        fiber: Int = 0,
        isCompleted: Bool = false,
        isSkipped: Bool = false,
        source: String = "planner",
        actualDurationMinutes: Int? = nil
    ) {
        self.id = id
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
        self.date = date
        self.type = type
        self.title = title
        self.durationMinutes = durationMinutes
        self.icon = icon
        self.imageName = imageName
        self.colorRed = colorRed
        self.colorGreen = colorGreen
        self.colorBlue = colorBlue
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.fiber = fiber
        self.isCompleted = isCompleted
        self.isSkipped = isSkipped
        self.source = source
        self.actualDurationMinutes = actualDurationMinutes
    }

    var effectiveDurationMinutes: Int {
        if isCompleted, let actualDurationMinutes, actualDurationMinutes > 0 {
            return actualDurationMinutes
        }
        return durationMinutes
    }

    var completionRatio: Double {
        guard durationMinutes > 0 else { return isCompleted ? 1 : 0 }
        return Double(effectiveDurationMinutes) / Double(durationMinutes)
    }

    var isPartialCompletion: Bool {
        guard isCompleted, !isSkipped else { return false }
        guard let actualDurationMinutes else { return false }
        return actualDurationMinutes > 0 && actualDurationMinutes < durationMinutes
    }

    var isFullCompletion: Bool {
        isCompleted && !isSkipped && !isPartialCompletion
    }

    var isWatchSynced: Bool {
        if healthKitWorkoutUUID?.isEmpty == false {
            return true
        }
        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedSource == "appleworkout" ||
            normalizedSource == "applewatch" ||
            normalizedSource == "healthkit"
    }

    var timelineEventKind: TimelineEventKind {
        let normalizedType = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedImageName = imageName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalizedImageName == "hydration" ||
            normalizedType == "drink" ||
            normalizedType == "water" ||
            normalizedSource == "hydration" ||
            normalizedSource == "waterlog" {
            return .drink
        }

        if normalizedType == "meal" ||
            normalizedType == "food" ||
            normalizedType == "snack" ||
            normalizedType == "nutrition" ||
            normalizedSource == "nutritionlog" ||
            normalizedSource == "foodlog" {
            return .food
        }

        if normalizedType == "bodyweight" || normalizedType == "body_weight" {
            return .bodyWeight
        }

        if normalizedType == "mood" || normalizedType == "checkin" || normalizedType == "check-in" {
            return .mood
        }

        if normalizedType == "coachnote" || normalizedType == "coach_note" {
            return .coachNote
        }

        if normalizedType == "calendar" || normalizedSource == "calendar" {
            return .calendar
        }

        if normalizedType == "sleep" ||
            normalizedTitle.contains("sleep") ||
            normalizedTitle.contains("rest") {
            return .sleep
        }

        if normalizedType == "workout" || normalizedType == "training" {
            return .workout
        }

        if normalizedType == "recovery" {
            if normalizedTitle.contains("sauna") {
                return .sauna
            }
            return .recovery
        }

        if normalizedTitle.contains("sauna") {
            return .sauna
        }

        return .plannedActivity
    }

    func terminalState(now: Date) -> PlannedActivityTerminalState {
        if isSkipped {
            return .cancelled
        }
        if isPartialCompletion {
            return .partial
        }
        if isCompleted {
            return .completed
        }
        if isActive(at: now) {
            return .active
        }
        return .planned
    }

    func isActive(at now: Date) -> Bool {
        guard !isCompleted, !isSkipped else { return false }
        let endDate = Calendar.current.date(
            byAdding: .minute,
            value: max(effectiveDurationMinutes, durationMinutes),
            to: date
        ) ?? date
        return date <= now && now <= endDate
    }
}

extension Array where Element == PlannedActivity {
    func coachSnapshots() -> [CoachPlannedActivitySnapshot] {
        map(CoachPlannedActivitySnapshot.init)
    }
}
