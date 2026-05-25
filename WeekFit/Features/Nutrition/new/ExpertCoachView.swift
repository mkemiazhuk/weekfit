import SwiftUI
import SwiftData
import HealthKit
internal import Combine

struct ExpertCoachView: View {

    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var appSession: AppSessionState
    @Environment(\.modelContext) private var modelContext

    @AppStorage(ProfileService.Keys.initials)
    private var profileInitials: String = "P"

    @State private var showProfile = false
    @State private var showContent = false
    @State private var selectedDate = Date()
    @State private var healthRefreshID = UUID()

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    private let background = WeekFitTheme.background
    private let cardBackground = WeekFitTheme.cardBackground
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let green = WeekFitTheme.meal

    var body: some View {
        ZStack(alignment: .top) {
            background.ignoresSafeArea()
            ambientBackground

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    heroHeaderSection
                        .padding(.top, 8)

                    coachCard

                    recommendedNowSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 110)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 6)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                showContent = true
            }
        }
        .task(id: healthRefreshID) {
            await refreshCoachDataAsync()
        }
        .onChange(of: appSession.healthRefreshTrigger) { _, _ in
            healthRefreshID = UUID()
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
            .environmentObject(healthManager)
            .environmentObject(nutritionViewModel)
            .environmentObject(appSession)
            .presentationDetents([.large])
            .presentationCornerRadius(36)
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - CoreEngine Insight Binding (🚀 ПОЛНОСТЬЮ СИНХРОНИЗИРОВАНО С TODAY)

    private var primaryInsight: DynamicInsight? {
        nutritionViewModel.nutritionResult?.activeInsights.first
    }

    // Внедряем сквозной расчет решения ИИ на лету для обхода застрявшего кэша
    private var liveDecision: CoachDecision {
        guard let res = nutritionViewModel.nutritionResult else {
            return CoachDecision(primaryStrategy: .maintain, secondaryPriorities: [], suppressedActions: [], hydrationAlreadySolved: false, needsElectrolytesInsteadOfWater: false)
        }
        return CoachDecisionEngine.makeDecision(from: res.brain)
    }

    private var coachAccentColor: Color {
        switch liveDecision.primaryStrategy {
        case .overload:
            return .orange
        case .supercompensation, .protectRecovery:
            return .indigo // Родной цвет суперкомпенсации мышц
        default:
            return primaryInsight?.color ?? green
        }
    }

    private var coachIcon: String {
        switch liveDecision.primaryStrategy {
        case .overload:
            return "exclamationmark.shield.fill"
        case .supercompensation:
            return "flame.circle.fill"
        case .protectRecovery:
            return "heart.text.square.fill"
        default:
            return primaryInsight?.icon ?? "sparkles"
        }
    }

    private var coachLabel: String {
        switch liveDecision.primaryStrategy {
        case .overload:           return "ENERGY OVERLOAD"
        case .supercompensation:  return "SUPERCOMPENSATION"
        case .protectRecovery:    return "RECOVERY FOCUS"
        case .logFood:            return "LOG INTAKE"
        default:                  return primaryInsight?.actionLabel.uppercased() ?? "TODAY'S GUIDANCE"
        }
    }

    private var heroTitle: String {
        switch liveDecision.primaryStrategy {
        case .overload:           return "Energy Overload Detected"
        case .supercompensation:  return "High Metabolic Strain"
        case .protectRecovery:    return "Recovery Focus Required"
        default:
            guard let result = nutritionViewModel.nutritionResult else {
                return "Keep your day balanced and steady."
            }
            return cleanTitle(result.status)
        }
    }

    private var heroMessage: String {
        guard let result = nutritionViewModel.nutritionResult else {
            return "Stay consistent with food, water and movement today."
        }
        // Передаем сквозное liveDecision в генератор копирайта, закрывая проблему рассинхрона текстов
        let upToDateSummary = CoachCopy.summary(brain: result.brain, decision: liveDecision, complianceScore: result.score)
        return compactMessage(upToDateSummary)
    }

    private func cleanTitle(_ title: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: "Great Workout! ", with: "")
            .replacingOccurrences(of: "Perfect Balance! ", with: "")
            .replacingOccurrences(of: "Short Sleep: ", with: "")
            .replacingOccurrences(of: "Evening Wind Down: ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.count > 42 {
            return String(cleaned.prefix(42)).trimmingCharacters(in: .whitespacesAndNewlines) + "."
        }

        return cleaned
    }

    private func compactMessage(_ text: String) -> String {
        let sentences = text
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let firstTwo = sentences.prefix(2).joined(separator: ". ")

        if firstTwo.count <= 180 {
            return firstTwo.hasSuffix(".") ? firstTwo : firstTwo + "."
        }

        return String(firstTwo.prefix(180)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    // MARK: - Background

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [
                    coachAccentColor.opacity(0.04),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    WeekFitTheme.purple.opacity(0.03),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 80,
                endRadius: 520
            )
        }
        .blur(radius: 30)
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var heroHeaderSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Coach")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.75)

                Text(selectedDateTitle)
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.76))
            }

            Spacer()

            avatarButton
        }
    }
    
    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: selectedDate)
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
                    .stroke(green.opacity(0.34), lineWidth: 2)

                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .padding(5)

                Text(profileInitials)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
            }
            .frame(width: 48, height: 48)
            .shadow(color: green.opacity(0.08), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Coach Card

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            stateBadge

            VStack(alignment: .leading, spacing: 10) {
                Text(heroTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.7)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text(heroMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.84))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("Focus on")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(coachAccentColor)

                VStack(spacing: 0) {
                    ForEach(Array(focusRows.prefix(2).enumerated()), id: \.element.id) { index, item in
                        focusRow(item)

                        if index < 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.04))
                                .frame(height: 1)
                                .padding(.leading, 42)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardBackground.opacity(0.52),
                            cardBackground.opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(coachAccentColor.opacity(0.10), lineWidth: 1)
                )
        )
        .shadow(color: coachAccentColor.opacity(0.035), radius: 18, y: 8)
    }

    private var stateBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: coachIcon)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(coachAccentColor)

            Text(coachLabel)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(coachAccentColor)
        }
        .padding(.horizontal, 11)
        .frame(height: 28)
        .background(
            Capsule()
                .fill(coachAccentColor.opacity(0.09))
                .overlay(
                    Capsule()
                        .stroke(coachAccentColor.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Focus Logic

    private struct CoachFocusItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let color: Color
    }

    private var focusRows: [CoachFocusItem] {
        guard let result = nutritionViewModel.nutritionResult else {
            return [.init(icon: "sparkles", title: "Stay consistent", subtitle: "Keep routine", color: green)]
        }

        // 🚀 ИСПРАВЛЕНО: Фокусы теперь собираются на основе вычисленной ИИ-стратегии,
        // а не по сырому флагу overfueled. Защита от перебора белка активна!
        if liveDecision.primaryStrategy == .overload {
            return [
                .init(icon: "drop.fill", title: "Pure Hydration", subtitle: "Flush metabolic excess", color: .blue),
                .init(icon: "moon.fill", title: "Digestive Rest", subtitle: "Zero heavy food load", color: WeekFitTheme.purple)
            ]
        }

        var items: [CoachFocusItem] = []

        func add(_ item: CoachFocusItem) {
            guard !items.contains(where: { $0.title == item.title }) else { return }
            items.append(item)
        }

        // Синхронный маппинг из динамических инсайтов нашей ИИ-фабрики
        let dynamicInsights = CoachInsightFactory.generateInsights(brain: result.brain, decision: liveDecision)

        for insight in dynamicInsights {
            if insight.tags.contains(.protein) {
                add(.init(icon: "fork.knife", title: "Protein", subtitle: "Support repair", color: green))
            }
            if insight.tags.contains(.hydration) {
                add(.init(icon: "drop.fill", title: "Hydration", subtitle: "Hydration covered", color: .blue))
            }
            if insight.tags.contains(.minerals) {
                add(.init(icon: "sparkles", title: "Minerals", subtitle: "Instead of more water", color: .blue))
            }
            if insight.tags.contains(.recovery) {
                add(.init(icon: "heart.fill", title: "Recovery", subtitle: "Maximize compensation", color: WeekFitTheme.purple))
            }
            if insight.tags.contains(.carbs) {
                add(.init(icon: "bolt.fill", title: "Fuel steady", subtitle: "Easy energy", color: .orange))
            }
            if insight.tags.contains(.sleep) {
                add(.init(icon: "moon.fill", title: "Earlier sleep", subtitle: "Protect recovery", color: WeekFitTheme.purple))
            }
        }

        if items.isEmpty {
            add(.init(icon: "sparkles", title: "Stay consistent", subtitle: "Keep routine", color: green))
        }

        return items
    }

    private func focusRow(_ item: CoachFocusItem) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.12))
                    .frame(width: 30, height: 30)

                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(item.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(item.subtitle)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.72))
            }

            Spacer()
        }
        .frame(height: 50)
    }

    // MARK: - FastFuel Recommendations

    private var recommendedNowItems: [FastFuelItem] {
        let result = nutritionViewModel.nutritionResult

        return FastFuelSuggestionService().generate(
            currentWater: nutritionViewModel.totalWaterLiters,
            waterGoal: result?.goals.waterLiters ?? 3.0,
            currentProtein: nutritionViewModel.currentMetrics?.protein ?? 0,
            proteinGoal: result?.goals.protein ?? 140,
            currentCarbs: nutritionViewModel.currentMetrics?.carbs ?? 0,
            carbsGoal: result?.goals.carbs ?? 220,
            sleepHours: healthManager.sleepHours,
            activeCalories: healthManager.activeCalories,
            plannedActivities: plannedActivitiesForSelectedDate,
            selectedDate: selectedDate,
            primaryInsight: primaryInsight,
            brain: result?.brain,
            decision: liveDecision // 🚀 Передаем актуальное решение
        )
    }

    private var recommendedNowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recommended now")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text("Quick support based on your current state.")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.70))
            }

            VStack(spacing: 8) {
                ForEach(Array(recommendedNowItems.prefix(3).enumerated()), id: \.offset) { _, item in
                    fastFuelRow(item)
                }
            }
        }
    }

    private func fastFuelRow(_ item: FastFuelItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.035))
                    .frame(width: 42, height: 42)

                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(item.reason)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.72))
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    nutritionViewModel.addCoachRecommendationToPlan(item: item, context: modelContext)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(WeekFitTheme.purple)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(WeekFitTheme.purple.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardBackground.opacity(0.42),
                            cardBackground.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    // MARK: - Refresh

    private func refreshCoachDataAsync() async {
        guard healthManager.isHealthAccessGranted else { return }

        await healthManager.loadHealthData(
            for: selectedDate,
            plannedActivities: plannedActivitiesForSelectedDate
        )

        let metrics = DailyNutritionMetrics(
            protein: nutritionViewModel.currentMetrics?.protein ?? 0,
            carbs: nutritionViewModel.currentMetrics?.carbs ?? 0,
            fats: nutritionViewModel.currentMetrics?.fats ?? 0,
            calories: nutritionViewModel.currentMetrics?.calories ?? 0,
            waterLiters: nutritionViewModel.currentMetrics?.waterLiters ?? 0,
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
            plannedActivities: plannedActivitiesForSelectedDate
        )
    }

    private var plannedActivitiesForSelectedDate: [PlannedActivity] {
        get {
            plannedActivities.filter {
                Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
            }
        }
    }
}
