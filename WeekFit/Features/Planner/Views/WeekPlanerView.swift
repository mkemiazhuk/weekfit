import SwiftUI
import SwiftData
import HealthKit
import OSLog
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
    @Environment(\.weekFitPalette) private var palette

    private var canvasBackground: Color { palette.appScreenBackground }

    @ObservedObject private var userSettings = WeekFitUserSettings.shared

    @State private var showProfile = false
    @AppStorage(OnboardingStore.Keys.introPlan) private var planIntroDismissed = false
    
    @Environment(\.modelContext) private var modelContext

    @State private var selectedMeal: Meals?
    @State private var selectedFood: Meals?
    @State private var selectedLoggedActivity: PlannedActivity?
    @State private var showNutritionDetails = false
    @State private var nutritionDetailsDate = Date()
    @State private var selectedActivitySession: ActivitySessionSnapshot?

    private let sessionResolver = PlannedActivitySessionResolver()

    private let calendar = Calendar.current

    private var sessionDetailPrefetchKey: String {
        let day = Int(calendar.startOfDay(for: viewModel.selectedDate).timeIntervalSince1970)
        let workoutIDs = viewModel.selectedDayActivities(from: plannedActivities)
            .compactMap(\.healthKitWorkoutUUID)
            .sorted()
            .joined(separator: ",")
        return "\(day)|\(workoutIDs)"
    }
    
    @AppStorage(NotificationPreferenceKey.activityReminders)
    private var activityRemindersEnabled = false

    @AppStorage(NotificationPreferenceKey.completionCheckIns)
    private var completionCheckInsEnabled = false

    @AppStorage(CustomMealStore.storageKey)
    private var customMealsStorage = ""
    
    @State private var activityToConfirm: PlannedActivity?
    @State private var timelineItemPendingDelete: PlanTimelineItem?
    @State private var hasPerformedInitialScroll = false
    /// User override for Completed disclosure, keyed by day start.
    @State private var completedExpandedByDayStart: [TimeInterval: Bool] = [:]
    @State private var plannerVoiceEnabled = false
    @State private var showPlannerVoice = false


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
            WeekFitScreenContainer(headerBottomSpacing: 12) {
                WeekFitScreenHeader(
                    title: WeekFitLocalizedString("planner.week.title"),
                    subtitle: WeekFitLocalizedString("planner.week.subtitle"),
                    initials: userSettings.profileInitials,
                    hasProfileName: userSettings.hasProfileName,
                    showAvatar: true,
                    avatarProminence: .subdued,
                    trailing: {
                        if plannerVoiceEnabled {
                            plannerVoiceCallButton
                        }
                    },
                    onAvatarTap: { showProfile = true }
                )
            } content: {
                plannerContent(
                    activitiesRevision: activitiesRevision,
                    timelineItems: timelineItems,
                    selectedDayKind: selectedDayKind
                )
                // Rebind when Light/Dark / Night Comfort flips — Theme.* alone can
                // leave day-title ink stuck on the previous appearance.
                .id("\(palette.appearanceInvalidationToken)-\(languageManager.selectedLanguage.rawValue)")
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        // Exact Meals bottom fade: dissolve scrolling cards under the floating tab bar.
        .safeAreaInset(edge: .bottom) {
            planBottomFixedActionArea
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.plan")
        .id("planner-keepalive")
        .weekFitSettingsSheet(isPresented: $showProfile)
        .sheet(
            isPresented: $viewModel.showAddActivity,
            onDismiss: {
                viewModel.finishAddSheetDismiss()
            }
        ) {
            PlanAddActivitySheet(
                viewModel: viewModel,
                plannedActivities: plannedActivities,
                modelContext: modelContext,
                activityRemindersEnabled: activityRemindersEnabled,
                completionCheckInsEnabled: completionCheckInsEnabled
            )
            .environmentObject(languageManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(
                cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius,
                background: QuickActionSheetDesign.Color.sheetBackground(
                    for: viewModel.selectedType == .meal ? .food : .activity
                )
            )
        }
        .sheet(isPresented: $showPlannerVoice) {
            PlanRealtimeVoiceSheet(
                planningDay: viewModel.selectedDate,
                activities: plannedActivities,
                onSave: { request in
                    try viewModel.saveVoiceActivity(
                        request,
                        activities: plannedActivities,
                        modelContext: modelContext,
                        activityRemindersEnabled: activityRemindersEnabled,
                        completionCheckInsEnabled: completionCheckInsEnabled
                    )
                }
            )
            .environmentObject(languageManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .weekFitSheetChrome(
                cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius,
                background: QuickActionSheetDesign.Color.sheetBackground(for: .activity)
            )
        }
        .task { await refreshPlannerVoiceAccess() }
        .sheet(item: $selectedMeal) { meal in
            MealDetailsView(meal: meal)
                .environmentObject(languageManager)
                .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
        }
        .sheet(item: $selectedFood) { food in
            CustomFoodDetailsView(
                food: food,
                existingMeals: customMeals
            )
            .environmentObject(languageManager)
            .weekFitSheetChrome(
                cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius,
                background: QuickActionSheetDesign.Color.sheetBackground(for: .food)
            )
        }
        .sheet(item: $selectedLoggedActivity) { activity in
            LoggedMealDetailView(
                activity: activity,
                existingMeals: customMeals,
                onSavedToLibrary: { meal in
                    let updated = CustomMealStore.upsert(meal, into: userSettings.customMealsCatalog)
                    userSettings.replaceCustomMealsCatalog(updated)
                    viewModel.syncCustomMeals(
                        from: updated,
                        revision: userSettings.customMealsCatalogRevision
                    )
                }
            )
            .environmentObject(languageManager)
            .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
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
        .task(id: sessionDetailPrefetchKey) {
            let sessions = sessionResolver.snapshotsForDetailPrefetch(
                viewModel.selectedDayActivities(from: plannedActivities)
            )
            await ActivitySessionDetailPrefetcher.prefetch(
                sessions: sessions,
                healthManager: healthManager
            )
        }
        .onChange(of: activityCoordinator.liveWorkout?.id) { _, _ in
            activityCoordinator.reconcileLiveWorkout(
                with: Array(plannedActivities),
                modelContext: modelContext
            )
        }
        .onAppear {
            activityCoordinator.reconcileLiveWorkout(
                with: Array(plannedActivities),
                modelContext: modelContext
            )
        }
        .sheet(item: $activityToConfirm) { activity in
            plannerConfirmationSheet(activity)
                .presentationDetents([.fraction(0.40)])
                .presentationDragIndicator(.visible)
                .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
        }
        .overlay {
            if timelineItemPendingDelete != nil {
                ConfirmationDialogView(
                    icon: "trash.fill",
                    iconTint: Color(red: 255/255, green: 83/255, blue: 88/255),
                    title: WeekFitLocalizedString("planner.delete.title"),
                    message: deleteConfirmationMessage(for: timelineItemPendingDelete),
                    secondaryTitle: WeekFitLocalizedString("common.action.cancel"),
                    primaryTitle: WeekFitLocalizedString("planner.delete"),
                    isPrimaryDestructive: true,
                    onSecondary: {
                        timelineItemPendingDelete = nil
                    },
                    onPrimary: {
                        if let item = timelineItemPendingDelete {
                            performDeleteTimelineItem(item)
                        }
                        timelineItemPendingDelete = nil
                    }
                )
            }
        }
        .onAppear {
            viewModel.syncCustomMeals(
                from: userSettings.customMealsCatalog,
                revision: userSettings.customMealsCatalogRevision
            )
            openPendingPlanAddIfNeeded()
            #if DEBUG
            TabSwitchProfiler.markEvent(
                "WeekPlannerView.onAppear revisionBytes=\(activitiesRevision.count) timelineCount=\(timelineItems.count)"
            )
            PlannerBodyDiagnostics.reportMountCompleted()
            #endif
        }
        .onChange(of: tabIsActive) { _, active in
            guard active else { return }
            openPendingPlanAddIfNeeded()
        }
        .onChange(of: PendingPlanAddOpen.shared.shouldOpen) { _, shouldOpen in
            guard shouldOpen, tabIsActive else { return }
            openPendingPlanAddIfNeeded()
        }
        .onChange(of: userSettings.customMealsCatalogRevision) { _, revision in
            viewModel.syncCustomMeals(from: userSettings.customMealsCatalog, revision: revision)
        }
    }

    private func openPendingPlanAddIfNeeded() {
        guard PendingPlanAddOpen.shared.consume() else { return }
        viewModel.selectedDate = calendar.startOfDay(for: Date())
        viewModel.startAdding(at: Date(), history: plannedActivities)
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
        selectedDayCard(
            activitiesRevision: activitiesRevision,
            timelineItems: timelineItems,
            selectedDayKind: selectedDayKind
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var plannerVoiceCallButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showPlannerVoice = true
        } label: {
            Image(systemName: "phone.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.textPrimary.opacity(0.92))
                .frame(width: 40, height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(palette.cardSurface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(palette.textPrimary.opacity(palette.isLight ? 0.10 : 0.14), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WeekFitLocalizedString("planner.voice.talk"))
        .accessibilityIdentifier("planner.voice.talk")
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
                // If the session was started from Today with a placeholder duration (e.g. default 60m),
                // stamping actualDurationMinutes here ensures Plan uses the true elapsed time.
                if (liveActivity.actualDurationMinutes ?? 0) <= 0 {
                    let passedMinutes = max(1, Int(Date().timeIntervalSince(liveActivity.date) / 60))
                    liveActivity.actualDurationMinutes = passedMinutes
                }
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
            // Card tap always opens details; completion is handled by the checkbox.
            openTimelineActivity(activity)
        }
    }

    private func toggleTimelineItemCompletion(_ item: PlanTimelineItem) {
        guard case .single(let activity) = item else { return }
        guard case .interactive = PlanAgendaCompletionControl.control(
            for: item,
            status: resolvedActivityStatus(for: activity)
        ) else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        guard let liveActivity = try? PlannedActivityPersistenceService.fetchActivity(
            id: activity.id,
            in: modelContext
        ) else {
            return
        }

        // Finished activities cannot be unchecked from the row — only mark complete.
        guard !liveActivity.isCompleted else { return }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            if (liveActivity.actualDurationMinutes ?? 0) <= 0,
               liveActivity.date <= Date() {
                let passedMinutes = max(1, Int(Date().timeIntervalSince(liveActivity.date) / 60))
                liveActivity.actualDurationMinutes = passedMinutes
            }
            try? PlannedActivityNotificationConfirmationService.markCompleted(
                liveActivity,
                modelContext: modelContext
            )
            viewModel.markPlannerDataChanged()
        }
    }

    private func openTimelineActivity(_ activity: PlannedActivity) {
        if activity.timelineEventKind == .food {
            if PlanTimelineRouter.shouldOpenLoggedMealDetail(
                for: activity,
                customMeals: customMeals
            ) {
                selectedLoggedActivity = activity
                return
            }
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

        if PlanTimelineRouter.shouldOpenLoggedMealDetail(
            for: activity,
            customMeals: customMeals
        ) {
            selectedLoggedActivity = activity
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

// MARK: - Week Picker

private extension WeekPlannerLiveQueryView {

    @ViewBuilder
    func weekPickerCard(activitiesRevision: String) -> some View {
        // activitiesRevision kept for call-site stability with day-kind cache identity.
        PlanningWeekPicker(selectedDate: $viewModel.selectedDate)
            .planAgendaSectionSurface(compact: true)
            .accessibilityElement(children: .contain)
            .id(activitiesRevision.isEmpty ? "week" : "week.\(activitiesRevision.prefix(12))")
    }
}

// MARK: - Selected Day

private extension WeekPlannerLiveQueryView {

    @ViewBuilder
    func selectedDayCard(
        activitiesRevision: String,
        timelineItems: [PlanTimelineItem],
        selectedDayKind: PlanDayKind
    ) -> some View {
        let sections = PlanAgendaDaySections.make(
            from: timelineItems,
            selectedDate: viewModel.selectedDate,
            statusFor: { resolvedActivityStatus(for: $0) }
        )
        let dayKey = calendar.startOfDay(for: viewModel.selectedDate).timeIntervalSince1970
        let completedExpanded = isCompletedSectionExpanded(
            dayKey: dayKey,
            sections: sections
        )
        let canMutateDay = allowsAgendaMutation(for: viewModel.selectedDate)
        let showsAllDoneLine = sections.isFullyComplete
        let hasLiveSection = !sections.liveItems.isEmpty
        let hasUpcomingSection = !sections.primaryItems.isEmpty
        let dayIsEmpty = selectedDayActivities.isEmpty
        /// Add stays on Up next when that section exists; otherwise on Live, then Completed.
        let addOnLive = canMutateDay && hasLiveSection && !hasUpcomingSection
        let addOnCompleted = canMutateDay
            && !hasUpcomingSection
            && !hasLiveSection
            && !sections.completedItems.isEmpty

        VStack(alignment: .leading, spacing: 0) {
            // Fixed: calendar + day summary (+ compact all-done) while schedule scrolls.
            // Empty days skip the character card — one empty CTA is enough.
            VStack(alignment: .leading, spacing: 0) {
                weekPickerCard(activitiesRevision: activitiesRevision)
                    .padding(.bottom, PlanAgendaLayout.calendarToSummary)

                if dayIsEmpty {
                    Text(PlanAgendaDateCopy.dayContextLine(for: viewModel.selectedDate))
                        .font(WeekFitType.secondary.weight(.medium))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.bottom, PlanAgendaLayout.summaryToSchedule)
                } else {
                    PlanAgendaDaySummaryCard(
                        date: viewModel.selectedDate,
                        kind: selectedDayKind
                    )
                    .padding(
                        .bottom,
                        showsAllDoneLine
                            ? PlanAgendaLayout.summaryToAllDone
                            : PlanAgendaLayout.summaryToSchedule
                    )

                    if showsAllDoneLine {
                        PlanAgendaAllDoneLine()
                            .padding(.bottom, PlanAgendaLayout.summaryToSchedule)
                    }
                }
            }

            // Scrollable: Live / Up next / Earlier / Completed (and empty states).
            ScrollViewReader { proxy in
                List {
                    Color.clear
                        .frame(height: 1)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .id("plan.schedule.top")
                        .accessibilityHidden(true)

                    if dayIsEmpty {
                        Group {
                            if canMutateDay {
                                agendaEmptyDayBlock
                            } else {
                                agendaPastEmptyDayBlock
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        if hasLiveSection {
                            PlanAgendaSectionHeader(
                                title: WeekFitLocalizedString("planner.status.live"),
                                trailing: addOnLive ? AnyView(agendaAddTrailingButton) : nil,
                                showsLiveMark: true
                            )
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: 0,
                                bottom: PlanAgendaLayout.scheduleHeaderToEvents,
                                trailing: 0
                            ))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                            agendaEventRows(
                                items: sections.liveItems,
                                allTimelineItems: timelineItems,
                                allowsCompletionToggle: canMutateDay
                            )
                        }

                        if !sections.primaryItems.isEmpty {
                            agendaPrimaryHeader(
                                kind: sections.primaryKind,
                                showsAdd: canMutateDay
                            )
                            .listRowInsets(EdgeInsets(
                                top: hasLiveSection
                                    ? max(0, PlanAgendaLayout.summaryToSchedule - PlanTimelineLayout.rowSpacing)
                                    : 0,
                                leading: 0,
                                bottom: PlanAgendaLayout.scheduleHeaderToEvents,
                                trailing: 0
                            ))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .id("plan.schedule.header")

                            agendaEventRows(
                                items: sections.primaryItems,
                                allTimelineItems: timelineItems,
                                allowsCompletionToggle: canMutateDay
                            )
                        }

                        if !sections.earlierItems.isEmpty {
                            PlanAgendaSectionHeader(
                                title: WeekFitLocalizedString("planner.agenda.earlier")
                            )
                            .listRowInsets(EdgeInsets(
                                top: max(0, PlanAgendaLayout.summaryToSchedule - PlanTimelineLayout.rowSpacing),
                                leading: 0,
                                bottom: PlanAgendaLayout.scheduleHeaderToEvents,
                                trailing: 0
                            ))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                            agendaEventRows(
                                items: sections.earlierItems,
                                allTimelineItems: timelineItems,
                                allowsCompletionToggle: canMutateDay
                            )
                        }

                        if !sections.completedItems.isEmpty {
                            agendaCompletedHeader(
                                count: sections.completedItems.count,
                                isExpanded: completedExpanded,
                                dayKey: dayKey,
                                showsAdd: addOnCompleted
                            )
                            .listRowInsets(EdgeInsets(
                                top: hasUpcomingSection || hasLiveSection || !sections.earlierItems.isEmpty
                                    ? max(0, PlanAgendaLayout.summaryToSchedule - PlanTimelineLayout.rowSpacing)
                                    : 0,
                                leading: 0,
                                bottom: completedExpanded
                                    ? PlanAgendaLayout.scheduleHeaderToEvents
                                    : 8,
                                trailing: 0
                            ))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                            if completedExpanded {
                                agendaEventRows(
                                    items: sections.completedItems,
                                    allTimelineItems: timelineItems,
                                    allowsCompletionToggle: canMutateDay
                                )
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .weekFitTransparentScrollBackground(fillsCanvas: false)
                .scrollBounceBehavior(.basedOnSize)
                .environment(\.defaultMinListRowHeight, 1)
                .contentMargins(.bottom, 8, for: .scrollContent)
                .id(viewModel.selectedDate)
                .onAppear {
                    guard !hasPerformedInitialScroll else { return }
                    hasPerformedInitialScroll = true
                    scheduleScrollToScheduleTop(proxy, animated: false)
                }
                .onChange(of: viewModel.selectedDate) { _, _ in
                    scheduleScrollToScheduleTop(proxy, animated: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Today / future: plan can still be edited. Past days are read-only.
    private func allowsAgendaMutation(for date: Date) -> Bool {
        calendar.startOfDay(for: date) >= calendar.startOfDay(for: Date())
    }

    private func refreshPlannerVoiceAccess() async {
        do {
            let token = try await PhotoFoodFirebaseAuth.idToken()
            let access = try await PlanRealtimeClient(
                baseURL: WeekFitCloudAPI.foodPhotoBaseURL,
                token: token
            ).access()
            plannerVoiceEnabled = access.enabled
            #if DEBUG
            Logger(subsystem: "com.weekfit.app", category: "PlannerVoice")
                .info("accountId=\(access.accountId, privacy: .public) enabled=\(access.enabled, privacy: .public)")
            #endif
        } catch {
            plannerVoiceEnabled = false
        }
    }

    // MARK: - Bottom fade (identical to Meals)

    private var planBottomFixedActionArea: some View {
        planBottomFadeOnly
            // Shorter / softer than Meals so the last card (e.g. Sauna) stays readable
            // while still clearing the floating tab bar.
            .frame(height: WeekFitScreenLayout.tabBarClearance)
            .background {
                planBottomFadeGradient
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var planBottomFadeOnly: some View {
        Color.clear
    }

    private var planBottomFadeGradient: some View {
        LinearGradient(
            colors: [
                canvasBackground.opacity(0),
                canvasBackground.opacity(palette.isLight ? 0.28 : 0.24),
                canvasBackground.opacity(palette.isLight ? 0.72 : 0.68),
                canvasBackground.opacity(palette.isLight ? 0.92 : 0.90)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .id(palette.appearanceInvalidationToken)
    }

    private var agendaEmptyDayBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !planIntroDismissed {
                OnboardingContextualIntroCard(
                    title: WeekFitLocalizedString("onboarding.intro.plan.title"),
                    message: WeekFitLocalizedString("onboarding.intro.plan.body"),
                    accent: WeekFitTheme.primaryGreen
                ) {
                    planIntroDismissed = true
                }
                .padding(.bottom, 12)
            }

            emptySelectedDay
                .padding(.top, planIntroDismissed ? 8 : 0)
        }
    }

    private var agendaPastEmptyDayBlock: some View {
        Text(WeekFitLocalizedString("planner.agenda.pastEmpty"))
            .font(WeekFitType.secondary.weight(.medium))
            .foregroundStyle(palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .planAgendaSectionSurface()
            .accessibilityElement(children: .combine)
    }

    private func agendaPrimaryHeader(
        kind: PlanAgendaPrimarySectionKind,
        showsAdd: Bool
    ) -> some View {
        PlanAgendaSectionHeader(
            title: kind.title,
            trailing: showsAdd ? AnyView(agendaAddTrailingButton) : nil
        )
    }

    private func agendaCompletedHeader(
        count: Int,
        isExpanded: Bool,
        dayKey: TimeInterval,
        showsAdd: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    completedExpandedByDayStart[dayKey] = !isExpanded
                }
            } label: {
                HStack(spacing: 8) {
                    Text(
                        String(
                            format: WeekFitLocalizedString("planner.agenda.completedSectionFormat"),
                            Int64(count)
                        )
                    )
                    .font(WeekFitType.cardTitle)
                    .fontDesign(.rounded)
                    .foregroundStyle(palette.textPrimary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .frame(width: 28, height: PlanAgendaLayout.minHitSize)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                String(
                    format: WeekFitLocalizedString("planner.agenda.completedSectionFormat"),
                    Int64(count)
                )
            )
            .accessibilityValue(
                isExpanded
                    ? WeekFitLocalizedString("common.expanded")
                    : WeekFitLocalizedString("common.collapsed")
            )
            .accessibilityHint(WeekFitLocalizedString("planner.agenda.completedToggleHint"))

            if showsAdd {
                agendaAddTrailingButton
            }
        }
    }

    private var agendaAddTrailingButton: some View {
        Button {
            viewModel.startAdding(
                at: viewModel.nextAvailableSlot(from: plannedActivities),
                history: plannedActivities
            )
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text(WeekFitLocalizedString("planner.agenda.add"))
                    .font(WeekFitType.secondary.weight(.semibold))
                    .fontDesign(.rounded)
            }
            .foregroundStyle(WeekFitPlanChromeTokens.addForeground(isLight: palette.isLight))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(WeekFitPlanChromeTokens.addFill(isLight: palette.isLight))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(
                                WeekFitPlanChromeTokens.addStroke(isLight: palette.isLight),
                                lineWidth: palette.isLight ? 0.8 : 0
                            )
                    }
            }
            .frame(minWidth: PlanAgendaLayout.minHitSize, minHeight: PlanAgendaLayout.minHitSize)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WeekFitLocalizedString("planner.sheet.addTitle"))
    }

    private func isCompletedSectionExpanded(
        dayKey: TimeInterval,
        sections: PlanAgendaDaySections
    ) -> Bool {
        if let userChoice = completedExpandedByDayStart[dayKey] {
            return userChoice
        }
        // Default: expand when the day is fully done; otherwise keep Completed collapsed.
        return sections.isFullyComplete
    }

    @ViewBuilder
    private func agendaEventRows(
        items: [PlanTimelineItem],
        allTimelineItems: [PlanTimelineItem],
        allowsCompletionToggle: Bool
    ) -> some View {
        let focusItemID = timelineFocusItemID(in: allTimelineItems)
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            let activity = item.representative
            let status = resolvedActivityStatus(for: activity)
            let category = PlanTimelineCategory.from(activity: activity)
            let emphasis = timelineEmphasis(
                for: item,
                status: status,
                timelineItems: allTimelineItems,
                focusItemID: focusItemID
            )
            let globalIndex = allTimelineItems.firstIndex(where: { $0.id == item.id }) ?? index
            let baseControl = PlanAgendaCompletionControl.control(for: item, status: status)
            let completionControl: PlanAgendaCompletionControl = {
                guard allowsCompletionToggle else {
                    // Past days: status only, never an interactive checkbox.
                    switch baseControl {
                    case .interactive(let isCompleted):
                        return isCompleted ? .informational(isCompleted: true) : .none
                    case .informational, .none:
                        return baseControl
                    }
                }
                return baseControl
            }()

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
                    at: globalIndex,
                    in: allTimelineItems,
                    focusItemID: focusItemID
                ),
                isFirst: index == 0,
                isLast: index == items.count - 1,
                connectorAbove: 0,
                density: PlanTimelineMetadataBuilder.density(for: item),
                showsTimeLabel: true,
                completionControl: completionControl,
                onToggleCompletion: allowsCompletionToggle
                    ? { toggleTimelineItemCompletion(item) }
                    : nil
            )
            .contentShape(Rectangle())
            .onTapGesture {
                openTimelineItem(item)
            }
            .id(item.id)
            .contextMenu {
                if allowsCompletionToggle {
                    timelineItemContextMenu(for: item, status: status)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if allowsCompletionToggle,
                   case .single(let activity) = item,
                   status == .pending {
                    Button {
                        presentActivityConfirmation(for: activity)
                    } label: {
                        Label(AppText.Common.Action.done, systemImage: "checkmark.circle.fill")
                    }
                    .tint(Color(hex: "#FFB457"))
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if allowsCompletionToggle {
                    Button(role: .destructive) {
                        deleteTimelineItem(item)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(Color.red.opacity(0.68))
                }
            }
            .listRowInsets(
                EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: PlanTimelineLayout.rowSpacing,
                    trailing: 0
                )
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    func resolvedActivityStatus(for item: PlannedActivity) -> PlanActivityStatus {
        activityCoordinator.resolvedStatus(
            for: item,
            among: selectedDayActivities,
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
            let slot = viewModel.nextAvailableSlot(from: selectedDayActivities)
            viewModel.startAdding(at: slot, history: plannedActivities)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            palette.isLight
                                ? WeekFitPlanChromeTokens.calendarSelectedFill
                                : WeekFitTheme.brandGold.opacity(0.18)
                        )
                        .frame(
                            width: PlanAgendaLayout.summaryIconSize,
                            height: PlanAgendaLayout.summaryIconSize
                        )

                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            palette.isLight
                                ? WeekFitPlanChromeTokens.recoveryIcon
                                : WeekFitTheme.brandGold.opacity(0.90)
                        )
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(WeekFitLocalizedString("planner.empty.title"))
                            .font(WeekFitType.body.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(palette.textPrimary)

                        Text(WeekFitLocalizedString("planner.empty.message"))
                            .font(WeekFitType.secondary)
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text(WeekFitLocalizedString("planner.agenda.add"))
                            .font(WeekFitType.secondary.weight(.semibold))
                            .fontDesign(.rounded)
                    }
                    .foregroundStyle(WeekFitPlanChromeTokens.addForeground(isLight: palette.isLight))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        Capsule(style: .continuous)
                            .fill(WeekFitPlanChromeTokens.addFill(isLight: palette.isLight))
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        WeekFitPlanChromeTokens.addStroke(isLight: palette.isLight),
                                        lineWidth: palette.isLight ? 0.8 : 0
                                    )
                            }
                    }
                    .frame(minWidth: PlanAgendaLayout.minHitSize, minHeight: PlanAgendaLayout.minHitSize)
                    .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .planAgendaSectionSurface()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(WeekFitLocalizedString("planner.sheet.addTitle"))
        .accessibilityHint(WeekFitLocalizedString("planner.empty.accessibilityHint"))
    }
}

// MARK: - Timeline Scroll

private extension WeekPlannerLiveQueryView {
    
    func scheduleScrollToScheduleTop(
        _ proxy: ScrollViewProxy,
        animated: Bool = true
    ) {
        Task { @MainActor in
            await Task.yield()
            guard tabIsActive else { return }
            let scrollAction = {
                // Calendar + day summary are fixed; reset only the schedule list.
                proxy.scrollTo("plan.schedule.top", anchor: .top)
            }
            if animated {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.90)) {
                    scrollAction()
                }
            } else {
                scrollAction()
            }
        }
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
                    && ($0.type.lowercased() == "meal" || $0.type.lowercased() == "drink" || $0.type.lowercased() == "snack")
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
        let type = activity.type.lowercased()
        guard type == "meal" || type == "snack" || activity.timelineEventKind == .food else {
            return nil
        }

        if let libraryId = activity.libraryMealId?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !libraryId.isEmpty {
            return customMeals.first { $0.id == libraryId }
        }

        let hasSnapshot = !(activity.nutritionSnapshotJSON ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        if hasSnapshot {
            return nil
        }

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

        HStack(spacing: 10) {
            if counts.workouts > 0 {
                PlanDayStatChip(
                    icon: "figure.mixed.cardio",
                    count: counts.workouts,
                    tint: WeekFitTheme.workout
                )
            }

            if counts.meals > 0 {
                PlanDayStatChip(
                    icon: "fork.knife",
                    count: counts.meals,
                    tint: WeekFitProgressRingColor.nutrition
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

            coachAppliedDayChip
        }
        .lineLimit(1)
        .minimumScaleFactor(0.9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(selectedDaySubtitle)
    }

    @ViewBuilder
    private var coachAppliedDayChip: some View {
        let count = coachAdjustedActiveCount
        if count > 0 {
            PlanDayStatChip(
                icon: "sparkles",
                count: count,
                tint: WeekFitTheme.coachAccent
            )
            .accessibilityLabel(
                WeekFitLocalizedQuantityFormat("planner.coachAdjusted", count: count)
            )
        }
    }

    private var coachAdjustedActiveCount: Int {
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: viewModel.selectedDate)
        return CoachAdjustmentProvenanceStore.adjustments(forDayKey: dayKey)
            .filter { !$0.userManuallyEditedAfterApply }
            .count
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

        let coachCount = coachAdjustedActiveCount
        if coachCount > 0 {
            parts.append(
                WeekFitLocalizedQuantityFormat("planner.coachAdjusted", count: coachCount)
            )
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
            || type == "drink"
            || title.contains("water")
            || title.contains("hydration")
            || (title.contains("drink") && type != "meal" && type != "snack") {
            return Color(red: 0.25, green: 0.55, blue: 0.95)
        }

        switch type {
        case "workout":
            return Color(red: 0.46, green: 0.72, blue: 0.82)
        case "recovery":
            return Color(red: 0.66, green: 0.58, blue: 0.86)
        case "meal", "snack", "food", "nutrition":
            return WeekFitProgressRingColor.nutrition
        case "habit":
            return Color(red: 0.82, green: 0.60, blue: 0.36)
        default:
            if item.timelineEventKind == .food {
                return WeekFitProgressRingColor.nutrition
            }
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

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(WeekFitType.captionEmphasized)
                .foregroundStyle(tint.opacity(0.88))

            Text("\(count)")
                .font(WeekFitType.secondary.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(palette.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5.5)
        .background {
            Capsule()
                .fill(tint.opacity(0.09))
        }
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.14), lineWidth: 0.7)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// Calm gold circular + for the Plan schedule header.
private struct PlanAgendaAddButtonStyle: ButtonStyle {
    @Environment(\.weekFitPalette) private var palette

    private let controlSize: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        PlanAgendaAddButtonLabel(
            configuration: configuration,
            palette: palette,
            controlSize: controlSize
        )
    }
}

private struct PlanAgendaAddButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    let palette: WeekFitSemanticPalette
    let controlSize: CGFloat

    @State private var didFirePressHaptic = false

    private var isPressed: Bool { configuration.isPressed }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .overlay {
                    if !palette.isLight {
                        Circle()
                            .strokeBorder(
                                WeekFitTheme.brandGold.opacity(isPressed ? 0.48 : 0.34),
                                lineWidth: 0.9
                            )
                    }
                }

            configuration.label
                .foregroundStyle(iconColor)
        }
        .frame(width: controlSize, height: controlSize)
        .frame(minWidth: PlanAgendaLayout.minHitSize, minHeight: PlanAgendaLayout.minHitSize)
        .contentShape(Circle())
        .scaleEffect(isPressed ? 0.94 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.76), value: isPressed)
        .onChange(of: isPressed) { _, pressed in
            if pressed {
                guard !didFirePressHaptic else { return }
                didFirePressHaptic = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                didFirePressHaptic = false
            }
        }
    }

    private var fillColor: Color {
        if palette.isLight {
            return WeekFitPlanChromeTokens.addFill.opacity(isPressed ? 0.82 : 1)
        }
        return WeekFitTheme.brandGold.opacity(isPressed ? 0.34 : 0.20)
    }

    private var iconColor: Color {
        WeekFitPlanChromeTokens.addForeground(isLight: palette.isLight)
    }
}

private struct PlanTimelineRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private struct PlanningWeekPicker: View {
    @Binding var selectedDate: Date

    @EnvironmentObject private var languageManager: AppLanguageManager
    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = WeekFitCurrentLocale()
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

    private var usesScrollableDays: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        let _ = languageManager.selectedLanguage
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 4) {
                Text(PlanAgendaDateCopy.monthYear(for: selectedDate))
                    .font(.system(size: PlanAgendaLayout.monthTitleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                weekNavigationButton(
                    systemName: "chevron.left",
                    accessibilityLabel: WeekFitLocalizedString("planner.week.previous")
                ) {
                    moveWeek(by: -1)
                }

                weekNavigationButton(
                    systemName: "chevron.right",
                    accessibilityLabel: WeekFitLocalizedString("planner.week.next")
                ) {
                    moveWeek(by: 1)
                }
            }

            dayStrip
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onEnded { value in
                            guard abs(value.translation.width) > 34 else { return }
                            moveWeek(by: value.translation.width < 0 ? 1 : -1)
                        }
                )
        }
    }

    @ViewBuilder
    private var dayStrip: some View {
        if usesScrollableDays {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(weekDays, id: \.self) { date in
                            dayButton(for: date)
                                .id(date)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    proxy.scrollTo(calendar.startOfDay(for: selectedDate), anchor: .center)
                }
                .onChange(of: selectedDate) { _, date in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        proxy.scrollTo(calendar.startOfDay(for: date), anchor: .center)
                    }
                }
            }
        } else {
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { date in
                    dayButton(for: date)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func dayButton(for date: Date) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                selectedDate = date
            }
        } label: {
            DynamicDayCapsule(
                date: date,
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                isToday: calendar.isDateInToday(date)
            )
        }
        .buttonStyle(.plain)
        .frame(minHeight: PlanAgendaLayout.minHitSize)
    }

    private func weekNavigationButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.textSecondary.opacity(0.85))
                .frame(width: PlanAgendaLayout.minHitSize, height: PlanAgendaLayout.minHitSize)
                .contentShape(Rectangle())
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
    let isSelected: Bool
    let isToday: Bool

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(spacing: 2) {
            Text(dayLabel)
                .font(WeekFitType.caption)
                .fontDesign(.rounded)
                .lineLimit(1)
                .foregroundStyle(dayLabelColor)

            Text(dayNumber)
                .font(
                    isSelected
                        ? WeekFitType.body.weight(.semibold)
                        : WeekFitType.body.weight(.medium)
                )
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(dayNumberColor)

            ZStack {
                Circle()
                    .fill(
                        WeekFitPlanChromeTokens.calendarDot(
                            isLight: palette.isLight,
                            isSelected: isSelected,
                            isToday: isToday
                        )
                    )
                    .frame(width: 4, height: 4)
                    .opacity(isToday || isSelected ? 1 : 0)
            }
            .frame(height: 5)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
        .frame(minWidth: PlanAgendaLayout.minHitSize, minHeight: PlanAgendaLayout.minHitSize)
        .background {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(selectedCapsuleFill)
            } else if isToday && palette.isLight {
                // Today (unselected): hairline so it stays distinct from selected lavender.
                Capsule(style: .continuous)
                    .strokeBorder(
                        WeekFitPlanChromeTokens.calendarSelectedDot.opacity(0.28),
                        lineWidth: 1
                    )
            }
        }
        .contentShape(Rectangle())
        .accessibilityLabel(accessibilityDayLabel)
        .accessibilityAddTraits(accessibilityTraits)
    }

    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = []
        if isSelected { traits.insert(.isSelected) }
        return traits
    }

    /// Soft lavender wash in Light; legacy gold wash in Dark.
    private var selectedCapsuleFill: Color {
        WeekFitPlanChromeTokens.calendarSelectedFill(isLight: palette.isLight)
    }

    private var dayLabelColor: Color {
        if isSelected {
            return palette.textSecondary
        }
        if isToday {
            return palette.textSecondary
        }
        return palette.textTertiary
    }

    private var dayNumberColor: Color {
        if isSelected {
            return palette.textPrimary
        }
        if isToday {
            return palette.textPrimary
        }
        return palette.textPrimary.opacity(0.88)
    }

    private var dayLabel: String {
        weekFitDateFormatter(template: "EEEEE").string(from: date)
    }

    private var dayNumber: String {
        weekFitDateFormatter(template: "d").string(from: date)
    }

    private var accessibilityDayLabel: String {
        var label = weekFitDateFormatter(template: "EEEE d MMMM").string(from: date)
        if isToday {
            label += ", " + WeekFitLocalizedString("planner.sheet.todayLabel")
        }
        if isSelected {
            label += ", " + WeekFitLocalizedString("common.selected")
        }
        return label
    }

    private func weekFitDateFormatter(template: String) -> DateFormatter {
        let locale = WeekFitCurrentLocale()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
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

    /// Calm green for completed / done glyphs (not brand gold).
    static func calmCompleted(isLight: Bool) -> Color {
        WeekFitPlanChromeTokens.completed(isLight: isLight)
    }

    /// Soft rose for skipped — readable, not alarm-red.
    static func calmSkipped(isLight: Bool) -> Color {
        isLight
            ? WeekFitLightTokens.critical
            : Color(red: 0.82, green: 0.50, blue: 0.48) // #D1807A
    }

    /// How a finished row got done — planned check-off vs log vs Watch sync.
    enum CompletionProvenance: Equatable {
        case done
        case logged
        case synced

        var title: String {
            switch self {
            case .done: return WeekFitLocalizedString("planner.status.completed")
            case .logged: return WeekFitLocalizedString("planner.status.logged")
            case .synced: return WeekFitLocalizedString("planner.status.synced")
            }
        }

        static func resolve(
            activity: PlannedActivity,
            status: PlanActivityStatus
        ) -> CompletionProvenance? {
            switch status {
            case .completed:
                return .done
            case .logged:
                let source = activity.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let syncedSources: Set<String> = ["appleworkout", "applewatch", "healthkit"]
                if activity.isWatchSynced || syncedSources.contains(source) {
                    return .synced
                }
                return .logged
            default:
                return nil
            }
        }
    }

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
        case .skipped: return Color(red: 0.82, green: 0.50, blue: 0.48)
        case .completed: return PlanActivityStatus.calmCompleted(isLight: WeekFitPaletteStore.current.isLight)
        case .logged: return WeekFitPlanChromeTokens.loggedBadgeInk(isLight: WeekFitPaletteStore.current.isLight)
        }
    }
}

// MARK: - Background

private enum PlanScreenSurface {
    @MainActor
    static var cardFill: Color {
        WeekFitPaletteStore.current.isLight
            ? WeekFitTheme.cardSurface
            : Color(red: 0.042, green: 0.040, blue: 0.038)
    }

    @MainActor
    static var cardStroke: Color { WeekFitTheme.borderSoft }

    @MainActor
    static var capsuleFill: Color {
        WeekFitPaletteStore.current.isLight
            ? WeekFitTheme.cardSurfaceWarm
            : Color(red: 0.052, green: 0.050, blue: 0.046)
    }

    @MainActor
    static var capsuleSelectedFill: Color {
        WeekFitPaletteStore.current.isLight
            ? WeekFitTheme.cardSurfaceElevated
            : Color(red: 0.068, green: 0.064, blue: 0.058)
    }
}

private extension WeekPlannerLiveQueryView {

    var cardBackground: some View {
        Color.clear
            .weekFitPrimaryCard()
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
            if isWaterDrinkTitle(normalizedTitle, imageName: activity.imageName) {
                return WeekFitLocalizedString("planner.timeline.water")
            }

            // Prefer the exact drink name (Coffee, Tea, …) over a generic "Drink" label.
            if !trimmedTitle.isEmpty, normalizedTitle != "drink" {
                return resolvedActivityDisplayTitle(trimmedTitle)
            }

            return WeekFitLocalizedString("planner.timeline.drink")
        }

        if type == "meal" && (trimmedTitle.isEmpty || normalizedTitle == "meal") {
            return WeekFitLocalizedString("planner.timeline.meal")
        }

        if normalizedTitle == "water" {
            return WeekFitLocalizedString("planner.timeline.water")
        }

        if let meal = matchingCustomMeal(for: activity) {
            return meal.localizedDisplayTitle
        }

        return resolvedActivityDisplayTitle(trimmedTitle)
    }

    private func isWaterDrinkTitle(_ normalizedTitle: String, imageName: String) -> Bool {
        if imageName.lowercased() == "hydration" { return true }
        return normalizedTitle.contains("water") || normalizedTitle.contains("hydration")
    }

    private func resolvedActivityDisplayTitle(_ trimmedTitle: String) -> String {
        guard !trimmedTitle.isEmpty else { return trimmedTitle }

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
    /// Semantic day accents — Recovery lavender, Activity green; open stays neutral.
    var color: Color {
        switch self {
        case .endurance, .load, .mixed:
            return WeekFitSemanticMetricTokens.activity
        case .recovery:
            return WeekFitSemanticMetricTokens.recovery
        case .open:
            return WeekFitPaletteStore.current.isLight
                ? WeekFitLightTokens.textTertiary
                : .white.opacity(0.24)
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
