import SwiftUI
import SwiftData
import HealthKit
internal import Combine

struct TodayView: View {

    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject private var appSession: AppSessionState
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage(ProfileService.Keys.initials)
    private var profileInitials: String = "P"

    @StateObject private var confirmationState = ActivityConfirmationState.shared
    
    @AppStorage(ProfileService.Keys.fullName)
    private var fullName: String = "P"
    
    @State private var healthRefreshID = UUID()

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]
    
    @State private var showDirectMealLogSheet = false

    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    
    @State private var showProfile = false
    @State private var selectedTab: WeekFitTab = .today
    @State private var showContent = false
    @State private var isEditingActivity = false
    @State private var selectedDate = Date()
    @State private var livePulse = false
    @State private var showWaterToast = false
    
    @State private var activityToConfirm: PlannedActivity? = nil

    private let background = Color(red: 0.05, green: 0.06, blue: 0.08)
    private let cardBackground = Color(red: 0.10, green: 0.11, blue: 0.14)
    private let cardSecondary = Color(red: 0.14, green: 0.15, blue: 0.19)

    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.65)
    private let textTertiary = Color.white.opacity(0.35)
    
    @State private var showDirectWorkoutLogSheet = false
    @State private var showDirectRecoveryLogSheet = false

    // MARK: - Динамический подсчет нутриентов из SwiftData (Локальный План)
    private var loggedPlanCalories: Double {
        selectedDayActivities
            .filter { $0.type.lowercased() == "meal" && $0.isCompleted && $0.imageName != "hydration" }
            .reduce(0.0) { $0 + Double($1.calories) }
    }

    private var loggedPlanProtein: Double {
        selectedDayActivities
            .filter { $0.type.lowercased() == "meal" && $0.isCompleted && $0.imageName != "hydration" }
            .reduce(0.0) { $0 + Double($1.protein) }
    }

    private var loggedPlanCarbs: Double {
        selectedDayActivities
            .filter { $0.type.lowercased() == "meal" && $0.isCompleted && $0.imageName != "hydration" }
            .reduce(0.0) { $0 + Double($1.carbs) }
    }

    private var loggedPlanFats: Double {
        selectedDayActivities
            .filter { $0.type.lowercased() == "meal" && $0.isCompleted && $0.imageName != "hydration" }
            .reduce(0.0) { $0 + Double($1.fats) }
    }

    // Итоговые сквозные макросы (Датчики + Локальный лог)
    private var currentProtein: Double { healthManager.protein + loggedPlanProtein }
    private var currentCarbs: Double { healthManager.carbs + loggedPlanCarbs }
    private var currentFats: Double { healthManager.fats + loggedPlanFats }
    private var currentCalories: Double { healthManager.calories + loggedPlanCalories }

    private var proteinGoal: Double { nutritionViewModel.nutritionResult?.goals.protein ?? 153.0 }
    private var carbsGoal: Double { nutritionViewModel.nutritionResult?.goals.carbs ?? 330.0 }
    private var fatsGoal: Double { nutritionViewModel.nutritionResult?.goals.fats ?? 90.0 }
    private var caloriesGoal: Double { nutritionViewModel.nutritionResult?.goals.calories ?? 2761.0 }
    private var waterGoal: Double { nutritionViewModel.nutritionResult?.goals.waterLiters ?? 4.46 }
    
    // ИСПРАВЛЕНО: Источник правды для Коуча теперь берет очищенные метрики из вью-модели
    private var currentCoachState: CoachInsightState {
        let metrics = nutritionViewModel.currentMetrics ?? DailyNutritionMetrics(
            protein: 0, carbs: 0, fats: 0, calories: 0, waterLiters: 0,
            activeCalories: healthManager.activeCalories, sleepHours: healthManager.sleepHours, weightKg: healthManager.weight
        )
        return AICoachEngine.evaluateSmartInsight(selectedDate: selectedDate, activities: selectedDayActivities, metrics: metrics, name: fullName)
    }
    
    private var currentWater: Double {
        let waterLogsToday = selectedDayActivities.filter { $0.imageName == "hydration" }
        return Double(waterLogsToday.count) * 0.25
    }

    // Вычисляем динамический стейт приветствия
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

    var body: some View {
        ZStack(alignment: .bottom) {
            background.ignoresSafeArea()
            ambientBackground

            Group {
                switch selectedTab {
                case .today:
                    summaryContent
                case .coach:
//                    CoachView(authViewModel: authViewModel)
                    ExpertCoachView(authViewModel: authViewModel)
                        .transition(.opacity)
                case .meals:
                    MealsView(authViewModel: authViewModel, nutritionResult: nutritionViewModel.nutritionResult)
                        .transition(.opacity)
                case .calendar:
                    PlanView(authViewModel: authViewModel, isEditingActivity: $isEditingActivity)
                        .transition(.opacity)
                }
            }

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
        .preferredColorScheme(.dark)
        // ИСПРАВЛЕНО: Убран DispatchQueue, ломающий жизненный цикл асинхронного таска
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.88)) { showContent = true }
        }
        .task(id: healthRefreshID) {
            await refreshHealthAndNutritionAsync()
        }
        .onChange(of: plannedActivities) { _, _ in
            updateNutrition()
        }
        .onReceive(Timer.publish(every: 10, on: .main, in: .common).autoconnect()) { _ in
            let calendar = Calendar.current
            if !calendar.isDate(selectedDate, inSameDayAs: Date()) {
                withAnimation(.smooth) {
                    selectedDate = Date()
                    healthRefreshID = UUID()
                }
                print("🔄 [Circadian Engine] Date shifted past midnight. Retracking health metrics.")
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                // 1. Обязательно передаем authViewModel, если профиль завязан на сессию
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
            // 2. Пробрасываем все окружения, чтобы ProfileView не крашился и видел данные
            .environmentObject(healthManager)
            .environmentObject(nutritionViewModel)
            .environmentObject(appSession)
            .presentationDetents([.large])
            .presentationCornerRadius(36)
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showDirectWorkoutLogSheet) {
            PremiumActivityStartSheet(
                background: WeekFitTheme.background,
                cardBackground: WeekFitTheme.cardBackground,
                textSecondary: WeekFitTheme.secondaryText,
                isPresented: $showDirectWorkoutLogSheet,
                refreshID: $healthRefreshID
            )
            .presentationDetents([.height(320)])
            .presentationCornerRadius(34)
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showDirectMealLogSheet) {
            NavigationStack {
                // Извлекаем еду напрямую из UserDefaults, как это делает MealsView
                let storedData = UserDefaults.standard.string(forKey: "weekfit_custom_meals_v1") ?? ""
                let decodedMeals = (try? JSONDecoder().decode([Meals].self, from: storedData.data(using: .utf8) ?? Data())) ?? []
                
                ZStack {
                    Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea() // Твой фон проекта
                    
                    if decodedMeals.isEmpty {
                        // Если базы рецептов вообще нет, мягко предлагаем перейти в полноценное меню
                        VStack(spacing: 16) {
                            Text("No custom meals saved yet")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Button("Open Meal Planner") {
                                showDirectMealLogSheet = false
                                withAnimation { selectedTab = .meals } // Переключаем нижний таб
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.16, green: 0.80, blue: 0.43))
                        }
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 10) {
                                ForEach(decodedMeals) { meal in
                                    MealCardRow(meal: meal, isQuickLogMode: true) {
                                        // Мгновенный лог-экшен при тапе на Плюс
                                        let quickLogActivity = PlannedActivity(
                                            id: UUID().uuidString,
                                            date: Date(),
                                            type: "meal",
                                            title: meal.title,
                                            durationMinutes: 20,
                                            icon: "fork.knife",
                                            imageName: meal.imageName,
                                            colorRed: 0.55, colorGreen: 0.40, colorBlue: 0.85,
                                            calories: meal.calories,
                                            protein: meal.protein,
                                            carbs: meal.carbs,
                                            fats: meal.fats,
                                            isCompleted: true,
                                            isSkipped: false
                                        )
                                        modelContext.insert(quickLogActivity)
                                        try? modelContext.save()
                                        
                                        showDirectMealLogSheet = false
                                        healthRefreshID = UUID()
                                    }
                                    .onTapGesture {
                                        // Дополнительный UX: если юзер тапнул на саму карточку, а не на плюс,
                                        // мы можем либо тоже логать, либо просто проигнорировать. Оставим лог для удобства!
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                }
                .navigationTitle("Log Meal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { showDirectMealLogSheet = false }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
            }
//            .presentationDetents([.medium, .large]) // Шторка открывается наполовину экрана, не перекрывая Today полностью!
//            .presentationCornerRadius(32)
            .presentationDetents([.height(320)])
            .presentationCornerRadius(34)
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
        }
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(colors: [Color(red: 0.16, green: 0.80, blue: 0.43).opacity(0.02), Color.clear], center: .topTrailing, startRadius: 10, endRadius: 400)
        }
        .ignoresSafeArea()
    }

    private var summaryContent: some View {
        VStack(spacing: 11) {
            heroHeaderSection
                .padding(.top, UIScreen.main.bounds.height > 800 ? 14 : 5)
            
            dailyStatusSection
            
            upNextSection
            
            coachInsightSection
            
            quickActionsSection
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 95)
    }

    private var heroHeaderSection: some View {
        let greeting = timeOfDayGreeting
        
        return HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.75)
                
                HStack(spacing: 5) {
                    Text(selectedDateTitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(textSecondary)
//                    Text("•")
                        .foregroundStyle(textTertiary)
                    
//                    Image(systemName: greeting.icon)
//                        .font(.system(size: 11))
//                        .foregroundColor(greeting.iconColor)
//                    
//                    Text("\(greeting.text), \(fullName)")
//                        .font(.system(size: 13, weight: .regular))
//                        .foregroundStyle(textSecondary)
                }
            }
            Spacer()
            
            avatarButton
        }
    }
    
    private var avatarButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showProfile = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.92, green: 0.78, blue: 0.50),
                                Color(red: 0.76, green: 0.62, blue: 0.36)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Circle()
                    .stroke(WeekFitTheme.meal.opacity(0.38), lineWidth: 2.5)

                Circle()
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
                    .padding(5)

                Text(profileInitials)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.94))
            }
            .frame(width: 48, height: 48)
            .shadow(color: WeekFitTheme.meal.opacity(0.09), radius: 11, y: 5)
            .shadow(color: Color.black.opacity(0.22), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open profile")
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
        
        // 1. Расчет Activity (0-100%)
        let activityPercent = baseGoal > 0 ? Int((healthManager.activeCalories / baseGoal) * 100) : 0
        
        // 🎯 ФИКС NUTRITION ПРОЦЕНТА (Разбиваем выражение для компилятора и переводим в Int 0-100)
        let baseTargetCalories: Double = nutritionViewModel.nutritionResult?.targetCalories ?? 1743.0
        let activeCaloriesBurned: Double = healthManager.activeCalories
        let dynamicNutritionTarget: Double = baseTargetCalories + activeCaloriesBurned
        let eatenCalories: Double = nutritionViewModel.currentMetrics?.calories ?? 0.0
        
        let nutritionPercent: Int = dynamicNutritionTarget > 0.0
            ? Int((eatenCalories / dynamicNutritionTarget) * 100)
            : 0
        
        // 2. Расчет Recovery (0-100%)
        let recoveryPercent: Int = {
            guard healthManager.sleepMinutes > 0 else { return 0 }
            let durationScore = min(Double(healthManager.sleepMinutes) / 450.0, 1.0) * 40.0
            let qualityMinutes = Double(healthManager.deepSleepMinutes + healthManager.remSleepMinutes)
            let qualityScore: Double = qualityMinutes > 0
                ? (min((qualityMinutes / Double(healthManager.sleepMinutes)) / 0.40, 1.0) * 30.0)
                : (durationScore * 0.75)
            let hrvScore = healthManager.hrvSDNN > 0 ? (min(healthManager.hrvSDNN / 50.0, 1.0) * 30.0) : 20.0
            return Int(min(max(durationScore + qualityScore + hrvScore, 0), 100))
        }()
        
        let activityColor = Color(red: 0.16, green: 0.80, blue: 0.43)
        let nutritionColor = Color(red: 0.95, green: 0.65, blue: 0.12)
        let recoveryColor = Color(red: 0.18, green: 0.74, blue: 0.89)
        
        // MARK: - Текстовые конфигурации подписей
        let activityGoalText = "Goal: \(Int(baseGoal)) kcal"
        let activityValueText = "\(Int(healthManager.activeCalories)) kcal"
        
        let sleepValueInfoText = healthManager.sleepMinutes > 0
            ? String(format: "Sleep: %.1f h", Double(healthManager.sleepMinutes) / 60.0)
            : "Sleep: —"
        
        // 🎯 ФИКС RECOVERY СТАТУСА: Если кольцо набрало 92%, принудительно выводим "Ready" вместо "Need Rest"
        let recoveryStatusText: String = {
            if recoveryPercent >= 85 || (healthManager.hrvSDNN > 75.0 && healthManager.restingHeartRate < 60.0) {
                return "Ready"
            } else if recoveryPercent >= 70 {
                return "Good"
            } else if recoveryPercent >= 50 {
                return "Ok"
            } else {
                return "Need Rest"
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
                            Text("Apple Health Disconnected")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(textPrimary)
                            Text("WeekFit requires biometric access to analyze your active metabolic circles and sleep data.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(textSecondary)
                                .lineSpacing(2)
                        }
                    }
                    .padding(.top, 4)
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task {
                            await healthManager.requestAuthorization(for: selectedDate, plannedActivities: selectedDayActivities)
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
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.80, blue: 0.43), Color(red: 0.12, green: 0.70, blue: 0.38)], startPoint: .top, endPoint: .bottom))
                        )
                        .shadow(color: Color(red: 0.16, green: 0.80, blue: 0.43).opacity(0.2), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                HStack(alignment: .top, spacing: 6) {
                    
                    // КОЛОНКА 1: ACTIVITY
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
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.015)))
                        .padding(.horizontal, 2)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // КОЛОНКА 2: NUTRITION (ИСПРАВЛЕНО: Синхронизировано на 100% с Left ккал)
                    VStack(spacing: 12) {
                        statusRingWidget(
                            title: "Nutrition",
                            infoText: remainingCaloriesText,
                            valueText: "\(Int(eatenCalories)) kcal",
                            value: nutritionPercent, // 🌟 Передаем правильный Int (80%)
                            color: nutritionColor
                        )
                        
                        VStack(spacing: 5) {
                            metricRow(title: "P", value: "\(Int(nutritionViewModel.currentMetrics?.protein ?? 0.0))/\(Int(proteinGoal))", unit: "", color: Color(red: 0.55, green: 0.40, blue: 0.85))
                            metricRow(title: "C", value: "\(Int(nutritionViewModel.currentMetrics?.carbs ?? 0.0))/\(Int(carbsGoal))", unit: "", color: Color.orange)
                            metricRow(title: "F", value: "\(Int(nutritionViewModel.currentMetrics?.fats ?? 0.0))/\(Int(fatsGoal))", unit: "", color: Color.pink)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.015)))
                        .padding(.horizontal, 2)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // КОЛОНКА 3: RECOVERY (ИСПРАВЛЕНО: Выравнивание названий и статусов как у соседей)
                    VStack(spacing: 12) {
                        statusRingWidget(
                            title: "Recovery",
                            infoText: recoveryStatusText, // 🌟 Передаем вычисленный статус по HRV/Прогрессу ("Ready")
                            valueText: sleepValueInfoText, // Количество сна ("Sleep: 6.8 h")
                            value: recoveryPercent,
                            color: recoveryColor
                        )
                        
                        VStack(spacing: 5) {
                            metricRow(title: "Deep", value: deepSleepText, unit: "h", color: recoveryColor.opacity(0.5))
                            metricRow(title: "HRV", value: hrvValueText, unit: "ms", color: recoveryColor)
                            metricRow(title: "RHR", value: rhrValueText, unit: "bpm", color: recoveryColor.opacity(0.7))
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.015)))
                        .padding(.horizontal, 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardBackground.opacity(0.6))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.03), lineWidth: 1))
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

    private func statusRingWidget(title: String, infoText: String, valueText: String, value: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.04), lineWidth: 4.0).frame(width: 72, height: 72)
                
                Circle()
                    .trim(from: 0, to: CGFloat(value) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4.0, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                
                HStack(alignment: .firstTextBaseline, spacing: 0.5) {
                    Text("\(value)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(textPrimary)
                    Text("%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(textSecondary)
                }
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
        let now = Date()
        let nextActivity = plannedActivities.first(where: { activity in
            if activity.isCompleted || activity.isSkipped { return false }
            return activity.date > now && Calendar.current.isDate(activity.date, inSameDayAs: selectedDate)
        })
        
        return VStack(alignment: .leading, spacing: 8) {
            Text("Up Next")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(textPrimary)
                .tracking(0.3)
                .padding(.leading, 2)
            
            if let activity = nextActivity {
                let accentColor = activity.color
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedTab = .calendar }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [accentColor.opacity(0.18), accentColor.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 44, height: 44)
                            Image(systemName: activity.icon.isEmpty ? "sparkles" : activity.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shortDisplayTitle(activity.title)).font(.system(size: 16, weight: .bold)).foregroundStyle(textPrimary)
                            Text(activitySubtitle(activity) + " · " + (activity.type.lowercased() == "workout" ? "Endurance" : "Nutrition")).font(.system(size: 11, weight: .regular)).foregroundStyle(textTertiary)
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
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(accentColor.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                // ИСПРАВЛЕНО: Теперь пустая заглушка тоже является кнопкой и переводит в календарь!
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        selectedTab = .calendar
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(red: 0.16, green: 0.80, blue: 0.43))
                        
                        Text("All activities for this slot are up to date.")
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
                    // Легкий outline, чтобы пустая карточка стильно вписывалась в общую экосистему темного UI
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.015), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var coachInsightSection: some View {
        let now = Date()

        // 1. Поиск пропущенных активностей, требующих подтверждения
        let pendingActivity = selectedDayActivities.first { activity in
            let eventEndDate = Calendar.current.date(
                byAdding: .minute,
                value: activity.durationMinutes,
                to: activity.date
            ) ?? activity.date

            return !activity.isCompleted
                && !activity.isSkipped
                && now > eventEndDate
        }

        return Group {
            if let pending = pendingActivity {
                // MARK: - Контекст 1: Требуется подтверждение активности (Внимание)
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
                // MARK: - Контекст 2: Динамический инсайт Коуча (Синхронизированный через Live Engine)
                if let res = nutritionViewModel.nutritionResult {
                    
                    // 🚀 ДОБАВЛЯЕМ ЛОГ ПРЯМО СЮДА:
                    let _ = print("""
                    🍏 [TODAY VIEW LOG]
                    - Target Calories from Goal: \(res.targetCalories)
                    - Consumed Calories in metrics: \(res.consumedCalories)
                    - Brain Calories Progress: \(res.brain.current.caloriesProgress)
                    - Brain Carbs Progress: \(res.brain.current.carbsProgress)
                    - Brain Energy Coverage: \(res.brain.current.energyCoverage)
                    - Brain Fuel State: \(res.brain.fuel)
                    """)
                    
                    let liveDecision = CoachDecisionEngine.makeDecision(from: res.brain)
                    
                    let _ = print("🧠 [TODAY VIEW LOG] Live Decision Strategy: \(liveDecision.primaryStrategy)")
                    
                    let currentStrategy = liveDecision.primaryStrategy
                    
                    // 🎨 Настройка цвета плашки на основе ИИ-стратегии
                    let insightColor: Color = {
                        switch currentStrategy {
                        case .overload:
                            return .orange
                        case .supercompensation, .protectRecovery:
                            return .indigo // Мягкий индиго вместо панического красного!
                        default:
                            return Color(red: 0.16, green: 0.80, blue: 0.43) // Норма — Зеленый
                        }
                    }()
                    
                    // 🔤 Настройка заголовка плашки
                    let insightTitle: String = {
                        switch currentStrategy {
                        case .overload:           return "Energy Overload Detected"
                        case .supercompensation:  return "High Metabolic Strain"
                        case .protectRecovery:    return "Recovery Focus Required"
                        case .logFood:            return "Log Your Food"
                        default:                  return "Coach Insight"
                        }
                    }()
                    
                    // 🔣 Настройка иконки
                    let insightIcon: String = {
                        switch currentStrategy {
                        case .overload:           return "exclamationmark.shield.fill"
                        case .supercompensation:  return "flame.circle.fill"
                        case .protectRecovery:    return "heart.text.square.fill"
                        default:                  return "brain.head.profile"
                        }
                    }()
                    
                    // 📝 Сборка короткого текста
                    let insightMessage = CoachCopy.shortInsight(brain: res.brain, decision: liveDecision)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedTab = .coach
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(insightColor.opacity(0.12))
                                    .frame(width: 36, height: 36)

                                Image(systemName: insightIcon)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(insightColor)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(insightTitle)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(insightColor)

                                Text(insightMessage)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(textPrimary.opacity(0.90))
                                    .lineSpacing(2.5)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(insightColor.opacity(0.45))
                                .padding(.top, 11)
                        }
                        .padding(14)
                        .background(
                            LinearGradient(
                                colors: [
                                    insightColor.opacity(0.06),
                                    cardBackground.opacity(0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(insightColor.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: insightColor.opacity(0.04), radius: 12, y: 4)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Базовый фолбэк-индикатор, пока данные подгружаются
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Analyzing lifestyle balance...")
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
                .presentationDragIndicator(.visible)
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(textPrimary)
                .padding(.leading, 2)
            
            HStack(spacing: 0) {
                quickActionItem(icon: "drop.fill", label: "Log Water", subLabel: String(format: "%.1f/%.1fL", currentWater, waterGoal), color: Color(red: 0.25, green: 0.55, blue: 0.95))
                quickActionItem(icon: "fork.knife", label: "Log Meal", subLabel: "Nutrition", color: Color(red: 0.55, green: 0.40, blue: 0.85))
                
                // Проверяем, есть ли сейчас вообще какая-то запущенная Live-активность
                let hasLive = selectedDayActivities.contains { !$0.isCompleted && !$0.isSkipped && $0.date <= Date() && Date() <= Calendar.current.date(byAdding: .minute, value: $0.durationMinutes, to: $0.date)! }
                
                quickActionItem(
                    icon: hasLive ? "stop.circle.fill" : "play.circle.fill",
                    label: "Start Activity",
                    subLabel: hasLive ? "Active Session" : "Workout / Rest",
                    color: hasLive ? Color.orange : Color(red: 0.16, green: 0.80, blue: 0.43)
                )
            }
        }
    }

    private func quickActionItem(icon: String, label: String, subLabel: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                switch label {
                case "Log Water":
                    executePersistentWaterLog()
                case "Log Meal":
                    showDirectMealLogSheet = true
                case "Start Activity": // 🌟 ИСПРАВЛЕНО: Новый единый кейс для Workout и Recovery
                    showDirectWorkoutLogSheet = true
                default:
                    break
                }
            } label: {
                ZStack(alignment: .top) {
                    Circle().fill(color.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundColor(color).frame(width: 48, height: 48)
                    
                    if label == "Log Water" && showWaterToast {
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

    private func executePersistentWaterLog() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
            showWaterToast = true
            
            let redComponent: Double = 0.25
            let greenComponent: Double = 0.55
            let blueComponent: Double = 0.95
            
            let waterActivity = PlannedActivity(
                id: UUID().uuidString, date: Date(), type: "meal", title: "Water Log (0.25L)",
                durationMinutes: 5, icon: "drop.fill", imageName: "hydration",
                colorRed: redComponent, colorGreen: greenComponent, colorBlue: blueComponent,
                calories: 0, protein: 0, carbs: 0, fats: 0, isCompleted: true, isSkipped: false
            )
            
            modelContext.insert(waterActivity)
            try? modelContext.save()
            
            updateNutrition(withExtraWater: 0.25)
            healthRefreshID = UUID()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation { showWaterToast = false }
        }
    }

    private func updateNutrition(withExtraWater extra: Double = 0) {
        let metrics = DailyNutritionMetrics(
            protein: 0,
            carbs: 0,
            fats: 0,
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
            plannedActivities: selectedDayActivities
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
        .background(background.ignoresSafeArea())
    }

    private func activitySubtitle(_ activity: PlannedActivity) -> String {
        switch activity.type.lowercased() {
        case "meal": return "Nutrition"
        case "workout": return "Outdoor"
        default: return "Routine"
        }
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
        if let result = nutritionViewModel.nutritionResult {
            let dynamicCalories = result.goals.calories
            let activeTarget = (dynamicCalories / 1.15) * 0.25
            return (activeTarget / 10.0).rounded() * 10.0
        }
        
        let safeWeight = max(healthManager.weight, 60.0)
        let safeHeight = max(healthManager.heightCm, 160.0)
        let safeAge = max(Double(healthManager.age), 20.0)
        
        let genderBonus = healthManager.biologicalSex == .female ? -161.0 : 5.0
        let calculatedBMR = 10.0 * safeWeight + 6.25 * safeHeight - 5.0 * safeAge + genderBonus
        
        let fallbackActiveTarget = calculatedBMR * 0.25
        return (fallbackActiveTarget / 10.0).rounded() * 10.0
    }

    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }

    private func shortDisplayTitle(_ title: String) -> String {
        title.components(separatedBy: ",").first ?? title
    }

    private var selectedDayActivities: [PlannedActivity] {
        plannedActivities.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }.sorted { $0.date < $1.date }
    }
}
