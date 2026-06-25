import SwiftUI
import SwiftData
import HealthKit
import UIKit

struct WeekPlannerView: View {

    @ObservedObject var viewModel: PlanViewModel
    var plannedActivitiesRevision: String = ""
    @ObservedObject var authViewModel: AuthViewModel

    @Environment(\.tabIsActive) private var tabIsActive

    var body: some View {
        if tabIsActive {
            WeekPlannerLiveQueryView(
                viewModel: viewModel,
                plannedActivitiesRevision: plannedActivitiesRevision,
                authViewModel: authViewModel
            )
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        }
    }
}

private struct WeekPlannerLiveQueryView: View {

    @ObservedObject var viewModel: PlanViewModel
    var plannedActivitiesRevision: String = ""
    
    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]
    
    @ObservedObject var authViewModel: AuthViewModel
    
    @EnvironmentObject private var activityCoordinator: WeekFitActivityCoordinator
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Environment(\.tabIsActive) private var tabIsActive

    @StateObject private var userSettings = WeekFitUserSettings.shared

    @State private var mode: PlanMode = .week
    @State private var showProfile = false
    
    @Environment(\.modelContext) private var modelContext

    @State private var selectedMeal: Meals?
    @State private var selectedFood: Meals?
    @State private var showNutritionDetails = false
    @State private var nutritionDetailsDate = Date()
    @State private var selectedActivitySession: ActivitySessionSnapshot?

    private let sessionResolver = PlannedActivitySessionResolver()

    private let calendar = Calendar.current
    
    @AppStorage(NotificationPreferenceKey.activityReminders)
    private var activityRemindersEnabled = false

    @AppStorage(NotificationPreferenceKey.completionCheckIns)
    private var completionCheckInsEnabled = false

    @AppStorage(CustomMealStore.storageKey)
    private var customMealsStorage = ""
    
    @State private var activityToConfirm: PlannedActivity?
    @State private var hasPerformedInitialScroll = false

    @ScaledMetric(relativeTo: .title3) private var selectedDayTitleFontSize: CGFloat = 19
    
    private var effectiveActivitiesRevision: String {
        if !plannedActivitiesRevision.isEmpty {
            return plannedActivitiesRevision
        }
        return PlannedActivityRefreshSignature.make(from: plannedActivities)
    }

    private var plannerGateToken: String {
        let revision = PlannedActivityRefreshSignature.compactToken(from: effectiveActivitiesRevision)
        return "\(viewModel.plannerInteractionToken)|\(revision)"
    }

    var body: some View {
        EquatableView(
            content: PlannerBodyGate(
                gateToken: plannerGateToken,
                plannerContent: activePlannerBody
            )
        )
    }

    @ViewBuilder
    private var activePlannerBody: some View {
        let _ = languageManager.selectedLanguage
        #if DEBUG
        let _ = TabSwitchProfiler.mark("WeekPlannerView.body")
        #endif

        GeometryReader { proxy in
            let screenWidth = UIScreen.main.bounds.width
            
            ZStack {
                WeekFitScreenContainer {
                    Group {
                        if !viewModel.showAddActivity {
                            WeekFitScreenHeader(
                                title: WeekFitLocalizedString("planner.week.title"),
                                subtitle: WeekFitLocalizedString("planner.week.subtitle"),
                                initials: userSettings.profileInitials,
                                showAvatar: true
                            ) {
                                showProfile = true
                            }
                        }
                    }
                } content: {
                    plannerContent
                }
                .blur(radius: viewModel.showAddActivity ? 8 : 0)
                .opacity(viewModel.showAddActivity ? 0.22 : 1)
                .allowsHitTesting(!viewModel.showAddActivity)
                .padding(.bottom, WeekFitScreenLayout.tabBarClearance)
                .frame(width: screenWidth, height: proxy.size.height, alignment: .top)
                .clipped()

                if viewModel.showAddActivity {
                    Color.black.opacity(0.58)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.closeAddSheet()
                        }

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.plan")
        .id("planner-keepalive")
        .animation(
            .spring(response: 0.42, dampingFraction: 0.90, blendDuration: 0.08),
            value: viewModel.showAddActivity
        )
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
            .environmentObject(healthManager)
            .environmentObject(nutritionViewModel)
            .environmentObject(appSession)
            .environmentObject(languageManager)
            .weekFitSheetChrome(cornerRadius: 36)
        }
        .sheet(item: $selectedMeal) { meal in
            MealDetailsView(meal: meal)
                .environmentObject(languageManager)
        }
        .sheet(item: $selectedFood) { food in
            CustomFoodDetailsView(
                food: food,
                existingMeals: customMeals
            )
            .environmentObject(languageManager)
        }
        .fullScreenCover(isPresented: $showNutritionDetails) {
            NutritionDetailsView(
                selectedDate: nutritionDetailsDate,
                calories: nutritionCalories(for: nutritionDetailsDate),
                protein: nutritionProtein(for: nutritionDetailsDate),
                carbs: nutritionCarbs(for: nutritionDetailsDate),
                fats: nutritionFats(for: nutritionDetailsDate),
                fiber: nutritionFiber(for: nutritionDetailsDate),
                proteinGoal: proteinGoal,
                carbsGoal: carbsGoal,
                fatsGoal: fatsGoal,
                fiberGoal: fiberGoal,
                meals: nutritionMeals(for: nutritionDetailsDate)
            ) { newDate in
                nutritionDetailsDate = newDate
            }
            .environmentObject(languageManager)
        }
        .fullScreenCover(item: $selectedActivitySession) { session in
            ActivitySessionDetailView(
                session: session,
                healthManager: healthManager
            )
        }
        .sheet(item: $activityToConfirm) { activity in
            plannerConfirmationSheet(activity)
                .presentationDetents([.fraction(0.32)])
                .presentationDragIndicator(.visible)
                .weekFitSheetChrome(cornerRadius: 30)
        }
        .onAppear {
            viewModel.syncCustomMeals(
                from: userSettings.customMealsCatalog,
                revision: userSettings.customMealsCatalogRevision
            )
            #if DEBUG
            TabSwitchProfiler.markEvent("WeekPlannerView.onAppear revisionBytes=\(effectiveActivitiesRevision.count)")
            #endif
        }
        .onChange(of: userSettings.customMealsCatalogRevision) { _, revision in
            viewModel.syncCustomMeals(from: userSettings.customMealsCatalog, revision: revision)
        }
    }
    
    private func plannerConfirmationSheet(_ activity: PlannedActivity) -> some View {
        let accent = activityAccent(for: activity)

        return VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text(AppText.Planner.confirmActivityTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(String(format: WeekFitLocalizedString("planner.confirm.activityMessageFormat"), activity.title))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.62))
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
                        Text(WeekFitLocalizedString("planner.action.markSkipped"))
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.64))
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
                        Text(AppText.Common.Action.done)
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
    
    private     var plannerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mode == .week {
                weekPickerCard

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
    }

    private func deleteTimelineItem(_ item: PlanTimelineItem) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        switch item {
        case .single(let activity):
            deleteActivity(activity)

        case .waterGroup(let activities):
            activities.forEach { deleteActivity($0) }
        }
    }

    private func openTimelineItem(_ item: PlanTimelineItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        switch item {
        case .waterGroup:
            nutritionDetailsDate = viewModel.selectedDate
            showNutritionDetails = true

        case .single(let activity):
            openTimelineActivity(activity)
        }
    }

    private func openTimelineActivity(_ activity: PlannedActivity) {
        if activity.timelineEventKind == .food {
            openTimelineMeal(
                PlanTimelineRouter.meal(
                    for: activity,
                    customMeals: customMeals
                )
            )
            return
        }

        if PlanTimelineRouter.shouldOpenNutrition(for: activity) {
            nutritionDetailsDate = viewModel.selectedDate
            showNutritionDetails = true
            return
        }

        if PlanTimelineRouter.shouldOpenActivityDetail(for: activity) {
            Task {
                let session = await sessionResolver.resolve(activity, healthManager: healthManager)
                selectedActivitySession = session
            }
            return
        }

        openTimelineMeal(
            PlanTimelineRouter.meal(
                for: activity,
                customMeals: customMeals
            )
        )
    }

    private func openTimelineMeal(_ meal: Meals) {
        if meal.isFoodProduct {
            selectedFood = meal
        } else {
            selectedMeal = meal
        }
    }

    @ViewBuilder
    private func timelineItemContextMenu(
        for item: PlanTimelineItem,
        status: PlanActivityStatus
    ) -> some View {
        switch item {
        case .waterGroup:
            EmptyView()

        case .single(let activity):
            if status == .pending {
                Button {
                    activityToConfirm = activity
                } label: {
                    Label(AppText.Common.Action.done, systemImage: "checkmark.circle.fill")
                }
            }

            if status == .upcoming || status == .pending {
                Button {
                    viewModel.startEditing(activity)
                } label: {
                    Label(WeekFitLocalizedString("common.action.edit"), systemImage: "pencil")
                }
            }
        }
    }
}

// MARK: - Mode

private enum PlanMode {
    case week
    case month
}

// MARK: - Segmented Control

private extension WeekPlannerLiveQueryView {

    var segmentedControl: some View {
        HStack(spacing: 0) {
            segmentButton(WeekFitLocalizedString("planner.week"), .week)
            segmentButton(WeekFitLocalizedString("planner.month"), .month)
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

// MARK: - Week Picker

private extension WeekPlannerLiveQueryView {

    var weekPickerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            PlanningWeekPicker(
                selectedDate: $viewModel.selectedDate,
                dayKind: { viewModel.dayKind(for: $0, plannedActivities: plannedActivities, revision: effectiveActivitiesRevision) }
            )

            WeekOverviewLegend()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(cardBackground)
    }
}

private struct WeekOverviewLegend: View {

    private struct Entry {
        let titleKey: String
        let color: Color
    }

    private let entries: [Entry] = [
        Entry(titleKey: "planner.legend.endurance", color: Color(hex: "#5E7CFF")),
        Entry(titleKey: "planner.legend.highLoad", color: Color(hex: "#FF9F43")),
        Entry(titleKey: "planner.legend.mixed", color: Color(hex: "#FFD166")),
        Entry(titleKey: "planner.legend.recovery", color: Color(hex: "#59D98E"))
    ]

    @ScaledMetric(relativeTo: .caption2) private var fontSize: CGFloat = 10.5
    @ScaledMetric(relativeTo: .caption2) private var dotSize: CGFloat = 5

    var body: some View {
        ViewThatFits(in: .horizontal) {
            legendRow(itemSpacing: 10, dotSpacing: 5)
            legendRow(itemSpacing: 6, dotSpacing: 4)
            legendRow(itemSpacing: 4, dotSpacing: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func legendRow(itemSpacing: CGFloat, dotSpacing: CGFloat) -> some View {
        HStack(spacing: itemSpacing) {
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                legendItem(
                    title: WeekFitLocalizedString(entry.titleKey),
                    color: entry.color,
                    dotSpacing: dotSpacing
                )
            }
        }
    }

    private func legendItem(title: String, color: Color, dotSpacing: CGFloat) -> some View {
        HStack(spacing: dotSpacing) {
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)

            Text(title)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.54))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel(title)
    }
}

// MARK: - Selected Day

private extension WeekPlannerLiveQueryView {

    var selectedDayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedDayTitle)
                        .font(.system(size: selectedDayTitleFontSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)

                    if selectedDayActivities.isEmpty {
                        Text(WeekFitLocalizedString("planner.daySubtitle.empty"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                    } else {
                        selectedDayStatsRow
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                if !selectedDayActivities.isEmpty {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.startAdding(
                            at: viewModel.nextAvailableSlot(from: plannedActivities)
                        )
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "#8E9EFF").opacity(0.92))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(hex: "#7E8CFF").opacity(0.14))
                            )
                            .overlay {
                                Circle()
                                    .stroke(Color(hex: "#7E8CFF").opacity(0.22), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(WeekFitLocalizedString("planner.sheet.addTitle"))
                }
            }

            if selectedDayActivities.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    emptySelectedDay
                        .padding(.top, 8)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(timelineItems.enumerated()), id: \.element.id) { index, item in
                            let activity = item.representative
                            let status = resolvedActivityStatus(for: activity)
                            let category = PlanTimelineCategory.from(activity: activity)
                            let emphasis = timelineEmphasis(for: item, status: status)

                            if shouldShowTimelineNowDivider(at: index) {
                                PlanTimelineNowDivider()
                                    .listRowInsets(
                                        EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }

                            PlanTimelineRow(
                                activity: activity,
                                displayTitle: timelineTitle(for: item),
                                metadata: PlanTimelineMetadataBuilder.metadata(
                                    for: item,
                                    status: status,
                                    formattedDuration: formattedDuration
                                ),
                                customMeals: customMeals,
                                time: timelineTime(for: item),
                                category: category,
                                status: status,
                                emphasis: emphasis,
                                nextEmphasis: timelineNextEmphasis(at: index),
                                isFirst: index == 0,
                                isLast: index == timelineItems.count - 1,
                                connectorAbove: timelineConnectorAbove(at: index),
                                density: PlanTimelineMetadataBuilder.density(for: item),
                                showsTimeLabel: PlanTimelineItemGrouper.showsTimeLabel(
                                    at: index,
                                    in: timelineItems,
                                    timeText: { timelineTime(for: $0) }
                                )
                            )
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                openTimelineItem(item)
                            }
                            .contextMenu {
                                timelineItemContextMenu(for: item, status: status)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteTimelineItem(item)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .tint(Color.red.opacity(0.68))
                            }
                            .listRowInsets(
                                EdgeInsets(
                                    top: 0,
                                    leading: 6,
                                    bottom: PlanTimelineLayout.rowSpacing,
                                    trailing: 6
                                )
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                    .environment(\.defaultMinListRowHeight, 1)
                    .contentMargins(.top, 2, for: .scrollContent)
                    .contentMargins(.bottom, 28, for: .scrollContent)
                    .onAppear {
                        guard !hasPerformedInitialScroll else { return }
                        hasPerformedInitialScroll = true
                        scheduleScrollToRelevantActivity(proxy, animated: false)
                    }
                    .onChange(of: viewModel.selectedDate) { _, _ in
                        scheduleScrollToRelevantActivity(proxy)
                    }
                    .onChange(of: selectedDayActivities.count) { _, _ in
                        scheduleScrollToRelevantActivity(proxy)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectedDayCardBackground)
    }
    
    func resolvedActivityStatus(for item: PlannedActivity) -> PlanActivityStatus {
        activityCoordinator.resolvedStatus(
            for: item,
            baseStatus: activityStatus(for: item)
        )
    }

    private var timelineFocusItemID: String? {
        PlanTimelineEmphasisResolver.focusItemID(
            in: timelineItems,
            statusFor: { resolvedActivityStatus(for: $0) },
            selectedDay: viewModel.selectedDate
        )
    }

    private func timelineEmphasis(for item: PlanTimelineItem, status: PlanActivityStatus) -> PlanTimelineVisualEmphasis {
        PlanTimelineEmphasisResolver.emphasis(
            for: item,
            status: status,
            focusItemID: timelineFocusItemID
        )
    }

    private func timelineNextEmphasis(at index: Int) -> PlanTimelineVisualEmphasis? {
        guard index + 1 < timelineItems.count else { return nil }

        let nextItem = timelineItems[index + 1]
        let nextStatus = resolvedActivityStatus(for: nextItem.representative)
        return timelineEmphasis(for: nextItem, status: nextStatus)
    }

    private func shouldShowTimelineNowDivider(at index: Int) -> Bool {
        PlanTimelineEmphasisResolver.shouldShowNowDivider(
            at: index,
            in: timelineItems,
            focusItemID: timelineFocusItemID,
            statusFor: { resolvedActivityStatus(for: $0) }
        )
    }

    private func timelineConnectorAbove(at index: Int) -> CGFloat {
        guard index > 0 else { return 0 }

        let previous = timelineItems[index - 1]
        let current = timelineItems[index]
        let gapMinutes = current.firstDate.timeIntervalSince(previous.firstDate) / 60

        if gapMinutes >= 120 { return 10 }
        if gapMinutes >= 75 { return 6 }
        if gapMinutes >= 45 { return 4 }
        return 0
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

                    Text(AppText.Planner.buildYourDay)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(AppText.Planner.buildYourDayMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.20))
                    .padding(.leading, -2)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Month Placeholder

private extension WeekPlannerLiveQueryView {
    
    func scheduleScrollToRelevantActivity(_ proxy: ScrollViewProxy, animated: Bool = true) {
        Task { @MainActor in
            await Task.yield()
            guard tabIsActive else { return }
            scrollToRelevantActivity(proxy, animated: animated)
        }
    }

    func scrollToRelevantActivity(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let anchor = UnitPoint(x: 0.5, y: 0.38)
        let scrollAction = {
            if let focusID = timelineFocusItemID {
                proxy.scrollTo(focusID, anchor: anchor)
                return
            }

            if let lastCompleted = timelineItems.last(where: {
                resolvedActivityStatus(for: $0.representative) == .completed
            }) {
                proxy.scrollTo(lastCompleted.id, anchor: anchor)
            }
        }

        if animated {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                scrollAction()
            }
        } else {
            scrollAction()
        }
    }

    var monthPlaceholderCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(AppText.Planner.monthView)
                .font(.system(size: 11.5, weight: .bold))
                .tracking(0.35)
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.42))

            Text(AppText.Planner.monthComing)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(AppText.Planner.monthSourceOfTruth)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.56))

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    mode = .week
                }
            } label: {
                Text(AppText.Planner.backToWeek)
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

// MARK: - Footer

private extension WeekPlannerLiveQueryView {

    var adaptiveFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))

            Text(AppText.Planner.weeklyCoachNote)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }
}

// MARK: - Dynamic Data

private extension WeekPlannerLiveQueryView {

    var selectedDayActivities: [PlannedActivity] {
        viewModel.selectedDayActivities(from: plannedActivities)
    }

    private var timelineItems: [PlanTimelineItem] {
        viewModel.timelineItems(from: plannedActivities, revision: effectiveActivitiesRevision)
    }

    private var customMeals: [Meals] {
        viewModel.customMeals
    }

    private var proteinGoal: Double { nutritionViewModel.nutritionResult?.goals.protein ?? 153.0 }
    private var carbsGoal: Double { nutritionViewModel.nutritionResult?.goals.carbs ?? 330.0 }
    private var fatsGoal: Double { nutritionViewModel.nutritionResult?.goals.fats ?? 90.0 }
    private var fiberGoal: Double { nutritionViewModel.nutritionResult?.goals.fiber ?? 35.0 }

    private func nutritionMeals(for date: Date) -> [PlannedActivity] {
        plannedActivities
            .filter {
                calendar.isDate($0.date, inSameDayAs: date)
                    && ($0.type.lowercased() == "meal" || $0.type.lowercased() == "drink")
                    && $0.isCompleted
                    && !$0.isSkipped
                    && $0.imageName != "hydration"
            }
            .sorted { $0.date < $1.date }
    }

    private func nutritionCalories(for date: Date) -> Double {
        Double(nutritionMeals(for: date).reduce(0) { $0 + $1.calories })
    }

    private func nutritionProtein(for date: Date) -> Double {
        Double(nutritionMeals(for: date).reduce(0) { $0 + $1.protein })
    }

    private func nutritionCarbs(for date: Date) -> Double {
        Double(nutritionMeals(for: date).reduce(0) { $0 + $1.carbs })
    }

    private func nutritionFats(for date: Date) -> Double {
        Double(nutritionMeals(for: date).reduce(0) { $0 + $1.fats })
    }

    private func nutritionFiber(for date: Date) -> Double {
        Double(nutritionMeals(for: date).reduce(0) { $0 + $1.fiber })
    }

    private func matchingCustomMeal(for activity: PlannedActivity) -> Meals? {
        guard activity.type.lowercased() == "meal" else { return nil }

        let normalizedTitle = CustomMealStore.normalizedTitle(activity.title)
        guard !normalizedTitle.isEmpty else { return nil }

        return customMeals.first {
            CustomMealStore.normalizedTitle($0.title) == normalizedTitle
        }
    }

    var selectedDayKind: PlanDayKind {
        viewModel.dayKind(for: viewModel.selectedDate, plannedActivities: plannedActivities, revision: effectiveActivitiesRevision)
    }

    var selectedDayTitle: String {
        selectedDayKind.legendLabel
    }

    private var selectedDayActivityCounts: (workouts: Int, meals: Int, recovery: Int, habits: Int) {
        let activities = selectedDayActivities
        return (
            workouts: activities.filter { $0.type.lowercased() == "workout" }.count,
            meals: activities.filter { $0.type.lowercased() == "meal" }.count,
            recovery: activities.filter { $0.type.lowercased() == "recovery" }.count,
            habits: activities.filter { $0.type.lowercased() == "habit" }.count
        )
    }

    @ViewBuilder
    var selectedDayStatsRow: some View {
        let counts = selectedDayActivityCounts

        HStack(spacing: 8) {
            if counts.workouts > 0 {
                PlanDayStatChip(
                    icon: "figure.run",
                    count: counts.workouts,
                    tint: WeekFitTheme.workout
                )
            }

            if counts.meals > 0 {
                PlanDayStatChip(
                    icon: "fork.knife",
                    count: counts.meals,
                    tint: WeekFitTheme.meal
                )
            }

            if counts.recovery > 0 {
                PlanDayStatChip(
                    icon: "leaf.fill",
                    count: counts.recovery,
                    tint: WeekFitTheme.recovery
                )
            }

            if counts.habits > 0 {
                PlanDayStatChip(
                    icon: "checkmark.circle.fill",
                    count: counts.habits,
                    tint: WeekFitTheme.habit
                )
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectedDaySubtitle)
    }
    
    func formattedDuration(_ minutes: Int) -> String {

        if minutes >= 60 {

            let hours = minutes / 60
            let remainingMinutes = minutes % 60

            if remainingMinutes == 0 {
                return String(format: WeekFitLocalizedString("common.duration.hoursShortFormat"), hours)
            }

            return String(format: WeekFitLocalizedString("common.duration.hoursMinutesShortFormat"), hours, remainingMinutes)
        }

        return String(format: WeekFitLocalizedString("common.duration.minutesFormat"), minutes)
    }

    var selectedDaySubtitle: String {
        let count = selectedDayActivities.count

        if count == 0 {
            return WeekFitLocalizedString("planner.daySubtitle.empty")
        }

        let workouts = selectedDayActivities.filter { $0.type.lowercased() == "workout" }.count
        let meals = selectedDayActivities.filter { $0.type.lowercased() == "meal" }.count
        let recovery = selectedDayActivities.filter { $0.type.lowercased() == "recovery" }.count
        let habits = selectedDayActivities.filter { $0.type.lowercased() == "habit" }.count

        var parts: [String] = []

        if workouts > 0 { parts.append(workoutCountText(count: workouts)) }
        if meals > 0 { parts.append(mealCountText(count: meals)) }
        if recovery > 0 {
            parts.append(recoveryCountText(count: recovery))
        }
        if habits > 0 {
            parts.append(WeekFitCountPluralization.phrase(count: habits, category: .habit))
        }

        if parts.isEmpty {
            return WeekFitCountPluralization.phrase(count: count, category: .plannedItem)
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }

        return parts.joined(separator: " • ")
    }

    private func workoutCountText(count: Int) -> String {
        WeekFitCountPluralization.phrase(count: count, category: .workout)
    }

    private func mealCountText(count: Int) -> String {
        WeekFitCountPluralization.phrase(count: count, category: .meal)
    }

    private func recoveryCountText(count: Int) -> String {
        WeekFitCountPluralization.phrase(count: count, category: .recovery)
    }

    func dayActivities(for date: Date) -> [PlannedActivity] {
        viewModel.activities(for: date, from: plannedActivities)
    }

    func dayKind(for date: Date) -> PlanDayKind {
        viewModel.dayKind(for: date, plannedActivities: plannedActivities, revision: effectiveActivitiesRevision)
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

    private func isDrinkActivity(_ item: PlannedActivity) -> Bool {
        let type = item.type.lowercased()
        let title = item.title.lowercased()

        return type.contains("water") ||
            type.contains("drink") ||
            title.contains("water") ||
            title.contains("hydration") ||
            title.contains("drink")
    }

    private func localizedPlanTypeLabel(type: String, title: String) -> String {
        if type == "meal" || title.contains("meal") {
            return WeekFitLocalizedString("planner.timeline.meal")
        }

        if type.contains("water") || type.contains("drink") || title.contains("water") || title.contains("drink") {
            return WeekFitLocalizedString("planner.timeline.drink")
        }

        return WeekFitCoachRuntimeLocalizedString(type)
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

            if item.isWatchSynced || loggedSources.contains(item.source) {
                return .logged
            }

            return .completed
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

private struct PlanDayStatChip: View {
    let icon: String
    let count: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint.opacity(0.96))

            Text("\(count)")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.78))
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(tint.opacity(0.12))
        }
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.22), lineWidth: 0.8)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

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
        HStack(spacing: 6) {
            weekNavigationButton(systemName: "chevron.left") {
                moveWeek(by: -1)
            }

            HStack(spacing: 4) {
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
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.64))
                .frame(width: 24, height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PlanScreenSurface.capsuleFill)
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
        VStack(spacing: 4) {
            VStack(spacing: 1) {
                HStack(spacing: 2) {
                    Text(dayLabel)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    if isToday {
                        Circle()
                            .fill(kind.color)
                            .frame(width: 3, height: 3)
                    }
                }
                .foregroundStyle(isSelected ? kind.color : .white.opacity(0.70))

                Text(dayNumber)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WeekFitTheme.whiteOpacity(isSelected ? 0.94 : 0.70))
            }

            VStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index < kind.barCount ? kind.color : WeekFitTheme.whiteOpacity(0.045))
                        .frame(width: 16, height: 3)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? PlanScreenSurface.capsuleSelectedFill : PlanScreenSurface.capsuleFill.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? kind.color.opacity(0.72) : PlanScreenSurface.cardStroke,
                    lineWidth: isSelected ? 1.05 : 1
                )
        }
        .shadow(
            color: isSelected ? kind.color.opacity(0.07) : .clear,
            radius: 6,
            y: 3
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("d")
        return formatter.string(from: date)
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
        case .upcoming: return WeekFitLocalizedString("planner.status.upcoming")
        case .live: return WeekFitLocalizedString("planner.status.live")
        case .pending: return WeekFitLocalizedString("planner.status.pending")
        case .completed: return WeekFitLocalizedString("planner.status.completed")
        case .skipped: return WeekFitLocalizedString("planner.status.skipped")
        case .logged: return WeekFitLocalizedString("planner.status.logged")
        }
    }
    
    func color(accent: Color) -> Color {
        switch self {
        case .upcoming:  return Color(hex: "#7E8CFF").opacity(0.78)
        case .live: return accent
        case .pending: return Color(hex: "#FFB457")
        case .skipped: return Color(hex: "#FF6B6B")
        case .completed: return Color(hex: "#59D98E")      // Done
        case .logged: return WeekFitTheme.whiteOpacity(0.42)     // Logged
        }
    }
}

// MARK: - Background

private enum PlanScreenSurface {
    static var cardFill: Color { Color(red: 0.038, green: 0.042, blue: 0.048) }
    static var cardStroke: Color { WeekFitTheme.borderSoft }
    static var capsuleFill: Color { Color(red: 0.046, green: 0.050, blue: 0.056) }
    static var capsuleSelectedFill: Color { Color(red: 0.054, green: 0.058, blue: 0.066) }
}

private extension WeekPlannerLiveQueryView {

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(PlanScreenSurface.cardFill)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PlanScreenSurface.cardStroke, lineWidth: 1)
            }
    }

    var selectedDayCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(PlanScreenSurface.cardFill)
            .overlay(alignment: .bottom) {
                timelineBottomFade
                    .clipShape(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PlanScreenSurface.cardStroke, lineWidth: 1)
            }
    }

    var timelineBottomFade: some View {
        LinearGradient(
            colors: [
                PlanScreenSurface.cardFill.opacity(0),
                PlanScreenSurface.cardFill.opacity(0.62),
                WeekFitTheme.backgroundColor.opacity(0.94),
                WeekFitTheme.backgroundColor
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 72)
    }
    
    private func timelineTitle(for item: PlanTimelineItem) -> String {
        switch item {
        case .single(let activity):
            return timelineTitle(for: activity)
        case .waterGroup:
            return WeekFitLocalizedString("planner.timeline.water")
        }
    }

    private func timelineTitle(for activity: PlannedActivity) -> String {
        let trimmedTitle = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = trimmedTitle.lowercased()
        let type = activity.type.lowercased()

        if isDrinkActivity(activity) {
            if normalizedTitle.contains("water") || normalizedTitle.contains("hydration") {
                return WeekFitLocalizedString("planner.timeline.water")
            }

            return WeekFitLocalizedString("planner.timeline.drink")
        }

        if type == "meal" && (trimmedTitle.isEmpty || normalizedTitle == "meal") {
            return WeekFitLocalizedString("planner.timeline.meal")
        }

        if normalizedTitle == "water" {
            return WeekFitLocalizedString("planner.timeline.water")
        }

        if normalizedTitle == "drink" {
            return WeekFitLocalizedString("planner.timeline.drink")
        }

        if let meal = matchingCustomMeal(for: activity) {
            return meal.localizedDisplayTitle
        }

        let quickLocalized = QuickItem.localizedTitle(forStoredTitle: trimmedTitle)
        if quickLocalized != trimmedTitle {
            return quickLocalized
        }

        return WeekFitCoachRuntimeLocalizedString(trimmedTitle)
    }

    private func timelineTime(for item: PlanTimelineItem) -> String {
        switch item {
        case .single(let activity):
            return timeTitle(activity.date)

        case .waterGroup(let activities):
            return activities.last.map { timeTitle($0.date) } ?? ""
        }
    }
}

// MARK: - Keep-alive gate (skip heavy planner body while tab inactive)

private struct PlannerBodyGate<PlannerContent: View>: View, Equatable {
    let gateToken: String
    let plannerContent: PlannerContent

    static func == (lhs: PlannerBodyGate, rhs: PlannerBodyGate) -> Bool {
        lhs.gateToken == rhs.gateToken
    }

    var body: some View {
        plannerContent
    }
}

// MARK: - Color Helper

extension PlanDayKind {
    var color: Color {
        switch self {
        case .endurance: return Color(hex: "#5E7CFF")
        case .load: return Color(hex: "#FF9F43")
        case .mixed: return Color(hex: "#FFD166")
        case .recovery: return Color(hex: "#59D98E")
        case .open: return .white.opacity(0.24)
        }
    }
}

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
