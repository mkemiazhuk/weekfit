import SwiftUI
import SwiftData
import HealthKit
import UIKit
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
    @EnvironmentObject private var languageManager: AppLanguageManager
    
    @State private var showProfile = false
    @State private var showContent = false
    @State private var livePulse = false
    @State private var showWaterToast = false
    
    @State private var activityToConfirm: PlannedActivity? = nil

    private let cardBackground = Color(red: 0.10, green: 0.11, blue: 0.14)
    private let cardSecondary = Color(red: 0.14, green: 0.15, blue: 0.19)

    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.65)
    private let textTertiary = Color.white.opacity(0.35)

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
    @State private var quickItemUsage: [String: Int] = [:]
    @State private var didPreloadQuickFood = false
    @State private var didPreloadQuickDrinks = false
    
    @State private var showActivityIntelligence = false
    @State private var showNutritionDetails = false
    @State private var nutritionDetailsDate = Date()
    
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

    private var hasTodayRecoverySignals: Bool {
        healthManager.sleepMinutes > 0 ||
        healthManager.timeInBedMinutes > 0 ||
        healthManager.hrvSDNN > 0 ||
        healthManager.restingHeartRate > 0
    }

    private var shouldShowHealthConnectPrompt: Bool {
        !hasTodayRecoverySignals &&
        (
            !healthManager.isHealthAccessRequested ||
            (!healthManager.isHealthAccessGranted && healthManager.hasCompletedHealthAccessCheck)
        )
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
        let _ = languageManager.selectedLanguage

        ZStack(alignment: .bottom) {
            WeekFitTheme.appBackground
                .ignoresSafeArea()
            ambientBackground

            todayScreen
                .onAppear {
                   todayViewModel.now = Date()
                   preloadQuickFoodLogDataIfNeeded()
                   preloadQuickDrinkLogDataIfNeeded()
                   if !healthManager.isHealthAccessRequested {
                       updateNutrition()
                   }
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
        .task(id: todayViewModel.healthRefreshID) {
            await refreshHealthAndNutritionAsync()
        }
        .onChange(of: plannedActivities) { _, _ in
            debugTodayDataState(source: "TodayView.onChange.plannedActivities")
            refreshTodayLiveState(refreshHealth: false)
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            debugTodayDataState(source: "TodayView.onChange.selectedDate old=\(oldValue) new=\(newValue)")
            todayViewModel.triggerHealthRefresh()
        }
        .onChange(of: appSession.healthRefreshTrigger) { _, _ in
            debugTodayDataState(source: "TodayView.onChange.healthRefreshTrigger")
            todayViewModel.triggerHealthRefresh()
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
        .task(id: coachCoordinator.nextScheduledCheckpoint) {
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

                updateTodayCoachInsightIfNeeded(source: "CoachCoordinator.checkpoint")
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showProfile = false // Плавное закрытие шторки
                            } label: {
                                Text(AppText.Common.Action.done)
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 0.16, green: 0.80, blue: 0.43)) // Твой зеленый WeekFit акцент
                        }
                    }
            }
            .environmentObject(healthManager)
            .environmentObject(nutritionViewModel)
            .environmentObject(appSession)
            .environmentObject(languageManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .weekFitSheetChrome(cornerRadius: 36)
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
                refreshID: healthRefreshBinding
            )
            .presentationDetents([
                .fraction(0.45),
                .large
            ])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(cornerRadius: 34)
        }
        .sheet(isPresented: $showDirectMealLogSheet) {
            ZStack {
                Color(red: 0.035, green: 0.043, blue: 0.047)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    PremiumBottomSheetHeader(
                        title: WeekFitLocalizedString("today.quickLog.title.logFood"),
                        subtitle: selectedLogTab == .meals
                            ? WeekFitLocalizedString("today.quickLog.subtitle.savedFoods")
                            : WeekFitLocalizedString("today.quickLog.subtitle.drinksSnacks")
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
                                        title: WeekFitLocalizedString("today.quickLog.empty.savedFood.title"),
                                        message: WeekFitLocalizedString("today.quickLog.empty.savedFood.message"),
                                        buttonTitle: WeekFitLocalizedString("today.quickLog.empty.savedFood.action"),
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
                                        title: WeekFitLocalizedString("today.quickLog.empty.quickItems.title"),
                                        message: WeekFitLocalizedString("today.quickLog.empty.quickItems.message"),
                                        buttonTitle: nil,
                                        showAction: false
                                    )
                                } else {
                                    if !quickLogSnackRows.isEmpty {
                                        quickLogSectionHeader(WeekFitLocalizedString("today.quickLog.section.snacks"))
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
            .presentationDetents([
                .fraction(0.45),
                .large
            ])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(cornerRadius: 34)
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
                        title: WeekFitLocalizedString("today.quickActions.logDrinks"),
                        subtitle: WeekFitLocalizedString("today.quickLog.subtitle.drinks")
                    ) {
                        showDirectDrinkLogSheet = false
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            if quickLogDrinkRows.isEmpty {
                                quickLogEmptyState(
                                    icon: "drop.fill",
                                    title: WeekFitLocalizedString("today.quickLog.empty.drinks.title"),
                                    message: WeekFitLocalizedString("today.quickLog.empty.quickItems.message"),
                                    buttonTitle: nil,
                                    showAction: false
                                )
                            } else {
                                quickLogSectionHeader(WeekFitLocalizedString("today.quickLog.section.drinks"))
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
            .presentationDetents([
                .fraction(0.45),
                .large
            ])
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            .weekFitSheetChrome(cornerRadius: 34)
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

                    onSelectTab(.meals)
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
        let macros = localizedMacroSummary(protein: item.protein, carbs: item.carbs, fats: item.fats)
        let hasMacros = item.protein > 0 || item.carbs > 0 || item.fats > 0

        if item.calories > 0, hasMacros {
            return "\(localizedCalories(item.calories)) • \(macros)"
        }

        if item.calories > 0 {
            return localizedCalories(item.calories)
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
        let macros = localizedMacroSummary(protein: meal.protein, carbs: meal.carbs, fats: meal.fats)

        if meal.calories > 0 {
            return "\(localizedCalories(meal.calories)) • \(macros)"
        }

        return macros
    }

    private func localizedMacroSummary(protein: Int, carbs: Int, fats: Int) -> String {
        [
            "\(WeekFitLocalizedString("meals.library.macroProtein")) \(localizedGrams(protein))",
            "\(WeekFitLocalizedString("meals.library.macroCarbs")) \(localizedGrams(carbs))",
            "\(WeekFitLocalizedString("meals.library.macroFats")) \(localizedGrams(fats))"
        ].joined(separator: " • ")
    }

    private func localizedCalories(_ calories: Int) -> String {
        String(format: WeekFitLocalizedString("common.unit.caloriesFormat"), calories)
    }

    private func localizedGrams(_ grams: Int) -> String {
        String(format: WeekFitLocalizedString("common.unit.gramFormat"), grams)
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
        let nutritionTarget = (result?.targetCalories ?? 0) + healthManager.activeCalories
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

    private func debugTodayCoachInsight(
        semanticInsight: DynamicInsight?,
        titleKey: String,
        subtitleKey: String,
        localizedTitle: String,
        localizedSubtitle: String,
        coachScreenStoryTitle: String?
    ) {
        #if DEBUG
        let insightID = semanticInsight?.actionID ?? "missing"
        let semanticTitle = semanticInsight?.title ?? titleKey
        let semanticSubtitle = semanticInsight?.text ?? subtitleKey
        if let coachScreenStoryTitle {
            let expectedTitle = WeekFitCoachRuntimeLocalizedString(coachScreenStoryTitle)
            if localizedTitle != expectedTitle {
                Self.logger.error(
                    "TodayCoachInsight narrative mismatch localizedTitle=\(localizedTitle, privacy: .public) coachScreenStoryTitle=\(expectedTitle, privacy: .public)"
                )
                assertionFailure("TodayCoachInsight title must match CoachScreenStory title")
            }
        }
        if insightID == "missing" ||
            semanticTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            semanticSubtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Self.logger.error(
                "TodayCoachInsight missing metadata language=\(languageManager.selectedLanguage.rawValue, privacy: .public) semanticInsightID=\(insightID, privacy: .public) titleKey=\(semanticTitle, privacy: .public) subtitleKey=\(semanticSubtitle, privacy: .public) localizedTitle=\(localizedTitle, privacy: .public) localizedSubtitle=\(localizedSubtitle, privacy: .public)"
            )
        }
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
        todayViewModel.triggerHealthRefresh()
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
        todayViewModel.triggerHealthRefresh()
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

        init(
            row: QuickItemDisplayRow,
            accentColor: Color,
            onTap: @escaping () -> Void
        ) {
            self.row = row
            self.accentColor = accentColor
            self.onTap = onTap
        }

        var body: some View {
            Button {
                onTap()
            } label: {
                rowContent {
                    plusButton
                }
            }
            .buttonStyle(.plain)
        }

        private func rowContent<Trailing: View>(
            @ViewBuilder trailing: () -> Trailing
        ) -> some View {
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

                    trailing()
                }
                .padding(.horizontal, QuickLogRowMetrics.horizontalPadding)
                .frame(height: QuickLogRowMetrics.height)
                .quickLogCardBackground(
                    cardSecondary: WeekFitTheme.cardSecondary,
                    cardBackground: WeekFitTheme.cardBackground,
                    cornerRadius: QuickLogRowMetrics.cardCornerRadius
                )
        }

        private var plusButton: some View {
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
    }
    
    private var todayScreen: some View {
        WeekFitScreenContainer {

            WeekFitScreenHeader(
                title: WeekFitLocalizedString("today.title"),
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
        todayViewModel.triggerHealthRefresh()
    }
    

    private var ambientBackground: some View {
        WeekFitTheme.todayAmbient
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
        let target = nutritionViewModel.nutritionResult?.targetCalories ?? 2761.0
        let eaten = nutritionViewModel.currentMetrics?.calories ?? 0.0
        let burned = healthManager.activeCalories
        
        // Формула: План + Сожженное на тренировках - Съеденное
        let remaining = target + burned - eaten
        
        if remaining > 0 {
            return String(format: WeekFitLocalizedString("today.calories.leftFormat"), Int(remaining))
        } else {
            return String(format: WeekFitLocalizedString("today.calories.overFormat"), Int(abs(remaining)))
        }
    }

    private var dailyStatusSection: some View {
        let baseGoal = automatedActivityGoal
        let activityProgress = baseGoal > 0 ? healthManager.activeCalories / baseGoal : 0
        let activityPercent = Int(activityProgress * 100)
        let activityDisplayText = healthManager.activeCalories > 0 && activityProgress > 0 && activityProgress < 0.01
            ? "<1%"
            : "\(activityPercent)%"

        let baseTargetCalories: Double = nutritionViewModel.nutritionResult?.targetCalories ?? 1743.0
        let activeCaloriesBurned: Double = healthManager.activeCalories
        let dynamicNutritionTarget: Double = baseTargetCalories + activeCaloriesBurned
        let eatenCalories: Double = nutritionViewModel.currentMetrics?.calories ?? 0.0

        let nutritionPercent: Int = dynamicNutritionTarget > 0.0
            ? Int((eatenCalories / dynamicNutritionTarget) * 100)
            : 0

        let hasRecoveryData = hasTodayRecoverySignals

        let recoveryPercent = healthManager.recoveryPercent

        let recoveryDisplayValue: Int? =
            hasRecoveryData ? recoveryPercent : nil
        
        let activityColor = Color(red: 0.16, green: 0.80, blue: 0.43)
        let nutritionColor = Color(red: 0.95, green: 0.65, blue: 0.12)
        let recoveryColor = Color(red: 0.18, green: 0.74, blue: 0.89)

        let activityGoalText = String(format: WeekFitLocalizedString("today.status.activity.goalFormat"), Int(baseGoal))
        let activityValueText = String(format: WeekFitLocalizedString("common.unit.caloriesFormat"), Int(healthManager.activeCalories))

        let sleepValueInfoText = healthManager.sleepMinutes > 0
            ? String(format: WeekFitLocalizedString("today.sleep.valueFormat"), Double(healthManager.sleepMinutes) / 60.0)
            : WeekFitLocalizedString("today.sleep.empty")

        let recoveryStatusText: String = {
            guard hasRecoveryData else { return WeekFitLocalizedString("today.recovery.syncing") }

            if recoveryPercent >= 85 || (healthManager.hrvSDNN > 75.0 && healthManager.restingHeartRate < 60.0) {
                return WeekFitLocalizedString("today.recovery.ready")
            } else if recoveryPercent >= 70 {
                return WeekFitLocalizedString("today.recovery.good")
            } else if recoveryPercent >= 50 {
                return WeekFitLocalizedString("today.recovery.ok")
            } else if recoveryPercent > 0 {
                return WeekFitLocalizedString("today.recovery.needRest")
            } else {
                return WeekFitLocalizedString("today.recovery.syncing")
            }
        }()

        let exerciseMetric = compactActivityMetricDuration(healthManager.exerciseMinutes)
        let standValueText = healthManager.standHours > 0 ? "\(healthManager.standHours)/12" : "-"
        let vo2ValueText = healthManager.cardioFitnessVO2 > 0 ? String(format: "%.1f", healthManager.cardioFitnessVO2) : "—"

        let hrvValueText = healthManager.hrvSDNN > 0 ? "\(Int(healthManager.hrvSDNN))" : "—"
        let rhrValueText = healthManager.restingHeartRate > 0 ? "\(Int(healthManager.restingHeartRate))" : "—"
        let deepSleepText = healthManager.deepSleepMinutes > 0 ? String(format: "%.1f", Double(healthManager.deepSleepMinutes) / 60.0) : "—"

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(AppText.Today.dailyStatusTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(textPrimary)

                    Text(AppText.Today.dailyStatusSubtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(textTertiary)
                }

                Spacer()
            }

            if shouldShowHealthConnectPrompt {
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
                                title: WeekFitLocalizedString("today.status.activity"),
                                infoText: activityGoalText,
                                valueText: activityValueText,
                                value: activityPercent,
                                centerText: activityDisplayText,
                                color: activityColor
                            )

                            VStack(spacing: 5) {
                                metricRow(title: WeekFitLocalizedString("today.status.metric.exercise"), value: exerciseMetric.value, unit: exerciseMetric.unit, color: activityColor)
                                metricRow(title: WeekFitLocalizedString("today.status.metric.stand"), value: standValueText, unit: WeekFitLocalizedString("common.unit.hoursShort"), color: activityColor.opacity(0.7))
                                metricRow(title: WeekFitLocalizedString("common.unit.vo2"), value: vo2ValueText, unit: "", color: activityColor.opacity(0.5))
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

                        nutritionDetailsDate = Date()

                        showNutritionDetails = true
                    } label: {

                            VStack(spacing: 12) {
                            statusRingWidget(
                                title: WeekFitLocalizedString("today.status.nutrition"),
                                infoText: remainingCaloriesText,
                                valueText: String(format: WeekFitLocalizedString("common.unit.caloriesFormat"), Int(eatenCalories)),
                                value: nutritionPercent,
                                color: nutritionColor
                            )
                            VStack(spacing: 5) {
                                metricRow(
                                    title: WeekFitLocalizedString("meals.library.macroProtein"),
                                    value: "\(Int(nutritionViewModel.currentMetrics?.protein ?? 0.0))/\(Int(proteinGoal))",
                                    unit: "",
                                    color: Color(red: 0.55, green: 0.40, blue: 0.85)
                                )
                                
                                metricRow(
                                    title: WeekFitLocalizedString("meals.library.macroFats"),
                                    value: "\(Int(nutritionViewModel.currentMetrics?.fats ?? 0.0))/\(Int(fatsGoal))",
                                    unit: "",
                                    color: Color.pink
                                )

                                metricRow(
                                    title: WeekFitLocalizedString("meals.library.macroCarbs"),
                                    value: "\(Int(nutritionViewModel.currentMetrics?.carbs ?? 0.0))/\(Int(carbsGoal))",
                                    unit: "",
                                    color: Color.orange
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
                                title: WeekFitLocalizedString("today.status.recovery"),
                                infoText: recoveryDisplayValue == nil ? "" : recoveryStatusText,
                                valueText: recoveryDisplayValue == nil ? WeekFitLocalizedString("today.status.loading") : sleepValueInfoText,
                                value: recoveryDisplayValue,
                                color: recoveryColor
                            )

                            VStack(spacing: 5) {
                                metricRow(
                                    title: WeekFitLocalizedString("today.status.metric.deep"),
                                    value: deepSleepText,
                                    unit: WeekFitLocalizedString("common.unit.hoursShort"),
                                    color: recoveryColor.opacity(0.5)
                                )

                                metricRow(
                                    title: WeekFitLocalizedString("today.status.metric.hrv"),
                                    value: hrvValueText,
                                    unit: WeekFitLocalizedString("common.unit.millisecondShort"),
                                    color: recoveryColor
                                )

                                metricRow(
                                    title: WeekFitLocalizedString("today.status.metric.rhr"),
                                    value: rhrValueText,
                                    unit: WeekFitLocalizedString("common.unit.bpm"),
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

    private func compactActivityMetricDuration(_ minutes: Int) -> (value: String, unit: String) {
        let safeMinutes = max(0, minutes)

        if safeMinutes < 60 {
            return ("\(safeMinutes)", WeekFitLocalizedString("common.unit.minutesShort"))
        }

        return (String(format: "%.1f", Double(safeMinutes) / 60.0), WeekFitLocalizedString("common.unit.hoursShort"))
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

                Text(value == nil ? "—" : (centerText ?? "\(displayValue)%"))
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

                if !infoText.isEmpty {
                    Text(infoText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var upNextSection: some View {
        let now = todayViewModel.now
        let liveBronze = Color(red: 0.60, green: 0.52, blue: 0.39)
        let liveBadgeBronze = Color(red: 0.72, green: 0.63, blue: 0.45)
        let neutralIconFill = Color.white.opacity(0.065)
        let neutralStroke = Color.white.opacity(0.06)

        let activeSession = currentActiveSession

        let futureActivityToday = selectedDayActivities.first { activity in
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

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)
        let futureActivityTomorrow = plannedActivities
            .filter { activity in
                guard !activity.isCompleted,
                      !activity.isSkipped,
                      activity.date > now,
                      let tomorrow,
                      Calendar.current.isDate(activity.date, inSameDayAs: tomorrow) else {
                    return false
                }

                return true
            }
            .sorted { $0.date < $1.date }
            .first

        let nextActivity = futureActivityToday ?? futureActivityTomorrow

        return VStack(alignment: .leading, spacing: 8) {
            Text(AppText.Today.upNextTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(textPrimary)
                .tracking(0.3)
                .padding(.leading, 2)

            if let activeSession {
                let activeColor = liveBronze

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(activeColor.opacity(0.075))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(activeColor.opacity(0.24), lineWidth: 1))

                        Image(systemName: upNextIcon(for: activeSession, isLive: true))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(liveBadgeBronze.opacity(0.86))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppText.Today.currentSession)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(textPrimary)

                        Text(String(format: WeekFitLocalizedString("today.upNext.inProgressFormat"), shortDisplayTitle(activityDisplayTitle(activeSession))))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(textTertiary)
                    }

                    Spacer()

                    Text(AppText.Today.live)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(liveBadgeBronze.opacity(0.92))
                        .clipShape(Capsule())
                }
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [
                            activeColor.opacity(0.030),
                            cardBackground.opacity(0.44)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(activeColor.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: activeColor.opacity(0.025), radius: 10, y: 4)

            } else if let activity = nextActivity {
                Button {
                    onSelectTab(.calendar)
                } label: {
                    HStack(spacing: 12) {

                        ZStack {
                            Circle()
                                .fill(neutralIconFill)
                                .frame(width: 44, height: 44)
                                .overlay(Circle().stroke(neutralStroke, lineWidth: 1))

                            Image(systemName: upNextIcon(for: activity))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(textSecondary.opacity(0.86))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(shortDisplayTitle(activityDisplayTitle(activity)))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(textPrimary)

                            Text(upNextSubtitle(for: activity))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(textTertiary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .layoutPriority(1)

                        Spacer()

                        Text(upNextTimeText(for: activity, selectedDate: selectedDate))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(liveBronze.opacity(0.82))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(liveBronze.opacity(0.075))
                            .clipShape(Capsule())
                            .fixedSize(horizontal: true, vertical: false)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(textTertiary)
                    }
                    .padding(14)
                    .background(cardBackground.opacity(0.38))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(neutralStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()

                    onSelectTab(.calendar)

                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.16, green: 0.80, blue: 0.43))

                        Text(AppText.Today.noActivitiesPlanned)
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
            return WeekFitLocalizedString("today.activity.context.nutrition")

        case "workout":
            return WeekFitLocalizedString("today.activity.context.endurance")

        case "recovery":
            return WeekFitLocalizedString("today.activity.context.recovery")

        default:
            return WeekFitLocalizedString("today.activity.context.routine")
        }
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
                if let finalStory = coachCoordinator.state.finalStory {
                    let renderModel = CoachFinalStoryRenderModel(story: finalStory)
                    let insightColor = renderModel.color
                    let insightTitle = renderModel.title
                    let insightIcon = renderModel.icon
                    let insightMessage = renderModel.subtitle
                    let insightStateLabel = renderModel.badge

                    let _ = debugTodayCoachInsight(
                        semanticInsight: finalStory.todaySemanticInsight,
                        titleKey: finalStory.titleKey,
                        subtitleKey: finalStory.subtitleKey,
                        localizedTitle: insightTitle,
                        localizedSubtitle: insightMessage,
                        coachScreenStoryTitle: nil
                    )

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSelectTab(.coach)
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(insightColor.opacity(0.10))
                                    .frame(width: 38, height: 38)

                                Image(systemName: insightIcon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(insightColor)
                            }

                            VStack(alignment: .leading, spacing: 8) {

                                Text(insightStateLabel)
                                    .font(.system(size: 10.5, weight: .bold))
                                    .tracking(1.3)
                                    .foregroundStyle(insightColor.opacity(0.82))

                                Text(insightTitle)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil)
                                    .layoutPriority(1)
                                    .fixedSize(horizontal: false, vertical: true)

                                if !insightMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                                    Text(insightMessage)
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundStyle(textSecondary.opacity(0.82))
                                        .lineSpacing(2)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                        .layoutPriority(1)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(textTertiary)
                                .padding(.top, 4)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [
                                    insightColor.opacity(0.060),
                                    cardBackground.opacity(0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            insightColor.opacity(0.18),
                                            Color.white.opacity(0.035)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: insightColor.opacity(0.05), radius: 12, y: 5)
                        .shadow(color: Color.black.opacity(0.10), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Settling fallback only. Do not synthesize a legacy Coach story without CoachFinalStory.
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text(shouldShowHealthConnectPrompt ? AppText.Today.connectHealthInsights : AppText.Today.recoverySleepSyncPending)
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
                .weekFitSheetChrome(cornerRadius: 30)
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

    private func handleReturnToTodayRequest() {
        selectedDate = Date()
        debugTodayDataState(source: "handleReturnToTodayRequest")
    }

    private func refreshTodayAfterAppBecameActive() {
        let currentDate = Date()
        todayViewModel.now = currentDate

        if !Calendar.current.isDate(selectedDate, inSameDayAs: currentDate) {
            selectedDate = currentDate
            debugTodayDataState(source: "scenePhase.active.dateRolledOver")
            return
        }

        debugTodayDataState(source: "scenePhase.active.sameDay")
        todayViewModel.triggerHealthRefresh()
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

        if text.contains("walk")
            || text.contains("walking")
            || text.contains("ходь")
            || text.contains("прогул") {
            return "figure.walk"
        }

        if text.contains("run")
            || text.contains("running")
            || text.contains("бег") {
            return "figure.run"
        }

        if text.contains("cycling")
            || text.contains("cycle")
            || text.contains("bike")
            || text.contains("ride")
            || text.contains("вел")
            || text.contains("вело") {
            return "bicycle"
        }

        if text.contains("hike")
            || text.contains("hiking")
            || text.contains("поход") {
            return "figure.hiking"
        }

        if text.contains("core")
            || text.contains("abs")
            || text.contains("abdominal")
            || text.contains("кор")
            || text.contains("пресс") {
            return "figure.core.training"
        }

        if text.contains("upper body")
            || text.contains("lower body")
            || text.contains("full body")
            || text.contains("strength")
            || text.contains("gym")
            || text.contains("weights")
            || text.contains("dumbbell")
            || text.contains("сил")
            || text.contains("зал") {
            return "figure.strengthtraining.traditional"
        }

        if text.contains("stretch")
            || text.contains("stretching")
            || text.contains("mobility")
            || text.contains("flexibility")
            || text.contains("растяж")
            || text.contains("мобил") {
            return "figure.flexibility"
        }

        if text.contains("yoga")
            || text.contains("йога") {
            return "figure.mind.and.body"
        }

        if text.contains("breathing")
            || text.contains("breath")
            || text.contains("дых") {
            return "wind"
        }

        if text.contains("sauna")
            || text.contains("heat")
            || text.contains("саун") {
            return "flame.fill"
        }

        if text.contains("swim")
            || text.contains("swimming")
            || text.contains("плав") {
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
    
    private var quickActionsSection: some View {
        let activeSession = currentActiveSession

        return VStack(alignment: .leading, spacing: 8) {
            Text(AppText.Today.quickActionsTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(textPrimary)
                .padding(.leading, 2)

            HStack(spacing: 0) {
                quickActionItem(
                    icon: "takeoutbag.and.cup.and.straw.fill",
                    label: WeekFitLocalizedString("today.quickActions.logDrinks"),
                    subLabel: String(format: "%.1f/%.1fL", currentWater, waterGoal),
                    color: Color(red: 0.25, green: 0.55, blue: 0.95),
                    showsWaterToast: showWaterToast
                ) {
                    preloadQuickDrinkLogDataIfNeeded()
                    showDirectDrinkLogSheet = true
                }

                quickActionItem(
                    icon: "fork.knife",
                    label: WeekFitLocalizedString("today.quickActions.logFood"),
                    subLabel: WeekFitLocalizedString("today.quickActions.mealsSnacks"),
                    color: Color(red: 0.95, green: 0.65, blue: 0.12)
                ) {
                    selectedLogTab = .meals
                    preloadQuickFoodLogDataIfNeeded()
                    showDirectMealLogSheet = true
                }

                quickActionItem(
                    icon: activeSession == nil ? "play.circle.fill" : "stop.circle.fill",
                    label: activeSession == nil ? WeekFitLocalizedString("today.quickActions.startActivity") : WeekFitLocalizedString("today.quickActions.endActivity"),
                    subLabel: activeSession.map { activityDisplayTitle($0) }
                        ?? WeekFitLocalizedString("today.quickActions.workoutRecovery"),
                    color: activeSession == nil ? CoachPalette.stable : Color(red: 0.60, green: 0.52, blue: 0.39),
                    liveIndicatorColor: activeSession == nil
                        ? nil
                        : Color(red: 0.72, green: 0.63, blue: 0.45)
                ) {
                    showDirectWorkoutLogSheet = true
                }
            }
        }
    }

    private func quickActionItem(
        icon: String,
        label: String,
        subLabel: String,
        color: Color,
        liveIndicatorColor: Color? = nil,
        showsWaterToast: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action()
            } label: {
                ZStack(alignment: .top) {
                    Circle()
                        .fill(color.opacity(0.12))
//                        .overlay(Circle().stroke(color.opacity(0.72), lineWidth: 1.4))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundColor(color).frame(width: 30, height: 30)
                    
                    if showsWaterToast {
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
        let accentColor = activity.color
        
        return VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text(AppText.Today.verifyLogBlock)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(textPrimary)
                
                Text(String(format: WeekFitLocalizedString("today.verify.messageFormat"), activityDisplayTitle(activity)))
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
                        todayViewModel.triggerHealthRefresh()
                        activityToConfirm = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text(AppText.Today.skippedAction)
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
                        todayViewModel.triggerHealthRefresh()
                        activityToConfirm = nil
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(AppText.Today.confirmLogAction)
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

    private func upNextIcon(for activity: PlannedActivity, isLive: Bool = false) -> String {
        let fallback = activity.icon.isEmpty ? "sparkles" : activity.icon
        let normalizedType = activity.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedSource = activity.source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard normalizedType == "workout" ||
            normalizedType == "training" ||
            normalizedType == "recovery" ||
            normalizedSource == "appleworkout" else {
            return fallback
        }

        let text = [
            activity.title,
            activity.type,
            activity.source,
            activity.imageName
        ]
        .joined(separator: " ")
        .lowercased()

        let resolvedIcon = iconForWorkoutInsightText(text, fallback: fallback)

        if isLive && resolvedIcon == "figure.walk" {
            return "figure.walk.motion"
        }

        return resolvedIcon
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

        let prefix = WeekFitCurrentLocale().identifier.hasPrefix("ru") ? "Завтра" : "Tomorrow"
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
            nutritionViewModel: nutritionViewModel,
            appSession: appSession
        )
        await MainActor.run {
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
        WeekFitCoachRuntimeLocalizedString(activity.title)
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
