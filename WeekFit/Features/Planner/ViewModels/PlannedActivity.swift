import Foundation
import SwiftData
import SwiftUI

enum TimelineEventKind {
    case food
    case drink
    case workout
    case recovery
    case sauna
    case calendar
    case sleep
    case bodyWeight
    case mood
    case coachNote
    case plannedActivity
}

enum PlannedActivityTerminalState: String {
    case planned
    case active
    case completed
    case partial
    case cancelled
}

@Model
final class PlannedActivity {
    @Attribute(.unique) var id: String
    
    var healthKitWorkoutUUID: String?

    var date: Date
    var type: String
    var title: String
    var durationMinutes: Int
    var icon: String
    var imageName: String = ""

    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double

    var calories: Int = 0
    var protein: Int = 0
    var carbs: Int = 0
    var fats: Int = 0
    var fiber: Int = 0

    var isCompleted: Bool = false
    var isSkipped: Bool = false
    var source: String = "planner"
    
    var actualDurationMinutes: Int?

    init(
        id: String = UUID().uuidString,
        healthKitWorkoutUUID: String? = nil,
        date: Date,
        type: String,
        title: String,
        durationMinutes: Int,
        icon: String,
        imageName: String = "",
        colorRed: Double,
        colorGreen: Double,
        colorBlue: Double,
        calories: Int = 0,
        protein: Int = 0,
        carbs: Int = 0,
        fats: Int = 0,
        fiber: Int = 0,
        isCompleted: Bool = false,
        isSkipped: Bool = false,
        source: String = "planner"
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
    }
}

extension PlannedActivity {
    var color: Color {
        Color(red: colorRed, green: colorGreen, blue: colorBlue)
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

    var blocksPlannerTime: Bool {
        switch timelineEventKind {
        case .workout, .recovery, .sauna, .calendar, .sleep, .plannedActivity:
            return true
        case .food, .drink, .bodyWeight, .mood, .coachNote:
            return false
        }
    }
}

struct DisplayActivity: Identifiable {
    let id: String
    let timeString: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let calories: Int
    let isWater: Bool
    let totalWaterVolume: Double?
    let isCompleted: Bool
    let originalActivities: [PlannedActivity]
}

extension PlannedActivity {
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
