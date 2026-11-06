import Foundation
import SwiftData
import SwiftUI
import WeekFitPlanner

enum ActivityBadgeRoute: Equatable {
    case collection(highlight: String?)
    case start(badgeID: String)
    case logWater
}

@MainActor
enum ActivityBadgeCenter {
    static let routeNotification = Notification.Name("activityBadgeRoute")

    static func refresh(
        activities: [PlannedActivity],
        waterGoalLiters: Double,
        now: Date = Date(),
        store: ActivityBadgeStore = .shared
    ) {
        let goal = waterGoalLiters > 0 ? Int((waterGoalLiters * 1000).rounded()) : 0
        var ledger = store.ledger
        ActivityBadgeEngine.ingest(
            activities.map(input(from:)),
            waterGoalMilliliters: goal,
            now: now,
            into: &ledger
        )
        ledger.suggestedBadgeID = ActivityBadgeEngine.suggestionID(
            ledger: ledger,
            inputs: activities.map(input(from:)),
            now: now
        )
        store.replace(ledger)
    }

    static func noteLiveFinish(_ activity: PlannedActivity, elapsedSeconds: Int, store: ActivityBadgeStore = .shared) {
        store.noteLiveFinish(
            recordID: activity.id,
            elapsedSeconds: elapsedSeconds,
            catalogTitle: activity.title
        )
    }

    /// Starts the badge action. Returns true when Today should open the water log.
    @discardableResult
    static func start(
        _ badge: ActivityBadgeDisplay,
        activities: [PlannedActivity],
        modelContext: ModelContext,
        waterGoalLiters: Double,
        now: Date = Date()
    ) -> Bool {
        let awardID = ActivityBadgeEngine.awardBaseID(badge.id)
        if awardID == "habit.drink-water" {
            return true
        }
        let custom = awardID.hasPrefix(ActivityBadgeEngine.customPrefix)
        if custom || ActivityBadgeCatalog.definition(id: awardID)?.requirement == .habitCheckIn {
            let calendar = Calendar.current
            let title = ActivityBadgeCatalog.definition(id: awardID)?.catalogTitle ?? badge.activityName
            if let planned = activities.first(where: {
                !$0.isCompleted && !$0.isSkipped
                    && calendar.isDate($0.date, inSameDayAs: now)
                    && ActivityBadgeCatalog.normalize($0.title) == ActivityBadgeCatalog.normalize(title)
            }) {
                planned.isCompleted = true
                try? modelContext.save()
                noteLiveFinish(planned, elapsedSeconds: 60)
                refresh(activities: activities, waterGoalLiters: waterGoalLiters, now: now)
            }
            return false
        }
        guard let definition = ActivityBadgeCatalog.definition(id: awardID) else { return false }
        let plannerType: PlannerType = definition.category == .activity ? .workout : .recovery
        guard let option = plannerType.options.first(where: { $0.title == definition.catalogTitle }) else { return false }
        let components = plannerType.colorComponents
        let activity = PlannedActivity(
            date: now,
            type: plannerType.title.lowercased(),
            title: option.title,
            durationMinutes: definition.actionMinutes ?? 20,
            icon: option.icon,
            imageName: option.imageName,
            colorRed: components.red,
            colorGreen: components.green,
            colorBlue: components.blue,
            isCompleted: false,
            source: "today"
        )
        modelContext.insert(activity)
        try? modelContext.save()
        return false
    }

    static func display(
        id: String,
        activities: [PlannedActivity],
        store: ActivityBadgeStore = .shared
    ) -> ActivityBadgeDisplay? {
        let inputs = activities.map(input(from:))
        return ActivityBadgePresenter.sections(
            ledger: store.ledger,
            inputs: inputs,
            activityName: { PlannerOptionLocalization.localizedTitle(for: $0) }
        )
        .flatMap(\.cells)
        .first { $0.id == id }
    }

    static func renameHabitIfNeeded(from oldTitle: String, to newTitle: String, store: ActivityBadgeStore = .shared) {
        var ledger = store.ledger
        ActivityBadgeEngine.renameCustomHabit(from: oldTitle, to: newTitle, ledger: &ledger)
        store.replace(ledger)
    }

    static func input(from activity: PlannedActivity) -> ActivityBadgeInput {
        ActivityBadgeInput(
            recordID: activity.id,
            title: activity.title,
            type: activity.type,
            imageName: activity.imageName,
            isCompleted: activity.isCompleted,
            isSkipped: activity.isSkipped,
            startedAt: activity.date,
            durationMinutes: activity.durationMinutes,
            actualDurationMinutes: activity.actualDurationMinutes,
            source: activity.source,
            waterMilliliters: QuickLogActivityPortions.waterMilliliters(for: activity)
        )
    }
}
