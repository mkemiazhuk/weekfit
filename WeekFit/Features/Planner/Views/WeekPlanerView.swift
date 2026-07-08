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
    @State private var timelineItemPendingDelete: PlanTimelineItem?
    @State private var hasPerformedInitialScroll = false

    @ScaledMetric(relativeTo: .title3) private var selectedDayTitleFontSize: CGFloat = 19

    var body: some View {
        activePlannerBodyFromLiveQuery()
    }

    private func activePlannerBodyFromLiveQuery() -> some View {
        PlannerBodyDiagnostics.markBodyEvaluation()

        let activitiesRevision = PlannerBodyDiagnostics.measure("activitiesRevision") {
            PlannedActivityRefreshSignature.make(from: plannedActivities)
        }

        let timelineItems = PlannerBodyDiagnostics.measure("timelineItems") {
            viewModel.timelineItems(from: plannedActivities, revision: activitiesRevision)
        }

        let selectedDayKind = viewModel.dayKind(
            for: viewModel.selectedDate,
            plannedActivities: plannedActivities,
            revision: activitiesRevision
        )

        let plannerGateToken = "\(viewModel.plannerInteractionToken)|\(PlannedActivityRefreshSignature.compactToken(from: activitiesRevision))"
        let _ = plannerGateToken

        return activePlannerBody(
            activitiesRevision: activitiesRevision,
            timelineItems: timelineItems,
            selectedDayKind: selectedDayKind
        )
    }

    @ViewBuilder
    private func activePlannerBody(
        activitiesRevision: String,
        timelineItems: [PlanTimelineItem],
        selectedDayKind: PlanDayKind
    ) -> some View {
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
                    plannerContent(
                        activitiesRevision: activitiesRevision,
                        timelineItems: timelineItems,
                        selectedDayKind: selectedDayKind
                    )
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
                caloriesGoal: caloriesGoal,
                proteinGoal: proteinGoal,
                carbsGoal: carbsGoal,
                fatsGoal: fatsGoal,
                fiberGoal: fiberGoal,
                waterLiters: nutritionWater(for: nutritionDetailsDate),
                waterGoal: waterGoal,
                meals: nutritionMeals(for: nutritionDetailsDate),
                mealCatalog: customMeals
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
                .presentationDetents([.fraction(0.40)])
                .presentationDragIndicator(.visible)
                .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
        }
        .confirmationDialog(
            WeekFitLocalizedString("planner.delete.title"),
            isPresented: Binding(
                get: { timelineItemPendingDelete != nil },
                set: { if !$0 { timelineItemPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(WeekFitLocalizedString("planner.delete"), role: .destructive) {
                if let item = timelineItemPendingDelete {
                    performDeleteTimelineItem(item)
                    timelineItemPendingDelete = nil
                }
            }
            Button(WeekFitLocalizedString("common.action.cancel"), role: .cancel) {
                timelineItemPendingDelete = nil
            }
        } message: {
            Text(deleteConfirmationMessage(for: timelineItemPendingDelete))
        }
        .onAppear {
            viewModel.syncCustomMeals(
                from: userSettings.customMealsCatalog,
                revision: userSettings.customMealsCatalogRevision
            )
            #if DEBUG
            TabSwitchProfiler.markEvent(
                "WeekPlannerView.onAppear revisionBytes=\(activitiesRevision.count) timelineCount=\(timelineItems.count)"
            )
            PlannerBodyDiagnostics.reportMountCompleted()
            #endif
        }
        .onChange(of: userSettings.customMealsCatalogRevision) { _, revision in
            viewModel.syncCustomMeals(from: userSettings.customMealsCatalog, revision: revision)
        }
    }
    
    private func plannerConfirmationSheet(_ activity: PlannedActivity) -> some View {
        PremiumActivityConfirmationSheet(
            icon: WeekFitActivityIconResolver.resolve(for: activity),
            accentColor: activityAccent(for: activity),
            title: WeekFitLocalizedString("today.verify.title"),
            messageFormat: WeekFitLocalizedString("today.verify.messageFormat"),
            highlightedName: activity.title,
            confirmTitle: WeekFitLocalizedString("today.verify.confirm"),
            skipTitle: WeekFitLocalizedString("today.verify.skipped"),
            onConfirm: {
                applyPlannerActivityConfirmation(completed: true, for: activity)
            },
            onSkip: {
                applyPlannerActivityConfirmation(completed: false, for: activity)
            }
        )
    }
    
    @ViewBuilder
    private func plannerContent(
        activitiesRevision: String,
        timelineItems: [PlanTimelineItem],
        selectedDayKind: PlanDayKind
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if mode == .week {
                weekPickerCard(activitiesRevision: activitiesRevision)

                selectedDayCard(
                    timelineItems: timelineItems,
                    selectedDayKind: selectedDayKind
                )
                .frame(maxHeight: .infinity)
            } else {
                monthPlaceholderCard
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    func deleteActivity(_ activity: PlannedActivity) {
        viewModel.removePlannedActivities(withIDs: [activity.id], modelContext: modelContext)
    }

    private func deleteTimelineItem(_ item: PlanTimelineItem) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        logPlannerAction(item: item, action: "delete-requested")
        timelineItemPendingDelete = item
    }

    private func performDeleteTimelineItem(_ item: PlanTimelineItem) {
        logPlannerAction(item: item, action: "delete-confirmed")

        let targetIDs = deleteTargetIDs(for: item)
        guard !targetIDs.isEmpty else {
            PlannedActivityPlannerAudit.deleteAborted(
                reason: "no-deletable-targets-or-skipped",
                modelContext: modelContext
            )
            return
        }

        for id in targetIDs {
            logFetchedActivity(id: id, phase: "before-delete")
        }

        PlannedActivityPlannerAudit.deleteTapped(
            itemKind: deleteItemKind(for: item),
            activityIDs: targetIDs,
            titles: deleteAuditTitles(for: item),
            dates: deleteAuditDates(for: item),
            modelContext: modelContext
        )

        do {
            viewModel.beforePlannedActivityDeleted?()
            try PlannedActivityPersistenceService.deleteActivities(
                withIDs: targetIDs,
                modelContext: modelContext,
                auditSource: "WeekPlannerLiveQueryView.performDeleteTimelineItem"
            )
            viewModel.markPlannerDataChanged()
            viewModel.afterPlannedActivityDeleted?()

            for id in targetIDs {
                logFetchedActivity(id: id, phase: "after-save-same-context")
            }

            let freshContext = ModelContext(modelContext.container)
            for id in targetIDs {
                logFetchedActivity(id: id, phase: "after-save-fresh-context", context: freshContext)
            }

            PlannedActivityPlannerAudit.deleteCompleted(
                activityIDs: targetIDs,
                modelContext: modelContext,
                queryActivityIDs: plannedActivities.map(\.id)
            )
        } catch {
            PlannedActivityPlannerAudit.deleteFailed(
                ids: targetIDs,
                error: error,
                modelContext: modelContext
            )
        }
    }

    private func logPlannerAction(item: PlanTimelineItem, action: String) {
        switch item {
        case .single(let activity):
            PlannedActivityPlannerAudit.plannerAction(
                action: action,
                activity: activity,
                modelContext: modelContext
            )

        case .waterGroup(let activities):
            for activity in activities {
                PlannedActivityPlannerAudit.plannerAction(
                    action: action,
                    activity: activity,
                    modelContext: modelContext
                )
            }
        }
    }

    private func logFetchedActivity(
        id: String,
        phase: String,
        context: ModelContext? = nil
    ) {
        let fetchContext = context ?? modelContext
        do {
            let matches = try fetchActivities(id: id, in: fetchContext)
            PlannedActivityPlannerAudit.fetchVerification(
                phase: phase,
                activityID: id,
                count: matches.count,
                matches: matches.map { ($0.title, $0.date, $0.isSkipped) },
                modelContext: fetchContext
            )
        } catch {
            PlannedActivityPlannerAudit.deleteFailed(
                ids: [id],
                error: error,
                modelContext: fetchContext
            )
        }
    }

    private func fetchActivities(id: String, in context: ModelContext) throws -> [PlannedActivity] {
        let targetID = id
        let descriptor = FetchDescriptor<PlannedActivity>(
            predicate: #Predicate { activity in
                activity.id == targetID
            }
        )
        return try context.fetch(descriptor)
    }

    private func deleteItemKind(for item: PlanTimelineItem) -> String {
        switch item {
        case .single:
            return "single"
        case .waterGroup:
            return "waterGroup"
        }
    }

    private func deleteTargetIDs(for item: PlanTimelineItem) -> [String] {
        switch item {
        case .single(let activity):
            guard !activity.isSkipped else {
                return []
            }
            return [activity.id]

        case .waterGroup(let cachedActivities):
            return resolvedWaterGroupDeleteIDs(cachedHint: cachedActivities)
        }
    }

    private func deleteAuditTitles(for item: PlanTimelineItem) -> [String] {
        switch item {
        case .single(let activity):
            return [activity.title]
        case .waterGroup(let activities):
            return activities.map(\.title)
        }
    }

    private func deleteAuditDates(for item: PlanTimelineItem) -> [Date] {
        switch item {
        case .single(let activity):
            return [activity.date]
        case .waterGroup(let activities):
            return activities.map(\.date)
        }
    }

    private func resolvedWaterGroupDeleteIDs(cachedHint: [PlannedActivity]) -> [String] {
        let hintIDs = Set(cachedHint.map(\.id))
        let hintMinuteKeys = Set(cachedHint.map(waterGroupMinuteKey(for:)))

        let liveMatches = selectedDayActivities.filter { activity in
            !activity.isSkipped
                && PlanTimelineItemGrouper.isWaterActivity(activity)
                && (hintIDs.contains(activity.id) || hintMinuteKeys.contains(waterGroupMinuteKey(for: activity)))
        }

        let resolvedIDs = liveMatches.map(\.id)
        if resolvedIDs.isEmpty {
            return Array(hintIDs)
        }
        return resolvedIDs
    }

    private func waterGroupMinuteKey(for activity: PlannedActivity) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute], from: activity.date)
    }

    private func deleteConfirmationMessage(for item: PlanTimelineItem?) -> String {
        guard let item else {
            return WeekFitLocalizedString("planner.delete.message")
        }

        switch item {
        case .single(let activity):
            return String(
                format: WeekFitLocalizedString("planner.delete.activityMessageFormat"),
                activity.title
            )
        case .waterGroup:
            return WeekFitLocalizedString("planner.delete.message")
        }
    }

    private func activityNeedsConfirmation(_ activity: PlannedActivity) -> Bool {
        resolvedActivityStatus(for: activity) == .pending
    }

    private func presentActivityConfirmation(for activity: PlannedActivity) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        activityToConfirm = activity
    }

    private func applyPlannerActivityConfirmation(completed: Bool, for activity: PlannedActivity) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        guard let liveActivity = try? PlannedActivityPersistenceService.fetchActivity(
            id: activity.id,
            in: modelContext
        ) else {
            return
        }

        PlannedActivityPlannerAudit.plannerAction(
            action: completed ? "confirm-completed" : "skip-confirmed",
            activity: liveActivity,
            modelContext: modelContext
        )

        withAnimation {
            if completed {
                try? PlannedActivityNotificationConfirmationService.markCompleted(
                    liveActivity,
                    modelContext: modelContext
                )
            } else {
                try? PlannedActivityNotificationConfirmationService.markSkipped(
                    liveActivity,
                    modelContext: modelContext
                )
            }

            viewModel.markPlannerDataChanged()
            activityToConfirm = nil
        }
    }

    private func openTimelineItem(_ item: PlanTimelineItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        switch item {
        case .waterGroup:
            nutritionDetailsDate = viewModel.selectedDate
            showNutritionDetails = true

        case .single(let activity):
            if activityNeedsConfirmation(activity) {
                presentActivityConfirmation(for: activity)
                return
            }
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
                    presentActivityConfirmation(for: activity)
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

    func weekPickerCard(activitiesRevision: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            PlanningWeekPicker(
                selectedDate: $viewModel.selectedDate,
                dayKind: { viewModel.dayKind(for: $0, plannedActivities: plannedActivities, revision: activitiesRevision) }
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

    @ViewBuilder
    func selectedDayCard(
        timelineItems: [PlanTimelineItem],
        selectedDayKind: PlanDayKind
    ) -> some View {
        let timelineFocusItemID = timelineFocusItemID(in: timelineItems)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedDayKind.legendLabel)
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
                            let emphasis = timelineEmphasis(
                                for: item,
                                status: status,
                                timelineItems: timelineItems,
                                focusItemID: timelineFocusItemID
                            )

                            if shouldShowTimelineNowDivider(
                                at: index,
                                in: timelineItems,
                                focusItemID: timelineFocusItemID
                            ) {
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
                                nextEmphasis: timelineNextEmphasis(
                                    at: index,
                                    in: timelineItems,
                                    focusItemID: timelineFocusItemID
                                ),
                                isFirst: index == 0,
                                isLast: index == timelineItems.count - 1,
                                connectorAbove: timelineConnectorAbove(at: index, in: timelineItems),
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
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if case .single(let activity) = item, status == .pending {
                                    Button {
                                        presentActivityConfirmation(for: activity)
                                    } label: {
                                        Label(AppText.Common.Action.done, systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(Color(hex: "#FFB457"))
                                }
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
                        scheduleScrollToRelevantActivity(
                            proxy,
                            timelineItems: timelineItems,
                            animated: false
                        )
                    }
                    .onChange(of: viewModel.selectedDate) { _, _ in
                        scheduleScrollToRelevantActivity(
                            proxy,
                            timelineItems: currentTimelineItems()
                        )
                    }
                    .onChange(of: selectedDayActivities.count) { _, _ in
                        scheduleScrollToRelevantActivity(
                            proxy,
                            timelineItems: currentTimelineItems()
                        )
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

    private func timelineFocusItemID(in timelineItems: [PlanTimelineItem]) -> String? {
        PlanTimelineEmphasisResolver.focusItemID(
            in: timelineItems,
            statusFor: { resolvedActivityStatus(for: $0) },
            selectedDay: viewModel.selectedDate
        )
    }

    private func timelineEmphasis(
        for item: PlanTimelineItem,
        status: PlanActivityStatus,
        timelineItems: [PlanTimelineItem],
        focusItemID: String?
    ) -> PlanTimelineVisualEmphasis {
        PlanTimelineEmphasisResolver.emphasis(
            for: item,
            status: status,
            focusItemID: focusItemID
        )
    }

    private func timelineNextEmphasis(
        at index: Int,
        in timelineItems: [PlanTimelineItem],
        focusItemID: String?
    ) -> PlanTimelineVisualEmphasis? {
        guard index + 1 < timelineItems.count else { return nil }

        let nextItem = timelineItems[index + 1]
        let nextStatus = resolvedActivityStatus(for: nextItem.representative)
        return timelineEmphasis(
            for: nextItem,
            status: nextStatus,
            timelineItems: timelineItems,
            focusItemID: focusItemID
        )
    }

    private func shouldShowTimelineNowDivider(
        at index: Int,
        in timelineItems: [PlanTimelineItem],
        focusItemID: String?
    ) -> Bool {
        PlanTimelineEmphasisResolver.shouldShowNowDivider(
            at: index,
            in: timelineItems,
            focusItemID: focusItemID,
            statusFor: { resolvedActivityStatus(for: $0) }
        )
    }

    private func timelineConnectorAbove(at index: Int, in timelineItems: [PlanTimelineItem]) -> CGFloat {
        guard index > 0 else { return 0 }

        let previous = timelineItems[index - 1]
        let current = timelineItems[index]
        let gapMinutes = current.firstDate.timeIntervalSince(previous.firstDate) / 60

        if gapMinutes >= 120 { return 10 }
        if gapMinutes >= 75 { return 6 }
        if gapMinutes >= 45 { return 4 }
        return 0
    }

    private func currentTimelineItems() -> [PlanTimelineItem] {
        let revision = PlannedActivityRefreshSignature.make(from: plannedActivities)
        return viewModel.timelineItems(from: plannedActivities, revision: revision)
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
    
    func scheduleScrollToRelevantActivity(
        _ proxy: ScrollViewProxy,
        timelineItems: [PlanTimelineItem],
        animated: Bool = true
    ) {
        Task { @MainActor in
            await Task.yield()
            guard tabIsActive else { return }
            scrollToRelevantActivity(proxy, timelineItems: timelineItems, animated: animated)
        }
    }

    func scrollToRelevantActivity(
        _ proxy: ScrollViewProxy,
        timelineItems: [PlanTimelineItem],
        animated: Bool = true
    ) {
        let anchor = UnitPoint(x: 0.5, y: 0.38)
        let focusItemID = timelineFocusItemID(in: timelineItems)
        let scrollAction = {
            if let focusID = focusItemID {
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

    private var customMeals: [Meals] {
        viewModel.customMeals
    }

    private var caloriesGoal: Double {
        nutritionViewModel.nutritionBudget.totalCalories > 0
            ? nutritionViewModel.nutritionBudget.totalCalories
            : 2761.0
    }
    private var proteinGoal: Double { nutritionViewModel.nutritionResult?.goals.protein ?? 153.0 }
    private var carbsGoal: Double { nutritionViewModel.nutritionResult?.goals.carbs ?? 330.0 }
    private var fatsGoal: Double { nutritionViewModel.nutritionResult?.goals.fats ?? 90.0 }
    private var fiberGoal: Double { nutritionViewModel.nutritionResult?.goals.fiber ?? 35.0 }
    private var waterGoal: Double { nutritionViewModel.nutritionResult?.goals.waterLiters ?? 4.46 }

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
        nutritionMeals(for: date).reduce(0.0) { total, activity in
            total + Double(PlannedActivityNutritionResolver.resolvedFiber(for: activity, in: customMeals))
        }
    }

    private func nutritionWater(for date: Date) -> Double {
        if calendar.isDateInToday(date),
           let waterLiters = nutritionViewModel.currentMetrics?.waterLiters {
            return waterLiters
        }

        let dayActivities = plannedActivities.filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }
        return QuickLogActivityPortions.totalWaterLiters(from: dayActivities)
    }

    private func matchingCustomMeal(for activity: PlannedActivity) -> Meals? {
        guard activity.type.lowercased() == "meal" else { return nil }

        let normalizedTitle = CustomMealStore.normalizedTitle(activity.title)
        guard !normalizedTitle.isEmpty else { return nil }

        return customMeals.first {
            CustomMealStore.normalizedTitle($0.title) == normalizedTitle
        }
    }

    func dayKind(for date: Date, activitiesRevision: String) -> PlanDayKind {
        viewModel.dayKind(for: date, plannedActivities: plannedActivities, revision: activitiesRevision)
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
        let now = Date()

        if item.isSkipped {
            return .skipped
        }

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

        if item.isActive(at: now) {
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
            weekNavigationButton(
                systemName: "chevron.left",
                accessibilityLabel: WeekFitLocalizedString("planner.week.previous")
            ) {
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

            weekNavigationButton(
                systemName: "chevron.right",
                accessibilityLabel: WeekFitLocalizedString("planner.week.next")
            ) {
                moveWeek(by: 1)
            }
        }
    }

    private func weekNavigationButton(
        systemName: String,
        accessibilityLabel: String,
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
        .accessibilityLabel(accessibilityLabel)
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

        let plannerLocalized = PlannerOptionLocalization.localizedTitle(for: trimmedTitle)
        if plannerLocalized != trimmedTitle {
            return plannerLocalized
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
