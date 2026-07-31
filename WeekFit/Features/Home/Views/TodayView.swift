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
    
    @StateObject private var userSettings = WeekFitUserSettings.shared

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
    
    @State private var showProfile = false
    @State private var livePulse = false
    @AppStorage(OnboardingStore.Keys.introToday) private var todayIntroDismissed = false
    @State private var drinksQuickLogToast: String?
    @State private var foodQuickLogToast: String?
    
    @State private var activityToConfirm: PlannedActivity? = nil
    @State private var queuedActivityToConfirm: PlannedActivity? = nil

    private let cardBackground = WeekFitTheme.cardSurface
    private let cardSecondary = WeekFitTheme.cardSurfaceElevated

    private var textPrimary: Color { palette.textPrimary }
    private var textSecondary: Color { palette.textSecondary }
    private var textTertiary: Color { palette.textTertiary }

    private let todayRingSize: CGFloat = 86
    private let todayRingStroke: CGFloat = 4
    private let todayPremiumBronze = Color(red: 0.72, green: 0.63, blue: 0.45)
    private let todayPremiumBronzeSoft = Color(red: 0.60, green: 0.52, blue: 0.39)

    private var todayActivityColor: Color { WeekFitProgressRingColor.activity }
    private var todayNutritionColor: Color { WeekFitProgressRingColor.nutrition }
    private var todayRecoveryColor: Color { WeekFitProgressRingColor.recovery }

    private enum TodayLayout {
        static let cardRadius: CGFloat = WeekFitSurface.primaryRadius
        /// Header spacing now lives in `WeekFitScreenLayout.headerBottomSpacing`.
        static let contentTopInset: CGFloat = 0
        static let gapBetweenCards: CGFloat = 22
        static let gapAfterOverview: CGFloat = gapBetweenCards
        static let gapAfterUpNext: CGFloat = gapBetweenCards
        static let gapBeforeQuickActions: CGFloat = gapBetweenCards
        /// Align with shared tab clearance.
        static let tabBarContentInset: CGFloat = WeekFitScreenLayout.tabBarClearance
        static let ringGroupSpacing: CGFloat = 4
        static let cardTitleBottomGap: CGFloat = 10
        static let overviewContentTopPadding: CGFloat = 13
        static let overviewContentBottomPadding: CGFloat = 14
        static let overviewHorizontalPadding: CGFloat = 16
        static let coachCardVerticalPadding: CGFloat = 19
        static let cardInteriorVerticalPadding: CGFloat = 14
        static let quickTileRadius: CGFloat = 18
        static let quickTileSpacing: CGFloat = 10
    }

    private var shouldScrollSummary: Bool {
        dynamicTypeSize >= .large
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
            return 78
        case .xxxLarge:
            return 74
        default:
            return todayRingSize
        }
    }

    private var ringCaptionLineLimit: Int {
        if shouldStackRings { return 3 }
        return dynamicTypeSize >= .xLarge ? 2 : 1
    }

    private var quickActionCaptionLineLimit: Int {
        shouldStackQuickActions ? 2 : 1
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
    @State private var quickLogDrinkRows: [QuickItemDisplayRow] = []
    @State private var quickLogSession = QuickLogSessionStore()
    @State private var quickLogCommittedUsageIDs: Set<String> = []
    @State private var quickItemUsage: [String: Int] = [:]
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
    
    private let quickItemUsageKey = "weekfit_quick_item_usage_v1"

    init(
        authViewModel: AuthViewModel,
        selectedDate: Binding<Date>,
        returnToTodayTrigger: UUID = UUID(),
        onSelectTab: @escaping (WeekFitTab) -> Void = { _ in }
    ) {
        self.authViewModel = authViewModel
        self._selectedDate = selectedDate
        self.returnToTodayTrigger = returnToTodayTrigger
        self.onSelectTab = onSelectTab
    }
    
    private enum QuickNutritionLogTab: String, CaseIterable, Identifiable {
        case meals
        case snacks

        var id: String { rawValue }

        var title: String {
            switch self {
            case .meals: return WeekFitLocalizedString("today.quickLog.section.meals")
            case .snacks: return WeekFitLocalizedString("today.quickLog.section.snacks")
            }
        }
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
        healthManager.sleepMinutes > 0 ||
        healthManager.timeInBedMinutes > 0 ||
        healthManager.hrvSDNN > 0 ||
        healthManager.restingHeartRate > 0
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
            return ("Good morning", "sun.max.fill", .orange)
        case .afternoon:
            return ("Good afternoon", "sun.max.fill", .orange)
        case .evening:
            return ("Good evening", "moon.stars.fill", Color(red: 0.55, green: 0.40, blue: 0.85))
        case .night:
            return ("Good night", "moon.fill", .indigo)
        }
    }
    
    private func incrementQuickItemUsage(_ item: QuickItem) {
        var nextUsage = quickItemUsage
        nextUsage[item.id, default: 0] += 1
        setQuickItemUsage(nextUsage, persist: true)

        if !quickLogSnacks.isEmpty {
            setQuickLogSnacks(sortByUsage(quickLogSnacks, usage: nextUsage))
        }

        if !quickLogDrinks.isEmpty {
            setQuickLogDrinks(sortByUsage(quickLogDrinks, usage: nextUsage))
        }
    }

    @ViewBuilder
    private var todayActiveBody: some View {
        let _ = languageManager.selectedLanguage

        ZStack(alignment: .bottom) {
            todayBackground

            todayScreen
                .onAppear {
                   todayViewModel.now = Date()
                   reconcileTodayDayBoundary()
                   preloadQuickFoodLogDataIfNeeded()
                   preloadQuickDrinkLogDataIfNeeded()
                   if !healthManager.isHealthAccessRequested {
                       updateNutrition()
                   }
                }

        }
    }

    var body: some View {
        Group {
            if tabIsActive {
                todayActiveBody
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.today")
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
        .task(id: todayViewModel.healthRefreshID) {
            guard tabIsActive else { return }
            await refreshHealthAndNutritionAsync()
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

            let dayActivities = todayViewModel.selectedDayActivities(
                on: selectedDate,
                from: newActivities
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

            Task {
                await todayViewModel.reconcileNutritionAfterPlannedActivitiesChange(
                    selectedDate: selectedDate,
                    plannedActivities: newActivities,
                    healthManager: healthManager,
                    nutritionViewModel: nutritionViewModel
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
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshTodayAfterAppBecameActive()
        }
        .onChange(of: returnToTodayTrigger) { _, _ in
            handleReturnToTodayRequest()
        }
        .onChange(of: appSession.localDataResetTrigger) { _, _ in
            handleLocalDataResetCompleted()
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
            let delay = checkpoint.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            guard !Task.isCancelled else { return }

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
        }
        .weekFitSettingsSheet(isPresented: $showProfile)
        .sheet(
            isPresented: $showDirectWorkoutLogSheet,
            onDismiss: {
                refreshTodayLiveState(refreshHealth: true)
            }
        ) {
            PremiumActivityStartSheet(
                background: QuickActionSheetDesign.Color.sheetBackground,
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
            .presentationDetents([
                .fraction(0.45),
                .large
            ])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
        }
        .sheet(isPresented: $showDirectMealLogSheet) {
            ZStack {
                QuickActionSheetDesign.Color.sheetBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    PremiumBottomSheetHeader(
                        title: WeekFitLocalizedString("today.quickActions.logFood"),
                        subtitle: selectedLogTab == .meals
                            ? WeekFitLocalizedString("today.quickLog.subtitle.savedFoods")
                            : WeekFitLocalizedString("today.quickLog.subtitle.drinksSnacks")
                    ) {
                        showDirectMealLogSheet = false
                    }

                    QuickActionSheetSegmentedControl(
                        segments: [
                            QuickActionSheetSegment(
                                id: QuickNutritionLogTab.meals.rawValue,
                                title: WeekFitLocalizedString("today.quickLog.section.meals"),
                                badgeCount: quickLogMealRows.count
                            ),
                            QuickActionSheetSegment(
                                id: QuickNutritionLogTab.snacks.rawValue,
                                title: WeekFitLocalizedString("today.quickLog.section.snacks"),
                                badgeCount: quickLogSnackRows.count
                            )
                        ],
                        selection: Binding(
                            get: { selectedLogTab.rawValue },
                            set: { newValue in
                                selectedLogTab = QuickNutritionLogTab(rawValue: newValue) ?? .meals
                            }
                        )
                    )
                    .padding(.horizontal, QuickActionSheetDesign.Layout.horizontalPadding)
                    .padding(.bottom, QuickActionSheetDesign.Layout.segmentedBottomPadding)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: QuickActionSheetDesign.Layout.listRowSpacing) {
                            QuickActionCoachRecommendationSlot()

                            switch selectedLogTab {

                            case .meals:
                                if quickLogMealRows.isEmpty {
                                    quickLogEmptyState(
                                        icon: "fork.knife.circle.fill",
                                        title: WeekFitLocalizedString("today.quickLog.empty.savedFood.title"),
                                        message: WeekFitLocalizedString("today.quickLog.empty.savedFood.message"),
                                        buttonTitle: WeekFitLocalizedString("today.quickLog.empty.savedFood.action"),
                                        showAction: true
                                    )
                                } else {
                                    ForEach(quickLogMealRows) { row in
                                        let profile = QuickLogNutritionProfile.from(meal: row.meal)
                                        let selection = quickLogSession.selection(for: row.id)
                                        QuickLogMealRow(
                                            row: row,
                                            accentColor: Color(red: 0.50, green: 0.74, blue: 0.54),
                                            selection: selection,
                                            displayQuantity: selection.effectivePortions(for: profile),
                                            onPlusTap: {
                                                handleQuickAdd(profile: profile)
                                            },
                                            onIncrement: {
                                                handleQuickIncrement(profile: profile)
                                            },
                                            onDecrement: {
                                                handleQuickDecrement(profile: profile)
                                            }
                                        )
                                    }
                                }

                            case .snacks:
                                if quickLogSnackRows.isEmpty {
                                    quickLogEmptyState(
                                        icon: "leaf.fill",
                                        title: WeekFitLocalizedString("today.quickLog.empty.quickItems.title"),
                                        message: WeekFitLocalizedString("today.quickLog.empty.quickItems.message"),
                                        buttonTitle: nil,
                                        showAction: false
                                    )
                                } else {
                                    ForEach(quickLogSnackRows) { row in
                                        let profile = QuickLogNutritionProfile.from(item: row.item)
                                        let selection = quickLogSession.selection(for: row.id)
                                        QuickLogItemRow(
                                            row: row,
                                            accentColor: Color(red: 0.50, green: 0.74, blue: 0.54),
                                            selection: selection,
                                            displayQuantity: selection.effectivePortions(for: profile),
                                            onPlusTap: {
                                                handleQuickAdd(profile: profile, quickItem: row.item)
                                            },
                                            onIncrement: {
                                                handleQuickIncrement(profile: profile)
                                            },
                                            onDecrement: {
                                                handleQuickDecrement(profile: profile)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, QuickActionSheetDesign.Layout.horizontalPadding)
                        .padding(.bottom, QuickActionSheetDesign.Layout.listBottomPadding)
                    }
                }
            }
            .presentationDetents([
                .fraction(0.45),
                .large
            ])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
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
        .sheet(isPresented: $showDirectDrinkLogSheet) {
            ZStack {
                QuickActionSheetDesign.Color.sheetBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    PremiumBottomSheetHeader(
                        title: WeekFitLocalizedString("today.quickActions.logDrinks"),
                        subtitle: WeekFitLocalizedString("today.quickLog.subtitle.drinks")
                    ) {
                        showDirectDrinkLogSheet = false
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: QuickActionSheetDesign.Layout.listRowSpacing) {
                            QuickActionCoachRecommendationSlot()

                            if quickLogDrinkRows.isEmpty {
                                quickLogEmptyState(
                                    icon: "drop.fill",
                                    title: WeekFitLocalizedString("today.quickLog.empty.drinks.title"),
                                    message: WeekFitLocalizedString("today.quickLog.empty.quickItems.message"),
                                    buttonTitle: nil,
                                    showAction: false
                                )
                            } else {
                                ForEach(quickLogDrinkRows) { row in
                                    let profile = QuickLogNutritionProfile.from(item: row.item)
                                    let selection = quickLogSession.selection(for: row.id)
                                    QuickLogItemRow(
                                        row: row,
                                        accentColor: Color(red: 0.25, green: 0.55, blue: 0.95),
                                        selection: selection,
                                        displayQuantity: selection.effectivePortions(for: profile),
                                        onPlusTap: {
                                            handleQuickAdd(profile: profile, quickItem: row.item)
                                        },
                                        onIncrement: {
                                            handleQuickIncrement(profile: profile)
                                        },
                                        onDecrement: {
                                            handleQuickDecrement(profile: profile)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, QuickActionSheetDesign.Layout.horizontalPadding)
                        .padding(.bottom, QuickActionSheetDesign.Layout.listBottomPadding)
                    }
                }
            }
            .presentationDetents([
                .fraction(0.45),
                .large
            ])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
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
        let usage = loadQuickItemUsage()
        let quickItems = repository.loadQuickItems()

        setQuickItemUsage(usage)
        refreshQuickLogMealsFromCatalog()
        setQuickLogSnacks(sortByUsage(quickItems.filter { $0.category == .snack }, usage: usage))
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
        setQuickLogMeals(userSettings.customMealsCatalog)
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
        let usage = loadQuickItemUsage()
        let drinks = sortByUsage(
            NutritionRepository().loadQuickItems().filter { $0.category == .drink },
            usage: usage
        )

        setQuickItemUsage(usage)
        setQuickLogDrinks(drinks)
        Self.debugEnd(
            "quickDrink.prepare drinks=\(quickLogDrinks.count)",
            start: start
        )
    }

    private func preloadQuickDrinkLogDataIfNeeded() {
        guard !didPreloadQuickDrinks else { return }
        didPreloadQuickDrinks = true
        prepareQuickDrinkLogData()
    }

    private func loadQuickItemUsage() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: quickItemUsageKey) as? [String: Int] ?? [:]
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

    private func setQuickItemUsage(_ usage: [String: Int], persist: Bool = false) {
        guard quickItemUsage != usage else { return }
        quickItemUsage = usage

        if persist {
            UserDefaults.standard.set(usage, forKey: quickItemUsageKey)
        }
    }

    private func setQuickLogMeals(_ meals: [Meals]) {
        guard quickLogMeals != meals else { return }
        quickLogMeals = meals

        let rows = makeQuickMealRows(meals)
        if quickLogMealRows != rows {
            quickLogMealRows = rows
        }
    }

    private func setQuickLogSnacks(_ snacks: [QuickItem]) {
        guard quickLogSnacks != snacks else { return }
        quickLogSnacks = snacks

        let rows = makeQuickItemRows(snacks)
        if quickLogSnackRows != rows {
            quickLogSnackRows = rows
        }
    }

    private func setQuickLogDrinks(_ drinks: [QuickItem]) {
        guard quickLogDrinks != drinks else { return }
        quickLogDrinks = drinks

        let rows = makeQuickItemRows(drinks)
        if quickLogDrinkRows != rows {
            quickLogDrinkRows = rows
        }
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
        return meals.map { meal in
            let isFoodProduct = meal.isFoodProduct
            let builderImageItems = isFoodProduct
                ? []
                : (meal.builderImageItems ?? []).sorted { $0.zIndex < $1.zIndex }

            return QuickMealDisplayRow(
                meal: meal,
                usesAssetImage: !isFoodProduct && !meal.imageName.isEmpty && UIImage(named: meal.imageName) != nil,
                sortedBuilderImageItems: builderImageItems,
                localPhotoFilename: quickMealPhotoFilename(for: meal),
                isFoodProduct: isFoodProduct,
                placeholderInitial: meal.placeholderInitial
            )
        }
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
        WeekFitScreenContainer {

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

            Group {
                if shouldScrollSummary {
                    ScrollView(.vertical, showsIndicators: false) {
                        summaryContent()
                            .padding(.top, TodayLayout.contentTopInset)
                            .padding(.bottom, 8)
                    }
                    .weekFitTransparentScrollBackground()
                } else {
                    summaryContent()
                        .padding(.top, TodayLayout.contentTopInset)
                }
            }
        }
        .padding(.bottom, TodayLayout.tabBarContentInset)

    }

    @ViewBuilder
    private var todayBackground: some View {
        if TodayAtmospherePolicy.isEnabled {
            TodayAtmosphereBackground(
                snapshot: todayAtmosphereSnapshot,
                ambientOpacity: palette.ambientOpacity
            )
            .ignoresSafeArea()
        } else {
            WeekFitTheme.appBackground
                .ignoresSafeArea()
            ambientBackground
        }
    }

    private var todayAtmosphereSnapshot: TodayAtmosphereSnapshot {
        TodayAtmosphereResolver.resolve(
            recoveryPercent: healthManager.recoveryPercent,
            hasRecoverySignals: hasTodayRecoverySignals,
            sleepHours: healthManager.sleepHours,
            activeCalories: healthManager.activeCalories,
            activityGoal: automatedActivityGoal,
            completedTrainingCount: completedTrainingCountToday,
            hour: Calendar.current.component(.hour, from: todayViewModel.now)
        )
    }

    private var completedTrainingCountToday: Int {
        selectedDayActivities.filter { activity in
            activity.isCompleted && CoachTomorrowDemandResolver.isTraining(CoachPlannedActivitySnapshot(from: activity))
        }.count
    }

    private var ambientBackground: some View {
        WeekFitTheme.todayAmbient
            .opacity(palette.ambientOpacity)
            .ignoresSafeArea()
    }
    

    private func summaryContent() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !todayIntroDismissed {
                OnboardingContextualIntroCard(
                    title: WeekFitLocalizedString("onboarding.intro.today.title"),
                    message: WeekFitLocalizedString("onboarding.intro.today.body"),
                    accent: WeekFitTheme.workout
                ) {
                    todayIntroDismissed = true
                }
                .padding(.bottom, 16)
            }

            dailyStatusSection

            upNextSection
                .padding(.top, TodayLayout.gapAfterOverview)

            coachEntryPointSection
                .padding(.top, TodayLayout.gapAfterUpNext)

            quickActionsSection
                .padding(.top, TodayLayout.gapBeforeQuickActions)
        }
    }

    private func todayCardSectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .fontDesign(.rounded)
            .tracking(palette.isLight ? 1.2 : 1.15)
            .foregroundStyle(palette.isLight ? WeekFitTheme.secondaryText : palette.textTertiary.opacity(0.68))
            .offset(y: 0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todayPremiumCard<Content: View>(
        accent: Color?,
        cornerRadius: CGFloat = TodayLayout.cardRadius,
        featured: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .weekFitPremiumCard(
                emphasis: featured ? .elevated : .standard,
                accent: accent,
                cornerRadius: cornerRadius
            )
    }

    /// Premium action surface — same card family as Coach/Up Next, tuned as the execution layer after Coach.
    private func todayActionSurfaceCard<Content: View>(
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, TodayLayout.cardInteriorVerticalPadding)
            .weekFitPremiumCard(
                emphasis: .accent,
                accent: accent,
                cornerRadius: TodayLayout.cardRadius
            )
    }

    private var todayQuickActionsAccent: Color {
        if coachCoordinator.state.canRenderTodayCoachInsight {
            return coachCoordinator.state.coachUIPresentation?.accentColor ?? WeekFitTheme.coachAccent
        }
        return WeekFitTheme.coachAccent
    }

    private var todayCoachCardAccent: Color {
        // Coach identity is purple; green is reserved for positive status chips.
        WeekFitTheme.coachAccent
    }

    private func todayOverviewShell<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, TodayLayout.overviewHorizontalPadding)
            .padding(.top, TodayLayout.overviewContentTopPadding)
            .padding(.bottom, TodayLayout.overviewContentBottomPadding)
            .frame(maxWidth: .infinity)
            .weekFitPremiumCard(
                emphasis: .elevated,
                accent: nil,
                cornerRadius: TodayLayout.cardRadius
            )
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

    private func coachSettlingCard(needsHealthConnect: Bool) -> some View {
        todayPremiumCard(accent: todayCoachCardAccent, featured: true) {
            HStack(alignment: .top, spacing: 14) {
                coachSettlingGlyph
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppText.Today.coachInsightLabel)
                        .font(.caption2.weight(.bold))
                        .fontDesign(.rounded)
                        .tracking(1.45)
                        .foregroundStyle(todayCoachCardAccent.opacity(0.78))

                    Text(AppText.Today.coachSettlingTitle)
                        .font(.callout.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(textPrimary)
                        .padding(.top, 2)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        needsHealthConnect
                            ? AppText.Today.coachSettlingMessageHealth
                            : AppText.Today.coachSettlingMessageSleep
                    )
                        .font(.footnote)
                        .fontDesign(.rounded)
                        .foregroundStyle(textSecondary.opacity(0.68))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, TodayLayout.coachCardVerticalPadding)
        }
        .onAppear {
            logTodayCoachInsightHiddenIfNeeded()
            guard !livePulse else { return }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                livePulse = true
            }
        }
    }

    private func coachPreparingCard() -> some View {
        todayPremiumCard(accent: todayCoachCardAccent, featured: true) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(todayCoachCardAccent.opacity(0.11))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(todayCoachCardAccent.opacity(0.20), lineWidth: 1)
                        }

                    Image(systemName: CoachState.registryGapIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(todayCoachCardAccent.opacity(0.90))
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppText.Today.coachInsightLabel)
                        .font(.caption2.weight(.bold))
                        .fontDesign(.rounded)
                        .tracking(1.45)
                        .foregroundStyle(todayCoachCardAccent.opacity(0.78))

                    Text(CoachState.registryGapTitle)
                        .font(.callout.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(textPrimary)
                        .padding(.top, 2)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(CoachState.registryGapMessage)
                        .font(.footnote)
                        .fontDesign(.rounded)
                        .foregroundStyle(textSecondary.opacity(0.68))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, TodayLayout.coachCardVerticalPadding)
        }
    }

    private var todayLimitedRecoveryChip: some View {
        Text(AppText.Today.coachChipLimitedRecovery)
            .font(.caption2.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(textSecondary.opacity(0.68))
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

    private var coachSettlingGlyph: some View {
        ZStack {
            Circle()
                .fill(todayCoachCardAccent.opacity(livePulse ? 0.16 : 0.09))
                .frame(width: 40, height: 40)
                .blur(radius: livePulse ? 1 : 0)

            Circle()
                .fill(todayCoachCardAccent.opacity(0.11))
                .frame(width: 40, height: 40)
                .overlay {
                    Circle()
                        .stroke(todayCoachCardAccent.opacity(0.20), lineWidth: 1)
                }

            Image(systemName: "brain.head.profile")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(todayCoachCardAccent.opacity(0.90))
                .offset(y: 0.5)
                .scaleEffect(livePulse ? 1.03 : 0.97)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }
    
    private var plannedActivitiesForSelectedDate: [PlannedActivity] {
        plannedActivities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
    }
    
    private var coachEntryPointSection: some View {
        Group {
//            if shouldShowEveningReview {
//                eveningReviewEntryPoint
//            } else {
                coachInsightSection
//            }
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
                        .foregroundStyle(textSecondary.opacity(0.72))
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

    private var dailyStatusSection: some View {
        let baseGoal = automatedActivityGoal
        let activityProgress = baseGoal > 0 ? healthManager.activeCalories / baseGoal : 0
        let activityPercent = Int(activityProgress * 100)
        let activityDisplayText = healthManager.activeCalories > 0 && activityProgress > 0 && activityProgress < 0.01
            ? "<1%"
            : "\(activityPercent)%"

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

        let recoveryDisplayValue: Int? =
            recoveryRingMode == .hasData ? recoveryPercent : nil

        let activityColor = todayActivityColor
        let nutritionColor = todayNutritionColor
        let recoveryColor = recoveryRingMode == .sleepNotRecorded
            ? textSecondary.opacity(0.58)
            : todayRecoveryColor

        let activityGoalText = String(format: WeekFitLocalizedString("today.status.activity.goalFormat"), Int(baseGoal))
        let activityValueText = String(format: WeekFitLocalizedString("common.unit.caloriesFormat"), Int(healthManager.activeCalories))

        let sleepValueInfoText = healthManager.sleepMinutes > 0
            ? String(format: WeekFitLocalizedString("today.sleep.valueFormat"), Double(healthManager.sleepMinutes) / 60.0)
            : WeekFitLocalizedString("today.sleep.empty")

        let recoverySleepRingText: String = {
            switch recoveryRingMode {
            case .sleepNotRecorded:
                return WeekFitLocalizedString("today.recovery.sleepNotRecorded")
            case .awaitingMorningSync, .hasData:
                return sleepValueInfoText
            }
        }()

        let recoveryInfoRingText: String = {
            switch recoveryRingMode {
            case .hasData:
                return recoveryStatusLabel(for: recoveryPercent)
            case .awaitingMorningSync:
                return WeekFitLocalizedString("today.recovery.syncingSleep")
            case .sleepNotRecorded:
                return WeekFitLocalizedString("today.recovery.unavailable")
            }
        }()

        return Group {
            if shouldShowHealthConnectPrompt {
                todayPremiumCard(accent: todayActivityColor, cornerRadius: 22) {
                    VStack(spacing: 16) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "heart.text.square.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.red)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(AppText.Today.connectAppleHealth)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(textPrimary)

                                Text(AppText.Today.healthDescription)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(textSecondary)
                                    .lineSpacing(2)
                            }
                        }
                        .padding(.top, 4)

                        Button {
                            handleConnectAppleHealthTap()
                        } label: {
                            HStack {
                                Image(systemName: healthManager.isHealthAuthorizationInFlight ? "hourglass" : "arrow.triangle.2.circlepath")
                                    .font(.system(size: 13, weight: .bold))

                                Text(AppText.Today.connectAppleHealth)
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                todayActivityColor,
                                                todayActivityColor.opacity(0.82)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                            .shadow(color: todayActivityColor.opacity(0.22), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                        .disabled(healthManager.isHealthAuthorizationInFlight)
                        .accessibilityIdentifier("today.connectAppleHealth")
                    }
                    .padding(16)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))

            } else {
                todayOverviewShell {
                    VStack(alignment: .leading, spacing: 0) {
                        todayCardSectionTitle(WeekFitLocalizedString("today.overview.title"))
                            .padding(.bottom, 8)

                        Group {
                            if shouldStackRings {
                                VStack(spacing: 16) {
                                    dailyStatusActivityRingButton(
                                        activityGoalText: activityGoalText,
                                        activityValueText: activityValueText,
                                        activityPercent: activityPercent,
                                        activityDisplayText: activityDisplayText,
                                        activityColor: activityColor
                                    )

                                    dailyStatusNutritionRingButton(
                                        eatenCalories: eatenCalories,
                                        nutritionPercent: nutritionPercent,
                                        nutritionColor: nutritionColor
                                    )

                                    dailyStatusRecoveryRingButton(
                                        recoveryDisplayValue: recoveryDisplayValue,
                                        recoverySleepRingText: recoverySleepRingText,
                                        recoveryInfoRingText: recoveryInfoRingText,
                                        recoveryColor: recoveryColor
                                    )
                                }
                            } else {
                                HStack(alignment: .center, spacing: TodayLayout.ringGroupSpacing) {
                                    dailyStatusActivityRingButton(
                                        activityGoalText: activityGoalText,
                                        activityValueText: activityValueText,
                                        activityPercent: activityPercent,
                                        activityDisplayText: activityDisplayText,
                                        activityColor: activityColor
                                    )

                                    dailyStatusNutritionRingButton(
                                        eatenCalories: eatenCalories,
                                        nutritionPercent: nutritionPercent,
                                        nutritionColor: nutritionColor
                                    )

                                    dailyStatusRecoveryRingButton(
                                        recoveryDisplayValue: recoveryDisplayValue,
                                        recoverySleepRingText: recoverySleepRingText,
                                        recoveryInfoRingText: recoveryInfoRingText,
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
        activityColor: Color
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            openActivityIntelligence()
        } label: {
            statusRingWidget(
                title: WeekFitLocalizedString("today.status.activity"),
                infoText: activityGoalText,
                valueText: activityValueText,
                value: activityPercent,
                centerText: activityDisplayText,
                color: activityColor
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(TodayScaleButtonStyle())
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
                title: WeekFitLocalizedString("today.status.nutrition"),
                infoText: remainingCaloriesText,
                valueText: String(format: WeekFitLocalizedString("common.unit.caloriesFormat"), Int(eatenCalories)),
                value: nutritionPercent,
                color: nutritionColor
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
        recoveryInfoRingText: String,
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
                infoText: recoveryInfoRingText,
                valueText: recoverySleepRingText,
                value: recoveryDisplayValue,
                color: recoveryColor
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
        color: Color
    ) -> some View {
        let displayValue = value ?? 0
        let progress = CGFloat(displayValue) / 100.0
        let ringSize = todayEffectiveRingSize
        let ringStroke = max(3, todayRingStroke * (ringSize / todayRingSize))

        return VStack(spacing: 6) {
            WeekFitProgressRing(
                progress: value == nil ? 0 : progress,
                color: color,
                size: ringSize,
                strokeWidth: ringStroke
            ) {
                Text(value == nil ? "—" : (centerText ?? "\(displayValue)%"))
                    .font(.title3.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .offset(y: value == nil ? 1 : 0.5)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary.opacity(palette.isLight ? 0.88 : 0.94))
                    .lineLimit(ringCaptionLineLimit)
                    .minimumScaleFactor(0.85)

                Text(valueText)
                    .font(.caption.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(palette.isLight ? color : color.opacity(1))
                    .lineLimit(ringCaptionLineLimit)
                    .minimumScaleFactor(0.84)

                if !infoText.isEmpty {
                    Text(infoText)
                        .font(.caption2.weight(.medium))
                        .fontDesign(.rounded)
                        .foregroundStyle(
                            palette.isLight
                                ? WeekFitTheme.secondaryText
                                : textSecondary.opacity(0.58)
                        )
                        .lineLimit(ringCaptionLineLimit)
                        .minimumScaleFactor(0.82)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var upNextSection: some View {
        let now = Date()

        let activeSession = currentLiveUpNextActivity(now: now)
        let nextActivity = activeSession == nil
            ? nextUpcomingPlannedActivity(now: now)
            : nil

        return Group {
            if let activeSession {
                todayPremiumCard(accent: palette.isLight ? nil : todayPremiumBronze, featured: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        todayCardSectionTitle(WeekFitLocalizedString("today.upNext.title"))
                            .padding(.bottom, TodayLayout.cardTitleBottomGap)

                        VStack(alignment: .leading, spacing: shouldRelocateUpNextTime ? 8 : 0) {
                            HStack(alignment: .top, spacing: 12) {
                                upNextIconBadge(
                                    systemName: upNextIcon(for: activeSession, isLive: true),
                                    accent: todayPremiumBronze
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(AppText.Today.currentSession)
                                        .font(.subheadline.weight(.bold))
                                        .fontDesign(.rounded)
                                        .foregroundStyle(textPrimary.opacity(0.94))

                                    Text(String(format: WeekFitLocalizedString("today.upNext.inProgressFormat"), shortDisplayTitle(activityDisplayTitle(activeSession))))
                                        .font(.caption.weight(.medium))
                                        .fontDesign(.rounded)
                                        .foregroundStyle(textTertiary)
                                        .lineLimit(shouldRelocateUpNextTime ? 3 : 2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                if !shouldRelocateUpNextTime {
                                    Spacer(minLength: 8)

                                    Text(AppText.Today.live)
                                        .font(.caption2.weight(.bold))
                                        .fontDesign(.rounded)
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            todayPremiumBronze.opacity(0.96),
                                                            todayPremiumBronzeSoft.opacity(0.88)
                                                        ],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                        )
                                        .offset(y: 0.5)
                                }
                            }

                            if shouldRelocateUpNextTime {
                                HStack {
                                    Spacer(minLength: 0)
                                    Text(AppText.Today.live)
                                        .font(.caption2.weight(.bold))
                                        .fontDesign(.rounded)
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            todayPremiumBronze.opacity(0.96),
                                                            todayPremiumBronzeSoft.opacity(0.88)
                                                        ],
                                                        startPoint: .top,
                                                        endPoint: .bottom
                                                    )
                                                )
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, TodayLayout.cardInteriorVerticalPadding)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    String(
                        format: WeekFitLocalizedString("today.upNext.liveAccessibilityFormat"),
                        shortDisplayTitle(activityDisplayTitle(activeSession))
                    )
                )
            } else if let activity = nextActivity {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelectTab(.calendar)
                } label: {
                    todayPremiumCard(accent: palette.isLight ? nil : todayPremiumBronze.opacity(0.75), featured: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            todayCardSectionTitle(WeekFitLocalizedString("today.upNext.title"))
                                .padding(.bottom, TodayLayout.cardTitleBottomGap)

                            VStack(alignment: .leading, spacing: shouldRelocateUpNextTime ? 8 : 0) {
                                HStack(alignment: .top, spacing: 12) {
                                    upNextIconBadge(
                                        systemName: upNextIcon(for: activity),
                                        accent: upNextAccent(for: activity)
                                    )

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(shortDisplayTitle(activityDisplayTitle(activity)))
                                            .font(.subheadline.weight(.bold))
                                            .fontDesign(.rounded)
                                            .foregroundStyle(textPrimary.opacity(0.94))

                                        Text(upNextSubtitle(for: activity))
                                            .font(.caption.weight(.medium))
                                            .fontDesign(.rounded)
                                            .foregroundStyle(textTertiary)
                                            .lineLimit(shouldRelocateUpNextTime ? 3 : 2)
                                            .fixedSize(horizontal: false, vertical: true)

                                        if let kind = coachProvenanceKind(for: activity) {
                                            CoachProvenanceBadge(kind: kind, showsLabel: true, compact: true)
                                                .padding(.top, 2)
                                        }
                                    }
                                    .layoutPriority(1)

                                    if !shouldRelocateUpNextTime {
                                        Spacer(minLength: 8)

                                        upNextTimePill(
                                            text: upNextTimeText(for: activity, selectedDate: selectedDate)
                                        )
                                    }
                                }

                                if shouldRelocateUpNextTime {
                                    HStack {
                                        Spacer(minLength: 0)
                                        upNextTimePill(
                                            text: upNextTimeText(for: activity, selectedDate: selectedDate)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, TodayLayout.cardInteriorVerticalPadding)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    String(
                        format: WeekFitLocalizedString("today.upNext.upcomingAccessibilityFormat"),
                        shortDisplayTitle(activityDisplayTitle(activity)),
                        upNextSubtitle(for: activity)
                    )
                )

            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelectTab(.calendar)
                } label: {
                    todayPremiumCard(accent: nil, featured: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            todayCardSectionTitle(WeekFitLocalizedString("today.upNext.title"))
                                .padding(.bottom, TodayLayout.cardTitleBottomGap)

                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(todayActivityColor)
                                    .offset(y: -0.5)

                                Text(AppText.Today.noActivitiesPlanned)
                                    .font(.footnote.weight(.medium))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(textSecondary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(textTertiary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, TodayLayout.cardInteriorVerticalPadding)
                    }
                }
                .buttonStyle(.plain)
            }
        }
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

    private func upNextAccent(for activity: PlannedActivity) -> Color {
        switch activity.type.lowercased() {
        case "meal", "drink", "hydration":
            return WeekFitTheme.meal
        case "workout":
            return todayActivityColor
        case "recovery":
            return palette.isLight ? WeekFitLightTokens.coachPurple : WeekFitTheme.recovery
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
            size: .lg,
            shape: .circle,
            backgroundOpacity: palette.isLight ? 0.16 : 0.14,
            strokeOpacity: 1,
            strokeWidth: 1,
            fillColor: palette.isLight
                ? accent.opacity(0.14)
                : WeekFitTheme.whiteOpacity(0.07),
            strokeColor: palette.isLight
                ? accent.opacity(0.32)
                : accent.opacity(0.22),
            iconColor: palette.isLight ? accent : accent.opacity(0.92)
        )
    }
    
    private func nextUpcomingPlannedActivity(
        now: Date,
        excludingActivityID: PersistentIdentifier? = nil
    ) -> PlannedActivity? {
        let calendar = Calendar.current

        func isCandidate(_ activity: PlannedActivity) -> Bool {
            guard !activity.isCompleted, !activity.isSkipped else { return false }
            guard activity.date > now else { return false }
            if let excludingActivityID, activity.id == excludingActivityID {
                return false
            }
            return true
        }

        let upcoming = plannedActivities
            .filter(isCandidate)
            .sorted { $0.date < $1.date }

        guard !upcoming.isEmpty else { return nil }

        let viewingToday = calendar.isDate(selectedDate, inSameDayAs: now)
        guard viewingToday else {
            return upcoming.first {
                calendar.isDate($0.date, inSameDayAs: selectedDate)
            }
        }

        if let today = upcoming.first(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
            return today
        }

        guard let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) else {
            return nil
        }

        return upcoming.first { calendar.isDate($0.date, inSameDayAs: tomorrow) }
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
        selectedDayActivities
            .filter { $0.terminalState(now: now) == .active }
            .sorted { $0.date < $1.date }
            .first
    }

    private func currentActiveSession(now: Date = Date()) -> PlannedActivity? {
        selectedDayActivities.first { activity in
            let type = activity.type.lowercased()

            guard type == "workout" || type == "recovery" else { return false }
            return activity.terminalState(now: now) == .active
        }
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

    private func coachInsightCard(presentation: CoachUIPresentation) -> some View {
        let insightColor = WeekFitTheme.coachAccent
        let insightTitle = presentation.todayTitle
        let insightIcon = presentation.icon
        let insightMessage = presentation.showsLimitedConfidenceBadge
            ? presentation.recommendation
            : presentation.todayMessage

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            ProductAnalytics.todayPrimaryActionTapped(.coach)
            onSelectTab(.coach)
        } label: {
            todayPremiumCard(accent: insightColor, featured: true) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(insightColor.opacity(0.11))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Circle()
                                    .stroke(insightColor.opacity(0.18), lineWidth: 1)
                            }

                        Image(systemName: insightIcon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(insightColor.opacity(0.92))
                            .offset(y: coachIconOpticalYOffset(insightIcon))
                    }
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppText.Today.coachInsightLabel)
                            .font(.caption2.weight(.bold))
                            .fontDesign(.rounded)
                            .tracking(1.45)
                            .foregroundStyle(insightColor.opacity(0.78))

                        Text(insightTitle)
                            .font(.callout.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(textPrimary)
                            .padding(.top, 2)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                            .lineSpacing(1)
                            .minimumScaleFactor(0.92)
                            .fixedSize(horizontal: false, vertical: true)
                            .layoutPriority(1)

                        if !insightMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(insightMessage)
                                .font(.footnote)
                                .fontDesign(.rounded)
                                .foregroundStyle(textSecondary.opacity(0.68))
                                .lineSpacing(2)
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if presentation.showsLimitedConfidenceBadge {
                            todayLimitedRecoveryChip
                                .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(textTertiary.opacity(0.75))
                        .padding(.top, 10)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, TodayLayout.coachCardVerticalPadding)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                format: "%@: %@. %@",
                String(localized: AppText.Today.coachInsightLabel),
                insightTitle,
                insightMessage
            )
        )
        .accessibilityHint(WeekFitLocalizedString("today.coachInsight.opensCoach"))
        .transition(.identity)
    }

    private var coachInsightSection: some View {
        let now = todayViewModel.now

        // 1. Поиск пропущенных активностей, требующих подтверждения
        let pendingActivity = selectedDayActivities.first { activity in
            let eventEndDate = Calendar.current.date(
                byAdding: .minute,
                value: activity.effectiveDurationMinutes,
                to: activity.date
            ) ?? activity.date

            return activity.terminalState(now: now) == .planned
                && now > eventEndDate
                && !isCoveredByActiveSession(activity)
        }

        return Group {
            if let pending = pendingActivity {
                let attentionColor = Color(red: 0.95, green: 0.60, blue: 0.15)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    presentActivityConfirmation(pending)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(attentionColor.opacity(0.10))
                                .frame(width: 36, height: 36)

                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(attentionColor)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(AppText.Today.pendingActionTitle)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(attentionColor)

                            Text(String(format: WeekFitLocalizedString("today.pending.messageFormat"), pending.title))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(textPrimary.opacity(0.92))
                                .lineSpacing(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Image(systemName: "chevron.up.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(attentionColor.opacity(0.45))
                            .padding(.top, 11)
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

            } else {
                coachInsightWithOptionalProposalOverlay
            }
        }
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
        }
        .onAppear {
            refreshMorningProposal()
        }
        .onChange(of: coachCoordinator.state.id) { _, _ in
            refreshMorningProposal()
        }
        .onChange(of: healthManager.settledMetricsDayStart) { _, _ in
            refreshMorningProposal()
        }
        .onChange(of: hasTodayRecoverySignals) { _, hasSignals in
            guard hasSignals else { return }
            refreshMorningProposal()
        }
        .onChange(of: morningProposal?.id) { _, _ in
            morningProposalChromeHidden = false
        }
    }

    @ViewBuilder
    private var coachInsightWithOptionalProposalOverlay: some View {
        // Stack proposal on top of the regular coach card (same footprint, WeekFit chrome —
        // no grey material overlay). Full copy lives in Review.
        let showProposal = !morningProposalChromeHidden && morningProposalCard() != nil

        Group {
            if showProposal, let proposalCard = morningProposalCard() {
                morningProposalStackedOverCoach(front: proposalCard)
            } else {
                coachInsightPhaseContent
            }
        }
        .animation(.easeOut(duration: 0.22), value: showProposal)
    }

    @ViewBuilder
    private var coachInsightPhaseContent: some View {
        switch todayCoachInsightPhase {
        case .insight(let presentation, _):
            coachInsightCard(presentation: presentation)
        case .awaitingHealthConnect:
            coachSettlingCard(needsHealthConnect: true)
        case .awaitingMorningSync:
            coachSettlingCard(needsHealthConnect: false)
        case .preparing:
            coachPreparingCard()
        }
    }

    /// Bevel-style stack: front proposal card + underlays (coach silhouette) peeking below.
    private func morningProposalStackedOverCoach<Front: View>(front: Front) -> some View {
        let radius = TodayLayout.cardRadius
        let peek: CGFloat = 9

        return front
            .background(alignment: .top) {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    ZStack {
                        // Deepest sheet — same family as WeekFit cards, slightly inset.
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(WeekFitTheme.cardSurface.opacity(0.78))
                            .overlay {
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .strokeBorder(WeekFitTheme.whiteOpacity(0.07), lineWidth: 1)
                            }
                            .frame(width: w * 0.94, height: h)
                            .shadow(color: Color.black.opacity(0.30), radius: 12, y: 8)
                            .offset(y: peek * 2)

                        // Mid sheet — faded coach face so the stack reads as “over coach”.
                        morningProposalCoachUnderlayFace
                            .frame(width: w * 0.97, height: h, alignment: .topLeading)
                            .background {
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .fill(WeekFitTheme.cardSurfaceElevated)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                                            .fill(coachUnderlayAccent.opacity(0.08))
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                                            .strokeBorder(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                                    }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                            .shadow(color: Color.black.opacity(0.24), radius: 8, y: 5)
                            .offset(y: peek)
                    }
                    .frame(width: w, height: h, alignment: .top)
                    .allowsHitTesting(false)
                }
            }
            .padding(.bottom, peek * 2 + 2)
    }

    private var coachUnderlayAccent: Color {
        if case .insight(let presentation, _) = todayCoachInsightPhase {
            return presentation.accentColor
        }
        return WeekFitTheme.coachAccent
    }

    @ViewBuilder
    private var morningProposalCoachUnderlayFace: some View {
        let accent = coachUnderlayAccent
        let title: String = {
            if case .insight(let presentation, _) = todayCoachInsightPhase {
                return presentation.todayTitle
            }
            return WeekFitLocalizedString("coach.proposal.chrome.readyTitle")
        }()

        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(accent.opacity(0.11))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(accent.opacity(0.55))
                }
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppText.Today.coachInsightLabel)
                    .font(.caption2.weight(.bold))
                    .fontDesign(.rounded)
                    .tracking(1.45)
                    .foregroundStyle(accent.opacity(0.45))
                Text(title)
                    .font(.callout.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary.opacity(0.42))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, TodayLayout.coachCardVerticalPadding)
        .opacity(0.9)
    }

    private func morningProposalCard() -> AnyView? {
        let chrome = MorningProposalPresenter.chromeState(for: morningProposal)
        switch chrome {
        case .gathering:
            return AnyView(morningProposalGatheringCard())
        case .proposalReady(let changeCount, let guidanceCount):
            return AnyView(morningProposalReadyCard(changeCount: changeCount, guidanceCount: guidanceCount))
        case .noChangesNeeded:
            return AnyView(morningProposalNoChangesCard())
        case .applied:
            guard let dayKey = morningProposal?.dayKey,
                  MorningProposalPresenter.shouldShowAppliedAcknowledgment(dayKey: dayKey),
                  CoachAppliedAcknowledgmentCopy.planAdjustmentMode(forDayKey: dayKey) == .appliedExecuting else {
                return nil
            }
            return AnyView(morningProposalAppliedCard(dayKey: dayKey))
        case .stale:
            return AnyView(morningProposalStaleCard())
        case .failed:
            return AnyView(morningProposalFailedCard())
        case .hidden, .unavailable:
            return nil
        }
    }

    private func morningProposalGatheringCard() -> some View {
        morningProposalDismissibleChrome(accent: WeekFitTheme.coachAccent) {
            dismissMorningProposalChrome(permanent: false)
        } content: {
            HStack(alignment: .top, spacing: 14) {
                ProgressView()
                    .tint(WeekFitTheme.coachAccent)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(WeekFitLocalizedString("coach.proposal.chrome.eyebrow"))
                        .font(.caption2.weight(.bold))
                        .fontDesign(.rounded)
                        .tracking(1.45)
                        .foregroundStyle(WeekFitTheme.coachAccent.opacity(0.78))
                    Text(WeekFitLocalizedString("coach.proposal.chrome.gathering"))
                        .font(.callout.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(textPrimary)
                        .lineLimit(2)
                }
                Spacer(minLength: 28)
            }
        }
    }

    private func morningProposalReadyCard(changeCount: Int, guidanceCount: Int) -> some View {
        let givenName = ProfileService.resolvedGivenName()
        let weatherLine = MorningProposalBriefComposer.weatherMetaLine(
            from: morningWeatherSummary
        )
        let brief = morningProposal.map {
            MorningProposalBriefComposer.compose(
                proposal: $0,
                givenName: givenName.isEmpty ? nil : givenName,
                weatherLine: weatherLine
            )
        }

        let title = brief?.headline
            ?? MorningProposalStrategyCopy.localizedSummary(for: morningProposal?.strategy)
            ?? WeekFitLocalizedString("coach.proposal.chrome.readyTitle")
        let actionLines = brief?.actionLines ?? []
        let metaLine = brief?.metaLine

        return morningProposalDismissibleChrome(accent: WeekFitTheme.recovery) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            morningProposalChromeHidden = true
            showProposalReview = true
        } onClose: {
            dismissMorningProposalChrome(permanent: true)
        } content: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(WeekFitTheme.recovery.opacity(0.14))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(WeekFitTheme.recovery.opacity(0.22), lineWidth: 1)
                        }
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.recovery.opacity(0.95))
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(brief?.eyebrow ?? WeekFitLocalizedString("coach.proposal.chrome.eyebrow"))
                        .font(.caption2.weight(.bold))
                        .fontDesign(.rounded)
                        .tracking(1.45)
                        .foregroundStyle(WeekFitTheme.recovery.opacity(0.78))

                    Text(title)
                        .font(.callout.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .minimumScaleFactor(0.88)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(title)

                    if !actionLines.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(actionLines.prefix(3).enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(WeekFitTheme.recovery.opacity(0.78))
                                    Text(line)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(textSecondary.opacity(0.88))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(.top, 1)
                    } else if changeCount > 0 || guidanceCount > 0 {
                        // Fallback if brief empty but counts exist.
                        Text(
                            [
                                changeCount > 0
                                    ? String(
                                        format: WeekFitLocalizedString(
                                            changeCount == 1
                                                ? "coach.proposal.chrome.adjustmentCount.one"
                                                : "coach.proposal.chrome.adjustmentCount.other"
                                        ),
                                        changeCount
                                    )
                                    : nil,
                                guidanceCount > 0
                                    ? String(
                                        format: WeekFitLocalizedString(
                                            guidanceCount == 1
                                                ? "coach.proposal.chrome.guidanceCount.one"
                                                : "coach.proposal.chrome.guidanceCount.other"
                                        ),
                                        guidanceCount
                                    )
                                    : nil,
                            ]
                            .compactMap { $0 }
                            .joined(separator: " · ")
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeekFitTheme.recovery.opacity(0.88))
                        .lineLimit(1)
                    }

                    if let metaLine, !metaLine.isEmpty {
                        Text(metaLine)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(textSecondary.opacity(0.62))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        Spacer(minLength: 0)
                        Text(brief?.ctaTitle ?? WeekFitLocalizedString("coach.proposal.chrome.reviewCTA.short"))
                            .font(.caption.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(WeekFitTheme.recovery.opacity(0.92))
                            }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            if let proposal = morningProposal {
                MorningProposalAnalytics.proposalViewed(
                    proposalId: proposal.id,
                    changeCount: proposal.changes.count
                )
            }
        }
    }

    private func morningProposalNoChangesCard() -> some View {
        morningProposalDismissibleChrome(accent: WeekFitTheme.coachAccent) {
            dismissMorningProposalChrome(permanent: true)
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text(WeekFitLocalizedString("coach.proposal.chrome.eyebrow"))
                    .font(.caption2.weight(.bold))
                    .fontDesign(.rounded)
                    .tracking(1.45)
                    .foregroundStyle(WeekFitTheme.coachAccent.opacity(0.78))
                Text(WeekFitLocalizedString("coach.proposal.chrome.noChangesTitle"))
                    .font(.callout.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                Text(WeekFitLocalizedString("coach.proposal.chrome.noChangesBody"))
                    .font(.footnote)
                    .foregroundStyle(textSecondary.opacity(0.72))
                    .lineLimit(2)
            }
            .padding(.trailing, 18)
        }
    }

    private func morningProposalAppliedCard(dayKey: String) -> some View {
        morningProposalDismissibleChrome(accent: WeekFitTheme.recovery) {
            morningProposalChromeHidden = true
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text(WeekFitLocalizedString("coach.proposal.chrome.eyebrow"))
                    .font(.caption2.weight(.bold))
                    .fontDesign(.rounded)
                    .tracking(1.45)
                    .foregroundStyle(WeekFitTheme.recovery.opacity(0.78))
                Text(WeekFitLocalizedString("coach.proposal.chrome.appliedTitle"))
                    .font(.callout.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                Text(WeekFitLocalizedString("coach.proposal.chrome.appliedBody"))
                    .font(.footnote)
                    .foregroundStyle(textSecondary.opacity(0.72))
                    .lineLimit(2)
            }
            .padding(.trailing, 18)
        }
        .onAppear {
            MorningProposalPresenter.markAppliedAcknowledgmentShown(dayKey: dayKey)
            MorningProposalAnalytics.coachAcknowledgmentViewed(dayKey: dayKey)
        }
    }

    private func morningProposalStaleCard() -> some View {
        morningProposalDismissibleChrome(accent: WeekFitTheme.recovery) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            morningProposalChromeHidden = true
            refreshMorningProposal(forceRegenerate: true)
            morningProposalChromeHidden = false
        } onClose: {
            dismissMorningProposalChrome(permanent: true)
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text(WeekFitLocalizedString("coach.proposal.chrome.eyebrow"))
                    .font(.caption2.weight(.bold))
                    .fontDesign(.rounded)
                    .tracking(1.45)
                    .foregroundStyle(WeekFitTheme.recovery.opacity(0.78))
                Text(WeekFitLocalizedString("coach.proposal.chrome.staleTitle"))
                    .font(.callout.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                Text(WeekFitLocalizedString("coach.proposal.chrome.staleBody"))
                    .font(.footnote)
                    .foregroundStyle(textSecondary.opacity(0.72))
                    .lineLimit(2)
            }
            .padding(.trailing, 18)
        }
    }

    private func morningProposalFailedCard() -> some View {
        morningProposalDismissibleChrome(accent: WeekFitTheme.recovery) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            morningProposalChromeHidden = true
            refreshMorningProposal(forceRegenerate: true)
            morningProposalChromeHidden = false
        } onClose: {
            dismissMorningProposalChrome(permanent: true)
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text(WeekFitLocalizedString("coach.proposal.chrome.eyebrow"))
                    .font(.caption2.weight(.bold))
                    .fontDesign(.rounded)
                    .tracking(1.45)
                    .foregroundStyle(WeekFitTheme.recovery.opacity(0.78))
                Text(WeekFitLocalizedString("coach.proposal.chrome.failedTitle"))
                    .font(.callout.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                Text(WeekFitLocalizedString("coach.proposal.chrome.failedBody"))
                    .font(.footnote)
                    .foregroundStyle(textSecondary.opacity(0.72))
                    .lineLimit(2)
            }
            .padding(.trailing, 18)
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
        let now = Date()
        let calendar = Calendar.current
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: now, calendar: calendar)

        Task { @MainActor in
            let (cached, _) = await WeekFitWeatherProvider.shared.cachedSummaryAndFreshness()
            if morningWeatherSummary != cached {
                morningWeatherSummary = cached
            }
        }

        if forceRegenerate {
            MorningProposalStore.remove(dayKey: dayKey)
        }

        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let todayActivities = plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: todayStart) }
            .map(CoachPlannedActivitySnapshot.init(from:))
        let tomorrowActivities = plannedActivities
            .filter { calendar.isDate($0.date, inSameDayAs: tomorrowStart) }
            .map(CoachPlannedActivitySnapshot.init(from:))

        let coachState = coachCoordinator.state
        let readiness: CoachDayReadiness = {
            if let input = coachState.input {
                return CoachDayReadinessResolver.resolve(from: input)
            }
            let percent = Int(healthManager.readyScore.rounded())
            let sleepHours = Double(healthManager.sleepMinutes) / 60.0
            return CoachDayReadiness(
                recoveryPercent: percent,
                sleepHours: sleepHours,
                recoveryBand: percent >= 70 ? .good : (percent >= 55 ? .moderate : .low),
                hadHeavyYesterday: false,
                sleepIsLow: sleepHours > 0 && sleepHours < 6,
                recoveryDataAvailable: percent > 0 || sleepHours > 0
            )
        }()

        let scenarioKey = coachState.coachIntegrationDebug?.scenario
        let tomorrowDemand = CoachTomorrowDemandResolver.resolve(activities: tomorrowActivities).level

        let completedWalkToday = todayActivities.contains {
            $0.isCompleted && CoachActivityClassifier.type(for: $0) == .walk
        }

        let hasCompletedPlannedItemToday = todayActivities.contains {
            ($0.isCompleted || $0.isPartialCompletion || ($0.actualDurationMinutes ?? 0) > 0) && !$0.isSkipped
        }

        let isMorningWindow = CoachMorningOverviewPolicy.isBeforeLocalNoon(now: now, calendar: calendar)
        let healthSettled = healthManager.hasSettledMetrics(for: selectedDate)
        // Recovery rings can populate before the settled flag flips; don't block the proposal on that race.
        let healthRefreshCompleted = healthSettled || hasTodayRecoverySignals
        let existingProposal = MorningProposalStore.proposal(for: dayKey)
        let healthRefreshTimedOut = !healthRefreshCompleted
            && existingProposal?.status == .gatheringData
            && now.timeIntervalSince(existingProposal?.generatedAt ?? now)
                >= MorningProposalGate.healthTimeoutSeconds

        let recentDayTemplates = buildRecentDayTemplates(
            from: plannedActivities,
            excludingDayStart: todayStart,
            calendar: calendar,
            lookbackDays: 90
        )
        let observationContextRevision = ProposalObservationContextRevision.make(from: recentDayTemplates)
        let mealLibraryRevision = "\(userSettings.customMealsCatalogRevision)"
        let behavioralSnapshot = ProposalBehavioralPreferences.load()
        let mealLibrary = userSettings.customMealsCatalog.map {
            ProposalMealCandidate(
                id: $0.id,
                title: $0.title,
                imageName: $0.imageName,
                calories: $0.calories,
                protein: $0.protein,
                carbs: $0.carbs,
                fats: $0.fats,
                fiber: $0.fiber,
                mealsTypeRaw: $0.type.rawValue,
                suggestedTime: $0.suggestedTime
            )
        }

        let recoveryBand = ProposalInputFingerprintBuilder.recoveryBand(from: readiness)
        let sleepPresenceForFP = MorningProposalGate.sleepPresence(
            from: MorningProposalGateInput(
                now: now,
                dayRolloverCompleted: true,
                healthRefreshCompleted: healthRefreshCompleted,
                healthRefreshTimedOut: healthRefreshTimedOut,
                isHealthAccessGranted: healthManager.isHealthAccessGranted,
                sleepHours: Double(healthManager.sleepMinutes) / 60.0,
                recoveryDataAvailable: readiness.recoveryDataAvailable,
                todayPlanLoaded: true,
                tomorrowPlanLoaded: true,
                yesterdayContextLoaded: true,
                isMorningWindow: isMorningWindow,
                hasCompletedPlannedItemToday: hasCompletedPlannedItemToday,
                existingStatus: existingProposal?.status
            )
        )
        let seriousOpen = todayActivities.filter {
            !$0.isCompleted && !$0.isSkipped && CoachActivityClassifier.isSeriousTraining($0)
        }.count
        let stackedLoad = ProposalStackedLoadResolver.resolve(
            yesterdayHeavy: readiness.hadHeavyYesterday,
            tomorrowDemand: tomorrowDemand,
            recoveryBand: recoveryBand,
            todaySeriousOpenCount: seriousOpen
        )
        let generationMode = MorningProposalGenerationModeResolver.resolve(
            openCount: todayActivities.filter {
                !$0.isCompleted && !$0.isSkipped && CoachActivityClassifier.type(for: $0) != .none
            }.count,
            hasCompletedOrPartialToday: hasCompletedPlannedItemToday,
            isMorningWindow: isMorningWindow
        )
        let physiologyRevision = ProposalInputFingerprintBuilder.physiologyRevision(
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresenceForFP,
            yesterdayHeavy: readiness.hadHeavyYesterday,
            stackedLoad: stackedLoad
        )

        let weatherRiskToken = ProposalWeatherRisk.resolve(from: morningWeatherSummary)

        // Mark ready/reviewing drafts stale when live fingerprint diverges before regenerate.
        let liveFingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: dayKey,
            todaySnapshots: todayActivities,
            tomorrowSnapshots: tomorrowActivities,
            recoveryBand: recoveryBand,
            sleepPresence: sleepPresenceForFP,
            scenarioKey: scenarioKey?.rawValue ?? "none",
            yesterdayHeavy: readiness.hadHeavyYesterday,
            observationContextRevision: observationContextRevision,
            behavioralGeneration: ProposalBehavioralPreferences.generation,
            stackedLoad: stackedLoad,
            generationMode: generationMode,
            mealLibraryRevision: mealLibraryRevision,
            physiologyContextRevision: physiologyRevision,
            weatherRiskToken: weatherRiskToken
        )
        MorningProposalService.markStaleIfNeeded(dayKey: dayKey, liveFingerprint: liveFingerprint)

        morningProposal = MorningProposalService.evaluateAndPersist(
            context: .init(
                now: now,
                dayRolloverCompleted: true,
                healthRefreshCompleted: healthRefreshCompleted,
                healthRefreshTimedOut: healthRefreshTimedOut,
                isHealthAccessGranted: healthManager.isHealthAccessGranted,
                sleepHours: Double(healthManager.sleepMinutes) / 60.0,
                readiness: readiness,
                scenarioKey: scenarioKey,
                tomorrowDemand: tomorrowDemand,
                stackedLoad: stackedLoad,
                yesterdayHeavy: readiness.hadHeavyYesterday,
                completedWalkToday: completedWalkToday,
                todayActivities: todayActivities,
                tomorrowActivities: tomorrowActivities,
                isMorningWindow: isMorningWindow,
                hasCompletedPlannedItemToday: hasCompletedPlannedItemToday,
                recentDayTemplates: recentDayTemplates,
                mealLibrary: mealLibrary,
                observationContextRevision: observationContextRevision,
                mealLibraryRevision: mealLibraryRevision,
                behavioralGeneration: ProposalBehavioralPreferences.generation,
                walkRejectPenalty: ProposalBehavioralPreferences.walkRejectPenalty(from: behavioralSnapshot),
                stronglyRejectsWalk: ProposalBehavioralPreferences.stronglyRejectsWalk(from: behavioralSnapshot),
                weatherRiskToken: weatherRiskToken
            )
        )

        if morningProposal?.status == .gatheringData {
            scheduleMorningProposalHealthTimeout()
        } else {
            morningProposalTimeoutTask?.cancel()
            morningProposalTimeoutTask = nil
        }
    }

    private func buildRecentDayTemplates(
        from activities: [PlannedActivity],
        excludingDayStart: Date,
        calendar: Calendar,
        lookbackDays: Int
    ) -> [SimilarDayTemplate] {
        let oldest = calendar.date(byAdding: .day, value: -lookbackDays, to: excludingDayStart) ?? excludingDayStart
        let grouped = Dictionary(grouping: activities) { calendar.startOfDay(for: $0.date) }
        return grouped.compactMap { dayStart, dayActivities -> SimilarDayTemplate? in
            guard dayStart < excludingDayStart, dayStart >= oldest else { return nil }
            let dayKey = ProposalInputFingerprintBuilder.dayKey(for: dayStart, calendar: calendar)
            let snapshots = dayActivities.map(CoachPlannedActivitySnapshot.init(from:))
            // Keep skipped items for quality scoring; miner filters for cloning.
            guard snapshots.contains(where: { !$0.isSkipped }) else { return nil }

            let observation = CoachObservationStore.observation(for: dayKey)
            let observationAvailable = observation?.hasRecoverySignal == true
            let band: ProposalRecoveryBandToken
            let sleepPresence: ProposalSleepPresenceToken
            if let observation, observation.hasRecoverySignal {
                band = SimilarDayPlanMiner.recoveryBand(fromPercent: observation.recoveryPercent)
                sleepPresence = observation.hasSleepSignal ? .present : .missing
            } else {
                // Neutral fallback — do not pretend physiological similarity.
                band = .unavailable
                sleepPresence = .unavailable
            }

            return SimilarDayTemplate(
                dayKey: dayKey,
                recoveryBand: band,
                observationAvailable: observationAvailable,
                sleepPresence: sleepPresence,
                activities: snapshots
            )
        }
    }

    private func scheduleMorningProposalHealthTimeout() {
        morningProposalTimeoutTask?.cancel()
        let timeout = MorningProposalGate.healthTimeoutSeconds
        morningProposalTimeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
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
        setQuickItemUsage([:])
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
                return elapsed >= 0 && elapsed <= 45 * 60
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

    private func quickActionFoodSubtitle(now: Date) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 5..<12:
            return WeekFitLocalizedString("today.quickActions.firstMeal")
        case 12..<17:
            return WeekFitLocalizedString("today.quickActions.lunch")
        case 17..<22:
            return WeekFitLocalizedString("today.quickActions.dinner")
        default:
            return WeekFitLocalizedString("today.quickActions.mealsSnacks")
        }
    }

    private func quickActionDrinksSubtitle() -> String {
        let drinks = loggedDrinksForSelectedDay

        switch drinks.count {
        case 0:
            return WeekFitLocalizedString("today.quickActions.firstDrink")
        case 1:
            return activityDisplayTitle(drinks[0])
        default:
            return WeekFitCountPluralization.drinksTodaySubtitle(count: drinks.count)
        }
    }

    private func quickActionActivitySubtitle(now: Date) -> String {
        if currentActiveSession(now: now) != nil {
            return WeekFitLocalizedString("today.quickActions.open")
        }
        if recentlyCompletedExerciseActivity(now: now) != nil {
            return WeekFitLocalizedString("today.quickActions.logged")
        }
        if let upcoming = nextUpcomingExerciseActivity(now: now) {
            let calendar = Calendar.current
            if calendar.isDate(upcoming.date, inSameDayAs: now) {
                return WeekFitLocalizedString("today.quickActions.prepare")
            }
            return WeekFitLocalizedString("today.quickActions.upNext")
        }
        return WeekFitLocalizedString("today.quickActions.workoutRecovery")
    }

    @ViewBuilder
    private func quickActionButtons(activeSession: PlannedActivity?, now: Date) -> some View {
        let priority = quickActionDynamicPriority(now: now)
        let drinksSubtitle = quickActionDrinksSubtitle()
        let foodSubtitle = quickActionFoodSubtitle(now: now)
        let activitySubtitle = quickActionActivitySubtitle(now: now)

        quickActionItem(
            icon: "takeoutbag.and.cup.and.straw.fill",
            label: WeekFitLocalizedString("today.quickActions.logDrinks"),
            subLabel: drinksSubtitle,
            color: WeekFitTheme.workout,
            isEmphasized: false,
            toastMessage: drinksQuickLogToast
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
            label: WeekFitLocalizedString("today.quickActions.logFood"),
            subLabel: foodSubtitle,
            color: todayNutritionColor,
            isEmphasized: priority == .food,
            toastMessage: foodQuickLogToast
        ) {
            selectedLogTab = .meals
            preloadQuickFoodLogDataIfNeeded()
            ProductAnalytics.todayPrimaryActionTapped(.food)
            ProductAnalytics.quickLogOpened(category: .food)
            presentExclusiveTodayActionSheet {
                ProductAnalytics.foodLoggingStarted(method: .quickLog, source: .today)
                showDirectMealLogSheet = true
            }
        }

        quickActionItem(
            icon: activeSession == nil ? "play.circle.fill" : "stop.circle.fill",
            label: WeekFitLocalizedString("today.quickActions.startActivity"),
            subLabel: activitySubtitle,
            color: activeSession == nil ? todayActivityColor : todayPremiumBronzeSoft,
            isEmphasized: priority == .activity,
            liveIndicatorColor: activeSession == nil ? nil : todayPremiumBronze
        ) {
            ProductAnalytics.todayPrimaryActionTapped(.activity)
            presentExclusiveTodayActionSheet {
                ProductAnalytics.activityLoggingStarted(source: .today)
                showDirectWorkoutLogSheet = true
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
                todayCardSectionTitle(WeekFitLocalizedString("today.quickActions.title"))
                    .foregroundStyle(WeekFitTheme.tertiaryText.opacity(0.74))
                    .padding(.bottom, TodayLayout.cardTitleBottomGap)

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
        subLabel: String,
        color: Color,
        isEmphasized: Bool = false,
        liveIndicatorColor: Color? = nil,
        toastMessage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let iconFillOpacity = isEmphasized ? (palette.isLight ? 0.18 : 0.17) : (palette.isLight ? 0.14 : 0.11)
        let iconStrokeOpacity = isEmphasized ? (palette.isLight ? 0.32 : 0.22) : (palette.isLight ? 0.24 : 0.15)
        let iconGlowOpacity = isEmphasized ? (palette.isLight ? 0.18 : 0.24) : (palette.isLight ? 0.10 : 0.15)
        let subtitleOpacity = isEmphasized ? 0.88 : 0.78
        let iconForeground = palette.isLight
            ? color
            : color.opacity(isEmphasized ? 0.94 : 0.88)

        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .top) {
                    Circle()
                        .fill(color.opacity(iconFillOpacity))
                        .overlay {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            color.opacity(iconGlowOpacity),
                                            color.opacity(0.02)
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 22
                                    )
                                )
                        }
                        .overlay(
                            Circle()
                                .stroke(color.opacity(iconStrokeOpacity), lineWidth: isEmphasized ? 1.25 : 1)
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(iconForeground)
                        .offset(y: quickActionIconOpticalYOffset(icon))
                        .frame(width: 40, height: 40)

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

                VStack(spacing: 1) {
                    Text(verbatim: label)
                        .font(.caption.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(
                            palette.isLight
                                ? textPrimary
                                : textPrimary.opacity(isEmphasized ? 0.94 : 0.88)
                        )
                        .lineLimit(quickActionCaptionLineLimit)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                    Text(verbatim: subLabel)
                        .font(.caption2.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(textSecondary.opacity(subtitleOpacity))
                        .lineLimit(quickActionCaptionLineLimit)
                        .minimumScaleFactor(0.82)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(QuickActionPressStyle())
        .accessibilityLabel("\(label), \(subLabel)")
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
        let subtitle = activitySubtitle(activity)
        let context = activityContext(activity)

        if activity.type.lowercased() == "recovery" {
            return subtitle
        }

        if subtitle == context {
            return subtitle
        }

        return "\(subtitle) · \(context)"
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
        if Calendar.current.isDate(activity.date, inSameDayAs: selectedDate) {
            return activityTime(activity.date)
        }

        let prefix = WeekFitUsesRussianLanguage() ? "Завтра" : "Tomorrow"
        return "\(prefix) \(activityTime(activity.date))"
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
        let quickLocalized = QuickItem.localizedTitle(forStoredTitle: trimmedTitle)
        if quickLocalized != trimmedTitle {
            return quickLocalized
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
