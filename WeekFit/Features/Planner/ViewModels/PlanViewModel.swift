import SwiftUI
import SwiftData
import WeekFitPlanner
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

    // MARK: - Meals
    @Published var customMeals: [Meals] = []
    @Published var selectedMealID: String?

    /// Per-category draft while the planner stays open (date/time are shared).
    private struct CategoryDraft {
        var mealID: String?
        var item: PlannerOption
        var duration: Int
    }

    private var categoryDrafts: [PlannerType: CategoryDraft] = [:]

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

    /// Set when Add opens, consumed once the sheet can see the live plan history.
    private var shouldApplyOpeningDefaults = false

    /// Recent plans used to preselect type, activity, duration, and time.
    private(set) var addHistorySamples: [PlanAddPreference.Sample] = []
    private var addHistoryActivities: [PlannedActivity] = []
    /// True after the user taps a time chip, so switching activity does not move the clock.
    private var userPinnedTime = false

    var rankedMeals: [Meals] {
        PlanAddPreference.rankedMeals(availableMeals, samples: addHistorySamples)
    }

    var currentOptions: [PlannerOption] {
        if selectedType == .meal {
            return rankedMeals.map { plannerOption(for: $0) }
        }
        return PlanAddPreference.rankedOptions(
            selectedType.options,
            type: selectedType,
            samples: addHistorySamples
        )
    }
    
    func selectType(_ type: PlannerType) {
        guard selectedType != type else { return }
        persistCurrentCategoryDraft()
        selectedType = type
        restoreCategoryDraft(for: type)
    }

    /// True when the current category has an intentional catalog selection (not an empty placeholder).
    var hasValidItemSelection: Bool {
        if editingActivity != nil { return true }
        switch selectedType {
        case .meal:
            return selectedMealForPlanner != nil
        case .workout, .recovery, .habit:
            return selectedType.options.contains {
                $0.imageName == selectedItem.imageName || $0.title == selectedItem.title
            }
        }
    }

    private func persistCurrentCategoryDraft() {
        categoryDrafts[selectedType] = CategoryDraft(
            mealID: selectedMealID,
            item: selectedItem,
            duration: selectedDuration
        )
    }

    private func restoreCategoryDraft(for type: PlannerType) {
        if let draft = categoryDrafts[type] {
            selectedMealID = draft.mealID
            selectedItem = draft.item
            selectedDuration = draft.duration
            customDuration = draft.duration
            showCustomDuration = false
            return
        }

        applyDefaultSelection(for: type)
    }

    /// Most-used catalog item for the type, otherwise the first item in add-sheet order.
    private func applyDefaultSelection(for type: PlannerType) {
        switch type {
        case .meal:
            if let meal = rankedMeals.first {
                selectedMealID = meal.id
                selectedItem = plannerOption(for: meal)
            } else {
                selectedMealID = nil
                selectedItem = PlannerOption(
                    title: "",
                    subtitle: "",
                    icon: type.icon,
                    imageName: ""
                )
            }
            selectedDuration = 15
        case .workout, .recovery, .habit:
            selectedMealID = nil
            if let option = PlanAddPreference.rankedOptions(
                type.options,
                type: type,
                samples: addHistorySamples
            ).first {
                selectedItem = option
            } else {
                selectedItem = PlannerOption(
                    title: "",
                    subtitle: "",
                    icon: type.icon,
                    imageName: ""
                )
            }
            switch type {
            case .workout: selectedDuration = 45
            case .recovery: selectedDuration = 20
            case .habit: selectedDuration = 15
            case .meal: break
            }
        }
        customDuration = selectedDuration
        showCustomDuration = false
        applyDefaultDurationForSelectedItem()
        applyHabit(forTitle: selectedItem.title, imageName: selectedItem.imageName)
    }

    private func clearItemSelection(for type: PlannerType) {
        applyDefaultSelection(for: type)
    }

    func resetPlannerDrafts() {
        categoryDrafts.removeAll()
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

    /// Repeat plans keep the activity the user already uses, at the clock they used before.
    private func applyHabit(forTitle title: String, imageName: String) {
        guard let habit = PlanAddPreference.habit(
            type: selectedType,
            title: title,
            imageName: imageName,
            samples: addHistorySamples
        ) else { return }

        selectedDuration = habit.durationMinutes
        customDuration = habit.durationMinutes
        showCustomDuration = false
        guard !userPinnedTime else { return }
        selectedSlot = slot(
            matchingHabit: habit.minuteOfDay,
            durationMinutes: habit.durationMinutes,
            blocksTime: selectedType.blocksPlannerTime,
            fallback: selectedSlot ?? Date()
        )
    }

    func pinSelectedTime(_ slot: Date) {
        userPinnedTime = true
        selectedSlot = slot
    }

    func selectCatalogOption(_ option: PlannerOption) {
        selectedItem = option
        applyDefaultDurationForSelectedItem()
        applyHabit(forTitle: option.title, imageName: option.imageName)
    }

    func selectMeal(_ meal: Meals) {
        selectedMealID = meal.id
        selectedItem = plannerOption(for: meal)
        applyHabit(forTitle: meal.title, imageName: meal.imageName)
    }

    private func slot(
        matchingHabit minuteOfDay: Int,
        durationMinutes: Int,
        blocksTime: Bool,
        fallback: Date
    ) -> Date {
        let day = calendar.startOfDay(for: selectedDate)
        let timelineStart = calendar.date(byAdding: .hour, value: timelineStartHour, to: day) ?? day
        let timelineEnd = calendar.date(byAdding: .hour, value: timelineEndHour, to: day) ?? day
        let preferred = calendar.date(byAdding: .minute, value: minuteOfDay, to: day) ?? fallback
        let dayActivities = addHistoryActivities.filter {
            calendar.isDate($0.date, inSameDayAs: day) && !$0.isSkipped
        }

        func usable(_ candidate: Date) -> Bool {
            guard candidate >= timelineStart, candidate <= timelineEnd else { return false }
            if calendar.isDateInToday(selectedDate), candidate < Date() { return false }
            return !hasTimeConflict(
                newStart: candidate,
                durationMinutes: durationMinutes,
                activities: dayActivities,
                excluding: editingActivity,
                newEventBlocksPlannerTime: blocksTime
            )
        }

        if usable(preferred) {
            return clampedTimelineDate(preferred)
        }

        var forward = preferred
        while forward < timelineEnd {
            forward = calendar.date(byAdding: .minute, value: timelineMinuteStep, to: forward) ?? timelineEnd
            if usable(forward) { return clampedTimelineDate(forward) }
        }

        var backward = preferred
        while backward > timelineStart {
            backward = calendar.date(byAdding: .minute, value: -timelineMinuteStep, to: backward) ?? timelineStart
            if usable(backward) { return clampedTimelineDate(backward) }
        }

        return clampedTimelineDate(fallback)
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

        // Keep an intentional / restored selection if it still exists.
        if let selectedMealID,
           let meal = availableMeals.first(where: { $0.id == selectedMealID }) {
            selectedItem = plannerOption(for: meal)
            return
        }

        applyDefaultSelection(for: .meal)
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

    func startAdding(at slot: Date, history: [PlannedActivity] = []) {
        let normalizedSlot = clampedTimelineDate(roundedToNext15Minutes(slot))

        editingActivity = nil
        userPinnedTime = false
        shouldApplyOpeningDefaults = true
        addHistorySamples = PlanAddPreference.samples(from: history, calendar: calendar)
        addHistoryActivities = history
        selectedSlot = normalizedSlot
        let type = PlanAddPreference.preferredType(addHistorySamples)
        selectedType = type
        resetPlannerDrafts()
        applyDefaultSelection(for: type)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        ProductAnalytics.planItemCreationStarted(
            itemType: PlanItemAnalyticsType(plannerTypeTitle: type.title)
        )

        withAnimation(.spring(response: 0.46, dampingFraction: 0.84, blendDuration: 0.08)) {
            showAddActivity = true
        }
    }

    /// Selects the most-used type and activity once the add sheet is on screen.
    func applyOpeningSelectionIfNeeded(from activities: [PlannedActivity]) {
        guard shouldApplyOpeningDefaults, editingActivity == nil else { return }
        shouldApplyOpeningDefaults = false
        userPinnedTime = false
        addHistorySamples = PlanAddPreference.samples(from: activities, calendar: calendar)
        addHistoryActivities = activities
        let type = PlanAddPreference.preferredType(addHistorySamples)
        selectedType = type
        resetPlannerDrafts()
        applyDefaultSelection(for: type)
    }

    func startEditing(_ activity: PlannedActivity) {
        editingActivity = activity
        shouldApplyOpeningDefaults = false
        userPinnedTime = true
        selectedDate = calendar.startOfDay(for: activity.date)
        selectedSlot = activity.date
        selectedDuration = activity.durationMinutes
        customDuration = activity.durationMinutes
        resetPlannerDrafts()

        // 🎯 ФИКС 1: Сравниваем типы через lowercased(), чтобы сопоставить "workout" из SwiftData и "Workout" из Enum
        let type = PlannerType.allCases.first { $0.title.lowercased() == activity.type.lowercased() } ?? .meal
        selectedType = type
        ProductAnalytics.planItemEditStarted(
            itemType: PlanItemAnalyticsType(plannedActivityType: activity.type)
        )

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

        if !hasValidItemSelection {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }

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
            editingActivity.icon = resolvedIconForSelection(imageName: finalImageName)
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
                ReviewEngagement.record(.planCreatedOrUpdated)
                ProductAnalytics.planItemUpdated(
                    itemType: PlanItemAnalyticsType(plannerTypeTitle: selectedType.title)
                )
                if CoachAdjustmentProvenanceStore.adjustment(forActivityId: editingActivity.id) != nil {
                    CoachAdjustmentProvenanceStore.markManualEdit(activityId: editingActivity.id)
                    let kind = CoachProvenanceLookupCache.adjustment(
                        forActivityId: editingActivity.id,
                        dayKey: ProposalInputFingerprintBuilder.dayKey(for: editingActivity.date)
                    )?.kind
                    ProductAnalytics.morningProposalAdjustedItemManuallyEdited(changeKind: kind)
                }
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
                icon: resolvedIconForSelection(imageName: finalImageName),
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

            AppReviewDemoPlannedActivityTagger.tagIfNeeded(activity)
            modelContext.insert(activity)

            do {
                try modelContext.save()
                scheduleNotificationsIfNeeded(
                    for: activity,
                    activityRemindersEnabled: activityRemindersEnabled,
                    completionCheckInsEnabled: completionCheckInsEnabled
                )
                ReviewEngagement.record(.planCreatedOrUpdated)
                ProductAnalytics.planItemCreated(
                    itemType: PlanItemAnalyticsType(plannerTypeTitle: selectedType.title)
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
        #if DEBUG
        print("Failed to save planned activity:", error)
        #endif
    }

    /// Prefer the selected option icon (e.g. cycling) over the generic type icon (dumbbell).
    private func resolvedIconForSelection(imageName: String) -> String {
        WeekFitActivityIconResolver.resolve(
            storedIcon: selectedItem.icon,
            title: selectedItem.title,
            type: selectedType.title.lowercased(),
            imageName: imageName
        )
    }

    private func displayImageName(for meal: Meals?) -> String {
        guard let meal else { return selectedItem.imageName }
        let resolved = meal.activityImageName
        return resolved.isEmpty ? selectedItem.imageName : resolved
    }

    func closeAddSheet() {
        showAddActivity = false
    }

    /// Runs after the system sheet dismiss, including a drag, so the form does not jump while it is leaving.
    func finishAddSheetDismiss() {
        editingActivity = nil
        selectedSlot = nil
        resetPlannerDrafts()
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
            let snapshots = try PlannedActivityPersistenceService.deleteActivities(
                withIDs: ids,
                modelContext: modelContext,
                auditSource: "PlanViewModel.removePlannedActivities"
            )
            markPlannerDataChanged()
            afterPlannedActivityDeleted?()
            for snapshot in snapshots {
                ProductAnalytics.planItemDeleted(
                    itemType: PlanItemAnalyticsType(plannedActivityType: snapshot.type)
                )
            }
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
