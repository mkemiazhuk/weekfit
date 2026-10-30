import SwiftUI
import SwiftData
import HealthKit
import UIKit
import WeekFitPlanner
internal import Combine
import OSLog

struct TodayView: View {

    @ObservedObject var authViewModel: AuthViewModel
    @Binding var selectedDate: Date
    let returnToTodayTrigger: UUID
    let onSelectTab: (WeekFitTab) -> Void
    @EnvironmentObject private var appSession: AppSessionState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    
    @ObservedObject private var userSettings = WeekFitUserSettings.shared

    @StateObject private var confirmationState = ActivityConfirmationState.shared
    @StateObject private var todayViewModel = TodayViewModel()

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]
    
    @State private var showDirectMealLogSheet = false
    @State private var showDirectDrinkLogSheet = false

    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var coachInputProvider: CoachInputProvider
    @EnvironmentObject private var activityCoordinator: WeekFitActivityCoordinator
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Environment(\.weekFitPalette) private var palette
    @Environment(\.tabIsActive) private var tabIsActive
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    @State private var showProfile = false
    @State private var plannerVoiceEnabled = false
    @State private var showPlannerVoice = false
    @State private var showAIUsage = false
    @State private var openingMaya = false
    @AppStorage(NotificationPreferenceKey.activityReminders)
    private var activityRemindersEnabled = false
    @AppStorage(NotificationPreferenceKey.completionCheckIns)
    private var completionCheckInsEnabled = false
    @AppStorage(OnboardingStore.Keys.introToday) private var todayIntroDismissed = false
    @State private var drinksQuickLogToast: String?
    @State private var foodQuickLogToast: String?
    /// Save-failure retry banner only — success returns to normal Today with no plaque.
    @State private var sessionFinishErrorToast: String?
    @State private var isFinishingSession = false
    
    @State private var activityToConfirm: PlannedActivity? = nil
    @State private var queuedActivityToConfirm: PlannedActivity? = nil

    private let cardBackground = WeekFitTheme.cardSurface
    private let cardSecondary = WeekFitTheme.cardSurfaceElevated

    private var textPrimary: Color { palette.textPrimary }
    private var textSecondary: Color { palette.textSecondary }
    private var textTertiary: Color { palette.textTertiary }

    /// Secondary labels — cool gray on midnight navy.
    private var todaySecondaryReadable: Color {
        let base = TodayChrome.secondaryText(isLight: palette.isLight)
        guard !palette.isLight else { return base }
        return colorSchemeContrast == .increased ? base : base.opacity(0.94)
    }

    /// Meta under rings (goal / remaining / sleep).
    private var todayMetaReadable: Color {
        let base = TodayChrome.secondaryText(isLight: palette.isLight)
        guard !palette.isLight else { return base.opacity(0.92) }
        return colorSchemeContrast == .increased ? base.opacity(0.92) : base.opacity(0.86)
    }

    private var todaySectionTitleColor: Color {
        let base = TodayChrome.secondaryText(isLight: palette.isLight)
        if palette.isLight { return base }
        return colorSchemeContrast == .increased ? base.opacity(0.90) : base.opacity(0.82)
    }

    private let todayRingSize: CGFloat = 72
    private let todayRingStroke: CGFloat = 3.5
    private let todayPremiumBronze = Color(red: 0.72, green: 0.63, blue: 0.45)
    private let todayPremiumBronzeSoft = Color(red: 0.60, green: 0.52, blue: 0.39)

    private var todayActivityColor: Color { WeekFitProgressRingColor.activity }
    private var todayNutritionColor: Color { WeekFitProgressRingColor.nutrition }
    private var todayRecoveryColor: Color { WeekFitProgressRingColor.recovery }

    /// Finish/stop control — muted rose so it reads as stop without competing with live green.
    private var sessionStopFill: Color {
        WeekFitLightTokens.critical.opacity(palette.isLight ? 0.14 : 0.22)
    }
    private var sessionStopForeground: Color {
        palette.isLight
            ? Color(red: 0.62, green: 0.28, blue: 0.26)
            : Color(red: 0.92, green: 0.68, blue: 0.66)
    }
    /// Brighter edge so the capsule separates from the dark card surface.
    private var sessionStopBorder: Color {
        sessionStopForeground.opacity(palette.isLight ? 0.45 : 0.72)
    }

    private enum TodayLayout {
        static let cardRadius: CGFloat = TodayChrome.cardRadius
        /// Header spacing now lives in `WeekFitScreenLayout.headerBottomSpacing`.
        static let contentTopInset: CGFloat = 0
        static let gapBetweenCards: CGFloat = 18
        static let ringGroupSpacing: CGFloat = 6
        static let cardTitleBottomGap: CGFloat = 6
        static let overviewContentTopPadding: CGFloat = 10
        static let overviewContentBottomPadding: CGFloat = 10
        static let overviewHorizontalPadding: CGFloat = TodayChrome.cardPadding
        static let coachCardVerticalPadding: CGFloat = 12
        static let cardInteriorVerticalPadding: CGFloat = 12
        static let quickTileRadius: CGFloat = 18
        static let quickTileSpacing: CGFloat = 10
        /// Recent completion window for compact summary (does not permanently pin).
        static let recentCompletionWindow: TimeInterval = 45 * 60
    }

    /// Layout modes for Today stack — derived from session/plan state, not health refresh.
    /// After finish, restore normal (upcoming/idle) — no dedicated completion layout.
    private enum TodayStackMode: Equatable {
        case activeSession
        case upcoming
        case idle
    }

    private var shouldStackRings: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var shouldStackQuickActions: Bool {
        dynamicTypeSize >= .xxLarge
    }

    private var shouldRelocateUpNextTime: Bool {
        dynamicTypeSize >= .xLarge
    }

    private var todayEffectiveRingSize: CGFloat {
        if shouldStackRings { return todayRingSize }
        switch dynamicTypeSize {
        case .xxLarge:
            return 66
        case .xxxLarge:
            return 62
        default:
            return todayRingSize
        }
    }

    private var ringCaptionLineLimit: Int {
        // Allow wrap so +10–12% type doesn't collide across the three columns.
        if shouldStackRings { return 3 }
        return dynamicTypeSize >= .xLarge ? 3 : 2
    }

    private var quickActionCaptionLineLimit: Int {
        // Allow wrap so ×1.10 labels fit DE/PL/RU without shrinking.
        shouldStackQuickActions ? 3 : 2
    }

    private var healthRefreshBinding: Binding<UUID> {
        Binding(
            get: { todayViewModel.healthRefreshID },
            set: { todayViewModel.healthRefreshID = $0 }
        )
    }
    
    @State private var showDirectWorkoutLogSheet = false
    @State private var showDirectRecoveryLogSheet = false
    
    @State private var selectedLogTab: QuickNutritionLogTab = .meals
    @State private var quickLogMeals: [Meals] = []
    @State private var quickLogMealRows: [QuickMealDisplayRow] = []
    @State private var quickLogSnacks: [QuickItem] = []
    @State private var quickLogDrinks: [QuickItem] = []
    @State private var quickLogSnackRows: [QuickItemDisplayRow] = []
    @State private var quickLogFrequentSnackRows: [QuickFoodFrequentSnackRow] = []
    @State private var quickLogRecentSnackRows: [QuickItemDisplayRow] = []
    @State private var quickLogFrequentMealRows: [QuickFoodFrequentMealRow] = []
    @State private var quickLogRecentMealRows: [QuickMealDisplayRow] = []
    @State private var quickLogDrinkRows: [QuickItemDisplayRow] = []
    @State private var quickLogFrequentDrinkRows: [QuickDrinkFrequentDisplayRow] = []
    @State private var quickLogRecentDrinkRows: [QuickItemDisplayRow] = []
    @State private var quickLogSession = QuickLogSessionStore()
    @State private var quickLogCommittedUsageIDs: Set<String> = []
    @State private var quickItemUsageEntries: [String: QuickItemUsageStore.Entry] = [:]
    @State private var didPreloadQuickFood = false
    @State private var didPreloadQuickDrinks = false
    
    @State private var showActivityIntelligence = false
    @State private var showNutritionDetails = false
    @State private var nutritionDetailsDate = Date()
    @State private var showProposalReview = false
    @State private var morningProposal: MorningPlanProposal?
    @State private var morningProposalTimeoutTask: Task<Void, Never>?
    @State private var morningProposalDebounceTask: Task<Void, Never>?
    @State private var morningProposalChromeHidden = false
    @State private var morningWeatherSummary: WeekFitWeatherSummary?

    @State private var showRecoveryDetails = false

    private var quickItemUsage: [String: Int] {
        QuickItemUsageStore.counts(from: quickItemUsageEntries)
    }

    init(
        authViewModel: AuthViewModel,
        selectedDate: Binding<Date>,
        returnToTodayTrigger: UUID = UUID(),
        onSelectTab: @escaping (WeekFitTab) -> Void = { _ in }
    ) {
        // NOTE: @StateObject / @Query property wrappers are initialized before this body runs.
        // Each struct value gets a new instanceID — duplicate TODAY 01 lines with different
        // IDs mean SwiftUI recreated the view value; identical IDs cannot happen across values.
        let instanceID = UUID()
        TodayStartupDiagnostics.step(
            1,
            "init begin",
            detail: "instance=\(instanceID.uuidString.prefix(8)) | \(TodayStartupDiagnostics.selectedDaySanity(selectedDate: selectedDate.wrappedValue))"
        )
        self.authViewModel = authViewModel
        self._selectedDate = selectedDate
        self.returnToTodayTrigger = returnToTodayTrigger
        self.onSelectTab = onSelectTab
        TodayStartupDiagnostics.step(
            2,
            "init complete",
            detail: "instance=\(instanceID.uuidString.prefix(8)) | \(TodayStartupDiagnostics.selectedDaySanity(selectedDate: selectedDate.wrappedValue))"
        )
        // Do not also emit STARTUP 11 here — RootView logs mounting separately; dual STARTUP+TODAY
        // lines with the same instance looked like two TodayView instances.
    }
    
    private var completedNutritionLogsForSelectedDay: [PlannedActivity] {
        selectedDayActivities.filter { activity in
            guard activity.isCompleted, !activity.isSkipped, activity.imageName != "hydration" else {
                return false
            }

            let type = activity.type.lowercased()
            return type == "meal" || type == "drink" || type == "snack"
        }
    }

    private var loggedDrinksForSelectedDay: [PlannedActivity] {
        selectedDayActivities
            .filter { $0.isCompleted && !$0.isSkipped && $0.type.lowercased() == "drink" }
            .sorted { $0.date < $1.date }
    }

    private var loggedPlanCalories: Double {
        completedNutritionLogsForSelectedDay
            .reduce(0.0) { $0 + Double($1.calories) }
    }

    private var loggedPlanProtein: Double {
        completedNutritionLogsForSelectedDay
            .reduce(0.0) { $0 + Double($1.protein) }
    }

    private var loggedPlanCarbs: Double {
        completedNutritionLogsForSelectedDay
            .reduce(0.0) { $0 + Double($1.carbs) }
    }

    private var loggedPlanFats: Double {
        completedNutritionLogsForSelectedDay
            .reduce(0.0) { $0 + Double($1.fats) }
    }
    
    private var loggedPlanFiber: Double {
        completedNutritionLogsForSelectedDay
            .reduce(0.0) { $0 + Double($1.fiber) }
    }
    
    private func nutritionFiber(for date: Date) -> Double {
        let catalog = userSettings.customMealsCatalog
        return nutritionMeals(for: date).reduce(0.0) { total, activity in
            total + Double(PlannedActivityNutritionResolver.resolvedFiber(for: activity, in: catalog))
        }
    }

    private func nutritionMeals(for date: Date) -> [PlannedActivity] {
        plannedActivities
            .filter {
                Calendar.current.isDate($0.date, inSameDayAs: date)
                && ($0.type.lowercased() == "meal"
                    || $0.type.lowercased() == "drink"
                    || $0.type.lowercased() == "snack")
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

    private func nutritionWater(for date: Date) -> Double {
        if Calendar.current.isDateInToday(date),
           let waterLiters = nutritionViewModel.currentMetrics?.waterLiters {
            return waterLiters
        }

        let dayActivities = todayViewModel.selectedDayActivities(on: date, from: plannedActivities)
        return QuickLogActivityPortions.totalWaterLiters(from: dayActivities)
    }
    
    private var currentProtein: Double { healthManager.protein + loggedPlanProtein }
    private var currentCarbs: Double { healthManager.carbs + loggedPlanCarbs }
    private var currentFats: Double { healthManager.fats + loggedPlanFats }
    private var currentCalories: Double { healthManager.calories + loggedPlanCalories }

    private var proteinGoal: Double { nutritionViewModel.nutritionResult?.goals.protein ?? 153.0 }
    private var carbsGoal: Double { nutritionViewModel.nutritionResult?.goals.carbs ?? 330.0 }
    private var fatsGoal: Double { nutritionViewModel.nutritionResult?.goals.fats ?? 90.0 }
    private var fiberGoal: Double { nutritionViewModel.nutritionResult?.goals.fiber ?? 35.0 }
    private var todayNutritionBudget: NutritionBudget {
        NutritionBudgetCalculator.canonicalBudget(from: nutritionViewModel)
    }

    private var caloriesGoal: Double { todayNutritionBudget.totalCalories > 0 ? todayNutritionBudget.totalCalories : 2761.0 }
    private var waterGoal: Double { nutritionViewModel.nutritionResult?.goals.waterLiters ?? 4.46 }

    private var hasTodayRecoverySignals: Bool {
        // Ring "has data" must mean a recovery score is actually available.
        // Bare RHR/HRV without sleep previously painted a fake 0% while Details showed a real score.
        healthManager.sleepMinutes > 0 ||
        healthManager.timeInBedMinutes > 0 ||
        healthManager.recoveryPercent > 0
    }

    private var shouldShowHealthConnectPrompt: Bool {
        !hasTodayRecoverySignals &&
        !healthManager.isHealthAccessGranted &&
        (
            healthManager.isHealthAuthorizationInFlight ||
            !healthManager.isHealthAccessRequested ||
            healthManager.hasCompletedHealthAccessCheck
        )
    }

    private var timeOfDayGreeting: (text: String, icon: String, iconColor: Color) {
        switch WeekFitLocalDayPeriod.from() {
        case .morning:
            return (WeekFitLocalizedString("today.greeting.morning"), "sun.max.fill", .orange)
        case .afternoon:
            return (WeekFitLocalizedString("today.greeting.afternoon"), "sun.max.fill", .orange)
        case .evening:
            return (
                WeekFitLocalizedString("today.greeting.evening"),
                "moon.stars.fill",
                Color(red: 0.55, green: 0.40, blue: 0.85)
            )
        case .night:
            return (WeekFitLocalizedString("today.greeting.night"), "moon.fill", .indigo)
        }
    }
    
    private func incrementQuickItemUsage(_ item: QuickItem) {
        var nextUsage = quickItemUsageEntries
        QuickItemUsageStore.recordUse(of: item.id, in: &nextUsage)
        setQuickItemUsageEntries(nextUsage, persist: true)

        if !quickLogSnacks.isEmpty {
            refreshSnackPartitions(snacks: quickLogSnacks, usage: nextUsage)
        }

        if !quickLogDrinks.isEmpty {
            refreshDrinkPartitions(drinks: quickLogDrinks, usage: nextUsage)
        }
    }

    private func incrementMealUsage(_ meal: Meals) {
        var nextUsage = quickItemUsageEntries
        QuickItemUsageStore.recordUse(of: meal.id, in: &nextUsage)
        setQuickItemUsageEntries(nextUsage, persist: true)
        refreshMealPartitions(meals: quickLogMeals, usage: nextUsage)
    }

    @ViewBuilder
    private var todayActiveBody: some View {
        let _ = TodayStartupDiagnostics.child("todayActiveBody begin")
        let _ = languageManager.selectedLanguage

        // Match Coach / Meals / Plan: header chrome stays in safe area; root paints
        // the shared canvas. Atmosphere is a background, not a layout sibling.
        ZStack(alignment: .top) {
            todayScreen
                .background { todayBackground }
                .onAppear {
                   TodayStartupDiagnostics.step(
                       8,
                       "onAppear",
                       detail: "tabActive=\(tabIsActive) healthRequested=\(healthManager.isHealthAccessRequested) planned=\(plannedActivities.count) \(TodayStartupDiagnostics.selectedDaySanity(selectedDate: selectedDate))"
                   )
                   todayViewModel.now = Date()
                   reconcileTodayDayBoundary()
                   #if DEBUG
                   TodayHierarchyScreenshotFixtures.prepareIfNeeded(modelContext: modelContext)
                   #endif
                   refreshMorningProposal()
                   openPendingMorningProposalReviewIfNeeded()
                   StartupDiagnostics.step(
                       19,
                       "quick-log catalog preload begin",
                       detail: "loads Today quick-add snacks/drinks JSON + customMealsCatalog into memory — does NOT create meal library records"
                   )
                   // Defer catalog preload off the first paint — sync JSON work competed
                   // with SwiftUI type specialization on the same main-thread stack.
                   DispatchQueue.main.async {
                       preloadQuickFoodLogDataIfNeeded()
                       preloadQuickDrinkLogDataIfNeeded()
                       StartupDiagnostics.step(
                           20,
                           "quick-log catalog preload complete",
                           detail: "quickFoodCatalogLoaded=\(didPreloadQuickFood) quickDrinkCatalogLoaded=\(didPreloadQuickDrinks) customMealsCatalogCount=\(userSettings.customMealsCatalog.count) quickLogMealsInMemory=\(quickLogMeals.count) quickLogDrinksInMemory=\(quickLogDrinks.count)"
                       )
                       if !healthManager.isHealthAccessRequested {
                           updateNutrition()
                       }
                   }
                   TodayStartupDiagnostics.markFirstFrameStableIfNeeded(
                       detail: "TodayView.onAppear"
                   )
                   StartupDiagnostics.markFirstScreenStableIfNeeded(
                       detail: "TodayView.onAppear before health task"
                   )
                }
        }
    }

    var body: some View {
        let _ = TodayStartupDiagnostics.step(
            3,
            "body evaluation begin",
            detail: "tabActive=\(tabIsActive) \(TodayStartupDiagnostics.selectedDaySanity(selectedDate: selectedDate))"
        )
        let root = Group {
            if tabIsActive {
                let _ = TodayStartupDiagnostics.step(4, "body root created", detail: "todayActiveBody branch")
                // Erase TodayActiveBody's enormous opaque type before attaching sheets/tasks.
                // Identity transition: the tab-bar transaction must not slide each card in.
                AnyView(todayActiveBody)
                    .transition(.identity)
            } else {
                let _ = TodayStartupDiagnostics.step(4, "body root created", detail: "inactive clear branch")
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
                    .transition(.identity)
            }
        }
        .animation(nil, value: tabIsActive)
        let _ = TodayStartupDiagnostics.step(7, "body evaluation complete", detail: "modifiers attaching")

        // Bound SwiftUI generic inference at stable root modifier boundaries.
        let presented = root
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.today")
        .sheet(isPresented: $showAIUsage) { NavigationStack { WeekFitAIUsageView() } }
        .fullScreenCover(isPresented: $showPlannerVoice) {
            PlanRealtimeVoiceSheet(
                planningDay: selectedDate,
                activities: plannedActivities,
                dayContext: voiceDayContext(),
                onSave: { request in
                    try PlanViewModel().saveVoiceActivity(
                        request,
                        activities: plannedActivities,
                        modelContext: modelContext,
                        activityRemindersEnabled: activityRemindersEnabled,
                        completionCheckInsEnabled: completionCheckInsEnabled
                    )
                },
                onUpdate: { request in
                    try PlanViewModel().updateVoiceActivity(
                        request,
                        activities: plannedActivities,
                        modelContext: modelContext,
                        activityRemindersEnabled: activityRemindersEnabled,
                        completionCheckInsEnabled: completionCheckInsEnabled
                    )
                },
                onDelete: { id in
                    try PlanViewModel().deleteVoiceActivity(
                        id: id,
                        activities: plannedActivities,
                        modelContext: modelContext
                    )
                }
            )
            .environmentObject(languageManager)
            .interactiveDismissDisabled(true)
        }
        .task {
            await refreshMayaAccess()
        }
        .fullScreenCover(isPresented: $showActivityIntelligence) {
            ActivityIntelligenceView(
                selectedDate: selectedDate,
                healthManager: healthManager,
                plannedActivities: plannedActivities
            )
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
                mealCatalog: userSettings.customMealsCatalog
            ) { newDate in
                nutritionDetailsDate = newDate
            }
        }
        .fullScreenCover(isPresented: $showRecoveryDetails) {
            RecoveryDetailsView(
                selectedDate: selectedDate,
                recoveryScore: healthManager.recoveryPercent,
                recoveryBreakdown: healthManager.recoveryBreakdown
            )
        }
        let healthObserved = AnyView(presented)
        .task(id: todayViewModel.healthRefreshID) {
            guard tabIsActive else { return }
            let taskName = "today.refreshHealthAndNutrition"
            TodayStartupDiagnostics.step(9, "initial task begin", detail: taskName)
            TodayStartupDiagnostics.taskBegin(
                taskName,
                detail: "refreshID=\(todayViewModel.healthRefreshID) requested=\(healthManager.isHealthAccessRequested)"
            )
            StartupDiagnostics.taskBegin(
                taskName,
                detail: "refreshID=\(todayViewModel.healthRefreshID) requested=\(healthManager.isHealthAccessRequested)"
            )
            await refreshHealthAndNutritionAsync()
            if Task.isCancelled {
                TodayStartupDiagnostics.taskCancelled(taskName)
                StartupDiagnostics.taskCancelled(taskName)
            } else {
                TodayStartupDiagnostics.taskSuccess(
                    taskName,
                    detail: "recovery=\(healthManager.recoveryPercent) sleepMin=\(healthManager.sleepMinutes)"
                )
                TodayStartupDiagnostics.step(
                    10,
                    "initial task success",
                    detail: "recovery=\(healthManager.recoveryPercent) sleepMin=\(healthManager.sleepMinutes)"
                )
                StartupDiagnostics.taskSuccess(
                    taskName,
                    detail: "recovery=\(healthManager.recoveryPercent) sleepMin=\(healthManager.sleepMinutes)"
                )
                StartupDiagnostics.markFirstScreenStableIfNeeded(
                    detail: "after today health refresh"
                )
            }
        }
        .task(id: todayViewModel.trackedDisplayDayStart) {
            guard tabIsActive else { return }

            let delay = todayViewModel.nextDayBoundary().timeIntervalSinceNow + 0.5
            guard delay > 0 else {
                reconcileTodayDayBoundary()
                return
            }

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                reconcileTodayDayBoundary()
            }
        }
        .onChange(of: plannedActivities) { _, newActivities in
            debugTodayDataState(source: "TodayView.onChange.plannedActivities")

            let validActivityIDs = Set(newActivities.map(\.id))
            quickLogSession.removeReferencesToMissingActivities(validActivityIDs: validActivityIDs)

            // DEFECT (fixed): previously ran coachInputProvider.refreshFromCurrentState
            // synchronously inside the SwiftUI update. That path mutates @Published state,
            // hits UserDefaults under NSLock (observation/understanding stores), and can
            // re-enter body while Root reconcile still holds the same MainActor — hang site
            // that often surfaces as the last logged marker being quickActionsSection begin.
            let selectedDate = selectedDate
            let healthManager = healthManager
            let nutritionViewModel = nutritionViewModel
            let coachCoordinator = coachCoordinator
            let coachInputProvider = coachInputProvider
            let todayViewModel = todayViewModel
            Task { @MainActor in
                let dayActivities = todayViewModel.selectedDayActivities(
                    on: selectedDate,
                    from: newActivities
                )
                // Reload HealthKit-published macros first, then refresh coach/nutrition so
                // meal add/delete can move consumed % without a stale seed.
                await todayViewModel.reconcileNutritionAfterPlannedActivitiesChange(
                    selectedDate: selectedDate,
                    plannedActivities: newActivities,
                    healthManager: healthManager,
                    nutritionViewModel: nutritionViewModel
                )
                coachInputProvider.refreshFromCurrentState(
                    selectedDate: selectedDate,
                    dayActivities: dayActivities,
                    allPlannedActivities: newActivities,
                    healthManager: healthManager,
                    nutritionViewModel: nutritionViewModel,
                    coachCoordinator: coachCoordinator,
                    source: "TodayView.plannedActivitiesChanged"
                )
            }

            scheduleMorningProposalRefresh()
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            debugTodayDataState(source: "TodayView.onChange.selectedDate old=\(oldValue) new=\(newValue)")

            let calendar = Calendar.current
            if !calendar.isDate(oldValue, inSameDayAs: newValue) {
                let dayStart = calendar.startOfDay(for: newValue)
                healthManager.prepareForDisplayDay(dayStart)
                nutritionViewModel.prepareForDay(newValue)
                todayViewModel.triggerHealthRefresh()
            }
        }
        let eventObserved = AnyView(healthObserved)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshTodayAfterAppBecameActive()
        }
        .task(id: todayMiddleClockID) {
            await refreshTodayMiddleClock()
        }
        .onChange(of: returnToTodayTrigger) { _, _ in
            handleReturnToTodayRequest()
        }
        .onChange(of: appSession.localDataResetTrigger) { _, _ in
            handleLocalDataResetCompleted()
        }
        .onReceive(NotificationCenter.default.publisher(for: .weekfitDidCompleteAppleSignIn)) { _ in
            // Sign in / Sign up with Apple from Profile → close settings and land on Today.
            showProfile = false
            handleReturnToTodayRequest()
            appSession.triggerReturnToToday()
        }
        .onReceive(confirmationState.$pendingActivity) { pending in
            guard let pending else { return }
            presentActivityConfirmation(pending)
            confirmationState.pendingActivity = nil
        }
        .onChange(of: tabIsActive) { _, isActive in
            guard isActive else { return }
            reconcileTodayDayBoundary()
            // Full reload is event-driven at root; boundary reconcile clears stale ring totals first.
            refreshTodayLiveState(refreshHealth: false)
        }
        .task(id: coachCoordinator.nextScheduledCheckpoint) {
            guard tabIsActive else { return }
            guard let checkpoint = coachCoordinator.nextScheduledCheckpoint else { return }
            let taskName = "today.coachCheckpoint"
            TodayStartupDiagnostics.taskBegin(taskName, detail: "checkpoint=\(checkpoint)")
            let delay = checkpoint.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            guard !Task.isCancelled else {
                TodayStartupDiagnostics.taskCancelled(taskName)
                return
            }

            await MainActor.run {
                let value = Date()
                todayViewModel.now = value

                let calendar = Calendar.current
                if !calendar.isDate(selectedDate, inSameDayAs: value) {
                    withAnimation(.smooth) {
                        selectedDate = value
                        todayViewModel.triggerHealthRefresh()
                    }
                }

                coachCoordinator.invalidateResolvedStateForDayChange()
                updateTodayCoachInsightIfNeeded(source: "CoachCoordinator.checkpoint")
            }
            TodayStartupDiagnostics.taskSuccess(taskName)
        }
        // Sheets/observers stay on root (not under Coach card) — stack-safe, no staged UI.
        let actionSheets = AnyView(eventObserved)
        .sheet(item: $activityToConfirm) { activity in
            missedConfirmationSheet(activity)
                .presentationDetents([.fraction(0.40)])
                .presentationDragIndicator(.visible)
                .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
        }
        .sheet(isPresented: $showProposalReview) {
            ProposalReviewView(
                dayKey: ProposalInputFingerprintBuilder.dayKey(for: Date()),
                onApplied: { _ in
                    morningProposalChromeHidden = true
                    refreshMorningProposal()
                    appSession.triggerCoachRefresh(source: "morningProposal.applied")
                },
                onDismissPlan: {
                    morningProposalChromeHidden = true
                    refreshMorningProposal()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: coachCoordinator.state.id) { _, _ in
            scheduleMorningProposalRefresh()
        }
        .onChange(of: healthManager.settledMetricsDayStart) { _, _ in
            scheduleMorningProposalRefresh()
        }
        .onChange(of: hasTodayRecoverySignals) { _, hasSignals in
            guard hasSignals else { return }
            scheduleMorningProposalRefresh()
        }
        .onChange(of: morningProposal?.id) { _, _ in
            morningProposalChromeHidden = false
        }
        .onChange(of: PendingMorningProposalReview.shared.shouldOpenReview) { _, shouldOpen in
            guard shouldOpen else { return }
            openPendingMorningProposalReviewIfNeeded()
        }
        .weekFitSettingsSheet(isPresented: $showProfile)
        .sheet(
            isPresented: $showDirectWorkoutLogSheet,
            onDismiss: {
                refreshTodayLiveState(refreshHealth: true)
            }
        ) {
            PremiumActivityStartSheet(
                background: QuickActionSheetDesign.Color.sheetBackground(for: .activity),
                cardBackground: WeekFitTheme.cardBackground,
                textSecondary: WeekFitTheme.secondaryText,
                isPresented: $showDirectWorkoutLogSheet,
                refreshID: healthRefreshBinding
            )
            .environmentObject(appSession)
            .environmentObject(coachCoordinator)
            .environmentObject(nutritionViewModel)
            .environmentObject(coachInputProvider)
            .environmentObject(activityCoordinator)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(
                cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius,
                background: QuickActionSheetDesign.Color.sheetBackground(for: .activity)
            )
        }
        .sheet(isPresented: $showDirectMealLogSheet) {
            ZStack {
                QuickActionSheetDesign.Color.sheetBackground(for: .food)
                    .ignoresSafeArea()

                QuickFoodLogSheet(
                    selectedTab: $selectedLogTab,
                    mealRows: quickLogMealRows,
                    frequentMealRows: quickLogFrequentMealRows,
                    recentMealRows: quickLogRecentMealRows,
                    snackRows: quickLogSnackRows,
                    frequentSnackRows: quickLogFrequentSnackRows,
                    recentSnackRows: quickLogRecentSnackRows,
                    session: quickLogSession,
                    logDate: selectedDate,
                    existingMeals: quickLogMealRows.map(\.meal),
                    onClose: { showDirectMealLogSheet = false },
                    onOpenMealsTab: {
                        showDirectMealLogSheet = false
                        onSelectTab(.meals)
                    },
                    onMealPlus: { meal in
                        handleQuickAdd(profile: QuickLogNutritionProfile.from(meal: meal))
                    },
                    onMealIncrement: { meal in
                        handleQuickIncrement(profile: QuickLogNutritionProfile.from(meal: meal))
                    },
                    onMealDecrement: { meal in
                        handleQuickDecrement(profile: QuickLogNutritionProfile.from(meal: meal))
                    },
                    onSnackPlus: { item in
                        handleQuickAdd(
                            profile: QuickLogNutritionProfile.from(item: item),
                            quickItem: item
                        )
                    },
                    onSnackIncrement: { item in
                        handleQuickIncrement(profile: QuickLogNutritionProfile.from(item: item))
                    },
                    onSnackDecrement: { item in
                        handleQuickDecrement(profile: QuickLogNutritionProfile.from(item: item))
                    },
                    onSaveLibraryMeal: { meal in
                        savePhotoLoggedMealToLibrary(meal)
                    },
                    onPhotoFoodLogged: {
                        showDirectMealLogSheet = false
                        refreshQuickLogMealsFromCatalog()
                    }
                )
            }
            // Food opens full-height so AI + frequent cards aren't clipped by the mid detent.
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(
                cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius,
                background: QuickActionSheetDesign.Color.sheetBackground(for: .food)
            )
            .onAppear {
                configureQuickLogSheetDismiss(closeMealSheet: true)
            }
        }
        .onChange(of: showDirectMealLogSheet) { _, isPresented in
            if isPresented {
                quickLogCommittedUsageIDs.removeAll()
                prepareQuickNutritionLogData()
            } else {
                ProductAnalytics.foodLoggingCancelIfNeeded()
                quickLogSession.reset()
                flushQueuedActivityConfirmationIfNeeded()
            }
        }
        .onChange(of: userSettings.customMealsCatalogRevision) { _, _ in
            refreshQuickLogMealsFromCatalog()
            scheduleMorningProposalRefresh()
        }
        .onChange(of: languageManager.selectedLanguage) { _, _ in
            refreshQuickLogLocalizedRows()
        }
        return AnyView(actionSheets)
        .sheet(isPresented: $showDirectDrinkLogSheet) {
            ZStack {
                QuickActionSheetDesign.Color.sheetBackground(for: .drinks)
                    .ignoresSafeArea()

                QuickDrinkLogSheet(
                    frequentRows: quickLogFrequentDrinkRows,
                    recentRows: quickLogRecentDrinkRows,
                    allRows: quickLogDrinkRows,
                    session: quickLogSession,
                    onClose: { showDirectDrinkLogSheet = false },
                    onPlusTap: { item in
                        handleQuickAdd(
                            profile: QuickLogNutritionProfile.from(item: item),
                            quickItem: item
                        )
                    },
                    onIncrement: { item in
                        handleQuickIncrement(profile: QuickLogNutritionProfile.from(item: item))
                    },
                    onDecrement: { item in
                        handleQuickDecrement(profile: QuickLogNutritionProfile.from(item: item))
                    }
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(
                cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius,
                background: QuickActionSheetDesign.Color.sheetBackground(for: .drinks)
            )
            .onAppear {
                configureQuickLogSheetDismiss(closeMealSheet: false)
            }
        }
        .onChange(of: showDirectDrinkLogSheet) { _, isPresented in
            if isPresented {
                quickLogCommittedUsageIDs.removeAll()
                prepareQuickDrinkLogData()
            } else {
                ProductAnalytics.hydrationLoggingCancelIfNeeded()
                quickLogSession.reset()
                flushQueuedActivityConfirmationIfNeeded()
            }
        }
        .onChange(of: showDirectWorkoutLogSheet) { _, isPresented in
            guard !isPresented else { return }
            ProductAnalytics.activityLoggingCancelIfNeeded()
            flushQueuedActivityConfirmationIfNeeded()
        }
        .onChange(of: showProfile) { _, isPresented in
            guard !isPresented else { return }
            flushQueuedActivityConfirmationIfNeeded()
        }
    }
    
    private func openActivityIntelligence() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        ProductAnalytics.todaySectionOpened(.activity)
        ProductAnalytics.trackScreen(.activityDetails)
        showActivityIntelligence = true
    }

    private func quickLogEmptyState(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String?,
        showAction: Bool
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color(red: 0.50, green: 0.74, blue: 0.54).opacity(0.82))

            Text(title)
                .font(QuickActionSheetDesign.Typography.emptyTitle)
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))

            Text(message)
                .font(QuickActionSheetDesign.Typography.emptyMessage)
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.42))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            if showAction, let buttonTitle {
                Button {
                    showDirectMealLogSheet = false

                    onSelectTab(.meals)
                } label: {
                    Text(buttonTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black.opacity(0.82))
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background {
                            Capsule()
                                .fill(Color(red: 0.50, green: 0.74, blue: 0.54))
                        }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
    }
    
    private func prepareQuickNutritionLogData() {
        let start = Self.debugStart("quickNutrition.prepare")
        let repository = NutritionRepository()
        let usageEntries = QuickItemUsageStore.load()
        let quickItems = repository.loadQuickItems()

        setQuickItemUsageEntries(usageEntries)
        refreshQuickLogMealsFromCatalog()
        setQuickLogSnacks(quickItems.filter { $0.category == .snack })
        Self.debugEnd(
            "quickNutrition.prepare meals=\(quickLogMeals.count) snacks=\(quickLogSnacks.count)",
            start: start
        )
    }

    private func refreshQuickLogLocalizedRows() {
        if !quickLogMeals.isEmpty {
            setQuickLogMeals(quickLogMeals)
        }
        if !quickLogSnacks.isEmpty {
            setQuickLogSnacks(quickLogSnacks)
        }
        if !quickLogDrinks.isEmpty {
            setQuickLogDrinks(quickLogDrinks)
        }
    }

    private func refreshQuickLogMealsFromCatalog() {
        // Keep Log Food → Meals in lockstep with Meals-tab library (meals + foods, no ingredients).
        let loggable = userSettings.customMealsCatalog.filter(\.appearsInQuickFoodLogMealsTab)
        setQuickLogMeals(loggable)
    }

    private func savePhotoLoggedMealToLibrary(_ meal: Meals) {
        let updated = CustomMealStore.upsert(meal, into: userSettings.customMealsCatalog)
        userSettings.replaceCustomMealsCatalog(updated)
        refreshQuickLogMealsFromCatalog()
    }

    private func preloadQuickFoodLogDataIfNeeded() {
        guard !didPreloadQuickFood else {
            refreshQuickLogMealsFromCatalog()
            return
        }
        didPreloadQuickFood = true
        prepareQuickNutritionLogData()
    }

    private func prepareQuickDrinkLogData() {
        let start = Self.debugStart("quickDrink.prepare")
        let usageEntries = QuickItemUsageStore.load()
        let drinks = NutritionRepository().loadQuickItems().filter { $0.category == .drink }

        setQuickItemUsageEntries(usageEntries)
        refreshDrinkPartitions(drinks: drinks, usage: usageEntries)
        Self.debugEnd(
            "quickDrink.prepare drinks=\(quickLogDrinks.count) frequent=\(quickLogFrequentDrinkRows.count) recent=\(quickLogRecentDrinkRows.count)",
            start: start
        )
    }

    private func preloadQuickDrinkLogDataIfNeeded() {
        guard !didPreloadQuickDrinks else { return }
        didPreloadQuickDrinks = true
        prepareQuickDrinkLogData()
    }

    private func refreshDrinkPartitions(
        drinks: [QuickItem],
        usage: [String: QuickItemUsageStore.Entry]
    ) {
        let temperatureC = morningWeatherSummary?.temperature.converted(to: .celsius).value
        let frequentPicks = QuickDrinkFrequentComposer.picks(
            drinks: drinks,
            usage: usage,
            now: Date(),
            temperatureCelsius: temperatureC
        )
        let frequentIDs = Set(frequentPicks.map(\.item.id))
        let partition = QuickItemUsageStore.partition(
            drinks: drinks,
            usage: usage,
            excludingFromRecent: frequentIDs
        )

        if quickLogDrinks != drinks {
            quickLogDrinks = drinks
        }

        let allRows = makeQuickItemRows(partition.all)
        if quickLogDrinkRows != allRows {
            quickLogDrinkRows = allRows
        }

        let frequentRows = frequentPicks.map { pick in
            QuickDrinkFrequentDisplayRow(
                row: QuickItemDisplayRow(
                    item: pick.item,
                    usesAssetImage: !pick.item.imageName.isEmpty && UIImage(named: pick.item.imageName) != nil
                ),
                badge: pick.badge
            )
        }
        if quickLogFrequentDrinkRows != frequentRows {
            quickLogFrequentDrinkRows = frequentRows
        }

        let recentRows = makeQuickItemRows(partition.recent)
        if quickLogRecentDrinkRows != recentRows {
            quickLogRecentDrinkRows = recentRows
        }
    }

    private func sortByUsage(_ items: [QuickItem], usage: [String: Int]) -> [QuickItem] {
        return items.sorted {
            let left = usage[$0.id, default: 0]
            let right = usage[$1.id, default: 0]

            if left == right {
                return $0.title < $1.title
            }

            return left > right
        }
    }

    private func setQuickItemUsageEntries(
        _ entries: [String: QuickItemUsageStore.Entry],
        persist: Bool = false
    ) {
        guard quickItemUsageEntries != entries else { return }
        quickItemUsageEntries = entries

        if persist {
            QuickItemUsageStore.save(entries)
        }
    }

    private func setQuickLogMeals(_ meals: [Meals]) {
        if quickLogMeals != meals {
            quickLogMeals = meals
        }
        refreshMealPartitions(meals: meals, usage: quickItemUsageEntries)
    }

    private func setQuickLogSnacks(_ snacks: [QuickItem]) {
        if quickLogSnacks != snacks {
            quickLogSnacks = snacks
        }
        refreshSnackPartitions(snacks: snacks, usage: quickItemUsageEntries)
    }

    private func refreshSnackPartitions(
        snacks: [QuickItem],
        usage: [String: QuickItemUsageStore.Entry]
    ) {
        let frequentPicks = QuickSnackFrequentComposer.picks(snacks: snacks, usage: usage)
        let frequentIDs = Set(frequentPicks.map(\.item.id))
        let partition = QuickItemUsageStore.partition(
            drinks: snacks,
            usage: usage,
            excludingFromRecent: frequentIDs
        )

        if quickLogSnacks != snacks {
            quickLogSnacks = snacks
        }

        let allRows = makeQuickItemRows(partition.all)
        if quickLogSnackRows != allRows {
            quickLogSnackRows = allRows
        }

        let frequentRows = frequentPicks.map {
            QuickFoodFrequentSnackRow(
                row: QuickItemDisplayRow(
                    item: $0.item,
                    usesAssetImage: !$0.item.imageName.isEmpty && UIImage(named: $0.item.imageName) != nil
                ),
                badgeKey: $0.badge.localizationKey,
                badgeSymbol: $0.badge.symbolName
            )
        }
        if quickLogFrequentSnackRows != frequentRows {
            quickLogFrequentSnackRows = frequentRows
        }

        let recentRows = makeQuickItemRows(partition.recent)
        if quickLogRecentSnackRows != recentRows {
            quickLogRecentSnackRows = recentRows
        }
    }

    private func refreshMealPartitions(
        meals: [Meals],
        usage: [String: QuickItemUsageStore.Entry]
    ) {
        let frequentPicks = QuickMealFrequentComposer.picks(meals: meals, usage: usage)
        let frequentIDs = Set(frequentPicks.map(\.meal.id))

        let allRows = makeQuickMealRows(meals)
        if quickLogMealRows != allRows {
            quickLogMealRows = allRows
        }

        let frequentRows = frequentPicks.map {
            QuickFoodFrequentMealRow(
                row: makeQuickMealRows([$0.meal])[0],
                badgeKey: $0.badge.localizationKey,
                badgeSymbol: $0.badge.symbolName
            )
        }
        if quickLogFrequentMealRows != frequentRows {
            quickLogFrequentMealRows = frequentRows
        }

        let recentMealIDs = usage
            .filter { entry in
                entry.value.lastUsedAt > .distantPast
                    && !frequentIDs.contains(entry.key)
                    && meals.contains(where: { $0.id == entry.key })
            }
            .sorted { $0.value.lastUsedAt > $1.value.lastUsedAt }
            .prefix(6)
            .map(\.key)

        let recentMeals = recentMealIDs.compactMap { id in meals.first(where: { $0.id == id }) }
        let recentRows = makeQuickMealRows(recentMeals)
        if quickLogRecentMealRows != recentRows {
            quickLogRecentMealRows = recentRows
        }
    }

    private func setQuickLogDrinks(_ drinks: [QuickItem]) {
        refreshDrinkPartitions(drinks: drinks, usage: quickItemUsageEntries)
    }

    private func makeQuickItemRows(_ items: [QuickItem]) -> [QuickItemDisplayRow] {
        items.map { item in
            QuickItemDisplayRow(
                item: item,
                usesAssetImage: !item.imageName.isEmpty && UIImage(named: item.imageName) != nil
            )
        }
    }

    private func makeQuickMealRows(_ meals: [Meals]) -> [QuickMealDisplayRow] {
        meals.map { QuickMealDisplayRow.make(from: $0) }
    }

    private func quickMealPhotoFilename(for meal: Meals) -> String? {
        [
            meal.localPhotoThumbnailFilename,
            meal.localPhotoFilename
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty }
    }

    private func updateTodayCoachInsightIfNeeded(source: String) {
        debugTodayDataState(source: "todayCoachInsight.update.\(source)")
        WeekFitActivityCoordinator.shared.syncHeartRateMonitoring(with: selectedDayActivities)
        todayViewModel.refreshCoachInsight(
            selectedDate: selectedDate,
            plannedActivities: plannedActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachCoordinator: coachCoordinator,
            coachInputProvider: coachInputProvider,
            source: source
        )
    }

    private func debugTodayDataState(source: String) {
        #if DEBUG
        guard CoachDebugSettings.todayDataAuditEnabled else { return }

        let calendar = Calendar.current
        let currentDate = Date()
        let snapshot = nutritionViewModel.coachMetricsSnapshot
        let metrics = nutritionViewModel.currentMetrics
        let result = nutritionViewModel.nutritionResult
        let selectedActivities = selectedDayActivities
        let plannedMeals = selectedActivities.filter { $0.type.lowercased() == "meal" }
        let completedMeals = plannedMeals.filter(\.isCompleted)
        let activityGoal = automatedActivityGoal
        let nutritionTarget = nutritionViewModel.nutritionBudget.totalCalories
        Self.logger.debug(
            """
            [TodayDataAudit] source=\(source, privacy: .public) currentDate=\(currentDate, privacy: .public) selectedDate=\(selectedDate, privacy: .public) selectedIsToday=\(calendar.isDate(selectedDate, inSameDayAs: currentDate), privacy: .public) dailySnapshotDate=\(String(describing: snapshot?.createdAt), privacy: .public) snapshotSource=\(snapshot?.source ?? "nil", privacy: .public) plannedActivities=\(selectedActivities.count, privacy: .public) allPlannedActivities=\(plannedActivities.count, privacy: .public) plannedMeals=\(plannedMeals.count, privacy: .public) completedMeals=\(completedMeals.count, privacy: .public) recoveryInputs sleepMinutes=\(healthManager.sleepMinutes, privacy: .public) sleepHours=\(healthManager.sleepHours, privacy: .public) hrv=\(healthManager.hrvSDNN, privacy: .public) rhr=\(healthManager.restingHeartRate, privacy: .public) recovery=\(healthManager.recoveryPercent, privacy: .public) recoveryBreakdown=\(String(describing: healthManager.recoveryBreakdown), privacy: .public) nutritionInputs hkCalories=\(healthManager.calories, privacy: .public) hkProtein=\(healthManager.protein, privacy: .public) hkCarbs=\(healthManager.carbs, privacy: .public) hkFats=\(healthManager.fats, privacy: .public) hkWater=\(healthManager.waterLiters, privacy: .public) metricsCalories=\(metrics?.calories ?? -1, privacy: .public) metricsProtein=\(metrics?.protein ?? -1, privacy: .public) metricsCarbs=\(metrics?.carbs ?? -1, privacy: .public) metricsWater=\(metrics?.waterLiters ?? -1, privacy: .public) nutritionTarget=\(nutritionTarget, privacy: .public) nutritionPercent=\(nutritionViewModel.nutritionPercent, privacy: .public) activityInputs activeCalories=\(healthManager.activeCalories, privacy: .public) steps=\(healthManager.steps, privacy: .public) exerciseMinutes=\(healthManager.exerciseMinutes, privacy: .public) activityGoal=\(activityGoal, privacy: .public) activityProgress=\(activityGoal > 0 ? healthManager.activeCalories / activityGoal : 0, privacy: .public) lastHealthKitSync=\(String(describing: healthManager.lastHealthKitSyncTime), privacy: .public)
            """
        )
        #endif
    }

    private static let logger = Logger(subsystem: "WeekFit", category: "TodayView")

    private static func debugStart(_ label: String) -> CFAbsoluteTime {
        #if DEBUG
        guard CoachDebugSettings.todayDataAuditEnabled else { return 0 }

        let start = CFAbsoluteTimeGetCurrent()
        logger.debug("\(label, privacy: .public) start")
        return start
        #else
        return 0
        #endif
    }

    private static func debugEnd(_ label: String, start: CFAbsoluteTime) {
        #if DEBUG
        guard CoachDebugSettings.todayDataAuditEnabled, start > 0 else { return }

        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.debug("\(String(format: "%@ end %.1fms", label, elapsed), privacy: .public)")
        #endif
    }

    private func logTodayCoachInsightHiddenIfNeeded() {
        guard let reason = coachCoordinator.state.todayCoachInsightHiddenReason else { return }
        CoachLogger.compact(
            "[TodayCoachInsight]",
            "hidden reason=\(reason.rawValue) status=\(coachCoordinator.state.statusLogLabel) usingCoach=\(coachCoordinator.state.coachUIPresentation != nil ? "yes" : "no") todayTitle=\"\(coachCoordinator.state.coachUIPresentation?.todayTitle ?? "")\""
        )
    }
    
    private func quickItem(for profile: QuickLogNutritionProfile) -> QuickItem? {
        quickLogSnacks.first(where: { $0.id == profile.id })
            ?? quickLogDrinks.first(where: { $0.id == profile.id })
    }

    private func configureQuickLogSheetDismiss(closeMealSheet: Bool) {
        quickLogSession.onSheetDismissRequest = { itemID in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            presentQuickLogToast(for: itemID, isDrinkSheet: !closeMealSheet)
            if closeMealSheet {
                showDirectMealLogSheet = false
            } else {
                showDirectDrinkLogSheet = false
            }
        }
    }

    private func presentQuickLogToast(for itemID: String, isDrinkSheet: Bool) {
        guard let profile = quickLogProfile(for: itemID) else { return }

        let selection = quickLogSession.selection(for: itemID)
        guard selection.isSelected else { return }

        commitQuickItemUsageIfNeeded(itemID: itemID, selection: selection)

        let message = QuickLogToastMessage.make(profile: profile, selection: selection)

        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
            if isDrinkSheet {
                drinksQuickLogToast = message
            } else {
                foodQuickLogToast = message
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                if isDrinkSheet {
                    drinksQuickLogToast = nil
                } else {
                    foodQuickLogToast = nil
                }
            }
        }
    }

    private func quickLogProfile(for itemID: String) -> QuickLogNutritionProfile? {
        if let meal = quickLogMeals.first(where: { $0.id == itemID }) {
            return QuickLogNutritionProfile.from(meal: meal)
        }

        if let item = quickLogSnacks.first(where: { $0.id == itemID })
            ?? quickLogDrinks.first(where: { $0.id == itemID }) {
            return QuickLogNutritionProfile.from(item: item)
        }

        return nil
    }

    private func commitQuickItemUsageIfNeeded(itemID: String, selection: QuickLogSelection) {
        guard selection.portions > 0 else { return }
        guard !quickLogCommittedUsageIDs.contains(itemID) else { return }

        if let meal = quickLogMeals.first(where: { $0.id == itemID }) {
            incrementMealUsage(meal)
            quickLogCommittedUsageIDs.insert(itemID)
            return
        }

        guard let item = quickLogSnacks.first(where: { $0.id == itemID })
            ?? quickLogDrinks.first(where: { $0.id == itemID }) else {
            return
        }

        incrementQuickItemUsage(item)
        quickLogCommittedUsageIDs.insert(itemID)
    }

    private func handleQuickAdd(profile: QuickLogNutritionProfile, quickItem: QuickItem? = nil) {
        let selection = quickLogSession.quickAdd(profile: profile)
        syncQuickLogSelection(profile: profile, selection: selection, quickItem: quickItem)
    }

    private func handleQuickIncrement(profile: QuickLogNutritionProfile) {
        quickLogSession.increment(profile: profile)
        let selection = quickLogSession.selection(for: profile.id)
        syncQuickLogSelection(profile: profile, selection: selection, quickItem: quickItem(for: profile))
    }

    private func handleQuickDecrement(profile: QuickLogNutritionProfile) {
        let previousActivityID = quickLogSession.selection(for: profile.id).loggedActivityID
        quickLogSession.decrement(profile: profile)
        let selection = quickLogSession.selection(for: profile.id)
        var syncSelection = selection
        if !selection.isSelected {
            syncSelection.loggedActivityID = previousActivityID
        }
        syncQuickLogSelection(profile: profile, selection: syncSelection, quickItem: quickItem(for: profile))
    }

    private func syncQuickLogSelection(
        profile: QuickLogNutritionProfile,
        selection: QuickLogSelection,
        quickItem: QuickItem? = nil
    ) {
        let activityID = QuickLogActivitySync.sync(
            profile: profile,
            selection: selection,
            plannedActivities: plannedActivities,
            modelContext: modelContext
        )

        if let activityID {
            quickLogSession.attachActivityID(activityID, to: profile.id)
        } else {
            quickLogSession.clearActivityID(for: profile.id)
        }

        updateNutrition()
        todayViewModel.triggerHealthRefresh()
    }

    private var todayScreen: some View {
        let _ = TodayStartupDiagnostics.child("todayScreen begin")
        return WeekFitScreenContainer(headerBottomSpacing: 12) {

            let _ = TodayStartupDiagnostics.child("header WeekFitTodayWeatherHeader")
            WeekFitTodayWeatherHeader(
                title: WeekFitLocalizedString("today.title"),
                subtitle: selectedDateTitle,
                initials: userSettings.profileInitials,
                hasProfileName: userSettings.hasProfileName,
                onAvatarTap: {
                    showProfile = true
                }
            )

        } content: {

            ScrollView(.vertical, showsIndicators: false) {
                todayScrollContent
                    .padding(.top, TodayLayout.contentTopInset)
                    .padding(.bottom, 4)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Transparent — same atmosphere plane as the weather header.
            // Opaque canvas fill here painted a black/white slab over the glows.
            .weekFitTransparentScrollBackground(fillsCanvas: false)
        }
        // Reserve the floating tab bar footprint so the last card can scroll fully clear.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: 74)
                .accessibilityHidden(true)
        }
        // One geometry group: ancestor tab animation can't move each card on its own.
        .geometryGroup()
    }

    /// Full Today stack at once — AnyView only for stack-safe type erasure, no staged reveal.
    private var todayScrollContent: some View {
        AnyView(summaryContent())
    }

    @ViewBuilder
    private var todayBackground: some View {
        let _ = TodayStartupDiagnostics.child(
            "todayBackground",
            detail: "atmosphereEnabled=\(TodayAtmospherePolicy.isEnabled)"
        )
        if TodayAtmospherePolicy.isEnabled {
            // Root shell already paints `TodayAtmosphereBackground` for every tab.
            Color.clear
        } else {
            WeekFitTheme.appBackground
                .ignoresSafeArea()
            ambientBackground
        }
    }

    private var ambientBackground: some View {
        WeekFitTheme.todayAmbient
            .opacity(palette.ambientOpacity)
            .ignoresSafeArea()
    }
    

    private func summaryContent() -> AnyView {
        let _ = TodayStartupDiagnostics.step(5, "first section created", detail: "summaryContent begin")
        let now = todayViewModel.now
        let activeSession = currentStartedSession(now: now)
        let upcoming = activeSession == nil ? nextUpcomingPlannedActivity(now: now) : nil
        let mode = todayStackMode(activeSession: activeSession, upcoming: upcoming)

        return AnyView(
            VStack(alignment: .leading, spacing: TodayLayout.gapBetweenCards) {
                if let sessionFinishErrorToast {
                    Button {
                        retryFinishIfNeeded()
                    } label: {
                        todayTransientBanner(
                            text: sessionFinishErrorToast,
                            accessibilityID: "today.sessionFinishErrorToast",
                            isError: true
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(WeekFitLocalizedString("today.session.saveFailedRetryHint"))
                }

                MissingSleepMorningNoticeHost(
                    surface: .today,
                    now: todayViewModel.now,
                    isHealthAccessGranted: healthManager.isHealthAccessGranted,
                    hasSettledMetrics: healthManager.hasSettledMetrics(for: selectedDate),
                    isLoadingMetrics: healthManager.isLoadingDisplayDayMetrics,
                    sleepReadConfirmed: healthManager.sleepSampleReadConfirmed,
                    hasSleepRecords: healthManager.sleepMinutes > 0 || healthManager.timeInBedMinutes > 0,
                    isScreenActive: tabIsActive,
                    onCheckConnection: { appSession.presentHealthAccess() }
                )

                if !todayIntroDismissed {
                    let _ = TodayStartupDiagnostics.child("OnboardingContextualIntroCard")
                    OnboardingContextualIntroCard(
                        title: WeekFitLocalizedString("onboarding.intro.today.title"),
                        message: WeekFitLocalizedString("onboarding.intro.today.body"),
                        accent: WeekFitTheme.workout
                    ) {
                        todayIntroDismissed = true
                    }
                }

                let _ = TodayStartupDiagnostics.child("dailyStatusSection begin")
                AnyView(dailyStatusSection)
                let _ = TodayStartupDiagnostics.child("dailyStatusSection complete")

                if plannerVoiceEnabled {
                    MayaPearlCallCard(isReturning: showPlannerVoice) {
                        openMayaCall()
                    }
                }

                switch mode {
                case .activeSession:
                    // Your Day → In Progress → Quick Log. Hide Focus / Up next while live.
                    if let activeSession {
                        AnyView(activeSessionCard(activeSession))
                    }
                    AnyView(quickActionsSection)

                case .upcoming:
                    if let upcoming {
                        AnyView(upcomingActivityCard(upcoming, now: now))
                    }
                    AnyView(quickActionsSection)

                case .idle:
                    erasedCoachEntryPoint()
                    AnyView(quickActionsSection)
                }
            }
        )
    }

    /// Type-erasure only — Coach paints with the rest of Today, no delayed reveal.
    private func erasedCoachEntryPoint() -> AnyView {
        let _ = TodayStartupDiagnostics.child(
            "coachEntryPointSection",
            detail: "phase=\(String(describing: todayCoachInsightPhase)) status=\(coachCoordinator.state.statusLogLabel)"
        )
        return AnyView(coachInsightWithOptionalProposalOverlay)
    }

    /// Pending confirmations take the Up Next slot; Coach stays visible separately.
    private func erasedPlanAttentionSlot(
        now: Date,
        upcoming: PlannedActivity?,
        excludingActivityID: String? = nil
    ) -> AnyView? {
        let pending = pendingConfirmationActivities(
            now: now,
            excludingActivityID: excludingActivityID
        )
        if !pending.isEmpty {
            return AnyView(pendingConfirmationStack(pending))
        }
        if let upcoming {
            return AnyView(upcomingActivityCard(upcoming, now: now))
        }
        return nil
    }

    private func todayStackMode(
        activeSession: PlannedActivity?,
        upcoming: PlannedActivity?
    ) -> TodayStackMode {
        if activeSession != nil { return .activeSession }
        if upcoming != nil { return .upcoming }
        return .idle
    }

    private func todayTransientBanner(
        text: String,
        accessibilityID: String,
        isError: Bool = false
    ) -> some View {
        Text(text)
            .font(WeekFitType.secondary.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(isError ? Color.red.opacity(0.92) : textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TodayLayout.cardInteriorVerticalPadding)
            .padding(.vertical, 12)
            .todaySurface(elevated: true, cornerRadius: TodayLayout.cardRadius)
            .accessibilityIdentifier(accessibilityID)
            .accessibilityAddTraits(.isStaticText)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func todayCardSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(TodayCardTypography.sectionLabel)
            .foregroundStyle(todaySectionTitleColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todaySupportingCardChevron(color: Color) -> some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(color.opacity(0.72))
            .accessibilityHidden(true)
    }

    private func todayPremiumCard<Content: View>(
        accent: Color?,
        cornerRadius: CGFloat = TodayLayout.cardRadius,
        featured: Bool = true,
        coachEmphasis: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let _ = accent
        return content()
            .todaySurface(
                elevated: featured,
                coachEmphasis: coachEmphasis,
                cornerRadius: cornerRadius
            )
    }

    /// Quick-log surface — same quiet navy family as Overview / Plan.
    private func todayActionSurfaceCard<Content: View>(
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let _ = accent
        return content()
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .todaySurface(elevated: false, cornerRadius: TodayLayout.cardRadius)
    }

    private var todayQuickActionsAccent: Color {
        if coachCoordinator.state.canRenderTodayCoachInsight {
            return coachCoordinator.state.coachUIPresentation?.accentColor ?? WeekFitTheme.coachAccent
        }
        return WeekFitTheme.coachAccent
    }

    private var todayCoachCardAccent: Color {
        coachCoordinator.state.coachUIPresentation?.accentColor ?? WeekFitTheme.coachAccent
    }

    private func todayOverviewShell<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, TodayLayout.overviewHorizontalPadding)
            .padding(.top, TodayLayout.overviewContentTopPadding)
            .padding(.bottom, TodayLayout.overviewContentBottomPadding)
            .frame(maxWidth: .infinity)
            .todaySurface(elevated: true, cornerRadius: TodayLayout.cardRadius)
    }

    private var todayCoachInsightPhase: TodayCoachInsightPhase {
        TodayCoachInsightResolver.resolve(
            TodayCoachInsightResolver.Input(
                coachState: coachCoordinator.state,
                cachedPresentation: CoachTodayInsightCache.presentation(
                    for: selectedDate,
                    languageCode: todayCoachInsightLanguageCode
                ),
                shouldShowHealthConnectPrompt: shouldShowHealthConnectPrompt,
                hasRecoverySignals: hasTodayRecoverySignals,
                isHealthMetricsSettled: healthManager.hasSettledMetrics(for: selectedDate)
            )
        )
    }

    private var todayCoachInsightLanguageCode: String {
        languageManager.selectedLanguage.rawValue
    }

    private func coachSettlingCard(
        needsHealthConnect: Bool,
        useSyncingCopy: Bool = false
    ) -> some View {
        // Shallow extracted body — no nested Button / forever animations on @State
        // (repeatForever livePulse was invalidating Today body continuously).
        TodayCoachSettlingCardBody(
            focusHeading: todayCoachFocusHeading(),
            needsHealthConnect: needsHealthConnect,
            useSyncingCopy: useSyncingCopy,
            accent: todayCoachCardAccent,
            textPrimary: textPrimary,
            textSecondary: todaySecondaryReadable,
            meta: todayMetaReadable
        )
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            ProductAnalytics.todayPrimaryActionTapped(.coach)
            onSelectTab(.coach)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(WeekFitLocalizedString("today.coachInsight.opensCoach"))
        .todaySurface(elevated: true, coachEmphasis: true, cornerRadius: TodayLayout.cardRadius)
        .onAppear {
            logTodayCoachInsightHiddenIfNeeded()
        }
    }

    private var todayLimitedRecoveryChip: some View {
        Text(AppText.Today.coachChipLimitedRecovery)
            .font(.caption2.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(todaySecondaryReadable)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(WeekFitTheme.whiteOpacity(0.05))
            )
            .overlay(
                Capsule()
                    .stroke(WeekFitTheme.whiteOpacity(0.08), lineWidth: 1)
            )
    }

    private var todayRecoveryChallengeCue: TodayRecoveryChallengeCue? {
        guard RecoveryChallengeConfig.isFeatureAvailable else { return nil }
        switch RecoveryChallengeStore.headerEntry() {
        case .hidden:
            return nil
        case .invite:
            return TodayRecoveryChallengeCue(
                label: WeekFitLocalizedString("today.coach.challenge.invite"),
                showsCheckmark: false
            )
        case .participating(let active):
            return TodayRecoveryChallengeCue(
                label: String(
                    format: WeekFitLocalizedString("today.coach.challenge.dayOf"),
                    active.dayIndex,
                    RecoveryChallengeConfig.dayCount
                ),
                showsCheckmark: active.todayCompleted
            )
        case .summary(let summary):
            return TodayRecoveryChallengeCue(
                label: String(
                    format: WeekFitLocalizedString("today.coach.challenge.finishedCount"),
                    summary.completedCount,
                    RecoveryChallengeConfig.dayCount
                ),
                showsCheckmark: true
            )
        }
    }

    private func todayRecoveryChallengeStatusRow(_ cue: TodayRecoveryChallengeCue) -> some View {
        // Status-only cue — no chevron / no direct sheet open. Whole Coach card
        // navigates to the Coach tab; challenge opens from there.
        HStack(spacing: 8) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(todaySecondaryReadable)
                .frame(width: 40, alignment: .center)
                .accessibilityHidden(true)

            Text(cue.label)
                .font(.caption.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(todaySecondaryReadable)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if cue.showsCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(textTertiary.opacity(0.90))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
    }

    private var plannedActivitiesForSelectedDate: [PlannedActivity] {
        plannedActivities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }
    
    private func pendingConfirmationStack(_ activities: [PlannedActivity]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(activities, id: \.id) { activity in
                pendingConfirmationCard(activity)
            }
        }
    }

    private func pendingConfirmationCard(_ activity: PlannedActivity) -> some View {
        let title = activityDisplayTitle(activity)
        return TodayPendingActivityConfirmCard(
            title: title,
            message: String(
                format: WeekFitLocalizedString("today.pending.messageFormat"),
                title
            ),
            pendingTitle: String(localized: AppText.Today.pendingActionTitle),
            textPrimary: textPrimary,
            cardBackground: cardBackground
        ) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            presentActivityConfirmation(activity)
        }
        .accessibilityIdentifier("today.pendingConfirmation.\(activity.id)")
    }

    /// Overdue unfinished day activities that still need confirm/skip — same rule as before
    /// the type allowlist (habits and other planner slots included; matches Plan `.pending`).
    private func pendingConfirmationActivities(
        now: Date,
        excludingActivityID: String? = nil
    ) -> [PlannedActivity] {
        selectedDayActivities.filter { activity in
            if let excludingActivityID, activity.id == excludingActivityID {
                return false
            }
            let eventEndDate = Calendar.current.date(
                byAdding: .minute,
                value: activity.effectiveDurationMinutes,
                to: activity.date
            ) ?? activity.date

            return activity.terminalState(now: now) == .planned
                && now > eventEndDate
                && !isCoveredByActiveSession(activity)
        }
    }

    private var shouldShowEveningReview: Bool {
        let now = Date()
        let calendar = Calendar.current

        let hour = calendar.component(.hour, from: now)
        guard hour >= 23 else { return false }

        guard let lastPlannedActivity = reviewRelevantActivities.max(by: {
            $0.date < $1.date
        }) else {
            return true
        }

        let lastActivityEnd = calendar.date(
            byAdding: .minute,
            value: lastPlannedActivity.durationMinutes + 15,
            to: lastPlannedActivity.date
        ) ?? lastPlannedActivity.date

        guard now >= lastActivityEnd else { return false }

        return !hasUnresolvedActivities
    }
    
    private var reviewRelevantActivities: [PlannedActivity] {
        plannedActivitiesForSelectedDate.filter { activity in
            activity.source != "today" &&
            activity.imageName != "hydration"
        }
    }
    
    private var hasUnresolvedActivities: Bool {
        reviewRelevantActivities.contains { activity in
            !activity.isCompleted &&
            !activity.isSkipped
        }
    }
    
    private var eveningReviewEntryPoint: some View {
        let coachAccent = Color(red: 0.55, green: 0.40, blue: 0.85)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            onSelectTab(.coach)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(WeekFitTheme.coachAccent.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.coachAccent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(AppText.Today.eveningReviewReady)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)

                    Text(AppText.Today.eveningReviewSubtitle)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(todaySecondaryReadable)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(textTertiary)
            }
            .padding(14)
            .background(cardBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(WeekFitTheme.coachAccent.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var remainingCaloriesText: String {
        let budget = todayNutritionBudget

        if TodayNutritionDisplayMetrics.isOverBudget(budget) {
            return String(
                format: WeekFitLocalizedString("today.calories.overFormat"),
                TodayNutritionDisplayMetrics.remainingCalories(from: budget)
            )
        }

        return String(
            format: WeekFitLocalizedString("today.calories.leftFormat"),
            TodayNutritionDisplayMetrics.remainingCalories(from: budget)
        )
    }

    /// Active Energy progress label: percent below goal, concise multiple at/above.
    private func activityRingCenterText(progress: Double, percent: Int) -> String {
        if progress >= 1.0 {
            let multiple = progress
            if multiple >= 9.95 {
                return String(
                    format: WeekFitLocalizedString("today.status.activity.multipleWholeFormat"),
                    Int(multiple.rounded())
                )
            }
            let nearestWhole = multiple.rounded()
            if abs(multiple - nearestWhole) < 0.05 {
                return String(
                    format: WeekFitLocalizedString("today.status.activity.multipleWholeFormat"),
                    Int(nearestWhole)
                )
            }
            return String(
                format: WeekFitLocalizedString("today.status.activity.multipleTenthsFormat"),
                multiple
            )
        }
        if healthManager.activeCalories > 0 && progress > 0 && progress < 0.01 {
            return "<1%"
        }
        return "\(percent)%"
    }

    private func sleepDurationDisplayText(minutes: Int) -> String {
        guard minutes > 0 else {
            return WeekFitLocalizedString("today.sleep.empty")
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return String(
            format: WeekFitLocalizedString("today.sleep.hoursMinutesFormat"),
            hours,
            mins
        )
    }

    private var isEveningCoachFocusWindow: Bool {
        let hour = Calendar.current.component(.hour, from: todayViewModel.now)
        return hour >= 18
    }

    private func todayCoachFocusHeading() -> String {
        WeekFitLocalizedString(
            isEveningCoachFocusWindow
                ? "today.coachInsight.focusTonight"
                : "today.coachInsight.focusToday"
        )
    }

    private func todayCoachDisplayIcon(for presentation: CoachUIPresentation) -> String {
        switch presentation.scenario {
        case .tomorrowProtection,
             .protectTomorrowFresh,
             .walkEveningWindDown,
             .eveningAfterEndurance,
             .eveningAfterRacket,
             .eveningAfterStrength,
             .eveningAfterRecovery:
            return "moon.fill"
        default:
            break
        }
        if isEveningCoachFocusWindow,
           presentation.icon.hasPrefix("figure.") || presentation.icon.contains("bicycle") {
            return "moon.fill"
        }
        return presentation.icon
    }

    private func todayCoachFocusAccent(
        for presentation: CoachUIPresentation,
        displayIcon: String
    ) -> Color {
        // Evening focus mockup: lavender icon well for wind-down / recovery stance.
        switch presentation.scenario {
        case .walkEveningWindDown,
             .eveningAfterEndurance,
             .eveningAfterRacket,
             .eveningAfterStrength,
             .eveningAfterRecovery,
             .protectTomorrowFresh,
             .tomorrowProtection:
            return WeekFitProgressRingColor.recovery
        default:
            break
        }
        if displayIcon == "moon.fill" || displayIcon.contains("brain") {
            return WeekFitProgressRingColor.recovery
        }
        return presentation.accentColor
    }

    /// Duration pill only when a real planned focus duration exists (never invented).
    private func todayCoachFocusDurationLabel(for presentation: CoachUIPresentation) -> String? {
        switch presentation.scenario {
        case .walkEveningWindDown,
             .eveningAfterEndurance,
             .eveningAfterRacket,
             .eveningAfterStrength,
             .eveningAfterRecovery,
             .protectTomorrowFresh,
             .tomorrowProtection:
            break
        default:
            return nil
        }

        let now = todayViewModel.now
        let calendar = Calendar.current
        let recoveryTypes: Set<String> = [
            "recovery", "mobility", "stretch", "breath", "breathwork",
            "meditation", "yoga", "walk", "cool"
        ]
        let candidates = plannedActivities.filter { activity in
            guard calendar.isDate(activity.date, inSameDayAs: now) else { return false }
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            return recoveryTypes.contains(activity.type.lowercased())
                || activity.title.lowercased().contains("wind")
                || activity.title.lowercased().contains("breath")
        }
        guard let activity = candidates.sorted(by: { $0.date < $1.date }).first else { return nil }
        let minutes = max(activity.actualDurationMinutes ?? 0, activity.effectiveDurationMinutes)
        guard minutes > 0 else { return nil }
        return String(
            format: WeekFitLocalizedString("common.unit.minutesFormat"),
            Int64(minutes)
        )
    }

    private var dailyStatusSection: some View {
        let _ = TodayStartupDiagnostics.child(
            "dailyStatusSection compute",
            detail: "calories=\(healthManager.activeCalories) sleepMin=\(healthManager.sleepMinutes) recovery=\(healthManager.recoveryPercent) hrv=\(healthManager.hrvSDNN) rhr=\(healthManager.restingHeartRate)"
        )
        let baseGoal = automatedActivityGoal
        let _ = TodayStartupDiagnostics.child("dailyStatusSection activityGoal=\(baseGoal)")
        let activityProgress = baseGoal > 0 ? healthManager.activeCalories / baseGoal : 0
        let activityPercent = Int((activityProgress * 100).rounded())
        let activityDisplayText = activityRingCenterText(progress: activityProgress, percent: activityPercent)
        let activityAccessibilityProgress = String(
            format: WeekFitLocalizedString("today.status.activity.accessibilityProgressFormat"),
            activityPercent
        )

        let budget = todayNutritionBudget
        let eatenCalories = TodayNutritionDisplayMetrics.consumedCalories(from: budget)
        let nutritionPercent = TodayNutritionDisplayMetrics.progressPercent(from: budget)

        let hasRecoveryData = hasTodayRecoverySignals

        let recoveryPercent = healthManager.recoveryPercent

        let recoveryRingMode = CoachInputReadiness.recoveryRingMode(
            isHealthAccessGranted: healthManager.isHealthAccessGranted,
            hasRecoverySignals: hasRecoveryData,
            now: todayViewModel.now
        )
        let _ = TodayStartupDiagnostics.child(
            "dailyStatusSection recoveryRingMode",
            detail: "\(String(describing: recoveryRingMode)) hasSignals=\(hasRecoveryData)"
        )

        let recoveryDisplayValue: Int? =
            recoveryRingMode == .hasData ? recoveryPercent : nil

        let activityColor = todayActivityColor
        let nutritionColor = todayNutritionColor
        let recoveryColor = recoveryRingMode == .sleepNotRecorded
            ? todaySecondaryReadable.opacity(0.58)
            : todayRecoveryColor

        let activityGoalText = String(format: WeekFitLocalizedString("today.status.activity.goalFormat"), Int(baseGoal))
        let activityValueText = String(format: WeekFitLocalizedString("common.unit.caloriesFormat"), Int(healthManager.activeCalories))

        let sleepValueInfoText = sleepDurationDisplayText(minutes: healthManager.sleepMinutes)

        // Mockup order: status (accent) then sleep (meta).
        let confirmedMissingSleep = recoveryRingMode == .sleepNotRecorded
            && healthManager.hasSettledMetrics(for: selectedDate)
            && !healthManager.isLoadingDisplayDayMetrics
            && healthManager.sleepSampleReadConfirmed
        let recoveryStatusRingText: String = {
            if confirmedMissingSleep {
                return WeekFitLocalizedString("today.missingSleepNotice.title")
            }
            switch recoveryRingMode {
            case .hasData:
                return recoveryStatusLabel(for: recoveryPercent)
            case .awaitingMorningSync:
                return WeekFitLocalizedString("today.recovery.syncingSleep")
            case .sleepNotRecorded:
                return WeekFitLocalizedString("today.recovery.unavailable")
            }
        }()

        let recoverySleepRingText: String = {
            if confirmedMissingSleep { return "" }
            switch recoveryRingMode {
            case .sleepNotRecorded:
                return WeekFitLocalizedString("today.recovery.sleepNotRecorded")
            case .awaitingMorningSync, .hasData:
                return sleepValueInfoText
            }
        }()

        return Group {
            if shouldShowHealthConnectPrompt {
                todayPremiumCard(accent: nil, cornerRadius: TodayLayout.cardRadius, featured: true) {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "heart.text.square.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.red)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(AppText.Today.connectAppleHealth)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(textPrimary)

                                Text(AppText.Today.healthDescription)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(todaySecondaryReadable)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Button {
                            handleConnectAppleHealthTap()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: healthManager.isHealthAuthorizationInFlight ? "hourglass" : "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .bold))

                                Text(AppText.Today.connectAppleHealth)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black.opacity(0.88))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(todayActivityColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(healthManager.isHealthAuthorizationInFlight)
                        .accessibilityIdentifier("today.connectAppleHealth")
                    }
                    .padding(TodayLayout.cardInteriorVerticalPadding)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))

            } else {
                todayOverviewShell {
                    VStack(alignment: .leading, spacing: 0) {
                        todayCardSectionTitle(WeekFitLocalizedString("today.overview.title"))
                            .padding(.bottom, 6)

                        Group {
                            if shouldStackRings {
                                VStack(spacing: 16) {
                                    dailyStatusActivityRingButton(
                                        activityGoalText: activityGoalText,
                                        activityValueText: activityValueText,
                                        activityPercent: activityPercent,
                                        activityDisplayText: activityDisplayText,
                                        activityAccessibilityProgress: activityAccessibilityProgress,
                                        activityColor: activityColor,
                                        activityProgress: activityProgress
                                    )

                                    dailyStatusNutritionRingButton(
                                        eatenCalories: eatenCalories,
                                        nutritionPercent: nutritionPercent,
                                        nutritionColor: nutritionColor
                                    )

                                    dailyStatusRecoveryRingButton(
                                        recoveryDisplayValue: recoveryDisplayValue,
                                        recoverySleepRingText: recoverySleepRingText,
                                        recoveryStatusRingText: recoveryStatusRingText,
                                        recoveryColor: recoveryColor
                                    )
                                }
                            } else {
                                HStack(alignment: .top, spacing: TodayLayout.ringGroupSpacing) {
                                    dailyStatusActivityRingButton(
                                        activityGoalText: activityGoalText,
                                        activityValueText: activityValueText,
                                        activityPercent: activityPercent,
                                        activityDisplayText: activityDisplayText,
                                        activityAccessibilityProgress: activityAccessibilityProgress,
                                        activityColor: activityColor,
                                        activityProgress: activityProgress
                                    )

                                    dailyStatusNutritionRingButton(
                                        eatenCalories: eatenCalories,
                                        nutritionPercent: nutritionPercent,
                                        nutritionColor: nutritionColor
                                    )

                                    dailyStatusRecoveryRingButton(
                                        recoveryDisplayValue: recoveryDisplayValue,
                                        recoverySleepRingText: recoverySleepRingText,
                                        recoveryStatusRingText: recoveryStatusRingText,
                                        recoveryColor: recoveryColor
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func dailyStatusActivityRingButton(
        activityGoalText: String,
        activityValueText: String,
        activityPercent: Int,
        activityDisplayText: String,
        activityAccessibilityProgress: String,
        activityColor: Color,
        activityProgress: Double
    ) -> some View {
        let ringFillPercent = min(100, max(0, activityPercent))
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            openActivityIntelligence()
        } label: {
            statusRingWidget(
                title: WeekFitLocalizedString("today.status.activity"),
                infoText: activityGoalText,
                valueText: activityValueText,
                value: ringFillPercent,
                centerText: activityDisplayText,
                color: activityColor,
                valueColor: WeekFitProgressRingColor.activityLabel,
                ringProgressOverride: CGFloat(min(1, max(0, activityProgress >= 1 ? 1 : activityProgress)))
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(TodayScaleButtonStyle())
        .accessibilityLabel(
            Text(
                [
                    WeekFitLocalizedString("today.status.activity"),
                    activityDisplayText,
                    activityAccessibilityProgress,
                    activityValueText,
                    activityGoalText
                ].joined(separator: ", ")
            )
        )
        .accessibilityHint(Text(String(localized: AppText.Today.statusRingAccessibilityHint)))
    }

    private func dailyStatusNutritionRingButton(
        eatenCalories: Double,
        nutritionPercent: Int,
        nutritionColor: Color
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            ProductAnalytics.todaySectionOpened(.nutrition)
            ProductAnalytics.trackScreen(.nutritionDetails)
            nutritionDetailsDate = Date()
            showNutritionDetails = true
        } label: {
            statusRingWidget(
                title: WeekFitLocalizedString("today.status.calories"),
                infoText: remainingCaloriesText,
                valueText: String(format: WeekFitLocalizedString("common.unit.caloriesFormat"), Int(eatenCalories)),
                value: nutritionPercent,
                color: nutritionColor,
                valueColor: WeekFitProgressRingColor.nutritionLabel
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(TodayScaleButtonStyle())
        .accessibilityHint(Text(String(localized: AppText.Today.statusRingAccessibilityHint)))
    }

    private struct TodayScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
        }
    }

    private func recoveryStatusLabel(for recoveryPercent: Int) -> String {
        let input = healthManager.currentRecoveryScoreInput
        switch RecoveryScoreEngine.statusTier(
            score: recoveryPercent,
            input: input,
            breakdown: healthManager.recoveryBreakdown
        ) {
        case .wellRecovered:
            return WeekFitLocalizedString("today.recovery.good")
        case .moderatelyReady:
            return WeekFitLocalizedString("today.recovery.ok")
        case .takeItEasier, .recoveryPriority, .noData:
            if recoveryPercent > 0 {
                return WeekFitLocalizedString("today.recovery.needRest")
            }
            return WeekFitLocalizedString("today.recovery.syncing")
        }
    }

    private func dailyStatusRecoveryRingButton(
        recoveryDisplayValue: Int?,
        recoverySleepRingText: String,
        recoveryStatusRingText: String,
        recoveryColor: Color
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            ProductAnalytics.todaySectionOpened(.recovery)
            ProductAnalytics.trackScreen(.recoveryDetails)
            showRecoveryDetails = true
        } label: {
            statusRingWidget(
                title: WeekFitLocalizedString("today.status.recovery"),
                infoText: recoverySleepRingText,
                valueText: recoveryStatusRingText,
                value: recoveryDisplayValue,
                color: recoveryColor,
                valueColor: WeekFitProgressRingColor.recoveryLabel
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(TodayScaleButtonStyle())
        .accessibilityHint(Text(String(localized: AppText.Today.statusRingAccessibilityHint)))
    }

    private func statusRingWidget(
        title: String,
        infoText: String,
        valueText: String,
        value: Int?,
        centerText: String? = nil,
        color: Color,
        valueColor: Color? = nil,
        ringProgressOverride: CGFloat? = nil
    ) -> some View {
        let displayValue = value ?? 0
        let progress = ringProgressOverride ?? (CGFloat(displayValue) / 100.0)
        let ringSize = todayEffectiveRingSize
        let ringStroke = max(3, todayRingStroke * (ringSize / todayRingSize))
        let centerLabel = value == nil ? "—" : (centerText ?? "\(displayValue)%")
        let captionColor = valueColor ?? color

        return VStack(spacing: 5) {
            WeekFitProgressRing(
                progress: value == nil ? 0 : progress,
                color: color,
                size: ringSize,
                strokeWidth: ringStroke
            ) {
                Text(centerLabel)
                    .font(TodayCardTypography.ringPercent(compact: centerLabel.count > 3))
                    .foregroundStyle(textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .offset(y: value == nil ? 1 : 0.5)
            }

            VStack(spacing: 3) {
                Text(title)
                    .font(TodayCardTypography.ringCategory)
                    .foregroundStyle(textPrimary.opacity(palette.isLight ? 0.88 : 0.94))
                    .lineLimit(ringCaptionLineLimit)
                    .fixedSize(horizontal: false, vertical: true)

                Text(valueText)
                    .font(TodayCardTypography.ringPrimaryValue)
                    .foregroundStyle(captionColor)
                    .lineLimit(ringCaptionLineLimit)
                    .fixedSize(horizontal: false, vertical: true)

                if !infoText.isEmpty {
                    Text(infoText)
                        .font(TodayCardTypography.ringMeta)
                        .foregroundStyle(todayMetaReadable)
                        .lineLimit(ringCaptionLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: - Session / plan cards

    private func activeSessionCard(_ activity: PlannedActivity) -> some View {
        let accent = todayActivityColor
        let title = shortDisplayTitle(activityDisplayTitle(activity))
        let startLabel = String(
            format: WeekFitLocalizedString("today.session.startedFormat"),
            activity.date.formatted(.dateTime.hour().minute())
        )

        return todayPremiumCard(accent: nil, featured: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text(WeekFitLocalizedString("today.session.inProgress"))
                    .font(TodayCardTypography.sectionLabel)
                    .foregroundStyle(todaySecondaryReadable)

                HStack(alignment: .center, spacing: 12) {
                    upNextIconBadge(
                        systemName: upNextIcon(for: activity, isLive: true),
                        accent: accent
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(TodayCardTypography.cardTitle)
                            .foregroundStyle(textPrimary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(startLabel)
                            .font(TodayCardTypography.cardBody)
                            .foregroundStyle(todaySecondaryReadable)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Isolated timer view — avoids re-specializing the whole Today tree every second.
                    TodayElapsedClockLabel(start: activity.date, foreground: textPrimary)
                }

                Button {
                    finishStartedSession(activity)
                } label: {
                    Text(WeekFitLocalizedString("today.session.finishActivity"))
                        .font(WeekFitType.button)
                        .foregroundStyle(sessionStopForeground)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background {
                            Capsule(style: .continuous)
                                .fill(sessionStopFill)
                                .overlay {
                                    Capsule(style: .continuous)
                                        .strokeBorder(sessionStopBorder, lineWidth: 1)
                                }
                        }
                }
                .buttonStyle(.plain)
                .disabled(isFinishingSession)
                .accessibilityIdentifier("today.finishActivity")
            }
            .padding(.horizontal, TodayLayout.cardInteriorVerticalPadding)
            .padding(.vertical, TodayLayout.cardInteriorVerticalPadding)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.activeSession")
        .accessibilityLabel(
            String(
                format: WeekFitLocalizedString("today.session.liveAccessibilityFormat"),
                title
            )
        )
    }

    private func upcomingActivityCard(_ activity: PlannedActivity, now: Date) -> some View {
        let title = activityDisplayTitle(activity)
        let caption = upNextSubtitle(for: activity)
        return Button {
            openUpcomingActivity(activity)
        } label: {
            TodayMiddleCard(
                header: WeekFitLocalizedString("today.upNext.title"),
                title: title,
                message: caption,
                systemImage: upNextIcon(for: activity),
                tone: .sage,
                trailingTime: activityTime(activity.date),
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today.upNext.card")
        .accessibilityLabel(
            String(
                format: WeekFitLocalizedString("today.upNext.upcomingAccessibilityFormat"),
                title,
                caption
            )
        )
    }

    private func openUpcomingActivity(_ activity: PlannedActivity) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        appSession.requestOpenPlannedActivity(id: activity.id, on: activity.date)
        onSelectTab(.calendar)
    }

    /// Trailing clock is useful with short countdowns; hide it when the subtitle
    /// already carries an absolute “Today at …” / day+time phrase.
    private func shouldShowUpNextTrailingTime(for activity: PlannedActivity) -> Bool {
        guard Calendar.current.isDateInToday(activity.date) else { return true }
        let seconds = activity.date.timeIntervalSinceNow
        guard seconds > 0 else { return true }
        let minutes = Int(ceil(seconds / 60.0))
        return minutes < 120
    }

    private func recentCompletionCard(_ activity: PlannedActivity) -> some View {
        let title = shortDisplayTitle(activityDisplayTitle(activity))
        let minutes = max(activity.actualDurationMinutes ?? 0, activity.effectiveDurationMinutes, 1)
        let duration = String(
            format: WeekFitLocalizedString("common.duration.minutesFormat"),
            Int64(minutes)
        )

        return Button {
            openCompletedSession(activity)
        } label: {
            todayPremiumCard(accent: nil, featured: false) {
                HStack(alignment: .center, spacing: 12) {
                    upNextIconBadge(
                        systemName: upNextIcon(for: activity),
                        accent: todayActivityColor
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(WeekFitLocalizedString("today.session.completed"))
                            .font(.caption2.weight(.bold))
                            .fontDesign(.rounded)
                            .tracking(1.0)
                            .foregroundStyle(todaySecondaryReadable)
                            .textCase(.uppercase)

                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(textPrimary)
                            .lineLimit(2)

                        Text(duration)
                            .font(.caption.weight(.medium))
                            .fontDesign(.rounded)
                            .foregroundStyle(todaySecondaryReadable)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(WeekFitLocalizedString("today.session.viewActivity"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(todayActivityColor)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(todayMetaReadable)
                }
                .padding(.horizontal, TodayLayout.cardInteriorVerticalPadding)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
    }

    private func voiceDayContext() -> PlanVoiceDayContext {
        let now = Date()
        let todayActivities = CoachCanonicalDayState.selectedDayActivities(
            from: plannedActivities,
            selectedDate: now
        )
        let meals = CoachCanonicalDayState.completedMeals(from: todayActivities).prefix(8).map { activity in
            PlanVoiceDayContext.Meal(
                title: activityDisplayTitle(activity),
                time: voiceClock(activity.date)
            )
        }
        let percent = healthManager.recoveryPercent
        return PlanVoiceDayContext(
            recoveryPercent: percent > 0 ? percent : nil,
            recoveryBand: percent > 0 ? voiceRecoveryBand(percent) : nil,
            sleepMinutes: healthManager.sleepMinutes > 0 ? healthManager.sleepMinutes : nil,
            meals: Array(meals)
        )
    }

    private func voiceRecoveryBand(_ percent: Int) -> String? {
        switch RecoveryScoreEngine.statusTier(
            score: percent,
            input: healthManager.currentRecoveryScoreInput,
            breakdown: healthManager.recoveryBreakdown
        ) {
        case .wellRecovered:
            return "good"
        case .moderatelyReady:
            return "ok"
        case .takeItEasier, .recoveryPriority:
            return "need_rest"
        case .noData:
            return nil
        }
    }

    private func voiceClock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func openMayaCall() {
        guard plannerVoiceEnabled, !showPlannerVoice else { return }
        if WeekFitAIBilling.refused {
            showAIUsage = true
            return
        }
        if WeekFitAIBilling.enabled {
            guard !openingMaya else { return }
            openingMaya = true
            Task {
                defer { openingMaya = false }
                do {
                    let usage = try await WeekFitAIClient().usage()
                    if usage.active && usage.voice.total > 0 { showPlannerVoice = true }
                    else { showAIUsage = true }
                } catch { showAIUsage = true }
            }
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showPlannerVoice = true
    }

    private func refreshMayaAccess() async {
        #if DEBUG
        if WeekFitUITestSupport.isActive,
           ProcessInfo.processInfo.arguments.contains("-weekfit-show-maya-card")
            || WeekFitUITestSupport.mayaPreviewPhase != nil {
            plannerVoiceEnabled = true
            if WeekFitUITestSupport.mayaPreviewPhase != nil {
                showPlannerVoice = true
            }
            return
        }
        #endif
        do {
            let token = try await PhotoFoodFirebaseAuth.idToken()
            let access = try await PlanRealtimeClient(
                baseURL: WeekFitCloudAPI.foodPhotoBaseURL,
                token: token
            ).access()
            plannerVoiceEnabled = access.enabled
        } catch {
            plannerVoiceEnabled = false
        }
    }

    /// Prefer “Next Up” only when the next destination is tomorrow.
    private func upNextSectionTitle(for activity: PlannedActivity?, now: Date) -> String {
        let calendar = Calendar.current
        guard calendar.isDate(selectedDate, inSameDayAs: now) else {
            return WeekFitLocalizedString("today.upNext.title")
        }
        if let activity {
            if calendar.isDate(activity.date, inSameDayAs: now) {
                return WeekFitLocalizedString("today.upNext.title")
            }
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
               calendar.isDate(activity.date, inSameDayAs: tomorrow) {
                return WeekFitLocalizedString("today.upNext.tomorrowsPlan")
            }
            return WeekFitLocalizedString("today.upNext.yourPlan")
        }
        // Empty planning row — no upcoming activity identity to call “tomorrow.”
        return WeekFitLocalizedString("today.upNext.yourPlan")
    }

    private func elapsedClockText(from start: Date, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(start)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func finishStartedSession(_ activity: PlannedActivity) {
        guard !isFinishingSession, !activity.isCompleted, !activity.isSkipped else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isFinishingSession = true
        sessionFinishErrorToast = nil

        let title = shortDisplayTitle(activityDisplayTitle(activity))
        let previousDuration = activity.actualDurationMinutes
        let passedMinutes = max(1, Int(Date().timeIntervalSince(activity.date) / 60))
        activity.actualDurationMinutes = passedMinutes
        activity.isCompleted = true

        do {
            try modelContext.save()
        } catch {
            activity.isCompleted = false
            activity.actualDurationMinutes = previousDuration
            isFinishingSession = false
            let message = WeekFitLocalizedString("today.session.saveFailed")
            sessionFinishErrorToast = message
            UIAccessibility.post(notification: .announcement, argument: message)
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            todayViewModel.triggerHealthRefresh()
        }
        UIAccessibility.post(
            notification: .announcement,
            argument: String(
                format: WeekFitLocalizedString("today.session.savedFormat"),
                title
            )
        )

        ReviewEngagement.record(.activityLoggedOrCompleted)
        ProductAnalytics.activityCompleted(source: .today)

        CoachSnapshotInvalidator.invalidate(
            coordinator: coachCoordinator,
            nutritionViewModel: nutritionViewModel,
            inputProvider: coachInputProvider,
            reason: "today.activeSession.finish"
        )
        _ = coachCoordinator.forceRecompute(reason: "today.activeSession.finish")
        updateTodayCoachInsightIfNeeded(source: "today.activeSession.finish")
        activityCoordinator.refresh()
        appSession.triggerHealthRefresh(source: "today.activeSession.finish")
        appSession.triggerCoachRefresh(source: "today.activeSession.finish")
        isFinishingSession = false
    }

    private func retryFinishIfNeeded() {
        guard let active = currentStartedSession() else {
            sessionFinishErrorToast = nil
            return
        }
        finishStartedSession(active)
    }

    private func openActiveSession(_ activity: PlannedActivity) {
        let _ = activity
        ProductAnalytics.todayPrimaryActionTapped(.activity)
        presentExclusiveTodayActionSheet {
            showDirectWorkoutLogSheet = true
        }
    }

    private func openCompletedSession(_ activity: PlannedActivity) {
        let _ = activity
        openActivityIntelligence()
    }

    private func upNextTimePill(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundColor(todayPremiumBronze.opacity(0.88))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(todayPremiumBronze.opacity(0.10))
                    .overlay {
                        Capsule()
                            .stroke(todayPremiumBronze.opacity(0.14), lineWidth: 1)
                    }
            )
            .offset(x: shouldRelocateUpNextTime ? 0 : -2, y: shouldRelocateUpNextTime ? 0 : 1)
            .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func upNextTrailingMeta(timeText: String, provenance: CoachChangeKind?) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            upNextTimePill(text: timeText)
            if let provenance {
                CoachProvenanceBadge(kind: provenance, showsLabel: true, compact: true)
            }
        }
    }

    private func upNextAccent(for activity: PlannedActivity) -> Color {
        // Walk / run icons stay in the activity (green) family even if typed as habit.
        let icon = WeekFitActivityIconResolver.resolve(for: activity).lowercased()
        if icon.contains("walk") || icon.contains("run") || icon.contains("hiking") {
            return todayActivityColor
        }

        switch activity.type.lowercased() {
        case "meal", "drink", "hydration":
            // Nutrition family (apricot) — not activity green.
            return todayNutritionColor
        case "workout":
            return todayActivityColor
        case "recovery", "sauna":
            return todayRecoveryColor
        case "habit":
            return WeekFitTheme.habit
        default:
            return todayActivityColor
        }
    }

    private func upNextIconBadge(systemName: String, accent: Color) -> some View {
        WeekFitIconBadge(
            systemName: systemName,
            color: accent,
            size: .md,
            shape: .circle,
            backgroundOpacity: palette.isLight ? 0.14 : 0.14,
            strokeOpacity: 1,
            strokeWidth: 1,
            fillColor: palette.isLight
                ? accent.opacity(0.10)
                : WeekFitTheme.whiteOpacity(0.07),
            strokeColor: palette.isLight
                ? accent.opacity(WeekFitLightTokens.softBadgeStrokeOpacity)
                : accent.opacity(0.22),
            iconColor: palette.isLight ? accent : accent.opacity(0.92)
        )
    }
    
    private func nextUpcomingPlannedActivity(
        now: Date,
        excludingActivityID: String? = nil
    ) -> PlannedActivity? {
        let calendar = Calendar.current
        guard calendar.isDate(selectedDate, inSameDayAs: now) else { return nil }
        let candidates = plannedActivities.map {
            TodayUpNextCandidate(
                id: $0.id,
                date: $0.date,
                isCompleted: $0.isCompleted,
                isSkipped: $0.isSkipped
            )
        }
        guard let id = TodayUpNextSelection.nextID(
            among: candidates,
            now: now,
            calendar: calendar,
            excludingID: excludingActivityID
        ) else { return nil }
        return plannedActivities.first { $0.id == id }
    }

    private func isCoveredByActiveSession(_ activity: PlannedActivity) -> Bool {
        guard let active = currentActiveSession() else { return false }

        let activeEnd = Calendar.current.date(
            byAdding: .minute,
            value: active.durationMinutes,
            to: active.date
        ) ?? active.date

        return activity.date >= active.date && activity.date <= activeEnd
    }

    private func currentLiveUpNextActivity(now: Date = Date()) -> PlannedActivity? {
        currentStartedSession(now: now)
    }

    private func currentActiveSession(now: Date = Date()) -> PlannedActivity? {
        currentStartedSession(now: now)
    }

    /// Live session for Today: Quick Start / Today-started, or a plan workout/recovery in window.
    private func currentStartedSession(now: Date = Date()) -> PlannedActivity? {
        selectedDayActivities
            .filter { $0.isTodayLiveSessionDisplay(now: now) }
            .sorted { $0.date < $1.date }
            .first
    }
    
    private func activityContext(_ activity: PlannedActivity) -> String {
        switch activity.type.lowercased() {

        case "meal":
            return WeekFitLocalizedString("today.activity.context.nutrition")

        case "workout":
            return WeekFitLocalizedString("today.activity.context.endurance")

        case "recovery":
            return WeekFitLocalizedString("today.activity.context.recovery")

        default:
            return WeekFitLocalizedString("today.activity.context.routine")
        }
    }

    private func coachInsightCard(presentation: CoachUIPresentation) -> AnyView {
        let display = CoachTodayCardCopy.focusCard(from: presentation)
        let insightIcon = todayCoachDisplayIcon(for: presentation)
        let focusHeading = WeekFitLocalizedString("today.coachInsight.focusToday")
        let insightTitle = display?.title ?? ""
        let insightMessage = display?.message ?? ""
        guard display != nil, !insightTitle.isEmpty else {
            return AnyView(neutralFocusCard())
        }

        return AnyView(Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            ProductAnalytics.todayPrimaryActionTapped(.coach)
            onSelectTab(.coach)
        } label: {
            TodayMiddleCard(
                header: focusHeading,
                title: insightTitle,
                message: insightMessage,
                systemImage: insightIcon,
                tone: .lavender,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today.focus.card")
        .accessibilityLabel(
            [focusHeading, insightTitle, insightMessage]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")
        )
        .accessibilityHint(WeekFitLocalizedString("today.coachInsight.opensCoach"))
        .onAppear {
            guard presentation.planAdjustmentMode == .appliedExecuting else { return }
            let dayKey = ProposalInputFingerprintBuilder.dayKey(for: Date())
            guard MorningProposalPresenter.shouldShowAppliedAcknowledgment(dayKey: dayKey) else { return }
            MorningProposalPresenter.markAppliedAcknowledgmentShown(dayKey: dayKey)
            MorningProposalAnalytics.coachAcknowledgmentViewed(dayKey: dayKey)
            Task { @MainActor in
                coachCoordinator.forceRecompute(reason: "appliedAcknowledgmentViewed.todayInsight")
            }
        })
    }

    private func neutralFocusCard() -> some View {
        TodayMiddleCard(
            header: WeekFitLocalizedString("today.coachInsight.focusToday"),
            title: WeekFitLocalizedString("today.focus.neutralTitle"),
            message: WeekFitLocalizedString("today.focus.neutralMessage"),
            systemImage: "heart",
            tone: .lavender,
            showsChevron: false
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today.focus.card")
    }

    // Coach sheets / morning-proposal observers live on `body` — attaching them
    // here recreated the September "Thread stack size exceeded" SIGSEGV when the
    // deferred Coach slot mounted ~1s after first paint.

    private var coachInsightWithOptionalProposalOverlay: AnyView {
        if !morningProposalChromeHidden,
           hasMorningProposalChrome,
           let proposalCard = morningProposalCard() {
            return proposalCard
        }
        return AnyView(coachInsightPhaseContent)
    }

    /// Whether Morning Adjustments chrome exists — without building the card view.
    private var hasMorningProposalChrome: Bool {
        switch MorningProposalPresenter.chromeState(for: morningProposal) {
        case .proposalReady:
            return true
        case .applied:
            guard let dayKey = morningProposal?.dayKey else { return false }
            return MorningProposalPresenter.shouldShowAppliedAcknowledgment(dayKey: dayKey)
                && CoachAppliedAcknowledgmentCopy.planAdjustmentMode(forDayKey: dayKey) == .appliedExecuting
        case .gathering, .noChangesNeeded, .stale, .failed, .hidden, .unavailable:
            return false
        }
    }

    @ViewBuilder
    private var morningAdjustmentsOverlayStack: some View {
        let peek: CGFloat = 16
        let underlayInset: CGFloat = 10
        ZStack(alignment: .top) {
            morningProposalStackUnderlay
                .padding(.top, peek)
                .padding(.horizontal, underlayInset)
                .allowsHitTesting(false)

            if let proposalCard = morningProposalCard() {
                proposalCard
                    .onAppear {
                        if let dayKey = morningProposal?.dayKey {
                            MorningProposalNotificationService.shared.cancel(dayKey: dayKey)
                            MorningProposalNotificationService.shared.markHandled(dayKey: dayKey)
                        }
                    }
                    .zIndex(1)
                    .shadow(
                        color: palette.isLight
                            ? Color.black.opacity(0.10)
                            : Color.black.opacity(0.55),
                        radius: palette.isLight ? 16 : 22,
                        y: palette.isLight ? 8 : 12
                    )
            }
        }
        .padding(.bottom, peek)
        .animation(.easeOut(duration: 0.22), value: true)
    }

    /// Quiet plate under Morning Adjustments.
    ///
    /// Never nest `coachInsightCard` / `coachInsightPhaseContent` here. Combining
    /// that heavy opaque SwiftUI type with the proposal card in one ZStack
    /// overflows the main-thread stack while instantiating mangled metadata
    /// (`EXC_BAD_ACCESS` / "Thread stack size exceeded" — see device IPS
    /// 2026-09-14…17 morning crashes).
    private var morningProposalStackUnderlay: some View {
        RoundedRectangle(cornerRadius: TodayLayout.cardRadius, style: .continuous)
            .fill(palette.cardSurfaceElevated.opacity(palette.isLight ? 0.92 : 0.88))
            .overlay {
                RoundedRectangle(cornerRadius: TodayLayout.cardRadius, style: .continuous)
                    .strokeBorder(
                        palette.isLight
                            ? WeekFitLightTokens.cardBorder.opacity(0.35)
                            : Color.white.opacity(0.07),
                        lineWidth: 1
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .overlay(alignment: .topLeading) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(WeekFitTheme.coachAccent.opacity(0.12))
                        .frame(width: 28, height: 28)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(textSecondary.opacity(0.18))
                        .frame(width: 72, height: 8)
                }
                .padding(.horizontal, 18)
                .padding(.top, 22)
                .opacity(0.55)
            }
            .accessibilityHidden(true)
    }

    private var coachInsightPhaseContent: AnyView {
        // Always erase — insight/settling branches have different opaque depths and
        // swapping them after Health settles was a delayed SIGSEGV trigger.
        // Never omit the Coach entry with EmptyView — users expect Today’s Focus
        // between Up Next and Quick Log whenever a session is not running.
        // When insight exists, show it as-is so Focus matches the Coach tab hero.
        switch todayCoachInsightPhase {
        case .insight(let presentation, _):
            return AnyView(coachInsightCard(presentation: presentation))
        case .awaitingHealthConnect, .awaitingMorningSync, .preparing:
            return AnyView(neutralFocusCard())
        }
    }

    private func morningProposalCard() -> AnyView? {
        let chrome = MorningProposalPresenter.chromeState(for: morningProposal)
        switch chrome {
        case .proposalReady:
            return AnyView(morningProposalReadyCard())
        case .applied:
            guard let dayKey = morningProposal?.dayKey,
                  MorningProposalPresenter.shouldShowAppliedAcknowledgment(dayKey: dayKey),
                  CoachAppliedAcknowledgmentCopy.planAdjustmentMode(forDayKey: dayKey) == .appliedExecuting else {
                return nil
            }
            return AnyView(morningProposalAppliedCard(dayKey: dayKey))
        case .gathering, .noChangesNeeded, .stale, .failed, .hidden, .unavailable:
            return nil
        }
    }

    private func morningProposalReadyCard() -> some View {
        let title = WeekFitLocalizedString("coach.proposal.chrome.readyTitle")
        let review = WeekFitLocalizedString("coach.proposal.chrome.reviewCTA")
        let canReview = MorningProposalPresenter.shouldPresentReview(morningProposal)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            guard canReview else {
                morningProposalChromeHidden = true
                return
            }
            morningProposalChromeHidden = true
            showProposalReview = true
        } label: {
            TodayMiddleCard(
                header: WeekFitLocalizedString("today.coachInsight.focusToday"),
                title: title,
                message: review,
                systemImage: "sun.horizon.fill",
                tone: .lavender,
                showsChevron: canReview
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("morning.proposal.card")
        .accessibilityLabel(title)
        .accessibilityHint(review)
        .onAppear {
            if let dayKey = morningProposal?.dayKey {
                MorningProposalNotificationService.shared.cancel(dayKey: dayKey)
                MorningProposalNotificationService.shared.markHandled(dayKey: dayKey)
            }
            if let proposal = morningProposal {
                MorningProposalAnalytics.proposalViewed(
                    proposalId: proposal.id,
                    changeCount: proposal.changes.count
                )
            }
        }
    }

    private func morningProposalAppliedCard(dayKey: String) -> some View {
        let title = WeekFitLocalizedString("coach.proposal.chrome.appliedTitle")
        let message = WeekFitLocalizedString("coach.proposal.chrome.appliedBody")
        return Button {
            morningProposalChromeHidden = true
            onSelectTab(.coach)
        } label: {
            TodayMiddleCard(
                header: WeekFitLocalizedString("today.coachInsight.focusToday"),
                title: title,
                message: message,
                systemImage: "checkmark",
                tone: .lavender,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("morning.proposal.card")
        .accessibilityLabel("\(title). \(message)")
        .accessibilityHint(WeekFitLocalizedString("today.coachInsight.opensCoach"))
        .onAppear {
            MorningProposalPresenter.markAppliedAcknowledgmentShown(dayKey: dayKey)
            MorningProposalAnalytics.coachAcknowledgmentViewed(dayKey: dayKey)
            Task { @MainActor in
                coachCoordinator.forceRecompute(reason: "appliedAcknowledgmentViewed.today")
            }
        }
    }

    private func morningProposalDismissibleChrome<Content: View>(
        accent: Color,
        onTap: @escaping () -> Void,
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, TodayLayout.coachCardVerticalPadding)
                    .padding(.trailing, 12)
            }
            .buttonStyle(.plain)

            WeekFitCloseButton(
                size: .compact,
                accessibilityLabel: WeekFitLocalizedString("coach.proposal.chrome.dismiss")
            ) {
                (onClose ?? { dismissMorningProposalChrome(permanent: true) })()
            }
            .padding(.top, 10)
            .padding(.trailing, 10)
        }
        .weekFitPremiumCard(
            emphasis: .elevated,
            accent: accent,
            cornerRadius: TodayLayout.cardRadius
        )
        // Soft ceramic edge lift so the teaser reads above the coach underlay.
        .overlay {
            RoundedRectangle(cornerRadius: TodayLayout.cardRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(palette.isLight ? 0.55 : 0.14),
                            Color.white.opacity(palette.isLight ? 0.12 : 0.04),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
                .allowsHitTesting(false)
        }
        .accessibilityIdentifier("morning.proposal.card")
    }

    private func dismissMorningProposalChrome(permanent: Bool) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        morningProposalChromeHidden = true
        guard permanent, let dayKey = morningProposal?.dayKey else { return }
        MorningProposalService.dismiss(dayKey: dayKey)
        refreshMorningProposal()
    }

    private func scheduleMorningProposalRefresh() {
        morningProposalDebounceTask?.cancel()
        morningProposalDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            refreshMorningProposal()
        }
    }

    private func refreshMorningProposal(forceRegenerate: Bool = false) {
        #if DEBUG
        if MorningProposalScreenshotFixtures.shouldSeed {
            let proposal = MorningProposalScreenshotFixtures.sampleProposal()
            MorningProposalStore.upsert(proposal)
            morningProposal = proposal
            morningProposalChromeHidden = false
            if MorningProposalScreenshotFixtures.shouldOpenReview {
                showProposalReview = true
            }
            return
        }
        #endif

        let now = Date()

        Task { @MainActor in
            let taskName = "today.weather.cachedSummary"
            StartupDiagnostics.step(21, "weather load begin", detail: "cachedSummaryAndFreshness")
            StartupDiagnostics.taskBegin(taskName)
            let (cached, isFresh) = await WeekFitWeatherProvider.shared.cachedSummaryAndFreshness()
            if morningWeatherSummary != cached {
                morningWeatherSummary = cached
                if !quickLogDrinks.isEmpty {
                    refreshDrinkPartitions(drinks: quickLogDrinks, usage: quickItemUsageEntries)
                }
            }
            StartupDiagnostics.taskSuccess(
                taskName,
                detail: "hasSummary=\(cached != nil) fresh=\(isFresh)"
            )
            StartupDiagnostics.step(
                22,
                "weather load complete",
                detail: "hasSummary=\(cached != nil) fresh=\(isFresh)"
            )
        }

        let coachState = coachCoordinator.state
        let sleepHours = Double(healthManager.sleepMinutes) / 60.0
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
        let meals = MorningProposalEvaluator.mealLibrary(from: userSettings)
        let weatherAssessment = OutdoorSuitabilityResolver.assess(from: morningWeatherSummary)
        let weatherRiskToken = weatherAssessment.riskToken
        let outdoorSuitability = weatherAssessment.suitability

        morningProposal = MorningProposalEvaluator.evaluate(
            .init(
                now: now,
                plannedActivities: plannedActivities,
                isHealthAccessGranted: healthManager.isHealthAccessGranted,
                sleepHours: sleepHours,
                hasSettledMetrics: healthManager.hasSettledMetrics(for: selectedDate),
                hasRecoverySignals: hasTodayRecoverySignals,
                readiness: readiness,
                scenarioKey: coachState.coachIntegrationDebug?.scenario,
                mealLibrary: meals.candidates,
                mealLibraryRevision: meals.revision,
                weatherRiskToken: weatherRiskToken,
                outdoorSuitability: outdoorSuitability,
                forceRegenerate: forceRegenerate
            )
        )

        syncMorningProposalNotification(proposal: morningProposal, todaySurfaceVisible: true)

        if morningProposal?.status == .gatheringData {
            scheduleMorningProposalHealthTimeout()
        } else {
            morningProposalTimeoutTask?.cancel()
            morningProposalTimeoutTask = nil
        }
    }

    private func syncMorningProposalNotification(
        proposal: MorningPlanProposal?,
        todaySurfaceVisible: Bool
    ) {
        let givenName: String? = {
            let name = ProfileService.resolvedGivenName()
            return name.isEmpty ? nil : name
        }()
        MorningProposalNotificationService.shared.sync(
            proposal: proposal,
            wakeTime: healthManager.wakeTime,
            todaySurfaceVisible: todaySurfaceVisible,
            givenName: givenName
        )
    }

    private func openPendingMorningProposalReviewIfNeeded() {
        guard PendingMorningProposalReview.shared.consume() else { return }
        morningProposal = MorningProposalStore.proposal(
            for: ProposalInputFingerprintBuilder.dayKey(for: Date())
        ) ?? morningProposal
        guard MorningProposalPresenter.shouldPresentReview(morningProposal) else { return }
        morningProposalChromeHidden = false
        showProposalReview = true
    }

    private func scheduleMorningProposalHealthTimeout() {
        morningProposalTimeoutTask?.cancel()
        guard let proposal = morningProposal, proposal.status == .gatheringData else { return }
        // Aim at the sleep-wait deadline (absolute). Rescheduling on refresh shrinks
        // remaining time instead of resetting an 8s loop forever.
        let sleepRemaining = MorningProposalGate.sleepWaitTimeoutSeconds
            - Date().timeIntervalSince(proposal.generatedAt)
        let healthSettled = healthManager.hasSettledMetrics(for: selectedDate)
            || MorningProposalEvaluator.hasRecoverySignals(
                sleepMinutes: healthManager.sleepMinutes,
                timeInBedMinutes: healthManager.timeInBedMinutes,
                hrvSDNN: healthManager.hrvSDNN,
                restingHeartRate: healthManager.restingHeartRate
            )
        let delay: TimeInterval
        if healthSettled {
            delay = max(0.5, sleepRemaining)
        } else {
            delay = min(
                MorningProposalGate.healthTimeoutSeconds,
                max(0.5, sleepRemaining)
            )
        }
        morningProposalTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard morningProposal?.status == .gatheringData else { return }
            refreshMorningProposal()
        }
    }

    private func handleConnectAppleHealthTap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        HealthConnectDiagnostics.logButtonTapped(source: "today.connectAppleHealth")

        _ = healthManager.requestNativeHealthAuthorizationFromConnectTap(
            source: "today.connectAppleHealth",
            for: selectedDate,
            plannedActivities: selectedDayActivities
        ) {
            appSession.triggerHealthRefresh(source: "today.healthConnect")
            refreshTodayLiveState(refreshHealth: true)
        }
    }
    
    private func refreshTodayLiveState(refreshHealth: Bool = false) {
        debugTodayDataState(source: "refreshTodayLiveState.before refreshHealth=\(refreshHealth)")
        todayViewModel.refreshTodayLiveState(
            refreshHealth: refreshHealth,
            selectedDate: selectedDate,
            plannedActivities: plannedActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel
        )
        debugTodayDataState(source: "refreshTodayLiveState.afterNutrition refreshHealth=\(refreshHealth)")
    }

    private var todayMiddleClockID: String {
        let now = todayViewModel.now
        let next = nextUpcomingPlannedActivity(now: now)?.date.timeIntervalSince1970 ?? 0
        return "\(tabIsActive)|\(Int(now.timeIntervalSince1970))|\(Int(next))"
    }

    /// Keeps “In N min” and the Up next / focus switch current while Today stays open.
    private func refreshTodayMiddleClock() async {
        guard tabIsActive else { return }
        let now = Date()
        let untilEvent = nextUpcomingPlannedActivity(now: now)?.date.timeIntervalSince(now) ?? .greatestFiniteMagnitude
        let calendar = Calendar.current
        let nextDay = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)
        let untilDay = max(0, nextDay.timeIntervalSince(now))
        let wait = min(60, max(1, min(max(0, untilEvent), untilDay)))
        try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        guard !Task.isCancelled, tabIsActive else { return }
        todayViewModel.now = Date()
        reconcileTodayDayBoundary()
    }

    private func reconcileTodayDayBoundary() {
        var date = selectedDate
        let shouldRefresh = todayViewModel.reconcileDayBoundary(
            selectedDate: &date,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel
        )

        if date != selectedDate {
            selectedDate = date
        } else if shouldRefresh {
            todayViewModel.triggerHealthRefresh()
        }
    }

    private func handleReturnToTodayRequest() {
        selectedDate = Date()
        todayViewModel.now = Date()
        reconcileTodayDayBoundary()
    }

    private func refreshTodayAfterAppBecameActive() {
        todayViewModel.now = Date()
        var date = selectedDate
        let shouldRefreshHealth = todayViewModel.reconcileDayBoundary(
            selectedDate: &date,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel
        )
        if date != selectedDate {
            selectedDate = date
        }
        refreshTodayLiveState(refreshHealth: shouldRefreshHealth)
        if shouldRefreshHealth {
            appSession.triggerCoachRefresh(source: "TodayView.sceneActive.dayBoundary")
        }
    }

    private func handleLocalDataResetCompleted() {
        showActivityIntelligence = false
        showNutritionDetails = false
        showRecoveryDetails = false
        showProfile = false
        appSession.dismissHealthAccess()
        showDirectWorkoutLogSheet = false
        showDirectMealLogSheet = false
        showDirectDrinkLogSheet = false
        showDirectRecoveryLogSheet = false
        activityToConfirm = nil
        queuedActivityToConfirm = nil
        setQuickLogMeals([])
        setQuickLogSnacks([])
        setQuickLogDrinks([])
        setQuickItemUsageEntries([:], persist: true)
        quickLogFrequentDrinkRows = []
        quickLogRecentDrinkRows = []
        quickLogFrequentSnackRows = []
        quickLogRecentSnackRows = []
        quickLogFrequentMealRows = []
        quickLogRecentMealRows = []
        didPreloadQuickFood = false
        didPreloadQuickDrinks = false

        nutritionViewModel.resetLocalState()
        handleReturnToTodayRequest()
        todayViewModel.now = Date()
        todayViewModel.triggerHealthRefresh()
    }

    /// iOS 17 only allows one sheet at a time — keep Today action sheets mutually exclusive.
    private var isTodayActionSheetPresented: Bool {
        showProfile
            || showDirectMealLogSheet
            || showDirectDrinkLogSheet
            || showDirectWorkoutLogSheet
            || showDirectRecoveryLogSheet
    }

    private func presentExclusiveTodayActionSheet(_ present: () -> Void) {
        showDirectMealLogSheet = false
        showDirectDrinkLogSheet = false
        showDirectWorkoutLogSheet = false
        showDirectRecoveryLogSheet = false
        activityToConfirm = nil
        present()
    }

    private func presentActivityConfirmation(_ activity: PlannedActivity) {
        if isTodayActionSheetPresented {
            queuedActivityToConfirm = activity
            return
        }
        activityToConfirm = activity
    }

    private func flushQueuedActivityConfirmationIfNeeded() {
        guard !isTodayActionSheetPresented,
              let queued = queuedActivityToConfirm else { return }
        queuedActivityToConfirm = nil
        activityToConfirm = queued
    }
    
    private struct QuickActionPressStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.955 : 1)
                .opacity(configuration.isPressed ? 0.90 : 1)
                .animation(.spring(response: 0.20, dampingFraction: 0.78), value: configuration.isPressed)
        }
    }

    private enum QuickActionKind {
        case food
        case activity
    }

    private func isExerciseActivity(_ activity: PlannedActivity) -> Bool {
        switch activity.type.lowercased() {
        case "workout", "recovery", "sauna":
            return true
        default:
            return false
        }
    }

    private func nextUpcomingExerciseActivity(now: Date) -> PlannedActivity? {
        guard let activity = nextUpcomingPlannedActivity(now: now),
              isExerciseActivity(activity) else {
            return nil
        }
        return activity
    }

    private func recentlyCompletedExerciseActivity(now: Date) -> PlannedActivity? {
        selectedDayActivities
            .filter { activity in
                guard isExerciseActivity(activity) else { return false }
                let state = activity.terminalState(now: now)
                guard state == .completed || state == .partial else { return false }
                let endDate = Calendar.current.date(
                    byAdding: .minute,
                    value: activity.effectiveDurationMinutes,
                    to: activity.date
                ) ?? activity.date
                let elapsed = now.timeIntervalSince(endDate)
                return elapsed >= 0 && elapsed <= TodayLayout.recentCompletionWindow
            }
            .max(by: { $0.date < $1.date })
    }

    private func quickActionDynamicPriority(now: Date) -> QuickActionKind? {
        if currentActiveSession(now: now) != nil {
            return .activity
        }
        if quickActionFoodLoggingBehind(now: now) {
            return .food
        }
        return nil
    }

    private func quickActionFoodLoggingBehind(now: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        guard hour >= 12 else { return false }
        let loggedMeals = nutritionMeals(for: selectedDate).filter { $0.type.lowercased() == "meal" }
        return loggedMeals.isEmpty
    }

    @ViewBuilder
    private func quickActionButtons(activeSession: PlannedActivity?, now: Date) -> some View {
        let priority = quickActionDynamicPriority(now: now)
        let activityIcon = activeSession.map { upNextIcon(for: $0, isLive: true) } ?? "play.fill"
        let activityLabel = activeSession == nil
            ? WeekFitLocalizedString("today.quickActions.startActivity")
            : WeekFitLocalizedString("today.quickActions.viewSession")

        quickActionItem(
            icon: "cup.and.saucer.fill",
            label: WeekFitLocalizedString("today.quickActions.logDrink"),
            color: QuickDrinkAccent.hydration,
            isEmphasized: false,
            toastMessage: drinksQuickLogToast,
            accessibilityIdentifier: "today.quickAction.drinks"
        ) {
            preloadQuickDrinkLogDataIfNeeded()
            ProductAnalytics.todayPrimaryActionTapped(.hydration)
            ProductAnalytics.quickLogOpened(category: .hydration)
            presentExclusiveTodayActionSheet {
                ProductAnalytics.hydrationLoggingStarted(method: .quickLog, source: .today)
                showDirectDrinkLogSheet = true
            }
        }

        quickActionItem(
            icon: "fork.knife",
            label: WeekFitLocalizedString("today.quickActions.logMeal"),
            color: todayNutritionColor,
            isEmphasized: priority == .food,
            toastMessage: foodQuickLogToast,
            accessibilityIdentifier: "today.quickAction.food"
        ) {
            selectedLogTab = .meals
            preloadQuickFoodLogDataIfNeeded()
            ProductAnalytics.todayPrimaryActionTapped(.food)
            ProductAnalytics.quickLogOpened(category: .food)
            presentExclusiveTodayActionSheet {
                ProductAnalytics.foodLoggingStarted(method: .quickLog, source: .today, operation: .diary)
                showDirectMealLogSheet = true
            }
        }

        quickActionItem(
            icon: activityIcon,
            label: activityLabel,
            color: todayActivityColor,
            isEmphasized: priority == .activity,
            liveIndicatorColor: activeSession == nil ? nil : todayActivityColor,
            accessibilityIdentifier: "today.quickAction.activity"
        ) {
            if let activeSession {
                openActiveSession(activeSession)
            } else {
                ProductAnalytics.todayPrimaryActionTapped(.activity)
                presentExclusiveTodayActionSheet {
                    ProductAnalytics.activityLoggingStarted(source: .today)
                    showDirectWorkoutLogSheet = true
                }
            }
        }
    }

    @ViewBuilder
    private var quickActionsSection: some View {
        let now = todayViewModel.now
        let activeSession = currentActiveSession(now: now)
        let accent = todayQuickActionsAccent

        todayActionSurfaceCard(accent: accent) {
            VStack(alignment: .leading, spacing: 0) {
                Text(WeekFitLocalizedString("today.quickActions.title"))
                    .font(TodayCardTypography.quickActionSectionTitle)
                    .foregroundStyle(todaySectionTitleColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)

                Group {
                    if shouldStackQuickActions {
                        VStack(spacing: 8) {
                            quickActionButtons(activeSession: activeSession, now: now)
                        }
                    } else {
                        HStack(spacing: 0) {
                            quickActionButtons(activeSession: activeSession, now: now)
                        }
                    }
                }
            }
        }
    }

    private func quickActionItem(
        icon: String,
        label: String,
        color: Color,
        isEmphasized: Bool = false,
        liveIndicatorColor: Color? = nil,
        toastMessage: String? = nil,
        accessibilityIdentifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let iconFillOpacity = isEmphasized ? (palette.isLight ? 0.18 : 0.17) : (palette.isLight ? 0.14 : 0.11)
        let iconStrokeOpacity = isEmphasized ? (palette.isLight ? 0.32 : 0.22) : (palette.isLight ? 0.24 : 0.15)
        let iconForeground = palette.isLight
            ? color
            : color.opacity(isEmphasized ? 0.94 : 0.88)

        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .top) {
                    Circle()
                        .fill(color.opacity(iconFillOpacity))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(iconStrokeOpacity), lineWidth: isEmphasized ? 1.1 : 1)
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconForeground)
                        .offset(y: quickActionIconOpticalYOffset(icon))
                        .frame(width: 52, height: 52)

                    if let liveIndicatorColor {
                        Circle()
                            .fill(liveIndicatorColor)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color.black.opacity(0.28), lineWidth: 1))
                            .offset(x: 14, y: -12)
                    }

                    if let toastMessage {
                        Text(toastMessage)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(color.opacity(0.92))
                            .clipShape(Capsule())
                            .offset(y: -32)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                Text(verbatim: label)
                    .font(TodayCardTypography.quickActionLabel)
                    .foregroundStyle(
                        palette.isLight
                            ? textPrimary
                            : textPrimary.opacity(isEmphasized ? 0.94 : 0.88)
                    )
                    .lineLimit(quickActionCaptionLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(QuickActionPressStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(accessibilityIdentifier ?? label)
    }

    private func coachIconOpticalYOffset(_ systemName: String) -> CGFloat {
        if systemName.hasPrefix("figure.") {
            return -0.5
        }
        if systemName == "brain.head.profile" {
            return 0.5
        }
        return 0
    }

    private func quickActionIconOpticalYOffset(_ systemName: String) -> CGFloat {
        switch systemName {
        case "fork.knife", "takeoutbag.and.cup.and.straw.fill":
            return 0.5
        case "play.circle.fill", "stop.circle.fill":
            return 0
        default:
            return 0
        }
    }

    private func updateNutrition(withExtraWater extra: Double = 0) {
        todayViewModel.updateNutrition(
            selectedDate: selectedDate,
            plannedActivities: plannedActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            extraWater: extra
        )
        debugTodayDataState(source: "updateNutrition")
    }

    private func missedConfirmationSheet(_ activity: PlannedActivity) -> some View {
        PremiumActivityConfirmationSheet(
            icon: upNextIcon(for: activity),
            accentColor: activity.color,
            title: WeekFitLocalizedString("today.verify.title"),
            messageFormat: WeekFitLocalizedString("today.verify.messageFormat"),
            highlightedName: activityDisplayTitle(activity),
            confirmTitle: WeekFitLocalizedString("today.verify.confirm"),
            skipTitle: WeekFitLocalizedString("today.verify.skipped"),
            onConfirm: {
                withAnimation {
                    try? PlannedActivityNotificationConfirmationService.markCompleted(
                        activity,
                        modelContext: modelContext
                    )
                    todayViewModel.triggerHealthRefresh()
                    activityToConfirm = nil
                }
            },
            onSkip: {
                withAnimation {
                    try? PlannedActivityNotificationConfirmationService.markSkipped(
                        activity,
                        modelContext: modelContext
                    )
                    todayViewModel.triggerHealthRefresh()
                    activityToConfirm = nil
                }
            }
        )
    }
    
    private func upNextSubtitle(for activity: PlannedActivity) -> String {
        let seconds = max(0, activity.date.timeIntervalSince(todayViewModel.now))
        let minutes = max(1, Int(ceil(seconds / 60.0)))
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            if remainder > 0 {
                return String(
                    format: WeekFitLocalizedString("today.upNext.inHoursMinutesFormat"),
                    Int64(hours),
                    Int64(remainder)
                )
            }
            return String(
                format: WeekFitLocalizedString("today.upNext.inHoursFormat"),
                Int64(hours)
            )
        }
        return String(
            format: WeekFitLocalizedString("today.upNext.inMinutesFormat"),
            Int64(minutes)
        )
    }

    /// Compact countdown near start; clock time when several hours away.
    private func upNextStartsInText(for activity: PlannedActivity) -> String? {
        let calendar = Calendar.current
        guard calendar.isDateInToday(activity.date) else { return nil }
        let seconds = activity.date.timeIntervalSinceNow
        guard seconds > 0 else { return nil }
        let minutes = Int(ceil(seconds / 60.0))
        guard minutes > 0, minutes < 24 * 60 else { return nil }

        // Several hours away → “Today at 11:30” (not “Starts in 141 min”).
        if minutes >= 120 {
            return String(
                format: WeekFitLocalizedString("today.upNext.todayAtFormat"),
                activity.date.formatted(.dateTime.hour().minute())
            )
        }

        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            if remainder > 0 {
                return String(
                    format: WeekFitLocalizedString("today.upNext.startsInHoursMinutesFormat"),
                    Int64(hours),
                    Int64(remainder)
                )
            }
            return String(
                format: WeekFitLocalizedString("today.upNext.startsInHoursFormat"),
                Int64(hours)
            )
        }

        return String(
            format: WeekFitLocalizedString("today.upNext.startsInMinutesFormat"),
            Int64(minutes)
        )
    }

    private func coachProvenanceKind(for activity: PlannedActivity) -> CoachChangeKind? {
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: activity.date)
        return CoachProvenanceLookupCache.adjustment(
            forActivityId: activity.id,
            dayKey: dayKey
        )?.kind
    }

    private func upNextIcon(for activity: PlannedActivity, isLive: Bool = false) -> String {
        let resolved = WeekFitActivityIconResolver.resolve(for: activity)

        if isLive && resolved == "figure.walk" {
            return "figure.walk.motion"
        }

        return resolved
    }

    private func activitySubtitle(_ activity: PlannedActivity) -> String {
        switch activity.type.lowercased() {

        case "meal":
            if activity.title.lowercased().contains("breakfast") {
                return WeekFitLocalizedString("today.activity.subtitle.morningFuel")
            } else if activity.title.lowercased().contains("snack") {
                return WeekFitLocalizedString("today.activity.subtitle.energySupport")
            } else {
                return WeekFitLocalizedString("today.activity.subtitle.nutritionSupport")
            }

        case "workout":
            return WeekFitLocalizedString("today.activity.subtitle.trainingSession")

        case "recovery":
            return WeekFitLocalizedString("today.activity.subtitle.recoveryBlock")

        case "hydration":
            return WeekFitLocalizedString("today.activity.subtitle.hydrationSupport")

        default:
            return WeekFitLocalizedString("today.activity.subtitle.plannedActivity")
        }
    }

    private func durationText(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let remainder = safeMinutes % 60

        if hours > 0 && remainder > 0 {
            return String(format: WeekFitLocalizedString("common.duration.hoursMinutesShortFormat"), hours, remainder)
        }

        if hours > 0 {
            return String(format: WeekFitLocalizedString("common.duration.hoursShortFormat"), hours)
        }

        return String(format: WeekFitLocalizedString("common.duration.minutesShortFormat"), safeMinutes)
    }

    private func activityTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private func upNextTimeText(for activity: PlannedActivity, selectedDate: Date) -> String {
        let time = activityTime(activity.date)
        let calendar = Calendar.current
        let now = Date()
        guard calendar.isDate(selectedDate, inSameDayAs: now),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
              calendar.isDate(activity.date, inSameDayAs: tomorrow) else {
            return time
        }
        return String(
            format: WeekFitLocalizedString("today.upNext.tomorrowAtFormat"),
            time
        )
    }

    private func refreshHealthAndNutritionAsync() async {
        await MainActor.run {
            debugTodayDataState(source: "refreshHealthAndNutritionAsync.start")
        }
        await todayViewModel.refreshHealthAndNutrition(
            selectedDate: selectedDate,
            plannedActivities: plannedActivities,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel
        )
        await MainActor.run {
            let dayActivities = todayViewModel.selectedDayActivities(on: selectedDate, from: plannedActivities)
            coachInputProvider.refreshFromCurrentState(
                selectedDate: selectedDate,
                dayActivities: dayActivities,
                allPlannedActivities: plannedActivities,
                healthManager: healthManager,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                source: "TodayView.healthLoad"
            )
            healthManager.markDisplayMetricsSettled(for: selectedDate)
            refreshMorningProposal()
            if !healthManager.isHealthAccessRequested {
                debugTodayDataState(source: "refreshHealthAndNutritionAsync.noHealthAccess")
            }
            debugTodayDataState(source: "refreshHealthAndNutritionAsync.end")
        }
    }

    private var automatedActivityGoal: Double {
        let goal = ProfileService().resolvedNutritionGoal(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm
        )
        return ActivityGoalEngine.calculate(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm,
            age: healthManager.age,
            sex: healthManager.biologicalSex,
            recoveryPercent: healthManager.recoveryPercent,
            sleepHours: healthManager.sleepHours,
            vo2Max: healthManager.cardioFitnessVO2,
            goal: goal
        )
    }

    private var selectedDateTitle: String {
        WeekFitShortWeekdayMonthDay(selectedDate)
    }

    private func shortDisplayTitle(_ title: String) -> String {
        title.components(separatedBy: ",").first ?? title
    }

    private func activityDisplayTitle(_ activity: PlannedActivity) -> String {
        if activity.type.lowercased() == "drink" || activity.imageName == "hydration" {
            return QuickItem.localizedTitle(forStoredTitle: activity.title)
        }

        let trimmedTitle = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)

        // Snacks / quick catalog items (Banana, Greek Yogurt, …).
        let quickLocalized = QuickItem.localizedTitle(forStoredTitle: trimmedTitle)
        if quickLocalized != trimmedTitle {
            return quickLocalized
        }

        // Builder / starter meals persist English ingredient phrases ("Eggs Oatmeal").
        // Meals tab remaps via MealBuilderTitleComposer; Today must do the same.
        let mealLocalized = MealBuilderTitleComposer.localizedStoredTitle(trimmedTitle)
        if mealLocalized != trimmedTitle {
            return mealLocalized
        }

        let plannerLocalized = PlannerOptionLocalization.localizedTitle(for: trimmedTitle)
        if plannerLocalized != trimmedTitle {
            return plannerLocalized
        }

        return WeekFitCoachRuntimeLocalizedString(activity.title)
    }

    private var selectedDayActivities: [PlannedActivity] {
        todayViewModel.selectedDayActivities(on: selectedDate, from: plannedActivities)
    }
}

private extension View {
    func quickLogCardBackground(
        cardSecondary: Color,
        cardBackground: Color,
        cornerRadius: CGFloat
    ) -> some View {
        weekFitPremiumCard(
            emphasis: .compact,
            accent: nil,
            cornerRadius: cornerRadius
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Today Coach card bodies (shallow types — launch stack safety)

/// Compact secondary cue for Recovery Challenge inside the Today Coach card.
private struct TodayRecoveryChallengeCue: Equatable {
    var label: String
    var showsCheckmark: Bool
}

private struct TodayElapsedClockLabel: View {
    let start: Date
    let foreground: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let text = Self.clockText(from: start, now: context.date)
            Text(text)
                .font(WeekFitType.activeTimer)
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(foreground)
                .accessibilityLabel(
                    String(
                        format: WeekFitLocalizedString("today.session.elapsedAccessibilityFormat"),
                        text
                    )
                )
        }
    }

    private static func clockText(from start: Date, now: Date) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(start)))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Shallow pending-confirm card — kept out of TodayView's opaque Coach tree.
private struct TodayPendingActivityConfirmCard: View {
    let title: String
    let message: String
    let pendingTitle: String
    let textPrimary: Color
    let cardBackground: Color
    let onConfirm: () -> Void

    private let attentionColor = Color(red: 0.95, green: 0.60, blue: 0.15)

    var body: some View {
        Button(action: onConfirm) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(attentionColor.opacity(0.10))
                        .frame(width: 36, height: 36)

                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(attentionColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(pendingTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(attentionColor)

                    Text(message)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(textPrimary.opacity(0.92))
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(attentionColor.opacity(0.45))
                    .padding(.top, 11)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [
                        attentionColor.opacity(0.05),
                        cardBackground.opacity(0.90)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(attentionColor.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pendingTitle). \(title)")
    }
}

private struct TodayCoachSettlingCardBody: View {
    let focusHeading: String
    let needsHealthConnect: Bool
    var useSyncingCopy: Bool = false
    let accent: Color
    let textPrimary: Color
    let textSecondary: Color
    let meta: Color

    private var settlingTitle: LocalizedStringResource {
        if useSyncingCopy {
            return AppText.Today.coachSettlingTitleSyncing
        }
        return AppText.Today.coachSettlingTitle
    }

    private var settlingMessage: LocalizedStringResource {
        if needsHealthConnect {
            return AppText.Today.coachSettlingMessageHealth
        }
        if useSyncingCopy {
            return AppText.Today.coachSettlingMessageSyncing
        }
        return AppText.Today.coachSettlingMessageSleep
    }

    var body: some View {
        // Match Up Next / Log Quickly: section label on its own top row.
        VStack(alignment: .leading, spacing: 8) {
            Text(focusHeading)
                .font(TodayCardTypography.sectionLabel)
                .foregroundStyle(textSecondary)

            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Circle()
                        .stroke(accent.opacity(0.20), lineWidth: 1)
                        .frame(width: 40, height: 40)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent.opacity(0.90))
                        .offset(y: 0.5)
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(settlingTitle)
                        .font(TodayCardTypography.cardTitle)
                        .foregroundStyle(textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(settlingMessage)
                        .font(TodayCardTypography.cardBody)
                        .foregroundStyle(textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(meta.opacity(0.72))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, TodayChrome.cardPadding)
        .padding(.vertical, TodayChrome.cardPadding)
    }
}

private struct TodayCoachInsightCardBody: View {
    let focusHeading: String
    let insightTitle: String
    let insightMessage: String
    let insightIcon: String
    let insightColor: Color
    let iconYOffset: CGFloat
    let durationLabel: String?
    let challengeCue: TodayRecoveryChallengeCue?
    let textPrimary: Color
    let textSecondary: Color
    let meta: Color

    var body: some View {
        // Same card anatomy as Up Next: section label → content row → optional footer.
        VStack(alignment: .leading, spacing: 8) {
            Text(focusHeading)
                .font(TodayCardTypography.sectionLabel)
                .foregroundStyle(textSecondary)

            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(insightColor.opacity(0.14))
                        .frame(width: 40, height: 40)

                    Image(systemName: insightIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(insightColor.opacity(0.95))
                        .offset(y: iconYOffset)
                }
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(insightTitle)
                            .font(TodayCardTypography.cardTitle)
                            .foregroundStyle(textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)

                        if let durationLabel, !durationLabel.isEmpty {
                            Text(durationLabel)
                                .font(WeekFitType.captionEmphasized)
                                .fontDesign(.rounded)
                                .monospacedDigit()
                                .foregroundStyle(insightColor.opacity(0.92))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(insightColor.opacity(0.14))
                                )
                                .accessibilityLabel(durationLabel)
                        }
                    }

                    if !insightMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(insightMessage)
                            .font(TodayCardTypography.cardBody)
                            .foregroundStyle(textSecondary)
                            .lineSpacing(1)
                            .multilineTextAlignment(.leading)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(meta.opacity(0.72))
                    .accessibilityHidden(true)
            }

            if let challengeCue {
                Rectangle()
                    .fill(WeekFitTheme.divider.opacity(0.45))
                    .frame(height: 1)

                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(textSecondary)
                        .frame(width: 40, alignment: .center)
                        .accessibilityHidden(true)

                    Text(challengeCue.label)
                        .font(WeekFitType.captionEmphasized)
                        .fontDesign(.rounded)
                        .foregroundStyle(textSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if challengeCue.showsCheckmark {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(WeekFitTheme.workout.opacity(0.85))
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            }
        }
        .padding(.horizontal, TodayChrome.cardPadding)
        .padding(.vertical, TodayChrome.cardPadding)
    }
}
