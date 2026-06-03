import SwiftUI

final class DayFlowService {

    func generate(
        plannedActivities: [PlannedActivity],
        selectedDate: Date,
        loggedWater: Double = 0,
        activeActivity: PlannedActivity? = nil
    ) -> [DayFlowItem] {

        let now = Date()
        let calendar = Calendar.current

        let activeItems = plannedActivities
            .filter {
                !$0.isCompleted &&
                !$0.isSkipped &&
                $0.date <= now &&
                (calendar.date(
                    byAdding: .minute,
                    value: $0.durationMinutes,
                    to: $0.date
                ) ?? $0.date) >= now
            }
            .map {
                DayFlowItem(
                    id: "active_\($0.id)",
                    label: "LIVE",
                    title: $0.title,
                    subtitle: "Happening now",
                    meta: activityTime($0.date),
                    icon: $0.icon.isEmpty ? "figure.run" : $0.icon,
                    color: $0.color,
                    state: .inProgress,
                    source: .activity,
                    date: $0.date,
                    slot: .current
                )
            }

        let upcomingItems = plannedActivities
            .filter {
                !$0.isCompleted &&
                !$0.isSkipped &&
                $0.date > now &&
                Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
            }
            .sorted { $0.date < $1.date }
            .prefix(3)
            .map {
                DayFlowItem(
                    id: "planned_\($0.id)",
                    label: "NEXT",
                    title: $0.title,
                    subtitle: "Planned",
                    meta: activityTime($0.date),
                    icon: $0.icon.isEmpty ? "sparkles" : $0.icon,
                    color: $0.color,
                    state: .planned,
                    source: .plan,
                    date: $0.date,
                    slot: .future
                )
            }

        let completedItems = plannedActivities
            .filter {
                ($0.isCompleted || $0.isSkipped) &&
                Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
            }
            .sorted { $0.date > $1.date }
            .map {
                DayFlowItem(
                    id: "done_\($0.id)",
                    label: $0.isSkipped ? "SKIPPED" : "DONE",
                    title: $0.title,
                    subtitle: $0.isSkipped ? "Skipped" : "Completed",
                    meta: activityTime($0.date),
                    icon: $0.icon.isEmpty ? "checkmark.circle.fill" : $0.icon,
                    color: $0.color,
                    state: $0.isSkipped ? .skipped : .done,
                    source: .plan,
                    date: $0.date,
                    slot: .past
                )
            }

        let all = (
            completedItems +
            activeItems +
            upcomingItems
        )
        .sorted { $0.date < $1.date }

        return all.isEmpty ? [DayFlowItem.empty] : all
    }

    private func activityTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct DayFlowItem: Identifiable {
    let id: String
    let label: String
    let title: String
    let subtitle: String
    let meta: String
    let icon: String
    let color: Color
    let state: DayFlowState
    let source: DayFlowSource
    let date: Date
    let slot: DayFlowSlot

    static let empty = DayFlowItem(
        id: "empty_day_flow",
        label: "CLEAR",
        title: "Nothing planned right now",
        subtitle: "Your current slot is open",
        meta: "Plan",
        icon: "checkmark.circle.fill",
        color: WeekFitTheme.meal,
        state: .done,
        source: .system,
        date: .now,
        slot: .current
    )
}

enum DayFlowState {
    case planned
    case inProgress
    case done
    case skipped
}

enum DayFlowSource {
    case plan
    case water
    case activity
    case system
}

enum DayFlowSlot {
    case past
    case current
    case future
}
