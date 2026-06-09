import SwiftUI
import SwiftData
import HealthKit
import UIKit
internal import Combine
import OSLog

struct TodayView: View {

    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject private var appSession: AppSessionState
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var userSettings = WeekFitUserSettings.shared

    @StateObject private var confirmationState = ActivityConfirmationState.shared
    
    @State private var healthRefreshID = UUID()

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]
    
    @State private var showDirectMealLogSheet = false
    @State private var showDirectDrinkLogSheet = false

    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    
    @StateObject private var planViewModel = PlanViewModel()
    
    @State private var showProfile = false
    @State private var selectedTab: WeekFitTab = .today
    @State private var showContent = false
    @State private var isEditingActivity = false
    @State private var selectedDate = Date()
    @State private var livePulse = false
    @State private var now = Date()
    @State private var showWaterToast = false
    
    @State private var activityToConfirm: PlannedActivity? = nil

    private let cardBackground = Color(red: 0.10, green: 0.11, blue: 0.14)
    private let cardSecondary = Color(red: 0.14, green: 0.15, blue: 0.19)

    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.65)
    private let textTertiary = Color.white.opacity(0.35)
    
    @State private var showDirectWorkoutLogSheet = false
    @State private var showDirectRecoveryLogSheet = false
    
    @State private var selectedLogTab: QuickNutritionLogTab = .meals
    @State private var quickLogMeals: [Meals] = []
    @State private var quickLogMealRows: [QuickMealDisplayRow] = []
    @State private var quickLogSnacks: [QuickItem] = []
    @State private var quickLogDrinks: [QuickItem] = []
    @State private var quickLogSnackRows: [QuickItemDisplayRow] = []
    @State private var quickLogDrinkRows: [QuickItemDisplayRow] = []
    @State private var quickItemUsage: [String: Int] = [:]
    @State private var didPreloadQuickFood = false
    @State private var didPreloadQuickDrinks = false
    @State private var cachedTodayCoachInsight: TodayCoachInsight?
    @State private var lastTodayCoachInsightSignature = ""
    
    @State private var showActivityIntelligence = false
    @State private var showNutritionDetails = false
    @State private var nutritionDetailsDate = Date()
    
    @State private var showRecoveryDetails = false
    
    private let quickItemUsageKey = "weekfit_quick_item_usage_v1"
    
    private enum QuickNutritionLogTab: String, CaseIterable, Identifiable {
        case meals
        case snacks

        var id: String { rawValue }

        var title: String {
            switch self {
            case .meals: return "Meals"
            case .snacks: return "Snacks"
            }
        }
    }
    
    private var completedNutritionLogsForSelectedDay: [PlannedActivity] {
        selectedDayActivities.filter { activity in
            guard activity.isCompleted, !activity.isSkipped, activity.imageName != "hydration" else {
                return false
            }

            let type = activity.type.lowercased()
            return type == "meal" || type == "drink"
        }
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
        Double(nutritionMeals(for: date).reduce(0) { $0 + $1.fiber })
    }

    private func nutritionMeals(for date: Date) -> [PlannedActivity] {
        plannedActivities
            .filter {
                Calendar.current.isDate($0.date, inSameDayAs: date)
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
    
    private var currentProtein: Double { healthManager.protein + loggedPlanProtein }
    private var currentCarbs: Double { healthManager.carbs + loggedPlanCarbs }
    private var currentFats: Double { healthManager.fats + loggedPlanFats }
    private var currentCalories: Double { healthManager.calories + loggedPlanCalories }

    private var proteinGoal: Double { nutritionViewModel.nutritionResult?.goals.protein ?? 153.0 }
    private var carbsGoal: Double { nutritionViewModel.nutritionResult?.goals.carbs ?? 330.0 }
    private var fatsGoal: Double { nutritionViewModel.nutritionResult?.goals.fats ?? 90.0 }
    private var fiberGoal: Double { nutritionViewModel.nutritionResult?.goals.fiber ?? 35.0 }
    private var caloriesGoal: Double { nutritionViewModel.nutritionResult?.goals.calories ?? 2761.0 }
    private var waterGoal: Double { nutritionViewModel.nutritionResult?.goals.waterLiters ?? 4.46 }
    
    private var currentWater: Double {
        let waterLogsToday = selectedDayActivities.filter { $0.imageName == "hydration" }
        return Double(waterLogsToday.count) * 0.25
    }

    private var timeOfDayGreeting: (text: String, icon: String, iconColor: Color) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        switch hour {
        case 5..<12:
            return ("Good morning", "sun.max.fill", .orange)
        case 12..<17:
            return ("Good afternoon", "sun.max.fill", .orange)
        case 17..<22:
            return ("Good evening", "moon.stars.fill", Color(red: 0.55, green: 0.40, blue: 0.85))
        default:
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

    var body: some View {
        ZStack(alignment: .bottom) {
            WeekFitTheme.appBackground
                .ignoresSafeArea()
            ambientBackground

            Group {
                switch selectedTab {
                    case .today:
                        todayScreen
                        .onAppear {
                           now = Date()
                           preloadQuickFoodLogDataIfNeeded()
                           preloadQuickDrinkLogDataIfNeeded()
                           if !healthManager.isHealthAccessRequested {
                               updateNutrition()
                           }
                           healthRefreshID = UUID()
                        }
                        
                    case .coach:
                        ExpertCoachViewV3(authViewModel: authViewModel)

                    case .meals:
                        MealsView(authViewModel: authViewModel, nutritionResult: nutritionViewModel.nutritionResult)
                        
                    case .calendar:
                        WeekPlannerView(viewModel: planViewModel, authViewModel: authViewModel)
                }
            }
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
            
            WeekFitBottomBar(selectedTab: $selectedTab) {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { selectedTab = .calendar }
            }
            .padding(.horizontal, 1)
            .background(alignment: .top) {
                Rectangle()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.02), Color.clear], startPoint: .top, endPoint: .bottom))
                    .frame(height: 1)
                    .offset(y: -7)
            }
            .shadow(color: Color.black.opacity(0.4), radius: 25, y: -10)
            .opacity(showContent && !isEditingActivity ? 1 : 0)
            .offset(y: showContent && !isEditingActivity ? 0 : 120)
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
                fiber: nutritionFats(for: nutritionDetailsDate),
                proteinGoal: proteinGoal,
                carbsGoal: carbsGoal,
                fatsGoal: fatsGoal,
                fiberGoal: fiberGoal,
                meals: nutritionMeals(for: nutritionDetailsDate)
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
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.88)) { showContent = true }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            #if DEBUG
            if newValue == .coach {
                CoachRefreshDebug.log(
                    "[CoachScreenLifecycle]",
                    "CoachTab selected source=TodayView oldTab=\(oldValue)"
                )
            }
            #endif
        }
        .task(id: healthRefreshID) {
            await refreshHealthAndNutritionAsync()
        }
        .onChange(of: plannedActivities) { _, _ in
            refreshTodayLiveState(refreshHealth: false)
        }
        .onChange(of: appSession.returnToTodayTrigger) { _, _ in
            handleReturnToTodayRequest()
        }
        .onChange(of: appSession.localDataResetTrigger) { _, _ in
            handleLocalDataResetCompleted()
        }
        .onChange(of: WeekFitActivityCoordinator.shared.completedWorkoutsBatch) { _, _ in
            WeekFitActivityCoordinator.shared.reconcileCompletedWorkouts(
                with: plannedActivities,
                modelContext: modelContext
            )

            appSession.healthRefreshTrigger = UUID()
            healthRefreshID = UUID()
        }
        .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { value in
            now = value
            updateTodayCoachInsightIfNeeded(source: "TodayView.timer")

            let calendar = Calendar.current
            if !calendar.isDate(selectedDate, inSameDayAs: value) {
                withAnimation(.smooth) {
                    selectedDate = value
                    healthRefreshID = UUID()
                }
            }
        }
        .onChange(of: nutritionViewModel.coachStateRefreshID) { _, _ in
            updateTodayCoachInsightIfNeeded(source: "TodayView.onChange.nutritionCoachStateRefreshID")
        }
        .onChange(of: nutritionViewModel.coachGuidanceSnapshot?.id) { _, _ in
            updateTodayCoachInsightIfNeeded(source: "TodayView.onChange.coachGuidanceSnapshot")
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showProfile = false // Плавное закрытие шторки
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 0.16, green: 0.80, blue: 0.43)) // Твой зеленый WeekFit акцент
                        }
                    }
            }
            .environmentObject(healthManager)
            .environmentObject(nutritionViewModel)
            .environmentObject(appSession)
            .presentationDetents([.large])
            .presentationCornerRadius(36)
            .presentationDragIndicator(.hidden)
        }
        .sheet(
            isPresented: $showDirectWorkoutLogSheet,
            onDismiss: {
                refreshTodayLiveState(refreshHealth: true)
            }
        ) {
            PremiumActivityStartSheet(
                background: WeekFitTheme.backgroundColor,
                cardBackground: WeekFitTheme.cardBackground,
                textSecondary: WeekFitTheme.secondaryText,
                isPresented: $showDirectWorkoutLogSheet,
                refreshID: $healthRefreshID
            )
            .presentationDetents([.height(370)])
            .presentationBackground(
                Color(red: 0.035, green: 0.043, blue: 0.047)
            )
            .presentationCornerRadius(34)
            .presentationDragIndicator(.hidden)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showDirectMealLogSheet) {
            ZStack {
                Color(red: 0.035, green: 0.043, blue: 0.047)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    PremiumBottomSheetHeader(
                        title: "Log Food",
                        subtitle: selectedLogTab == .meals
                            ? "Quick add saved meals"
                            : "Quick add snacks"
                    ) {
                        showDirectMealLogSheet = false
                    }

                    quickLogSegmentedControl(
                        decodedMealsCount: quickLogMealRows.count,
                        snacksCount: quickLogSnackRows.count
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            switch selectedLogTab {

                            case .meals:
                                if quickLogMealRows.isEmpty {
                                    quickLogEmptyState(
                                        icon: "fork.knife.circle.fill",
                                        title: "No saved meals yet",
                                        message: "Create meals first, then log them instantly here.",
                                        buttonTitle: "Open Meals Library",
                                        showAction: true
                                    )
                                } else {
                                    ForEach(quickLogMealRows) { row in
                                        QuickMealLogRow(
                                            row: row
                                        ) {
                                            logQuickMeal(row.meal)
                                        }
                                    }
                                }

                            case .snacks:
                                if quickLogSnackRows.isEmpty {
                                    quickLogEmptyState(
                                        icon: "leaf.fill",
                                        title: "No snacks available",
                                        message: "Check that drinks_snacks.json is added to the app bundle.",
                                        buttonTitle: nil,
                                        showAction: false
                                    )
                                } else {
                                    if !quickLogSnackRows.isEmpty {
                                        quickLogSectionHeader("Snacks")
                                            .padding(.top, 2)

                                        ForEach(quickLogSnackRows) { row in
                                            QuickItemLogRow(
                                                row: row,
                                                accentColor: Color(red: 0.50, green: 0.74, blue: 0.54)
                                            ) {
                                                logSnackItem(row.item)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    }
                }
            }
            .presentationDetents([.height(370)])
            .presentationBackground(
                Color(red: 0.035, green: 0.043, blue: 0.047)
            )
            .presentationCornerRadius(34)
            .presentationDragIndicator(.hidden)
        }
        .onChange(of: showDirectMealLogSheet) { _, isPresented in
            if isPresented {
                prepareQuickNutritionLogData()
            }
        }
        .onChange(of: userSettings.customMealsStorage) { _, _ in
            refreshQuickLogMealsFromStorage()
        }
        .sheet(isPresented: $showDirectDrinkLogSheet) {
            ZStack {
                Color(red: 0.035, green: 0.043, blue: 0.047)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    PremiumBottomSheetHeader(
                        title: "Log Drinks",
                        subtitle: "Quick add water or another drink"
                    ) {
                        showDirectDrinkLogSheet = false
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            if quickLogDrinkRows.isEmpty {
                                quickLogEmptyState(
                                    icon: "drop.fill",
                                    title: "No drinks available",
                                    message: "Check that drinks_snacks.json is added to the app bundle.",
                                    buttonTitle: nil,
                                    showAction: false
                                )
                            } else {
                                quickLogSectionHeader("Drinks")
                                    .padding(.top, 2)

                                ForEach(quickLogDrinkRows) { row in
                                    QuickItemLogRow(
                                        row: row,
                                        accentColor: Color(red: 0.25, green: 0.55, blue: 0.95)
                                    ) {
                                        logDrinkItem(row.item)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    }
                }
            }
            .presentationDetents([.height(370)])
            .presentationBackground(
                Color(red: 0.035, green: 0.043, blue: 0.047)
            )
            .presentationCornerRadius(34)
            .presentationDragIndicator(.hidden)
        }
    }
    
    private enum QuickSheetTypography {
        static let title = Font.system(size: 15.5, weight: .bold, design: .rounded)
        static let subtitle = Font.system(size: 12.2, weight: .medium, design: .rounded)
        static let meta = Font.system(size: 11.2, weight: .semibold, design: .rounded)
        static let badge = Font.system(size: 8.8, weight: .bold, design: .rounded)
    }

    private enum QuickLogRowMetrics {
        static let height: CGFloat = 74
        static let horizontalPadding: CGFloat = 12
        static let imageSize: CGFloat = 60
        static let imageCornerRadius: CGFloat = 16
        static let cardCornerRadius: CGFloat = 23
        static let plusButtonSize: CGFloat = 42
    }

    private func openActivityIntelligence() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showActivityIntelligence = true
    }

    private func quickLogSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(.white.opacity(0.52))
            .frame(maxWidth: .infinity, alignment: .leading)
    }


    private func quickLogSegmentedControl(
        decodedMealsCount: Int,
        snacksCount: Int
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(QuickNutritionLogTab.allCases) { tab in
                let isSelected = selectedLogTab == tab
                let count = tab == .meals ? decodedMealsCount : snacksCount

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedLogTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(tab.title)
                            .font(.system(size: 12.2, weight: .bold, design: .rounded))
                            .lineLimit(1)

                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 10.2, weight: .bold, design: .rounded))
                                .foregroundStyle(isSelected ? .black.opacity(0.70) : .white.opacity(0.42))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule()
                                        .fill(isSelected ? .white.opacity(0.70) : .white.opacity(0.06))
                                }
                        }
                    }
                    .foregroundStyle(isSelected ? .white.opacity(0.96) : .white.opacity(0.42))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.14),
                                            Color.white.opacity(0.08)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.035))
        }
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
    }

    private func quickLogEmptyState(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String?,
        showAction: Bool
    ) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color(red: 0.50, green: 0.74, blue: 0.54).opacity(0.85))

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))

            Text(message)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            if showAction, let buttonTitle {
                Button {
                    showDirectMealLogSheet = false

                    withAnimation {
                        selectedTab = .meals
                    }
                } label: {
                    Text(buttonTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black.opacity(0.82))
                        .padding(.horizontal, 18)
                        .frame(height: 42)
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
        .padding(.horizontal, 24)
        .padding(.vertical, 38)
    }
    
    private func prepareQuickNutritionLogData() {
        let start = Self.debugStart("quickNutrition.prepare")
        let repository = NutritionRepository()
        let usage = loadQuickItemUsage()
        let quickItems = repository.loadQuickItems()

        setQuickItemUsage(usage)
        refreshQuickLogMealsFromStorage()
        setQuickLogSnacks(sortByUsage(quickItems.filter { $0.category == .snack }, usage: usage))
        Self.debugEnd(
            "quickNutrition.prepare meals=\(quickLogMeals.count) snacks=\(quickLogSnacks.count)",
            start: start
        )
    }

    private func refreshQuickLogMealsFromStorage() {
        setQuickLogMeals(CustomMealStore.load(from: userSettings.customMealsStorage))
    }

    private func preloadQuickFoodLogDataIfNeeded() {
        guard !didPreloadQuickFood else {
            refreshQuickLogMealsFromStorage()
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
                subtitleText: item.subtitle,
                metaText: quickItemMetaText(for: item),
                usesAssetImage: !item.imageName.isEmpty && UIImage(named: item.imageName) != nil
            )
        }
    }

    private func quickItemMetaText(for item: QuickItem) -> String? {
        let macros = "P \(item.protein)g • C \(item.carbs)g • F \(item.fats)g"
        let hasMacros = item.protein > 0 || item.carbs > 0 || item.fats > 0

        if item.calories > 0, hasMacros {
            return "\(item.calories) kcal • \(macros)"
        }

        if item.calories > 0 {
            return "\(item.calories) kcal"
        }

        return hasMacros ? macros : nil
    }

    private func makeQuickMealRows(_ meals: [Meals]) -> [QuickMealDisplayRow] {
        return meals.map { meal in
            let isFoodProduct = meal.isFoodProduct
            let builderImageItems = isFoodProduct
                ? []
                : (meal.builderImageItems ?? []).sorted { $0.zIndex < $1.zIndex }

            return QuickMealDisplayRow(
                meal: meal,
                title: isFoodProduct ? meal.title : meal.shortTitle,
                subtitle: quickMealSubtitle(for: meal),
                macroText: quickMealMacroText(for: meal),
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

    private func quickMealSubtitle(for meal: Meals) -> String {
        if meal.isFoodProduct {
            return meal.servingDescription
        }

        let subtitle = meal.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return subtitle.isEmpty ? meal.servingDescription : subtitle
    }

    private func quickMealMacroText(for meal: Meals) -> String {
        let macros = "P \(meal.protein)g • C \(meal.carbs)g • F \(meal.fats)g"

        if meal.calories > 0 {
            return "\(meal.calories) kcal • \(macros)"
        }

        return macros
    }

    private func updateTodayCoachInsightIfNeeded(source: String) {
        guard let snapshot = nutritionViewModel.coachMetricsSnapshot else {
            if cachedTodayCoachInsight != nil || !lastTodayCoachInsightSignature.isEmpty {
                cachedTodayCoachInsight = nil
                lastTodayCoachInsightSignature = ""
            }
            return
        }

        let signature = todayCoachInsightSignature()
        guard signature != lastTodayCoachInsightSignature else { return }

        let start = Self.debugStart("todayCoachInsight.update source=\(source)")
        let inputSignature = canonicalCoachGuidanceInputSignature(snapshot: snapshot)
        let output: CoachGuidanceV3
        if let committed = nutritionViewModel.committedCoachGuidance(
            metricsSnapshotID: snapshot.id,
            inputSignature: inputSignature
        ) {
            output = committed
        } else {
            let next = CoachEngineV3.decide(
                from: snapshot.brain.refreshedForCurrentLocalTime(activities: plannedActivities),
                plannedActivities: plannedActivities,
                selectedDate: selectedDate,
                recoveryContext: snapshot.recoveryContext,
                nutritionContext: snapshot.nutritionContext
            )
            nutritionViewModel.commitCoachGuidance(
                next,
                metricsSnapshotID: snapshot.id,
                inputSignature: inputSignature,
                source: "TodayView.\(source)"
            )
            output = next
        }
        let compact = output.v5Interpretation.compactInsight
        let nextInsight = TodayCoachInsight(
            title: compact.title,
            message: compact.text,
            icon: compact.icon,
            color: compact.color
        )

        lastTodayCoachInsightSignature = signature
        if cachedTodayCoachInsight != nextInsight {
            cachedTodayCoachInsight = nextInsight
        }
        Self.debugEnd("todayCoachInsight.update source=\(source)", start: start)
    }

    private func todayCoachInsightSignature() -> String {
        let snapshot = nutritionViewModel.coachMetricsSnapshot
        let metrics = snapshot?.metrics
        let goals = snapshot?.result.goals
        let day = Calendar.current.startOfDay(for: selectedDate).timeIntervalSince1970
        let activitiesSignature = plannedActivities
            .sorted { $0.id < $1.id }
            .map { activity in
                [
                    activity.id,
                    "\(Int(activity.date.timeIntervalSince1970 / 60))",
                    activity.type,
                    activity.title,
                    "\(activity.durationMinutes)",
                    "\(activity.calories)",
                    "\(activity.protein)",
                    "\(activity.carbs)",
                    "\(activity.fats)",
                    "\(activity.fiber)",
                    "\(activity.isCompleted)",
                    "\(activity.isSkipped)",
                    activity.imageName
                ].joined(separator: ":")
            }
            .joined(separator: "|")

        return [
            "\(Int(day / 86_400))",
            coachCopyTimePhaseSignature(),
            String(format: "%.1f", metrics?.calories ?? -1),
            String(format: "%.1f", metrics?.protein ?? -1),
            String(format: "%.1f", metrics?.carbs ?? -1),
            String(format: "%.1f", metrics?.fats ?? -1),
            String(format: "%.1f", nutritionViewModel.totalWaterLiters),
            String(format: "%.1f", goals?.calories ?? -1),
            String(format: "%.1f", goals?.protein ?? -1),
            String(format: "%.1f", goals?.carbs ?? -1),
            String(format: "%.1f", goals?.fats ?? -1),
            String(format: "%.1f", goals?.waterLiters ?? -1),
            snapshot?.id.uuidString ?? "snapshot=nil",
            activitiesSignature
        ].joined(separator: "#")
    }

    private func canonicalCoachGuidanceInputSignature(snapshot: CoachMetricsSnapshot) -> String {
        let day = Calendar.current.startOfDay(for: selectedDate).timeIntervalSince1970
        let activitiesSignature = plannedActivities
            .sorted { $0.id < $1.id }
            .map { activity in
                [
                    activity.id,
                    "\(Int(activity.date.timeIntervalSince1970 / 60))",
                    activity.type,
                    activity.title,
                    "\(activity.durationMinutes)",
                    "\(activity.actualDurationMinutes ?? -1)",
                    activity.imageName,
                    "\(activity.isCompleted)",
                    "\(activity.isSkipped)",
                    activity.source
                ].joined(separator: ":")
            }
            .joined(separator: "|")

        return [
            snapshot.id.uuidString,
            "\(Int(day / 86_400))",
            coachCopyTimePhaseSignature(),
            activitiesSignature
        ].joined(separator: "#")
    }

    private func coachCopyTimePhaseSignature() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6..<11:
            return "morning"
        case 11..<16:
            return "midday"
        default:
            return "evening"
        }
    }

    private static let logger = Logger(subsystem: "WeekFit", category: "TodayView")

    private static func debugStart(_ label: String) -> CFAbsoluteTime {
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        logger.debug("\(label, privacy: .public) start")
        return start
        #else
        return 0
        #endif
    }

    private static func debugEnd(_ label: String, start: CFAbsoluteTime) {
        #if DEBUG
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        logger.debug("\(String(format: "%@ end %.1fms", label, elapsed), privacy: .public)")
        #endif
    }
    
    private func logSnackItem(_ item: QuickItem) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        incrementQuickItemUsage(item)

        let quickLogActivity = PlannedActivity(
            id: UUID().uuidString,
            date: Date(),
            type: "meal",
            title: item.title,
            durationMinutes: 5,
            icon: item.icon,
            imageName: item.imageName,
            colorRed: 0.50,
            colorGreen: 0.74,
            colorBlue: 0.54,
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fats: item.fats,
            isCompleted: true,
            isSkipped: false,
            source: "today"
        )

        modelContext.insert(quickLogActivity)
        try? modelContext.save()

        showDirectMealLogSheet = false
        healthRefreshID = UUID()
    }

    private func logDrinkItem(_ item: QuickItem) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        incrementQuickItemUsage(item)

        let isWater = item.id == "drink_water" || item.title.lowercased() == "water"
        let quickLogActivity = PlannedActivity(
            id: UUID().uuidString,
            date: Date(),
            type: "drink",
            title: item.title,
            durationMinutes: 5,
            icon: item.icon,
            imageName: isWater ? "hydration" : item.imageName,
            colorRed: 0.25,
            colorGreen: 0.55,
            colorBlue: 0.95,
            calories: item.calories,
            protein: item.protein,
            carbs: item.carbs,
            fats: item.fats,
            isCompleted: true,
            isSkipped: false,
            source: "today"
        )

        modelContext.insert(quickLogActivity)
        try? modelContext.save()

        if isWater {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                showWaterToast = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation { showWaterToast = false }
            }
        }

        showDirectDrinkLogSheet = false
        updateNutrition()
        healthRefreshID = UUID()
    }
    
    private struct QuickMealDisplayRow: Identifiable, Equatable {
        let meal: Meals
        let title: String
        let subtitle: String
        let macroText: String
        let usesAssetImage: Bool
        let sortedBuilderImageItems: [MealBuilderImageItem]
        let localPhotoFilename: String?
        let isFoodProduct: Bool
        let placeholderInitial: String

        var id: String { meal.id }
    }

    private struct QuickMealLogRow: View {
        let row: QuickMealDisplayRow
        let onTap: () -> Void

        private let accent = Color(red: 0.50, green: 0.74, blue: 0.54)
        private let textPrimary = WeekFitTheme.primaryText
        private let textSecondary = WeekFitTheme.secondaryText
        private let cardSecondary = WeekFitTheme.cardSecondary
        private let cardBackground = WeekFitTheme.cardBackground

        var body: some View {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onTap()
            } label: {
                HStack(spacing: 12) {
                    mealImage
                        .frame(
                            width: QuickLogRowMetrics.imageSize,
                            height: QuickLogRowMetrics.imageSize
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title)
                            .font(QuickSheetTypography.title)
                            .foregroundStyle(textPrimary)
                            .tracking(-0.35)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text(row.subtitle)
                            .font(QuickSheetTypography.subtitle)
                            .foregroundStyle(textSecondary.opacity(0.56))
                            .lineLimit(1)

                        Text(row.macroText)
                            .font(QuickSheetTypography.meta)
                            .foregroundStyle(textSecondary.opacity(0.62))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    plusButton
                }
                .padding(.horizontal, QuickLogRowMetrics.horizontalPadding)
                .frame(height: QuickLogRowMetrics.height)
                .quickLogCardBackground(
                    cardSecondary: cardSecondary,
                    cardBackground: cardBackground,
                    cornerRadius: QuickLogRowMetrics.cardCornerRadius
                )
            }
            .buttonStyle(.plain)
            .shadow(color: accent.opacity(0.035), radius: 12, y: 5)
        }

        private var plusButton: some View {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(accent)
                .frame(
                    width: QuickLogRowMetrics.plusButtonSize,
                    height: QuickLogRowMetrics.plusButtonSize
                )
                .background {
                    Circle()
                        .fill(accent.opacity(0.18))
                }
                .overlay {
                    Circle()
                        .stroke(accent.opacity(0.14), lineWidth: 1)
                }
        }

        private var mealImage: some View {
            ZStack {
                RoundedRectangle(
                    cornerRadius: QuickLogRowMetrics.imageCornerRadius,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.04))

                mealImageContent

                quickFoodImageTone
            }
            .frame(width: QuickLogRowMetrics.imageSize, height: QuickLogRowMetrics.imageSize)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: QuickLogRowMetrics.imageCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: QuickLogRowMetrics.imageCornerRadius,
                    style: .continuous
                )
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
            }
        }

        private var imageContentSize: CGFloat {
            row.isFoodProduct
                ? QuickLogRowMetrics.imageSize * 0.68
                : QuickLogRowMetrics.imageSize * 0.92
        }

        private var imageContentCornerRadius: CGFloat {
            QuickLogRowMetrics.imageCornerRadius * 0.70
        }

        private var quickFoodImageTone: some View {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.04),
                    Color.black.opacity(0.16)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.multiply)
            .allowsHitTesting(false)
        }

        @ViewBuilder
        private var mealImageContent: some View {
            if row.isFoodProduct {
                AsyncMealPhotoView(filename: row.localPhotoFilename) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(
                                width: imageContentSize,
                                height: imageContentSize
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: imageContentCornerRadius,
                                    style: .continuous
                                )
                            )
                            .saturation(0.88)
                            .contrast(0.92)
                            .brightness(-0.035)
                    } else {
                        CustomFoodVisualView(
                            image: nil,
                            placeholderInitial: row.placeholderInitial,
                            size: imageContentSize,
                            imageScale: 0.62
                        )
                    }
                }
            } else if !row.sortedBuilderImageItems.isEmpty {
                builtMealImage(row.sortedBuilderImageItems)
            } else if row.usesAssetImage {
                Image(row.meal.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: imageContentSize,
                        height: imageContentSize
                    )
                    .saturation(0.94)
                    .contrast(0.96)
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 20))
                    .foregroundColor(WeekFitTheme.tertiaryText)
            }
        }

        private func builtMealImage(_ items: [MealBuilderImageItem]) -> some View {
            return ZStack {
                Color.black.opacity(0.10)

                BuiltMealPlateView(
                    items: items,
                    plateSize: imageContentSize,
                    itemScale: 0.33,
                    offsetScale: 0.30,
                    plateOpacity: 0.42,
                    shadowOpacity: 0.12,
                    layoutMode: .compactPreview
                )
            }
            .frame(width: imageContentSize, height: imageContentSize)
        }
    }

    private struct QuickItemDisplayRow: Identifiable, Equatable {
        let item: QuickItem
        let subtitleText: String
        let metaText: String?
        let usesAssetImage: Bool

        var id: String { item.id }
    }

    private struct QuickItemLogRow: View {
        let row: QuickItemDisplayRow
        let accentColor: Color
        let onTap: () -> Void

        var body: some View {
            Button {
                onTap()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(
                            cornerRadius: QuickLogRowMetrics.imageCornerRadius,
                            style: .continuous
                        )
                        .fill(Color.white.opacity(0.045))
                        .frame(
                            width: QuickLogRowMetrics.imageSize,
                            height: QuickLogRowMetrics.imageSize
                        )

                        if row.usesAssetImage {
                            Image(row.item.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 38, height: 38)
                        } else {
                            Image(systemName: row.item.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.item.title)
                            .font(QuickSheetTypography.title)
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)

                        Text(row.subtitleText)
                            .font(QuickSheetTypography.subtitle)
                            .foregroundStyle(.white.opacity(0.50))
                            .lineLimit(1)

                        if let metaText = row.metaText {
                            Text(metaText)
                                .font(QuickSheetTypography.meta)
                                .foregroundStyle(.white.opacity(0.56))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(accentColor)
                        .frame(
                            width: QuickLogRowMetrics.plusButtonSize,
                            height: QuickLogRowMetrics.plusButtonSize
                        )
                        .background {
                            Circle()
                                .fill(accentColor.opacity(0.18))
                        }
                        .overlay {
                            Circle()
                                .stroke(accentColor.opacity(0.14), lineWidth: 1)
                        }
                }
                .padding(.horizontal, QuickLogRowMetrics.horizontalPadding)
                .frame(height: QuickLogRowMetrics.height)
                .quickLogCardBackground(
                    cardSecondary: WeekFitTheme.cardSecondary,
                    cardBackground: WeekFitTheme.cardBackground,
                    cornerRadius: QuickLogRowMetrics.cardCornerRadius
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var todayScreen: some View {
        WeekFitScreenContainer {

            WeekFitScreenHeader(
                title: "Today",
                subtitle: selectedDateTitle,
                initials: userSettings.profileInitials,
                showAvatar: true
            ) {
                showProfile = true
            }

        } content: {

            summaryContent
        }
        .padding(.bottom, 95)
        .opacity(showContent ? 1 : 0)

    }
    
    private func logQuickMeal(_ meal: Meals) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let quickLogActivity = PlannedActivity(
            id: UUID().uuidString,
            date: Date(),
            type: "meal",
            title: meal.title,
            durationMinutes: 15,
            icon: "fork.knife",
            imageName: meal.imageName,
            colorRed: 0.50,
            colorGreen: 0.74,
            colorBlue: 0.54,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fats: meal.fats,
            isCompleted: true,
            isSkipped: false,
            source: "today"
        )

        modelContext.insert(quickLogActivity)
        try? modelContext.save()

        showDirectMealLogSheet = false
        healthRefreshID = UUID()
    }
    

    private var ambientBackground: some View {
        Group {
            switch selectedTab {

            case .today:
                WeekFitTheme.todayAmbient

            case .coach:
                WeekFitTheme.coachAmbient

            case .meals:
                WeekFitTheme.mealsAmbient

            case .calendar:
                WeekFitTheme.planAmbient
            }
        }
        .ignoresSafeArea()
    }
    

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: WeekFitScreenLayout.rootSpacing) {

            dailyStatusSection
            
            upNextSection
            
            coachEntryPointSection
            
            quickActionsSection
            
            Spacer(minLength: 0)
        }
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

            selectedTab = .coach
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
                    Text("Evening Review is ready")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)

                    Text("Open Coach to review how today went.")
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
        let target = nutritionViewModel.nutritionResult?.targetCalories ?? 2761.0
        let eaten = nutritionViewModel.currentMetrics?.calories ?? 0.0
        let burned = healthManager.activeCalories
        
        // Формула: План + Сожженное на тренировках - Съеденное
        let remaining = target + burned - eaten
        
        if remaining > 0 {
            return "Left: \(Int(remaining)) kcal"
        } else {
            return "Over: \(Int(abs(remaining))) kcal"
        }
    }

    private var dailyStatusSection: some View {
        let baseGoal = automatedActivityGoal
        let activityPercent = baseGoal > 0 ? Int((healthManager.activeCalories / baseGoal) * 100) : 0

        let baseTargetCalories: Double = nutritionViewModel.nutritionResult?.targetCalories ?? 1743.0
        let activeCaloriesBurned: Double = healthManager.activeCalories
        let dynamicNutritionTarget: Double = baseTargetCalories + activeCaloriesBurned
        let eatenCalories: Double = nutritionViewModel.currentMetrics?.calories ?? 0.0

        let nutritionPercent: Int = dynamicNutritionTarget > 0.0
            ? Int((eatenCalories / dynamicNutritionTarget) * 100)
            : 0

        let hasRecoveryData =
            healthManager.sleepMinutes > 0 ||
            healthManager.timeInBedMinutes > 0 ||
            healthManager.hrvSDNN > 0 ||
            healthManager.restingHeartRate > 0

        let recoveryPercent = healthManager.recoveryPercent

        let recoveryDisplayValue: Int? =
            hasRecoveryData ? recoveryPercent : nil
        
        let activityColor = Color(red: 0.16, green: 0.80, blue: 0.43)
        let nutritionColor = Color(red: 0.95, green: 0.65, blue: 0.12)
        let recoveryColor = Color(red: 0.18, green: 0.74, blue: 0.89)

        let activityGoalText = "Goal: \(Int(baseGoal)) kcal"
        let activityValueText = "\(Int(healthManager.activeCalories)) kcal"

        let sleepValueInfoText = healthManager.sleepMinutes > 0
            ? String(format: "Sleep: %.1f h", Double(healthManager.sleepMinutes) / 60.0)
            : "Sleep: —"

        let recoveryStatusText: String = {
            guard hasRecoveryData else { return "Syncing" }

            if recoveryPercent >= 85 || (healthManager.hrvSDNN > 75.0 && healthManager.restingHeartRate < 60.0) {
                return "High recovery"
            } else if recoveryPercent >= 70 {
                return "Solid recovery"
            } else if recoveryPercent >= 50 {
                return "Moderate recovery"
            } else if recoveryPercent > 0 {
                return "Low recovery"
            } else {
                return "Syncing"
            }
        }()

        let exerciseValueText = "\(healthManager.exerciseMinutes)"
        let standValueText = healthManager.standHours > 0 ? "\(healthManager.standHours)/12" : "-"
        let vo2ValueText = healthManager.cardioFitnessVO2 > 0 ? String(format: "%.1f", healthManager.cardioFitnessVO2) : "—"

        let hrvValueText = healthManager.hrvSDNN > 0 ? "\(Int(healthManager.hrvSDNN))" : "—"
        let rhrValueText = healthManager.restingHeartRate > 0 ? "\(Int(healthManager.restingHeartRate))" : "—"
        let deepSleepText = healthManager.deepSleepMinutes > 0 ? String(format: "%.1f", Double(healthManager.deepSleepMinutes) / 60.0) : "—"

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Daily Status")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(textPrimary)

                    Text("Your key metrics at a glance")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(textTertiary)
                }

                Spacer()
            }

            if !healthManager.isHealthAccessGranted {
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
                            Text("Connect Apple Health")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(textPrimary)

                            Text("WeekFit uses Health data to adapt activity, recovery and nutrition to your real day.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(textSecondary)
                                .lineSpacing(2)
                        }
                    }
                    .padding(.top, 4)

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                        Task {
                            await healthManager.requestAuthorization(
                                for: selectedDate,
                                plannedActivities: selectedDayActivities
                            )
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .bold))

                            Text("Connect Apple Health")
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
                                            Color(red: 0.16, green: 0.80, blue: 0.43),
                                            Color(red: 0.12, green: 0.70, blue: 0.38)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .shadow(
                            color: Color(red: 0.16, green: 0.80, blue: 0.43).opacity(0.2),
                            radius: 8,
                            y: 3
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

            } else {
                HStack(alignment: .top, spacing: 6) {

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        openActivityIntelligence()
                    } label: {
                        VStack(spacing: 12) {
                            statusRingWidget(
                                title: "Activity",
                                infoText: activityGoalText,
                                valueText: activityValueText,
                                value: activityPercent,
                                color: activityColor
                            )

                            VStack(spacing: 5) {
                                metricRow(title: "Exercise", value: exerciseValueText, unit: "m", color: activityColor)
                                metricRow(title: "Stand", value: standValueText, unit: "h", color: activityColor.opacity(0.7))
                                metricRow(title: "Cardio", value: vo2ValueText, unit: "vo2", color: activityColor.opacity(0.5))
                            }
                            .padding(6)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.015))
                            }
                            .padding(.horizontal, 2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()

                        nutritionDetailsDate = selectedDate

                        showNutritionDetails = true
                    } label: {

                            VStack(spacing: 12) {
                            statusRingWidget(
                                title: "Nutrition",
                                infoText: remainingCaloriesText,
                                valueText: "\(Int(eatenCalories)) kcal",
                                value: nutritionPercent,
                                color: nutritionColor
                            )
                            VStack(spacing: 5) {
                                metricRow(
                                    title: "P",
                                    value: "\(Int(nutritionViewModel.currentMetrics?.protein ?? 0.0))/\(Int(proteinGoal))",
                                    unit: "",
                                    color: Color(red: 0.55, green: 0.40, blue: 0.85)
                                )

                                metricRow(
                                    title: "C",
                                    value: "\(Int(nutritionViewModel.currentMetrics?.carbs ?? 0.0))/\(Int(carbsGoal))",
                                    unit: "",
                                    color: Color.orange
                                )

                                metricRow(
                                    title: "F",
                                    value: "\(Int(nutritionViewModel.currentMetrics?.fats ?? 0.0))/\(Int(fatsGoal))",
                                    unit: "",
                                    color: Color.pink
                                )
                            }
                            .padding(6)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.015))
                            }
                            .padding(.horizontal, 2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showRecoveryDetails = true
                    } label: {

                        VStack(spacing: 12) {

                            statusRingWidget(
                                title: "Recovery",
                                infoText: recoveryDisplayValue == nil ? "Syncing Health" : recoveryStatusText,
                                valueText: recoveryDisplayValue == nil ? "Loading" : sleepValueInfoText,
                                value: recoveryDisplayValue,
                                color: recoveryColor
                            )

                            VStack(spacing: 5) {
                                metricRow(
                                    title: "Deep",
                                    value: deepSleepText,
                                    unit: "h",
                                    color: recoveryColor.opacity(0.5)
                                )

                                metricRow(
                                    title: "HRV",
                                    value: hrvValueText,
                                    unit: "ms",
                                    color: recoveryColor
                                )

                                metricRow(
                                    title: "RHR",
                                    value: rhrValueText,
                                    unit: "bpm",
                                    color: recoveryColor.opacity(0.7)
                                )
                            }
                            .padding(6)
                            .background {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.015))
                            }
                            .padding(.horizontal, 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardBackground.opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.03), lineWidth: 1)
                }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func metricRow(title: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
            
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(textTertiary)
            
            Spacer(minLength: 1)
            
            HStack(spacing: 1) {
                Text(value)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(textSecondary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 8, weight: .regular))
                        .foregroundStyle(textTertiary)
                }
            }
        }
    }

    private func statusRingWidget(
        title: String,
        infoText: String,
        valueText: String,
        value: Int?,
        color: Color
    ) -> some View {
        let displayValue = value ?? 0

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 4.0)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: CGFloat(displayValue) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4.0, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))

                Text(value == nil ? "—" : "\(displayValue)%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textPrimary)
            }

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(textPrimary)

                Text(valueText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)

                Text(infoText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var upNextSection: some View {
        let now = self.now

        let activeSession = currentActiveSession

        let futureActivity = selectedDayActivities.first { activity in
            guard !activity.isCompleted,
                  !activity.isSkipped else {
                return false
            }

            guard activity.date > now else {
                return false
            }

            if let activeSession,
               activity.id == activeSession.id {
                return false
            }

            return true
        }

        let nextActivity = futureActivity

        return VStack(alignment: .leading, spacing: 8) {
            Text("Up Next")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(textPrimary)
                .tracking(0.3)
                .padding(.leading, 2)

            if let activity = nextActivity {
                let accentColor = activity.color

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedTab = .calendar
                    }
                } label: {
                    HStack(spacing: 12) {

                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accentColor.opacity(0.18),
                                            accentColor.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            Image(systemName: activity.icon.isEmpty ? "sparkles" : activity.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(shortDisplayTitle(activity.title))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(textPrimary)

                            Text(upNextSubtitle(for: activity))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(textTertiary)
                        }

                        Spacer()

                        Text(activityTime(activity.date))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.35, green: 0.55, blue: 0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.1))
                            .clipShape(Capsule())

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(textTertiary)
                    }
                    .padding(14)
                    .background(cardBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(accentColor.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

            } else if let activeSession {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(activeSession.color.opacity(0.16))
                            .frame(width: 44, height: 44)

                        Image(systemName: activeSession.icon.isEmpty ? "figure.run" : activeSession.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(activeSession.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current session")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(textPrimary)

                        Text("\(shortDisplayTitle(activeSession.title)) is in progress")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(textTertiary)
                    }

                    Spacer()

                    Text("LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(activeSession.color)
                        .clipShape(Capsule())
                }
                .padding(14)
                .background(cardBackground.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(activeSession.color.opacity(0.25), lineWidth: 1)
                )

            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedTab = .calendar
                    }

                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.16, green: 0.80, blue: 0.43))

                        Text("No activities planned yet.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(textSecondary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(textTertiary)
                    }
                    .padding(14)
                    .background(cardBackground.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.015), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func isCoveredByActiveSession(_ activity: PlannedActivity) -> Bool {
        guard let active = currentActiveSession else { return false }

        let activeEnd = Calendar.current.date(
            byAdding: .minute,
            value: active.durationMinutes,
            to: active.date
        ) ?? active.date

        return activity.date >= active.date && activity.date <= activeEnd
    }
    
    private var currentActiveSession: PlannedActivity? {
        let now = Date()

        return selectedDayActivities.first { activity in
            let type = activity.type.lowercased()

            guard type == "workout" || type == "recovery" else { return false }
            return activity.terminalState(now: now) == .active
        }
    }
    
    private func activityContext(_ activity: PlannedActivity) -> String {
        switch activity.type.lowercased() {

        case "meal":
            return "Nutrition"

        case "workout":
            return "Endurance"

        case "recovery":
            return "Recovery"

        default:
            return "Routine"
        }
    }

    private var coachInsightSection: some View {
        let now = self.now

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
                    activityToConfirm = pending
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
                            Text("Pending Action Required")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(attentionColor)

                            Text("Your slot '\(pending.title)' needs confirmation. Tap to update your metrics.")
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
                if let insight = cachedTodayCoachInsight {
                    let insightColor = insight.color
                    let insightTitle = insight.title
                    let insightIcon = insight.icon
                    let insightMessage = insight.message

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedTab = .coach
                    } label: {
                        HStack(alignment: .center, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(insightColor.opacity(0.10))
                                    .frame(width: 38, height: 38)

                                Image(systemName: insightIcon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(insightColor)
                            }

                            VStack(alignment: .leading, spacing: 8) {

                                Text("COACH INSIGHT")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .tracking(1.3)
                                    .foregroundStyle(insightColor.opacity(0.82))

                                Text(insightTitle)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                if !insightMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                                    Text(compactTodayInsight(insightMessage))
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundStyle(textSecondary.opacity(0.82))
                                        .lineSpacing(2)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.015),
                                    cardBackground.opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.10), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Базовый фолбэк-индикатор, пока данные подгружаются
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Connect Health to unlock recovery insights")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(cardBackground.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .sheet(item: $activityToConfirm) { activity in
            missedConfirmationSheet(activity)
                .presentationDetents([.fraction(0.32)])
                .presentationDragIndicator(.hidden)
        }
    }
    
    private func refreshTodayLiveState(refreshHealth: Bool = false) {
        now = Date()
        updateNutrition()

        if refreshHealth {
            healthRefreshID = UUID()
        }
    }

    private func handleReturnToTodayRequest() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            selectedTab = .today
            selectedDate = Date()
        }
    }

    private func handleLocalDataResetCompleted() {
        showActivityIntelligence = false
        showNutritionDetails = false
        showRecoveryDetails = false
        showProfile = false
        showDirectWorkoutLogSheet = false
        showDirectMealLogSheet = false
        showDirectDrinkLogSheet = false
        showDirectRecoveryLogSheet = false
        activityToConfirm = nil
        isEditingActivity = false

        setQuickLogMeals([])
        setQuickLogSnacks([])
        setQuickLogDrinks([])
        setQuickItemUsage([:])
        didPreloadQuickFood = false
        didPreloadQuickDrinks = false
        cachedTodayCoachInsight = nil
        lastTodayCoachInsightSignature = ""

        nutritionViewModel.resetLocalState()
        handleReturnToTodayRequest()
        now = Date()
        healthRefreshID = UUID()
    }
    
    private func todayCoachInsight(
        phase: CoachActivityPhaseV3,
        fallback: (title: String, text: String, icon: String, color: Color)
    ) -> (title: String, text: String, icon: String, color: Color) {

        switch phase {

        case .active(let activity, _):
            return (
                title: activeCoachActionTitle(for: activity),
                text: activeCoachingMessage(for: activity),
                icon: activity.icon.isEmpty ? "figure.run" : activity.icon,
                color: activity.color
            )

        case .recovering(let activity, _, _):
            let next = nextRelevantActivity(after: activity)

            return (
                title: recoveryCoachActionTitle(after: activity, before: next),
                text: "\(activity.title) completed recently.",
                icon: "heart.fill",
                color: CoachPalette.recovery
            )

        case .preparing(let activity, _, let minutesUntil):
            return (
                title: preparingCoachActionTitle(for: activity),
                text: preparingText(for: activity, minutesUntil: minutesUntil),
                icon: activity.icon.isEmpty ? "clock.fill" : activity.icon,
                color: activity.color
            )

        case .stable:
            return fallback
        }
    }
    
    private func preparingText(
        for activity: PlannedActivity,
        minutesUntil: Int
    ) -> String {

        if minutesUntil <= 5 {
            return "\(activity.title) is about to start."
        }

        if minutesUntil < 60 {
            return "\(activity.title) starts in \(minutesUntil) min."
        }

        if minutesUntil < 120 {
            let hours = minutesUntil / 60
            let mins = minutesUntil % 60

            if mins == 0 {
                return "\(activity.title) starts in \(hours) hour."
            }

            return "\(activity.title) starts in \(hours)h \(mins)m."
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let startTime = Calendar.current.date(
            byAdding: .minute,
            value: minutesUntil,
            to: Date()
        ) ?? Date()

        return "\(activity.title) today at \(formatter.string(from: startTime))."
    }
    
    private func activeCoachingMessage(
        for activity: PlannedActivity
    ) -> String {

        let title = activity.title.lowercased()

        if title.contains("tennis") {
            return "Avoid turning every rally into maximal effort."
        }

        if title.contains("squash") {
            return "Keep reserve for the final games."
        }

        if title.contains("running") {
            return "Stay below threshold and keep pace sustainable."
        }

        if title.contains("cycling") {
            return "Focus on smooth cadence and steady output."
        }

        if title.contains("upper body") {
            return "Keep technique consistent and stop before form drops."
        }

        return "Stay controlled and avoid unnecessary fatigue."
    }
    
    private func nextRelevantActivity(after activity: PlannedActivity) -> PlannedActivity? {
        selectedDayActivities
            .filter {
                $0.terminalState(now: Date()) == .planned &&
                $0.date > Date()
            }
            .filter { $0.id != activity.id }
            .sorted { $0.date < $1.date }
            .first
    }

    private func activeCoachActionTitle(for activity: PlannedActivity) -> String {
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        switch kind {
        case .workout, .endurance:
            return "Stay controlled"
        case .recovery:
            return "Keep it easy"
        case .heat:
            return "Hydrate steadily"
        case .meal:
            return "Fuel calmly"
        case .other:
            return "Stay on track"
        }
    }

    private func recoveryCoachActionTitle(
        after activity: PlannedActivity,
        before next: PlannedActivity?
    ) -> String {
        guard let next else {
            return "Focus on recovery"
        }

        let nextKind = CoachActivityContextResolverV3.kind(for: next)

        switch nextKind {
        case .recovery:
            return "Recover before your next block"
        case .workout:
            return "Recover before training"
        case .endurance:
            return "Refuel before endurance"
        case .heat:
            return "Hydrate before heat"
        case .meal:
            return "Refuel next"
        case .other:
            return "Recover before moving on"
        }
    }

    private func preparingCoachActionTitle(for activity: PlannedActivity) -> String {
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        switch kind {
        case .workout:
            return "Prepare for training"
        case .endurance:
            return "Prepare for endurance"
        case .recovery:
            return "Keep recovery easy"
        case .heat:
            return "Hydrate before heat"
        case .meal:
            return "Fuel next"
        case .other:
            return "Get ready"
        }
    }
    
    private func workoutInsightIcon(
        fallback: String,
        output: CoachGuidanceV3
    ) -> String {
        let text = [
            output.insightTitle,
            output.insightSubtitle ?? "",
            output.dynamicInsight.title,
            output.dynamicInsight.text
        ]
        .joined(separator: " ")
        .lowercased()

        return iconForWorkoutInsightText(text, fallback: fallback)
    }

    private func iconForWorkoutInsightText(
        _ text: String,
        fallback: String
    ) -> String {

        if text.contains("walk") || text.contains("walking") {
            return "figure.walk"
        }

        if text.contains("run") || text.contains("running") {
            return "figure.run"
        }

        if text.contains("cycling")
            || text.contains("cycle")
            || text.contains("bike")
            || text.contains("ride") {
            return "bicycle"
        }

        if text.contains("hike") || text.contains("hiking") {
            return "figure.hiking"
        }

        if text.contains("upper body")
            || text.contains("strength")
            || text.contains("gym")
            || text.contains("weights")
            || text.contains("dumbbell") {
            return "figure.strengthtraining.traditional"
        }

        if text.contains("stretch")
            || text.contains("stretching")
            || text.contains("mobility")
            || text.contains("flexibility") {
            return "figure.flexibility"
        }

        if text.contains("yoga") {
            return "figure.mind.and.body"
        }

        if text.contains("breathing") || text.contains("breath") {
            return "wind"
        }

        if text.contains("sauna") || text.contains("heat") {
            return "flame.fill"
        }

        if text.contains("swim") || text.contains("swimming") {
            return "figure.pool.swim"
        }

        if text.contains("hiit") || text.contains("interval") {
            return "flame.fill"
        }

        return fallback
    }
    
    private func debugWorkoutInsight(_ output: CoachGuidanceV3) {
        print("🧠 [WorkoutInsight] phase:", output.phase)
        print("🧠 [WorkoutInsight] opportunity:", output.opportunity.type)
        print("🧠 [WorkoutInsight] shouldSurface:", output.shouldSurface)
        print("🧠 [WorkoutInsight] title:", output.insightTitle)
        print("🧠 [WorkoutInsight] subtitle:", output.insightSubtitle ?? "nil")
    }
    
    private func compactTodayInsight(_ text: String) -> String {
        let sentences = text
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let firstTwo = sentences.prefix(2).joined(separator: ". ")

        if firstTwo.count <= 115 {
            return firstTwo.hasSuffix(".") ? firstTwo : firstTwo + "."
        }

        return String(firstTwo.prefix(115)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private var quickActionsSection: some View {
        let activeSession = currentActiveSession

        return VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(textPrimary)
                .padding(.leading, 2)

            HStack(spacing: 0) {
                quickActionItem(
                    icon: "takeoutbag.and.cup.and.straw.fill",
                    label: "Log Drinks",
                    subLabel: String(format: "%.1f/%.1fL", currentWater, waterGoal),
                    color: Color(red: 0.25, green: 0.55, blue: 0.95)
                )

                quickActionItem(
                    icon: "fork.knife",
                    label: "Log Food",
                    subLabel: "Meals / Snacks",
                    color: Color(red: 0.55, green: 0.40, blue: 0.85)
                )

                quickActionItem(
                    icon: activeSession == nil ? "play.circle.fill" : "stop.circle.fill",
                    label: "Start Activity",
                    subLabel: activeSession?.title ?? "Workout / Recovery",
                    color: activeSession == nil
                        ? Color(red: 0.16, green: 0.80, blue: 0.43)
                        : Color.orange
                )
            }
        }
    }

    private func quickActionItem(icon: String, label: String, subLabel: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                switch label {
                case "Log Drinks":
                    preloadQuickDrinkLogDataIfNeeded()
                    showDirectDrinkLogSheet = true
                case "Log Food":
                    selectedLogTab = .meals
                    preloadQuickFoodLogDataIfNeeded()
                    showDirectMealLogSheet = true
                case "Start Activity":
//                    if currentActiveSession != nil {
//                        selectedTab = .calendar
//                    } else {
                        showDirectWorkoutLogSheet = true
//                    }
                default:
                    break
                }
            } label: {
                ZStack(alignment: .top) {
                    Circle().fill(color.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundColor(color).frame(width: 48, height: 48)
                    
                    if label == "Log Drinks" && showWaterToast {
                        Text("+0.25L")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color(red: 0.25, green: 0.55, blue: 0.95)).clipShape(Capsule())
                            .offset(y: -34).transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .buttonStyle(.plain)
            
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                Text(subLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func updateNutrition(withExtraWater extra: Double = 0) {
        let metrics = DailyNutritionMetrics(
            protein: 0,
            carbs: 0,
            fats: 0,
            fiber: 0,
            calories: 0,
            waterLiters: extra,
            activeCalories: healthManager.activeCalories,
            sleepHours: healthManager.sleepHours,
            weightKg: healthManager.weight
        )
        
        let profile = UserNutritionProfile.createAutomatic(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm,
            age: healthManager.age,
            sex: healthManager.biologicalSex == .male ? .male : .female
        )
        
        nutritionViewModel.updateNutrition(
            metrics: metrics,
            profile: profile,
            plannedActivities: selectedDayActivities,
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: Int(healthManager.recoveryPercent),
                sleepHours: healthManager.sleepHours
            )
        )
    }

    private func missedConfirmationSheet(_ activity: PlannedActivity) -> some View {
        let accentColor = activity.color
        
        return VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("Verify Log Block")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textPrimary)
                
                Text("Coach requires confirmation for **\(activity.title)** to update your active metabolic and energy expenditure baseline.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(textSecondary)
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
                        healthRefreshID = UUID()
                        activityToConfirm = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("I skipped it")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(textSecondary)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(cardSecondary))
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
                        healthRefreshID = UUID()
                        activityToConfirm = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Confirm Log")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(accentColor))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WeekFitTheme.backgroundColor.ignoresSafeArea())
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

    private func activitySubtitle(_ activity: PlannedActivity) -> String {
        switch activity.type.lowercased() {

        case "meal":
            if activity.title.lowercased().contains("breakfast") {
                return "Morning fuel"
            } else if activity.title.lowercased().contains("snack") {
                return "Energy support"
            } else {
                return "Nutrition support"
            }

        case "workout":
            return "Training session"

        case "recovery":
            return "Recovery block"

        case "hydration":
            return "Hydration support"

        default:
            return "Planned activity"
        }
    }

    private func durationText(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let remainder = safeMinutes % 60

        if hours > 0 && remainder > 0 {
            return "\(hours)h \(remainder)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(safeMinutes)m"
    }

    private func activityTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private func refreshHealthAndNutritionAsync() async {
        guard healthManager.isHealthAccessRequested else { return }
        await healthManager.loadHealthData(for: selectedDate, plannedActivities: selectedDayActivities)
        await MainActor.run { updateNutrition() }
    }

    private var automatedActivityGoal: Double {
        ActivityGoalEngine.calculate(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm,
            age: healthManager.age,
            sex: healthManager.biologicalSex,
            recoveryPercent: healthManager.recoveryPercent,
            sleepHours: healthManager.sleepHours,
            vo2Max: healthManager.cardioFitnessVO2
        )
    }

    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    private func shortDisplayTitle(_ title: String) -> String {
        title.components(separatedBy: ",").first ?? title
    }

    private var selectedDayActivities: [PlannedActivity] {
        plannedActivities.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }.sorted { $0.date < $1.date }
    }
}

private extension View {
    func quickLogCardBackground(
        cardSecondary: Color,
        cardBackground: Color,
        cornerRadius: CGFloat
    ) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            cardSecondary.opacity(0.97),
                            cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.035), lineWidth: 1)
        }
        .contentShape(Rectangle())
    }
}

private struct TodayCoachInsight: Equatable {
    let title: String
    let message: String
    let icon: String
    let color: Color

    static func == (lhs: TodayCoachInsight, rhs: TodayCoachInsight) -> Bool {
        lhs.title == rhs.title &&
        lhs.message == rhs.message &&
        lhs.icon == rhs.icon
    }
}
