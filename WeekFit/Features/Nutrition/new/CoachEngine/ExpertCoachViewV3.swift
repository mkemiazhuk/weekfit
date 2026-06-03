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


    // MARK: - Coach V3 Binding
    
    private var dayContext: CoachDayContext {
        CoachDayContextBuilder.build(
            activities: plannedActivitiesForSelectedDate,
            selectedDate: selectedDate,
            now: Date()
        )
    }

    private var guidance: CoachGuidanceV3 {
        guard let brain = nutritionViewModel.nutritionResult?.brain else {
            return fallbackGuidance
        }

        return CoachEngineV3.decide(
            from: brain,
            plannedActivities: plannedActivitiesForSelectedDate,
            selectedDate: selectedDate,
            dayContext: dayContext,
            recoveryContext: CoachRecoveryContext(
                recoveryPercent: Int(healthManager.recoveryPercent),
                sleepHours: healthManager.sleepHours
            ),
            nutritionContext: nutritionContext
        )
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
        CoachScenarioRule(
            stateLabel: "OVERVIEW",
            title: "No active focus right now",
            message: "Nothing needs immediate attention right now. Keep the day steady and follow the next planned training block.",
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
        switch coachScenario.archetype {
        case .performance:
            return CoachPalette.training
        case .endurance:
            return CoachPalette.activity
        case .recovery:
            return CoachPalette.recovery
        case .heat:
            return CoachPalette.warning
        case .meal:
            return CoachPalette.stable
        case .stable:
            return CoachPalette.stable
        }
    }

    private var coachIcon: String {
        switch coachScenario.archetype {
        case .performance:
            return "figure.strengthtraining.traditional"
        case .endurance:
            return "figure.run"
        case .recovery:
            return "figure.cooldown"
        case .heat:
            return "flame.fill"
        case .meal:
            return "waveform.path.ecg"
        case .stable:
            return "waveform.path.ecg.rectangle.fill"
        }
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
            message: "Nothing needs immediate attention. Check today’s balance below.",
            insightTitle: "No active focus right now",
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
        ZStack(alignment: .topTrailing) {
            Image(systemName: coachIcon)
                .font(.system(size: 68, weight: .regular))
                .foregroundStyle(coachAccentColor.opacity(0.025))
                .padding(.top, 18)
                .padding(.trailing, 18)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                stateBadge

                VStack(alignment: .leading, spacing: 7) {
                    Text(coachDisplayText.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.8)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(coachDisplayText.message)
                        .font(.system(size: 13.4, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.70))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
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
        let narrative = CoachNarrativeBuilder.build(
            scenario: coachScenario,
            dayContext: dayContext,
            nutrition: nutritionContext
        )

        return (
            narrative.title,
            narrative.message
        )
    }

    private var coachDisplayStateLabel: String {
        coachRule.stateLabel
    }

    private var coachSections: [CoachSection] {
        CoachSectionBuilder.build(
            scenario: coachScenario,
            nutrition: nutritionContext,
            trainingFallback: trainingFocusFallback,
            coachAccentColor: coachAccentColor
        )
    }

    private var trainingFocusFallback: [String] {
        let items = coachRule.supportFocus
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !items.isEmpty {
            return Array(items.prefix(3))
        }

        return [
            "Stay controlled",
            "Keep the plan simple",
            "Avoid unnecessary intensity"
        ]
    }

    private var premiumAvoidNotes: [String] {
        coachRule.avoidNotes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var shouldSurfaceCoach: Bool {
        switch effectiveCoachPhase {
        case .stable:
            return guidance.shouldSurface
        default:
            return true
        }
    }
    
//    private var effectiveCoachPhase: CoachActivityPhaseV3 {
//        CoachActivityPriorityResolver.resolve(
//            activities: plannedActivitiesForSelectedDate,
//            selectedDate: selectedDate,
//            now: Date()
//        )
//    }

//    private var effectiveCoachPhase: CoachActivityPhaseV3 {
//        let now = Date()
//
//        if let active = highestPriorityActivity(from: activeActivities(now: now)) {
//            return .active(
//                activity: active,
//                kind: CoachActivityContextResolverV3.kind(for: active)
//            )
//        }
//
//        if let recent = highestPriorityActivity(from: recentCompletedActivities(now: now)) {
//            return .recovering(
//                activity: recent,
//                kind: CoachActivityContextResolverV3.kind(for: recent),
//                minutesSinceEnd: minutesSinceActivityEnd(recent, now: now)
//            )
//        }
//
//        if let upcoming = highestPriorityActivity(from: preparingActivities(now: now)) {
//            return .preparing(
//                activity: upcoming,
//                kind: CoachActivityContextResolverV3.kind(for: upcoming),
//                minutesUntil: minutesUntilActivityStart(upcoming, now: now)
//            )
//        }
//
//        return guidance.phase
//    }

    private var effectiveCoachPhase: CoachActivityPhaseV3 {
        CoachActivityPhasePriorityResolver.resolve(
            activities: plannedActivitiesForSelectedDate,
            selectedDate: selectedDate,
            now: Date()
        )
    }
    
    private func activeActivities(now: Date) -> [PlannedActivity] {
        plannedActivitiesForSelectedDate.filter { activity in
            guard !activity.isCompleted && !activity.isSkipped else { return false }
            guard isCoachRelevantActivity(activity) else { return false }

            let endDate = Calendar.current.date(
                byAdding: .minute,
                value: max(activity.effectiveDurationMinutes, activity.durationMinutes),
                to: activity.date
            ) ?? activity.date

            return activity.date <= now && now <= endDate
        }
    }

    private func recentCompletedActivities(now: Date) -> [PlannedActivity] {
        plannedActivitiesForSelectedDate.filter { activity in
            guard activity.isCompleted && !activity.isSkipped else { return false }
            guard isCoachRelevantActivity(activity) else { return false }

            let minutes = minutesSinceActivityEnd(activity, now: now)
            guard minutes >= 0 else { return false }

            return minutes <= recoveryHoldMinutes(for: activity)
        }
    }

    private func preparingActivities(now: Date) -> [PlannedActivity] {
        plannedActivitiesForSelectedDate.filter { activity in
            guard !activity.isCompleted && !activity.isSkipped else { return false }
            guard isCoachRelevantActivity(activity) else { return false }

            let minutes = minutesUntilActivityStart(activity, now: now)

            return minutes >= 0 && minutes <= preparationLookaheadMinutes(for: activity)
        }
    }

    private func highestPriorityActivity(
        from activities: [PlannedActivity]
    ) -> PlannedActivity? {
        activities.max {
            activityPriorityScore($0) < activityPriorityScore($1)
        }
    }

    private func activityPriorityScore(_ activity: PlannedActivity) -> Int {
        let load = CoachActivityContextResolverV3.load(for: activity)
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        var score: Int

        switch load {
        case .extreme:
            score = 500
        case .high:
            score = 400
        case .moderate:
            score = 260
        case .low:
            score = 120
        }

        switch kind {
        case .workout:
            score += 55
        case .endurance:
            score += 50
        case .heat:
            score += 35
        case .recovery:
            score += 20
        case .meal:
            score -= 80
        case .other:
            score += 5
        }

        score += min(activity.effectiveDurationMinutes, 180) / 3

        if isWalkLike(activity) {
            score -= 12
        }

        return score
    }

    private func isWalkLike(_ activity: PlannedActivity) -> Bool {
        let text = "\(activity.type) \(activity.title)".lowercased()

        return text.contains("walk") ||
               text.contains("walking") ||
               text.contains("hike")
    }

    private func isCoachRelevantActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()

        if type == "meal" { return false }
        if activity.imageName == "hydration" { return false }
        if title.contains("water") || title.contains("hydration") { return false }

        return true
    }

    private func recoveryHoldMinutes(for activity: PlannedActivity) -> Int {
        let load = CoachActivityContextResolverV3.load(for: activity)
        let kind = CoachActivityContextResolverV3.kind(for: activity)

        switch load {
        case .extreme:
            return 120
        case .high:
            return 90
        case .moderate:
            return kind == .recovery ? 25 : 60
        case .low:
            return kind == .recovery ? 20 : 35
        }
    }

    private func preparationLookaheadMinutes(for activity: PlannedActivity) -> Int {
        let load = CoachActivityContextResolverV3.load(for: activity)

        switch load {
        case .extreme, .high:
            return 120
        case .moderate:
            return 90
        case .low:
            return 45
        }
    }

    private func minutesSinceActivityEnd(
        _ activity: PlannedActivity,
        now: Date = Date()
    ) -> Int {
        let endDate = Calendar.current.date(
            byAdding: .minute,
            value: max(activity.effectiveDurationMinutes, activity.durationMinutes),
            to: activity.date
        ) ?? activity.date

        return Int(now.timeIntervalSince(endDate) / 60)
    }

    private func minutesUntilActivityStart(
        _ activity: PlannedActivity,
        now: Date = Date()
    ) -> Int {
        max(0, Int(activity.date.timeIntervalSince(now) / 60))
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

                if shouldShowEveningReview {
                    CoachEveningReviewSection(
                        summary: eveningReviewSummary,
                        plan: eveningReviewPlan,
                        readiness: tomorrowReadiness
                    )
                } else if shouldSurfaceCoach {
                    coachCard
                    supportSection
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

        return CoachNutritionContext(
            caloriesCurrent: nutritionViewModel.currentMetrics?.calories ?? 0,
            caloriesGoal: goals?.calories ?? 2200,

            proteinCurrent: nutritionViewModel.currentMetrics?.protein ?? 0,
            proteinGoal: goals?.protein ?? 140,

            waterCurrent: nutritionViewModel.totalWaterLiters,
            waterGoal: goals?.waterLiters ?? 3.0
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

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(coachSections) { section in
                coachSectionView(section)
            }

            if !premiumAvoidNotes.isEmpty {
                avoidNoteSection
                    .padding(.top, 1)
            }
        }
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

                if UIImage(named: item.imageName) != nil {
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
            fiber: nutritionViewModel.currentMetrics?.fiber ?? 0,
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
        plannedActivities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
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
