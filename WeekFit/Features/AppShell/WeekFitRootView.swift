import SwiftUI
import SwiftData

struct WeekFitRootView: View {

    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var activityCoordinator: WeekFitActivityCoordinator
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var languageManager: AppLanguageManager

    @StateObject private var planViewModel = PlanViewModel()
    @StateObject private var coachInputProvider = CoachInputProvider()
    @State private var selectedTab: WeekFitTab = .today
    @State private var todaySelectedDate = Date()
    @State private var todayResetTrigger = UUID()
    @State private var showContent = false

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    var body: some View {
        ZStack(alignment: .bottom) {
            WeekFitTheme.appBackground
                .ignoresSafeArea()
            ambientBackground
                .ignoresSafeArea()

            selectedContent
            .transition(
                .asymmetric(
                    insertion: .offset(y: 8).combined(with: .opacity),
                    removal: .opacity
                )
            )
            .animation(
                selectedTab == .coach
                    ? nil
                    : .interactiveSpring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.12),
                value: selectedTab
            )

            WeekFitBottomBar(selectedTab: $selectedTab)
                .padding(.horizontal, 1)
                .background(alignment: .top) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 1)
                        .offset(y: -7)
                }
                .shadow(color: Color.black.opacity(0.4), radius: 25, y: -10)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 120)
        }
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.88)) {
                showContent = true
            }
            reconcileWatchWorkouts(source: "root.onAppear")
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            handleTabChange(from: oldValue, to: newValue)
        }
        .onChange(of: appSession.returnToTodayTrigger) { _, _ in
            returnToToday()
        }
        .onChange(of: activityCoordinator.completedWorkoutsBatch) { _, _ in
            reconcileWatchWorkouts(source: "root.onChange.completedWorkoutsBatch")
        }
        .onChange(of: watchSyncPlannerSignature) { _, _ in
            reconcileWatchWorkouts(source: "root.onChange.plannedActivities")
        }
        .task(id: coachRefreshSignature) {
            await refreshCoachInput(source: "rootTask")
        }
    }

    private var coachRefreshSignature: String {
        [
            selectedTab == .coach ? "coachVisible" : "coachHidden",
            languageManager.selectedLanguage.rawValue,
            nutritionViewModel.coachStateRefreshID.uuidString,
            appSession.healthRefreshTrigger.uuidString,
            appSession.coachRefreshTrigger.uuidString,
            appSession.returnToTodayTrigger.uuidString,
            "\(hasSettledInitialHealthState)",
            "\(Int(Calendar.current.startOfDay(for: coachRefreshDate).timeIntervalSince1970 / 86_400))",
            plannedActivities
                .map { activity in
                    [
                        activity.id,
                        "\(Int(activity.date.timeIntervalSince1970 / 60))",
                        activity.title,
                        activity.type,
                        "\(activity.isCompleted)",
                        "\(activity.isSkipped)",
                        "\(activity.actualDurationMinutes ?? -1)",
                        activity.healthKitWorkoutUUID ?? "nil",
                        activity.source
                    ].joined(separator: ":")
                }
                .joined(separator: "|")
        ].joined(separator: "#")
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .today:
            TodayView(
                authViewModel: authViewModel,
                selectedDate: $todaySelectedDate,
                returnToTodayTrigger: todayResetTrigger,
                onSelectTab: selectTab
            )
            .environmentObject(coachInputProvider)

        case .coach:
            ExpertCoachView(authViewModel: authViewModel)
                .environmentObject(coachInputProvider)

//        case .highlights:
//            HighlightsView()

        case .meals:
            MealsView(
                authViewModel: authViewModel,
                nutritionResult: nutritionViewModel.nutritionResult
            )

        case .calendar:
            WeekPlannerView(
                viewModel: planViewModel,
                authViewModel: authViewModel
            )
        }
    }

    @ViewBuilder
    private var ambientBackground: some View {
        switch selectedTab {
        case .today:
            WeekFitTheme.todayAmbient
        case .coach:
            WeekFitTheme.coachAmbient
//        case .highlights:
//            WeekFitTheme.todayAmbient
        case .meals:
            WeekFitTheme.mealsAmbient
        case .calendar:
            WeekFitTheme.planAmbient
        }
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
        if newValue == .coach {
            CoachRefreshDebug.log(
                "[CoachScreenLifecycle]",
                "CoachTab selected source=WeekFitRootView oldTab=\(oldValue)"
            )
        }
        #endif

        if newValue == .calendar {
            resetPlanDateToToday()
        }

        Task {
            await refreshCoachInput(source: "tabChange.\(newValue)")
        }
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

    private func refreshCoachInput(source: String) async {
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
            refreshHealth: selectedTab == .coach && source == "tabChange.coach"
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
        healthManager.lastHealthKitSyncTime != nil ||
            (healthManager.hasCompletedHealthAccessCheck && !healthManager.isHealthAccessGranted)
    }

    private var watchSyncPlannerSignature: String {
        plannedActivities
            .map { "\($0.id):\($0.healthKitWorkoutUUID ?? ""):\($0.isCompleted)" }
            .joined(separator: "|")
    }

    private func reconcileWatchWorkouts(source: String) {
        guard !activityCoordinator.completedWorkoutsBatch.isEmpty else { return }

        activityCoordinator.reconcileCompletedWorkouts(
            with: plannedActivities,
            modelContext: modelContext
        )
        appSession.triggerHealthRefresh(source: source)
        appSession.triggerCoachRefresh(source: source)
    }
}
