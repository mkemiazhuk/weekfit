import SwiftUI
import SwiftData
import HealthKit
internal import Combine

struct ExpertCoachViewV3: View {

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
    @State private var coachRefreshID = UUID()
    @State private var pendingCoachRefreshSources: [String] = []
    @State private var pendingHealthRefreshSources: [String] = []
    @State private var isCoachRefreshScheduled = false
    @State private var isHealthRefreshScheduled = false
    @State private var lastAppliedCoachRefreshSignature = ""
    @State private var cachedCoachGuidance: CoachGuidanceV3?

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    private let background = WeekFitTheme.backgroundColor
    private let cardBackground = WeekFitTheme.cardBackground
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let green = WeekFitTheme.meal
    
    @State private var pendingFuelItem: FastFuelItem?

    var body: some View {
        ZStack(alignment: .top) {
            WeekFitTheme.appBackground
                .ignoresSafeArea()

            ambientBackground

            WeekFitScreenContainer {

                WeekFitScreenHeader(
                    title: "Coach",
                    subtitle: selectedDateTitle,
                    initials: profileInitials,
                    showAvatar: true
                ) {
                    showProfile = true
                }

            } content: {
                coachContent
            }
            .opacity(showContent ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                showContent = true
            }
            regenerateCoachRefreshID(source: "ExpertCoachViewV3.onAppear")
        }
        .task(id: healthRefreshID) {
            await refreshCoachDataAsync()
        }
        .onChange(of: plannedActivities) { _, _ in
            #if DEBUG
            CoachRefreshDebug.log(
                "[CoachRefreshOnChange]",
                "ExpertCoachViewV3.plannedActivities changed count=\(plannedActivities.count) selectedDayCount=\(plannedActivitiesForSelectedDate.count) source=SwiftDataQuery"
            )
            #endif
            refreshCoachLiveState(refreshHealth: false, source: "ExpertCoachViewV3.onChange.plannedActivities")
        }
        .onChange(of: appSession.healthRefreshTrigger) { oldValue, newValue in
            #if DEBUG
            CoachRefreshDebug.log(
                "[CoachRefreshOnChange]",
                "ExpertCoachViewV3.appSession.healthRefreshTrigger \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newValue))"
            )
            #endif
            regenerateHealthRefreshID(source: "ExpertCoachViewV3.onChange.appSession.healthRefreshTrigger")
        }
        .onChange(of: appSession.coachRefreshTrigger) { oldValue, newValue in
            #if DEBUG
            CoachRefreshDebug.log(
                "[CoachRefreshOnChange]",
                "ExpertCoachViewV3.appSession.coachRefreshTrigger \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newValue)) \(debugHydrationSummary()) before=\(debugCoachPrioritySummary())"
            )
            #endif
            regenerateCoachRefreshID(source: "ExpertCoachViewV3.onChange.appSession.coachRefreshTrigger")
        }
        .onReceive(nutritionViewModel.$currentMetrics) { metrics in
            #if DEBUG
            let current = metrics?.waterLiters ?? -1
            let goal = nutritionViewModel.nutritionResult?.goals.waterLiters ?? 0
            CoachRefreshDebug.log(
                "[CoachRefreshOnChange]",
                "ExpertCoachViewV3.currentMetrics received \(CoachRefreshDebug.hydrationSummary(current: current, goal: goal)) before=\(debugCoachPrioritySummary())"
            )
            #endif
            regenerateCoachRefreshID(source: "ExpertCoachViewV3.onReceive.currentMetrics")
        }
        .onChange(of: nutritionViewModel.coachStateRefreshID) { oldValue, newValue in
            #if DEBUG
            CoachRefreshDebug.log(
                "[CoachRefreshOnChange]",
                "ExpertCoachViewV3.nutritionViewModel.coachStateRefreshID \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newValue)) \(debugHydrationSummary()) before=\(debugCoachPrioritySummary())"
            )
            #endif
            regenerateCoachRefreshID(source: "ExpertCoachViewV3.onChange.nutritionCoachStateRefreshID")
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


    // MARK: - Coach V3 Binding
    
    private var dayContext: CoachDayContext {
        CoachDayContextBuilder.build(
            activities: plannedActivitiesForSelectedDate,
            selectedDate: selectedDate,
            now: Date()
        )
    }

    private var guidance: CoachGuidanceV3 {
        let _ = coachRefreshID
        return cachedCoachGuidance ?? fallbackGuidance
    }


    private var coachScenario: CoachActivityScenario {
        guard let brain = nutritionViewModel.nutritionResult?.brain else {
            return fallbackCoachScenario
        }

        return CoachActivityScenarioResolver.resolve(
            phase: effectiveCoachPhase,
            brain: brain
        )
    }

    private var coachRule: CoachScenarioRule {
        guard let brain = nutritionViewModel.nutritionResult?.brain else {
            return fallbackCoachRule
        }

        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: effectiveCoachPhase
        )

        return CoachScenarioRuleEngine.resolve(
            scenario: coachScenario,
            dayContext: dayContext,
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: Int(healthManager.recoveryPercent),
                sleepHours: healthManager.sleepHours
            ),
            nutritionContext: nutritionContext,
            readiness: readiness,
            brain: brain
        )
    }

    private var fallbackCoachScenario: CoachActivityScenario {
        CoachActivityScenario(
            stage: .stable,
            archetype: .stable,
            kind: .other,
            load: .low,
            durationBucket: .under30,
            dayTime: coachDayTime(from: Calendar.current.component(.hour, from: Date())),
            activity: nil,
            minutesUntilStart: nil,
            minutesSinceEnd: nil
        )
    }

    private var fallbackCoachRule: CoachScenarioRule {
        let stable = CoachActivityContextResolverV3.stablePresentation(from: coachDayContext)
        return CoachScenarioRule(
            stateLabel: "OVERVIEW",
            title: stable.title,
            message: stable.message,
            supportFocus: [
                "Keep rhythm",
                "Avoid unnecessary intensity",
                "Follow the plan"
            ],
            supportActions: [],
            avoidNotes: []
        )
    }

    private var coachAccentColor: Color {
        coachScreenStory.color
    }

    private var coachIcon: String {
        coachScreenStory.icon
    }

    private var coachScreenStory: CoachScreenStory {
        if let story = guidance.screenStory {
            return story
        }

        let fallbackDecision = HumanCoachDecision(
            status: .goodToGo,
            title: fallbackGuidance.title,
            myRead: fallbackGuidance.message,
            myRecommendation: "Keep the next step simple.",
            beCarefulWith: "Turning a normal day into something to fix.",
            why: nil,
            planChallenge: nil,
            supportingActions: [
                CoachSupportingAction(
                    type: .stayConsistent,
                    icon: "waveform.path.ecg",
                    title: "Keep rhythm",
                    subtitle: "Stay consistent with food, water, and movement",
                    color: CoachPalette.stable
                )
            ],
            priority: .supporting,
            sourceSignals: [],
            v5Contract: nil,
            narrativePlan: nil
        )

        return CoachScreenStory(
            decision: fallbackDecision,
            phase: fallbackGuidance.phase,
            icon: fallbackGuidance.icon,
            color: fallbackGuidance.color,
            tone: fallbackGuidance.tone
        )
    }

    private var coachRenderedTitle: String {
        validTitle(guidance.title) ?? coachScreenStory.title
    }

    private func validTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var fallbackGuidance: CoachGuidanceV3 {
        CoachGuidanceV3(
            phase: .stable,
            opportunity: CoachSupportOpportunityV3(
                type: .stable,
                importance: .quiet,
                reason: "No active guidance."
            ),
            shouldSurface: false,
            stateLabel: "OVERVIEW",
            title: "No active focus right now",
            message: CoachActivityContextResolverV3.stablePresentation(from: coachDayContext).message,
            insightTitle: CoachActivityContextResolverV3.stablePresentation(from: coachDayContext).title,
            insightSubtitle: nil,
            supportActions: [
                CoachSupportActionV3(
                    type: .stayConsistent,
                    icon: "waveform.path.ecg",
                    title: "Keep rhythm",
                    subtitle: "Stay consistent with food, water and movement",
                    color: CoachPalette.stable
                )
            ],
            avoidNotes: [],
            icon: "waveform.path.ecg.rectangle.fill",
            color: green,
            importance: .quiet,
            tone: .calm
        )
    }

    // MARK: - Background

    private var ambientBackground: some View {
        WeekFitTheme.coachAmbient
            .blur(radius: 30)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    private func coachDayTime(from hour: Int) -> CoachDayTime {
        switch hour {
        case 5..<10:
            return .morning
        case 10..<12:
            return .preLunch
        case 12..<14:
            return .lunch
        case 14..<18:
            return .afternoon
        case 18..<21:
            return .evening
        case 21..<24:
            return .lateEvening
        default:
            return .night
        }
    }

    private var selectedDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Coach Card

    private var coachCard: some View {
        let story = coachScreenStory

        return ZStack(alignment: .topTrailing) {
            Image(systemName: coachIcon)
                .font(.system(size: 68, weight: .regular))
                .foregroundStyle(coachAccentColor.opacity(0.025))
                .padding(.top, 18)
                .padding(.trailing, 18)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                stateBadge

                VStack(alignment: .leading, spacing: 12) {
                    Text(coachRenderedTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.8)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        coachHeroTextBlock(
                            label: "My Read",
                            text: story.myRead
                        )

                        coachHeroTextBlock(
                            label: "My Recommendation",
                            text: story.myRecommendation
                        )

                        if story.shouldShowBeCarefulWith {
                            coachHeroTextBlock(
                                label: "Be Careful With",
                                text: story.beCarefulWith
                            )
                        }
                    }
                }
                .padding(.top, 14)
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            coachAccentColor.opacity(0.075),
                            cardBackground.opacity(0.52),
                            cardBackground.opacity(0.30)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    coachAccentColor.opacity(0.12),
                                    Color.white.opacity(0.035)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: coachAccentColor.opacity(0.055), radius: 18, y: 8)
        .shadow(color: Color.black.opacity(0.18), radius: 14, y: 7)
    }

    private func coachHeroTextBlock(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .black, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(coachAccentColor.opacity(0.82))

            Text(text)
                .font(.system(size: 13.4, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.76))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stateBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: coachIcon)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(coachAccentColor)

            Text(coachDisplayStateLabel)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(coachAccentColor)
        }
        .padding(.horizontal, 11)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(coachAccentColor.opacity(0.09))
                .overlay(
                    Capsule()
                        .stroke(coachAccentColor.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Today Balance

    private struct TodayBalanceItem: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        let color: Color
        let isGood: Bool
    }
    
    private func expectedHydrationProgress(hour: Int) -> Double {

        switch hour {
        case 5..<9:
            return 0.15

        case 9..<12:
            return 0.35

        case 12..<15:
            return 0.55

        case 15..<18:
            return 0.70

        case 18..<21:
            return 0.85

        default:
            return 1.0
        }
    }

    private var todayBalanceItems: [TodayBalanceItem] {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)

        let waterGoal = nutritionViewModel.nutritionResult?.goals.waterLiters ?? 3.0
        let currentWater = nutritionViewModel.totalWaterLiters
        
        let waterRatio = waterGoal > 0 ? currentWater / waterGoal : 0
        let expectedRatio = expectedHydrationProgress(hour: hour)

        let hydrationGood =
            waterRatio >= expectedRatio * 0.9
        
        let waterRemaining = max(0, waterGoal - currentWater)

        let protein = nutritionViewModel.currentMetrics?.protein ?? 0
        let proteinGoal = nutritionViewModel.nutritionResult?.goals.protein ?? 140
        let proteinRatio = proteinGoal > 0 ? protein / proteinGoal : 0
        let proteinRemaining = max(0, proteinGoal - protein)

        let calories = nutritionViewModel.currentMetrics?.calories ?? 0
        let calorieGoal = nutritionViewModel.nutritionResult?.goals.calories ?? 2200
        let calorieRatio = calorieGoal > 0 ? calories / calorieGoal : 0
        let caloriesRemaining = max(0, calorieGoal - calories)

        let fuelingGood = proteinRatio >= 0.65 || calorieRatio >= 0.45

        let recoveryPercent = healthManager.recoveryPercent
        let sleepHours = healthManager.sleepHours
        let hrv = healthManager.hrvSDNN
        let rhr = healthManager.restingHeartRate

        let hasSleepData = sleepHours > 0
        let shortSleep = hasSleepData && sleepHours < 7
        let recoveryGood = recoveryPercent >= 80
        let recoveryOkay = recoveryPercent >= 65
        let recoveryIsGood = recoveryGood || recoveryOkay

        let completedActivities = plannedActivitiesForSelectedDate.filter { $0.isCompleted }.count
        let upcomingActivities = plannedActivitiesForSelectedDate.filter {
            !$0.isCompleted && !$0.isSkipped && $0.date >= now
        }.count

        let nextActivity = plannedActivitiesForSelectedDate
            .filter { !$0.isCompleted && !$0.isSkipped && $0.date >= now }
            .sorted { $0.date < $1.date }
            .first

        let hasActivityToday = !plannedActivitiesForSelectedDate.isEmpty

        let recoverySubtitle: String = {
            if !hasSleepData {
                if recoveryPercent > 0 {
                    return "\(Int(recoveryPercent))% recovery • sleep data missing"
                }
                return "Sleep data missing • recovery limited"
            }

            if recoveryGood && shortSleep {
                return "\(Int(recoveryPercent))% recovery • short sleep had limited impact"
            }

            if recoveryGood {
                return "\(Int(recoveryPercent))% recovery • body looks ready"
            }

            if recoveryOkay && shortSleep {
                return "\(Int(recoveryPercent))% recovery • shorter sleep noted"
            }

            if recoveryPercent < 65 && shortSleep {
                return "\(Int(recoveryPercent))% recovery • sleep is limiting today"
            }

            if hrv > 0 && rhr > 0 {
                return "\(Int(recoveryPercent))% recovery • HRV \(Int(hrv)), RHR \(Int(rhr))"
            }

            return "\(Int(recoveryPercent))% recovery today"
        }()

        let hydrationSubtitle: String = {
            if waterGoal <= 0 {
                return "\(oneDecimal(currentWater))L logged today"
            }

            if currentWater <= 0.01 {
                return "Hydration not started • first target 500ml"
            }

            if hydrationGood {
                return "\(oneDecimal(currentWater))L of \(oneDecimal(waterGoal))L completed"
            }

            if hour < 12 {
                return "\(oneDecimal(currentWater))L logged • keep building the base"
            }

            return "\(oneDecimal(waterRemaining))L remaining to target"
        }()

        let fuelingSubtitle: String = {
            if protein <= 0.5 && calories <= 20 {
                if hour < 12 {
                    return "Breakfast not started • protein first"
                }
                return "No fueling logged • protein first"
            }

            if proteinRatio < 0.65 && calorieRatio < 0.45 {
                return "\(Int(proteinRemaining))g protein • \(Int(caloriesRemaining)) kcal left"
            }

            if proteinRatio < 0.65 {
                return "\(Int(proteinRemaining))g protein remaining"
            }

            if calorieRatio < 0.45 {
                return "\(Int(caloriesRemaining)) kcal remaining today"
            }

            return "\(Int(protein))g of \(Int(proteinGoal))g protein reached"
        }()

        let loadSubtitle: String = {
            if let nextActivity {
                return "\(completedActivities) done • \(nextActivity.title) in \(timeUntil(nextActivity.date))"
            }

            if !hasActivityToday {
                return "Open schedule • recovery remains priority"
            }

            return "\(completedActivities) completed • \(upcomingActivities) upcoming"
        }()

        return [
            TodayBalanceItem(
                id: "recovery",
                icon: recoveryIsGood ? "heart.fill" : "heart.text.square.fill",
                title: "Recovery",
                subtitle: recoverySubtitle,
                color: recoveryIsGood ? CoachPalette.recovery : CoachPalette.warning,
                isGood: recoveryIsGood
            ),

            TodayBalanceItem(
                id: "load",
                icon: hasActivityToday ? "figure.run" : "waveform.path.ecg",
                title: hasActivityToday ? "Activities" : "Daily load",
                subtitle: loadSubtitle,
                color: hasActivityToday ? CoachPalette.training : CoachPalette.stable,
                isGood: true
            )
        ]
    }
    
    private var coachDisplayText: (title: String, message: String) {
        return (
            coachScreenStory.title,
            coachScreenStory.myRecommendation
        )
    }

    private var coachDisplayStateLabel: String {
        coachScreenStory.stateLabel
    }

    private var coachSections: [CoachSection] {
        CoachSectionBuilder.build(
            scenario: coachScenario,
            nutrition: nutritionContext,
            trainingFallback: trainingFocusFallback,
            coachAccentColor: coachAccentColor,
            priority: guidance.priority
        )
    }

    private var trainingFocusFallback: [String] {
        let items = guidance.supportActions
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !items.isEmpty {
            return Array(items.prefix(3))
        }

        let ruleItems = coachRule.supportFocus
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !ruleItems.isEmpty {
            return Array(ruleItems.prefix(3))
        }

        return [
            "Stay steady",
            "Keep the plan simple",
            "Avoid unnecessary intensity"
        ]
    }

    private var premiumAvoidNotes: [String] {

        let whyText = guidance.priority.whyThisMatters?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return guidance.avoidNotes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { note in
                guard let whyText else { return true }
                return note.lowercased() != whyText
            }
    }

    private var shouldSurfaceCoach: Bool {
        ExpertCoachRenderMode.resolve(cachedGuidance: cachedCoachGuidance) == .guidance
    }

    private var coachDayContext: CoachDayActivityContext {
        CoachActivityContextResolverV3.resolveDayContext(
            activities: plannedActivitiesForSelectedDate,
            selectedDate: selectedDate,
            now: Date(),
            brain: nutritionViewModel.nutritionResult?.brain
        )
    }

    private var effectiveCoachPhase: CoachActivityPhaseV3 {
        guidance.phase
    }

    private func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func timeUntil(_ date: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSince(Date()) / 60))

        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainder = minutes % 60

        if remainder == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(remainder)m"
    }
    
    private var coachContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: WeekFitScreenLayout.rootSpacing) {

//                if shouldShowEveningReview {
//                    CoachEveningReviewSection(
//                        summary: eveningReviewSummary,
//                        plan: eveningReviewPlan,
//                        readiness: tomorrowReadiness
//                    )
//                } else
                if shouldSurfaceCoach {
                    coachCard
                    storySupportSection
                } else {
                    todayBalanceSection
                        .padding(.top, 12)
                }
            }
            .padding(.bottom, 110)
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

    private var eveningReviewSummary: CoachEveningReviewSummary {

        let plannerActivities = plannedActivitiesForSelectedDate.filter {
            $0.source == "planner"
        }

        let completedPlannerActivities = plannerActivities.filter {
            $0.isCompleted
        }

        let skippedPlannerActivities = plannerActivities.filter {
            $0.isSkipped
        }

        let completedActivities = plannedActivitiesForSelectedDate.filter {
            $0.isCompleted
        }

        let plannedCount = plannerActivities.count
        let completedCount = completedPlannerActivities.count
        let skippedCount = skippedPlannerActivities.count

        let totalMinutes = completedActivities.reduce(0) { result, activity in
            result + activity.durationMinutes
        }

        let activeTimeText = formatMinutes(totalMinutes)
        let score = eveningReviewScore

        if plannedCount == 0 {
            return CoachEveningReviewSummary(
                title: totalMinutes > 0 ? "Active recovery day" : "Recovery day",
                message: totalMinutes > 0
                    ? "\(activeTimeText) active time"
                    : "No planned activities today",
                achievement: biggestAchievementText,
                score: score
            )
        }

        if completedCount == plannedCount && skippedCount == 0 {
            return CoachEveningReviewSummary(
                title: "Perfect execution",
                message: "\(activeTimeText) active time",
                achievement: biggestAchievementText,
                score: score
            )
        }

        if completedCount > 0 {
            return CoachEveningReviewSummary(
                title: "Solid execution",
                message: "\(activeTimeText) active time",
                achievement: biggestAchievementText,
                score: score
            )
        }

        return CoachEveningReviewSummary(
            title: "Reset tomorrow",
            message: totalMinutes > 0
                ? "\(activeTimeText) active time"
                : "No active time logged",
            achievement: biggestAchievementText,
            score: score
        )
    }
    
    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(minutes)m"
    }

    private var eveningReviewScore: Int {

        let plannerActivities = plannedActivitiesForSelectedDate.filter {
            $0.source == "planner"
        }

        let plannedCount = plannerActivities.count

        let completedCount = plannerActivities.filter {
            $0.isCompleted
        }.count

        // PLAN

        let planScore: Double

        if plannedCount == 0 {
            planScore = 100
        } else {
            planScore = Double(completedCount) / Double(plannedCount) * 100
        }

        // BURN

        let baseTargetCalories: Double =
            nutritionViewModel.nutritionResult?.targetCalories ?? 1743

        let activeCaloriesBurned: Double =
            healthManager.activeCalories

        let burnScore = min(
            100,
            activeCaloriesBurned / max(baseTargetCalories * 0.35, 1) * 100
        )

        // NUTRITION

        let dynamicNutritionTarget: Double =
            baseTargetCalories + activeCaloriesBurned

        let eatenCalories: Double =
            nutritionViewModel.currentMetrics?.calories ?? 0

        let nutritionRatio =
            dynamicNutritionTarget > 0
            ? eatenCalories / dynamicNutritionTarget
            : 1

        let nutritionScore: Double

        switch nutritionRatio {

        case 0.90...1.10:
            nutritionScore = 100

        case 0.80..<0.90, 1.10...1.20:
            nutritionScore = 80

        case 0.70..<0.80, 1.20...1.35:
            nutritionScore = 60

        default:
            nutritionScore = 30
        }

        let score =
            planScore * 0.40 +
            burnScore * 0.35 +
            nutritionScore * 0.25

        return max(0, min(100, Int(score.rounded())))
    }
    
    private var eveningReviewActiveTimeText: String {

        let completedActivities = plannedActivitiesForSelectedDate.filter {
            $0.isCompleted
        }

        let totalMinutes = completedActivities.reduce(0) { result, activity in
            result + activity.durationMinutes
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(minutes)m"
    }

    private var tomorrowReadiness: CoachTomorrowReadiness {
        let completed = plannedActivitiesForSelectedDate.filter { $0.isCompleted }

        let totalMinutes = completed.reduce(0) { result, activity in
            result + activity.durationMinutes
        }

        let recovery = healthManager.recoveryPercent

        let longest = completed.max {
            $0.durationMinutes < $1.durationMinutes
        }

        let longestTitle = longest?.title ?? "Activity"
        let longestDuration = longest.map { formatMinutes($0.effectiveDurationMinutes) } ?? "0m"

        let hasLongSession = longest?.durationMinutes ?? 0 >= 120
        let hasVeryHighVolume = totalMinutes >= 240
        let hasHighVolume = totalMinutes >= 150

        let recoveryActivities = completed.filter { activity in
            let text = "\(activity.type) \(activity.title)".lowercased()

            return text.contains("sauna")
                || text.contains("stretch")
                || text.contains("mobility")
                || text.contains("recovery")
                || text.contains("walk")
                || text.contains("walking")
                || text.contains("yoga")
        }

        let hasRecoverySupport = !recoveryActivities.isEmpty

        let loadLabel: String = {
            if hasVeryHighVolume || hasLongSession {
                return "High load"
            }

            if hasHighVolume {
                return "Moderate load"
            }

            return "Balanced load"
        }()

        let metricsLine: String = {
            if let longest {
                return "Recovery \(Int(recovery))% • \(longest.title) \(formatMinutes(longest.effectiveDurationMinutes))"
            }

            return "Recovery \(Int(recovery))% • \(loadLabel)"
        }()

        if recovery < 55 {
            return CoachTomorrowReadiness(
                title: "Recovery day recommended",
                metrics: metricsLine,
                recommendation: "Sleep • Mobility • Easy walk",
                icon: "moon.zzz.fill",
                color: CoachPalette.stress
            )
        }

        if hasVeryHighVolume || hasLongSession {
            if recovery >= 75 {
                return CoachTomorrowReadiness(
                    title: "Keep tomorrow lighter",
                    metrics: "Recovery \(Int(recovery))% • \(longestTitle) \(longestDuration)",
                    recommendation: "Sauna • Mobility • Walk",
                    icon: "figure.cooldown",
                    color: CoachPalette.warning
                )
            } else {
                return CoachTomorrowReadiness(
                    title: "Prioritize recovery tomorrow",
                    metrics: "Recovery \(Int(recovery))% • \(loadLabel)",
                    recommendation: "Sleep • Mobility • Easy walk",
                    icon: "heart.fill",
                    color: CoachPalette.warning
                )
            }
        }

        if hasHighVolume && !hasRecoverySupport {
            return CoachTomorrowReadiness(
                title: "Add recovery support",
                metrics: "Recovery \(Int(recovery))% • \(loadLabel)",
                recommendation: "Sauna • Stretching • Easy walk",
                icon: "sparkles",
                color: CoachPalette.recovery
            )
        }

        if recovery >= 75 {
            return CoachTomorrowReadiness(
                title: "Ready for training",
                metrics: "Recovery \(Int(recovery))% • \(loadLabel)",
                recommendation: "Normal training • Keep intensity planned",
                icon: "checkmark.seal.fill",
                color: CoachPalette.stable
            )
        }

        return CoachTomorrowReadiness(
            title: "Moderate readiness",
            metrics: "Recovery \(Int(recovery))% • \(loadLabel)",
            recommendation: "Flexible plan • Avoid extra intensity",
            icon: "gauge.medium",
            color: CoachPalette.training
        )
    }
    
    private var biggestAchievementText: String {

        let completed = plannedActivitiesForSelectedDate.filter { $0.isCompleted }

        let meaningfulCompleted = completed.filter {
            let type = $0.type.lowercased()
            let title = $0.title.lowercased()

            return type != "meal"
                && $0.imageName != "hydration"
                && !title.contains("water")
                && !title.contains("hydration")
                && $0.durationMinutes >= 20
        }

        if let best = meaningfulCompleted.max(by: {
            achievementScore(for: $0) < achievementScore(for: $1)
        }) {
            return "\(achievementLabel(for: best)) — \(durationText(best.durationMinutes)) completed."
        }

        let planned = plannedActivitiesForSelectedDate.count
        let completedCount = completed.count
        let skippedCount = plannedActivitiesForSelectedDate.filter { $0.isSkipped }.count

        if planned > 0 && completedCount == planned {
            return "You completed everything you planned today."
        }

        if planned > 0 && completedCount + skippedCount == planned {
            return "You closed the day clearly by completing or skipping every planned item."
        }

        let recovery = Int(healthManager.recoveryPercent)
        if recovery >= 80 {
            return "Recovery finished strong at \(recovery)%."
        }

        if completedCount > 0 {
            return "You still completed \(completedCount) planned item\(completedCount == 1 ? "" : "s")."
        }

        return "You closed the day without forcing a late catch-up."
    }

    private func achievementScore(for activity: PlannedActivity) -> Double {
        let title = activity.title.lowercased()
        let type = activity.type.lowercased()

        var score = Double(activity.durationMinutes)

        if type == "workout" {
            score *= 1.6
        }

        if type == "recovery" {
            score *= 1.15
        }

        if title.contains("ride") ||
            title.contains("bike") ||
            title.contains("cycling") ||
            title.contains("run") ||
            title.contains("walk") ||
            title.contains("strength") ||
            title.contains("gym") ||
            title.contains("training") {
            score *= 1.35
        }

        if activity.durationMinutes >= 180 {
            score += 90
        } else if activity.durationMinutes >= 120 {
            score += 60
        } else if activity.durationMinutes >= 60 {
            score += 30
        }

        return score
    }

    private func achievementLabel(for activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Strongest activity" : title
    }

    private func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60

        if hours > 0 && remainder > 0 {
            return "\(hours)h \(remainder)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(minutes)m"
    }

    private var nutritionContext: CoachNutritionContext {
        let goals = nutritionViewModel.nutritionResult?.goals
        let completedMeals = CoachCanonicalDayState.completedMeals(from: plannedActivitiesForSelectedDate)

        return CoachNutritionContext(
            caloriesCurrent: nutritionViewModel.currentMetrics?.calories ?? 0,
            caloriesGoal: goals?.calories ?? 2200,

            proteinCurrent: nutritionViewModel.currentMetrics?.protein ?? 0,
            proteinGoal: goals?.protein ?? 140,

            carbsCurrent: nutritionViewModel.currentMetrics?.carbs ?? 0,
            carbsGoal: goals?.carbs ?? 300,

            fatsCurrent: nutritionViewModel.currentMetrics?.fats ?? 0,
            fatsGoal: goals?.fats ?? 80,

            waterCurrent: nutritionViewModel.totalWaterLiters,
            waterGoal: goals?.waterLiters ?? 3.0,

            mealsCount: completedMeals.count,
            lastMealTime: completedMeals.last?.date
        )
    }
    
    private var todayBalanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Current status")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text("Your main recovery and activity signals right now.")
                    .font(.system(size: 12.2, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.62))
            }

            VStack(spacing: 8) {
                ForEach(todayBalanceItems) { item in
                    todayBalanceRow(item)
                }
            }
        }
    }

    private func todayBalanceRow(_ item: TodayBalanceItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(item.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15.2, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(item.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.72))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: item.isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(item.isGood ? green.opacity(0.85) : item.color.opacity(0.95))
        }
        .padding(.horizontal, 14)
        .frame(height: 66)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    item.isGood
                    ? LinearGradient(
                        colors: [
                            cardBackground.opacity(0.36),
                            cardBackground.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [
                            item.color.opacity(0.10),
                            cardBackground.opacity(0.26)
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

    // MARK: - Suggested Support

    private var storySupportSection: some View {
        let story = coachScreenStory

        return VStack(alignment: .leading, spacing: 13) {
            if !story.primaryActions.isEmpty {
                primaryActionsSection(story)
            }

            if story.shouldShowWhy, let why = story.whyThisMatters {
                storyInfoSection(
                    title: "Why This Matters",
                    subtitle: "The reason behind the recommendation",
                    icon: "lightbulb.fill",
                    text: why,
                    color: story.color
                )
            }

            if story.shouldShowPlanAdjustment, let planAdjustment = story.planAdjustment {
                storyInfoSection(
                    title: "Plan Adjustment",
                    subtitle: "Only if the plan needs changing",
                    icon: "arrow.triangle.2.circlepath",
                    text: planAdjustment,
                    color: CoachPalette.warning
                )
            }

            if story.shouldShowActivityContext, let activityContext = story.activityContext {
                storyInfoSection(
                    title: "Activity Context",
                    subtitle: "What this activity means right now",
                    icon: "figure.mind.and.body",
                    text: activityContext,
                    color: story.color
                )
            }
        }
    }

    private func primaryActionsSection(_ story: CoachScreenStory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: "Primary Actions",
                subtitle: "Do these next"
            )

            VStack(spacing: 5) {
                ForEach(Array(story.primaryActions.prefix(3).enumerated()), id: \.offset) { _, action in
                    coachFocusRow(
                        action.title,
                        color: action.color,
                        icon: action.icon
                    )
                }
            }
        }
    }

    private func supportSignalsSection(_ story: CoachScreenStory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: "Support Signals",
                subtitle: "Helpful secondary reminders"
            )

            VStack(spacing: 5) {
                ForEach(Array(story.supportActions.prefix(3).enumerated()), id: \.offset) { _, action in
                    coachFocusRow(
                        action.title,
                        color: action.color,
                        icon: action.icon
                    )
                }
            }
        }
    }

    private func storyInfoSection(
        title: String,
        subtitle: String,
        icon: String,
        text: String,
        color: Color
    ) -> some View {
        coachSectionView(
            CoachSection(
                title: title,
                subtitle: subtitle,
                icon: icon,
                color: color,
                style: .info,
                items: [],
                informationalText: text
            )
        )
    }

    private func coachSectionView(
        _ section: CoachSection
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: section.title,
                subtitle: section.subtitle
            )

            switch section.style {
            case .compact:
                compactSectionBody(section)

            case .cards:
                cardSectionBody(section)

            case .info:
                infoSectionBody(section)
            }
        }
    }
    
    private func infoSectionBody(
        _ section: CoachSection
    ) -> some View {

        HStack(alignment: .top, spacing: 12) {

            ZStack {
                Circle()
                    .fill(section.color.opacity(0.12))
                    .frame(width: 30, height: 30)

                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(section.color)
            }
            .padding(.top, 1)

            Text(section.informationalText ?? "")
                .font(.system(size: 13.2, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.84))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            section.color.opacity(0.06),
                            cardBackground.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private func compactSectionBody(
        _ section: CoachSection
    ) -> some View {
        VStack(spacing: 7) {
            ForEach(Array(section.items.prefix(3).enumerated()), id: \.offset) { _, item in
                compactSupportRow(
                    item,
                    color: section.color,
                    icon: section.icon
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            section.color.opacity(0.075),
                            cardBackground.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.045), lineWidth: 1)
                )
        )
    }

    private func cardSectionBody(
        _ section: CoachSection
    ) -> some View {
        VStack(spacing: 5) {
            ForEach(Array(section.items.prefix(3).enumerated()), id: \.offset) { _, item in
                coachFocusRow(
                    item,
                    color: section.color,
                    icon: section.icon
                )
            }
        }
    }

    private func supportGroupHeader(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            Text(subtitle)
                .font(.system(size: 12.1, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.62))
        }
    }

    private func compactSupportRow(
        _ text: String,
        color: Color,
        icon: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.13))
                    .frame(width: 26, height: 26)

                Image(systemName: compactIcon(for: text, fallback: icon))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color.opacity(0.96))
            }
            .padding(.top, 1)

            Text(text)
                .font(.system(size: 13.8, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.94))
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private func compactIcon(
        for text: String,
        fallback: String
    ) -> String {
        let value = text.lowercased()

        if value.contains("water") ||
            value.contains("drink") ||
            value.contains("sip") ||
            value.contains("fluid") ||
            value.contains("hydrate") {
            return "drop.fill"
        }

        if value.contains("electrolyte") ||
            value.contains("isotonic") ||
            value.contains("mineral") {
            return "bolt.fill"
        }

        if value.contains("banana") ||
            value.contains("bar") ||
            value.contains("gel") ||
            value.contains("snack") {
            return "takeoutbag.and.cup.and.straw.fill"
        }

        if value.contains("protein") ||
            value.contains("yogurt") ||
            value.contains("eggs") ||
            value.contains("chicken") ||
            value.contains("shake") ||
            value.contains("meal") ||
            value.contains("food") {
            return "fork.knife"
        }

        if value.contains("sleep") ||
            value.contains("calm") ||
            value.contains("stress") ||
            value.contains("nervous") {
            return "moon.stars.fill"
        }

        if value.contains("stiffness") ||
            value.contains("mobility") ||
            value.contains("circulation") ||
            value.contains("tension") {
            return "leaf.fill"
        }

        return fallback
    }

    private func coachFocusRow(
        _ text: String,
        color: Color? = nil,
        icon: String = "checkmark"
    ) -> some View {
        let rowColor = color ?? coachAccentColor

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(rowColor.opacity(0.10))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(rowColor)
            }

            Text(text)
                .font(.system(size: 13.8, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.94))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardBackground.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.035), lineWidth: 1)
                )
        )
    }


    private var avoidNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(premiumAvoidNotes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(coachAccentColor.opacity(0.9))
                        .padding(.top, 2)

                    Text(note)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.78))
                        .lineSpacing(3)

                    Spacer()
                }
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardBackground.opacity(0.26))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private func fastFuelRow(_ item: FastFuelItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.026))
                    .frame(width: 30, height: 30)

                if !item.imageName.isEmpty, UIImage(named: item.imageName) != nil {
                    Image(item.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .opacity(0.92)
                } else {
                    Image(systemName: item.imageName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(coachAccentColor.opacity(0.9))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15.2, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(item.reason)
                    .font(.system(size: 11.8, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.68))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()

                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    nutritionViewModel.addCoachRecommendationToPlan(
                        item: item,
                        context: modelContext
                    )
                    refreshCoachLiveState(refreshHealth: false, source: "ExpertCoachViewV3.addFuelRecommendation")
                    appSession.triggerCoachRefresh(source: "ExpertCoachViewV3.addFuelRecommendation")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WeekFitTheme.purple.opacity(0.92))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(WeekFitTheme.purple.opacity(0.065))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 15)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardBackground.opacity(0.32),
                            cardBackground.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.035), lineWidth: 1)
                )
        )
    }

    // MARK: - Refresh

    private func refreshCoachLiveState(refreshHealth: Bool = false, source: String = "ExpertCoachViewV3.refreshCoachLiveState") {
        #if DEBUG
        let priorityBefore = debugCoachPrioritySummary()
        regenerateCoachRefreshID(source: source, priorityBefore: priorityBefore)
        #else
        regenerateCoachRefreshID(source: source)
        #endif

        if refreshHealth {
            regenerateHealthRefreshID(source: source)
        }
    }

    private func refreshCoachDataAsync() async {
        guard healthManager.isHealthAccessGranted else { return }

        await healthManager.loadHealthData(
            for: selectedDate,
            plannedActivities: plannedActivitiesForSelectedDate
        )
        regenerateCoachRefreshID(source: "ExpertCoachViewV3.refreshCoachDataAsync")
    }

    private func regenerateCoachRefreshID(
        source: String,
        priorityBefore: String? = nil
    ) {
        CoachStateStabilizer.markSyncEvent(source: source)
        pendingCoachRefreshSources.append(source)
        guard !isCoachRefreshScheduled else { return }

        isCoachRefreshScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            let sourceSummary = summarizeRefreshSources(pendingCoachRefreshSources)
            pendingCoachRefreshSources.removeAll()
            isCoachRefreshScheduled = false

            applyCoachRefreshID(source: sourceSummary, priorityBefore: priorityBefore)
        }
    }

    private func applyCoachRefreshID(
        source: String,
        priorityBefore: String? = nil
    ) {
        guard let resolvedGuidance = resolveCoachGuidance(source: "ExpertCoachViewV3.applyCoachRefreshID") else {
            #if DEBUG
            CoachRefreshDebug.log(
                "[CoachScreenRender]",
                "ExpertCoachViewV3.renderMode=\(ExpertCoachRenderMode.fallbackCurrentStatus.rawValue) cachedCoachGuidanceNil=true screenStoryNil=true renderedState=nil renderedTitle=nil priority=nil intent=\(debugCoachIntentSummary())"
            )
            #endif
            return
        }
        let signature = CoachStateStabilizer.visibleSignature(
            for: resolvedGuidance,
            source: "ExpertCoachViewV3.applyCoachRefreshID"
        ) + "#\(coachInputSignature)"
        guard signature != lastAppliedCoachRefreshSignature else { return }
        lastAppliedCoachRefreshSignature = signature
        cachedCoachGuidance = resolvedGuidance

        let oldValue = coachRefreshID
        let newValue = UUID()
        #if DEBUG
        let resolverTitle = resolvedGuidance.priority.detailTitle
        let guidanceTitle = resolvedGuidance.title
        let screenStoryTitle = resolvedGuidance.screenStory?.title
        let renderedTitle = validTitle(guidanceTitle) ?? screenStoryTitle ?? resolverTitle
        let fallbackUsed = validTitle(guidanceTitle) == nil
        let priorityDetails = [
            priorityBefore.map { "priorityBefore=\($0)" },
            "priorityAfter=\(debugCoachPrioritySummary(for: resolvedGuidance))",
            "renderMode=\(ExpertCoachRenderMode.resolve(cachedGuidance: resolvedGuidance).rawValue)",
            "cachedCoachGuidanceNil=false",
            "screenStoryNil=\(resolvedGuidance.screenStory == nil)",
            "priority=\(resolvedGuidance.priority.priority)/\(resolvedGuidance.priority.focus)",
            "limiter=\(resolvedGuidance.priority.limiter)",
            "strength=\(resolvedGuidance.priority.strength)",
            "screenStoryType=\(debugScreenStoryType(resolvedGuidance))",
            "renderedState=\"\(resolvedGuidance.screenStory?.stateLabel ?? resolvedGuidance.stateLabel)\"",
            "renderedTitle=\"\(renderedTitle)\"",
            "intent=\(debugCoachIntentSummary())"
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        CoachRefreshDebug.log(
            "[CoachScreenTitleMapping]",
            "resolverTitle=\"\(resolverTitle)\" guidanceTitle=\"\(guidanceTitle)\" screenStoryTitle=\"\(screenStoryTitle ?? "nil")\" renderedTitle=\"\(renderedTitle)\" fallbackUsed=\(fallbackUsed)"
        )
        CoachRefreshDebug.log(
            "[CoachRefreshDebug]",
            "ExpertCoachViewV3.coachRefreshID source=\(source) \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newValue)) \(debugHydrationSummary()) \(priorityDetails)"
        )
        CoachRefreshDebug.log(
            "[CoachScreenRender]",
            debugCoachScreenRenderDetails(for: resolvedGuidance)
        )
        #endif
        coachRefreshID = newValue
    }

    private func resolveCoachGuidance(source: String) -> CoachGuidanceV3? {
        guard let brain = nutritionViewModel.nutritionResult?.brain else {
            return nil
        }

        #if DEBUG
        let completedMeals = CoachCanonicalDayState.completedMeals(from: plannedActivitiesForSelectedDate)
        let mealDebug = completedMeals
            .map { meal in
                "mealID=\(meal.id) mealName=\"\(meal.title)\" calories=\(meal.calories) protein=\(meal.protein) carbs=\(meal.carbs) fat=\(meal.fats)"
            }
            .joined(separator: " | ")
        CoachRefreshDebug.log(
            "[CoachNutritionMeals]",
            "source=ExpertCoachViewV3.resolveCoachGuidance.\(source) meals=\(completedMeals.count) \(mealDebug)"
        )
        #endif

        CoachNutritionConsistency.assertMatchesCurrentMetrics(
            metrics: nutritionViewModel.currentMetrics,
            coach: nutritionContext,
            source: "ExpertCoachViewV3.resolveCoachGuidance.\(source)"
        )

        let output = CoachEngineV3.decide(
            from: brain,
            plannedActivities: plannedActivities,
            selectedDate: selectedDate,
            dayContext: dayContext,
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: Int(healthManager.recoveryPercent),
                sleepHours: healthManager.sleepHours
            ),
            nutritionContext: nutritionContext
        )
        return CoachStateStabilizer.stabilized(output, source: source)
    }

    private var coachInputSignature: String {
        let nutrition = nutritionContext
        let hydrationLogs = plannedActivitiesForSelectedDate.filter { $0.imageName == "hydration" && $0.isCompleted }.count
        let hydrationRatio = nutrition.waterGoal > 0 ? nutrition.waterCurrent / nutrition.waterGoal : 0
        let nextActivity = dayContext.nextActivity
        let minutesUntil = nextActivity.map { Int($0.date.timeIntervalSince(Date()) / 60) } ?? -1
        let minutesBucket = max(-1, minutesUntil / 5)
        let coachRelevantActivities = plannedActivitiesForSelectedDate.filter(CoachDayActivityContextResolver.isCoachRelevant)
        let activityVersion = coachRelevantActivities
            .map { "\($0.id):\(Int($0.date.timeIntervalSince1970 / 60)):\($0.isCompleted):\($0.isSkipped)" }
            .sorted()
            .joined(separator: ",")

        return [
            "water=\(String(format: "%.2f", nutrition.waterCurrent))",
            "hydrationRatio=\(String(format: "%.2f", hydrationRatio))",
            "hydrationLogs=\(hydrationLogs)",
            "rawAllActivities=\(plannedActivities.count)",
            "selectedDayActivities=\(plannedActivitiesForSelectedDate.count)",
            "coachRelevantActivities=\(coachRelevantActivities.count)",
            "activityVersion=\(activityVersion)",
            "meals=\(nutrition.mealsCount ?? -1)",
            "carbs=\(String(format: "%.1f", nutrition.carbsCurrent))",
            "lastMeal=\(nutrition.lastMealTime.map { Int($0.timeIntervalSince1970 / 60) } ?? -1)",
            "activity=\(nextActivity?.id ?? "none")",
            "activityStart=\(nextActivity.map { Int($0.date.timeIntervalSince1970 / 60) } ?? -1)",
            "minutesBucket=\(minutesBucket)"
        ].joined(separator: "#")
    }

    private func regenerateHealthRefreshID(source: String) {
        CoachStateStabilizer.markSyncEvent(source: source)
        pendingHealthRefreshSources.append(source)
        guard !isHealthRefreshScheduled else { return }

        isHealthRefreshScheduled = true
        DispatchQueue.main.async {
            let sourceSummary = summarizeRefreshSources(pendingHealthRefreshSources)
            pendingHealthRefreshSources.removeAll()
            isHealthRefreshScheduled = false

            applyHealthRefreshID(source: sourceSummary)
        }
    }

    private func applyHealthRefreshID(source: String) {
        let oldValue = healthRefreshID
        let newValue = UUID()
        #if DEBUG
        CoachRefreshDebug.log(
            "[CoachRefreshDebug]",
            "ExpertCoachViewV3.healthRefreshID source=\(source) \(CoachRefreshDebug.uuidChange(oldValue: oldValue, newValue: newValue))"
        )
        #endif
        healthRefreshID = newValue
    }

    private func summarizeRefreshSources(_ sources: [String]) -> String {
        guard !sources.isEmpty else { return "unspecified" }

        let uniqueSources = Array(Set(sources)).sorted()
        let summary = uniqueSources.prefix(4).joined(separator: ",")
        let overflow = uniqueSources.count > 4 ? ",+\(uniqueSources.count - 4)" : ""
        return "[\(summary)\(overflow)]"
    }

    #if DEBUG
    private func debugHydrationSummary() -> String {
        CoachRefreshDebug.hydrationSummary(
            current: nutritionViewModel.currentMetrics?.waterLiters ?? 0,
            goal: nutritionViewModel.nutritionResult?.goals.waterLiters ?? 0
        )
    }

    private func debugCoachPrioritySummary() -> String {
        guard let output = cachedCoachGuidance else { return "priority=missingCachedGuidance" }
        return debugCoachPrioritySummary(for: output)
    }

    private func debugCoachPrioritySummary(for output: CoachGuidanceV3) -> String {
        let renderedState = output.screenStory?.stateLabel ?? output.stateLabel
        let renderedTitle = validTitle(output.title) ?? output.screenStory?.title ?? output.priority.detailTitle
        return "priority=\(output.priority.priority)/\(output.priority.focus) limiter=\(output.priority.limiter) strength=\(output.priority.strength) title=\"\(output.priority.todayTitle)\" renderedState=\"\(renderedState)\" renderedTitle=\"\(renderedTitle)\""
    }

    private func debugScreenStoryType(_ output: CoachGuidanceV3) -> String {
        guard output.screenStory != nil else { return "nil" }
        return output.narrativePlan.map { "badge=\($0.badgeIntent)" } ?? "legacy"
    }

    private func debugCoachScreenRenderDetails(for output: CoachGuidanceV3) -> String {
        let story = output.screenStory
        let selectedActivity = output.priority.activity ?? coachDayContext.coachFocusActivity
        let nextActivity = dayContext.nextActivity
        let coachRelevantActivities = plannedActivitiesForSelectedDate.filter(CoachDayActivityContextResolver.isCoachRelevant)
        let visibleFutureUpNextCount = coachRelevantActivities.filter {
            !$0.isCompleted &&
                !$0.isSkipped &&
                $0.date >= Date()
        }.count
        let selectedActivityRenderState = debugSelectedActivityRenderState(
            selectedActivity,
            visibleFutureActivities: coachRelevantActivities.filter {
                !$0.isCompleted &&
                    !$0.isSkipped &&
                    $0.date >= Date()
            }
        )
        let supportSignals = output.priority.supportBullets
        let primaryActions = story?.primaryActions ?? []
        let secondarySupportActions = story?.supportActions ?? []
        let hiddenSupportReason: String = {
            if story == nil { return "screenStoryNil" }
            if supportSignals.isEmpty && primaryActions.isEmpty && secondarySupportActions.isEmpty && output.supportActions.isEmpty { return "noSupportSignalsOrActions" }
            if !supportSignals.isEmpty || !secondarySupportActions.isEmpty { return "hiddenByRenderingContract" }
            if !supportSignals.isEmpty && secondarySupportActions.isEmpty { return "supportSignalsNotMappedToSupportActions" }
            return "none"
        }()
        let visibleRisk = story?.shouldShowBeCarefulWith == true ? story?.beCarefulWith : nil

        return """
        ExpertCoachViewV3.renderMode=\(ExpertCoachRenderMode.resolve(cachedGuidance: output).rawValue) \
        cachedCoachGuidanceNil=false screenStoryNil=\(story == nil) \
        renderedState=\"\(story?.stateLabel ?? output.stateLabel)\" renderedTitle=\"\(validTitle(output.title) ?? story?.title ?? output.priority.detailTitle)\" \
        myRead=\"\(story?.myRead ?? output.message)\" myRecommendation=\"\(story?.myRecommendation ?? output.insightSubtitle ?? "")\" beCarefulWith=\"\(visibleRisk ?? output.avoidNotes.joined(separator: " | "))\" \
        hiddenSupportSignals.count=\(supportSignals.count) \
        primaryActions.count=\(primaryActions.count) primaryActions.titles=\"\(primaryActions.map(\.title).joined(separator: " | "))\" \
        hiddenSecondarySupportActions.count=\(secondarySupportActions.count) \
        visibleSupportActions.count=\(output.supportActions.count) hiddenSupportReason=\(hiddenSupportReason) \
        selectedCoachActivity=\"\(debugActivitySummary(selectedActivity))\" selectedCoachActivityRenderState=\(selectedActivityRenderState) nextActivityTime=\(nextActivity.map { "\($0.date)" } ?? "nil") \
        visibleFutureUpNextActivities=\(visibleFutureUpNextCount) rawAllActivities=\(plannedActivities.count) selectedDayActivities=\(plannedActivitiesForSelectedDate.count) coachRelevantActivities=\(coachRelevantActivities.count) \
        guidanceSourceTime=\(Date().timeIntervalSince1970) planVersion=\"\(coachInputSignature)\" \
        priority=\(output.priority.priority)/\(output.priority.focus) limiter=\(output.priority.limiter) intent=\(debugCoachIntentSummary())
        """
    }

    private func debugActivitySummary(_ activity: PlannedActivity?) -> String {
        guard let activity else { return "none" }
        return "\(activity.title)|\(activity.date)|completed=\(activity.isCompleted)|skipped=\(activity.isSkipped)"
    }

    private func debugSelectedActivityRenderState(
        _ activity: PlannedActivity?,
        visibleFutureActivities: [PlannedActivity]
    ) -> String {
        guard let activity else { return "none" }
        if visibleFutureActivities.contains(where: { $0.id == activity.id }) {
            return "visibleFutureUpNext"
        }
        if activity.isCompleted {
            return "selectedCompletedOrRecovering"
        }
        if activity.isSkipped {
            return "selectedSkipped"
        }
        if activity.date < Date() {
            return "selectedActiveOrPast"
        }
        return "selectedCoachOnly"
    }

    private func debugCoachIntentSummary() -> String {
        guard let brain = nutritionViewModel.nutritionResult?.brain else { return "missingBrain" }
        let activityContext = CoachActivityContextResolverV3.resolveDayContext(
            activities: plannedActivitiesForSelectedDate,
            selectedDate: selectedDate,
            now: Date(),
            brain: brain
        )
        let readiness = CoachReadinessAnalyzerV3.analyze(
            brain: brain,
            phase: activityContext.phase
        )
        let context = CoachDecisionContext(
            brain: brain,
            dayContext: dayContext,
            activityContext: activityContext,
            tomorrowContext: nil,
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: Int(healthManager.recoveryPercent),
                sleepHours: healthManager.sleepHours
            ),
            nutritionContext: nutritionContext,
            readiness: readiness
        )
        return "\(CoachIntentResolver.resolve(context))"
    }
    #endif

    private var plannedActivitiesForSelectedDate: [PlannedActivity] {
        CoachCanonicalDayState.selectedDayActivities(
            from: plannedActivities,
            selectedDate: selectedDate
        )
    }
    
    
    private var eveningReviewPlan: CoachEveningReviewPlan {

        let plannerActivities = plannedActivitiesForSelectedDate.filter {
            $0.source == "planner"
        }

        let planned = plannerActivities.count

        let completed = plannerActivities.filter {
            $0.isCompleted
        }.count

        let skipped = plannerActivities.filter {
            $0.isSkipped
        }.count

        return CoachEveningReviewPlan(
            planned: planned,
            completed: completed,
            skipped: skipped
        )
    }
}

enum CoachPalette {
    static let recovery = Color(red: 0.66, green: 0.58, blue: 0.98)
    static let hydration = Color(red: 0.40, green: 0.72, blue: 0.98)
    static let warning = Color(red: 1.00, green: 0.76, blue: 0.26)
    static let fueling = Color(red: 0.52, green: 0.90, blue: 0.70)
    static let training = Color(red: 0.47, green: 0.42, blue: 1.00)
    static let stable = Color(red: 0.62, green: 0.84, blue: 0.67)
    static let stress = Color(red: 1.00, green: 0.47, blue: 0.47)

    // NEW
    static let good = stable
    static let activity = training
}

enum ExpertCoachRenderMode: String {
    case guidance
    case fallbackCurrentStatus

    static func resolve(cachedGuidance: CoachGuidanceV3?) -> ExpertCoachRenderMode {
        guard cachedGuidance?.screenStory != nil else {
            return .fallbackCurrentStatus
        }

        return .guidance
    }
}
