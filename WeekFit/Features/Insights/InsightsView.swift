import SwiftUI
import SwiftData
import HealthKit
internal import Combine

struct InsightsSnapshot {
    let avatarInitials: String
    let weekDays: [String]
    let hero: InsightsHeroInsight
    let weeklyScores: [InsightsMiniScore]
    let trends: [InsightsTrendCard]
    let hydrationImpact: InsightsCorrelationCard
    let weeklyReflection: InsightsReflection
    let focusNext: InsightsFocusNext
    let dataQuality: InsightsDataQuality

    static let fallback = InsightsSnapshot(
        avatarInitials: "WF",
        weekDays: ["M", "T", "W", "T", "F", "S", "S"],
        hero: InsightsHeroInsight(
            label: "AI INSIGHT",
            title: "Building your patterns",
            subtitle: "Log sleep, meals, drinks and activities for a few more days to unlock trends.",
            takeaway: "Start with one consistent week.",
            icon: "brain.head.profile",
            accent: WeekFitTheme.meal,
            graphValues: [0.32, 0.42, 0.38, 0.48, 0.45, 0.52, 0.50],
            badgeValue: "—",
            badgeLabel: "patterns",
            domain: .missingData
        ),
        weeklyScores: [
            InsightsMiniScore(icon: "heart.fill", iconColor: WeekFitTheme.meal, title: "Recovery", value: "—", detail: "log recovery"),
            InsightsMiniScore(icon: "moon.fill", iconColor: WeekFitTheme.purple, title: "Sleep", value: "—", detail: "log sleep"),
            InsightsMiniScore(icon: "bolt.fill", iconColor: WeekFitTheme.orange, title: "Training", value: "—", detail: "need 7 days"),
            InsightsMiniScore(icon: "fork.knife", iconColor: WeekFitTheme.blue, title: "Nutrition", value: "—", detail: "need 7 days")
        ],
        trends: [
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Training pattern unavailable", subtitle: "Complete or sync workouts for 7 days", takeaway: "Build consistency before judging load.", icon: "figure.run", domain: .activity),
            InsightsTrendCard(accent: WeekFitTheme.meal, label: "NUTRITION PATTERN", title: "Nutrition insight unavailable", subtitle: "Log meals for 7 days", takeaway: "Protein consistency unlocks better recovery context.", icon: "fork.knife", domain: .nutrition)
        ],
        hydrationImpact: InsightsCorrelationCard(
            label: "HYDRATION INSIGHT",
            title: "Hydration insight unavailable",
            subtitle: "Log drinks for 7 days to compare with recovery.",
            rows: [
                InsightsCorrelationRow(icon: "drop.fill", title: "Water evidence", values: ["—", "—", "—"], color: WeekFitTheme.blue),
                InsightsCorrelationRow(icon: "heart.fill", title: "Recovery context", values: ["—", "—", "—"], color: WeekFitTheme.meal)
            ]
        ),
        weeklyReflection: InsightsReflection(
            label: "WEEKLY REFLECTION",
            text: "Building your patterns. Log sleep, meals, drinks and activities for a few more days to unlock trends.",
            domain: .missingData
        ),
        focusNext: InsightsFocusNext(
            label: "FOCUS NEXT",
            title: "Build the baseline first",
            text: "Insights becomes useful once sleep, recovery, food, drink and activity have enough recent history.",
            action: "Log the next 7 days consistently.",
            icon: "sparkles",
            accent: WeekFitTheme.meal,
            domain: .missingData
        ),
        dataQuality: InsightsDataQuality(
            recoveryDays: 0,
            sleepDays: 0,
            hydrationDays: 0,
            mealDays: 0,
            activityDays: 0,
            plannerDays: 0
        )
    )
}

enum InsightsDomain: Hashable {
    case recovery
    case sleep
    case nutrition
    case hydration
    case activity
    case consistency
    case missingData
}

enum InsightsDetailDestination: Equatable, Identifiable {
    case activity
    case nutrition
    case recovery

    var id: String {
        switch self {
        case .activity: return "activity"
        case .nutrition: return "nutrition"
        case .recovery: return "recovery"
        }
    }
}

struct InsightsDataQuality {
    let recoveryDays: Int
    let sleepDays: Int
    let hydrationDays: Int
    let mealDays: Int
    let activityDays: Int
    let plannerDays: Int

    var hasAnySignal: Bool {
        [recoveryDays, sleepDays, hydrationDays, mealDays, activityDays, plannerDays].contains { $0 > 0 }
    }
}

#if DEBUG
private extension InsightsSnapshot {

    static let previewBalanced = makePreview(
        hero: InsightsHeroInsight(
            label: "AI INSIGHT",
            title: "Recovery looks resilient",
            subtitle: "30-day recovery averages 78. Current load appears sustainable if sleep stays steady.",
            takeaway: "Keep this rhythm for another week.",
            icon: "heart.fill",
            accent: WeekFitTheme.meal,
            graphValues: [0.70, 0.76, 0.74, 0.82, 0.79, 0.81, 0.77],
            badgeValue: "78",
            badgeLabel: "avg",
            domain: .recovery
        ),
        weeklyScores: [
            InsightsMiniScore(icon: "heart.fill", iconColor: WeekFitTheme.meal, title: "Recovery", value: "Strong", detail: ""),
            InsightsMiniScore(icon: "moon.fill", iconColor: WeekFitTheme.purple, title: "Sleep", value: "7.4h", detail: "30d enough"),
            InsightsMiniScore(icon: "bolt.fill", iconColor: WeekFitTheme.orange, title: "Training", value: "4", detail: "3h 50m 7d"),
            InsightsMiniScore(icon: "fork.knife", iconColor: WeekFitTheme.blue, title: "Nutrition", value: "Ready", detail: "")
        ],
        trends: [
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Recovery is keeping up with training", subtitle: "4 active days this week with recovery holding steady.", takeaway: "Hold the rhythm; only add load if recovery stays stable.", icon: "figure.run", domain: .activity),
            InsightsTrendCard(accent: WeekFitTheme.meal, label: "NUTRITION PATTERN", title: "Nutrition data is strong enough to coach from", subtitle: "5 logged days • 118g avg protein", takeaway: "Use protein consistency to interpret recovery changes.", icon: "fork.knife", domain: .nutrition)
        ],
        hydrationImpact: InsightsCorrelationCard(
            label: "HYDRATION PATTERN",
            title: "Hydration is not the obvious limiter",
            subtitle: "Last 7 days do not show a meaningful recovery difference.",
            rows: [
                InsightsCorrelationRow(icon: "drop.fill", title: "Water evidence", values: ["2.1L", "2.4L", "2.2L"], color: WeekFitTheme.blue),
                InsightsCorrelationRow(icon: "heart.fill", title: "Recovery context", values: ["82", "79", "77"], color: WeekFitTheme.meal)
            ]
        ),
        weeklyReflection: InsightsReflection(
            label: "WEEKLY REFLECTION",
            text: "Recovery is the clearest pattern. Training and nutrition are strong enough to support the same conclusion.",
            domain: .missingData
        ),
        dataQuality: InsightsDataQuality(recoveryDays: 7, sleepDays: 7, hydrationDays: 7, mealDays: 7, activityDays: 7, plannerDays: 7)
    )

    static let previewRecoveryDown = makePreview(
        hero: InsightsHeroInsight(
            label: "AI INSIGHT",
            title: "Recovery is losing momentum",
            subtitle: "Recovery moved from 82 to 61 in recent Health history. Treat the next sessions as maintenance.",
            takeaway: "Keep the next workout easy.",
            icon: "heart.fill",
            accent: WeekFitTheme.meal,
            graphValues: [0.82, 0.78, 0.74, 0.69, 0.66, 0.63, 0.61],
            badgeValue: "61",
            badgeLabel: "latest",
            domain: .recovery
        ),
        weeklyScores: [
            InsightsMiniScore(icon: "heart.fill", iconColor: WeekFitTheme.meal, title: "Recovery", value: "Low", detail: ""),
            InsightsMiniScore(icon: "moon.fill", iconColor: WeekFitTheme.purple, title: "Sleep", value: "6.6h", detail: "30d below 7h"),
            InsightsMiniScore(icon: "bolt.fill", iconColor: WeekFitTheme.orange, title: "Training", value: "3", detail: "2h 40m 7d"),
            InsightsMiniScore(icon: "fork.knife", iconColor: WeekFitTheme.blue, title: "Nutrition", value: "Low", detail: "")
        ],
        trends: [
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Training may need restraint", subtitle: "3 active days this week while recovery is below target.", takeaway: "Keep the next workout lighter if recovery keeps dropping.", icon: "figure.run", domain: .activity),
            InsightsTrendCard(accent: WeekFitTheme.purple, label: "SLEEP CONSISTENCY", title: "Variable sleep is adding recovery noise", subtitle: "Sleep has been inconsistent recently.", takeaway: "Move sleep above 7h before chasing more volume.", icon: "bed.double.fill", domain: .sleep)
        ],
        hydrationImpact: InsightsCorrelationCard(
            label: "HYDRATION PATTERN",
            title: "Hydration insight unavailable",
            subtitle: "Log drinks on 2 more days to compare with recovery.",
            rows: [
                InsightsCorrelationRow(icon: "drop.fill", title: "Water evidence", values: ["—", "1.5L", "1.7L"], color: WeekFitTheme.blue),
                InsightsCorrelationRow(icon: "heart.fill", title: "Recovery", values: ["66", "63", "61"], color: WeekFitTheme.meal)
            ]
        ),
        weeklyReflection: InsightsReflection(
            label: "WEEKLY REFLECTION",
            text: "Recovery is the clearest signal this week. Sleep and hydration need steadier logs before comparing patterns.",
            domain: .sleep
        ),
        dataQuality: InsightsDataQuality(recoveryDays: 7, sleepDays: 7, hydrationDays: 2, mealDays: 7, activityDays: 7, plannerDays: 7)
    )

    static let previewSyncedTrainingLoad = makePreview(
        hero: InsightsHeroInsight(
            label: "AI INSIGHT",
            title: "Training may be outrunning recovery",
            subtitle: "5 active days this week while recovery is below target.",
            takeaway: "Hold volume until recovery rebounds.",
            icon: "figure.run",
            accent: WeekFitTheme.orange,
            graphValues: [0.28, 0.82, 0.34, 0.78, 0.72, 0.88, 0.64],
            badgeValue: "5 active days",
            badgeLabel: "This week",
            domain: .activity
        ),
        weeklyScores: [
            InsightsMiniScore(icon: "heart.fill", iconColor: WeekFitTheme.meal, title: "Recovery", value: "Low", detail: ""),
            InsightsMiniScore(icon: "moon.fill", iconColor: WeekFitTheme.purple, title: "Sleep", value: "6.8h", detail: "below 7h avg"),
            InsightsMiniScore(icon: "bolt.fill", iconColor: WeekFitTheme.orange, title: "Training", value: "5", detail: "4h 35m 7d"),
            InsightsMiniScore(icon: "fork.knife", iconColor: WeekFitTheme.blue, title: "Nutrition", value: "Low", detail: "")
        ],
        trends: [
            InsightsTrendCard(accent: WeekFitTheme.meal, label: "RECOVERY PATTERN", title: "Recovery is asking for restraint", subtitle: "6 days in last 30d", takeaway: "Reduce intensity until recovery moves back up.", icon: "chart.line.uptrend.xyaxis", domain: .recovery),
            InsightsTrendCard(accent: WeekFitTheme.meal, label: "NUTRITION PATTERN", title: "Nutrition data is not ready to explain recovery", subtitle: "3 logged days • 92g avg protein", takeaway: "Log protein on more days to make recovery patterns clearer.", icon: "fork.knife", domain: .nutrition)
        ],
        hydrationImpact: InsightsCorrelationCard(
            label: "HYDRATION PATTERN",
            title: "Hydration insight unavailable",
            subtitle: "A few more drink logs will make this pattern clearer.",
            rows: [
                InsightsCorrelationRow(icon: "drop.fill", title: "Water evidence", values: ["1.3L", "—", "1.8L"], color: WeekFitTheme.blue),
                InsightsCorrelationRow(icon: "heart.fill", title: "Recovery", values: ["58", "66", "61"], color: WeekFitTheme.meal)
            ]
        ),
        weeklyReflection: InsightsReflection(
            label: "WEEKLY REFLECTION",
            text: "This state represents logged done plus synced workouts. Activity is the strongest signal; recovery is the limiter to watch.",
            domain: .recovery
        ),
        dataQuality: InsightsDataQuality(recoveryDays: 7, sleepDays: 7, hydrationDays: 3, mealDays: 7, activityDays: 7, plannerDays: 7)
    )

    static let previewHydrationGap = makePreview(
        hero: InsightsHeroInsight(
            label: "AI INSIGHT",
            title: "Hydration is the clearest gap in the last 7 days",
            subtitle: "Average intake is 1.2L against a 2.4L target.",
            takeaway: "Log drinks consistently this week.",
            icon: "drop.fill",
            accent: WeekFitTheme.blue,
            graphValues: [0.42, 0.50, 0.36, 0.54, 0.46, 0.38, 0.44],
            badgeValue: "1.2L",
            badgeLabel: "avg water",
            domain: .hydration
        ),
        weeklyScores: [
            InsightsMiniScore(icon: "heart.fill", iconColor: WeekFitTheme.meal, title: "Recovery", value: "Low", detail: ""),
            InsightsMiniScore(icon: "moon.fill", iconColor: WeekFitTheme.purple, title: "Sleep", value: "7.1h", detail: "30d enough"),
            InsightsMiniScore(icon: "bolt.fill", iconColor: WeekFitTheme.orange, title: "Training", value: "2", detail: "1h 55m 7d"),
            InsightsMiniScore(icon: "fork.knife", iconColor: WeekFitTheme.blue, title: "Nutrition", value: "Low", detail: "")
        ],
        trends: [
            InsightsTrendCard(accent: WeekFitTheme.meal, label: "RECOVERY PATTERN", title: "Recovery is asking for restraint", subtitle: "5 days in last 30d", takeaway: "Reduce intensity until recovery moves back up.", icon: "chart.line.uptrend.xyaxis", domain: .recovery),
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Training frequency is still building", subtitle: "2 active days this week.", takeaway: "Add consistency before adding intensity.", icon: "figure.run", domain: .activity)
        ],
        hydrationImpact: InsightsCorrelationCard(
            label: "HYDRATION PATTERN",
            title: "Hydration may be helping recovery",
            subtitle: "Higher water days average +8 recovery points.",
            rows: [
                InsightsCorrelationRow(icon: "drop.fill", title: "Water evidence", values: ["0.9L", "1.4L", "1.8L"], color: WeekFitTheme.blue),
                InsightsCorrelationRow(icon: "heart.fill", title: "Recovery", values: ["62", "70", "74"], color: WeekFitTheme.meal)
            ]
        ),
        weeklyReflection: InsightsReflection(
            label: "WEEKLY REFLECTION",
            text: "Hydration is the clearest opportunity. Recovery and activity are present, but drink logging is the pattern to improve first.",
            domain: .hydration
        ),
        dataQuality: InsightsDataQuality(recoveryDays: 7, sleepDays: 7, hydrationDays: 7, mealDays: 7, activityDays: 7, plannerDays: 7)
    )

    static let previewProteinOpportunity = makePreview(
        hero: InsightsHeroInsight(
            label: "AI INSIGHT",
            title: "Protein consistency is limiting recovery insight",
            subtitle: "Logged meals average 74g protein against a 145g target.",
            takeaway: "Hit protein on one more day.",
            icon: "fork.knife",
            accent: WeekFitTheme.meal,
            graphValues: [0.34, 0.44, 0.28, 0.52, 0.40, 0.46, 0.36],
            badgeValue: "74g",
            badgeLabel: "avg protein",
            domain: .nutrition
        ),
        weeklyScores: [
            InsightsMiniScore(icon: "heart.fill", iconColor: WeekFitTheme.meal, title: "Recovery", value: "73", detail: "recovering well"),
            InsightsMiniScore(icon: "moon.fill", iconColor: WeekFitTheme.purple, title: "Sleep", value: "7.0h", detail: "30d enough"),
            InsightsMiniScore(icon: "bolt.fill", iconColor: WeekFitTheme.orange, title: "Training", value: "3", detail: "2h 15m 7d"),
            InsightsMiniScore(icon: "fork.knife", iconColor: WeekFitTheme.blue, title: "Nutrition", value: "Ready", detail: "")
        ],
        trends: [
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Recovery is keeping up with training", subtitle: "3 active days this week with recovery holding steady.", takeaway: "Hold the rhythm; only add load if recovery stays stable.", icon: "figure.run", domain: .activity),
            InsightsTrendCard(accent: WeekFitTheme.purple, label: "SLEEP CONSISTENCY", title: "Sleep rhythm looks stable", subtitle: "Avg 7.0h, range 0.8h", takeaway: "You are close to a solid sleep baseline.", icon: "bed.double.fill", domain: .sleep)
        ],
        hydrationImpact: InsightsCorrelationCard(
            label: "HYDRATION PATTERN",
            title: "Hydration is not the obvious limiter",
            subtitle: "Your logged drink days do not show a recovery difference yet.",
            rows: [
                InsightsCorrelationRow(icon: "drop.fill", title: "Water evidence", values: ["2.0L", "2.1L", "2.0L"], color: WeekFitTheme.blue),
                InsightsCorrelationRow(icon: "heart.fill", title: "Recovery", values: ["72", "74", "73"], color: WeekFitTheme.meal)
            ]
        ),
        weeklyReflection: InsightsReflection(
            label: "WEEKLY REFLECTION",
            text: "Nutrition is the main gap. Sleep and activity are stable enough to make protein intake worth focusing on.",
            domain: .nutrition
        ),
        dataQuality: InsightsDataQuality(recoveryDays: 7, sleepDays: 7, hydrationDays: 7, mealDays: 7, activityDays: 7, plannerDays: 7)
    )

    private static func makePreview(
        hero: InsightsHeroInsight,
        weeklyScores: [InsightsMiniScore],
        trends: [InsightsTrendCard],
        hydrationImpact: InsightsCorrelationCard,
        weeklyReflection: InsightsReflection,
        focusNext: InsightsFocusNext = InsightsFocusNext(
            label: "FOCUS NEXT",
            title: "Keep the pattern going",
            text: "The current data is strong enough to guide the next week without adding more intensity.",
            action: "Repeat the strongest habit and watch recovery.",
            icon: "target",
            accent: WeekFitTheme.orange,
            domain: .consistency
        ),
        dataQuality: InsightsDataQuality
    ) -> InsightsSnapshot {
        InsightsSnapshot(
            avatarInitials: "WF",
            weekDays: ["M", "T", "W", "T", "F", "S", "S"],
            hero: hero,
            weeklyScores: weeklyScores,
            trends: trends,
            hydrationImpact: hydrationImpact,
            weeklyReflection: weeklyReflection,
            focusNext: focusNext,
            dataQuality: dataQuality
        )
    }
}

private struct InsightsPreviewHost: View {
    let snapshot: InsightsSnapshot

    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var healthManager = HealthManager()
    @StateObject private var nutritionViewModel = NutritionViewModel()

    var body: some View {
        InsightsView(authViewModel: authViewModel, previewSnapshot: snapshot)
            .environmentObject(healthManager)
            .environmentObject(nutritionViewModel)
            .modelContainer(for: PlannedActivity.self, inMemory: true)
    }
}

#Preview("Insights - Building") {
    InsightsPreviewHost(snapshot: .fallback)
}

#Preview("Insights - Balanced") {
    InsightsPreviewHost(snapshot: .previewBalanced)
}

#Preview("Insights - Recovery Down") {
    InsightsPreviewHost(snapshot: .previewRecoveryDown)
}

#Preview("Insights - Synced Load") {
    InsightsPreviewHost(snapshot: .previewSyncedTrainingLoad)
}

#Preview("Insights - Hydration Gap") {
    InsightsPreviewHost(snapshot: .previewHydrationGap)
}

#Preview("Insights - Protein Opportunity") {
    InsightsPreviewHost(snapshot: .previewProteinOpportunity)
}
#endif

struct InsightsHeroInsight {
    let label: String
    let title: String
    let subtitle: String
    let takeaway: String
    let icon: String
    let accent: Color
    let graphValues: [Double]
    let badgeValue: String
    let badgeLabel: String
    let domain: InsightsDomain
}

struct InsightsMiniScore: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let detail: String
    let destination: InsightsDetailDestination?

    init(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        detail: String,
        destination: InsightsDetailDestination? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.value = value
        self.detail = detail
        self.destination = destination
    }
}

struct InsightsTrendCard: Identifiable {
    let id = UUID()
    let accent: Color
    let label: String
    let title: String
    let subtitle: String
    let takeaway: String
    let icon: String
    let domain: InsightsDomain
}

struct InsightsCorrelationCard {
    let label: String
    let title: String
    let subtitle: String
    let rows: [InsightsCorrelationRow]
}

struct InsightsCorrelationRow: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let values: [String]
    let color: Color
}

struct InsightsReflection {
    let label: String
    let text: String
    let domain: InsightsDomain
}

struct InsightsFocusNext {
    let label: String
    let title: String
    let text: String
    let action: String
    let icon: String
    let accent: Color
    let domain: InsightsDomain
}

private struct InsightsHeroCandidate {
    let priority: Int
    let insight: InsightsHeroInsight
}

private struct InsightsTrendCandidate {
    let priority: Int
    let card: InsightsTrendCard
}

private struct InsightsSyncedWorkout {
    let id: String
    let startDate: Date
    let durationMinutes: Int
    let activityType: HKWorkoutActivityType
}

@MainActor
final class InsightsViewModel: ObservableObject {

    @Published private(set) var snapshot = InsightsSnapshot.fallback
    @Published private(set) var hasLoadedSnapshot: Bool

    init(
        initialSnapshot: InsightsSnapshot = .fallback,
        hasLoadedSnapshot: Bool = false
    ) {
        snapshot = initialSnapshot
        self.hasLoadedSnapshot = hasLoadedSnapshot
    }

    func refresh(
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        plannedActivities: [PlannedActivity]
    ) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 6, to: today)
        }
        let healthHistoryDates = (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: offset - 29, to: today)
        }

        let metricsByDay: [Date: ActivityMetricsSnapshot]
        let workoutsByDay: [Date: [InsightsSyncedWorkout]]
        if healthManager.isHealthAccessRequested {
            var loaded: [Date: ActivityMetricsSnapshot] = [:]
            var loadedWorkouts: [Date: [InsightsSyncedWorkout]] = [:]
            for date in healthHistoryDates {
                loaded[date] = await healthManager.readActivityMetrics(for: date)
            }

            for date in dates {
                let workouts = await healthManager.loadWorkoutSamples(for: date)
                loadedWorkouts[date] = workouts.map { workout in
                    InsightsSyncedWorkout(
                        id: workout.uuid.uuidString,
                        startDate: workout.startDate,
                        durationMinutes: max(1, Int((workout.duration / 60.0).rounded())),
                        activityType: workout.workoutActivityType
                    )
                }
            }
            metricsByDay = loaded
            workoutsByDay = loadedWorkouts
        } else {
            metricsByDay = Dictionary(uniqueKeysWithValues: healthHistoryDates.map { ($0, ActivityMetricsSnapshot.empty) })
            workoutsByDay = [:]
        }

        let records = dates.map { date in
            let dayActivities = plannedActivities.filter { calendar.isDate($0.date, inSameDayAs: date) }
            return InsightsDayRecord(
                date: date,
                metrics: metricsByDay[date] ?? .empty,
                activities: dayActivities,
                syncedWorkouts: workoutsByDay[date] ?? [],
                todayNutrition: calendar.isDate(date, inSameDayAs: today) ? nutritionViewModel.currentMetrics : nil,
                nutritionGoals: nutritionViewModel.nutritionResult?.goals
            )
        }

        let healthHistoryRecords = healthHistoryDates.map { date in
            InsightsDayRecord(
                date: date,
                metrics: metricsByDay[date] ?? .empty,
                activities: [],
                syncedWorkouts: [],
                todayNutrition: nil,
                nutritionGoals: nutritionViewModel.nutritionResult?.goals
            )
        }

        snapshot = makeSnapshot(
            records: records,
            recoverySleepRecords: healthHistoryRecords,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel
        )
        hasLoadedSnapshot = true
    }

    private func makeSnapshot(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel
    ) -> InsightsSnapshot {
        let calendarWeekDays = records.map { shortWeekday(for: $0.date) }
        let fallback = InsightsSnapshot.fallback
        let dataQuality = makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)
        let hero = makeHero(records: records, recoverySleepRecords: recoverySleepRecords, nutritionViewModel: nutritionViewModel)
        let heroWeekDays = hero.domain == .recovery || hero.domain == .sleep
            ? ["", "", "", "", "", "", ""]
            : calendarWeekDays
        let trends = makeTrends(records: records, recoverySleepRecords: recoverySleepRecords, avoiding: hero.domain)
        let trendDomains = Set(trends.map(\.domain))
        let reflection = makeReflection(
            records: records,
            recoverySleepRecords: recoverySleepRecords,
            nutritionViewModel: nutritionViewModel,
            usedDomains: trendDomains.union([hero.domain])
        )

        return InsightsSnapshot(
            avatarInitials: fallback.avatarInitials,
            weekDays: heroWeekDays,
            hero: hero,
            weeklyScores: makeWeeklyScores(records: records, recoverySleepRecords: recoverySleepRecords),
            trends: trends,
            hydrationImpact: makeHydrationImpact(records: records),
            weeklyReflection: reflection,
            focusNext: makeFocusNext(
                records: records,
                recoverySleepRecords: recoverySleepRecords
            ),
            dataQuality: dataQuality
        )
    }

    private func makeDataQuality(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsDataQuality {
        InsightsDataQuality(
            recoveryDays: recoverySleepRecords.filter { $0.recoveryScore > 0 }.count,
            sleepDays: recoverySleepRecords.filter { $0.sleepMinutes > 0 }.count,
            hydrationDays: records.filter { $0.waterLiters > 0 }.count,
            mealDays: records.filter { $0.mealCount > 0 }.count,
            activityDays: records.filter(\.hasActivitySignal).count,
            plannerDays: records.filter { $0.plannedCount > 0 }.count
        )
    }

    private func makeHero(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        nutritionViewModel: NutritionViewModel
    ) -> InsightsHeroInsight {
        let validRecovery = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let validSleep = recoverySleepRecords.filter { $0.sleepHours > 0 }
        let validNutrition = records.filter { $0.mealCount > 0 }
        let validActivity = records.filter { $0.hasActivitySignal }
        let recoveryValues = normalizedRecoveryValues(Array(validRecovery.suffix(7)))
        var candidates: [InsightsHeroCandidate] = []

        if validRecovery.count >= 7,
           validSleep.count >= 7,
           let today = records.last,
           today.recoveryScore > 0,
           today.sleepHours > 0,
           today.recoveryScore < 55,
           today.sleepHours < 6.5 {
            candidates.append(InsightsHeroCandidate(priority: 10, insight: InsightsHeroInsight(
                label: "AI INSIGHT",
                title: "Sleep is limiting recovery",
                subtitle: "Short sleep and low recovery are showing up together.",
                takeaway: "Protect sleep before adding load.",
                icon: "bed.double.fill",
                accent: WeekFitTheme.purple,
                graphValues: recoveryValues,
                badgeValue: "\(today.recoveryScore)",
                badgeLabel: "recovery",
                domain: .sleep
            )))
        }

        if validRecovery.count >= 7,
           let first = validRecovery.first?.recoveryScore,
           let last = validRecovery.last?.recoveryScore,
           last - first <= -8 {
            candidates.append(InsightsHeroCandidate(priority: 11, insight: InsightsHeroInsight(
                label: "AI INSIGHT",
                title: "Recovery is losing momentum",
                subtitle: "Recovery has dropped recently, so your body may need a lighter block.",
                takeaway: "Treat the next sessions as maintenance.",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: recoveryValues,
                badgeValue: "\(last)",
                badgeLabel: "latest",
                domain: .recovery
            )))
        }

        if validActivity.count == 7, validRecovery.count >= 7 {
            let averageLoad = average(validActivity.map(\.activityLoadScore))
            let averageRecovery = average(validRecovery.map { Double($0.recoveryScore) })
            if averageLoad >= 72, averageRecovery < 68 {
                let activeDays = validActivity.count
                candidates.append(InsightsHeroCandidate(priority: 12, insight: InsightsHeroInsight(
                    label: "AI INSIGHT",
                    title: "Training may be outrunning recovery",
                    subtitle: "\(activeDays) active days this week while recovery is below target.",
                    takeaway: "Hold volume until recovery rebounds.",
                    icon: "figure.run",
                    accent: WeekFitTheme.orange,
                    graphValues: records.map(\.activityLoadGraphValue),
                    badgeValue: "\(activeDays) active days",
                    badgeLabel: "This week",
                    domain: .activity
                )))
            }
        }

        if validNutrition.count == 7, let proteinGoal = records.last?.nutritionGoals?.protein, proteinGoal > 0 {
            let averageProtein = average(validNutrition.map(\.proteinGrams))
            if averageProtein < proteinGoal * 0.65 {
                candidates.append(InsightsHeroCandidate(priority: 20, insight: InsightsHeroInsight(
                    label: "AI INSIGHT",
                    title: "Protein consistency is limiting recovery insight",
                    subtitle: "Protein is too inconsistent to explain recovery changes clearly.",
                    takeaway: "Hit protein on one more day this week.",
                    icon: "fork.knife",
                    accent: WeekFitTheme.meal,
                    graphValues: records.map(\.proteinGraphValue),
                    badgeValue: "\(Int(averageProtein.rounded()))g",
                    badgeLabel: "Protein",
                    domain: .nutrition
                )))
            }
        }

        if validSleep.count >= 7 {
            let averageSleepHours = average(validSleep.map(\.sleepHours))
            candidates.append(InsightsHeroCandidate(priority: 30, insight: InsightsHeroInsight(
                label: "AI INSIGHT",
                title: averageSleepHours >= 7 ? "Sleep is supporting recovery" : "Sleep is your biggest recovery opportunity",
                subtitle: averageSleepHours >= 7
                    ? "Your recent sleep is giving recovery a solid foundation."
                    : "Your recent sleep is under 7 hours, making recovery harder to improve.",
                takeaway: averageSleepHours >= 7
                    ? "Keep sleep timing steady."
                    : "Aim for one more 7+ hour night.",
                icon: "moon.fill",
                accent: WeekFitTheme.purple,
                graphValues: Array(validSleep.suffix(7)).map { sleepScore($0.sleepMinutes) / 100.0 },
                badgeValue: "\(formatOneDecimal(averageSleepHours))h",
                badgeLabel: "Sleep",
                domain: .sleep
            )))
        }

        if validRecovery.count >= 7 {
            let averageRecovery = Int(average(validRecovery.map { Double($0.recoveryScore) }).rounded())
            candidates.append(InsightsHeroCandidate(priority: 31, insight: InsightsHeroInsight(
                label: "AI INSIGHT",
                title: averageRecovery >= 72 ? "Recovery looks resilient" : "Recovery needs a lighter week",
                subtitle: averageRecovery >= 72
                    ? "Recovery is holding up well against your recent routine."
                    : "Recovery is low enough that more training is unlikely to help.",
                takeaway: averageRecovery >= 72
                    ? "Keep the current rhythm."
                    : "Keep the next block easy.",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: recoveryValues,
                badgeValue: "\(averageRecovery)",
                badgeLabel: "Recovery",
                domain: .recovery
            )))
        }

        if let best = candidates.sorted(by: { $0.priority < $1.priority }).first {
            return best.insight
        }

        return missingDataHero(records: records, recoverySleepRecords: recoverySleepRecords)
    }

    private func missingDataHero(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsHeroInsight {
        let quality = makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)

        let unlockCopy: String
        if quality.mealDays < 7 {
            let needed = max(1, 7 - quality.mealDays)
            unlockCopy = "\(needed) more meal \(dayWord(needed)) needed to unlock nutrition trends."
        } else if quality.activityDays < 7 {
            let needed = max(1, 7 - quality.activityDays)
            unlockCopy = "\(needed) more activity \(dayWord(needed)) needed to unlock load patterns."
        } else if quality.recoveryDays < 7 {
            let needed = max(1, 7 - quality.recoveryDays)
            unlockCopy = "\(needed) more recovery \(dayWord(needed)) needed to understand your recovery pattern."
        } else if quality.sleepDays < 7 {
            let needed = max(1, 7 - quality.sleepDays)
            unlockCopy = "\(needed) more \(needed == 1 ? "night" : "nights") needed to understand your sleep pattern."
        } else if quality.hydrationDays < 7 {
            unlockCopy = "Core patterns are forming. More drink logs can add hydration context later."
        } else {
            unlockCopy = "Log sleep, meals, drinks and activities for a few more days to unlock trends."
        }

        return InsightsHeroInsight(
            label: "AI INSIGHT",
            title: "Building your patterns",
            subtitle: unlockCopy,
            takeaway: "Keep logging consistently.",
            icon: "brain.head.profile",
            accent: WeekFitTheme.meal,
            graphValues: InsightsSnapshot.fallback.hero.graphValues,
            badgeValue: "—",
            badgeLabel: "patterns",
            domain: .missingData
        )
    }

    private func makeWeeklyScores(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> [InsightsMiniScore] {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let activityRecords = records.filter(\.hasActivitySignal)
        let proteinRecords = records.filter { $0.proteinGrams > 0 }

        let recoveryAverage = average(recoveryRecords.map { Double($0.recoveryScore) })
        let averageSleepHours = average(sleepRecords.map(\.sleepHours))
        let activeDays = activityRecords.count
        let proteinGoal = records.last?.nutritionGoals?.protein ?? 0
        let proteinTargetDays = proteinGoal > 0
            ? proteinRecords.filter { $0.proteinGrams >= proteinGoal }.count
            : proteinRecords.count

        return [
            weeklyMetric(
                icon: "heart.fill",
                iconColor: WeekFitTheme.meal,
                title: "Recovery",
                value: recoveryRecords.count >= 7
                    ? (recoveryAverage >= 72 ? "Strong" : (recoveryAverage >= 65 ? "Okay" : "Low"))
                    : "Building",
                detail: "",
                missingDetail: "",
                destination: .recovery
            ),
            weeklyMetric(
                icon: "moon.fill",
                iconColor: WeekFitTheme.purple,
                title: "Sleep",
                value: sleepRecords.count >= 7
                    ? (averageSleepHours >= 7 ? "Enough" : "Low")
                    : "Building",
                detail: "",
                missingDetail: "",
                destination: .recovery
            ),
            weeklyMetric(
                icon: "bolt.fill",
                iconColor: WeekFitTheme.orange,
                title: "Training",
                value: activeDays >= 4
                    ? "Stable"
                    : (activeDays > 0 ? "Building" : "Missing"),
                detail: "",
                missingDetail: "",
                destination: .activity
            ),
            weeklyMetric(
                icon: "fork.knife",
                iconColor: WeekFitTheme.blue,
                title: "Nutrition",
                value: proteinRecords.count == 7
                    ? (proteinGoal > 0 && proteinTargetDays >= 4 ? "Ready" : "Low")
                    : "Missing",
                detail: "",
                missingDetail: "",
                destination: .nutrition
            )
        ]
    }

    private func makeTrends(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        avoiding heroDomain: InsightsDomain
    ) -> [InsightsTrendCard] {
        [
            makeTrainingRecoveryInsight(records: records, recoverySleepRecords: recoverySleepRecords),
            makeNutritionInsight(records: records, recoverySleepRecords: recoverySleepRecords)
        ]
    }

    private func makeTrainingRecoveryInsight(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsTrendCard {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let activityRecords = records.filter(\.hasActivitySignal)
        let activeDays = activityRecords.count
        let averageRecovery = average(recoveryRecords.map { Double($0.recoveryScore) })

        guard activityRecords.count == 7 else {
            return InsightsTrendCard(
                accent: WeekFitTheme.orange,
                label: "TRAINING & RECOVERY",
                title: "Training pattern is not complete yet",
                subtitle: "Complete or sync activity for the full 7 days.",
                takeaway: "Once training is complete, Insights can judge whether load matches recovery.",
                icon: "figure.run",
                domain: .activity
            )
        }

        guard recoveryRecords.count >= 7 else {
            return InsightsTrendCard(
                accent: WeekFitTheme.orange,
                label: "TRAINING & RECOVERY",
                title: "Activity is logged, but recovery context is missing",
                subtitle: "\(activeDays) active days this week.",
                takeaway: "Recovery history is needed before changing load.",
                icon: "figure.run",
                domain: .activity
            )
        }

        if averageRecovery >= 72 {
            return InsightsTrendCard(
                accent: WeekFitTheme.orange,
                label: "TRAINING & RECOVERY",
                title: "Recovery is keeping up with training",
                subtitle: "\(activeDays) active days this week with recovery holding steady.",
                takeaway: "Maintain this rhythm before adding more intensity.",
                icon: "figure.run",
                domain: .activity
            )
        }

        return InsightsTrendCard(
            accent: WeekFitTheme.orange,
            label: "TRAINING & RECOVERY",
            title: "Training may need a lighter week",
            subtitle: "\(activeDays) active days while recovery is below target.",
            takeaway: "Reduce intensity until recovery moves back up.",
            icon: "figure.run",
            domain: .activity
        )
    }

    private func makeNutritionInsight(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsTrendCard {
        let nutritionRecords = records.filter { $0.mealCount > 0 }
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let proteinGoal = records.last?.nutritionGoals?.protein ?? 0
        let proteinTargetDays = proteinGoal > 0
            ? nutritionRecords.filter { $0.proteinGrams >= proteinGoal }.count
            : 0

        guard nutritionRecords.count == 7 else {
            let needed = max(1, 7 - nutritionRecords.count)
            return InsightsTrendCard(
                accent: WeekFitTheme.meal,
                label: "NUTRITION INSIGHT",
                title: "Not enough nutrition data",
                subtitle: "Log meals on \(needed) more \(dayWord(needed)) so food can be compared with recovery.",
                takeaway: "Start with consistent meal logging.",
                icon: "fork.knife",
                domain: .nutrition
            )
        }

        if proteinGoal > 0, proteinTargetDays < 4 {
            return InsightsTrendCard(
                accent: WeekFitTheme.meal,
                label: "NUTRITION INSIGHT",
                title: "Protein consistency is limiting recovery insight",
                subtitle: "\(proteinTargetDays) days met protein target in the last 7 days.",
                takeaway: "Hit protein more consistently before changing training.",
                icon: "fork.knife",
                domain: .nutrition
            )
        }

        if recoveryRecords.count >= 7 {
            return InsightsTrendCard(
                accent: WeekFitTheme.meal,
                label: "NUTRITION INSIGHT",
                title: "Nutrition is supporting recovery insight",
                subtitle: proteinGoal > 0 ? "Protein was on target \(proteinTargetDays) days this week." : "Meal logging was consistent this week.",
                takeaway: "Keep meal logging steady while training changes.",
                icon: "fork.knife",
                domain: .nutrition
            )
        }

        return InsightsTrendCard(
            accent: WeekFitTheme.meal,
            label: "NUTRITION INSIGHT",
            title: "Nutrition consistency is improving",
            subtitle: proteinGoal > 0 ? "Protein was on target \(proteinTargetDays) days this week." : "Meal logging was consistent this week.",
            takeaway: "Keep food logging steady while recovery history builds.",
            icon: "fork.knife",
            domain: .nutrition
        )
    }

    private func makeHydrationImpact(records: [InsightsDayRecord]) -> InsightsCorrelationCard {
        let paired = records.filter { $0.waterLiters > 0 && $0.recoveryScore > 0 }
        let hydrationValues = lastThreeValues(records.map(\.waterLiters), formatter: formatLiters)
        let recoveryValues = lastThreeValues(records.map { Double($0.recoveryScore) }, formatter: { value in
            value > 0 ? "\(Int(value.rounded()))" : "—"
        })

        let rows = [
            InsightsCorrelationRow(icon: "drop.fill", title: "Water evidence", values: hydrationValues, color: WeekFitTheme.blue),
            InsightsCorrelationRow(icon: "heart.fill", title: "Recovery context", values: recoveryValues, color: WeekFitTheme.meal)
        ]

        guard paired.count == 7 else {
            let needed = max(1, 7 - paired.count)
            return InsightsCorrelationCard(
                label: "HYDRATION INSIGHT",
                title: "Hydration insight unavailable",
                subtitle: "Log drinks on \(needed) more \(dayWord(needed)) in the last 7 days to compare with recovery.",
                rows: rows
            )
        }

        let sorted = paired.sorted { $0.waterLiters < $1.waterLiters }
        let splitIndex = sorted.count / 2
        let lower = Array(sorted.prefix(splitIndex))
        let higher = Array(sorted.suffix(sorted.count - splitIndex))

        guard lower.count >= 2, higher.count >= 2 else {
            return InsightsCorrelationCard(
                label: "HYDRATION INSIGHT",
                title: "Hydration needs a cleaner sample",
                subtitle: "The last 7 days have logs, but not enough contrast to compare recovery.",
                rows: rows
            )
        }

        let lowerRecovery = average(lower.map { Double($0.recoveryScore) })
        let higherRecovery = average(higher.map { Double($0.recoveryScore) })
        let difference = Int((higherRecovery - lowerRecovery).rounded())

        if abs(difference) < 5 {
            return InsightsCorrelationCard(
                label: "HYDRATION INSIGHT",
                title: "Hydration is not the obvious limiter",
                subtitle: "Last 7 days do not show a meaningful recovery difference.",
                rows: rows
            )
        }

        return InsightsCorrelationCard(
            label: "HYDRATION INSIGHT",
            title: difference > 0
                ? "Hydration may be helping recovery"
                : "Hydration is not the recovery limiter",
            subtitle: difference > 0
                ? "In the last 7 days, higher-water days averaged +\(difference) recovery."
                : "Higher-water days did not improve recovery in this 7-day sample.",
            rows: rows
        )
    }

    private func makeReflection(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        nutritionViewModel: NutritionViewModel,
        usedDomains: Set<InsightsDomain>
    ) -> InsightsReflection {
        let recoveryDays = recoverySleepRecords.filter { $0.recoveryScore > 0 }.count
        let sleepDays = recoverySleepRecords.filter { $0.sleepMinutes > 0 }.count
        let hydrationDays = records.filter { $0.waterLiters > 0 }.count
        let mealDays = records.filter { $0.mealCount > 0 }.count
        let activityDays = records.filter(\.hasActivitySignal).count

        guard recoveryDays >= 2 || sleepDays >= 2 || hydrationDays >= 2 || mealDays >= 2 || activityDays >= 2 else {
            return InsightsSnapshot.fallback.weeklyReflection
        }

        let domainCounts: [(domain: InsightsDomain, name: String, count: Int, target: Int)] = [
            (.recovery, "recovery", recoveryDays, 7),
            (.sleep, "sleep", sleepDays, 7),
            (.hydration, "hydration", hydrationDays, 7),
            (.nutrition, "nutrition", mealDays, 7),
            (.activity, "activity", activityDays, 7)
        ]

        if let unlock = domainCounts
            .filter({ $0.count < $0.target && !usedDomains.contains($0.domain) })
            .sorted(by: { ($0.target - $0.count) > ($1.target - $1.count) })
            .first {
            let needed = max(1, unlock.target - unlock.count)
            return InsightsReflection(
                label: "WEEKLY REFLECTION",
                text: "\(strongestDomainName(from: domainCounts).capitalized) is currently the clearest signal. \(needed) more \(unlock.name) \(needed == 1 ? "day" : "days") will make the next coaching pattern more reliable.",
                domain: unlock.domain
            )
        }

        if let coachInsight = nutritionViewModel.nutritionResult?.activeInsights.first,
           let coachDomain = domain(for: coachInsight),
           !usedDomains.contains(coachDomain) {
            return InsightsReflection(
                label: "WEEKLY REFLECTION",
                text: "The strongest pattern supports the same theme Coach is watching now: \(coachInsight.title). Use Insights for the pattern, Coach for the next immediate step.",
                domain: coachDomain
            )
        }

        let strongest = strongestDomainName(from: domainCounts)
        return InsightsReflection(
            label: "WEEKLY REFLECTION",
            text: "\(strongest.capitalized) is the clearest pattern. The rest of the screen explains whether that signal is supported by training, nutrition and hydration consistency.",
            domain: .missingData
        )
    }

    private func makeFocusNext(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsFocusNext {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let nutritionRecords = records.filter { $0.mealCount > 0 }
        let activityRecords = records.filter(\.hasActivitySignal)
        let recoveryAverage = average(recoveryRecords.map { Double($0.recoveryScore) })
        let sleepAverage = average(sleepRecords.map(\.sleepHours))
        let proteinGoal = records.last?.nutritionGoals?.protein ?? 0
        let proteinTargetDays = proteinGoal > 0
            ? nutritionRecords.filter { $0.proteinGrams >= proteinGoal }.count
            : 0

        if sleepRecords.count >= 7, sleepAverage > 0, sleepAverage < 7 {
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Prioritize sleep before more volume",
                text: "Sleep has been under 7 hours recently. Better sleep is more likely to help recovery than extra training.",
                action: "Aim for one more 7h+ night this week.",
                icon: "moon.zzz.fill",
                accent: WeekFitTheme.purple,
                domain: .sleep
            )
        }

        if recoveryRecords.count >= 7, recoveryAverage > 0, recoveryAverage < 68 {
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Let recovery catch up",
                text: "Recovery is low enough that adding more training is unlikely to help right now.",
                action: "Keep the next training block easy.",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                domain: .recovery
            )
        }

        if nutritionRecords.count < 7 {
            let needed = max(1, 7 - nutritionRecords.count)
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Make nutrition visible",
                text: "Meal logging is too inconsistent to connect food with recovery yet.",
                action: "Log meals on \(needed) more \(dayWord(needed)).",
                icon: "fork.knife",
                accent: WeekFitTheme.meal,
                domain: .nutrition
            )
        }

        if proteinGoal > 0, proteinTargetDays < 4 {
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Make protein more consistent",
                text: "Protein is inconsistent enough that recovery changes are harder to explain.",
                action: "Hit protein on at least 4 days next week.",
                icon: "takeoutbag.and.cup.and.straw.fill",
                accent: WeekFitTheme.meal,
                domain: .nutrition
            )
        }

        if activityRecords.count < 7 {
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Build training consistency first",
                text: "Training is not logged consistently enough to judge load yet.",
                action: "Log or sync activity for the full week.",
                icon: "figure.run",
                accent: WeekFitTheme.orange,
                domain: .activity
            )
        }

        if recoveryAverage >= 72 {
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Current load looks sustainable",
                text: "Recovery is stable and your recent routine looks manageable.",
                action: "Repeat the week or add only a small load bump.",
                icon: "checkmark.seal.fill",
                accent: WeekFitTheme.meal,
                domain: .consistency
            )
        }

        return InsightsFocusNext(
            label: "FOCUS NEXT",
            title: "Keep building the picture",
            text: "One more consistent week will make the next recommendation clearer.",
            action: "Keep logging sleep, food, drinks and activity.",
            icon: "sparkles",
            accent: WeekFitTheme.orange,
            domain: .missingData
        )
    }

    private func weeklyMetric(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        detail: String,
        missingDetail: String,
        destination: InsightsDetailDestination?
    ) -> InsightsMiniScore {
        guard value != "—" else {
            return InsightsMiniScore(
                icon: icon,
                iconColor: iconColor,
                title: title,
                value: "—",
                detail: missingDetail,
                destination: destination
            )
        }

        return InsightsMiniScore(
            icon: icon,
            iconColor: iconColor,
            title: title,
            value: value,
            detail: detail,
            destination: destination
        )
    }

    private func normalizedRecoveryValues(_ records: [InsightsDayRecord]) -> [Double] {
        records.map { record in
            record.recoveryScore > 0 ? Double(record.recoveryScore) / 100.0 : 0.18
        }
    }

    private func sleepScore(_ minutes: Int) -> Double {
        guard minutes > 0 else { return 0 }
        return clamp(Double(minutes) / 480.0) * 100.0
    }

    private func lastThreeValues(_ values: [Double], formatter: (Double) -> String) -> [String] {
        let suffix = Array(values.suffix(3))
        return suffix.map { $0 > 0 ? formatter($0) : "—" }
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func formatHours(_ hours: Double) -> String {
        guard hours > 0 else { return "—" }
        return "\(String(format: "%.1f", hours))h"
    }

    private func formatLiters(_ liters: Double) -> String {
        guard liters > 0 else { return "—" }
        return "\(String(format: "%.1f", liters))L"
    }

    private func formatOneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formatDuration(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let remainder = safeMinutes % 60

        if hours > 0, remainder > 0 {
            return "\(hours)h \(remainder)m"
        }

        if hours > 0 {
            return "\(hours)h"
        }

        return "\(safeMinutes)m"
    }

    private func dayWord(_ count: Int) -> String {
        count == 1 ? "day" : "days"
    }

    private func strongestDomainName(
        from domainCounts: [(domain: InsightsDomain, name: String, count: Int, target: Int)]
    ) -> String {
        domainCounts
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.target < rhs.target
                }

                return lhs.count > rhs.count
            }
            .first?.name ?? "patterns"
    }

    private func domain(for insight: DynamicInsight) -> InsightsDomain? {
        if insight.tags.contains(.hydration) { return .hydration }
        if insight.tags.contains(.protein) || insight.tags.contains(.carbs) || insight.tags.contains(.digestion) {
            return .nutrition
        }
        if insight.tags.contains(.recovery) { return .recovery }
        if insight.tags.contains(.sleep) { return .sleep }
        if insight.tags.contains(.consistency) || insight.tags.contains(.schedule) { return .consistency }
        return nil
    }

    private func shortWeekday(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1)).uppercased()
    }
}

private struct InsightsDayRecord {
    let date: Date
    let metrics: ActivityMetricsSnapshot
    let activities: [PlannedActivity]
    let syncedWorkouts: [InsightsSyncedWorkout]
    let todayNutrition: DailyNutritionMetrics?
    let nutritionGoals: NutritionGoals?

    var recoveryScore: Int { metrics.recoveryPercent }
    var sleepMinutes: Int { metrics.sleepMinutes }
    var sleepHours: Double { metrics.sleepHours }

    var waterLiters: Double {
        if let todayNutrition {
            return max(todayNutrition.waterLiters, plannedWaterLiters)
        }

        return plannedWaterLiters
    }

    var waterGoal: Double {
        nutritionGoals?.waterLiters ?? 0
    }

    var mealCount: Int {
        completedNutritionActivities.count
    }

    var proteinGrams: Double {
        if let todayNutrition {
            return max(todayNutrition.protein, plannedProteinGrams)
        }

        return plannedProteinGrams
    }

    var calories: Double {
        if let todayNutrition {
            return max(todayNutrition.calories, plannedCalories)
        }

        return plannedCalories
    }

    var proteinGraphValue: Double {
        if let proteinGoal = nutritionGoals?.protein, proteinGoal > 0 {
            return min(max(proteinGrams / proteinGoal, 0.12), 0.92)
        }

        return mealCount > 0 ? min(max(Double(mealCount) / 4.0, 0.12), 0.92) : 0.12
    }

    var hasActivitySignal: Bool {
        metrics.activeCalories > 0 || metrics.exerciseMinutes > 0 || metrics.steps > 0 || completedWorkoutCount > 0
    }

    var completedWorkoutCount: Int {
        completedWorkoutActivities.count + unmatchedSyncedWorkouts.count
    }

    var completedWorkoutMinutes: Int {
        completedWorkoutActivities.reduce(0) { $0 + $1.effectiveDurationMinutes } +
            unmatchedSyncedWorkouts.reduce(0) { $0 + $1.durationMinutes }
    }

    private var completedWorkoutActivities: [PlannedActivity] {
        activities.filter { activity in
            activity.isCompleted &&
            !activity.isSkipped &&
            activity.timelineEventKind == .workout
        }
    }

    private var unmatchedSyncedWorkouts: [InsightsSyncedWorkout] {
        syncedWorkouts.filter { workout in
            !completedWorkoutActivities.contains { activity in
                isLikelySameWorkout(activity: activity, workout: workout)
            }
        }
    }

    private func isLikelySameWorkout(
        activity: PlannedActivity,
        workout: InsightsSyncedWorkout
    ) -> Bool {
        guard activity.timelineEventKind == .workout else { return false }
        let closeStart = abs(activity.date.timeIntervalSince(workout.startDate)) <= 2 * 60 * 60
        return closeStart
    }

    var activityLoadScore: Double {
        let caloriesScore = min(metrics.activeCalories / 650.0, 1.0)
        let exerciseScore = min(Double(metrics.exerciseMinutes) / 60.0, 1.0)
        let stepsScore = min(Double(metrics.steps) / 10_000.0, 1.0)
        let plannedWorkoutScore = min(Double(completedWorkoutCount) / 2.0, 1.0)
        let base = max(caloriesScore, exerciseScore, stepsScore, plannedWorkoutScore)
        return base * 100.0
    }

    var activityLoadGraphValue: Double {
        hasActivitySignal ? min(max(activityLoadScore / 100.0, 0.12), 0.92) : 0.12
    }

    var plannedCount: Int {
        activities.filter { $0.blocksPlannerTime }.count
    }

    private var plannedWaterLiters: Double {
        let waterLogs = activities.filter { activity in
            activity.isCompleted &&
            !activity.isSkipped &&
            (activity.imageName == "hydration" || activity.source.lowercased() == "waterlog")
        }

        return Double(waterLogs.count) * 0.25
    }

    private var completedNutritionActivities: [PlannedActivity] {
        activities.filter { activity in
            activity.isCompleted &&
            !activity.isSkipped &&
            activity.imageName != "hydration" &&
            (activity.type.lowercased() == "meal" || activity.type.lowercased() == "drink")
        }
    }

    private var plannedProteinGrams: Double {
        Double(completedNutritionActivities.reduce(0) { $0 + $1.protein })
    }

    private var plannedCalories: Double {
        Double(completedNutritionActivities.reduce(0) { $0 + $1.calories })
    }
}

struct InsightsView: View {

    @ObservedObject var authViewModel: AuthViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]
    @StateObject private var viewModel: InsightsViewModel
    @StateObject private var userSettings = WeekFitUserSettings.shared
    @State private var showContent = false
    @State private var showProfile = false
    @State private var selectedDetail: InsightsDetailDestination?
    @State private var nutritionDetailsDate = Date()

    private let usesFixedSnapshot: Bool

    private let cardBackground = WeekFitTheme.cardBackground
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let elevatedCard = WeekFitTheme.elevatedCard

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText

    private let softShadow = WeekFitTheme.cardShadow

    private var snapshot: InsightsSnapshot {
        viewModel.snapshot
    }

    private var shouldShowSnapshotContent: Bool {
        usesFixedSnapshot || viewModel.hasLoadedSnapshot
    }

    init(
        authViewModel: AuthViewModel,
        previewSnapshot: InsightsSnapshot? = nil
    ) {
        self.authViewModel = authViewModel
        usesFixedSnapshot = previewSnapshot != nil
        _viewModel = StateObject(
            wrappedValue: InsightsViewModel(
                initialSnapshot: previewSnapshot ?? .fallback,
                hasLoadedSnapshot: previewSnapshot != nil
            )
        )
    }

    private var refreshSignature: String {
        [
            "\(plannedActivities.count)",
            "\(plannedActivities.filter(\.isCompleted).count)",
            "\(plannedActivities.filter(\.isSkipped).count)",
            "\(Int(healthManager.activeCalories.rounded()))",
            "\(healthManager.sleepMinutes)",
            "\(healthManager.recoveryPercent)",
            "\(String(format: "%.1f", nutritionViewModel.currentMetrics?.waterLiters ?? 0))",
            nutritionViewModel.coachStateRefreshID.uuidString
        ].joined(separator: "|")
    }

    var body: some View {
        ZStack(alignment: .top) {
            WeekFitTheme.appBackground
                .ignoresSafeArea()
            ambientBackground

            WeekFitScreenContainer {
                WeekFitScreenHeader(
                    title: "Insights",
                    subtitle: "What matters most",
                    initials: userSettings.profileInitials,
                    showAvatar: true
                ) {
                    showProfile = true
                }
            } content: {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        heroInsightCard
                        weeklyScoresSection
                        trendsSection
                        focusNextCard
                    }
                    .padding(.bottom, 95)
                    .opacity(showContent && shouldShowSnapshotContent ? 1 : 0)
                    .offset(y: showContent && shouldShowSnapshotContent ? 0 : 14)
                }
            }
            .padding(.bottom, 95)
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            showContent = true
        }
        .task(id: refreshSignature) {
            guard !usesFixedSnapshot else { return }

            await viewModel.refresh(
                healthManager: healthManager,
                nutritionViewModel: nutritionViewModel,
                plannedActivities: plannedActivities
            )
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
        }
        .fullScreenCover(item: $selectedDetail) { destination in
            detailView(for: destination)
        }
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [
                    WeekFitTheme.meal.opacity(0.075),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 320
            )

            RadialGradient(
                colors: [
                    WeekFitTheme.blue.opacity(0.04),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 70,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func detailView(for destination: InsightsDetailDestination) -> some View {
        switch destination {
        case .activity:
            ActivityIntelligenceView(
                selectedDate: Date(),
                healthManager: healthManager,
                plannedActivities: plannedActivities
            )

        case .nutrition:
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

        case .recovery:
            RecoveryDetailsView(
                selectedDate: Date(),
                recoveryScore: healthManager.recoveryPercent,
                recoveryBreakdown: healthManager.recoveryBreakdown
            )
        }
    }

    private var proteinGoal: Double { nutritionViewModel.nutritionResult?.goals.protein ?? 153.0 }
    private var carbsGoal: Double { nutritionViewModel.nutritionResult?.goals.carbs ?? 330.0 }
    private var fatsGoal: Double { nutritionViewModel.nutritionResult?.goals.fats ?? 90.0 }
    private var fiberGoal: Double { nutritionViewModel.nutritionResult?.goals.fiber ?? 35.0 }

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

    private func nutritionFiber(for date: Date) -> Double {
        Double(nutritionMeals(for: date).reduce(0) { $0 + $1.fiber })
    }
}

// MARK: - Hero

private extension InsightsView {

    var heroInsightCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    WeekFitTheme.meal.opacity(0.075),
                    WeekFitTheme.blue.opacity(0.04),
                    elevatedCard.opacity(0.92),
                    cardBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WeekFitTheme.meal.opacity(0.10))
                .frame(width: 96, height: 96)
                .blur(radius: 24)
                .offset(x: 260, y: 8)

            Circle()
                .fill(WeekFitTheme.blue.opacity(0.055))
                .frame(width: 120, height: 120)
                .blur(radius: 32)
                .offset(x: -36, y: 134)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))

                    Text(snapshot.hero.label)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(snapshot.hero.accent.opacity(0.86))

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(snapshot.hero.title)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(snapshot.hero.subtitle)
                            .font(.system(size: 13.2, weight: .semibold))
                            .foregroundStyle(textSecondary.opacity(0.82))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(snapshot.hero.takeaway)
                            .font(.system(size: 12.4, weight: .bold))
                            .foregroundStyle(snapshot.hero.accent.opacity(0.92))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    heroMetricBadge
                }

                Spacer(minLength: 0)

                heroGraph
            }
            .padding(17)
        }
        .frame(minHeight: 286)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.75), radius: 18, y: 9)
    }

    var heroGraph: some View {
        VStack(spacing: 7) {
            HStack {
                Text(heroGraphLabel)
                    .font(.system(size: 9.4, weight: .bold))
                    .tracking(0.25)
                    .foregroundStyle(textSecondary.opacity(0.72))

                Spacer(minLength: 0)
            }

            GeometryReader { geo in
                ZStack {
                    Path { path in
                        let values = normalizedGraphValues(snapshot.hero.graphValues)
                        guard !values.isEmpty else { return }
                        let w = geo.size.width
                        let h = geo.size.height
                        let step = values.count > 1 ? w / CGFloat(values.count - 1) : 0

                        for index in values.indices {
                            let point = CGPoint(
                                x: CGFloat(index) * step,
                                y: h * CGFloat(1 - values[index])
                            )

                            if index == values.startIndex {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(
                        snapshot.hero.accent.opacity(0.72),
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                    )

                    let values = normalizedGraphValues(snapshot.hero.graphValues)
                    ForEach(values.indices, id: \.self) { index in
                        heroDot(index: index, values: values, geo: geo)
                    }

                }
            }
            .frame(height: 64)

            HStack(spacing: 0) {
                ForEach(snapshot.weekDays.indices, id: \.self) { index in
                    Text(snapshot.weekDays[index])
                        .font(.system(size: 8.8, weight: .medium))
                        .foregroundStyle(textSecondary.opacity(0.78))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    var heroGraphLabel: String {
        switch snapshot.hero.domain {
        case .sleep:
            return "Sleep hours (recent nights)"
        case .recovery:
            return "Recovery trend (recent days)"
        case .activity:
            return "Active days this week"
        case .nutrition:
            return "Protein progress this week"
        case .hydration:
            return "Hydration logged this week"
        case .consistency, .missingData:
            return "Pattern building"
        }
    }

    var heroMetricBadge: some View {
        VStack(alignment: .trailing, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: snapshot.hero.icon)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(snapshot.hero.accent.opacity(0.88))

                Text(snapshot.hero.badgeLabel)
                    .font(.system(size: 9.4, weight: .bold))
                    .foregroundStyle(textSecondary.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(snapshot.hero.badgeValue)
                .font(.system(size: 17.5, weight: .bold))
                .foregroundStyle(textPrimary.opacity(0.96))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(width: 118, alignment: .trailing)
        .frame(minHeight: 58, alignment: .trailing)
        .background(Color.white.opacity(0.050))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    func heroDot(index: Int, values: [Double], geo: GeometryProxy) -> some View {
        let step = values.count > 1 ? geo.size.width / CGFloat(values.count - 1) : 0
        let x = CGFloat(index) * step
        let y = geo.size.height * CGFloat(1 - values[index])

        return Circle()
            .fill(textPrimary.opacity(0.88))
            .frame(width: 7.5, height: 7.5)
            .overlay {
                Circle()
                    .stroke(snapshot.hero.accent.opacity(0.72), lineWidth: 1.6)
            }
            .position(x: x, y: y)
    }

    func normalizedGraphValues(_ values: [Double]) -> [Double] {
        let fallback = InsightsSnapshot.fallback.hero.graphValues
        return (values.isEmpty ? fallback : values).map { min(max($0, 0.08), 0.92) }
    }

}

// MARK: - Weekly Scores

private extension InsightsView {

    var weeklyScoresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key signals")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(textPrimary)

            HStack(spacing: 8) {
                ForEach(snapshot.weeklyScores.indices, id: \.self) { index in
                    let score = snapshot.weeklyScores[index]
                    Button {
                        guard let destination = score.destination else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if destination == .nutrition {
                            nutritionDetailsDate = Date()
                        }
                        selectedDetail = destination
                    } label: {
                        insightMiniCard(
                            icon: score.icon,
                            iconColor: score.iconColor,
                            title: score.title,
                            value: score.value,
                            detail: score.detail
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(score.destination == nil)
                }
            }
        }
    }

    func insightMiniCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.11))
                    .frame(width: 29, height: 29)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor.opacity(0.80))
            }

            Spacer(minLength: 2)

            Text(title)
                .font(.system(size: 10.8, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(.system(size: 17.5, weight: .bold))
                .foregroundStyle(textPrimary.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 8.8, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 76)
        .padding(7)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardSecondary.opacity(0.76),
                            cardBackground.opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.55), radius: 9, y: 4)
    }
}

// MARK: - Trends

private extension InsightsView {

    var trendsSection: some View {
        VStack(spacing: 10) {
            ForEach(snapshot.trends.indices, id: \.self) { index in
                let trend = snapshot.trends[index]
                trendCard(
                    accent: trend.accent,
                    label: trend.label,
                    title: trend.title,
                    subtitle: trend.subtitle,
                    takeaway: trend.takeaway,
                    icon: trend.icon
                )
            }
        }
    }

    func trendCard(
        accent: Color,
        label: String,
        title: String,
        subtitle: String,
        takeaway: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(label)
                        .font(.system(size: 9.2, weight: .bold))
                        .foregroundStyle(accent.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(title)
                        .font(.system(size: 13.2, weight: .bold))
                        .foregroundStyle(textPrimary.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 10.4, weight: .semibold))
                        .foregroundStyle(textSecondary.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.11))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(accent.opacity(0.82))
                }
            }

            Spacer(minLength: 10)

            trendTakeawayPanel(accent: accent, text: takeaway)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 152)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.055),
                            cardBackground.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.65), radius: 10, y: 5)
    }

    func trendTakeawayPanel(accent: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(accent.opacity(0.84))
                .frame(width: 18, height: 18)
                .background(Circle().fill(accent.opacity(0.10)))

            Text(text)
                .font(.system(size: 10.6, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.82))
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .background(accent.opacity(0.045))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.032), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

}

// MARK: - Correlation

private extension InsightsView {

    var hydrationCorrelationCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.hydrationImpact.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WeekFitTheme.blue.opacity(0.78))

                Text(snapshot.hydrationImpact.title)
                    .font(.system(size: 13.3, weight: .bold))
                    .foregroundStyle(textPrimary.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)

                Text(snapshot.hydrationImpact.subtitle)
                    .font(.system(size: 10.4, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.76))
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(snapshot.hydrationImpact.rows.indices, id: \.self) { index in
                    let row = snapshot.hydrationImpact.rows[index]
                    compactCorrelationRow(
                        icon: row.icon,
                        title: row.title,
                        values: row.values,
                        color: row.color
                    )
                }
            }
            .frame(width: 162, alignment: .top)
            .offset(y: -2)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardSecondary.opacity(0.82),
                            cardBackground.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.65), radius: 10, y: 5)
    }

    func compactCorrelationRow(
        icon: String,
        title: String,
        values: [String],
        color: Color
    ) -> some View {
        HStack(alignment: .center, spacing: 9) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.11))
                    .frame(width: 24, height: 24)

                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(color.opacity(0.82))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 9.8, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(0.92))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }

                HStack(spacing: 0) {
                    ForEach(values.indices, id: \.self) { index in
                        Text(values[index])
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(textSecondary.opacity(0.76))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

// MARK: - Reflection

private extension InsightsView {

    var weeklyReflectionCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                Text(snapshot.weeklyReflection.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WeekFitTheme.orange.opacity(0.78))

                Text(snapshot.weeklyReflection.text)
                    .font(.system(size: 11.8, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.78))
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 3)

            mountainVisual
                .frame(width: 118, height: 74)
        }
        .padding(13)
        .frame(minHeight: 112)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.orange.opacity(0.055),
                            cardBackground.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.65), radius: 10, y: 5)
    }

    var focusNextCard: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(snapshot.focusNext.accent.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: snapshot.focusNext.icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(snapshot.focusNext.accent.opacity(0.86))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.focusNext.label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.35)
                    .foregroundStyle(snapshot.focusNext.accent.opacity(0.78))

                Text(snapshot.focusNext.title)
                    .font(.system(size: 14.4, weight: .bold))
                    .foregroundStyle(textPrimary.opacity(0.96))
                    .fixedSize(horizontal: false, vertical: true)

                Text(snapshot.focusNext.text)
                    .font(.system(size: 11.3, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.78))
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)

                Text(snapshot.focusNext.action)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(snapshot.focusNext.accent.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 128)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            snapshot.focusNext.accent.opacity(0.070),
                            cardBackground.opacity(0.97)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(snapshot.focusNext.accent.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.65), radius: 10, y: 5)
    }

    var mountainVisual: some View {
        ZStack {
            LinearGradient(
                colors: [
                    WeekFitTheme.orange.opacity(0.10),
                    WeekFitTheme.meal.opacity(0.075)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WeekFitTheme.orange.opacity(0.16))
                .frame(width: 34, height: 34)
                .offset(x: 14, y: -8)

            Path { path in
                path.move(to: CGPoint(x: 0, y: 54))
                path.addCurve(to: CGPoint(x: 40, y: 29), control1: CGPoint(x: 14, y: 42), control2: CGPoint(x: 27, y: 30))
                path.addCurve(to: CGPoint(x: 80, y: 52), control1: CGPoint(x: 55, y: 28), control2: CGPoint(x: 65, y: 47))
                path.addCurve(to: CGPoint(x: 118, y: 24), control1: CGPoint(x: 94, y: 55), control2: CGPoint(x: 106, y: 34))
                path.addLine(to: CGPoint(x: 118, y: 74))
                path.addLine(to: CGPoint(x: 0, y: 74))
                path.closeSubpath()
            }
            .fill(WeekFitTheme.meal.opacity(0.18))

            Path { path in
                path.move(to: CGPoint(x: 0, y: 60))
                path.addCurve(to: CGPoint(x: 44, y: 48), control1: CGPoint(x: 15, y: 57), control2: CGPoint(x: 30, y: 46))
                path.addCurve(to: CGPoint(x: 86, y: 60), control1: CGPoint(x: 60, y: 50), control2: CGPoint(x: 68, y: 64))
                path.addCurve(to: CGPoint(x: 118, y: 44), control1: CGPoint(x: 100, y: 57), control2: CGPoint(x: 108, y: 48))
                path.addLine(to: CGPoint(x: 118, y: 74))
                path.addLine(to: CGPoint(x: 0, y: 74))
                path.closeSubpath()
            }
            .fill(Color.black.opacity(0.16))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        }
    }
}
