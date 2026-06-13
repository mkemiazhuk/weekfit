import SwiftUI
import SwiftData
import HealthKit
import UIKit

struct WeekPlannerView: View {

    @ObservedObject var viewModel: PlanViewModel
    
    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]
    
    @ObservedObject var authViewModel: AuthViewModel
    
    @EnvironmentObject private var activityCoordinator: WeekFitActivityCoordinator

    @StateObject private var userSettings = WeekFitUserSettings.shared

    @State private var mode: PlanMode = .week
    @State private var showProfile = false
    
    @Environment(\.modelContext) private var modelContext

    @State private var activityPendingDelete: PlannedActivity?
    @State private var showDeleteConfirmation = false

    private let calendar = Calendar.current
    
    @AppStorage(NotificationPreferenceKey.activityReminders)
    private var activityRemindersEnabled = false

    @AppStorage(NotificationPreferenceKey.completionCheckIns)
    private var completionCheckInsEnabled = false

    @AppStorage(CustomMealStore.storageKey)
    private var customMealsStorage = ""
    
    @State private var activityToConfirm: PlannedActivity?
    

    var body: some View {
        GeometryReader { proxy in
            let screenWidth = UIScreen.main.bounds.width
            
            ZStack {
                WeekFitTheme.appBackground
                    .ignoresSafeArea()

                ambientBackground

                WeekFitScreenContainer {
                    WeekFitScreenHeader(
                        title: "Plan",
                        subtitle: "Weekly activities",
                        initials: userSettings.profileInitials,
                        showAvatar: true
                    ) {
                        showProfile = true
                    }
                } content: {
                    plannerContent
                        .blur(radius: viewModel.showAddActivity ? 4 : 0)
                        .scaleEffect(viewModel.showAddActivity ? 0.985 : 1.0)
                }
                .padding(.bottom, 96)
                .frame(width: screenWidth, height: proxy.size.height, alignment: .top)
                .clipped()

                if viewModel.showAddActivity {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.closeAddSheet()
                        }

                    VStack {
                        Spacer()

                        PlanAddActivitySheet(
                            viewModel: viewModel,
                            plannedActivities: plannedActivities,
                            modelContext: modelContext,
                            activityRemindersEnabled: activityRemindersEnabled,
                            completionCheckInsEnabled: completionCheckInsEnabled
                        )
                        .padding(.bottom, 92)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea(edges: .bottom)
                    .zIndex(10)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .preferredColorScheme(.dark)
        .animation(
            .spring(response: 0.42, dampingFraction: 0.90, blendDuration: 0.08),
            value: viewModel.showAddActivity
        )
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
        }
        .alert(
            "Delete logged activity?",
            isPresented: $showDeleteConfirmation,
            presenting: activityPendingDelete
        ) { activity in

            Button("Delete", role: .destructive) {
                deleteActivity(activity)
            }

            Button("Cancel", role: .cancel) {
                activityPendingDelete = nil
            }

        } message: { activity in
            Text("This will remove \(activity.title) from your plan.")
        }
        .onReceive(activityCoordinator.$completedWorkoutsBatch) { workouts in
            guard !workouts.isEmpty else { return }

            for workout in workouts {
//                аprint("🧷 Planner received completed workout:", workout.uuid)
                reconcileCompletedAppleWorkout(workout)
            }
        }
        .sheet(item: $activityToConfirm) { activity in
            plannerConfirmationSheet(activity)
                .presentationDetents([.fraction(0.32)])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func plannerConfirmationSheet(_ activity: PlannedActivity) -> some View {
        let accent = activityAccent(for: activity)

        return VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("Confirm activity")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text("Did you complete \(activity.title), or should we mark it as skipped?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .lineSpacing(3)
            }
            .padding(.top, 16)

            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                    withAnimation {
                        activity.isSkipped = true
                        activity.isCompleted = false

                        if activity.source.isEmpty {
                            activity.source = "planner"
                        }

                        try? modelContext.save()
                        activityToConfirm = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Skipped")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.64))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.07))
                    )
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                    withAnimation {
                        activity.isCompleted = true
                        activity.isSkipped = false

                        if activity.source.isEmpty {
                            activity.source = "planner"
                        }

                        try? modelContext.save()
                        activityToConfirm = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Done")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black.opacity(0.84))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(accent)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WeekFitTheme.backgroundColor.ignoresSafeArea())
    }
    
    private var plannerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mode == .week {
                weekOverviewCard

                selectedDayCard
                    .frame(maxHeight: .infinity)
            } else {
                monthPlaceholderCard
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    func deleteActivity(_ activity: PlannedActivity) {
        modelContext.delete(activity)

        do {
            try modelContext.save()
        } catch {
            print("❌ Failed to delete planned activity:", error)
        }

        activityPendingDelete = nil
    }
}

// MARK: - Mode

private enum PlanMode {
    case week
    case month
}

// MARK: - Segmented Control

private extension WeekPlannerView {

    var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton("Week", .week)
            segmentButton("Month", .month)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.043))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                }
        )
    }

    func segmentButton(_ title: String, _ value: PlanMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                mode = value
            }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(mode == value ? .white : .white.opacity(0.54))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background {
                    if mode == value {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.072))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Week Overview

private extension WeekPlannerView {

    var weekOverviewCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("WEEK OVERVIEW")
                        .font(.system(size: 11.5, weight: .bold))
                        .tracking(0.35)
                        .foregroundStyle(.white.opacity(0.42))

                    Text(weekRangeTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                }

                Spacer(minLength: 0)
            }

            PlanningWeekPicker(
                selectedDate: $viewModel.selectedDate,
                dayKind: dayKind(for:)
            )

            legend
        }
        .padding(.horizontal, 17)
        .padding(.top, 14)
        .padding(.bottom, 15)
        .background(cardBackground)
    }

    var legend: some View {
        HStack(spacing: 11) {
            legendItem("Endurance", Color(hex: "#5E7CFF"))
            legendItem("High load", Color(hex: "#FF9F43"))
            legendItem("Mixed", Color(hex: "#FFD166"))
            legendItem("Recovery", Color(hex: "#59D98E"))
        }
    }

    func legendItem(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
    }
}

// MARK: - Selected Day

private extension WeekPlannerView {

    var selectedDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedDateHeader.uppercased())
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(0.35)
                        .foregroundStyle(dayKind(for: viewModel.selectedDate).color)

                    Text(selectedDayTitle)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(selectedDaySubtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)
                }

                Spacer()

                if !selectedDayActivities.isEmpty {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.startAdding(
                            at: viewModel.nextAvailableSlot(from: plannedActivities)
                        )
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color(hex:"#7E8CFF").opacity(0.78))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if selectedDayActivities.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    emptySelectedDay
                        .padding(.top, 18)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(timelineItems) { item in
                                let activity = item.representative
                                let status = resolvedActivityStatus(for: activity)

                                ZStack(alignment: .leading) {
                                    Circle()
                                        .fill(
                                            activityAccent(for: activity)
                                                .opacity(status == .upcoming ? 0.62 : 0.88)
                                        )
                                        .frame(
                                            width: status == .upcoming ? 4.5 : 6,
                                            height: status == .upcoming ? 4.5 : 6
                                        )
                                        .offset(x: status == .upcoming ? 0.75 : 0)

                                    DynamicPlanRow(
                                        activity: activity,
                                        displayTitle: timelineTitle(for: item),
                                        accent: activityAccent(for: activity),
                                        time: timelineTime(for: item),
                                        subtitle: timelineSubtitle(for: item),
                                        status: status,
                                        mealImageName: mealImageName(for: activity),
                                        mealBuilderImageItems: mealBuilderImageItems(for: activity),
                                        mealPlaceholderInitial: mealPlaceholderInitial(for: activity)
                                    )
                                    .padding(.leading, 28)
                                }
                                .id(item.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                                    switch item {
                                    case .waterGroup(let activities):
                                        if let first = activities.first {
                                            activityPendingDelete = first
                                            showDeleteConfirmation = true
                                        }

                                    case .single(let activity):
                                        switch status {
                                        case .pending:
                                            activityToConfirm = activity

                                        case .completed, .logged:
                                            activityPendingDelete = activity
                                            showDeleteConfirmation = true

                                        default:
                                            viewModel.startEditing(activity)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .onAppear {
                        scrollToRelevantActivity(proxy)
                    }
                    .onChange(of: viewModel.selectedDate) { _, _ in
                        scrollToRelevantActivity(proxy)
                    }
                    .onChange(of: selectedDayActivities.count) { _, _ in
                        scrollToRelevantActivity(proxy)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(alignment: .leading) {
                    timelineOverlay
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .contentMargins(.top, 8, for: .scrollContent)
                .contentMargins(.bottom, 24, for: .scrollContent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, 17)
        .padding(.horizontal, 17)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(cardBackground)
    }
    
    func resolvedActivityStatus(for item: PlannedActivity) -> PlanActivityStatus {
        activityCoordinator.resolvedStatus(
            for: item,
            baseStatus: activityStatus(for: item)
        )
    }
    
    private var timelineOverlay: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        height: completedTimelineHeight(in: geo.size.height)
                    )

                Rectangle()
                    .fill(.white.opacity(0.045))
            }
            .frame(width: 2.1)
            .offset(x: 2)
        }
        .allowsHitTesting(false)
    }
    
    func completedTimelineHeight(in totalHeight: CGFloat) -> CGFloat {

        guard !selectedDayActivities.isEmpty else {
            return 0
        }

        let completed = selectedDayActivities.filter {
            let status = resolvedActivityStatus(for: $0)

            return status == .completed || status == .logged
        }.count

        let progress = CGFloat(completed) / CGFloat(selectedDayActivities.count)

        return max(24, totalHeight * progress)
    }
    
    private var emptySelectedDay: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            let slot = viewModel.nextAvailableSlot(
                from: selectedDayActivities
            )

            viewModel.startAdding(at: slot)
        } label: {

            HStack(spacing: 11) {

                ZStack {
                    Circle()
                        .fill(Color(hex: "#7E8CFF").opacity(0.14))
                        .frame(width: 42, height: 42)

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(hex: "#7E8CFF"))
                }

                VStack(alignment: .leading, spacing: 3) {

                    Text("Build your day")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Add training, meals, recovery, hydration, or sleep structure.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.20))
                    .padding(.leading, -2)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Month Placeholder

private extension WeekPlannerView {
    
    func scrollToRelevantActivity(_ proxy: ScrollViewProxy) {
//        if let live = selectedDayActivities.first(where: {
//            activityStatus(for: $0) == .live
//        }) {
        if let live = selectedDayActivities.first(where: {
            resolvedActivityStatus(for: $0) == .live
        }) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                proxy.scrollTo(live.id, anchor: .center)
            }
            return
        }

        let now = Date()

        if let upcoming = selectedDayActivities.first(where: {
            $0.date > now
        }) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                proxy.scrollTo(upcoming.id, anchor: .center)
            }
            return
        }

        if let lastCompleted = selectedDayActivities.last(where: {
            $0.isCompleted
        }) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                proxy.scrollTo(lastCompleted.id, anchor: .center)
            }
        }
    }

    var monthPlaceholderCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("MONTH VIEW")
                .font(.system(size: 11.5, weight: .bold))
                .tracking(0.35)
                .foregroundStyle(.white.opacity(0.42))

            Text("Monthly planning is coming next.")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("For now, your weekly structure is the source of truth for planning.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    mode = .week
                }
            } label: {
                Text("Back to week")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .frame(height: 38)
                    .background(
                        Capsule()
                            .fill(Color(hex: "#6E83FF"))
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(17)
        .background(cardBackground)
    }
}

// MARK: - Footer / FAB

private extension WeekPlannerView {

    var adaptiveFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))

            Text("Plan your week. Use Coach for real-time guidance.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }

    var floatingAddButton: some View {
        Button {
            viewModel.showCalendar = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#6E83FF"),
                                    Color(hex: "#5970FF")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(
                    color: Color(hex: "#6E83FF").opacity(0.30),
                    radius: 16,
                    y: 8
                )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 22)
        .padding(.bottom, 34)
    }
}

// MARK: - Dynamic Data

private extension WeekPlannerView {

    var selectedDayActivities: [PlannedActivity] {
        plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: viewModel.selectedDate) }
            .sorted { $0.date < $1.date }
    }
    
    private var timelineItems: [PlanTimelineItem] {
        let sorted = selectedDayActivities.sorted { $0.date < $1.date }

        var result: [PlanTimelineItem] = []
        var waterBuffer: [PlannedActivity] = []

        func flushWater() {
            guard !waterBuffer.isEmpty else { return }

            if waterBuffer.count == 1 {
                result.append(.single(waterBuffer[0]))
            } else {
                result.append(.waterGroup(waterBuffer))
            }

            waterBuffer.removeAll()
        }

        for activity in sorted {
            if isWater(activity) {
                waterBuffer.append(activity)
            } else {
                flushWater()
                result.append(.single(activity))
            }
        }

        flushWater()

        return result
    }
    
    private func isWater(_ activity: PlannedActivity) -> Bool {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()

        return title.contains("water")
            || title.contains("hydration")
            || type.contains("water")
            || type.contains("hydration")
    }

    private var customMeals: [Meals] {
        CustomMealStore.load(from: customMealsStorage)
    }

    private func matchingCustomMeal(for activity: PlannedActivity) -> Meals? {
        guard activity.type.lowercased() == "meal" else { return nil }

        let normalizedTitle = CustomMealStore.normalizedTitle(activity.title)
        guard !normalizedTitle.isEmpty else { return nil }

        return customMeals.first {
            CustomMealStore.normalizedTitle($0.title) == normalizedTitle
        }
    }

    private func mealImageName(for activity: PlannedActivity) -> String? {
        let storedImageName = activity.imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !storedImageName.isEmpty {
            return storedImageName
        }

        guard let meal = matchingCustomMeal(for: activity) else { return nil }

        if let photoFilename = meal.displayPhotoFilename?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !photoFilename.isEmpty {
            return photoFilename
        }

        let assetName = meal.imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        return assetName.isEmpty ? nil : assetName
    }

    private func mealBuilderImageItems(for activity: PlannedActivity) -> [MealBuilderImageItem] {
        matchingCustomMeal(for: activity)?
            .builderImageItems?
            .sorted { $0.zIndex < $1.zIndex } ?? []
    }

    private func mealPlaceholderInitial(for activity: PlannedActivity) -> String {
        matchingCustomMeal(for: activity)?.placeholderInitial
            ?? activityPlaceholderInitial(for: activity.title)
    }

    private func activityPlaceholderInitial(for title: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmedTitle.first else { return "" }
        return String(first).uppercased()
    }

    private func mergedWaterTitle(_ first: String, _ second: String) -> String {
        let firstAmount = waterAmount(from: first)
        let secondAmount = waterAmount(from: second)

        let total = firstAmount + secondAmount

        if total > 0 {
            return "Water Log (\(String(format: "%.2g", total))L)"
        }

        return "Water Log"
    }

    private func waterAmount(from title: String) -> Double {
        let pattern = #"(\d+(?:\.\d+)?)L"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: title,
                  range: NSRange(title.startIndex..., in: title)
              ),
              let range = Range(match.range(at: 1), in: title)
        else {
            return 0
        }

        return Double(title[range]) ?? 0
    }

    var weekRangeTitle: String {
        guard let first = viewModel.weekDays.first,
              let last = viewModel.weekDays.last else {
            return viewModel.selectedDate.formatted(.dateTime.month(.abbreviated).day())
        }

        let firstMonth = first.formatted(.dateTime.month(.abbreviated))
        let lastMonth = last.formatted(.dateTime.month(.abbreviated))

        let firstDay = first.formatted(.dateTime.day())
        let lastDay = last.formatted(.dateTime.day())

        if firstMonth == lastMonth {
            return "\(firstMonth) \(firstDay) – \(lastDay)"
        }

        return "\(firstMonth) \(firstDay) – \(lastMonth) \(lastDay)"
    }

    var selectedDateHeader: String {
        viewModel.selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    var selectedDayTitle: String {
        switch dayKind(for: viewModel.selectedDate) {
        case .endurance:
            return "Endurance Day"
        case .load:
            return "High Load Day"
        case .mixed:
            return "Mixed Day"
        case .recovery:
            return "Recovery Day"
        case .open:
            return "Open Day"
        }
    }
    
    func formattedDuration(_ minutes: Int) -> String {

        if minutes >= 60 {

            let hours = minutes / 60
            let remainingMinutes = minutes % 60

            if remainingMinutes == 0 {
                return "\(hours)h"
            }

            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(minutes) min"
    }

    var selectedDaySubtitle: String {
        let count = selectedDayActivities.count

        if count == 0 {
            return "Shape this day with intention."
        }

        let workouts = selectedDayActivities.filter { $0.type.lowercased() == "workout" }.count
        let meals = selectedDayActivities.filter { $0.type.lowercased() == "meal" }.count
        let recovery = selectedDayActivities.filter { $0.type.lowercased() == "recovery" }.count
        let habits = selectedDayActivities.filter { $0.type.lowercased() == "habit" }.count

        var parts: [String] = []

        if workouts > 0 { parts.append("\(workouts) workout\(workouts == 1 ? "" : "s")") }
        if meals > 0 { parts.append("\(meals) meal\(meals == 1 ? "" : "s")") }
        if recovery > 0 {
            parts.append(
                "\(recovery) recovery \(recovery == 1 ? "activity" : "activities")"
            )
        }
        if habits > 0 { parts.append("\(habits) habit\(habits == 1 ? "" : "s")") }

        if parts.isEmpty {
            return "\(count) planned item\(count == 1 ? "" : "s")."
        }

        return parts.joined(separator: " • ") + "."
    }

    func dayActivities(for date: Date) -> [PlannedActivity] {
        plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func dayKind(for date: Date) -> PlanDayKind {
        let items = dayActivities(for: date)

        guard !items.isEmpty else {
            return .open
        }

        let workouts = items.filter { $0.type.lowercased() == "workout" }
        let recovery = items.filter { $0.type.lowercased() == "recovery" }
        let meals = items.filter { $0.type.lowercased() == "meal" }
        let habits = items.filter { $0.type.lowercased() == "habit" }

        let workoutMinutes = workouts.reduce(0) { $0 + max($1.durationMinutes, 0) }
        let recoveryMinutes = recovery.reduce(0) { $0 + max($1.durationMinutes, 0) }

        let hasLongWorkout = workouts.contains { $0.durationMinutes >= 50 }

        if workouts.isEmpty && !recovery.isEmpty {
            return .recovery
        }

        if hasLongWorkout || workoutMinutes >= 60 {
            return .endurance
        }

        if workouts.count >= 2 || workoutMinutes >= 45 {
            return .load
        }

        if !workouts.isEmpty && (!recovery.isEmpty || !meals.isEmpty || !habits.isEmpty) {
            return .mixed
        }

        if workouts.isEmpty && recoveryMinutes >= 20 {
            return .recovery
        }

        let lightWorkoutTitles = ["walk", "walking", "yoga", "stretch", "stretching", "mobility"]

        let hasOnlyLightWorkouts = !workouts.isEmpty && workouts.allSatisfy { activity in
            let title = activity.title.lowercased()
            return lightWorkoutTitles.contains { title.contains($0) }
        }

        if hasOnlyLightWorkouts {
            return .recovery
        }

        if !workouts.isEmpty {
            return .load
        }

        return .recovery
    }

    func activityAccent(for item: PlannedActivity) -> Color {
        let type = item.type.lowercased()
        let title = item.title.lowercased()

        if type.contains("water")
            || title.contains("water")
            || title.contains("hydration")
            || title.contains("drink") {
            return Color(red: 0.18, green: 0.52, blue: 0.88)
        }

        switch type {
        case "workout":
            return Color(red: 0.46, green: 0.72, blue: 0.82)
        case "recovery":
            return Color(red: 0.66, green: 0.58, blue: 0.86)
        case "meal":
            return Color(red: 0.50, green: 0.74, blue: 0.54)
        case "habit":
            return Color(red: 0.82, green: 0.60, blue: 0.36)
        default:
            return item.color
        }
    }

    func activitySubtitle(_ item: PlannedActivity) -> String {

        let duration = formattedDuration(item.durationMinutes)

        switch item.type.lowercased() {

        case "meal":
            if item.calories > 0 {
                return "Meal • \(item.calories) kcal"
            }

            return "Fueling window"

        case "workout":
            if item.durationMinutes > 0 {
                return "Training • \(duration)"
            }

            return "Training"

        case "recovery":
            if item.durationMinutes > 0 {
                return "Recovery • \(duration)"
            }

            return "Recovery"

        case "habit":
            if item.durationMinutes > 0 {
                return "Routine • \(duration)"
            }

            return "Routine"

        default:
            if item.durationMinutes > 0 {
                return "\(item.type) • \(duration)"
            }

            return item.type
        }
    }
    
    func reconcileCompletedAppleWorkout(_ workout: HKWorkout) {
        WeekFitActivityCoordinator.shared.reconcileCompletedAppleWorkout(
            workout,
            with: plannedActivities,
            modelContext: modelContext
        )
        do {
            try modelContext.save()
        } catch {
            // Reconciliation is opportunistic; the next HealthKit refresh can retry.
        }
    }
    
    func title(for type: HKWorkoutActivityType) -> String {
        ActivityReconciler.title(for: type)
    }
    
    func icon(for type: HKWorkoutActivityType) -> String {
        ActivityReconciler.icon(for: type)
    }

    func bestPlannedActivityMatch(for workout: HKWorkout) -> PlannedActivity? {
        ActivityReconciler.bestMatch(for: workout, in: plannedActivities, calendar: calendar)
    }
    
    func isWorkoutCloseEnoughToPlannedActivity(
        workoutStart: Date,
        workoutEnd: Date,
        activity: PlannedActivity
    ) -> Bool {
        let plannedStart = activity.date
        guard plannedStart <= workoutEnd else { return false }

        return workoutEnd.timeIntervalSince(plannedStart) <= ActivityReconciler.pastMatchingWindow
    }
    
    func plannedDistanceScore(
        activity: PlannedActivity,
        workoutStart: Date,
        workoutEnd: Date
    ) -> TimeInterval {
        let plannedStart = activity.date
        let plannedEnd = calendar.date(
            byAdding: .minute,
            value: max(activity.durationMinutes, 1),
            to: plannedStart
        ) ?? plannedStart

        if workoutStart < plannedEnd && workoutEnd > plannedStart {
            return 0
        }

        let startDistance = abs(plannedStart.timeIntervalSince(workoutStart))
        let endDistance = abs(plannedEnd.timeIntervalSince(workoutEnd))

        return min(startDistance, endDistance)
    }
    
    func normalizedWorkoutKeywords(for type: HKWorkoutActivityType) -> [String] {
        switch type {
        case .walking:
            return ["walk", "walking"]

        case .running:
            return ["run", "running"]

        case .cycling:
            return ["cycle", "cycling", "bike", "ride"]

        case .hiking:
            return ["hike", "hiking"]

        case .yoga:
            return ["yoga"]

        case .traditionalStrengthTraining,
             .functionalStrengthTraining:
            return [
                "strength",
                "upper body",
                "lower body",
                "full body",
                "push",
                "pull",
                "gym",
                "dumbbell",
                "weights"
            ]

        case .flexibility:
            return [
                "stretch",
                "stretching",
                "mobility",
                "flexibility"
            ]

        case .highIntensityIntervalTraining:
            return ["hiit", "interval"]

        case .pilates:
            return ["pilates"]

        case .mindAndBody:
            return ["mind", "body", "meditation", "breathing"]

        case .cooldown:
            return ["cooldown", "cool down", "recovery"]

        default:
            return []
        }
    }

    func matches(
        activity: PlannedActivity,
        workoutType: HKWorkoutActivityType
    ) -> Bool {
        ActivityReconciler.matches(activity: activity, workoutType: workoutType)
    }

    func activityStatus(for item: PlannedActivity) -> PlanActivityStatus {
        
//        print("STATUS DEBUG:", item.title, "completed:", item.isCompleted, "source:", item.source)
        
        let now = Date()

        let endDate = calendar.date(
            byAdding: .minute,
            value: max(item.durationMinutes, 1),
            to: item.date
        ) ?? item.date

        if item.isSkipped {
            return .skipped
        }

//        if item.isCompleted {
//            print("STATUS DEBUG:", item.title, "source:", item.source)
//
//            return item.source == "today"
//                ? .logged
//                : .completed
//        }
        
        if item.isCompleted {
            let loggedSources = ["today", "appleWorkout", "healthKit", "appleWatch"]

            return loggedSources.contains(item.source)
                ? .logged
                : .completed
        }

        if item.date > now {
            return .upcoming
        }

        if item.date <= now && now <= endDate {
            return .live
        }

        return .pending
    }

    func timeTitle(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

// MARK: - Components

private struct PlanningWeekPicker: View {
    @Binding var selectedDate: Date

    let dayKind: (Date) -> PlanDayKind

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var weekDays: [Date] {
        let selectedDay = calendar.startOfDay(for: selectedDate)

        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: selectedDay)?.start else {
            return [selectedDay]
        }

        let start = calendar.startOfDay(for: weekStart)

        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).map {
                calendar.startOfDay(for: $0)
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            weekNavigationButton(systemName: "chevron.left") {
                moveWeek(by: -1)
            }

            HStack(spacing: 6) {
                ForEach(weekDays, id: \.self) { date in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()

                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            selectedDate = date
                        }
                    } label: {
                        DynamicDayCapsule(
                            date: date,
                            kind: dayKind(date),
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        guard abs(value.translation.width) > 34 else { return }
                        moveWeek(by: value.translation.width < 0 ? 1 : -1)
                    }
            )

            weekNavigationButton(systemName: "chevron.right") {
                moveWeek(by: 1)
            }
        }
    }

    private func weekNavigationButton(
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.64))
                .frame(width: 26, height: 46)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.032))
                }
        }
        .buttonStyle(.plain)
    }

    private func moveWeek(by weekDelta: Int) {
        let currentWeekdayIndex = weekDays.firstIndex {
            calendar.isDate($0, inSameDayAs: selectedDate)
        } ?? 0

        guard let currentWeekStart = weekDays.first,
              let nextWeekStart = calendar.date(byAdding: .day, value: weekDelta * 7, to: currentWeekStart),
              let nextSelectedDate = calendar.date(byAdding: .day, value: currentWeekdayIndex, to: nextWeekStart)
        else {
            return
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            selectedDate = calendar.startOfDay(for: nextSelectedDate)
        }
    }

}

private struct DynamicDayCapsule: View {

    let date: Date
    let kind: PlanDayKind
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 5) {
            VStack(spacing: 2) {
                HStack(spacing: 3) {
                    Text(dayLabel)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    if isToday {
                        Circle()
                            .fill(kind.color)
                            .frame(width: 3.5, height: 3.5)
                    }
                }
                .foregroundStyle(isSelected ? kind.color : .white.opacity(0.70))

                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(isSelected ? 0.94 : 0.70))
            }

            VStack(spacing: 2.5) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < kind.barCount ? kind.color : .white.opacity(0.070))
                        .frame(width: 18, height: 3.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? .white.opacity(0.055) : .white.opacity(0.010))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected ? kind.color.opacity(0.72) : .white.opacity(0.018),
                    lineWidth: isSelected ? 1.05 : 1
                )
        }
        .shadow(
            color: isSelected ? kind.color.opacity(0.07) : .clear,
            radius: 8,
            y: 4
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var dayLabel: String {
        date.formatted(.dateTime.weekday(.narrow))
    }
}

private struct TimelineSpine: View {

    let activities: [PlannedActivity]
    let accentFor: (PlannedActivity) -> Color

    var body: some View {
        VStack(spacing: 12) {
            ForEach(activities, id: \.id) { activity in
                ZStack {
                    Rectangle()
                        .fill(.white.opacity(0.035))
                        .frame(width: 1.5)

                    Circle()
                        .fill(accentFor(activity).opacity(0.95))
                        .frame(width: 5, height: 5)
                }
                .frame(width: 8, height: 58)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct DynamicPlanRow: View {

    let activity: PlannedActivity
    let displayTitle: String
    let accent: Color
    let time: String
    let subtitle: String
    let status: PlanActivityStatus
    let mealImageName: String?
    let mealBuilderImageItems: [MealBuilderImageItem]
    let mealPlaceholderInitial: String

    @State private var pulse = false

    private var isLive: Bool {
        status == .live
    }

    private var isPending: Bool {
        status == .pending
    }
    
    private var timelineMarker: some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1.2)

            Circle()
                .fill(accent.opacity(isPending ? 0.45 : 0.95))
                .frame(
                    width: isLive ? 7 : 5.5,
                    height: isLive ? 7 : 5.5
                )
        }
        .frame(width: 14)
        .frame(maxHeight: .infinity)
    }

    var body: some View {
        HStack(spacing: 14) {
            iconView

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.system(size: 14.6, weight: isLive ? .bold : .semibold))
                    .foregroundStyle(.white.opacity(isPending ? 0.58 : 0.96))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11.4, weight: .medium))
                    .foregroundStyle(.white.opacity(isPending ? 0.34 : 0.50))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(time)
                    .font(.system(size: 14.2, weight: isLive ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(
                        status == .logged
                            ? .white.opacity(0.58)
                            : .white.opacity(isPending ? 0.54 : 0.88)
                    )
      
                statusBadge

            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isLive
                        ? .white.opacity(0.050)
                        : .white.opacity(0.022)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isLive
                        ? accent.opacity(0.34)
                        : accent.opacity(0.11),
                    lineWidth: isLive ? 1.15 : 0.95
                )
        }
        .shadow(
            color: isLive
                ? accent.opacity(0.08)
                : .black.opacity(0.14),
            radius: 8,
            y: 4
        )
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(isLive ? 0.26 : 0.15))
                .frame(width: 34, height: 34)

            iconContent
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        if activity.type.lowercased() == "meal" {
            mealIconContent
                .opacity(isPending ? 0.62 : 0.96)
        } else {
            Image(systemName: resolvedIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent.opacity(isPending ? 0.62 : 0.96))
        }
    }

    @ViewBuilder
    private var mealIconContent: some View {
        if !mealBuilderImageItems.isEmpty {
            BuiltMealPlateView(
                items: mealBuilderImageItems,
                plateSize: 33,
                itemScale: 0.24,
                offsetScale: 0.22,
                plateOpacity: 0.48,
                shadowOpacity: 0.10,
                layoutMode: .compactPreview
            )
            .frame(width: 30, height: 30)
        } else if let assetImageName = activityAssetImageName {
            Image(assetImageName)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
        } else {
            AsyncCustomFoodVisualView(
                filename: activityLocalPhotoFilename,
                placeholderInitial: mealPlaceholderInitial,
                size: 28,
                imageScale: 0.62,
                fallbackSystemImage: resolvedIcon
            )
        }
    }

    private var activityAssetImageName: String? {
        let imageName = resolvedMealImageName
        guard !imageName.isEmpty, UIImage(named: imageName) != nil else { return nil }
        return imageName
    }

    private var activityLocalPhotoFilename: String? {
        let imageName = resolvedMealImageName
        guard !imageName.isEmpty, UIImage(named: imageName) == nil else { return nil }
        return imageName
    }

    private var resolvedMealImageName: String {
        mealImageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private var resolvedIcon: String {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()

        if title.contains("coffee")
              || title.contains("espresso")
              || title.contains("cappuccino")
              || title.contains("latte") {
              return "cup.and.saucer.fill"
          }

          if title.contains("tea") {
              return "teapot.fill"
          }

          if title.contains("water")
              || title.contains("hydration")
              || title.contains("drink") {
              return "drop.fill"
          }

        if title.contains("banana")
            || title.contains("meal")
            || type == "meal" {
            return "fork.knife"
        }

        if title.contains("sauna")
            || title.contains("heat") {
            return "flame.fill"
        }

        if title.contains("walk")
            || type.contains("walk") {
            return isLive ? "figure.walk.motion" : "figure.walk"
        }

        if title.contains("hike")
            || type.contains("hike") {
            return "figure.hiking"
        }

        if title.contains("running")
            || title.contains("run")
            || type.contains("running")
            || type.contains("run") {
            return "figure.run"
        }

        if title.contains("cycling")
            || title.contains("cycle")
            || title.contains("bike")
            || title.contains("ride")
            || type.contains("cycling")
            || type.contains("cycle")
            || type.contains("bike")
            || type.contains("ride") {
            return "bicycle"
        }

        if title.contains("yoga")
            || type.contains("yoga") {
            return "figure.mind.and.body"
        }

        if title.contains("breathing")
            || title.contains("breath")
            || type.contains("breathing")
            || type.contains("breath") {
            return "wind"
        }

        if title.contains("stretching")
            || title.contains("stretch")
            || title.contains("mobility")
            || type.contains("stretching")
            || type.contains("stretch")
            || type.contains("mobility") {
            return "figure.flexibility"
        }

        if title.contains("upper body") {
            return "figure.strengthtraining.traditional"
        }

        if title.contains("strength")
            || title.contains("gym")
            || title.contains("training")
            || title.contains("workout")
            || type.contains("workout") {
            return "dumbbell.fill"
        }

        if title.contains("sleep")
            || title.contains("bedtime") {
            return "bed.double.fill"
        }

        if title.contains("no screens")
            || title.contains("screen") {
            return "iphone.slash"
        }

        if title.contains("morning routine")
            || title.contains("morning") {
            return "sunrise.fill"
        }

        if title.contains("routine")
            || type == "habit" {
            return "checkmark.circle"
        }

        if type == "recovery" {
            return "leaf.fill"
        }

        return activity.icon.isEmpty ? fallbackIcon : activity.icon
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {

            if activity.source == "appleWorkout" {
                Image(systemName: "applewatch")
                    .font(.system(size: 9, weight: .bold))
                .foregroundStyle(accent.opacity(0.52))
            }

            if status == .live {
                Circle()
                    .fill(accent)
                    .frame(width: 5, height: 5)
                    .scaleEffect(pulse ? 1.22 : 0.86)
                    .opacity(pulse ? 0.48 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.1)
                            .repeatForever(autoreverses: true),
                        value: pulse
                    )
                    .onAppear {
                        pulse = true
                    }
            }

            Text(statusText)
        }
        .font(.system(size: 10.2, weight: .semibold))
        .foregroundStyle(status.color(accent: accent))
    }

    private var statusText: String {

        if activity.source == "appleWorkout",
           status == .logged {
            return "Synced"
        }

        return status.title
    }

    private var fallbackIcon: String {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()

        if title.contains("water")
            || title.contains("drink")
            || title.contains("tea")
            || title.contains("hydration") {
            return "drop.fill"
        }

        switch type {
        case "workout":
            return "figure.run"
        case "meal":
            return "fork.knife"
        case "recovery":
            return "leaf.fill"
        case "habit":
            return "checkmark.circle"
        default:
            return "sparkles"
        }
    }
}

// MARK: - Day Kind

private enum PlanDayKind: Equatable {
    case endurance
    case load
    case mixed
    case recovery
    case open

    var label: String {
        switch self {
        case .endurance: return "Endurance"
        case .load: return "Load"
        case .mixed: return "Mixed"
        case .recovery: return "Recovery"
        case .open: return "Open"
        }
    }

    var color: Color {
        switch self {
        case .endurance: return Color(hex: "#5E7CFF")
        case .load: return Color(hex: "#FF9F43")
        case .mixed: return Color(hex: "#FFD166")
        case .recovery: return Color(hex: "#59D98E")
        case .open: return .white.opacity(0.24)
        }
    }

    var barCount: Int {
        switch self {
        case .endurance: return 4
        case .load: return 3
        case .mixed: return 2
        case .recovery: return 1
        case .open: return 0
        }
    }
}

// MARK: - Activity Status

enum PlanActivityStatus {
    case upcoming
    case live
    case pending
    case completed
    case skipped
    case logged

    var title: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .live: return "Live"
        case .pending: return "Pending"
        case .completed: return "Done"
        case .skipped: return "Skipped"
        case .logged: return "Logged"
        }
    }
    
    func color(accent: Color) -> Color {
        switch self {
        case .upcoming:  return Color(hex: "#7E8CFF").opacity(0.78)
        case .live: return accent
        case .pending: return Color(hex: "#FFB457")
        case .skipped: return Color(hex: "#FF6B6B")
        case .completed: return Color(hex: "#59D98E")      // Done
        case .logged: return Color.white.opacity(0.42)     // Logged
        }
    }
}

// MARK: - Background

private extension WeekPlannerView {

    var ambientBackground: some View {
        WeekFitTheme.planAmbient
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(WeekFitTheme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(WeekFitTheme.borderSoft, lineWidth: 1)
            }
    }
    
    private func timelineTitle(for item: PlanTimelineItem) -> String {
        switch item {
        case .single(let activity):
            return activity.title
        case .waterGroup:
            return "Hydration"
        }
    }

    private func timelineTime(for item: PlanTimelineItem) -> String {
        switch item {
        case .single(let activity):
            return timeTitle(activity.date)

        case .waterGroup(let activities):
            return activities.last.map { timeTitle($0.date) } ?? ""
        }
    }

    private func timelineSubtitle(for item: PlanTimelineItem) -> String {
        switch item {
        case .single(let activity):
            return activitySubtitle(activity)

        case .waterGroup(let activities):
            let count = activities.count
            let first = activities.first.map { timeTitle($0.date) } ?? ""
            let last = activities.last.map { timeTitle($0.date) } ?? ""

            if first == last {
                return "\(count) water logs"
            }

            return "\(count) water logs • \(first)–\(last)"
        }
    }
}

// MARK: - Color Helper

private extension Color {

    init(hex: String) {
        let cleanHex = hex.replacingOccurrences(of: "#", with: "")
        let scanner = Scanner(string: cleanHex)

        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let red = Double((value >> 16) & 0xff) / 255.0
        let green = Double((value >> 8) & 0xff) / 255.0
        let blue = Double(value & 0xff) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

private enum PlanTimelineItem: Identifiable {
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
