import SwiftUI
import UIKit
import SwiftData

struct PlanWeekView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var authViewModel: AuthViewModel

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]
    @State private var selectedMealID: String?

    @AppStorage("weekfit_custom_meals_v1")
    private var customMealsStorage: String = ""

    @AppStorage("notifications.activityReminders")
    private var activityRemindersEnabled = true

    @AppStorage("notifications.completionCheckIns")
    private var completionCheckInsEnabled = true

    @State private var customMeals: [Meals] = []

    @Binding var isEditingActivity: Bool

    @State private var draggedActivityID: String?
    @State private var dragPreviewDate: Date?
    @State private var dragTranslationY: CGFloat = 0
    @State private var focusedDragSlot: Date?
    @State private var invalidDropSlot: Date?
    
    @State private var selectedDate = Date()
    @State private var showCalendar = false
    @State private var showAddActivity = false
    @State private var selectedSlot: Date?

    @State private var selectedType: PlannerType = .meal
    @State private var selectedItem: PlannerOption = PlannerType.meal.options[0]
    @State private var selectedDuration = 30

    @State private var showCustomDuration = false
    @State private var customDuration = 30

    @State private var editingActivity: PlannedActivity?

    @State private var showTimeConflictAlert = false
    @State private var timeConflictMessage = ""

    private let background = WeekFitTheme.background
    private let cardBackground = WeekFitTheme.cardBackground
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let elevatedCard = WeekFitTheme.elevatedCard

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let textTertiary = WeekFitTheme.tertiaryText

    private let borderSoft = WeekFitTheme.borderSoft
    private let softShadow = WeekFitTheme.cardShadow

    private let nowAccent = Color(red: 0.56, green: 0.76, blue: 0.64)
    private let recoveryAccent = Color(red: 0.66, green: 0.58, blue: 0.86)
    private let mealAccent = Color(red: 0.50, green: 0.74, blue: 0.54)
    private let workoutAccent = Color(red: 0.46, green: 0.72, blue: 0.82)
    private let habitAccent = Color(red: 0.82, green: 0.60, blue: 0.36)

    private let timelineEndHour = 24

    // Fixed calendar-style timeline.
    // 1 hour = 2 fixed 30-minute rows. Cards use exactly the same scale.
    // 30 min = timelineThirtyMinuteHeight, 15 min = half of it, 60 min = full hour.
    private let timelineThirtyMinuteHeight: CGFloat = 32
    private let timelineHourHeight: CGFloat = 64
    private let timelineEventLeftOffset: CGFloat = 56
    private let timelineTopPadding: CGFloat = 52
    private let timelineMinimumDurationMinutes = 15
    private let timelineMinuteStep = 15
    private let timelineCardCornerRadius: CGFloat = 18

    private let addSheetHorizontalInset: CGFloat = 8
    private let addSheetCornerRadius: CGFloat = 34
    private let addSheetVerticalSpacing: CGFloat = 6
    private let addSheetMealCardWidth: CGFloat = 118
    private let addSheetMealCardHeight: CGFloat = 112
    private let addSheetMealImageWidth: CGFloat = 104
    private let addSheetMealImageHeight: CGFloat = 60

    private let timelineStartHour = 5
    
    private var addSheetHeight: CGFloat {
        // Keep one stable sheet height for every activity type.
        // This prevents the sheet from jumping up/down when switching
        // between Meal, Workout, Recovery and Habit.
        let baseHeight: CGFloat = hasSelectedTimeConflict ? 648 : 634

        if editingActivity != nil {
            return 686
        }

        return baseHeight
    }

    private let nutritionRepository = NutritionRepository()

    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    
    private func loadCustomMeals() {
        guard let data = customMealsStorage.data(using: .utf8) else {
            customMeals = []
            return
        }

        guard let decoded = try? JSONDecoder().decode([Meals].self, from: data) else {
            customMeals = []
            return
        }

        customMeals = decoded
    }

    private var predefinedMeals: [Meals] {
        nutritionRepository.loadMeals()
    }

    private var availableMeals: [Meals] {
        customMeals.isEmpty ? predefinedMeals : customMeals
    }

    private var mealPlannerOptions: [PlannerOption] {
        availableMeals.map { plannerOption(for: $0) }
    }

    private var currentOptions: [PlannerOption] {
        if selectedType == .meal {
            return mealPlannerOptions
        }

        return selectedType.options
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var weekDays: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    private var timeSlots: [Date] {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        return Array(timelineStartHour...timelineEndHour).compactMap {
            calendar.date(byAdding: .hour, value: $0, to: startOfDay)
        }
    }

    private var selectedDayTitle: String {
        selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var selectedHeaderTitle: String {
        selectedDate.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
    }

    private var selectedDayActivities: [PlannedActivity] {
        plannedActivities
            .filter {
                calendar.isDate($0.date, inSameDayAs: selectedDate)
                && !$0.isSkipped
            }
            .sorted { $0.date < $1.date }
    }

    private var completedDayActivities: [PlannedActivity] {
        selectedDayActivities.filter {
            $0.isCompleted || isPastActivity($0)
        }
    }

    private var upcomingDayActivities: [PlannedActivity] {
        selectedDayActivities.filter {
            !($0.isCompleted || isPastActivity($0))
        }
    }

    private var nextUpcomingActivity: PlannedActivity? {
        upcomingDayActivities.first
    }

    private var planRhythmTitle: String {
        if selectedDayActivities.isEmpty {
            return "Shape today with intention"
        }

        if let nextUpcomingActivity {
            return "Your day is flowing well"
        }

        return "Today's flow is complete"
    }

    private var planRhythmSubtitle: String {
        let workouts = selectedDayActivities.filter { $0.type.lowercased() == "workout" }.count
        let recovery = selectedDayActivities.filter { $0.type.lowercased() == "recovery" }.count
        let meals = selectedDayActivities.filter { $0.type.lowercased() == "meal" }.count

        if selectedDayActivities.isEmpty {
            return "Add meals, movement and recovery to build your flow"
        }

        var parts: [String] = []
        if workouts > 0 { parts.append("\(workouts) workout\(workouts == 1 ? "" : "s")") }
        if recovery > 0 { parts.append("\(recovery) recovery") }
        if meals > 0 { parts.append("\(meals) meal\(meals == 1 ? "" : "s")") }

        return parts.isEmpty ? "\(selectedDayActivities.count) planned item\(selectedDayActivities.count == 1 ? "" : "s")" : parts.joined(separator: " • ")
    }

    private var planRhythmProgress: Double {
        guard !selectedDayActivities.isEmpty else { return 0.18 }
        return min(max(Double(completedDayActivities.count) / Double(selectedDayActivities.count), 0.12), 1.0)
    }

    private var planRhythmNextTitle: String {
        guard let nextUpcomingActivity else {
            return selectedDayActivities.isEmpty ? "Start planning" : "Day completed"
        }

        return "\(shortDisplayTitle(nextUpcomingActivity.title)) at \(slotTitle(nextUpcomingActivity.date))"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            background.ignoresSafeArea()
            ambientBackground

            VStack(spacing: 0) {
                header

                weekSelector
                    .padding(.horizontal, WeekFitStyle.Size.horizontalPadding)
                    .padding(.bottom, 8)

                planRhythmCard
                    .padding(.horizontal, WeekFitStyle.Size.horizontalPadding)
                    .padding(.bottom, 6)

                timeline
            }
            .blur(radius: showAddActivity ? 1.6 : 0)
            .scaleEffect(showAddActivity ? 0.985 : 1.0)
            .opacity(showAddActivity ? 0.90 : 1.0)

            if showAddActivity {
                sheetDepthScrim
                    .onTapGesture {
                        closeAddSheet()
                    }

                addActivitySheet
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.spring(response: 0.42, dampingFraction: 0.90, blendDuration: 0.08), value: showAddActivity)
        .sheet(isPresented: $showCalendar) {
            calendarSheet
        }
        .sheet(isPresented: $showCustomDuration) {
            customDurationSheet
        }
        .alert("Time already booked", isPresented: $showTimeConflictAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(timeConflictMessage)
        }
        .onAppear {
            loadCustomMeals()
            syncDefaultSelectedMeal()
        }
        .onChange(of: customMealsStorage) { _, _ in
            loadCustomMeals()
            syncDefaultSelectedMeal()
        }
        .onChange(of: showAddActivity) { _, newValue in
            withAnimation(.spring(response: 0.36, dampingFraction: 0.90, blendDuration: 0.06)) {
                isEditingActivity = newValue
            }
        }
    }
    
    private func plannerOption(for meal: Meals) -> PlannerOption {
        PlannerOption(
            title: meal.title,
            subtitle: "\(meal.calories) kcal • P \(meal.protein)g",
            icon: PlannerType.meal.icon,
            imageName: meal.imageName
        
        )
    }

    private var selectedMealForPlanner: Meals? {
        if let selectedMealID {
            return availableMeals.first { $0.id == selectedMealID }
        }

        return availableMeals.first {
            $0.title == selectedItem.title
        }
    }

    private var sheetDepthScrim: some View {
        ZStack {
            Color.black.opacity(0.28)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.00),
                    Color.black.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [
                    selectedType.color.opacity(0.030),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 300
            )

            RadialGradient(
                colors: [
                    WeekFitTheme.meal.opacity(0.014),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 60,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                showCalendar = true
            } label: {
                HStack(spacing: 6) {
                    Text(selectedHeaderTitle)
                        .font(.system(size: 22.5, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 10) {
                circleButton("plus") {
                    startAdding(at: nextAvailableSlot())
                }

                circleButton("calendar") {
                    showCalendar = true
                }
            }
        }
        .padding(.horizontal, WeekFitStyle.Size.horizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 13)
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16.5, weight: .semibold))
                .foregroundStyle(textPrimary.opacity(0.92))
                .frame(width: 43, height: 43)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    elevatedCard,
                                    cardBackground
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .stroke(borderSoft.opacity(0.54), lineWidth: 1)
                }
                .shadow(color: softShadow.opacity(0.32), radius: 7, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon == "plus" ? "Add activity" : "Open calendar")
    }

    private var weekSelector: some View {
        HStack(spacing: 8) {
            ForEach(weekDays, id: \.self) { date in
                weekDayButton(date)
            }
        }
    }

    private func weekDayButton(_ date: Date) -> some View {
        let active = calendar.isDate(date, inSameDayAs: selectedDate)

        return Button {
            selectedDate = date
            closeAddSheet()
        } label: {
            VStack(spacing: 5) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(WeekFitStyle.Font.dayName)
                    .foregroundStyle(active ? WeekFitTheme.meal.opacity(0.82) : textSecondary.opacity(0.50))

                Text(date.formatted(.dateTime.day()))
                    .font(WeekFitStyle.Font.dayNumber)
                    .foregroundStyle(active ? .black.opacity(0.82) : textPrimary.opacity(0.72))
                    .frame(
                        width: WeekFitStyle.Size.dayCell,
                        height: WeekFitStyle.Size.dayCell
                    )
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(active ? WeekFitTheme.meal.opacity(0.72) : Color.white.opacity(0.010))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(active ? Color.white.opacity(0.18) : Color.white.opacity(0.010), lineWidth: 1)
                    }
                    .shadow(
                        color: active ? WeekFitTheme.meal.opacity(0.055) : Color.black.opacity(0.030),
                        radius: active ? 5 : 1.5,
                        y: active ? 2.5 : 1.5
                    )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }


    private var planRhythmCard: some View {
        Button {
            if let nextUpcomingActivity {
                startEditing(nextUpcomingActivity)
            } else {
                startAdding(at: nextAvailableSlot())
            }
        } label: {
            HStack(spacing: 11) {
                rhythmProgressBadge

                VStack(alignment: .leading, spacing: 3) {
                    Text(planRhythmTitle)
                        .font(.system(size: 17.2, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(0.96))
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)

                    Text(planRhythmSubtitle)
                        .font(.system(size: 13.8, weight: .medium))
                        .foregroundStyle(WeekFitTheme.meal.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    rhythmNextRow
                        .padding(.top, 1)
                }

                Spacer(minLength: 6)

                rhythmPulseCluster
                    .frame(width: 56, height: 38)
                    .padding(.trailing, 2)
            }
            .padding(.horizontal, 14)
            .frame(height: 104)
            .background { planRhythmBackground }
            .overlay { planRhythmBorder }
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 9)
            .shadow(color: WeekFitTheme.meal.opacity(0.035), radius: 22, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(planRhythmTitle)
    }

    private var rhythmProgressBadge: some View {
        ZStack {
            Circle()
                .stroke(WeekFitTheme.meal.opacity(0.070), lineWidth: 3.2)

            Circle()
                .trim(from: 0, to: planRhythmProgress)
                .stroke(
                    WeekFitTheme.meal.opacity(0.60),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(WeekFitTheme.meal.opacity(0.070))
                .frame(width: 23, height: 23)
                .overlay {
                    Image(systemName: selectedDayActivities.isEmpty ? "plus" : "checkmark.seal.fill")
                        .font(.system(size: 10.6, weight: .bold))
                        .foregroundStyle(WeekFitTheme.meal.opacity(0.72))
                }
        }
        .frame(width: 42, height: 42)
    }

    private var rhythmNextRow: some View {
        HStack(spacing: 6) {
            Text(nextUpcomingActivity == nil && !selectedDayActivities.isEmpty ? "Done" : "Next")
                .font(.system(size: 11.1, weight: .medium))
                .foregroundStyle(textSecondary.opacity(0.64))

            Text("•")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.27))

            Text(planRhythmNextTitle)
                .font(.system(size: 11.1, weight: .semibold))
                .foregroundStyle((nextUpcomingActivity.map { activityAccent(for: $0) } ?? WeekFitTheme.meal).opacity(0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .padding(.horizontal, 8)
                .frame(height: 21)
                .background {
                    Capsule(style: .continuous)
                        .fill((nextUpcomingActivity.map { activityAccent(for: $0) } ?? WeekFitTheme.meal).opacity(0.058))
                }
        }
    }

    private var rhythmPulseCluster: some View {
        ZStack {
            Circle()
                .fill(WeekFitTheme.meal.opacity(0.080))
                .frame(width: 28, height: 28)
                .blur(radius: 0.4)
                .offset(x: -9, y: 3)

            Circle()
                .fill(WeekFitTheme.meal.opacity(0.045))
                .frame(width: 42, height: 42)
                .blur(radius: 1.2)
                .offset(x: 12, y: -2)

            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(WeekFitTheme.meal.opacity(index == 2 ? 0.30 : 0.17))
                        .frame(
                            width: index == 2 ? 5.5 : 4,
                            height: index == 2 ? 5.5 : 4
                        )
                        .offset(y: index == 1 ? -4 : index == 3 ? -7 : 0)
                }
            }
            .opacity(0.72)
        }
        .allowsHitTesting(false)
    }

    private var planRhythmBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.105, green: 0.125, blue: 0.116),
                            Color(red: 0.055, green: 0.064, blue: 0.062)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            WeekFitTheme.meal.opacity(0.155),
                            WeekFitTheme.meal.opacity(0.040),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 210
                    )
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.035),
                            Color.white.opacity(0.006),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private var planRhythmBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.082),
                        WeekFitTheme.meal.opacity(0.045),
                        Color.white.opacity(0.018)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    timelineScrollAnchors
                    timelineGrid
                    futureTimelineAtmosphereLayer
                    timelineEventsLayer
                    currentTimeIndicatorLayer
                }
                .padding(.top, timelineTopPadding)
                .frame(height: timelineContentHeight + timelineTopPadding, alignment: .top)
                .padding(.horizontal, WeekFitStyle.Size.horizontalPadding)
                 .padding(.bottom, showAddActivity ? 300 : 48)
            }
            .coordinateSpace(name: "PlanWeekTimelineScroll")
            .onAppear {
                scrollToCurrentHour(proxy)
                loadCustomMeals()
            }
            .onChange(of: selectedDate) { _, _ in
                scrollToCurrentHour(proxy)
            }
            .onChange(of: showAddActivity) { _, isOpen in
                if isOpen {
                    scrollToCurrentHour(proxy)
                }
            }
        }
    }

    private var timelineContentHeight: CGFloat {
        CGFloat(timelineEndHour - timelineStartHour) * timelineHourHeight
    }

    private var dayActivities: [PlannedActivity] {
        plannedActivities
            .filter {
                calendar.isDate($0.date, inSameDayAs: selectedDate)
                && !$0.isSkipped
            }
            .sorted { $0.date < $1.date }
    }

    private var timelineScrollAnchors: some View {
        VStack(spacing: 0) {
            ForEach(
                Array(stride(from: 0, through: (timelineEndHour - timelineStartHour) * 60, by: 5)),
                id: \.self
            ) { minutes in
                Color.clear
                    .frame(height: CGFloat(5) / 30 * timelineThirtyMinuteHeight)
                    .id(timelineAnchorID(forMinutes: minutes))
            }
        }
        .frame(height: timelineContentHeight, alignment: .top)
        .allowsHitTesting(false)
    }

    private func timelineAnchorID(forMinutes minutes: Int) -> String {
        "timeline-anchor-\(minutes)"
    }

    private func timelineAnchorID(for date: Date) -> String {
        let minutes = minutesFromTimelineStart(for: date)
        let snapped = Int((CGFloat(minutes) / 5.0).rounded()) * 5

        let clamped = max(
            0,
            min(snapped, (timelineEndHour - timelineStartHour) * 60)
        )

        return timelineAnchorID(forMinutes: clamped)
    }

    private var futureTimelineAtmosphereLayer: some View {
        GeometryReader { geometry in
            let railX = timelineEventLeftOffset - 10
            let width = max(geometry.size.width - railX, 0)
            let now = Date()

            ZStack(alignment: .topLeading) {
                ForEach(ambientSuggestionSlots(), id: \.self) { slot in
                    let y = yPosition(for: slot)
                    let isFutureToday = !calendar.isDateInToday(selectedDate) || slot > now

                    if isFutureToday {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(WeekFitTheme.meal.opacity(0.12))
                                .frame(width: 3, height: 3)

                            Text(ambientTimelineLabel(for: slot))
                                .font(.system(size: 9.4, weight: .medium))
                                .foregroundStyle(textSecondary.opacity(0.18))
                                .lineLimit(1)

                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.028),
                                            Color.white.opacity(0.000)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(height: 1)
                        }
                        .frame(width: width, alignment: .leading)
                        .offset(x: railX + 10, y: y - 5)
                        .opacity(dayActivities.contains { abs($0.date.timeIntervalSince(slot)) < 45 * 60 } ? 0.0 : 1.0)
                    }
                }
            }
        }
        .frame(height: timelineContentHeight)
        .allowsHitTesting(false)
    }

    private func ambientSuggestionSlots() -> [Date] {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        return [10, 13, 18, 21].compactMap { hour in
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfDay)
        }
    }

    private func ambientTimelineLabel(for date: Date) -> String {
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 7..<11:
            return "morning build"
        case 11..<15:
            return "fuel window"
        case 15..<19:
            return "movement window"
        default:
            return "wind down"
        }
    }

    private var timelineGrid: some View {
        GeometryReader { geometry in
            let railX = timelineEventLeftOffset - 10
            let lineWidth = max(geometry.size.width - railX, 0)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.000),
                                Color.white.opacity(0.030),
                                Color.white.opacity(0.030),
                                Color.white.opacity(0.000)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 0.65, height: timelineContentHeight)
                    .offset(x: railX, y: 0)

                ForEach(timelineStartHour...timelineEndHour, id: \.self) { hour in
                    let y = CGFloat(hour - timelineStartHour) * timelineHourHeight

                    Text("\(hour)")
                        .font(WeekFitStyle.Font.timelineTime)
                        .foregroundStyle(textSecondary.opacity(0.27))
                        .frame(width: railX - 3, alignment: .trailing)
                        .offset(x: 0, y: y - 6)

                    Rectangle()
                        .fill(Color.white.opacity(0.055))
                        .frame(width: lineWidth, height: 1)
                        .offset(x: railX, y: y)

                    if hour < timelineEndHour {
                        Rectangle()
                            .fill(Color.white.opacity(0.024))
                            .frame(width: lineWidth, height: 1)
                            .mask {
                                TimelineDashMask()
                            }
                            .offset(x: railX, y: y + timelineThirtyMinuteHeight)
                    }
                }
            }
        }
        .frame(height: timelineContentHeight)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var currentTimeIndicatorLayer: some View {
        if calendar.isDateInToday(selectedDate) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                GeometryReader { geometry in
                    let railX = timelineEventLeftOffset - 10
                    let maxMinutes = (timelineEndHour - timelineStartHour) * 60
                    let minutes = minutesFromTimelineStart(for: context.date)

                    let visible = minutes >= 0 && minutes <= maxMinutes

                    let rawY = CGFloat(minutes) / 60.0 * timelineHourHeight

                    let y = max(rawY, 18)
                    let contentWidth = max(geometry.size.width - railX, 0)
                    let dotSize: CGFloat = 5

                    if visible {
                        ZStack(alignment: .topLeading) {

                            RadialGradient(
                                colors: [
                                    nowAccent.opacity(0.030),
                                    nowAccent.opacity(0.010),
                                    Color.clear
                                ],
                                center: .leading,
                                startRadius: 4,
                                endRadius: 190
                            )
                            .frame(width: contentWidth, height: 92)
                            .offset(x: railX, y: y - 46)

                            Text(context.date.formatted(.dateTime.hour().minute()))
                                .font(.system(size: 11.2, weight: .medium))
                                .foregroundStyle(nowAccent.opacity(0.82))
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(width: 56, alignment: .trailing)
                                .offset(x: railX - 52, y: y - 7)

                            HStack(spacing: 0) {
                                Circle()
                                    .fill(nowAccent.opacity(0.78))
                                    .frame(width: dotSize, height: dotSize)
                                    .shadow(
                                        color: nowAccent.opacity(0.18),
                                        radius: 5,
                                        y: 1
                                    )
                                    .offset(x: -dotSize / 2)

                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                nowAccent.opacity(0.30),
                                                nowAccent.opacity(0.10),
                                                nowAccent.opacity(0.00)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: contentWidth, height: 1)
                            }
                            .offset(x: railX, y: y - dotSize / 2)
                        }
                        .frame(
                            width: geometry.size.width,
                            height: timelineContentHeight,
                            alignment: .topLeading
                        )
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private var timelineEventsLayer: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - timelineEventLeftOffset, 120)
            let layout = eventLayoutItems(in: availableWidth)

            ZStack(alignment: .topLeading) {
                ForEach(layout) { layoutItem in
                    let item = layoutItem.activity
                    let isDragging = draggedActivityID == item.id
                    let isCompact = layoutItem.columnCount > 1 && !isDragging
                    let displayDate = isDragging ? (dragPreviewDate ?? item.date) : item.date
                    let height = eventVisualHeight(for: item, previewDate: displayDate)
                    let visualY = yPosition(for: displayDate) + 1

                    let cardScale: CGFloat = isDragging ? 1.018 : 1.0

                    let isConflict = isDragging && dragPreviewDate.map {
                        hasTimeConflict(
                            newStart: $0,
                            durationMinutes: item.durationMinutes,
                            excluding: item
                        )
                    } ?? false

                    ZStack(alignment: .topLeading) {
                        plannedCard(
                            item,
                            previewDate: displayDate,
                            isDragging: isDragging,
                            isConflict: isConflict,
                            isCompact: isCompact
                        )
                        .contentShape(RoundedRectangle(cornerRadius: timelineCardCornerRadius, style: .continuous))
                        .onTapGesture {
                            guard draggedActivityID == nil else { return }
                            startEditing(item)
                        }
                        .simultaneousGesture(
                            dragGesture(for: item),
                            including: .gesture
                        )
                    }
                    .frame(width: layoutItem.width, height: height)
                    .offset(
                        x: timelineEventLeftOffset + layoutItem.x,
                        y: visualY
                    )
                    .scaleEffect(cardScale, anchor: .center)
                    .zIndex(isDragging ? 100 : Double(layoutItem.column + 5))
                    .transaction { transaction in
                        if isDragging {
                            transaction.animation = nil
                        }
                    }
                    .animation(
                        isDragging ? nil : .spring(response: 0.28, dampingFraction: 0.82),
                        value: isDragging
                    )
                }
            }
        }
        .frame(height: timelineContentHeight)
    }

    private func isConflictColor(isDragging: Bool, activity: PlannedActivity) -> Color {
        if isDragging,
           let dragPreviewDate,
           hasTimeConflict(
               newStart: dragPreviewDate,
               durationMinutes: activity.durationMinutes,
               excluding: activity
           ) {
            return Color.red
        }

        return WeekFitTheme.meal
    }

    private func dragHandle(
        for item: PlannedActivity,
        height: CGFloat
    ) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 64, height: height)
            .contentShape(Rectangle())
            .highPriorityGesture(
                dragGesture(for: item),
                including: .all
            )
    }

    private struct TimelineLayoutItem: Identifiable {
        let id: String
        let activity: PlannedActivity
        let start: Date
        let end: Date
        let column: Int
        let columnCount: Int
        let x: CGFloat
        let width: CGFloat
    }

    private func eventLayoutItems(in availableWidth: CGFloat) -> [TimelineLayoutItem] {
        struct EventProxy {
            let activity: PlannedActivity
            let start: Date
            let end: Date
        }

        let spacing: CGFloat = 6

        let events: [EventProxy] = dayActivities
            .map { activity in
                let start = effectiveDate(for: activity)
                let end = calendar.date(
                    byAdding: .minute,
                    value: max(activity.durationMinutes, timelineMinuteStep),
                    to: start
                ) ?? start

                return EventProxy(activity: activity, start: start, end: end)
            }
            .sorted {
                if $0.start == $1.start {
                    return $0.end < $1.end
                }
                return $0.start < $1.start
            }

        var result: [TimelineLayoutItem] = []
        var group: [EventProxy] = []
        var groupEnd: Date?

        func flushGroup() {
            guard !group.isEmpty else { return }

            var columnEnds: [Date] = []
            var assignments: [(event: EventProxy, column: Int)] = []

            for event in group.sorted(by: { $0.start < $1.start }) {
                if let freeColumn = columnEnds.firstIndex(where: { $0 <= event.start }) {
                    columnEnds[freeColumn] = event.end
                    assignments.append((event, freeColumn))
                } else {
                    columnEnds.append(event.end)
                    assignments.append((event, columnEnds.count - 1))
                }
            }

            let groupColumnCount = max(columnEnds.count, 1)
            let rawWidth = (availableWidth - CGFloat(groupColumnCount - 1) * spacing) / CGFloat(groupColumnCount)
            let itemWidth = groupColumnCount > 1 ? max(rawWidth, 88) : availableWidth

            for assignment in assignments {
                let x = groupColumnCount > 1
                ? CGFloat(assignment.column) * (itemWidth + spacing)
                : 0

                result.append(
                    TimelineLayoutItem(
                        id: assignment.event.activity.id,
                        activity: assignment.event.activity,
                        start: assignment.event.start,
                        end: assignment.event.end,
                        column: assignment.column,
                        columnCount: groupColumnCount,
                        x: x,
                        width: itemWidth
                    )
                )
            }

            group.removeAll()
            groupEnd = nil
        }

        for event in events {
            if group.isEmpty {
                group = [event]
                groupEnd = event.end
                continue
            }

            if let currentGroupEnd = groupEnd, event.start < currentGroupEnd {
                group.append(event)
                if event.end > currentGroupEnd {
                    groupEnd = event.end
                }
            } else {
                flushGroup()
                group = [event]
                groupEnd = event.end
            }
        }

        flushGroup()

        return result.sorted {
            if $0.start == $1.start {
                return $0.column < $1.column
            }
            return $0.start < $1.start
        }
    }
    
    private func effectiveDate(for activity: PlannedActivity) -> Date {
        if draggedActivityID == activity.id, let dragPreviewDate {
            return dragPreviewDate
        }

        return activity.date
    }
    
    private func roundedToNext15Minutes(_ date: Date) -> Date {
        let minute = calendar.component(.minute, from: date)
        let hour = calendar.component(.hour, from: date)

        let nextMinute = ((minute / timelineMinuteStep) + 1) * timelineMinuteStep

        if nextMinute >= 60 {
            return calendar.date(
                bySettingHour: hour + 1,
                minute: 0,
                second: 0,
                of: date
            ) ?? date
        }

        return calendar.date(
            bySettingHour: hour,
            minute: nextMinute,
            second: 0,
            of: date
        ) ?? date
    }

    private func eventEndDate(_ activity: PlannedActivity, using startDate: Date? = nil) -> Date {
        let start = startDate ?? effectiveDate(for: activity)

        return calendar.date(
            byAdding: .minute,
            value: max(activity.durationMinutes, timelineMinuteStep),
            to: start
        ) ?? start
    }

    private func isPastActivity(_ activity: PlannedActivity, previewDate: Date? = nil) -> Bool {
        let start = previewDate ?? activity.date
        let end = eventEndDate(activity, using: start)

        return end < Date()
    }

    private func eventVisualHeight(for durationMinutes: Int) -> CGFloat {
        let duration = max(durationMinutes, timelineMinimumDurationMinutes)
        let proportionalHeight = CGFloat(duration) / 30 * timelineThirtyMinuteHeight

        if duration <= 15 {
            return max(23, proportionalHeight)
        }

        return max(30, proportionalHeight - 5)
    }

    private func eventVisualHeight(
        for activity: PlannedActivity,
        previewDate: Date? = nil
    ) -> CGFloat {
        eventVisualHeight(for: activity.durationMinutes)
    }

    private func dateForTimelineSlot(hour: Int, step: Int) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: step * timelineMinuteStep,
            second: 0,
            of: selectedDate
        ) ?? selectedDate
    }

    private func minutesFromTimelineStart(for date: Date) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return ((hour - timelineStartHour) * 60) + minute
    }

    private func yPosition(for date: Date) -> CGFloat {
        let totalMinutes = minutesFromTimelineStart(for: date)
        let clampedMinutes = max(
            0,
            min(totalMinutes, (timelineEndHour - timelineStartHour) * 60)
        )

        return CGFloat(clampedMinutes) / 30 * timelineThirtyMinuteHeight
    }

    private func dateForTimelinePosition(_ y: CGFloat) -> Date {
        let rawMinutes = y / timelineThirtyMinuteHeight * 30
        let snappedMinutes = Int((rawMinutes / CGFloat(timelineMinuteStep)).rounded()) * timelineMinuteStep

        let clampedMinutes = max(
            0,
            min(
                snappedMinutes,
                (timelineEndHour - timelineStartHour) * 60
            )
        )

        let timelineStart = calendar.date(
            bySettingHour: timelineStartHour,
            minute: 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate

        return calendar.date(
            byAdding: .minute,
            value: clampedMinutes,
            to: timelineStart
        ) ?? timelineStart
    }


    private func dragCenterY(
        for activity: PlannedActivity,
        translationY: CGFloat
    ) -> CGFloat {

        let startY = yPosition(for: activity.date)
        let height = eventVisualHeight(for: activity)

        return startY + translationY + (height / 2)
    }

    @ViewBuilder
    private func timelineRow(_ slot: Date) -> some View {
        let isSelected = selectedSlot.map {
            calendar.isDate($0, equalTo: slot, toGranularity: .hour)
        } ?? false

        let items = itemsForSlot(slot)

        timelineRowContent(
            slot: slot,
            items: items,
            isSelected: isSelected
        )
    }

    private func timelineRowContent(
        slot: Date,
        items: [PlannedActivity],
        isSelected: Bool
    ) -> some View {
        let isEmpty = items.isEmpty && !isSelected

        return HStack(alignment: .top, spacing: 10) {
            Text(slotTitle(slot))
                .font(isSelected ? WeekFitStyle.Font.timelineTimeActive : WeekFitStyle.Font.timelineTime)
                .foregroundStyle(isSelected ? WeekFitTheme.meal.opacity(0.96) : textSecondary)
                .frame(width: 32, alignment: .leading)

            timelineMarker(isSelected: isSelected, isEmpty: isEmpty)

            if !items.isEmpty {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        plannedCard(
                            item,
                            previewDate: draggedActivityID == item.id
                            ? dragPreviewDate
                            : nil
                        )
                        .offset(
                            y: draggedActivityID == item.id
                            ? dragTranslationY
                            : 0
                        )
                        .scaleEffect(
                            draggedActivityID == item.id
                            ? 1.035
                            : 1.0
                        )
                        .zIndex(
                            draggedActivityID == item.id
                            ? 20
                            : 0
                        )
                        .opacity(
                            draggedActivityID == item.id
                            ? 0.96
                            : 1.0
                        )
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded {
                                    guard draggedActivityID == nil else { return }
                                    startEditing(item)
                                }
                        )
                        .simultaneousGesture(
                            dragGesture(for: item),
                            including: .gesture
                        )
                    }
                }
            } else if isSelected {
                selectedEmptySlot
            } else {
                cleanEmptySlot
            }
        }
        .frame(
            height: isEmpty
            ? WeekFitStyle.Size.timelineEmptyRow
            : max(WeekFitStyle.Size.timelineRow, CGFloat(items.count) * (WeekFitStyle.Size.plannedCardHeight + 8))
        )
    }

    private func timelineMarker(isSelected: Bool, isEmpty: Bool) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.045))
                .frame(width: 1)

            Circle()
                .fill(isSelected ? WeekFitTheme.meal.opacity(0.96) : Color.white.opacity(0.16))
                .frame(width: isSelected ? 8 : 5, height: isSelected ? 8 : 5)
                .shadow(
                    color: isSelected ? WeekFitTheme.meal.opacity(0.28) : .clear,
                    radius: 6,
                    y: 2
                )
                .offset(y: 5)
        }
        .frame(width: 8, height: isEmpty ? 48 : WeekFitStyle.Size.timelineRow)
    }

    private var cleanEmptySlot: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.050))
                .frame(width: 38, height: 6)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.030))
                .frame(width: 82, height: 6)

            Spacer()
        }
        .padding(.top, 8)
        .opacity(0.42)
    }

    private var selectedEmptySlot: some View {
        HStack(spacing: 7) {
            Spacer()

            Image(systemName: "plus")
                .font(WeekFitStyle.Font.icon)

            Text("Add activity")
                .font(WeekFitStyle.Font.button)

            Spacer()
        }
        .foregroundStyle(WeekFitTheme.meal.opacity(0.96))
        .frame(height: 38)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WeekFitTheme.meal.opacity(0.095))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    WeekFitTheme.meal.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1.1, dash: [5])
                )
        }
        .shadow(color: WeekFitTheme.meal.opacity(0.08), radius: 10, y: 5)
    }

    private func activityAccent(for item: PlannedActivity) -> Color {
        switch item.type.lowercased() {
        case "workout":
            return workoutAccent
        case "recovery":
            return recoveryAccent
        case "meal":
            return mealAccent
        case "habit":
            return habitAccent
        default:
            return item.color
        }
    }

    private func plannedCard(
        _ item: PlannedActivity,
        previewDate: Date? = nil,
        isDragging: Bool = false,
        isConflict: Bool = false,
        isCompact: Bool = false
    ) -> some View {
        let accent = activityAccent(for: item)
        let style = timelineStyle(for: item)
        let displayDate = previewDate ?? item.date
        let height = eventVisualHeight(for: item, previewDate: displayDate)
        let isPast = (item.isCompleted || isPastActivity(item, previewDate: displayDate)) && !isDragging && !isConflict
        let isShortEvent = height <= timelineThirtyMinuteHeight / 2 + 1
        let isCurrentWindow = !isPast && calendar.isDateInToday(selectedDate) && displayDate <= Date() && eventEndDate(item, using: displayDate) >= Date()

        let titleSize: CGFloat = isCompact ? 10.6 : isShortEvent ? 10.8 : 12.4
        let horizontalPadding: CGFloat = isShortEvent ? 8 : 10
        let handleOpacity = isPast ? 0.20 : isDragging ? 0.62 : 0.26
        let borderColor: Color = isConflict ? Color.red.opacity(0.40) : isDragging ? accent.opacity(0.34) : isCurrentWindow ? accent.opacity(0.20) : isPast ? Color.white.opacity(0.035) : style.border
        let backgroundFill = isPast ? cardSecondary.opacity(0.24) : style.background
        let titleOpacity = isPast ? 0.54 : isCurrentWindow ? 0.98 : 0.92
        let topLightOpacity = isPast ? style.topLightOpacity * 0.36 : isCurrentWindow ? style.topLightOpacity * 1.7 : style.topLightOpacity

        let iconContainerSize = min(max(height - 7, 14), isShortEvent ? 16 : 23)
        let iconFontSize = min(max(iconContainerSize * 0.50, 8.6), 12.8)
        let iconBackgroundOpacity = isPast ? style.iconOpacity * 0.55 : isCurrentWindow ? style.iconOpacity * 1.35 : style.iconOpacity
        let iconForegroundOpacity = isPast ? 0.48 : isCurrentWindow ? 0.96 : 0.86

        return HStack(spacing: isShortEvent ? 5 : 8) {
            Circle()
                .fill(accent.opacity(iconBackgroundOpacity))
                .frame(width: iconContainerSize, height: iconContainerSize)
                .overlay {
                    Image(systemName: item.icon)
                        .font(.system(size: iconFontSize, weight: .semibold))
                        .foregroundStyle(accent.opacity(iconForegroundOpacity))
                }

            VStack(alignment: .leading, spacing: 1.5) {
                Text(shortDisplayTitle(item.title))
                    .font(.system(size: titleSize, weight: isPast ? .medium : style.titleWeight))
                    .foregroundStyle(textPrimary.opacity(titleOpacity))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.70)

                if !isShortEvent {
                    Text(activityTimelineSubtitle(for: item, displayDate: displayDate))
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(textSecondary.opacity(isPast ? 0.28 : 0.50))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }

            Spacer(minLength: isCompact ? 3 : 8)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: isShortEvent ? 10.5 : 12, weight: .bold))
                .foregroundStyle(textTertiary.opacity(handleOpacity))
                .frame(width: 18)
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: height)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: timelineCardCornerRadius, style: .continuous)
                    .fill(
                        isPast
                        ? cardSecondary.opacity(0.28)
                        : Color(red: 0.070, green: 0.074, blue: 0.077).opacity(1.0)
                    )

                RoundedRectangle(cornerRadius: timelineCardCornerRadius, style: .continuous)
                    .fill(backgroundFill)

                if isCurrentWindow || isDragging {
                    RoundedRectangle(cornerRadius: timelineCardCornerRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    accent.opacity(isDragging ? 0.16 : 0.10),
                                    accent.opacity(0.020),
                                    Color.clear
                                ],
                                center: .leading,
                                startRadius: 2,
                                endRadius: 170
                            )
                        )
                }

                RoundedRectangle(cornerRadius: timelineCardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(topLightOpacity),
                                Color.white.opacity(0.004),
                                Color.white.opacity(0.000)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: timelineCardCornerRadius, style: .continuous)
                .stroke(
                    borderColor,
                    lineWidth: isDragging || isConflict || isCurrentWindow ? 1.25 : 1
                )
        }
        .shadow(
            color: isDragging
            ? accent.opacity(0.26)
            : accent.opacity(isPast ? 0.003 : isCurrentWindow ? 0.060 : style.shadowOpacity),
            radius: isDragging ? 12 : isPast ? 1.0 : isCurrentWindow ? 12 : style.shadowRadius * 0.48,
            x: 0,
            y: isDragging ? 6 : isPast ? 1 : isCurrentWindow ? 5 : style.shadowY * 0.48
        )
        .shadow(
            color: Color.black.opacity(isDragging ? 0.20 : isPast ? 0.014 : style.depthShadowOpacity),
            radius: isDragging ? 10 : isPast ? 1.4 : style.depthShadowRadius * 0.52,
            x: 0,
            y: isDragging ? 5 : isPast ? 1 : style.depthShadowY * 0.52
        )
        .opacity(isPast ? 0.78 : 1.0)
        .saturation(isPast ? 0.72 : 1.0)
        .compositingGroup()
    }

    private func activityTimelineSubtitle(
        for item: PlannedActivity,
        displayDate: Date
    ) -> String {
        let time: String

        if draggedActivityID == item.id, let focusedDragSlot {
            time = slotTitle(focusedDragSlot)
        } else {
            time = slotTitle(displayDate)
        }
        
        let duration = "\(item.durationMinutes) min"

        if item.isCompleted || isPastActivity(item, previewDate: displayDate) {
            switch item.type.lowercased() {
            case "meal":
                return "\(time) • Meal logged"
            case "workout":
                return "\(time) • Training finished"
            case "recovery":
                return "\(time) • Completed"
            case "habit":
                return "\(time) • Completed"
            default:
                return "\(time) • Completed"
            }
        }

        switch item.type.lowercased() {
        case "meal":
            return "\(time) • Nutrition • \(duration)"
        case "workout":
            return "\(time) • Movement • \(duration)"
        case "recovery":
            return "\(time) • Recovery • \(duration)"
        case "habit":
            return "\(time) • Routine • \(duration)"
        default:
            return "\(time) • \(duration)"
        }
    }

    private func timelineStyle(for item: PlannedActivity) -> TimelineCardStyle {
        let accent = activityAccent(for: item)

        switch item.type.lowercased() {
        case "workout":
            return TimelineCardStyle(
                background: accent.opacity(0.038),
                border: accent.opacity(0.070),
                iconOpacity: 0.086,
                shadowOpacity: 0.030,
                shadowRadius: 13,
                shadowY: 5,
                depthShadowOpacity: 0.078,
                depthShadowRadius: 14,
                depthShadowY: 7,
                titleWeight: .semibold,
                topLightOpacity: 0.032
            )

        case "meal":
            return TimelineCardStyle(
                background: accent.opacity(0.034),
                border: accent.opacity(0.056),
                iconOpacity: 0.074,
                shadowOpacity: 0.024,
                shadowRadius: 11,
                shadowY: 4,
                depthShadowOpacity: 0.064,
                depthShadowRadius: 12,
                depthShadowY: 6,
                titleWeight: .semibold,
                topLightOpacity: 0.034
            )

        case "recovery":
            return TimelineCardStyle(
                background: accent.opacity(0.036),
                border: accent.opacity(0.072),
                iconOpacity: 0.082,
                shadowOpacity: 0.028,
                shadowRadius: 12,
                shadowY: 5,
                depthShadowOpacity: 0.060,
                depthShadowRadius: 14,
                depthShadowY: 7,
                titleWeight: .semibold,
                topLightOpacity: 0.034
            )

        case "habit":
            return TimelineCardStyle(
                background: accent.opacity(0.034),
                border: accent.opacity(0.062),
                iconOpacity: 0.086,
                shadowOpacity: 0.020,
                shadowRadius: 9,
                shadowY: 4,
                depthShadowOpacity: 0.054,
                depthShadowRadius: 10,
                depthShadowY: 5,
                titleWeight: .semibold,
                topLightOpacity: 0.026
            )

        default:
            return TimelineCardStyle(
                background: cardSecondary.opacity(0.20),
                border: borderSoft.opacity(0.30),
                iconOpacity: 0.082,
                shadowOpacity: 0.012,
                shadowRadius: 6,
                shadowY: 3,
                depthShadowOpacity: 0.045,
                depthShadowRadius: 9,
                depthShadowY: 5,
                titleWeight: .medium,
                topLightOpacity: 0.020
            )
        }
    }

    private struct TimelineCardStyle {
        let background: Color
        let border: Color
        let iconOpacity: Double
        let shadowOpacity: Double
        let shadowRadius: CGFloat
        let shadowY: CGFloat
        let depthShadowOpacity: Double
        let depthShadowRadius: CGFloat
        let depthShadowY: CGFloat
        let titleWeight: Font.Weight
        let topLightOpacity: Double
    }


    private func sheetSectionHeader(
        _ title: String,
        subtitle: String? = nil,
        trailing: String? = nil
    ) -> some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15.6, weight: .semibold))
                    .foregroundStyle(textPrimary.opacity(0.93))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.2, weight: .regular))
                        .foregroundStyle(textSecondary.opacity(0.66))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            Spacer()

            if let trailing {
                Button {
                    lightHaptic.impactOccurred()
                } label: {
                    Text(trailing)
                        .font(.system(size: 12.2, weight: .semibold))
                        .foregroundStyle(selectedType.color.opacity(0.78))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chooseItemSubtitle: String {
        switch selectedType {
        case .meal:
            return customMeals.isEmpty ? "Suggested meals for today" : "Custom meals you've saved"
        case .workout:
            return "Choose the movement that fits your day"
        case .recovery:
            return "Support recovery and keep momentum"
        case .habit:
            return "Small routines that keep the day on track"
        }
    }

    private var timeSectionSubtitle: String {
        hasSelectedTimeConflict ? "Choose a free slot" : "Best time for you"
    }

    private var durationSectionSubtitle: String {
        selectedType == .recovery ? "Recommended for recovery balance" : "Recommended for energy balance"
    }

    private var selectedTimeIntelligenceLabel: String {
        guard let selectedSlot else { return "Choose time" }
        guard !hasSelectedTimeConflict else { return "Overlap" }

        let hour = calendar.component(.hour, from: selectedSlot)

        switch selectedType {
        case .meal:
            switch hour {
            case 6...10: return "Good breakfast window"
            case 11...14: return "Good lunch window"
            case 17...21: return "Good dinner window"
            default: return "Light fuel window"
            }
        case .workout:
            switch hour {
            case 6...10: return "Strong energy window"
            case 11...15: return "Balanced training time"
            case 16...19: return "Good cardio timing"
            default: return "Keep it gentle"
            }
        case .recovery:
            switch hour {
            case 6...11: return "Easy reset window"
            case 12...17: return "Good recovery gap"
            default: return "Wind-down friendly"
            }
        case .habit:
            switch hour {
            case 6...11: return "Good morning anchor"
            case 12...17: return "Steady routine slot"
            default: return "Calm evening anchor"
            }
        }
    }

    private var selectedTimeStatusText: String {
        hasSelectedTimeConflict ? "This time overlaps another activity" : selectedTimeIntelligenceLabel
    }


    private var addActivitySheet: some View {
        VStack(alignment: .leading, spacing: 7) {
            addSheetGrabber
            sheetHeader
                .padding(.bottom, 1)
            activityTypePickerSection
            itemPickerSection
            timePickerSection
            durationPickerSection
            saveButton
                .padding(.top, hasSelectedTimeConflict ? 6 : 2)

            if let editingActivity {
                deleteButton(editingActivity)
            }
        }
        .padding(.horizontal, WeekFitStyle.Size.horizontalPadding)
        .padding(.top, 7)
        .padding(.bottom, editingActivity == nil ? 11 : 10)
        .frame(height: addSheetHeight, alignment: .top)
        .clipped()
        .background { addSheetBackground }
        .overlay { addSheetBorder }
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: -5)
        .shadow(color: selectedType.color.opacity(0.012), radius: 12, x: 0, y: -2)
        .padding(.horizontal, addSheetHorizontalInset)
        .padding(.bottom, 7)
    }

    private var addSheetGrabber: some View {
        Capsule()
            .fill(Color.white.opacity(0.12))
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 2)
    }

    private var activityTypePickerSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sheetSectionHeader("Activity", subtitle: "What do you want to add?")

            HStack(spacing: 9) {
                ForEach(PlannerType.allCases, id: \.self) { type in
                    typeButton(type)
                }
            }
        }
    }

    private var itemPickerSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sheetSectionHeader(
                selectedType == .meal ? "Choose meal" : "Choose activity",
                subtitle: chooseItemSubtitle,
                trailing: selectedType == .meal ? "View all" : nil
            )
            .padding(.top, 1)

            itemPickerCarousel
                .frame(height: addSheetMealCardHeight + 8)
        }
    }

    private var itemPickerCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if selectedType == .meal {
                        ForEach(availableMeals) { meal in
                            mealOptionCard(meal)
                                .id(meal.id)
                        }
                    } else {
                        ForEach(currentOptions) { option in
                            optionCard(option)
                                .id(optionScrollID(option))
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .mask { horizontalFadeMask }
            .onAppear { scrollToSelectedOption(proxy) }
            .onChange(of: selectedItem.title) { _, _ in scrollToSelectedOption(proxy) }
            .onChange(of: selectedType) { _, _ in scrollToSelectedOption(proxy) }
        }
    }

    private var timePickerSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sheetSectionHeader("When", subtitle: timeSectionSubtitle)
                .padding(.top, 2)

            timeSelectionSection
        }
    }

    @ViewBuilder
    private var durationPickerSection: some View {
        if selectedType == .workout || selectedType == .recovery {
            VStack(alignment: .leading, spacing: 7) {
                sheetSectionHeader("Duration", subtitle: durationSectionSubtitle)
                    .padding(.top, 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        durationButton(15)
                        durationButton(30)
                        durationButton(45)
                        durationButton(60)
                        customDurationButton
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
                .mask { durationFadeMask }
            }
        }
    }

    private var horizontalFadeMask: some View {
        LinearGradient(
            colors: [Color.clear, Color.black, Color.black, Color.clear],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var durationFadeMask: some View {
        LinearGradient(
            colors: [Color.black, Color.black, Color.black, Color.clear],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var addSheetBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: addSheetCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.046, green: 0.050, blue: 0.054),
                            Color(red: 0.032, green: 0.036, blue: 0.039)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: addSheetCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.010),
                            Color.white.opacity(0.004),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        }
    }

    private var addSheetBorder: some View {
        RoundedRectangle(cornerRadius: addSheetCornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.056),
                        Color.white.opacity(0.018),
                        borderSoft.opacity(0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var sheetHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(editingActivity == nil ? "Add to your day" : "Edit activity")
                    .font(.system(size: 21.5, weight: .semibold))
                    .foregroundStyle(textPrimary.opacity(0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)

                HStack(spacing: 6) {
                    Text(selectedDayTitle)
                    Text("•")
                        .foregroundStyle(textSecondary.opacity(0.58))
                    Text(selectedSlot.map { slotTitle($0) } ?? "")
                        .foregroundStyle(selectedType.color.opacity(0.78))
                        .monospacedDigit()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(textSecondary.opacity(0.82))
            }

            Spacer()

            Button {
                closeAddSheet()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(textPrimary.opacity(0.88))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.045))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.040), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 1)
            .accessibilityLabel("Close")
        }
    }

    private var saveButton: some View {
        let topOpacity: Double = selectedType == .workout ? 0.38 : 0.42
        let bottomOpacity: Double = selectedType == .workout ? 0.32 : 0.36

        return Button {
            saveSelectedItem()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: editingActivity == nil ? "plus.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 14.5, weight: .semibold))

                Text(editingActivity == nil ? addButtonTitle : "Save changes")
                    .font(.system(size: 15.2, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .foregroundStyle(saveButtonForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient(
                    colors: [
                        selectedType.color.opacity(topOpacity),
                        selectedType.color.opacity(bottomOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
            }
            .shadow(color: selectedType.color.opacity(0.020), radius: 4, y: 2)
            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 3)
            .shadow(color: selectedType.color.opacity(0.08), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(editingActivity == nil ? addButtonTitle : "Save changes")
    }
    
    private var saveButtonForeground: Color {
        switch selectedType {
        case .workout, .recovery:
            return Color.white.opacity(0.90)
        case .meal, .habit:
            return Color.black.opacity(0.82)
        }
    }

    private var addButtonTitle: String {
        switch selectedType {
        case .meal:
            return "Add meal"
        case .workout:
            return "Add workout"
        case .recovery:
            return "Add recovery"
        case .habit:
            return "Add habit"
        }
    }

    private func deleteButton(_ activity: PlannedActivity) -> some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color.white.opacity(0.045))
                .frame(height: 1)
                .padding(.top, 2)

            Button(role: .destructive) {
                deleteActivity(activity)
                closeAddSheet()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 14.5, weight: .medium))

                    Text("Delete activity")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.36).opacity(0.72))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete activity")
        }
        .padding(.top, 2)
    }

    private var customDurationSheet: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.16))
                .frame(width: 44, height: 4)
                .padding(.top, 10)

            Text("Custom duration")
                .font(WeekFitStyle.Font.screenTitle)
                .foregroundStyle(textPrimary)

            Picker("Duration", selection: $customDuration) {
                ForEach(Array(stride(from: 5, through: 180, by: 5)), id: \.self) { minutes in
                    Text("\(minutes) min")
                        .foregroundStyle(textPrimary)
                        .tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)

            Button {
                selectedDuration = customDuration
                showCustomDuration = false
            } label: {
                Text("Set \(customDuration) min")
                    .font(WeekFitStyle.Font.button)
                    .foregroundStyle(.black.opacity(0.84))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedType.color.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 20)

            Button {
                showCustomDuration = false
            } label: {
                Text("Cancel")
                    .font(WeekFitStyle.Font.caption)
                    .foregroundStyle(textSecondary)
            }
            .padding(.bottom, 16)
        }
        .background(background)
        .presentationDetents([.height(360)])
        .preferredColorScheme(.dark)
    }

    private var smartRecommendation: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(selectedType.color.opacity(0.070))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: recommendationIcon)
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.72)
                        .foregroundStyle(selectedType.color.opacity(0.72))
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(recommendationTitle)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(textPrimary.opacity(0.92))

                Text(recommendationSubtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer()
        }
        .padding(.horizontal, 11)
        .frame(height: 44)
        .background(selectedType.color.opacity(0.032))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(selectedType.color.opacity(0.046), lineWidth: 1)
        }
    }



    private var hasSelectedTimeConflict: Bool {

        guard let selectedSlot else { return false }

        return hasTimeConflict(
            newStart: selectedSlot,
            durationMinutes: selectedDuration,
            excluding: editingActivity
        )
    }

    private var timePickerSlots: [Date] {
        let startOfTimeline = calendar.date(
            bySettingHour: timelineStartHour,
            minute: 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate

        let nowRounded = roundedToNext15Minutes(Date())

        let actualStart: Date

        if calendar.isDateInToday(selectedDate) {
            actualStart = max(startOfTimeline, nowRounded)
        } else {
            actualStart = startOfTimeline
        }

        let startOfDay = calendar.startOfDay(for: selectedDate)

        let timelineEnd = calendar.date(
            byAdding: .day,
            value: 1,
            to: startOfDay
        ) ?? selectedDate

        guard actualStart < timelineEnd else {
            return []
        }

        let totalMinutes = calendar.dateComponents(
            [.minute],
            from: actualStart,
            to: timelineEnd
        ).minute ?? 0

        let steps = max(totalMinutes / timelineMinuteStep, 0)

        return (0...steps).compactMap {
            calendar.date(
                byAdding: .minute,
                value: $0 * timelineMinuteStep,
                to: actualStart
            )
        }
    }

    private func nextAvailableNonConflictingSlot() -> Date? {

        guard let selectedSlot else { return nil }

        let futureSlots = timePickerSlots.filter {
            $0 > selectedSlot
        }

        for slot in futureSlots {

            let conflict = hasTimeConflict(
                newStart: slot,
                durationMinutes: selectedDuration,
                excluding: editingActivity
            )

            if !conflict {
                return slot
            }
        }

        return nil
    }

    private var timeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            selectedTimeSummaryCard

            compactTimePicker
                .padding(.top, 10)
        }
    }

    private var selectedTimeSummaryCard: some View {
        let conflict = hasSelectedTimeConflict
        let timeText = selectedSlot.map { slotTitle($0) } ?? "--:--"

        return HStack(spacing: 8) {
            Image(systemName: conflict ? "exclamationmark.circle.fill" : "clock")
                .font(.system(size: 12.2, weight: .semibold))
                .foregroundStyle(
                    conflict
                    ? Color(red: 1, green: 0.46, blue: 0.46).opacity(0.66)
                    : selectedType.color.opacity(0.62)
                )
                .frame(width: 22, height: 22)
                .background {
                    Circle()
                        .fill(
                            conflict
                            ? Color.red.opacity(0.055)
                            : selectedType.color.opacity(0.040)
                        )
                }

            Text(timeText)
                .font(.system(size: 18.2, weight: .semibold))
                .foregroundStyle(textPrimary.opacity(0.94))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text("•")
                .font(.system(size: 12.2, weight: .medium))
                .foregroundStyle(textSecondary.opacity(0.27))

            Text(conflict ? "Overlap" : selectedTimeIntelligenceLabel)
                .font(.system(size: 12.0, weight: .medium))
                .foregroundStyle(
                    conflict
                    ? Color(red: 1, green: 0.50, blue: 0.50).opacity(0.54)
                    : selectedType.color.opacity(0.60)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 6)

            if conflict {
                Button {
                    moveToNextFreeTime()
                } label: {
                    Text("Next free")
                        .font(.system(size: 11.6, weight: .semibold))
                        .foregroundStyle(selectedType.color.opacity(0.70))
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background {
                            Capsule(style: .continuous)
                                .fill(selectedType.color.opacity(0.044))
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(selectedType.color.opacity(0.035), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(conflict ? Color.red.opacity(0.035) : Color.white.opacity(0.022))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(
                    conflict
                    ? Color.red.opacity(0.16)
                    : Color.white.opacity(0.034),
                    lineWidth: 1
                )
        }
    }

    private var selectedTimeStatusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: hasSelectedTimeConflict ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    hasSelectedTimeConflict
                    ? Color(red: 1, green: 0.48, blue: 0.48).opacity(0.60)
                    : selectedType.color.opacity(0.56)
                )

            Text(selectedTimeStatusText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(
                    hasSelectedTimeConflict
                    ? Color(red: 1, green: 0.48, blue: 0.48).opacity(0.60)
                    : textSecondary.opacity(0.58)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 3)
        .frame(height: 18)
    }

    private func moveToNextFreeTime() {
        guard let next = nextAvailableNonConflictingSlot() else { return }

        lightHaptic.impactOccurred()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            selectedSlot = next
        }
    }

    private var compactTimePicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(timePickerSlots, id: \.self) { slot in
                        compactTimeSlotButton(slot)
                            .id(slot)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .mask { durationFadeMask }
            .onAppear { scrollToSelectedSlot(proxy) }
            .onChange(of: selectedSlot) { _, _ in scrollToSelectedSlot(proxy) }
        }
    }

    private func compactTimeSlotButton(_ slot: Date) -> some View {
        let selected = isSelectedTimeSlot(slot)
        let conflict = hasTimeConflict(
            newStart: slot,
            durationMinutes: selectedDuration,
            excluding: editingActivity
        )

        return Button {
            selectTimeSlot(slot)
        } label: {
            compactTimeSlotContent(
                slot: slot,
                isSelected: selected,
                hasConflict: conflict
            )
        }
        .buttonStyle(.plain)
        .disabled(conflict && !selected)
        .opacity(conflict && !selected ? 0.76 : 1.0)
    }

    private func compactTimeSlotContent(
        slot: Date,
        isSelected: Bool,
        hasConflict: Bool
    ) -> some View {
        VStack(spacing: 3) {
            Text(slotTitle(slot))
                .font(.system(size: 12.8, weight: isSelected ? .semibold : .medium))
                .monospacedDigit()
                .foregroundStyle(timeSlotTextColor(isSelected: isSelected, hasConflict: hasConflict))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Circle()
                .fill(timeSlotDotColor(isSelected: isSelected, hasConflict: hasConflict))
                .frame(width: isSelected ? 4.6 : 3.0, height: isSelected ? 4.6 : 3.0)
                .opacity(isSelected || hasConflict ? 1.0 : 0.32)
        }
        .frame(width: 64, height: 30)
        .background { timeSlotBackground(isSelected: isSelected, hasConflict: hasConflict) }
        .overlay { timeSlotBorder(isSelected: isSelected, hasConflict: hasConflict) }
        .shadow(
            color: isSelected ? selectedType.color.opacity(0.020) : Color.clear,
            radius: 6,
            y: 3
        )
    }

    private func selectTimeSlot(_ slot: Date) {
        lightHaptic.impactOccurred()

        withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
            selectedSlot = slot
        }
    }

    private func isSelectedTimeSlot(_ slot: Date) -> Bool {
        guard let selectedSlot else { return false }
        return calendar.isDate(slot, equalTo: selectedSlot, toGranularity: .minute)
    }

    private func scrollToSelectedSlot(_ proxy: ScrollViewProxy) {
        guard let selectedSlot else { return }

        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                proxy.scrollTo(selectedSlot, anchor: .center)
            }
        }
    }

    private func timeSlotTextColor(isSelected: Bool, hasConflict: Bool) -> Color {
        if isSelected { return .black.opacity(0.82) }
        if hasConflict { return Color(red: 1, green: 0.42, blue: 0.42).opacity(0.42) }
        return textPrimary.opacity(0.86)
    }

    private func timeSlotDotColor(isSelected: Bool, hasConflict: Bool) -> Color {
        if isSelected { return .black.opacity(0.42) }
        if hasConflict { return Color.red.opacity(0.28) }
        return selectedType.color.opacity(0.36)
    }

    private func timeSlotBackground(isSelected: Bool, hasConflict: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                isSelected
                ? selectedType.color.opacity(0.54)
                : hasConflict
                ? Color.red.opacity(0.026)
                : Color.white.opacity(0.026)
            )
    }

    private func timeSlotBorder(isSelected: Bool, hasConflict: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(
                isSelected
                ? Color.white.opacity(0.080)
                : hasConflict
                ? Color.red.opacity(0.065)
                : Color.white.opacity(0.034),
                lineWidth: 1
            )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13.6, weight: .medium))
            .foregroundStyle(textPrimary.opacity(0.84))
    }

    private func typeButton(_ type: PlannerType) -> some View {
        let active = selectedType == type
        let activeFillOpacity: Double = type == .workout ? 0.41 : 0.46

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                selectedType = type

                if type == .meal {
                    let firstMeal = availableMeals.first
                    selectedMealID = firstMeal?.id
                    selectedItem = firstMeal.map { plannerOption(for: $0) } ?? PlannerType.meal.options[0]
                } else {
                    selectedMealID = nil
                    selectedItem = type.options.first!
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(active ? .black.opacity(0.82) : type.color.opacity(0.66))

                Text(type.title)
                    .font(.system(size: 12.3, weight: .semibold))
                    .foregroundStyle(active ? .black.opacity(0.82) : textPrimary.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 39)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(active ? type.color.opacity(activeFillOpacity) : Color.white.opacity(0.026))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(active ? Color.white.opacity(0.070) : Color.white.opacity(0.035), lineWidth: 1)
            }
            .shadow(
                color: active ? type.color.opacity(type == .workout ? 0.014 : 0.022) : Color.black.opacity(0.032),
                radius: active ? 6 : 3,
                y: active ? 3 : 2
            )
        }
        .buttonStyle(.plain)
    }

    private func optionCard(_ option: PlannerOption) -> some View {
        let active = selectedItemMatches(option)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                selectedItem = option
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(option.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: addSheetMealImageWidth, height: addSheetMealImageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.00),
                                    Color.black.opacity(0.16)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                    if active {
                        Circle()
                            .fill(selectedType.color.opacity(0.56))
                            .frame(width: 18, height: 18)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.82))
                            }
                            .shadow(color: selectedType.color.opacity(0.045), radius: 5, y: 2)
                            .padding(5)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(.system(size: 13.2, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(active ? 0.96 : 0.80))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.88)

                    Text(option.subtitle)
                        .font(.system(size: 11.0, weight: .medium))
                        .foregroundStyle(selectedType.color.opacity(active ? 0.60 : 0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(height: 34, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 7)
            .frame(width: addSheetMealCardWidth, height: addSheetMealCardHeight, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(active ? selectedType.color.opacity(0.022) : Color.white.opacity(0.010))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(active ? selectedType.color.opacity(0.095) : Color.white.opacity(0.018), lineWidth: 1)
            }
            .shadow(
                color: active ? selectedType.color.opacity(0.012) : Color.black.opacity(0.018),
                radius: active ? 6 : 3,
                x: 0,
                y: active ? 3 : 2
            )
        }
        .buttonStyle(.plain)
    }

    private func selectedItemMatches(_ option: PlannerOption) -> Bool {
        option.imageName == selectedItem.imageName ||
        option.title == selectedItem.title ||
        shortDisplayTitle(option.title) == shortDisplayTitle(selectedItem.title)
    }

    private func durationButton(_ minutes: Int) -> some View {
        let active = selectedDuration == minutes

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedDuration = minutes
            }
        } label: {
            Text("\(minutes) min")
                .font(.system(size: 12.8, weight: .semibold))
                .foregroundStyle(active ? selectedType.color.opacity(0.72) : textPrimary.opacity(0.58))
                .frame(width: 68, height: 32)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(active ? selectedType.color.opacity(0.046) : Color.white.opacity(0.030))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(active ? selectedType.color.opacity(0.16) : Color.white.opacity(0.030), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var customDurationButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            customDuration = selectedDuration
            showCustomDuration = true
        } label: {
            HStack(spacing: 5) {
                Text("Custom")
                Image(systemName: "slider.horizontal.3")
            }
            .font(.system(size: 12.6, weight: .semibold))
            .foregroundStyle(textPrimary.opacity(0.56))
            .frame(width: 88, height: 32)
            .background(Color.white.opacity(0.034))
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.white.opacity(0.045), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var calendarSheet: some View {
        VStack(spacing: 16) {
            DatePicker("Select day", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .tint(WeekFitTheme.meal)
                .padding()

            Button {
                showCalendar = false
            } label: {
                Text("Done")
                    .font(WeekFitStyle.Font.button)
                    .foregroundStyle(.black.opacity(0.84))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(WeekFitTheme.meal.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: WeekFitTheme.meal.opacity(0.16), radius: 14, y: 7)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(background)
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private func nextAvailableSlot() -> Date {
        let candidate: Date

        if calendar.isDateInToday(selectedDate) {
            candidate = roundedToNext15Minutes(Date())
        } else {
            candidate = calendar.date(
                bySettingHour: timelineStartHour,
                minute: 0,
                second: 0,
                of: selectedDate
            ) ?? selectedDate
        }

        let minSlot = calendar.date(
            bySettingHour: timelineStartHour,
            minute: 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate

        let maxSlot = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: selectedDate)
        ) ?? selectedDate

        return min(max(candidate, minSlot), maxSlot)
    }

    private func itemsForSlot(_ slot: Date) -> [PlannedActivity] {
        plannedActivities
            .filter {
                calendar.isDate($0.date, equalTo: slot, toGranularity: .hour)
                && calendar.isDate($0.date, inSameDayAs: selectedDate)
            }
            .sorted { $0.date < $1.date }
    }

    private func scrollToCurrentHour(_ proxy: ScrollViewProxy) {
        let targetDate: Date

        if calendar.isDateInToday(selectedDate) {
            let now = Date()
            targetDate = calendar.date(byAdding: .minute, value: -45, to: now) ?? now
        } else if let first = selectedDayActivities.first {
            targetDate = calendar.date(byAdding: .minute, value: -45, to: first.date) ?? first.date
        } else {
            targetDate = calendar.date(
                bySettingHour: 8,
                minute: 0,
                second: 0,
                of: selectedDate
            ) ?? selectedDate
        }

        let anchorID = timelineAnchorID(for: targetDate)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeInOut(duration: 0.34)) {
                proxy.scrollTo(anchorID, anchor: .top)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.easeInOut(duration: 0.20)) {
                proxy.scrollTo(anchorID, anchor: .top)
            }
        }
    }

    private var recommendationIcon: String {
        switch selectedType {
        case .meal: return customMeals.isEmpty ? "sparkles" : "fork.knife.circle.fill"
        case .workout: return "bolt.heart.fill"
        case .recovery: return "leaf.fill"
        case .habit: return "checkmark.seal.fill"
        }
    }

    private var recommendationTitle: String {
        switch selectedType {
        case .meal:
            return customMeals.isEmpty ? "Meals ready to add" : "Your meals"
        case .workout:
            return "Training fits here"
        case .recovery:
            return "Recovery fits here"
        case .habit:
            return "Keep it easy"
        }
    }

    private var recommendationSubtitle: String {
        switch selectedType {
        case .meal:
            return customMeals.isEmpty
            ? "Choose from balanced meal options."
            : "Custom meals are used first."
        case .workout:
            return "Hydration and protein may help after."
        case .recovery:
            return "Useful after training or long sitting."
        case .habit:
            return "Short routines are easier to repeat."
        }
    }

    private func startAdding(at slot: Date) {
        loadCustomMeals()

        let normalizedSlot = clampedTimelineDate(
            roundedToNext15Minutes(slot)
        )

        editingActivity = nil
        selectedSlot = normalizedSlot
        selectedType = .meal

        let firstMeal = availableMeals.first
        selectedMealID = firstMeal?.id
        selectedItem = firstMeal.map { plannerOption(for: $0) } ?? PlannerType.meal.options[0]

        selectedDuration = 30

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.46, dampingFraction: 0.84, blendDuration: 0.08)) {
            showAddActivity = true
        }
    }
    
    private func customMealPreview(_ meal: Meals) -> some View {
        ZStack {
            Image("plate-dark")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            if let items = meal.builderImageItems {
                ForEach(items.sorted(by: { $0.zIndex < $1.zIndex })) { item in
                    Image(item.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: CGFloat(item.visualSize) * 0.34)
                        .offset(
                            x: CGFloat(item.offsetX) * 0.265,
                            y: CGFloat(item.offsetY) * 0.265
                        )
                        .rotationEffect(.degrees(Double(item.rotation)))
                        .zIndex(Double(item.zIndex))
                }
            }
        }
    }
    
    private func mealOptionCard(_ meal: Meals) -> some View {
        let active = selectedMealID == meal.id

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                selectedMealID = meal.id
                selectedItem = plannerOption(for: meal)
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    customMealPreview(meal)
                        .frame(width: addSheetMealImageWidth, height: addSheetMealImageHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .opacity(active ? 1.0 : 0.90)

                    if active {
                        Circle()
                            .fill(selectedType.color.opacity(0.56))
                            .frame(width: 18, height: 18)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.black.opacity(0.82))
                            }
                            .shadow(color: selectedType.color.opacity(0.045), radius: 5, y: 2)
                            .padding(5)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(meal.title)
                        .font(.system(size: 13.2, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(active ? 0.96 : 0.88))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.88)

                    Text("\(meal.calories) kcal • P \(meal.protein)g")
                        .font(.system(size: 11.0, weight: .medium))
                        .foregroundStyle(selectedType.color.opacity(active ? 0.60 : 0.50))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .frame(height: 34, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 7)
            .frame(width: addSheetMealCardWidth, height: addSheetMealCardHeight, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(active ? selectedType.color.opacity(0.022) : Color.white.opacity(0.014))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(active ? selectedType.color.opacity(0.095) : Color.white.opacity(0.026), lineWidth: 1)
            }
            .shadow(
                color: active ? selectedType.color.opacity(0.012) : Color.black.opacity(0.014),
                radius: active ? 6 : 3,
                x: 0,
                y: active ? 3 : 2
            )
        }
        .buttonStyle(.plain)
    }

    private func startEditing(_ activity: PlannedActivity) {
        loadCustomMeals()

        editingActivity = activity
        selectedSlot = activity.date
        selectedDuration = activity.durationMinutes

        let type = plannerType(from: activity.type)
        selectedType = type

        if type == .meal {

            let matchedMeal =
                availableMeals.first(where: { $0.id == activity.id }) ??
                availableMeals.first(where: { $0.title == activity.title }) ??
                availableMeals.first(where: {
                    shortDisplayTitle($0.title) == shortDisplayTitle(activity.title)
                })

            selectedMealID = matchedMeal?.id

            if let matchedMeal {
                selectedItem = plannerOption(for: matchedMeal)
            } else {
                let fallback = availableMeals.first
                selectedMealID = fallback?.id
                selectedItem = fallback.map { plannerOption(for: $0) } ?? PlannerType.meal.options[0]
            }

        } else {

            selectedMealID = nil

            selectedItem =
                type.options.first(where: { $0.title == activity.title }) ??
                type.options.first ??
                type.options[0]
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.46, dampingFraction: 0.84, blendDuration: 0.08)) {
            showAddActivity = true
        }
    }

    private func closeAddSheet() {
        withAnimation(.spring(response: 0.40, dampingFraction: 0.88, blendDuration: 0.06)) {
            showAddActivity = false
            editingActivity = nil
            isEditingActivity = false
        }

        selectedSlot = nil
        resetDragState()
    }

    private func saveSelectedItem() {
        guard let selectedSlot else { return }

        if hasTimeConflict(
            newStart: selectedSlot,
            durationMinutes: selectedDuration,
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
            editingActivity.type = selectedType.title
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
                scheduleNotificationsIfNeeded(for: editingActivity)
            } catch {
                print("Failed to update planned activity:", error)
            }
        } else {
            let activity = PlannedActivity(
                date: selectedSlot,
                type: selectedType.title,
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
                scheduleNotificationsIfNeeded(for: activity)
            } catch {
                print("Failed to save planned activity:", error)
            }
        }

        closeAddSheet()
    }

    private func deleteActivity(_ activity: PlannedActivity) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        cancelNotifications(for: activity)
        modelContext.delete(activity)

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete activity:", error)
        }
    }

    private func cancelNotifications(for activity: PlannedActivity) {
        ActivityNotificationService.shared.cancelNotifications(for: activity)
    }

    private func scheduleNotificationsIfNeeded(for activity: PlannedActivity) {
        ActivityNotificationService.shared.syncNotifications(
            for: activity,
            activityRemindersEnabled: activityRemindersEnabled,
            completionCheckInsEnabled: completionCheckInsEnabled
        )
    }

    private func hasSameStartTimeConflict(
        newStart: Date,
        excluding activity: PlannedActivity? = nil
    ) -> Bool {
        hasTimeConflict(
            newStart: newStart,
            durationMinutes: selectedDuration,
            excluding: activity
        )
    }

    private func activitiesOverlap(
        _ aStart: Date,
        _ aDuration: Int,
        _ bStart: Date,
        _ bDuration: Int
    ) -> Bool {
        let aEnd = calendar.date(
            byAdding: .minute,
            value: max(aDuration, timelineMinuteStep),
            to: aStart
        ) ?? aStart

        let bEnd = calendar.date(
            byAdding: .minute,
            value: max(bDuration, timelineMinuteStep),
            to: bStart
        ) ?? bStart

        return aStart < bEnd && aEnd > bStart
    }

    private func hasTimeConflict(
        newStart: Date,
        durationMinutes: Int,
        excluding activity: PlannedActivity? = nil
    ) -> Bool {
        plannedActivities.contains { existing in
            if let activity, existing === activity {
                return false
            }

            guard calendar.isDate(existing.date, inSameDayAs: newStart) else {
                return false
            }

            guard !existing.isSkipped else {
                return false
            }

            return activitiesOverlap(
                newStart,
                durationMinutes,
                existing.date,
                existing.durationMinutes
            )
        }
    }

    private func plannerType(from title: String) -> PlannerType {
        PlannerType.allCases.first { $0.title == title } ?? .meal
    }

    private func slotTitle(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private func shortDisplayTitle(_ title: String) -> String {
        title.components(separatedBy: ",").first ?? title
    }

    private func optionScrollID(_ option: PlannerOption) -> String {
        "\(option.title)-\(option.imageName)"
    }
    
//    old one
//    private func selectedOptionScrollID() -> String {
//        "\(selectedItem.title)-\(selectedItem.imageName)"
//    }
    
    private func selectedOptionScrollID() -> String {
        if selectedType == .meal {
            return selectedMealID ?? availableMeals.first?.id ?? ""
        }

        return "\(selectedItem.title)-\(selectedItem.imageName)"
    }

    private func scrollToSelectedOption(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                proxy.scrollTo(selectedOptionScrollID(), anchor: .center)
            }
        }
    }

    private func syncDefaultSelectedMeal() {
        guard selectedType == .meal else { return }

        if selectedMealForPlanner == nil {
            let firstMeal = availableMeals.first
            selectedMealID = firstMeal?.id
            selectedItem = firstMeal.map { plannerOption(for: $0) } ?? PlannerType.meal.options[0]
        }
    }

    private func dragGesture(for activity: PlannedActivity) -> some Gesture {
        LongPressGesture(minimumDuration: 0.42)
            .sequenced(before: DragGesture(minimumDistance: 3, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .first(true):
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                case .second(true, let drag):
                    guard let drag else { return }

                    guard abs(drag.translation.height) > abs(drag.translation.width) else {
                        return
                    }

                    if draggedActivityID == nil {
                        draggedActivityID = activity.id
                        dragPreviewDate = activity.date
                        focusedDragSlot = activity.date
                        invalidDropSlot = nil
                        dragTranslationY = 0

                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }

                    dragTranslationY = drag.translation.height
                    
                    let candidate = dragCandidateDate(
                        from: activity.date,
                        translationY: drag.translation.height,
                        activity: activity
                    )
                    
                    if dragPreviewDate != candidate {
                        dragPreviewDate = candidate
                        focusedDragSlot = candidate

                        let hasConflict = hasTimeConflict(
                            newStart: candidate,
                            durationMinutes: activity.durationMinutes,
                            excluding: activity
                        )

                        invalidDropSlot = hasConflict ? candidate : nil

                        UISelectionFeedbackGenerator().selectionChanged()
                    }

                default:
                    break
                }
            }
            .onEnded { value in
                guard case .second(true, _) = value else {
                    resetDragState()
                    return
                }

                let targetDate = dragPreviewDate

                draggedActivityID = nil
                dragPreviewDate = nil
                dragTranslationY = 0
                focusedDragSlot = nil
                invalidDropSlot = nil

                if let targetDate {
                    moveActivity(activity, to: targetDate)
                }
            }
    }

    private func dragCandidateDate(
        from date: Date,
        translationY: CGFloat,
        activity: PlannedActivity
    ) -> Date {
        let startY = yPosition(for: date)
        let proposedStartY = startY + translationY
        let proposedStart = dateForTimelinePosition(proposedStartY)

        return clampedTimelineDate(proposedStart)
    }

    private func clampedTimelineDate(
        _ date: Date
    ) -> Date {
        dateForTimelinePosition(yPosition(for: date))
    }

    private func moveActivity(
        _ activity: PlannedActivity,
        to newDate: Date
    ) {

        guard !calendar.isDate(
            activity.date,
            equalTo: newDate,
            toGranularity: .minute
        ) else {
            return
        }

        if hasTimeConflict(
            newStart: newDate,
            durationMinutes: activity.durationMinutes,
            excluding: activity
        ) {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

            invalidDropSlot = newDate
            timeConflictMessage = "This time overlaps with another activity. Choose another 15-minute slot."
            showTimeConflictAlert = true
            return
        }

        UIImpactFeedbackGenerator(
            style: .medium
        ).impactOccurred()

        cancelNotifications(for: activity)

        activity.date = newDate

        do {
            try modelContext.save()

            scheduleNotificationsIfNeeded(for: activity)

        } catch {
            print(
                "Failed to move planned activity:",
                error
            )
        }
    }

    private func resetDragState() {
        draggedActivityID = nil
        dragPreviewDate = nil
        dragTranslationY = 0
        focusedDragSlot = nil
        invalidDropSlot = nil
    }
}

private struct TimelineDashMask: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let dashWidth: CGFloat = 5
                let gapWidth: CGFloat = 5
                var x: CGFloat = 0

                while x < geometry.size.width {
                    path.move(to: CGPoint(x: x, y: 0.5))
                    path.addLine(to: CGPoint(x: min(x + dashWidth, geometry.size.width), y: 0.5))
                    x += dashWidth + gapWidth
                }
            }
            .stroke(Color.white, lineWidth: 1)
        }
    }
}

extension PlannerType {

    var colorComponents: (red: Double, green: Double, blue: Double) {
        switch self {
        case .meal:
            return WeekFitTheme.mealRGB
        case .workout:
            return WeekFitTheme.workoutRGB
        case .recovery:
            return WeekFitTheme.recoveryRGB
        case .habit:
            return WeekFitTheme.habitRGB
        }
    }
}
