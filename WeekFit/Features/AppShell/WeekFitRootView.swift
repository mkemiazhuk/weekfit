import SwiftUI
import SwiftData
import WeekFitPlanner

private struct CoachRefreshInputs: Equatable {
    var languageCode: String
    var healthRefreshToken: UUID
    var returnToTodayToken: UUID
    var coachRefreshToken: UUID
    var hasSettledInitialHealthState: Bool
    var coachDayStart: Int
    var plannedActivitiesSignature: String

    static let empty = CoachRefreshInputs(
        languageCode: "",
        healthRefreshToken: UUID(),
        returnToTodayToken: UUID(),
        coachRefreshToken: UUID(),
        hasSettledInitialHealthState: false,
        coachDayStart: 0,
        plannedActivitiesSignature: ""
    )
}

struct WeekFitRootView: View {

    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var activityCoordinator: WeekFitActivityCoordinator
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var languageManager: AppLanguageManager
    @EnvironmentObject private var reviewManager: ReviewPromptManager

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.weekFitPalette) private var palette

    @StateObject private var planViewModel = PlanViewModel()
    @StateObject private var coachInputProvider = CoachInputProvider()
    @State private var selectedTab: WeekFitTab = .today
    @State private var todaySelectedDate = Date()
    @State private var todayResetTrigger = UUID()
    @State private var showContent = false
    @State private var mountedTabs: Set<WeekFitTab> = [.today]
    @State private var coachRefreshInputs = CoachRefreshInputs.empty
    @State private var coachTabRefreshTask: Task<Void, Never>?
    @State private var healthRefreshEventTask: Task<Void, Never>?
    @State private var tabSwitchGeneration = 0
    @State private var trackedAppDayStart: Date?
    /// Last `healthRefreshTrigger` token applied to a HealthKit reload.
    /// Tab activation alone must not reload until this matches or data goes stale.
    @State private var acknowledgedHealthRefreshToken: UUID?
    @State private var cachedPlannedActivitiesSignature = ""

    /// Joins overlapping workout reconcile requests (appear + onChange can race).
    private static var reconcileInFlight: Task<Void, Never>?

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    var body: some View {
        rootShellWithHealthHandlers
            .environmentObject(authViewModel)
            .weekFitReviewPromptHost(manager: reviewManager)
    }

    private var rootShellWithHealthHandlers: some View {
        rootShellWithCoreHandlers
            .onChange(of: healthManager.recoveryPercent) { _, _ in
                syncNotifications(source: "root.recoveryPercent", includeActivities: false)
            }
            .onChange(of: healthManager.lastHealthKitSyncTime) { _, _ in
                syncCoachRefreshInputs()
            }
            .onChange(of: healthManager.settledMetricsDayStart) { _, _ in
                syncCoachRefreshInputs()
                evaluateMorningProposalFromRoot(source: "root.settledMetrics")
            }
            .onChange(of: healthManager.hasCompletedHealthAccessCheck) { _, _ in
                syncCoachRefreshInputs()
            }
            .onChange(of: healthManager.isHealthAccessGranted) { _, _ in
                syncCoachRefreshInputs()
            }
            .task(id: coachRefreshInputs) {
                let taskName = "root.refreshCoachInput"
                StartupDiagnostics.taskBegin(
                    taskName,
                    detail: "tab=\(String(describing: selectedTab)) settled=\(hasSettledInitialHealthState)"
                )
                await refreshCoachInput(source: "rootTask")
                if Task.isCancelled {
                    StartupDiagnostics.taskCancelled(taskName)
                } else {
                    StartupDiagnostics.taskSuccess(
                        taskName,
                        detail: "coachState=\(coachCoordinator.state.statusLogLabel)"
                    )
                }
            }
            .task(id: plannedActivitiesIconRepairKey) {
                let taskName = "root.repairPlannedActivityIcons"
                StartupDiagnostics.taskBegin(taskName, detail: plannedActivitiesIconRepairKey)
                repairPlannedActivityIconsIfNeeded()
                if Task.isCancelled {
                    StartupDiagnostics.taskCancelled(taskName)
                } else {
                    StartupDiagnostics.taskSuccess(taskName)
                }
            }
    }

    private var plannedActivitiesIconRepairKey: String {
        "\(plannedActivities.count)|\(cachedPlannedActivitiesSignature)"
    }

    private func repairPlannedActivityIconsIfNeeded() {
        let repaired = WeekFitActivityIconRepair.repairIcons(in: Array(plannedActivities))
        guard repaired > 0 else { return }
        do {
            try modelContext.save()
        } catch {
            // Non-fatal — display still uses preferred icons via the resolver.
        }
    }

    private var rootShellWithCoreHandlers: some View {
        rootShellWithNotificationHandlers
            .task(id: trackedAppDayStart) {
                await scheduleNextCalendarDayCheck()
            }
            .task(id: coachCoordinator.nextScheduledCheckpoint) {
                await handleCoachCheckpointIfNeeded()
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                mountedTabs.insert(newValue)
                handleTabChange(from: oldValue, to: newValue)
            }
            .onChange(of: appSession.returnToTodayTrigger) { _, _ in
                syncCoachRefreshInputs()
                returnToToday()
            }
            .onChange(of: activityCoordinator.completedWorkoutsBatch) { _, _ in
                Task {
                    await reconcileHealthWorkouts(source: "root.onChange.completedWorkoutsBatch")
                }
            }
            .onChange(of: watchSyncPlannerSignature) { _, _ in
                Task {
                    await reconcileHealthWorkouts(source: "root.onChange.plannedActivities")
                }
            }
            .onChange(of: languageManager.selectedLanguage) { _, language in
                coachInputProvider.invalidateCompletedRefreshCache()
                coachCoordinator.forceRecomputeForLanguageChange(
                    reason: "languageChange.root.\(language.rawValue)"
                )
                syncCoachRefreshInputs()
            }
            .onChange(of: appSession.healthRefreshTrigger) { _, _ in
                syncCoachRefreshInputs()
                handleHealthRefreshEvent()
            }
            .onChange(of: appSession.coachRefreshTrigger) { _, _ in
                syncCoachRefreshInputs()
            }
            .onChange(of: todaySelectedDate) { _, _ in
                syncCoachRefreshInputs()
            }
            .onChange(of: plannedActivities) { _, newActivities in
                refreshPlannedActivitiesSignature(warmPlannerCaches: mountedTabs.contains(.calendar))
                syncNotifications(source: "root.plannedActivities", includeActivities: true, includeWellness: true)
                // Today can be Equatable-frozen while Meals/Planner is active; reconcile
                // nutrition here so meal add/delete still updates consumed %.
                let selectedDate = todaySelectedDate
                let dayActivities = DailyStateSnapshotBuilder.activities(
                    on: selectedDate,
                    from: newActivities
                )
                Task { @MainActor in
                    await healthManager.loadNutritionMetrics(
                        for: selectedDate,
                        plannedActivities: dayActivities
                    )
                    coachInputProvider.refreshFromCurrentState(
                        selectedDate: selectedDate,
                        dayActivities: dayActivities,
                        allPlannedActivities: newActivities,
                        healthManager: healthManager,
                        nutritionViewModel: nutritionViewModel,
                        coachCoordinator: coachCoordinator,
                        source: "root.plannedActivitiesChanged"
                    )
                }
            }
    }

    private var rootShellWithNotificationHandlers: some View {
        rootShell
            .fullScreenCover(isPresented: $appSession.isPresentingOnboarding) {
                FirstRunOnboardingView()
                    .environmentObject(appSession)
                    .environmentObject(healthManager)
                    .environmentObject(languageManager)
            }
            .fullScreenCover(isPresented: $appSession.isPresentingHealthAccess) {
                NavigationStack {
                    HealthAccessView()
                }
                .environmentObject(healthManager)
            }
            .onAppear(perform: handleRootAppear)
            .onChange(of: appSession.pendingRootTab) { _, tab in
                guard tab != nil, let destination = appSession.consumePendingRootTab() else { return }
                selectTab(destination)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                reconcileAppCalendarDay(source: "root.sceneActive", returnToToday: false)
                syncNotifications(source: "root.sceneActive")
                evaluateMorningProposalFromRoot(source: "root.sceneActive")
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .activityNotificationAction),
                perform: handleActivityNotificationAction
            )
            .onReceive(
                NotificationCenter.default.publisher(for: .morningProposalNotificationAction)
            ) { _ in
                returnToToday()
            }
            .onChange(of: PendingMorningProposalReview.shared.shouldOpenReview) { _, shouldOpen in
                guard shouldOpen else { return }
                returnToToday()
            }
    }

    private var rootShell: some View {
        ZStack(alignment: .bottom) {
            palette.appScreenBackground
                .ignoresSafeArea()
            ambientBackground
                .ignoresSafeArea()

            selectedContent
                .animation(nil, value: selectedTab)

            WeekFitBottomBar(selectedTab: $selectedTab)
                .padding(.horizontal, 1)
                .background(alignment: .top) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    WeekFitTheme.whiteOpacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1)
                        .offset(y: -7)
                }
                .shadow(
                    color: palette.isLight
                        ? Color.clear
                        : Color.black.opacity(0.4),
                    radius: palette.isLight ? 0 : 25,
                    y: palette.isLight ? 0 : -10
                )
                .id(palette.appearanceInvalidationToken)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 120)
        }
    }

    private func handleRootAppear() {
        StartupHangDetector.armForColdLaunch()
        StartupDiagnostics.step(
            11,
            "root appear — Today tab mounting",
            detail: "mode=\(String(describing: AccountSessionController.shared.mode)) planned=\(plannedActivities.count)"
        )
        withAnimation(.spring(response: 0.62, dampingFraction: 0.88)) {
            showContent = true
        }
        ProductAnalytics.trackTab(selectedTab)
        planViewModel.beforePlannedActivityDeleted = {
            CoachStateStabilizer.markRealityChange(source: "plannerActivityDelete")
            CoachSnapshotInvalidator.invalidate(
                coordinator: coachCoordinator,
                nutritionViewModel: nutritionViewModel,
                inputProvider: coachInputProvider,
                reason: "plannerActivityDelete"
            )
        }
        planViewModel.afterPlannedActivityDeleted = {
            appSession.triggerCoachRefresh(source: "plannerActivityDelete")
        }
        StartupDiagnostics.step(17, "plan load begin", detail: "signature refresh + notification sync")
        refreshPlannedActivitiesSignature()
        StartupDiagnostics.step(
            18,
            "plan load complete",
            detail: "planned=\(plannedActivities.count) signatureLen=\(cachedPlannedActivitiesSignature.count)"
        )
        syncNotifications(source: "root.onAppear")
        reconcileAppCalendarDay(source: "root.onAppear", returnToToday: false)
        Task {
            let taskName = "root.reconcileHealthWorkouts.bootstrap"
            StartupDiagnostics.taskBegin(taskName, detail: "source=root.onAppear")
            if AccountSessionController.shared.mode != .reviewDemo {
                await reconcileHealthWorkouts(
                    source: "root.onAppear",
                    bootstrapFromHealth: true
                )
            }
            if Task.isCancelled {
                StartupDiagnostics.taskCancelled(taskName)
            } else {
                StartupDiagnostics.taskSuccess(
                    taskName,
                    detail: "batch=\(activityCoordinator.completedWorkoutsBatch.count)"
                )
            }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        ZStack {
            if mountedTabs.contains(.today) {
                WeekFitMountedTabLayers.today(
                    isActive: selectedTab == .today,
                    appearanceInvalidationToken: palette.appearanceInvalidationToken,
                    returnToTodayTrigger: todayResetTrigger,
                    nutritionRevision: nutritionViewModel.coachStateRefreshID,
                    plannedActivitiesRevision: cachedPlannedActivitiesSignature,
                    authViewModel: authViewModel,
                    selectedDate: $todaySelectedDate,
                    onSelectTab: selectTab,
                    coachInputProvider: coachInputProvider
                )
            }

            if mountedTabs.contains(.coach) {
                WeekFitMountedTabLayers.coach(
                    isActive: selectedTab == .coach,
                    appearanceInvalidationToken: palette.appearanceInvalidationToken,
                    coachStateID: coachCoordinator.state.id,
                    authViewModel: authViewModel,
                    coachInputProvider: coachInputProvider
                )
            }

            if mountedTabs.contains(.meals) {
                WeekFitMountedTabLayers.meals(
                    isActive: selectedTab == .meals,
                    appearanceInvalidationToken: palette.appearanceInvalidationToken,
                    nutritionRevision: nutritionViewModel.coachStateRefreshID,
                    nutritionResult: nutritionViewModel.nutritionResult,
                    authViewModel: authViewModel
                )
            }

            if mountedTabs.contains(.calendar) {
                WeekFitMountedTabLayers.calendar(
                    isActive: selectedTab == .calendar,
                    plannedActivitiesRevision: cachedPlannedActivitiesSignature,
                    viewModel: planViewModel,
                    authViewModel: authViewModel
                )
            }
        }
    }

    @ViewBuilder
    private var ambientBackground: some View {
        ZStack {
            WeekFitTheme.todayAmbient
                .opacity(selectedTab == .today && !TodayAtmospherePolicy.isEnabled ? palette.ambientOpacity : 0)
            WeekFitTheme.coachAmbient
                .opacity(selectedTab == .coach ? palette.ambientOpacity : 0)
            WeekFitTheme.mealsAmbient
                .opacity(selectedTab == .meals ? palette.ambientOpacity : 0)
            WeekFitTheme.planAmbient
                .opacity(selectedTab == .calendar ? palette.ambientOpacity : 0)
        }
        .animation(nil, value: selectedTab)
    }

    private func selectTab(_ tab: WeekFitTab) {
        guard selectedTab != tab else { return }

        if tab == .calendar {
            resetPlanDateToToday()
        }

        withAnimation(
            .spring(
                response: 0.36,
                dampingFraction: 0.82,
                blendDuration: 0.08
            )
        ) {
            selectedTab = tab
        }
    }

    private func handleTabChange(from oldValue: WeekFitTab, to newValue: WeekFitTab) {
        #if DEBUG
        TabSwitchDiagnostics.markSwitchCommitted()
        #endif

        ProductAnalytics.trackTab(newValue)

        if newValue == .calendar || oldValue == .meals {
            MealPhotoStore.releaseMemoryCache()
            #if DEBUG
            TabSwitchProfiler.markEvent("MealPhotoStore.releaseMemoryCache tab=\(oldValue)->\(newValue)")
            #endif
        }

        let handlerStart = CFAbsoluteTimeGetCurrent()
        let recomputeBefore = coachCoordinator.recomputeCount
        let skippedBefore = coachCoordinator.skippedUnchangedCount

        tabSwitchGeneration += 1
        let generation = tabSwitchGeneration
        coachTabRefreshTask?.cancel()
        coachTabRefreshTask = nil

        #if DEBUG
        TabSwitchProfiler.mark("handleTabChange")
        if newValue == .calendar || oldValue == .calendar {
            TabSwitchProfiler.markEvent("calendarTabTransition.\(oldValue)->\(newValue)")
        }
        if newValue == .coach {
            CoachRefreshDebug.log(
                "[CoachScreenLifecycle]",
                "CoachTab selected source=WeekFitRootView oldTab=\(oldValue)"
            )
        }
        #endif

        if newValue == .calendar {
            resetPlanDateToToday()
            warmPlannerCachesIfNeeded()
        }

        syncCoachRefreshInputsIfCoachDayChanged(from: oldValue, to: newValue)

        func reportSwitch(
            coachEvaluationTriggered: Bool,
            coachRefreshDurationMs: Double?,
            healthRefreshSkipped: Bool
        ) {
            #if DEBUG
            let handlerMs = (CFAbsoluteTimeGetCurrent() - handlerStart) * 1000
            TabSwitchDiagnostics.reportTabSwitch(
                from: oldValue,
                to: newValue,
                coachRecomputeCount: coachCoordinator.recomputeCount,
                coachRecomputeDelta: coachCoordinator.recomputeCount - recomputeBefore,
                coachSkippedUnchangedCount: coachCoordinator.skippedUnchangedCount,
                coachSkippedDelta: coachCoordinator.skippedUnchangedCount - skippedBefore,
                coachEvaluationTriggered: coachEvaluationTriggered,
                coachRefreshDurationMs: coachRefreshDurationMs,
                healthRefreshSkipped: healthRefreshSkipped,
                handlerMs: handlerMs
            )
            #endif
        }

        guard newValue == .coach else {
            reportSwitch(
                coachEvaluationTriggered: false,
                coachRefreshDurationMs: nil,
                healthRefreshSkipped: false
            )
            return
        }

        let refreshStart = CFAbsoluteTimeGetCurrent()
        let decision = coachTabHealthRefreshDecision()

        #if DEBUG
        HealthRefreshGuardLog.log(
            event: "coachTabActivation",
            decision: decision,
            sources: appSession.latestHealthRefreshSources
        )
        #endif

        guard decision.shouldReloadHealth else {
            reportSwitch(
                coachEvaluationTriggered: false,
                coachRefreshDurationMs: nil,
                healthRefreshSkipped: true
            )
            return
        }

        coachTabRefreshTask = Task {
            await reconcileHealthWorkouts(
                source: "tabChange.coach",
                bootstrapFromHealth: true
            )
            await refreshCoachInput(source: "tabChange.coach", refreshHealth: true)
            acknowledgeHealthRefreshEvent()

            guard !Task.isCancelled,
                  generation == tabSwitchGeneration,
                  selectedTab == .coach else {
                return
            }

            let refreshMs = (CFAbsoluteTimeGetCurrent() - refreshStart) * 1000
            reportSwitch(
                coachEvaluationTriggered: coachCoordinator.recomputeCount > recomputeBefore,
                coachRefreshDurationMs: refreshMs,
                healthRefreshSkipped: false
            )
        }
    }

    /// Real data events (Watch sync, foreground, manual refresh) reload HealthKit immediately,
    /// even when Today/Coach tabs are inactive. Tab switching alone is not a data event.
    private func handleHealthRefreshEvent() {
        healthRefreshEventTask?.cancel()
        healthRefreshEventTask = Task {
            let taskName = "root.handleHealthRefreshEvent"
            let sources = CoachTabHealthRefreshPolicy.summarizeSources(
                appSession.latestHealthRefreshSources
            )
            StartupDiagnostics.taskBegin(taskName, detail: "sources=\(sources)")
            let decision = healthRefreshEventDecision()
            #if DEBUG
            HealthRefreshGuardLog.log(
                event: "healthRefreshEvent",
                decision: decision,
                sources: appSession.latestHealthRefreshSources
            )
            #endif
            guard decision.shouldReloadHealth else {
                StartupDiagnostics.taskSuccess(taskName, detail: "skipped decision=\(String(describing: decision))")
                return
            }

            let sourceLabel = sources
            await reconcileHealthWorkouts(
                source: "healthRefreshEvent.\(sourceLabel)",
                bootstrapFromHealth: true
            )
            await refreshCoachInput(
                source: "healthRefreshEvent.\(sourceLabel)",
                refreshHealth: true
            )
            acknowledgeHealthRefreshEvent()
            if Task.isCancelled {
                StartupDiagnostics.taskCancelled(taskName)
            } else {
                StartupDiagnostics.taskSuccess(taskName, detail: "reloaded")
            }
        }
    }

    private func healthRefreshEventDecision() -> CoachTabHealthRefreshPolicy.Decision {
        CoachTabHealthRefreshPolicy.evaluate(
            CoachTabHealthRefreshPolicy.Input(
                trigger: .healthRefreshEvent(sources: appSession.latestHealthRefreshSources),
                healthRefreshToken: appSession.healthRefreshTrigger,
                acknowledgedHealthRefreshToken: acknowledgedHealthRefreshToken,
                lastHealthKitSyncTime: healthManager.lastHealthKitSyncTime,
                isHealthAccessRequested: healthManager.isHealthAccessRequested,
                now: Date()
            )
        )
    }

    private func coachTabHealthRefreshDecision() -> CoachTabHealthRefreshPolicy.Decision {
        CoachTabHealthRefreshPolicy.evaluate(
            CoachTabHealthRefreshPolicy.Input(
                trigger: .coachTabActivation,
                healthRefreshToken: appSession.healthRefreshTrigger,
                acknowledgedHealthRefreshToken: acknowledgedHealthRefreshToken,
                lastHealthKitSyncTime: healthManager.lastHealthKitSyncTime,
                isHealthAccessRequested: healthManager.isHealthAccessRequested,
                now: Date()
            )
        )
    }

    private func acknowledgeHealthRefreshEvent() {
        acknowledgedHealthRefreshToken = appSession.healthRefreshTrigger
    }

    private func returnToToday() {
        todaySelectedDate = Date()
        todayResetTrigger = UUID()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            selectedTab = .today
        }
    }

    private func resetPlanDateToToday() {
        let today = Date()
        guard !Calendar.current.isDate(planViewModel.selectedDate, inSameDayAs: today) else {
            return
        }

        planViewModel.selectedDate = today
    }

    private func refreshPlannedActivitiesSignature(warmPlannerCaches: Bool = false) {
        cachedPlannedActivitiesSignature = PlannedActivityRefreshSignature.make(from: plannedActivities)
        if warmPlannerCaches {
            warmPlannerCachesIfNeeded()
        }
        syncCoachRefreshInputs()
    }

    private func warmPlannerCachesIfNeeded() {
        planViewModel.warmDayKindCache(
            from: plannedActivities,
            revision: cachedPlannedActivitiesSignature
        )
        planViewModel.warmTimelineCache(
            from: plannedActivities,
            revision: cachedPlannedActivitiesSignature
        )
    }

    private func syncCoachRefreshInputsIfCoachDayChanged(from oldTab: WeekFitTab, to newTab: WeekFitTab) {
        guard coachDayStart(for: oldTab) != coachDayStart(for: newTab) else { return }
        syncCoachRefreshInputs()
    }

    private func coachDayStart(for tab: WeekFitTab) -> Int {
        let date = tab == .today ? todaySelectedDate : Date()
        return Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86_400)
    }

    private func syncCoachRefreshInputs() {
        let next = CoachRefreshInputs(
            languageCode: languageManager.selectedLanguage.rawValue,
            healthRefreshToken: appSession.healthRefreshTrigger,
            returnToTodayToken: appSession.returnToTodayTrigger,
            coachRefreshToken: appSession.coachRefreshTrigger,
            hasSettledInitialHealthState: hasSettledInitialHealthState,
            coachDayStart: coachDayStart(for: selectedTab),
            plannedActivitiesSignature: cachedPlannedActivitiesSignature
        )
        guard next != coachRefreshInputs else { return }
        coachRefreshInputs = next
    }

    private func refreshCoachInput(source: String, refreshHealth: Bool = false) async {
        if shouldDeferHiddenCoachRefresh {
            #if DEBUG
            CoachRefreshDebug.log(
                "[CoachInputTrace]",
                "source=\(source) deferred hidden Coach refresh until first HealthKit access check completes"
            )
            #endif
            return
        }

        await coachInputProvider.refresh(
            selectedDate: coachRefreshDate,
            plannedActivities: plannedActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            source: source,
            refreshHealth: refreshHealth
        )

        WidgetSnapshotPublisher.publishFromLiveState(
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            plannedActivities: plannedActivities
        )
    }

    private var coachRefreshDate: Date {
        selectedTab == .today ? todaySelectedDate : Date()
    }

    private var shouldDeferHiddenCoachRefresh: Bool {
        selectedTab != .coach &&
            healthManager.isHealthAccessRequested &&
            !hasSettledInitialHealthState
    }

    private var hasSettledInitialHealthState: Bool {
        if !healthManager.isHealthAccessRequested {
            return healthManager.hasCompletedHealthAccessCheck
        }
        return healthManager.hasSettledMetrics(for: coachRefreshDate)
    }

    private var watchSyncPlannerSignature: String {
        plannedActivities
            .map { "\($0.id):\($0.healthKitWorkoutUUID ?? ""):\($0.isCompleted)" }
            .joined(separator: "|")
    }

    private func reconcileHealthWorkouts(
        source: String,
        bootstrapFromHealth: Bool = false
    ) async {
        let run = UUID()
        let taskName = "root.reconcileHealthWorkouts"
        if let existing = Self.reconcileInFlight {
            StartupDiagnostics.taskBegin(
                taskName,
                detail: "run=\(run.uuidString.prefix(8)) joinInFlight source=\(source) bootstrap=\(bootstrapFromHealth)"
            )
            await existing.value
            // Non-bootstrap callers can coalesce. Bootstrap must still run if it lost the race.
            if !bootstrapFromHealth {
                StartupDiagnostics.taskSuccess(taskName, detail: "run=\(run.uuidString.prefix(8)) joined")
                return
            }
            StartupDiagnostics.taskBegin(
                taskName,
                detail: "run=\(run.uuidString.prefix(8)) bootstrapAfterJoin source=\(source)"
            )
        }

        let task = Task { @MainActor in
            await self.performReconcileHealthWorkouts(
                run: run,
                source: source,
                bootstrapFromHealth: bootstrapFromHealth
            )
        }
        Self.reconcileInFlight = task
        await task.value
        if Self.reconcileInFlight == task {
            Self.reconcileInFlight = nil
        }
    }

    private func performReconcileHealthWorkouts(
        run: UUID,
        source: String,
        bootstrapFromHealth: Bool
    ) async {
        let taskName = "root.reconcileHealthWorkouts"
        StartupDiagnostics.taskBegin(
            taskName,
            detail: "run=\(run.uuidString.prefix(8)) source=\(source) bootstrap=\(bootstrapFromHealth) planned=\(plannedActivities.count)"
        )
        CoachSnapshotInvalidator.invalidate(
            coordinator: coachCoordinator,
            nutritionViewModel: nutritionViewModel,
            inputProvider: coachInputProvider,
            reason: "preHealthReconcile.\(source)"
        )

        if bootstrapFromHealth {
            await activityCoordinator.bootstrapHealthWorkouts(
                for: Date(),
                healthManager: healthManager,
                with: plannedActivities,
                modelContext: modelContext
            )
        }

        guard !activityCoordinator.completedWorkoutsBatch.isEmpty else {
            StartupDiagnostics.taskSuccess(
                taskName,
                detail: "run=\(run.uuidString.prefix(8)) no completed batch"
            )
            return
        }

        activityCoordinator.reconcileCompletedWorkouts(
            with: plannedActivities,
            modelContext: modelContext
        )
        appSession.triggerHealthRefresh(source: source)
        appSession.triggerCoachRefresh(source: source)
        StartupDiagnostics.taskSuccess(
            taskName,
            detail: "run=\(run.uuidString.prefix(8)) reconciled batch"
        )
    }

    private func reconcileAppCalendarDay(source: String, returnToToday: Bool) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = AppCalendarDayBoundary.dayStart(for: now, calendar: calendar)

        let inMemoryRollover = trackedAppDayStart.map {
            !calendar.isDate($0, inSameDayAs: todayStart)
        } ?? false

        let persistedRollover = AppCalendarDayBoundary.detectPersistedRollover(
            now: now,
            calendar: calendar
        ) != nil

        if inMemoryRollover || persistedRollover {
            let previousDayStart = trackedAppDayStart
                ?? AppCalendarDayBoundary.loadPersistedDayStart()
                ?? todayStart

            applyInMemoryCalendarDayRollover(
                from: previousDayStart,
                to: todayStart,
                source: source,
                returnToToday: returnToToday
            )
        }

        trackedAppDayStart = todayStart
        syncCoachRefreshInputs()
    }

    private func applyInMemoryCalendarDayRollover(
        from previousDayStart: Date,
        to newDayStart: Date,
        source: String,
        returnToToday: Bool
    ) {
        let calendar = Calendar.current
        guard !calendar.isDate(previousDayStart, inSameDayAs: newDayStart) else { return }

        trackedAppDayStart = newDayStart

        if calendar.isDate(todaySelectedDate, inSameDayAs: previousDayStart) {
            todaySelectedDate = Date()
        }

        healthManager.prepareForDisplayDay(newDayStart)
        nutritionViewModel.prepareForDay(todaySelectedDate)
        coachCoordinator.invalidateResolvedStateForDayChange()
        coachInputProvider.invalidateCompletedRefreshCache()

        appSession.handleCalendarDayRollover(
            source: source,
            returnToToday: returnToToday
        )
    }

    private func scheduleNextCalendarDayCheck() async {
        let delay = AppCalendarDayBoundary.nextBoundary().timeIntervalSinceNow + 0.5
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        guard !Task.isCancelled else { return }

        reconcileAppCalendarDay(source: "midnightTimer", returnToToday: true)
    }

    private func handleCoachCheckpointIfNeeded() async {
        guard let checkpoint = coachCoordinator.nextScheduledCheckpoint else { return }

        let delay = checkpoint.timeIntervalSinceNow
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        guard !Task.isCancelled else { return }

        let now = Date()
        let calendar = Calendar.current
        let todayStart = AppCalendarDayBoundary.dayStart(for: now, calendar: calendar)

        if let trackedAppDayStart,
           !calendar.isDate(trackedAppDayStart, inSameDayAs: todayStart) {
            reconcileAppCalendarDay(source: "coachCheckpoint.dayRollover", returnToToday: true)
        } else {
            coachCoordinator.invalidateResolvedStateForDayChange()
            appSession.triggerCoachRefresh(source: "coachCheckpoint")
            syncCoachRefreshInputs()
        }
    }

    private func syncNotifications(
        source: String,
        includeActivities: Bool = true,
        includeWellness: Bool = true
    ) {
        if includeActivities && includeWellness {
            NotificationSyncCoordinator.syncAll(
                plannedActivities: plannedActivities,
                recoveryPercent: healthManager.recoveryPercent,
                source: source
            )
        } else if includeWellness {
            NotificationSyncCoordinator.syncWellness(
                plannedActivities: plannedActivities,
                recoveryPercent: healthManager.recoveryPercent,
                source: source
            )
        } else {
            NotificationSyncCoordinator.syncActivities(
                plannedActivities: plannedActivities,
                source: source
            )
        }
    }

    private func handleActivityNotificationAction(_ notification: Notification) {
        ActivityNotificationActionProcessor.handle(
            userInfo: notification.userInfo,
            modelContext: modelContext,
            onActivityStateChanged: {
                appSession.triggerHealthRefresh(source: "notificationAction")
                if ActivityConfirmationState.shared.pendingActivity != nil {
                    returnToToday()
                }
            }
        )
    }

    /// Evaluates morning proposal even when Today is unmounted (Coach/Meals/Plan tabs).
    private func evaluateMorningProposalFromRoot(source: String) {
        let now = Date()
        guard CoachMorningOverviewPolicy.isBeforeLocalNoon(now: now) else { return }

        #if DEBUG
        if MorningProposalScreenshotFixtures.shouldSeed { return }
        #endif

        let sleepHours = Double(healthManager.sleepMinutes) / 60.0
        let hasRecoverySignals = MorningProposalEvaluator.hasRecoverySignals(
            sleepMinutes: healthManager.sleepMinutes,
            timeInBedMinutes: healthManager.timeInBedMinutes,
            hrvSDNN: healthManager.hrvSDNN,
            restingHeartRate: healthManager.restingHeartRate
        )
        let coachState = coachCoordinator.state
        let readiness: CoachDayReadiness = {
            if let input = coachState.input {
                return CoachDayReadinessResolver.resolve(
                    from: input,
                    priorDayLoad: healthManager.recoveryPriorDayLoad
                )
            }
            return MorningProposalEvaluator.readinessFallback(
                readyScore: healthManager.readyScore,
                sleepHours: sleepHours,
                hadHeavyYesterday: CoachDayReadinessResolver.isHeavyPriorDayLoad(
                    healthManager.recoveryPriorDayLoad
                )
            )
        }()
        let meals = MorningProposalEvaluator.mealLibrary(from: WeekFitUserSettings.shared)

        Task { @MainActor in
            let (weather, _) = await WeekFitWeatherProvider.shared.cachedSummaryAndFreshness()
            let proposal = MorningProposalEvaluator.evaluate(
                .init(
                    now: now,
                    plannedActivities: Array(plannedActivities),
                    isHealthAccessGranted: healthManager.isHealthAccessGranted,
                    sleepHours: sleepHours,
                    hasSettledMetrics: healthManager.hasSettledMetrics(for: todaySelectedDate),
                    hasRecoverySignals: hasRecoverySignals,
                    readiness: readiness,
                    scenarioKey: coachState.coachIntegrationDebug?.scenario,
                    mealLibrary: meals.candidates,
                    mealLibraryRevision: meals.revision,
                    weatherRiskToken: ProposalWeatherRisk.resolve(from: weather)
                )
            )

            let givenName: String? = {
                let name = ProfileService.resolvedGivenName()
                return name.isEmpty ? nil : name
            }()
            MorningProposalNotificationService.shared.sync(
                proposal: proposal,
                wakeTime: healthManager.wakeTime,
                todaySurfaceVisible: selectedTab == .today && scenePhase == .active,
                givenName: givenName
            )
            #if DEBUG
            _ = source
            #endif
        }
    }
}
