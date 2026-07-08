import SwiftUI
import SwiftData
internal import Combine

@MainActor
final class PlanViewModel: ObservableObject {

    private let lifecycleToken = "PlanViewModel"

    // MARK: - Timeline constants
    let timelineStartHour = 5
    let timelineEndHour = 24
    let timelineMinuteStep = 15
    let timelineMinimumDurationMinutes = 15
    let timelineThirtyMinuteHeight: CGFloat = 32
    let timelineHourHeight: CGFloat = 64

    // MARK: - UI State
    @Published var selectedDate = Date()
    @Published var showAddActivity = false
    @Published var selectedSlot: Date?

    @Published var selectedType: PlannerType = .meal
    @Published var selectedItem: PlannerOption = PlannerOption.emptyMealPlaceholder
    @Published var selectedDuration = 15

    @Published var showCustomDuration = false
    @Published var customDuration = 15
    @Published var editingActivity: PlannedActivity?

    @Published var showTimeConflictAlert = false
    @Published var timeConflictMessage = ""
    @Published var showSaveFailureAlert = false
    @Published var saveFailureMessage = ""

    // MARK: - Drag State
    @Published var draggedActivityID: String?
    @Published var dragPreviewDate: Date?
    @Published var dragTranslationY: CGFloat = 0
    @Published var focusedDragSlot: Date?
    @Published var invalidDropSlot: Date?

    // MARK: - Meals
    @Published var customMeals: [Meals] = []
    @Published var selectedMealID: String?

    var dayKindCacheRevision = ""
    var dayKindByDayStart: [TimeInterval: PlanDayKind] = [:]
    var timelineItemsCacheKey = ""
    var cachedTimelineItems: [PlanTimelineItem] = []
    private var loadedCustomMealsStorage = ""
    private var loadedCustomMealsCatalogRevision: UInt = .max

    init() {
        WeekFitLifecycleTracker.attach(lifecycleToken)
    }
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {
        WeekFitLifecycleTracker.detach(lifecycleToken)
    }

    var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    /// Token for mounted-tab equality checks; must change when planner UI state changes.
    var plannerInteractionToken: String {
        let day = Int(calendar.startOfDay(for: selectedDate).timeIntervalSince1970)
        let editingID = editingActivity?.id ?? "-"
        return "\(day)|\(showAddActivity)|\(editingID)|\(plannerDataRevision)"
    }

    private var plannerDataRevision = 0

    func markPlannerDataChanged() {
        plannerDataRevision &+= 1
        invalidateTimelineCache()
    }

    var availableMeals: [Meals] {
        customMeals
    }

    var mealPlannerOptions: [PlannerOption] {
        availableMeals.map { plannerOption(for: $0) }
    }

    var currentOptions: [PlannerOption] {
        selectedType == .meal ? mealPlannerOptions : selectedType.options
    }
    
    func selectType(_ type: PlannerType) {
        selectedType = type
        selectedItem = type == .meal ? PlannerOption.emptyMealPlaceholder : type.options[0]

        applyDefaultDurationForSelectedItem()
    }
    
    func applyDefaultDurationForSelectedItem() {
        let title = selectedItem.title.lowercased()

        if selectedType == .meal {
            selectedDuration = 15
            customDuration = 15
            showCustomDuration = false
            return
        }

        if title.contains("sleep") || title.contains("bedtime") {
            selectedDuration = 480
            customDuration = 480
            showCustomDuration = false
        }
    }

    var selectedMealForPlanner: Meals? {
        if let selectedMealID {
            return availableMeals.first { $0.id == selectedMealID }
        }

        return availableMeals.first {
            $0.title == selectedItem.title
        }
    }

    var selectedDayTitle: String {
        WeekFitShortWeekdayMonthDay(selectedDate)
    }

    var selectedHeaderTitle: String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEE d MMMM")
        return formatter.string(from: selectedDate)
    }

    var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    // MARK: - Data helpers

    func loadCustomMeals(from storage: String) {
        customMeals = CustomMealStore.load(from: storage)

        if selectedType == .meal,
           let selectedMealID,
           !customMeals.contains(where: { $0.id == selectedMealID }) {
            syncDefaultSelectedMeal()
        }
    }

    func syncCustomMeals(from meals: [Meals], revision: UInt) {
        guard loadedCustomMealsCatalogRevision != revision else { return }
        loadedCustomMealsCatalogRevision = revision
        customMeals = meals

        if selectedType == .meal,
           let selectedMealID,
           !customMeals.contains(where: { $0.id == selectedMealID }) {
            syncDefaultSelectedMeal()
        }
    }

    func loadCustomMealsIfNeeded(from storage: String) {
        guard storage != loadedCustomMealsStorage else { return }
        loadedCustomMealsStorage = storage
        loadCustomMeals(from: storage)
    }

    func plannerOption(for meal: Meals) -> PlannerOption {
        PlannerOption(
            title: meal.title,
            subtitle: String(
                format: WeekFitLocalizedString("planner.meal.macroSummaryFormat"),
                meal.calories,
                meal.protein,
                meal.carbs,
                meal.fats
            ),
            icon: PlannerType.meal.icon,
            imageName: displayImageName(for: meal)
        )
    }

    func syncDefaultSelectedMeal() {
        guard selectedType == .meal else { return }

        let meal = availableMeals.first
        selectedMealID = meal?.id
        selectedItem = meal.map { plannerOption(for: $0) } ?? PlannerOption.emptyMealPlaceholder
    }

    func activities(for date: Date, from activities: [PlannedActivity]) -> [PlannedActivity] {
        activities
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    /// Activities that still count toward day progress (excludes skipped).
    func countableDayActivities(from activities: [PlannedActivity]) -> [PlannedActivity] {
        selectedDayActivities(from: activities).filter { !$0.isSkipped }
    }

    func selectedDayActivities(from activities: [PlannedActivity]) -> [PlannedActivity] {
        self.activities(for: selectedDate, from: activities)
    }

    func completedDayActivities(from activities: [PlannedActivity]) -> [PlannedActivity] {
        selectedDayActivities(from: activities).filter { $0.isCompleted }
    }

    func upcomingDayActivities(from activities: [PlannedActivity]) -> [PlannedActivity] {
        countableDayActivities(from: activities).filter { !$0.isCompleted }
    }

    func nextUpcomingActivity(from activities: [PlannedActivity]) -> PlannedActivity? {
        upcomingDayActivities(from: activities).first
    }

    func calculateProgress(from activities: [PlannedActivity]) -> Double {
        let dayActivities = countableDayActivities(from: activities)
        guard !dayActivities.isEmpty else { return 0.18 }

        let completed = dayActivities.filter { $0.isCompleted }.count
        return min(max(Double(completed) / Double(dayActivities.count), 0.12), 1.0)
    }

    // MARK: - Timeline math

    func yPosition(for date: Date) -> CGFloat {
        TimelineLayoutEngine.yPosition(for: date, calendar: calendar)
    }

    func dateForTimelinePosition(_ y: CGFloat) -> Date {
        TimelineLayoutEngine.dateForTimelinePosition(
            y,
            selectedDate: selectedDate,
            calendar: calendar
        )
    }

    func minutesFromTimelineStart(for date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return ((hour - timelineStartHour) * 60) + minute
    }

    func roundedToNext15Minutes(_ date: Date) -> Date {
        let minute = calendar.component(.minute, from: date)
        let hour = calendar.component(.hour, from: date)

        let nextMinute = ((minute / timelineMinuteStep) + 1) * timelineMinuteStep

        if nextMinute >= 60 {
            return calendar.date(bySettingHour: hour + 1, minute: 0, second: 0, of: date) ?? date
        }

        return calendar.date(bySettingHour: hour, minute: nextMinute, second: 0, of: date) ?? date
    }

    func clampedTimelineDate(_ date: Date) -> Date {
        dateForTimelinePosition(yPosition(for: date))
    }

    func nextAvailableSlot(from activities: [PlannedActivity]) -> Date {
        let startOfDay = calendar.startOfDay(for: selectedDate)

        let timelineStart = calendar.date(
            byAdding: .hour,
            value: timelineStartHour,
            to: startOfDay
        ) ?? selectedDate

        let timelineEnd = calendar.date(
            byAdding: .hour,
            value: timelineEndHour,
            to: startOfDay
        ) ?? selectedDate

        let firstCandidate = calendar.isDateInToday(selectedDate)
            ? max(roundedToNext15Minutes(Date()), timelineStart)
            : timelineStart

        let duration = selectedType == .meal ? 15 : max(selectedDuration, timelineMinimumDurationMinutes)

        var candidate = clampedTimelineDate(firstCandidate)

        while candidate < timelineEnd {
            if !hasTimeConflict(
                newStart: candidate,
                durationMinutes: duration,
                activities: activities,
                newEventBlocksPlannerTime: selectedType.blocksPlannerTime
            ) {
                return candidate
            }

            candidate = calendar.date(
                byAdding: .minute,
                value: timelineMinuteStep,
                to: candidate
            ) ?? candidate
        }

        return firstCandidate
    }

    func hasTimeConflict(
        newStart: Date,
        durationMinutes: Int,
        activities: [PlannedActivity],
        excluding: PlannedActivity? = nil,
        newEventBlocksPlannerTime: Bool = true
    ) -> Bool {
        TimelineLayoutEngine.hasTimeConflict(
            newStart: newStart,
            durationMinutes: durationMinutes,
            activities: activities,
            excluding: excluding,
            calendar: calendar,
            newEventBlocksPlannerTime: newEventBlocksPlannerTime
        )
    }

    // MARK: - Sheet actions

    // MARK: - Sheet actions

    func startAdding(at slot: Date) {
        let normalizedSlot = clampedTimelineDate(roundedToNext15Minutes(slot))

        editingActivity = nil
        selectedSlot = normalizedSlot
        selectedType = .meal

        let firstMeal = availableMeals.first
        selectedMealID = firstMeal?.id
        selectedItem = firstMeal.map { plannerOption(for: $0) } ?? PlannerOption.emptyMealPlaceholder

        selectedDuration = 15
        customDuration = 15

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.46, dampingFraction: 0.84, blendDuration: 0.08)) {
            showAddActivity = true
        }
    }

    func startEditing(_ activity: PlannedActivity) {
        editingActivity = activity
        selectedSlot = activity.date
        selectedDuration = activity.durationMinutes
        customDuration = activity.durationMinutes

        // 🎯 ФИКС 1: Сравниваем типы через lowercased(), чтобы сопоставить "workout" из SwiftData и "Workout" из Enum
        let type = PlannerType.allCases.first { $0.title.lowercased() == activity.type.lowercased() } ?? .meal
        selectedType = type

        // 🎯 ФИКС 2: Восстанавливаем точную структуру PlannerOption со всеми сабтитрами и калориями
        if type == .meal {
            if let matchingMeal = availableMeals.first(where: { $0.title.lowercased() == activity.title.lowercased() }) {
                selectedMealID = matchingMeal.id
                selectedItem = plannerOption(for: matchingMeal)
            } else {
                selectedMealID = nil
                selectedItem = PlannerOption(
                    title: activity.title,
                    subtitle: WeekFitLocalizedString("planner.loggedMeal"),
                    icon: activity.icon,
                    imageName: activity.imageName
                )
            }
        } else {
            selectedMealID = nil
            if let matchingOption = type.options.first(where: { $0.title.lowercased() == activity.title.lowercased() }) {
                selectedItem = matchingOption
            } else {
                // Если активность полностью кастомная — собираем её на лету с валидным сабтитром
                selectedItem = PlannerOption(
                    title: activity.title,
                    subtitle: String(format: WeekFitLocalizedString("planner.duration.summaryFormat"), activity.durationMinutes),
                    icon: activity.icon,
                    imageName: activity.imageName
                )
            }
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.46, dampingFraction: 0.84, blendDuration: 0.08)) {
            showAddActivity = true
        }
    }

    // MARK: - Persistence

    func saveSelectedItem(
        activities: [PlannedActivity],
        modelContext: ModelContext,
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool
    ) {
        guard let selectedSlot else { return }

        if hasTimeConflict(
            newStart: selectedSlot,
            durationMinutes: selectedDuration,
            activities: activities,
            excluding: editingActivity,
            newEventBlocksPlannerTime: selectedType.blocksPlannerTime
        ) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            timeConflictMessage = WeekFitLocalizedString("planner.timeConflict.message")
            showTimeConflictAlert = true
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let meal = selectedType == .meal ? selectedMealForPlanner : nil

        if selectedType == .meal, meal == nil, editingActivity == nil {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }

        let finalDuration = selectedType == .meal ? 15 : selectedDuration
        let finalImageName = selectedType == .meal
            ? displayImageName(for: meal)
            : selectedItem.imageName

        if let editingActivity {
            cancelNotifications(for: editingActivity)

            editingActivity.date = selectedSlot
            // 🎯 ФИКС 3: Сохраняем тип строго в нижнем регистре для бесшовной синхронизации с Live-статусами
            editingActivity.type = selectedType.title.lowercased()
            editingActivity.title = selectedItem.title
            editingActivity.durationMinutes = selectedDuration
            editingActivity.icon = selectedType.icon
            editingActivity.imageName = finalImageName
            editingActivity.colorRed = selectedType.colorComponents.red
            editingActivity.colorGreen = selectedType.colorComponents.green
            editingActivity.colorBlue = selectedType.colorComponents.blue
            editingActivity.calories = meal?.calories ?? editingActivity.calories
            editingActivity.protein = meal?.protein ?? editingActivity.protein
            editingActivity.carbs = meal?.carbs ?? editingActivity.carbs
            editingActivity.fats = meal?.fats ?? editingActivity.fats
            editingActivity.fiber = meal?.fiber ?? editingActivity.fiber

            do {
                try modelContext.save()
                scheduleNotificationsIfNeeded(
                    for: editingActivity,
                    activityRemindersEnabled: activityRemindersEnabled,
                    completionCheckInsEnabled: completionCheckInsEnabled
                )
            } catch {
                handleSaveFailure(error)
                return
            }
        } else {
            let activity = PlannedActivity(
                date: selectedSlot,
                // 🎯 ФИКС 4: Новые активности тоже сохраняем в нижнем регистре типа ("workout", "meal")
                type: selectedType.title.lowercased(),
                title: selectedItem.title,
                durationMinutes: finalDuration,
                icon: selectedType.icon,
                imageName: finalImageName,
                colorRed: selectedType.colorComponents.red,
                colorGreen: selectedType.colorComponents.green,
                colorBlue: selectedType.colorComponents.blue,
                calories: meal?.calories ?? 0,
                protein: meal?.protein ?? 0,
                carbs: meal?.carbs ?? 0,
                fats: meal?.fats ?? 0,
                fiber: meal?.fiber ?? 0
            )

            modelContext.insert(activity)

            do {
                try modelContext.save()
                scheduleNotificationsIfNeeded(
                    for: activity,
                    activityRemindersEnabled: activityRemindersEnabled,
                    completionCheckInsEnabled: completionCheckInsEnabled
                )
            } catch {
                modelContext.delete(activity)
                handleSaveFailure(error)
                return
            }
        }

        closeAddSheet()
    }

    private func handleSaveFailure(_ error: Error) {
        saveFailureMessage = WeekFitLocalizedString("planner.saveFailure.message")
        showSaveFailureAlert = true
        print("Failed to save planned activity:", error)
    }

    private func displayImageName(for meal: Meals?) -> String {
        guard let meal else { return selectedItem.imageName }

        if let photoFilename = meal.displayPhotoFilename?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !photoFilename.isEmpty {
            return photoFilename
        }

        return meal.imageName
    }

    func closeAddSheet() {
        withAnimation(.spring(response: 0.40, dampingFraction: 0.88, blendDuration: 0.06)) {
            showAddActivity = false
            editingActivity = nil
        }

        selectedSlot = nil
        resetDragState()
    }

    var beforePlannedActivityDeleted: (() -> Void)?
    var afterPlannedActivityDeleted: (() -> Void)?

    func invalidateTimelineCache() {
        timelineItemsCacheKey = ""
        cachedTimelineItems = []
    }

    func removePlannedActivities(withIDs ids: [String], modelContext: ModelContext) {
        guard !ids.isEmpty else { return }

        beforePlannedActivityDeleted?()

        do {
            try PlannedActivityPersistenceService.deleteActivities(
                withIDs: ids,
                modelContext: modelContext,
                auditSource: "PlanViewModel.removePlannedActivities"
            )
            markPlannerDataChanged()
            afterPlannedActivityDeleted?()
        } catch {
            PlannedActivityPlannerAudit.deleteFailed(ids: ids, error: error, modelContext: modelContext)
        }
    }

    func removePlannedActivities(_ activities: [PlannedActivity], modelContext: ModelContext) {
        removePlannedActivities(withIDs: activities.map(\.id), modelContext: modelContext)
    }

    func removePlannedActivity(_ activity: PlannedActivity, modelContext: ModelContext) {
        removePlannedActivities([activity], modelContext: modelContext)
    }

    func deleteActivity(_ activity: PlannedActivity, modelContext: ModelContext) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        removePlannedActivity(activity, modelContext: modelContext)
        closeAddSheet()
    }

    func moveActivity(
        _ activity: PlannedActivity,
        to newDate: Date,
        activities: [PlannedActivity],
        modelContext: ModelContext,
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool
    ) {
        guard !calendar.isDate(activity.date, equalTo: newDate, toGranularity: .minute) else {
            return
        }

        if hasTimeConflict(
            newStart: newDate,
            durationMinutes: activity.durationMinutes,
            activities: activities,
            excluding: activity,
            newEventBlocksPlannerTime: activity.blocksPlannerTime
        ) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            invalidDropSlot = newDate
            timeConflictMessage = WeekFitLocalizedString("planner.timeConflict.message")
            showTimeConflictAlert = true
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        cancelNotifications(for: activity)
        let previousDate = activity.date
        activity.date = newDate

        do {
            try modelContext.save()
            scheduleNotificationsIfNeeded(
                for: activity,
                activityRemindersEnabled: activityRemindersEnabled,
                completionCheckInsEnabled: completionCheckInsEnabled
            )
        } catch {
            activity.date = previousDate
            handleSaveFailure(error)
        }
    }

    // MARK: - Drag

    func resetDragState() {
        draggedActivityID = nil
        dragPreviewDate = nil
        dragTranslationY = 0
        focusedDragSlot = nil
        invalidDropSlot = nil
    }

    func dragCandidateDate(from date: Date, translationY: CGFloat) -> Date {
        let startY = yPosition(for: date)
        let proposedStartY = startY + translationY
        let proposedStart = dateForTimelinePosition(proposedStartY)

        return clampedTimelineDate(proposedStart)
    }

    // MARK: - Notifications

    private func cancelNotifications(for activity: PlannedActivity) {
        ActivityNotificationService.shared.cancelNotifications(for: activity)
    }

    private func scheduleNotificationsIfNeeded(
        for activity: PlannedActivity,
        activityRemindersEnabled: Bool,
        completionCheckInsEnabled: Bool
    ) {
        ActivityNotificationService.shared.syncNotifications(
            for: activity,
            activityRemindersEnabled: activityRemindersEnabled,
            completionCheckInsEnabled: completionCheckInsEnabled
        )
    }
}
