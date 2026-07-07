import Foundation
import WeekFitPlanner

/// Planned activity facts for Coach copy — calendar title and start time only.
struct CoachPlannedActivitySummary: Equatable, Sendable {
    let title: String
    let startHour: Int
    let startMinute: Int
    let durationMinutes: Int
    let activityType: CoachActivityType

    var formattedStartTime: String {
        String(format: "%d:%02d", startHour, startMinute)
    }

    static func from(activity: CoachPlannedActivitySnapshot, calendar: Calendar = .current) -> CoachPlannedActivitySummary {
        let components = calendar.dateComponents([.hour, .minute], from: activity.date)
        return CoachPlannedActivitySummary(
            title: activity.title.trimmingCharacters(in: .whitespacesAndNewlines),
            startHour: components.hour ?? 0,
            startMinute: components.minute ?? 0,
            durationMinutes: activity.effectiveDurationMinutes,
            activityType: CoachActivityClassifier.type(for: activity)
        )
    }
}
