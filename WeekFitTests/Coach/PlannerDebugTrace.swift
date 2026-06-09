import Foundation
@testable import WeekFit

struct PlannerDebugTrace {
    struct ReservedSlot: Equatable {
        let activityID: String
        let title: String
        let start: Date
        let end: Date
        let durationMinutes: Int
    }

    let reservedSlots: [ReservedSlot]
    let ignoredFoodAndDrinkIDs: [String]
    let conflictChecks: [String]

    var debugDescription: String {
        let slots = reservedSlots.map {
            "\($0.title)[\($0.activityID)] \($0.start)-\($0.end) duration=\($0.durationMinutes)"
        }
        return "reserved=\(slots) ignoredFoodDrinkIDs=\(ignoredFoodAndDrinkIDs) conflictChecks=\(conflictChecks)"
    }

    static func make(
        activities: [PlannedActivity],
        selectedDate: Date,
        calendar: Calendar = .current
    ) -> PlannerDebugTrace {
        let dayActivities = activities
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .filter { !$0.isSkipped }
            .sorted { $0.date < $1.date }

        let reservedSlots = dayActivities
            .filter(\.blocksPlannerTime)
            .map { activity in
                ReservedSlot(
                    activityID: activity.id,
                    title: activity.title,
                    start: activity.date,
                    end: calendar.date(
                        byAdding: .minute,
                        value: max(activity.effectiveDurationMinutes, 15),
                        to: activity.date
                    ) ?? activity.date,
                    durationMinutes: activity.effectiveDurationMinutes
                )
            }

        let ignoredFoodAndDrinkIDs = dayActivities
            .filter { !$0.blocksPlannerTime }
            .map(\.id)

        let conflictChecks = dayActivities
            .filter { !$0.blocksPlannerTime }
            .map { activity in
                let conflict = TimelineLayoutEngine.hasTimeConflict(
                    newStart: activity.date,
                    durationMinutes: max(activity.durationMinutes, 15),
                    activities: dayActivities,
                    excluding: nil,
                    calendar: calendar,
                    newEventBlocksPlannerTime: activity.blocksPlannerTime
                )
                return "\(activity.title):blocks=\(activity.blocksPlannerTime):conflict=\(conflict)"
            }

        return PlannerDebugTrace(
            reservedSlots: reservedSlots,
            ignoredFoodAndDrinkIDs: ignoredFoodAndDrinkIDs,
            conflictChecks: conflictChecks
        )
    }
}
