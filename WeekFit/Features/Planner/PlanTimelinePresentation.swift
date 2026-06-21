import SwiftUI
import WeekFitPlanner

enum PlanTimelineCategory: Equatable {
    case activity
    case recovery
    case nutrition

    var color: Color {
        switch self {
        case .activity:
            return Color(red: 0.46, green: 0.72, blue: 0.82)
        case .recovery:
            return Color(red: 0.66, green: 0.58, blue: 0.86)
        case .nutrition:
            return Color(red: 0.50, green: 0.74, blue: 0.54)
        }
    }

    var title: String {
        switch self {
        case .activity:
            return WeekFitLocalizedString("planner.timeline.category.activity")
        case .recovery:
            return WeekFitLocalizedString("planner.timeline.category.recovery")
        case .nutrition:
            return WeekFitLocalizedString("planner.timeline.category.nutrition")
        }
    }

    static func from(activity: PlannedActivity) -> PlanTimelineCategory {
        switch activity.timelineEventKind {
        case .food, .drink:
            return .nutrition
        case .workout:
            return .activity
        case .recovery, .sauna, .sleep:
            return .recovery
        case .plannedActivity, .calendar, .coachNote, .bodyWeight, .mood:
            let type = activity.type.lowercased()
            if type == "meal" { return .nutrition }
            if type == "recovery" { return .recovery }
            if type == "workout" { return .activity }
            if type == "habit" {
                return isHydrationHabit(activity) ? .nutrition : .recovery
            }
            return .activity
        }
    }

    private static func isHydrationHabit(_ activity: PlannedActivity) -> Bool {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()
        return type.contains("water")
            || type.contains("drink")
            || title.contains("water")
            || title.contains("hydration")
            || title.contains("drink")
    }
}

struct PlanTimelineRowMetadata: Equatable {
    let primary: String?
    let sourceLabel: String?
    let showsWatchIcon: Bool

    var isEmpty: Bool {
        (primary?.isEmpty ?? true)
            && (sourceLabel?.isEmpty ?? true)
            && !showsWatchIcon
    }
}

enum PlanTimelineMetadataBuilder {

    static func metadata(
        for item: PlanTimelineItem,
        customMeals: [Meals],
        status: PlanActivityStatus,
        formattedDuration: (Int) -> String,
        waterLogCountText: (Int) -> String
    ) -> PlanTimelineRowMetadata {
        switch item {
        case .single(let activity):
            return metadata(
                for: activity,
                customMeals: customMeals,
                status: status,
                formattedDuration: formattedDuration
            )

        case .waterGroup(let activities):
            return PlanTimelineRowMetadata(
                primary: waterLogCountText(activities.count),
                sourceLabel: WeekFitLocalizedString("planner.timeline.source.hydration"),
                showsWatchIcon: false
            )
        }
    }

    private static func metadata(
        for activity: PlannedActivity,
        customMeals: [Meals],
        status: PlanActivityStatus,
        formattedDuration: (Int) -> String
    ) -> PlanTimelineRowMetadata {
        let primary = primaryValue(
            for: activity,
            formattedDuration: formattedDuration
        )
        let watch = shouldShowWatchIcon(for: activity, status: status)
        let source = sourceLabel(for: activity, customMeals: customMeals)

        return PlanTimelineRowMetadata(
            primary: primary,
            sourceLabel: watch
                ? WeekFitLocalizedString("planner.timeline.source.appleWatch")
                : source,
            showsWatchIcon: watch
        )
    }

    private static func primaryValue(
        for activity: PlannedActivity,
        formattedDuration: (Int) -> String
    ) -> String? {
        if let quickLogPrimary = QuickLogActivityPortions.metadataPrimary(for: activity) {
            return quickLogPrimary
        }

        let type = activity.type.lowercased()

        if type == "meal", activity.calories > 0 {
            return String(
                format: WeekFitLocalizedString("nutrition.details.meal.caloriesFormat"),
                activity.calories
            )
        }

        if isDrinkActivity(activity) {
            return nil
        }

        if activity.durationMinutes > 0 {
            return formattedDuration(activity.durationMinutes)
        }

        return nil
    }

    private static func sourceLabel(
        for activity: PlannedActivity,
        customMeals: [Meals]
    ) -> String? {
        if PlanTimelineNutritionVisualResolver.isDrinkActivity(activity)
            || activity.timelineEventKind == .drink {
            if PlanTimelineNutritionVisualResolver.isWaterActivity(activity) {
                return WeekFitLocalizedString("planner.timeline.source.hydration")
            }
            return WeekFitLocalizedString("planner.timeline.source.drink")
        }

        guard activity.type.lowercased() == "meal"
            || activity.timelineEventKind == .food else {
            return nil
        }

        if let meal = matchingCustomMeal(for: activity, in: customMeals) {
            if meal.creationMode == .ingredients {
                return WeekFitLocalizedString("planner.timeline.source.recipe")
            }
            if meal.isFoodProduct || meal.creationMode == .manual {
                return WeekFitLocalizedString("meals.customFood")
            }
            return WeekFitLocalizedString("planner.timeline.source.meal")
        }

        if PlanTimelineFoodVisualResolver.isCustomFoodSource(activity, customMeals: customMeals) {
            return WeekFitLocalizedString("meals.customFood")
        }

        return WeekFitLocalizedString("planner.timeline.source.meal")
    }

    private static func shouldShowWatchIcon(
        for activity: PlannedActivity,
        status: PlanActivityStatus
    ) -> Bool {
        guard activity.isWatchSynced else { return false }
        guard status == .logged || status == .completed || status == .live else { return false }
        guard activity.healthKitWorkoutUUID?.isEmpty == false else { return false }
        return true
    }

    private static func matchingCustomMeal(
        for activity: PlannedActivity,
        in customMeals: [Meals]
    ) -> Meals? {
        guard activity.type.lowercased() == "meal" else { return nil }

        let normalizedTitle = CustomMealStore.normalizedTitle(activity.title)
        guard !normalizedTitle.isEmpty else { return nil }

        return customMeals.first {
            CustomMealStore.normalizedTitle($0.title) == normalizedTitle
        }
    }

    private static func isDrinkActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()

        return type.contains("water")
            || type.contains("drink")
            || title.contains("water")
            || title.contains("hydration")
            || title.contains("drink")
    }
}

enum PlanTimelineItem: Identifiable {
    case single(PlannedActivity)
    case waterGroup([PlannedActivity])

    var id: String {
        switch self {
        case .single(let activity):
            return activity.id
        case .waterGroup(let activities):
            return "water-\(activities.map(\.id).joined(separator: "-"))"
        }
    }

    var firstDate: Date {
        switch self {
        case .single(let activity):
            return activity.date
        case .waterGroup(let activities):
            return activities.first?.date ?? Date()
        }
    }

    var representative: PlannedActivity {
        switch self {
        case .single(let activity):
            return activity
        case .waterGroup(let activities):
            return activities.first!
        }
    }

    var count: Int {
        switch self {
        case .single:
            return 1
        case .waterGroup(let activities):
            return activities.count
        }
    }
}

enum PlanTimelineVisualEmphasis: Equatable {
    case past
    case skipped
    case upcoming
    case active
    case next
}

enum PlanTimelineEmphasisResolver {

    static func focusItemID(
        in items: [PlanTimelineItem],
        statusFor activityStatus: (PlannedActivity) -> PlanActivityStatus,
        selectedDay: Date,
        now: Date = Date()
    ) -> String? {
        let calendar = Calendar.current
        let selectedStart = calendar.startOfDay(for: selectedDay)
        let todayStart = calendar.startOfDay(for: now)

        guard selectedStart >= todayStart else { return nil }

        for item in items {
            switch activityStatus(item.representative) {
            case .live, .pending, .upcoming:
                return item.id
            case .completed, .logged, .skipped:
                continue
            }
        }

        return nil
    }

    static func emphasis(
        for item: PlanTimelineItem,
        status: PlanActivityStatus,
        focusItemID: String?
    ) -> PlanTimelineVisualEmphasis {
        if item.id == focusItemID {
            return .next
        }

        switch status {
        case .completed, .logged:
            return .past
        case .skipped:
            return .skipped
        case .live, .pending:
            return .active
        case .upcoming:
            return .upcoming
        }
    }

    static func shouldShowNowDivider(
        at index: Int,
        in items: [PlanTimelineItem],
        focusItemID: String?,
        statusFor activityStatus: (PlannedActivity) -> PlanActivityStatus
    ) -> Bool {
        guard let focusItemID,
              index > 0,
              items[index].id == focusItemID else {
            return false
        }

        switch activityStatus(items[index - 1].representative) {
        case .completed, .logged, .skipped:
            return true
        case .live, .pending, .upcoming:
            return false
        }
    }
}
