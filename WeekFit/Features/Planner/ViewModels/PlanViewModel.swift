import SwiftUI
import SwiftData
internal import Combine

@MainActor
final class PlanViewModel: ObservableObject {

    // MARK: - Timeline constants
    let timelineStartHour = 5
    let timelineEndHour = 24
    let timelineMinuteStep = 15
    let timelineMinimumDurationMinutes = 15
    let timelineThirtyMinuteHeight: CGFloat = 32
    let timelineHourHeight: CGFloat = 64

    // MARK: - UI State
    @Published var selectedDate = Date()
    @Published var showCalendar = false
    @Published var showAddActivity = false
    @Published var selectedSlot: Date?

    @Published var selectedType: PlannerType = .meal
    @Published var selectedItem: PlannerOption = PlannerType.meal.options[0]
    @Published var selectedDuration = 30

    @Published var showCustomDuration = false
    @Published var customDuration = 30
    @Published var editingActivity: PlannedActivity?

    @Published var showTimeConflictAlert = false
    @Published var timeConflictMessage = ""

    // MARK: - Drag State
    @Published var draggedActivityID: String?
    @Published var dragPreviewDate: Date?
    @Published var dragTranslationY: CGFloat = 0
    @Published var focusedDragSlot: Date?
    @Published var invalidDropSlot: Date?

    // MARK: - Meals
    @Published var customMeals: [Meals] = []
    @Published var selectedMealID: String?

    private let nutritionRepository = NutritionRepository()

    var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    var predefinedMeals: [Meals] {
        nutritionRepository.loadMeals()
    }

    var availableMeals: [Meals] {
        customMeals.isEmpty ? predefinedMeals : customMeals
    }

    var mealPlannerOptions: [PlannerOption] {
        availableMeals.map { plannerOption(for: $0) }
    }

    var currentOptions: [PlannerOption] {
        selectedType == .meal ? mealPlannerOptions : selectedType.options
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
        selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var selectedHeaderTitle: String {
        selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
    }

    var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    // MARK: - Data helpers

    func loadCustomMeals(from storage: String) {
        guard let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Meals].self, from: data) else {
            customMeals = []
            return
        }

        customMeals = decoded
    }

    func plannerOption(for meal: Meals) -> PlannerOption {
        PlannerOption(
            title: meal.title,
            subtitle: "\(meal.calories) kcal • P \(meal.protein)g",
            icon: PlannerType.meal.icon,
            imageName: meal.imageName
        )
    }

    func syncDefaultSelectedMeal() {
        guard selectedType == .meal else { return }

        let meal = availableMeals.first
        selectedMealID = meal?.id
        selectedItem = meal.map { plannerOption(for: $0) } ?? PlannerType.meal.options[0]
    }

    func activities(for date: Date, from activities: [PlannedActivity]) -> [PlannedActivity] {
        activities
            .filter { calendar.isDate($0.date, inSameDayAs: date) && !$0.isSkipped }
            .sorted { $0.date < $1.date }
    }

    func selectedDayActivities(from activities: [PlannedActivity]) -> [PlannedActivity] {
        self.activities(for: selectedDate, from: activities)
    }

    func completedDayActivities(from activities: [PlannedActivity]) -> [PlannedActivity] {
        selectedDayActivities(from: activities).filter { $0.isCompleted }
    }

    func upcomingDayActivities(from activities: [PlannedActivity]) -> [PlannedActivity] {
        selectedDayActivities(from: activities).filter { !$0.isCompleted && !$0.isSkipped }
    }

    func nextUpcomingActivity(from activities: [PlannedActivity]) -> PlannedActivity? {
        upcomingDayActivities(from: activities).first
    }

    func calculateProgress(from activities: [PlannedActivity]) -> Double {
        let dayActivities = selectedDayActivities(from: activities)
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

    func nextAvailableSlot() -> Date {
        let nowRounded = roundedToNext15Minutes(Date())
        let minSlot = calendar.date(bySettingHour: timelineStartHour, minute: 0, second: 0, of: selectedDate) ?? selectedDate

        return max(calendar.isDateInToday(selectedDate) ? nowRounded : minSlot, minSlot)
    }

    func hasTimeConflict(
        newStart: Date,
        durationMinutes: Int,
        activities: [PlannedActivity],
        excluding: PlannedActivity? = nil
    ) -> Bool {
        TimelineLayoutEngine.hasTimeConflict(
            newStart: newStart,
            durationMinutes: durationMinutes,
            activities: activities,
            excluding: excluding,
            calendar: calendar
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
        selectedItem = firstMeal.map { plannerOption(for: $0) } ?? PlannerType.meal.options[0]

        selectedDuration = 30
        customDuration = 30 // Синхронизируем кастомную длительность

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
                selectedItem = type.options.first(where: { $0.title.lowercased() == activity.title.lowercased() }) ?? type.options[0]
            }
        } else {
            selectedMealID = nil
            if let matchingOption = type.options.first(where: { $0.title.lowercased() == activity.title.lowercased() }) {
                selectedItem = matchingOption
            } else {
                // Если активность полностью кастомная — собираем её на лету с валидным сабтитром
                selectedItem = PlannerOption(
                    title: activity.title,
                    subtitle: "Duration · \(activity.durationMinutes) min",
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
            excluding: editingActivity
        ) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            timeConflictMessage = "This time overlaps with another activity. Choose another 15-minute slot."
            showTimeConflictAlert = true
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let meal = selectedType == .meal ? selectedMealForPlanner : nil

        if let editingActivity {
            cancelNotifications(for: editingActivity)

            editingActivity.date = selectedSlot
            // 🎯 ФИКС 3: Сохраняем тип строго в нижнем регистре для бесшовной синхронизации с Live-статусами
            editingActivity.type = selectedType.title.lowercased()
            editingActivity.title = selectedItem.title
            editingActivity.durationMinutes = selectedDuration
            editingActivity.icon = selectedType.icon
            editingActivity.imageName = selectedItem.imageName
            editingActivity.colorRed = selectedType.colorComponents.red
            editingActivity.colorGreen = selectedType.colorComponents.green
            editingActivity.colorBlue = selectedType.colorComponents.blue
            editingActivity.calories = meal?.calories ?? 0
            editingActivity.protein = meal?.protein ?? 0
            editingActivity.carbs = meal?.carbs ?? 0
            editingActivity.fats = meal?.fats ?? 0

            do {
                try modelContext.save()
                scheduleNotificationsIfNeeded(
                    for: editingActivity,
                    activityRemindersEnabled: activityRemindersEnabled,
                    completionCheckInsEnabled: completionCheckInsEnabled
                )
            } catch {
                print("Failed to update planned activity:", error)
            }
        } else {
            let activity = PlannedActivity(
                date: selectedSlot,
                // 🎯 ФИКС 4: Новые активности тоже сохраняем в нижнем регистре типа ("workout", "meal")
                type: selectedType.title.lowercased(),
                title: selectedItem.title,
                durationMinutes: selectedDuration,
                icon: selectedType.icon,
                imageName: selectedItem.imageName,
                colorRed: selectedType.colorComponents.red,
                colorGreen: selectedType.colorComponents.green,
                colorBlue: selectedType.colorComponents.blue,
                calories: meal?.calories ?? 0,
                protein: meal?.protein ?? 0,
                carbs: meal?.carbs ?? 0,
                fats: meal?.fats ?? 0
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
                print("Failed to save planned activity:", error)
            }
        }

        closeAddSheet()
    }

    func closeAddSheet() {
        withAnimation(.spring(response: 0.40, dampingFraction: 0.88, blendDuration: 0.06)) {
            showAddActivity = false
            editingActivity = nil
        }

        selectedSlot = nil
        resetDragState()
    }

    func deleteActivity(_ activity: PlannedActivity, modelContext: ModelContext) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        cancelNotifications(for: activity)
        modelContext.delete(activity)

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete activity:", error)
        }

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
            excluding: activity
        ) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            invalidDropSlot = newDate
            timeConflictMessage = "This time overlaps with another activity. Choose another 15-minute slot."
            showTimeConflictAlert = true
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        cancelNotifications(for: activity)
        activity.date = newDate

        do {
            try modelContext.save()
            scheduleNotificationsIfNeeded(
                for: activity,
                activityRemindersEnabled: activityRemindersEnabled,
                completionCheckInsEnabled: completionCheckInsEnabled
            )
        } catch {
            print("Failed to move planned activity:", error)
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
