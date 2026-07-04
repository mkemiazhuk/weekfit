import Foundation
import WeekFitPlanner

enum CoachCanonicalDayState {
    static func selectedDayActivities(
        from activities: [PlannedActivity],
        selectedDate: Date,
        calendar: Calendar = .current
    ) -> [PlannedActivity] {
        activities
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    static func completedMeals(from activities: [PlannedActivity]) -> [PlannedActivity] {
        activities
            .filter {
                isNutritionLog($0) &&
                    $0.isCompleted &&
                    !$0.isSkipped &&
                    !isHydrationLog($0)
            }
            .sorted { $0.date < $1.date }
    }

    static func coachRelevantActivities(from activities: [PlannedActivity]) -> [PlannedActivity] {
        activities
            .filter(isCoachRelevantActivity)
            .sorted { $0.date < $1.date }
    }

    static func coachRelevantSnapshots(from activities: [CoachPlannedActivitySnapshot]) -> [CoachPlannedActivitySnapshot] {
        activities
            .filter(isCoachRelevantSnapshot)
            .sorted { $0.date < $1.date }
    }

    static func isCoachRelevantActivity(_ activity: PlannedActivity) -> Bool {
        guard !activity.isSkipped else { return false }
        guard !isNutritionLog(activity) else { return false }
        guard !isHydrationLog(activity) else { return false }

        switch CoachActivityContextResolver.kind(for: CoachPlannedActivitySnapshot(from: activity)) {
        case .workout, .endurance, .recovery, .heat:
            return true
        case .meal, .other:
            return false
        }
    }

    static func isCoachRelevantSnapshot(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        guard !activity.isSkipped else { return false }
        guard !isNutritionLog(activity) else { return false }
        guard !isHydrationLog(activity) else { return false }

        switch CoachActivityContextResolver.kind(for: activity) {
        case .workout, .endurance, .recovery, .heat:
            return true
        case .meal, .other:
            return false
        }
    }

    static func isNutritionLog(_ activity: PlannedActivity) -> Bool {
        isNutritionLog(CoachPlannedActivitySnapshot(from: activity))
    }

    static func isHydrationLog(_ activity: PlannedActivity) -> Bool {
        isHydrationLog(CoachPlannedActivitySnapshot(from: activity))
    }

    static func isNutritionLog(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        let text = "\(activity.type) \(activity.title) \(activity.imageName) \(activity.source)".lowercased()
        let type = activity.type.lowercased()

        return type == "drink" ||
            text.contains("meal") ||
            text.contains("food") ||
            text.contains("snack") ||
            text.contains("breakfast") ||
            text.contains("lunch") ||
            text.contains("dinner") ||
            text.contains("coffee") ||
            text.contains("espresso") ||
            text.contains("cappuccino") ||
            text.contains("latte")
    }

    static func isHydrationLog(_ activity: CoachPlannedActivitySnapshot) -> Bool {
        let text = "\(activity.type) \(activity.title) \(activity.imageName)".lowercased()

        return text.contains("hydration") ||
            text.contains("water")
    }
}
