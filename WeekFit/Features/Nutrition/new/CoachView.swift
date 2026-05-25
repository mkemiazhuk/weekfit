//import SwiftUI
//import SwiftData
//
//struct CoachView: View {
//    
//    @ObservedObject var authViewModel: AuthViewModel
//    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
//    @EnvironmentObject private var healthManager: HealthManager
//    @EnvironmentObject private var appSession: AppSessionState
//    @Environment(\.modelContext) private var modelContext
//    
//    @AppStorage(ProfileService.Keys.initials)
//    private var profileInitials: String = "P"
//    
//    @State private var showProfile = false
//    @State private var showContent = false
//    @State private var selectedDate = Date()
//    @State private var healthRefreshID = UUID()
//    @State private var waterLoggedToast = false
//    
//    // Theme Token Setup
//    private let background = WeekFitTheme.background
//    private let cardBackground = WeekFitTheme.cardBackground
//    private let cardSecondary = WeekFitTheme.cardSecondary
//    private let cardTertiary = WeekFitTheme.cardTertiary
//    private let elevatedCard = WeekFitTheme.elevatedCard
//
//    private let textPrimary = WeekFitTheme.primaryText
//    private let textSecondary = WeekFitTheme.secondaryText
//    private let textTertiary = WeekFitTheme.tertiaryText
//    private let softShadow = WeekFitTheme.cardShadow
//    
//    private var nutrition: NutritionResult? { nutritionViewModel.nutritionResult }
//    
//    private var proteinGoal: Double { nutrition?.goals.protein ?? 0.0 }
//    private var carbsGoal: Double { nutrition?.goals.carbs ?? 0.0 }
//    private var caloriesGoal: Double { nutrition?.goals.calories ?? 0.0 }
//    private var waterGoal: Double { nutrition?.goals.waterLiters ?? 0.0 }
//    
//    private var currentProtein: Double { nutritionViewModel.currentMetrics?.protein ?? 0 }
//    private var currentCarbs: Double { nutritionViewModel.currentMetrics?.carbs ?? 0 }
//    private var currentCalories: Double { nutritionViewModel.currentMetrics?.calories ?? 0 }
//    private var currentWater: Double { nutritionViewModel.currentMetrics?.waterLiters ?? 0 }
//    
//    private var workoutCoachCard: WorkoutRecoveryCoachCard {
//        WorkoutRecoveryCoachService().generate(
//            plannedActivities: plannedActivities,
//            selectedDate: selectedDate,
//            sleepHours: healthManager.sleepHours,
//            activeCalories: healthManager.activeCalories
//        )
//    }
//    
//    private var coachState: WorkoutRecoveryCoachState {
//        workoutCoachCard.state
//    }
//    
//    private var coachColor: Color {
//        switch coachState {
//        case .liveActivity, .preActivity, .laterToday:
//            return WeekFitTheme.orange
//        case .recovery, .movement, .balanced:
//            return WeekFitTheme.meal
//        case .recentlyMissed, .adjustedDay, .sleep:
//            return WeekFitTheme.purple
//        }
//    }
//    
//    @Query(sort: \PlannedActivity.date, order: .forward)
//    private var plannedActivities: [PlannedActivity]
//    
//    private var fastFuelItems: [FastFuelItem] {
//        FastFuelSuggestionService().generate(
//            currentWater: currentWater,
//            waterGoal: waterGoal,
//            currentProtein: currentProtein,
//            proteinGoal: proteinGoal,
//            currentCarbs: currentCarbs,
//            carbsGoal: carbsGoal,
//            sleepHours: healthManager.sleepHours,
//            activeCalories: healthManager.activeCalories,
//            plannedActivities: plannedActivitiesForSelectedDate,
//            selectedDate: selectedDate,
//            primaryInsight: primaryInsight
//        )
//    }
//    
//    var body: some View {
//        ZStack(alignment: .top) {
//            background.ignoresSafeArea()
//            ambientBackground
//            
//            ScrollView(showsIndicators: false) {
//                VStack(alignment: .leading, spacing: 22) {
//                    heroHeaderSection
//                        .padding(.top, 10)
//                    
//                    dynamicCoachStateCard
//                    
//                    recommendedFoodSection
//                    
//                    aiDayAnalyticsSection
//                }
//                .padding(.horizontal, 16)
//                .padding(.bottom, 140)
//                .opacity(showContent ? 1 : 0)
//                .offset(y: showContent ? 0 : 8)
//            }
//            
//            if waterLoggedToast {
//                Text("Logged successfully!")
//                    .font(.system(size: 13, weight: .bold))
//                    .foregroundStyle(.white)
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 10)
//                    .background(Color(red: 0.16, green: 0.80, blue: 0.43))
//                    .clipShape(Capsule())
//                    .padding(.top, 20)
//                    .transition(.move(edge: .top).combined(with: .opacity))
//            }
//        }
//        .preferredColorScheme(.dark)
//        .onAppear {
//            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { showContent = true }
//        }
//        .task(id: healthRefreshID) {
//            await refreshCoachDataAsync()
//        }
//        .onChange(of: appSession.healthRefreshTrigger) { _, _ in
//            healthRefreshID = UUID()
//        }
//        .sheet(isPresented: $showProfile) {
//            NavigationStack {
//                ProfileView()
//                    .toolbar {
//                        ToolbarItem(placement: .topBarTrailing) {
//                            Button("Done") {
//                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                                showProfile = false
//                            }
//                            .font(.system(size: 15, weight: .bold))
//                            .foregroundColor(Color(red: 0.16, green: 0.80, blue: 0.43))
//                        }
//                    }
//            }
//            .environmentObject(healthManager)
//            .environmentObject(nutritionViewModel)
//            .environmentObject(appSession)
//            .presentationDetents([.large])
//            .presentationCornerRadius(36)
//            .presentationDragIndicator(.hidden)
//        }
//    }
//    
//    private var ambientBackground: some View {
//        ZStack {
//            RadialGradient(colors: [Color.orange.opacity(0.03), Color.clear], center: .topTrailing, startRadius: 10, endRadius: 380)
//            RadialGradient(colors: [Color(red: 0.25, green: 0.55, blue: 0.95).opacity(0.02), Color.clear], center: .bottomLeading, startRadius: 10, endRadius: 340)
//        }
//        .ignoresSafeArea()
//    }
//    
//    private var heroHeaderSection: some View {
//        HStack(alignment: .center) {
//            VStack(alignment: .leading, spacing: 4) {
//                Text("Coach")
//                    .font(.system(size: 34, weight: .bold))
//                    .foregroundStyle(textPrimary)
//                    .tracking(-0.75)
//                
//                Text(selectedDateTitle)
//                    .font(.system(size: 14, weight: .medium))
//                    .foregroundStyle(textSecondary)
//            }
//            Spacer()
//            avatarButton
//        }
//    }
//    
//    private var avatarButton: some View {
//        Button {
//            UIImpactFeedbackGenerator(style: .light).impactOccurred()
//            showProfile = true
//        } label: {
//            ZStack {
//                Circle()
//                    .fill(LinearGradient(colors: [Color(red: 0.92, green: 0.78, blue: 0.50), Color(red: 0.76, green: 0.62, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing))
//                Circle()
//                    .stroke(WeekFitTheme.meal.opacity(0.38), lineWidth: 2.5)
//                Circle()
//                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
//                    .padding(5)
//                Text(profileInitials)
//                    .font(.system(size: 15.5, weight: .bold))
//                    .foregroundStyle(.white.opacity(0.94))
//            }
//            .frame(width: 48, height: 48)
//            .shadow(color: WeekFitTheme.meal.opacity(0.09), radius: 11, y: 5)
//            .shadow(color: Color.black.opacity(0.22), radius: 8, y: 4)
//        }
//        .buttonStyle(.plain)
//        .accessibilityLabel("Open profile")
//    }
//    
//    @ViewBuilder
//    private var dynamicCoachStateCard: some View {
//        let liveActivity = plannedActivitiesForSelectedDate.first { activity in
//            ActivityStatusEvaluator.evaluate(activity) == .live
//        }
//        
//        let pendingActivity = plannedActivities.first { activity in
//            let eventEndDate = Calendar.current.date(byAdding: .minute, value: activity.durationMinutes, to: activity.date) ?? activity.date
//            return !activity.isCompleted && !activity.isSkipped && (Date() > eventEndDate)
//        }
//        
//        if let activity = pendingActivity {
//            let isMeal = activity.type.lowercased() == "meal"
//            let cardColor = Color.orange
//            
//            VStack(alignment: .leading, spacing: 14) {
//                HStack(alignment: .top, spacing: 12) {
//                    ZStack {
//                        Circle().fill(cardColor.opacity(0.12)).frame(width: 40, height: 40)
//                        Image(systemName: "questionmark.circle.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(cardColor)
//                    }
//                    
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text(isMeal ? "How did your meal go?" : "Check in with your coach")
//                            .font(.system(size: 15, weight: .bold))
//                            .foregroundStyle(textPrimary)
//                        Text("Action Required")
//                            .font(.system(size: 12, weight: .medium))
//                            .foregroundStyle(textSecondary)
//                    }
//                    Spacer()
//                }
//                
//                Text("Your scheduled \(activity.title.lowercased()) window has closed. Let me know if you completed it so I can instantly update your energy scores.")
//                    .font(.system(size: 13, weight: .medium))
//                    .foregroundStyle(textSecondary)
//                    .lineSpacing(3)
//                
//                HStack(spacing: 10) {
//                    Button {
//                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
//                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
//                            activity.isSkipped = true
//                            activity.isCompleted = false
//                            try? modelContext.save()
//                            healthRefreshID = UUID()
//                        }
//                    } label: {
//                        HStack {
//                            Image(systemName: "xmark.circle")
//                            Text("I skipped it")
//                        }
//                        .font(.system(size: 13, weight: .bold))
//                        .foregroundStyle(textSecondary)
//                        .frame(maxWidth: .infinity).frame(height: 40)
//                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
//                    }
//                    .buttonStyle(.plain)
//                    
//                    Button {
//                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
//                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
//                            activity.isCompleted = true
//                            activity.isSkipped = false
//                            try? modelContext.save()
//                            healthRefreshID = UUID()
//                        }
//                    } label: {
//                        HStack {
//                            Image(systemName: "checkmark.circle.fill")
//                            Text("Confirm")
//                        }
//                        .font(.system(size: 13, weight: .bold))
//                        .foregroundStyle(.black)
//                        .frame(maxWidth: .infinity).frame(height: 40)
//                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange))
//                    }
//                    .buttonStyle(.plain)
//                }
//                .padding(.top, 4)
//            }
//            .padding(16)
//            .background(LinearGradient(colors: [cardColor.opacity(0.05), elevatedCard.opacity(0.95), cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing))
//            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
//            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(cardColor.opacity(0.12), lineWidth: 1))
//            .shadow(color: softShadow.opacity(0.4), radius: 15, y: 8)
//            
//        } else {
//            let cardColor = liveActivity != nil ? Color(red: 0.16, green: 0.80, blue: 0.43) : WeekFitTheme.purple
//            let cardIcon = liveActivity != nil ? (liveActivity?.type.lowercased() == "meal" ? "fork.knife" : "play.fill") : "arrow.triangle.2.circlepath"
//            let cardTitle = liveActivity != nil ? "\(liveActivity!.title) is active" : "Metabolism calibrated"
//            
//            let cardMessage = liveActivity != nil
//                ? (liveActivity?.type.lowercased() == "meal"
//                    ? "Time for clean macro refueling. Enjoy your food, slow down, and take your time. I'll automatically balance your targets once you finish."
//                    : "Your session is currently in progress. Focus entirely on your breathing, pace, and form. I'm already calculating your post-workout recovery plan.")
//                : "Your training slot is safely closed. No stress—your body needed extra rest today. I've already adjusted your evening macros to match a lighter active state."
//            
//            let pillTitle1 = liveActivity != nil ? (liveActivity?.type.lowercased() == "meal" ? "Refuel" : "Session") : "Intensity"
//            let pillSubtitle1 = liveActivity != nil ? "active" : "rest mode"
//            let pillIcon1 = liveActivity != nil ? (liveActivity?.type.lowercased() == "meal" ? "fork.knife" : "figure.cross-training") : "moon.fill"
//            
//            VStack(alignment: .leading, spacing: 14) {
//                HStack(alignment: .top, spacing: 12) {
//                    ZStack {
//                        Circle().fill(cardColor.opacity(0.12)).frame(width: 40, height: 40)
//                        Image(systemName: cardIcon).font(.system(size: 14, weight: .bold)).foregroundStyle(cardColor)
//                    }
//                    
//                    VStack(alignment: .leading, spacing: 2) {
//                        Text(cardTitle).font(.system(size: 15, weight: .bold)).foregroundStyle(textPrimary)
//                        Text(liveActivity != nil ? "In Progress" : "Calibrated").font(.system(size: 12, weight: .medium)).foregroundStyle(textSecondary)
//                    }
//                    Spacer()
//                }
//                
//                Text(cardMessage).font(.system(size: 13, weight: .medium)).foregroundStyle(textSecondary).lineSpacing(3)
//                
//                HStack(spacing: 8) {
//                    HStack(spacing: 8) {
//                        ZStack {
//                            Circle().fill(cardColor.opacity(0.12)).frame(width: 28, height: 28)
//                            Image(systemName: pillIcon1).font(.system(size: 11, weight: .bold)).foregroundColor(cardColor)
//                        }
//                        VStack(alignment: .leading, spacing: 0) {
//                            Text(pillTitle1).font(.system(size: 12, weight: .bold)).foregroundStyle(textPrimary)
//                            Text(pillSubtitle1).font(.system(size: 10, weight: .medium)).foregroundStyle(textTertiary)
//                        }
//                        Spacer()
//                    }
//                    .padding(.horizontal, 10).frame(maxWidth: .infinity).frame(height: 44)
//                    .background(RoundedRectangle(cornerRadius: 16).fill(cardColor.opacity(0.04)))
//                    
//                    HStack(spacing: 8) {
//                        ZStack {
//                            Circle().fill(Color(red: 0.16, green: 0.80, blue: 0.43).opacity(0.12)).frame(width: 28, height: 28)
//                            Image(systemName: "figure.walk").font(.system(size: 12)).foregroundColor(Color(red: 0.16, green: 0.80, blue: 0.43))
//                        }
//                        VStack(alignment: .leading, spacing: 0) {
//                            Text("Recovery").font(.system(size: 12, weight: .bold)).foregroundStyle(textPrimary)
//                            Text("active").font(.system(size: 10, weight: .medium)).foregroundStyle(textTertiary)
//                        }
//                        Spacer()
//                    }
//                    .padding(.horizontal, 10).frame(maxWidth: .infinity).frame(height: 44)
//                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(red: 0.16, green: 0.80, blue: 0.43).opacity(0.04)))
//                }
//            }
//            .padding(16)
//            .background(LinearGradient(colors: [cardColor.opacity(0.05), elevatedCard.opacity(0.95), cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing))
//            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
//            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(cardColor.opacity(0.12), lineWidth: 1))
//            .shadow(color: softShadow.opacity(0.4), radius: 15, y: 8)
//        }
//    }
//    
//    private var recommendedFoodSection: some View {
//        let items = fastFuelItems
//        
//        return VStack(alignment: .leading, spacing: 10) {
//            HStack(alignment: .center) {
//                Text("Recommended now")
//                    .font(.system(size: 17.4, weight: .bold))
//                    .foregroundStyle(textPrimary)
//                    .tracking(-0.28)
//
//                Spacer()
//
//                Text("adaptive")
//                    .font(.system(size: 10.6, weight: .bold))
//                    .foregroundStyle(coachColor.opacity(0.84))
//                    .padding(.horizontal, 9)
//                    .frame(height: 22)
//                    .background(coachColor.opacity(0.085))
//                    .clipShape(Capsule())
//            }
//
//            HStack(spacing: 8) {
//                // ИСПРАВЛЕНО: Заменили id на \.title (или \.id если добавил), чтобы SwiftUI не путал ночные дубликаты
//                ForEach(items.prefix(4), id: \.title) { item in
//                    foodItemWidget(
//                        img: item.imageName,
//                        title: item.title,
//                        amount: item.amount,
//                        actionType: determineFastLogType(from: item.tags)
//                    )
//                }
//            }
//        }
//    }
//    
//    private func foodItemWidget(img: String, title: String, amount: String, actionType: FastLogType) -> some View {
//        Button {
//            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
//            withAnimation(.spring()) {
//                switch actionType {
//                case .water:
//                    nutritionViewModel.addWater(0.5)
//                case .shake:
//                    nutritionViewModel.addCustomProteinShake(context: modelContext)
//                case .carbs:
//                    nutritionViewModel.addCustomCarbSnack(context: modelContext)
//                }
//                waterLoggedToast = true
//            }
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                withAnimation {
//                    waterLoggedToast = false
//                }
//            }
//        } label: {
//            // ИСПРАВЛЕНО: Полностью восстановили дизайн и верстку карточки продукта, убрав пустоту!
//            VStack(spacing: 3) {
//                Image(img)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 38, height: 38)
//                    .padding(.top, 8)
//                    .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
//                
//                Spacer(minLength: 0)
//                
//                Text(title)
//                    .font(.system(size: 11, weight: .bold))
//                    .foregroundStyle(textPrimary)
//                    .lineLimit(1)
//                    .minimumScaleFactor(0.8)
//                    .padding(.horizontal, 4)
//                
//                Text(amount)
//                    .font(.system(size: 9.5, weight: .semibold))
//                    .foregroundStyle(textTertiary.opacity(0.7))
//                    .padding(.bottom, 8)
//            }
//            .frame(maxWidth: .infinity)
//            .frame(height: 92) // Идеальный гайдлайн высоты WeekFit карусели
//            .background(cardSecondary.opacity(0.35))
//            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
//            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.025), lineWidth: 1))
//        }
//        .buttonStyle(.plain)
//    }
//    
//    private var aiDayAnalyticsSection: some View {
//        let activeInsights = nutritionViewModel.nutritionResult?.activeInsights ?? []
//        
//        return VStack(alignment: .leading, spacing: 10) {
//            HStack {
//                Text("Daily Analytics")
//                    .font(.system(size: 16, weight: .bold))
//                    .foregroundStyle(textPrimary)
//                    .tracking(-0.3)
//                Spacer()
//                Text("Insights")
//                    .font(.system(size: 10, weight: .bold))
//                    .foregroundStyle(Color(red: 0.16, green: 0.80, blue: 0.43))
//                    .padding(.horizontal, 8)
//                    .frame(height: 20)
//                    .background(Color(red: 0.16, green: 0.80, blue: 0.43).opacity(0.08))
//                    .clipShape(Capsule())
//            }
//            .padding(.horizontal, 2)
//            
//            VStack(spacing: 2) {
//                if activeInsights.isEmpty {
//                    HStack {
//                        Spacer()
//                        Text("No analytical updates yet. Log data to track metrics.")
//                            .font(.system(size: 12, weight: .medium))
//                            .foregroundColor(textTertiary)
//                            .multilineTextAlignment(.center)
//                            .padding(.vertical, 20)
//                        Spacer()
//                    }
//                } else {
//                    ForEach(activeInsights) { insight in
//                        insightTextRow(
//                            icon: insight.icon,
//                            title: insight.title,
//                            text: insight.text,
//                            color: insight.color,
//                            actionLabel: insight.actionLabel
//                        )
//                    }
//                }
//            }
//        }
//        .padding(12)
//        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(cardBackground.opacity(0.4)))
//        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.02), lineWidth: 1))
//    }
//    
//    private func insightTextRow(icon: String, title: String, text: String, color: Color, actionLabel: String) -> some View {
//        HStack(alignment: .top, spacing: 10) {
//            ZStack {
//                Circle().fill(color.opacity(0.06)).frame(width: 28, height: 28)
//                Image(systemName: icon)
//                    .font(.system(size: 11, weight: .bold))
//                    .foregroundColor(color)
//            }
//            .padding(.top, 2)
//            
//            VStack(alignment: .leading, spacing: 3) {
//                HStack(alignment: .center) {
//                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(textPrimary)
//                    Spacer()
//                    
//                    Button {
//                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                        withAnimation {
//                            if actionLabel == "+500ml" { nutritionViewModel.addWater(0.5) }
//                            waterLoggedToast = true
//                        }
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
//                            withAnimation {
//                                waterLoggedToast = false
//                            }
//                        }
//                    } label: {
//                        Text(actionLabel)
//                            .font(.system(size: 9.5, weight: .bold))
//                            .foregroundStyle(color)
//                            .padding(.horizontal, 8)
//                            .frame(height: 20)
//                            .background(color.opacity(0.10))
//                            .clipShape(Capsule())
//                    }
//                }
//                
//                Text(text)
//                    .font(.system(size: 11.5, weight: .regular))
//                    .foregroundStyle(textSecondary.opacity(0.9))
//                    .lineSpacing(2)
//                    .fixedSize(horizontal: false, vertical: true)
//            }
//        }
//        .padding(.vertical, 6)
//        .padding(.horizontal, 4)
//    }
//    
//    private func refreshCoachDataAsync() async {
//        guard healthManager.isHealthAccessGranted else { return }
//        
//        await healthManager.loadHealthData(for: selectedDate, plannedActivities: plannedActivitiesForSelectedDate)
//        
//        let metrics = DailyNutritionMetrics(
//            protein: currentProtein,
//            carbs: currentCarbs,
//            fats: nutritionViewModel.currentMetrics?.fats ?? 0,
//            calories: currentCalories,
//            waterLiters: currentWater,
//            activeCalories: healthManager.activeCalories,
//            sleepHours: healthManager.sleepHours,
//            weightKg: healthManager.weight
//        )
//        
//        let profile = UserNutritionProfile.createAutomatic(
//            weightKg: healthManager.weight,
//            heightCm: healthManager.heightCm,
//            age: healthManager.age,
//            sex: healthManager.biologicalSex == .male ? .male : .female
//        )
//        
//        nutritionViewModel.updateNutrition(
//            metrics: metrics,
//            profile: profile,
//            plannedActivities: plannedActivitiesForSelectedDate
//        )
//    }
//    
//    private var plannedActivitiesForSelectedDate: [PlannedActivity] {
//        plannedActivities.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
//    }
//    
//    private var selectedDateTitle: String {
//        let formatter = DateFormatter()
//        formatter.locale = Locale(identifier: "en_US")
//        formatter.dateFormat = "EEEE, MMMM d"
//        return formatter.string(from: selectedDate)
//    }
//    
//    private func determineFastLogType(from tags: Set<FastFuelItem.ProductTag>) -> FastLogType {
//        if tags.contains(.hydration) { return .water }
//        if tags.contains(.fastProtein) || tags.contains(.slowProtein) { return .shake }
//        return .carbs
//    }
//}
//
//// MARK: - 🗺 Fast Log Action Strategy Classifications
//enum FastLogType {
//    case water
//    case shake
//    case carbs
//}
