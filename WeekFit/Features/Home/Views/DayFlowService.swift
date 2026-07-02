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
                    label: WeekFitLocalizedString("today.dayFlow.live"),
                    title: $0.title,
                    subtitle: WeekFitLocalizedString("today.dayFlow.happeningNow"),
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
                    label: WeekFitLocalizedString("today.dayFlow.next"),
                    title: $0.title,
                    subtitle: WeekFitLocalizedString("today.dayFlow.planned"),
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
                    label: WeekFitLocalizedString(
                        $0.isSkipped ? "today.dayFlow.skippedUpper" : "today.dayFlow.doneUpper"
                    ),
                    title: $0.title,
                    subtitle: WeekFitLocalizedString(
                        $0.isSkipped ? "today.dayFlow.skipped" : "today.dayFlow.completed"
                    ),
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

        return all.isEmpty ? [DayFlowItem.makeEmpty()] : all
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

    static func makeEmpty() -> DayFlowItem {
        DayFlowItem(
            id: "empty_day_flow",
            label: WeekFitLocalizedString("today.dayFlow.clear"),
            title: WeekFitLocalizedString("today.dayFlow.empty.title"),
            subtitle: WeekFitLocalizedString("today.dayFlow.empty.subtitle"),
            meta: WeekFitLocalizedString("today.dayFlow.empty.meta"),
            icon: "checkmark.circle.fill",
            color: WeekFitTheme.meal,
            state: .done,
            source: .system,
            date: .now,
            slot: .current
        )
    }
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
