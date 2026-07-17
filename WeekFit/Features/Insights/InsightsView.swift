import SwiftUI
import SwiftData
import HealthKit
internal import Combine

#if DEBUG
extension InsightsSnapshot {

    static let previewBalanced = makePreview(
        hero: InsightsHeroInsight(
            label: "MAIN INSIGHT",
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
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Recovery is keeping up with training", subtitle: "Moderate weekly volume is being absorbed without a recovery drop.", takeaway: "Hold the rhythm; only add load if recovery stays stable.", icon: "figure.run", domain: .activity),
            InsightsTrendCard(accent: WeekFitTheme.meal, label: "NUTRITION PATTERN", title: "Nutrition data is strong enough to coach from", subtitle: "5 logged days • 118g avg protein", takeaway: "Use protein consistency to interpret recovery changes.", icon: "fork.knife", domain: .nutrition)
        ],
        hydrationImpact: InsightsCorrelationCard(
            label: "HYDRATION PATTERN",
            title: "Hydration is not the obvious limiter",
            subtitle: "Recent paired logs do not show a meaningful recovery difference.",
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
            label: "MAIN INSIGHT",
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
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Training may need restraint", subtitle: "Recent workload is not being absorbed cleanly while recovery is below target.", takeaway: "Keep the next workout lighter if recovery keeps dropping.", icon: "figure.run", domain: .activity),
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
            label: "MAIN INSIGHT",
            title: "Training may be outrunning recovery",
            subtitle: "Weekly workload is high while recovery is below target.",
            takeaway: "Hold volume until recovery rebounds.",
            icon: "figure.run",
            accent: WeekFitTheme.orange,
            graphValues: [0.28, 0.82, 0.34, 0.78, 0.72, 0.88, 0.64],
            badgeValue: "high",
            badgeLabel: "weekly load",
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
            label: "MAIN INSIGHT",
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
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Training volume is still building", subtitle: "Weekly activity is still below a meaningful base-building load.", takeaway: "Add total work before adding intensity.", icon: "figure.run", domain: .activity)
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
            label: "MAIN INSIGHT",
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
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Recovery is keeping up with training", subtitle: "Current weekly volume is being absorbed without a recovery drop.", takeaway: "Hold the rhythm; only add load if recovery stays stable.", icon: "figure.run", domain: .activity),
            InsightsTrendCard(accent: WeekFitTheme.purple, label: "SLEEP CONSISTENCY", title: "Sleep rhythm looks stable", subtitle: "You are close to a repeatable sleep rhythm.", takeaway: "Keep the same bedtime rhythm.", icon: "bed.double.fill", domain: .sleep)
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

    static let previewCoachPlanAdjustment = makePreview(
        hero: InsightsHeroInsight(
            label: "MAIN INSIGHT",
            title: "Activity load is rising faster than recovery",
            subtitle: "Recent 7-day load is high while recovery is below the previous baseline.",
            takeaway: "Spread intensity across the next week and compare recovery.",
            icon: "bolt.shield.fill",
            accent: WeekFitTheme.purple,
            graphValues: [0.72, 0.80, 0.86, 0.76, 0.68, 0.62, 0.58],
            badgeValue: "high",
            badgeLabel: "load",
            domain: .activity,
            actionDestination: .detail(.activity)
        ),
        weeklyScores: [
            InsightsMiniScore(icon: "heart.fill", iconColor: WeekFitTheme.meal, title: "Recovery", value: "Low", detail: "62 avg"),
            InsightsMiniScore(icon: "moon.fill", iconColor: WeekFitTheme.purple, title: "Sleep", value: "Low", detail: "6.4h avg"),
            InsightsMiniScore(icon: "bolt.fill", iconColor: WeekFitTheme.orange, title: "Training", value: "High", detail: "5/7 days"),
            InsightsMiniScore(icon: "fork.knife", iconColor: WeekFitTheme.blue, title: "Nutrition", value: "Ready", detail: "6/7 logged")
        ],
        trends: [
            InsightsTrendCard(accent: WeekFitTheme.meal, label: "RECOVERY TREND", title: "Recovery is trending down", subtitle: "Recent 7 days average 62 vs 71 across the previous baseline. Latest is 58.", takeaway: "Hold volume until the recent average rebounds.", icon: "chart.line.uptrend.xyaxis", domain: .recovery, actionDestination: .detail(.recovery)),
            InsightsTrendCard(accent: WeekFitTheme.orange, label: "ACTIVITY LOAD", title: "Load is ahead of recovery", subtitle: "This week is high compared with your recent pattern while recovery is softer.", takeaway: "Spread intensity across the week before adding more.", icon: "figure.run", domain: .activity, actionDestination: .detail(.activity))
        ],
        hydrationImpact: InsightsCorrelationCard(
            label: "HYDRATION INSIGHT",
            title: "Hydration is supporting context",
            subtitle: "Drink logs are present, but load and recovery are the main story.",
            rows: [
                InsightsCorrelationRow(icon: "drop.fill", title: "Water evidence", values: ["2.0L", "2.2L", "1.9L"], color: WeekFitTheme.blue),
                InsightsCorrelationRow(icon: "heart.fill", title: "Recovery context", values: ["66", "63", "58"], color: WeekFitTheme.meal)
            ]
        ),
        weeklyReflection: InsightsReflection(
            label: "WEEKLY REFLECTION",
            text: "Activity is the strongest pressure in this pattern. Recovery is the limiter to watch over the next week.",
            domain: .activity,
            actionDestination: .detail(.activity)
        ),
        focusNext: InsightsFocusNext(
            label: "WATCH NEXT",
            title: "Spread intensity",
            text: "The useful experiment is a steadier training week, then comparing recovery the next morning.",
            action: "Review recovery after harder days.",
            icon: "bolt.shield.fill",
            accent: WeekFitTheme.purple,
            domain: .activity,
            actionTitle: "Open activity",
            actionDestination: .detail(.activity)
        ),
        dataQuality: InsightsDataQuality(recoveryDays: 24, sleepDays: 24, hydrationDays: 7, mealDays: 6, activityDays: 7, plannerDays: 7)
    )

    static let insightScenarioLibrary: [InsightScenario] = [
        galleryScenario(
            insightClass: .sleepOpportunity,
            triggerConditions: ["Sleep stays below target while recovery has enough history to compare against sleep changes."],
            title: "Sleep debt is limiting recovery",
            subtitle: "Recovery drops when sleep gets shorter than your usual range.",
            takeaway: "Test one earlier night before changing training.",
            icon: "moon.fill",
            accent: WeekFitTheme.purple,
            domain: .sleep,
            visualization: .trendLine(values: [0.70, 0.64, 0.58, 0.62, 0.54, 0.50, 0.56], target: 0.72, targetLabel: "usual range"),
            badgeValue: "6.3h",
            badgeLabel: "avg sleep",
            learning: "Recovery is most sensitive after the shortest nights, not after every hard day."
        ),
        galleryScenario(
            insightClass: .recoveryTrend,
            triggerConditions: ["Weekly training volume becomes one of the busier recent weeks while recovery remains stable."],
            title: "Recovery remains strong despite load",
            subtitle: "Despite one of your busiest recent weeks, readiness stayed inside your normal range.",
            takeaway: "Hold the rhythm before adding intensity.",
            icon: "heart.fill",
            accent: WeekFitTheme.meal,
            domain: .recovery,
            visualization: .correlation(primary: [0.70, 0.74, 0.78, 0.77, 0.80, 0.76, 0.79], secondary: [0.42, 0.58, 0.66, 0.64, 0.72, 0.69, 0.75], primaryLabel: "recovery", secondaryLabel: "load"),
            badgeValue: "79",
            badgeLabel: "recovery",
            learning: "Your current volume is closer to an advanced amateur week than a casual fitness week, and recovery is still absorbing it."
        ),
        galleryScenario(
            insightClass: .trainingFrequency,
            triggerConditions: ["Weekly activity volume is below a meaningful base-building threshold while recovery has capacity."],
            title: "Training volume is your biggest opportunity",
            subtitle: "You have enough recovery room, but total activity volume is still below a base-building week.",
            takeaway: "Add one low-risk hour first.",
            icon: "figure.run",
            accent: WeekFitTheme.orange,
            domain: .activity,
            visualization: .consistency(values: [true, false, false, true, false, false, false], positiveLabel: "active", negativeLabel: "open"),
            badgeValue: "2/7",
            badgeLabel: "training base",
            learning: "The missing signal is total weekly work, not motivation or another recovery day."
        ),
        galleryScenario(
            insightClass: .nutritionQuality,
            triggerConditions: ["Meal completeness and protein quality are weaker than sleep, recovery and training context."],
            title: "Nutrition quality is limiting adaptation",
            subtitle: "Protein and meal completeness are the weakest support signals around workouts.",
            takeaway: "Anchor protein around workouts.",
            icon: "fork.knife",
            accent: WeekFitTheme.blue,
            domain: .nutrition,
            visualization: .contributionBreakdown(segments: [
                InsightContribution(label: "protein", value: 0.42, color: WeekFitTheme.blue),
                InsightContribution(label: "fiber", value: 0.24, color: WeekFitTheme.meal),
                InsightContribution(label: "timing", value: 0.18, color: WeekFitTheme.orange)
            ]),
            badgeValue: "low",
            badgeLabel: "protein hit",
            learning: "Food logging is strongest on rest days, so training-day nutrition remains the blind spot."
        ),
        galleryScenario(
            insightClass: .hydrationPattern,
            triggerConditions: ["Hydration separates recovery only on higher-load days, not across all recent days."],
            title: "Hydration only matters on high-load days",
            subtitle: "Drink intake is not a broad limiter, but it separates recovery after harder sessions.",
            takeaway: "Prioritize fluids around hard training.",
            icon: "drop.fill",
            accent: WeekFitTheme.blue,
            domain: .hydration,
            visualization: .comparison(primaryLabel: "high load", primaryValue: "+7 rec", secondaryLabel: "easy days", secondaryValue: "+1 rec", delta: "load response"),
            badgeValue: "2.1L",
            badgeLabel: "avg water",
            learning: "Hydration does not need top-level focus every day; it earns attention when load is high."
        ),
        galleryScenario(
            insightClass: .weekendBehavior,
            triggerConditions: ["Weekday sleep is stable while weekend timing creates the largest recovery swing."],
            title: "Weekend sleep is reducing weekly recovery",
            subtitle: "Weekdays are stable, but weekend timing creates the largest readiness swing.",
            takeaway: "Protect wake time before adding volume.",
            icon: "calendar",
            accent: WeekFitTheme.purple,
            domain: .sleep,
            visualization: .weeklyPattern(values: [0.76, 0.78, 0.74, 0.77, 0.73, 0.48, 0.52], labels: ["M", "T", "W", "T", "F", "S", "S"]),
            badgeValue: "-9",
            badgeLabel: "weekend dip",
            learning: "The problem is not average sleep alone; the weekend pattern is what disturbs the week."
        ),
        galleryScenario(
            insightClass: .overtrainingRisk,
            triggerConditions: ["Training load rises while recovery and sleep trend in the opposite direction."],
            title: "Overtraining risk is building",
            subtitle: "Load is climbing while recovery and sleep move in the opposite direction.",
            takeaway: "Make the next session restorative.",
            icon: "exclamationmark.triangle.fill",
            accent: WeekFitTheme.orange,
            domain: .activity,
            visualization: .correlation(primary: [0.78, 0.74, 0.70, 0.66, 0.62, 0.58, 0.55], secondary: [0.36, 0.44, 0.52, 0.64, 0.72, 0.80, 0.86], primaryLabel: "recovery", secondaryLabel: "load"),
            badgeValue: "rising",
            badgeLabel: "risk",
            learning: "The issue appears when training rises faster than recovery can follow."
        ),
        galleryScenario(
            insightClass: .restDayEffectiveness,
            triggerConditions: ["Full rest is followed by stronger next-day recovery than active recovery sessions."],
            title: "Rest days are working better than active recovery",
            subtitle: "Full rest is followed by stronger recovery than low-intensity movement this month.",
            takeaway: "Use true rest after hard blocks.",
            icon: "bed.double.fill",
            accent: WeekFitTheme.meal,
            domain: .recovery,
            visualization: .comparison(primaryLabel: "rest day", primaryValue: "+8", secondaryLabel: "active rec", secondaryValue: "+3", delta: "next-day"),
            badgeValue: "+8",
            badgeLabel: "rest effect",
            learning: "Your recovery response favors fewer inputs after hard work, not simply easier movement."
        ),
        galleryScenario(
            insightClass: .consistency,
            triggerConditions: ["Sleep duration is adequate but bedtime timing varies enough to explain readiness swings."],
            title: "Bedtime consistency is the cleaner lever",
            subtitle: "Sleep duration varies less than sleep timing, making timing the more useful target.",
            takeaway: "Keep bedtime inside a 45-minute window.",
            icon: "clock.fill",
            accent: WeekFitTheme.purple,
            domain: .consistency,
            visualization: .distribution(values: [0.20, 0.32, 0.72, 0.84, 0.64, 0.36, 0.22], highlightIndex: 3),
            badgeValue: "82m",
            badgeLabel: "timing range",
            learning: "The variation is clustered around timing, so chasing more sleep may not be the first move."
        ),
        galleryScenario(
            insightClass: .proteinDeficiency,
            triggerConditions: ["Protein intake is moving toward target and is becoming reliable enough to interpret."],
            title: "Protein intake is improving",
            subtitle: "Recent meals are moving toward target often enough to change recovery interpretation.",
            takeaway: "Repeat the last three logged days.",
            icon: "fork.knife",
            accent: WeekFitTheme.blue,
            domain: .nutrition,
            visualization: .trendLine(values: [0.36, 0.42, 0.48, 0.56, 0.66, 0.74, 0.82], target: 0.80, targetLabel: "target"),
            badgeValue: "near",
            badgeLabel: "target",
            learning: "Nutrition is becoming explanatory data, not just logging coverage."
        ),
        galleryScenario(
            insightClass: .hrvTrend,
            triggerConditions: ["HRV or recovery-marker trend reverses upward after a lighter block."],
            title: "HRV trend is turning up",
            subtitle: "Recovery markers reversed after a lighter block and steadier sleep.",
            takeaway: "Avoid interrupting the rebound.",
            icon: "waveform.path.ecg",
            accent: WeekFitTheme.meal,
            domain: .recovery,
            visualization: .trendChange(
                before: [0.56, 0.50, 0.46, 0.42],
                after: [0.44, 0.52, 0.60, 0.68],
                label: "trend reversal"
            ),
            badgeValue: "turning up",
            badgeLabel: "HRV",
            learning: "The useful signal is the reversal, not the absolute value today."
        ),
        galleryScenario(
            insightClass: .activeCalorieTrend,
            triggerConditions: ["Active calorie trend declines while recovery remains normal enough to rule out fatigue."],
            title: "Active calories are trending down",
            subtitle: "Movement is declining while recovery is normal, pointing to consistency rather than fatigue.",
            takeaway: "Restore easy movement first.",
            icon: "flame.fill",
            accent: WeekFitTheme.orange,
            domain: .activity,
            visualization: .trendLine(values: [0.82, 0.76, 0.70, 0.66, 0.58, 0.52, 0.44], target: 0.62, targetLabel: "usual level"),
            badgeValue: "down",
            badgeLabel: "calories",
            learning: "Recovery does not explain the drop, so this looks behavioral rather than readiness-driven."
        ),
        galleryScenario(
            insightClass: .cardioFitness,
            triggerConditions: ["Training load is too varied to separate cardio fitness trend from session selection."],
            title: "Cardio fitness needs a clearer signal",
            subtitle: "Workout variety is hiding whether the same cardio load is becoming easier to absorb.",
            takeaway: "Repeat one benchmark session weekly.",
            icon: "lungs.fill",
            accent: WeekFitTheme.orange,
            domain: .activity,
            visualization: .distribution(values: [0.30, 0.72, 0.44, 0.86, 0.28, 0.58, 0.36], highlightIndex: nil),
            badgeValue: "mixed",
            badgeLabel: "signal",
            learning: "The limitation is comparability: different session types are hiding whether recovery and output are improving at the same workload."
        ),
        galleryScenario(
            insightClass: .stressAccumulation,
            triggerConditions: ["Consecutive high-load days are followed by lower recovery despite adequate sleep."],
            title: "Stress accumulation is visible",
            subtitle: "Recovery is lower after consecutive high-load days even when sleep is adequate.",
            takeaway: "Break up hard sessions.",
            icon: "bolt.heart.fill",
            accent: WeekFitTheme.orange,
            domain: .recovery,
            visualization: .relationshipGraph(
                primary: [0.82, 0.78, 0.72, 0.64, 0.61, 0.68, 0.74],
                secondary: [0.30, 0.48, 0.66, 0.84, 0.80, 0.42, 0.36],
                insightLabel: "inverse pattern"
            ),
            badgeValue: "3 days",
            badgeLabel: "stacked",
            learning: "Sleep is not the explanation here; consecutive load is the pattern that changes recovery."
        ),
        galleryScenario(
            insightClass: .recoveryResilience,
            triggerConditions: ["Recovery rebounds faster after hard days than it did earlier in the comparison window."],
            title: "Recovery resilience is improving",
            subtitle: "Recovery rebounds faster after hard days than it did earlier in the month.",
            takeaway: "Progress load gradually.",
            icon: "arrow.up.heart.fill",
            accent: WeekFitTheme.meal,
            domain: .recovery,
            visualization: .comparison(primaryLabel: "now", primaryValue: "1 day", secondaryLabel: "before", secondaryValue: "3 days", delta: "faster"),
            badgeValue: "1 day",
            badgeLabel: "rebound",
            learning: "The improvement is resilience after stress, not just a higher average score."
        ),
        galleryScenario(
            insightClass: .behaviorChange,
            triggerConditions: ["Routine consistency drifts across weeks as evening activity moves later."],
            title: "Seasonal routine drift is starting",
            subtitle: "Weekday consistency is slipping as evening activity moves later.",
            takeaway: "Protect one anchor habit.",
            icon: "sun.max.fill",
            accent: WeekFitTheme.purple,
            domain: .consistency,
            visualization: .weeklyPattern(values: [0.78, 0.74, 0.68, 0.60, 0.54, 0.50, 0.48], labels: ["W1", "W2", "W3", "W4", "W5", "W6", "W7"]),
            badgeValue: "drifting",
            badgeLabel: "routine",
            learning: "The pattern spans weeks, so a daily fix will be less useful than a repeatable anchor."
        ),
        galleryScenario(
            insightClass: .missingData,
            triggerConditions: ["Core signals are too sparse to explain cause, but the missing source is identifiable."],
            title: "Data quality is the main insight",
            subtitle: "Signals are too sparse to explain cause, but the missing source is clear.",
            takeaway: "Log meals around workouts first.",
            icon: "questionmark.diamond.fill",
            accent: WeekFitTheme.meal,
            domain: .missingData,
            visualization: .signalStrength(strength: 0.42, label: "building the picture"),
            badgeValue: "low",
            badgeLabel: "read",
            learning: "The missing information is specific: nutrition around workouts, not overall app usage."
        ),
        galleryScenario(
            insightClass: .loadManagement,
            triggerConditions: ["Total training volume is stable but hard efforts are clustered too tightly."],
            title: "Training volume is stable but intensity is not",
            subtitle: "Total work looks normal, but hard efforts are clustered too tightly.",
            takeaway: "Spread intensity across the week.",
            icon: "speedometer",
            accent: WeekFitTheme.orange,
            domain: .activity,
            visualization: .weeklyPattern(values: [0.30, 0.86, 0.32, 0.82, 0.78, 0.28, 0.24], labels: ["M", "T", "W", "T", "F", "S", "S"]),
            badgeValue: "3 hard",
            badgeLabel: "clustered",
            learning: "Volume alone would miss this; the pattern is intensity placement."
        ),
        galleryScenario(
            insightClass: .plateau,
            triggerConditions: ["Recovery improves, then flattens while previous support signals continue improving."],
            title: "Recovery trend has flattened",
            subtitle: "Recent improvements stalled even though sleep and food logs improved.",
            takeaway: "Look for the next constraint.",
            icon: "chart.line.flattrend.xyaxis",
            accent: WeekFitTheme.meal,
            domain: .recovery,
            visualization: .trendChange(
                before: [0.58, 0.66, 0.72, 0.74],
                after: [0.74, 0.73, 0.74, 0.73],
                label: "flattening"
            ),
            badgeValue: "flat",
            badgeLabel: "trend",
            learning: "The plateau says the first fixes worked, but another limiter has become more important."
        ),
        galleryScenario(
            insightClass: .trainingConsistency,
            triggerConditions: ["Moderate weekly volume is distributed better than isolated hard efforts, producing steadier recovery."],
            title: "Consistency beats intensity this week",
            subtitle: "Moderate volume spread across the week correlated with steadier recovery than isolated hard workouts.",
            takeaway: "Choose repeatability over heroic effort.",
            icon: "repeat",
            accent: WeekFitTheme.orange,
            domain: .consistency,
            visualization: .consistency(values: [true, true, false, true, false, true, false], positiveLabel: "on-plan", negativeLabel: "missed"),
            badgeValue: "4/7",
            badgeLabel: "on-plan",
            learning: "The pattern rewards workload distribution more than peak session difficulty."
        ),
        galleryScenario(
            insightClass: .trendReversal,
            triggerConditions: ["A declining recovery trend reverses after load is reduced and sleep steadies."],
            title: "Recovery trend has reversed",
            subtitle: "The direction changed after a lighter block, making the rebound more important than today’s score.",
            takeaway: "Hold the lighter rhythm long enough to confirm it.",
            icon: "arrow.triangle.2.circlepath",
            accent: WeekFitTheme.meal,
            domain: .recovery,
            visualization: .trendChange(
                before: [0.62, 0.56, 0.50, 0.46],
                after: [0.48, 0.56, 0.64, 0.70],
                label: "direction changed"
            ),
            badgeValue: "up",
            badgeLabel: "direction",
            learning: "The important discovery is the inflection point, not the absolute recovery score."
        ),
        galleryScenario(
            insightClass: .nutritionQuality,
            triggerConditions: ["Late meal timing is followed by lower sleep quality even when duration is similar."],
            title: "Late meals are affecting sleep quality",
            subtitle: "Nights after late dinners show lower sleep quality even when duration is similar.",
            takeaway: "Move dinner earlier twice this week.",
            icon: "fork.knife.circle.fill",
            accent: WeekFitTheme.blue,
            domain: .nutrition,
            visualization: .comparison(primaryLabel: "early meal", primaryValue: "82", secondaryLabel: "late meal", secondaryValue: "71", delta: "sleep quality"),
            badgeValue: "-11",
            badgeLabel: "quality",
            learning: "Duration is hiding the signal; quality changes with meal timing."
        ),
        galleryScenario(
            insightClass: .missingData,
            triggerConditions: ["Recovery and activity are present, but sleep coverage is too thin for confident causality."],
            title: "The best signal is still missing",
            subtitle: "Recovery and activity are present, but sleep coverage is too thin for confident causality.",
            takeaway: "Prioritize sleep sync/logging.",
            icon: "sensor.tag.radiowaves.forward.fill",
            accent: WeekFitTheme.purple,
            domain: .missingData,
            visualization: .consistency(values: [true, false, false, true, false, true, false], positiveLabel: "sleep logged", negativeLabel: "missing"),
            badgeValue: "3/7",
            badgeLabel: "sleep data",
            learning: "The app can describe what happened, but not why, until sleep overlaps with recovery."
        )
    ]

    static let galleryScenarios: [InsightsSnapshot] = insightScenarioLibrary.map(\.snapshot)

    private static func galleryScenario(
        insightClass: InsightScenarioClass,
        triggerConditions: [String],
        title: String,
        subtitle: String,
        takeaway: String,
        icon: String,
        accent: Color,
        domain: InsightsDomain,
        visualization: InsightVisualization,
        badgeValue: String,
        badgeLabel: String,
        learning: String
    ) -> InsightScenario {
        let hero = InsightsHeroInsight(
                label: "MAIN INSIGHT",
                title: title,
                subtitle: subtitle,
                takeaway: takeaway,
                timeframe: "Synthetic scenario",
                icon: icon,
                accent: accent,
                graphValues: [0.42, 0.48, 0.54, 0.60, 0.56, 0.64, 0.70],
                visualization: visualization,
                badgeValue: badgeValue,
                badgeLabel: badgeLabel,
                domain: domain
        )

        let evidence = InsightsEvidence(
            label: "WHY IT MATTERS",
            confidenceLabel: domain == .missingData ? "Building" : "High",
            confidenceValue: domain == .missingData ? 0.48 : 0.82,
            sourceSummary: "The read should explain what changed, why it matters, and what to try next.",
            recencyText: "Coaching scenario",
            bullets: [
                triggerConditions.joined(separator: " "),
                "The visual should make the story obvious without turning into analytics.",
                "Support cards must add new context instead of repeating the hero."
            ]
        )

        let learnings = [
            InsightsLearning(
                label: "EXPECTED LEARNING",
                title: "A separate pattern explains the read",
                text: learning,
                icon: "sparkles",
                accent: accent,
                domain: domain
            )
        ]

        let supportCards = [
            InsightSupportCard(
                role: supportRole(for: hero.insightType),
                domain: supportDomain(for: hero.insightType),
                title: "Coach context",
                text: learning,
                icon: icon,
                accent: accent,
                metrics: [
                    InsightTrendMetric(
                        label: "Where you are",
                        value: badgeValue,
                        direction: .stable,
                        detail: "current read",
                        benchmark: "what changed recently"
                    ),
                    InsightTrendMetric(
                        label: "Direction",
                        value: "steady",
                        direction: .stable,
                        detail: "holding steady",
                        benchmark: "watch the response"
                    )
                ]
            )
        ]

        let opportunity = InsightsOpportunity(
            label: "EXPECTED OPPORTUNITY",
            title: takeaway,
            text: "Use the highest-leverage next step implied by this scenario, without introducing a second competing recommendation.",
            icon: "target",
            accent: accent,
            domain: domain,
            actionDestination: nil
        )

        return InsightScenario(
            id: insightClass.rawValue + "." + title.replacingOccurrences(of: " ", with: "-").lowercased(),
            insightClass: insightClass,
            name: title,
            triggerConditions: triggerConditions,
            expectedHero: hero,
            expectedVisualizationType: visualization.kind,
            expectedEvidence: evidence,
            expectedSupportCards: supportCards,
            expectedLearnings: learnings,
            expectedOpportunity: opportunity,
            dataQuality: InsightsDataQuality(recoveryDays: 7, sleepDays: 7, hydrationDays: 7, mealDays: 7, activityDays: 7, plannerDays: 7)
        )
    }

    private static func supportRole(for type: InsightType) -> InsightSupportRole {
        switch type {
        case .sleep:
            return .strongestPattern
        case .training:
            return .workload
        case .recovery:
            return .resilience
        case .nutrition:
            return .bottleneck
        case .hydration:
            return .relationship
        case .consistency:
            return .progression
        case .missingData:
            return .opportunity
        }
    }

    private static func supportDomain(for type: InsightType) -> InsightsDomain {
        switch type {
        case .sleep:
            return .sleep
        case .training:
            return .activity
        case .recovery:
            return .recovery
        case .nutrition:
            return .nutrition
        case .hydration:
            return .hydration
        case .consistency:
            return .consistency
        case .missingData:
            return .missingData
        }
    }

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
    @StateObject private var coachCoordinator = CoachCoordinator()
    @StateObject private var coachInputProvider = CoachInputProvider()

    var body: some View {
        InsightsView(authViewModel: authViewModel, previewSnapshot: snapshot)
            .environmentObject(healthManager)
            .environmentObject(nutritionViewModel)
            .environmentObject(coachCoordinator)
            .environmentObject(coachInputProvider)
            .modelContainer(for: PlannedActivity.self, inMemory: true)
    }
}

private struct InsightsGalleryPreview: View {
    private let columns = [
        GridItem(.fixed(360), spacing: 18),
        GridItem(.fixed(360), spacing: 18)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: 18) {
                ForEach(InsightsSnapshot.insightScenarioLibrary) { scenario in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(scenario.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(WeekFitTheme.primaryText.opacity(0.84))
                            .lineLimit(1)

                        Text("\(scenario.insightClass.rawValue) • \(scenario.expectedVisualizationType.rawValue)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.62))
                            .lineLimit(1)

                        InsightsPreviewHost(snapshot: scenario.snapshot)
                            .frame(width: 360, height: 720)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    }
                }
            }
            .padding(24)
        }
        .background(WeekFitTheme.appBackground)
        .preferredColorScheme(.dark)
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

#Preview("Insights - Load Rising") {
    InsightsPreviewHost(snapshot: .previewCoachPlanAdjustment)
}

#Preview("Insights Gallery") {
    InsightsGalleryPreview()
}
#endif

private struct InsightsHeroCandidate {
    let priority: Int
    let insight: InsightsHeroInsight
}

private struct InsightsTrendCandidate {
    let priority: Int
    let card: InsightsTrendCard
}

struct InsightsSyncedWorkout {
    let id: String
    let startDate: Date
    let durationMinutes: Int
    let activityType: HKWorkoutActivityType
}

@MainActor
final class InsightsViewModel: ObservableObject {
    // MainActorDeinitStabilization: TaskLocal bad-free on sync @MainActor XCTest teardown (see MainActorDeinitStabilization.swift).

    nonisolated deinit {}

    @Published private(set) var snapshot = InsightsSnapshot.fallback
    @Published private(set) var hasLoadedSnapshot: Bool

    private struct InsightsStoryCandidate {
        let id: String
        let impactScore: Double
        let confidence: Double
        let trend: InsightsHeroInsight
        let driver: InsightSupportCard
        let action: InsightsFocusNext

        var evidence: InsightsEvidence {
            InsightsEvidence(
                label: "WHY THIS STORY",
                confidenceLabel: Self.confidenceLabel(for: confidence),
                confidenceValue: confidence,
                sourceSummary: "Impact score \(Int(impactScore.rounded()))/100",
                recencyText: trend.timeframe,
                bullets: [
                    driver.text,
                    action.action
                ]
            )
        }

        var displayStory: InsightsStory {
            InsightsStory(
                id: id,
                impactScore: impactScore,
                trend: trend,
                driver: driver,
                action: action,
                evidence: evidence
            )
        }

        private static func confidenceLabel(for confidence: Double) -> String {
            switch confidence {
            case 0.78...:
                return "High Confidence"
            case 0.55..<0.78:
                return "Medium Confidence"
            default:
                return "Low Confidence"
            }
        }
    }

    init(
        initialSnapshot: InsightsSnapshot? = nil,
        hasLoadedSnapshot: Bool = false
    ) {
        snapshot = initialSnapshot ?? .fallback
        self.hasLoadedSnapshot = hasLoadedSnapshot
    }

    func refresh(
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        plannedActivities: [PlannedActivity],
        coachContext: InsightsCoachContext?
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
            let dayActivities = plannedActivities.filter { calendar.isDate($0.date, inSameDayAs: date) }
            return InsightsDayRecord(
                date: date,
                metrics: metricsByDay[date] ?? .empty,
                activities: dayActivities,
                syncedWorkouts: [],
                todayNutrition: calendar.isDate(date, inSameDayAs: today) ? nutritionViewModel.currentMetrics : nil,
                nutritionGoals: nutritionViewModel.nutritionResult?.goals
            )
        }

        snapshot = makeSnapshot(
            records: records,
            recoverySleepRecords: healthHistoryRecords,
            healthManager: healthManager,
            nutritionViewModel: nutritionViewModel,
            coachContext: coachContext
        )
        hasLoadedSnapshot = true
    }

    private func makeSnapshot(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        healthManager: HealthManager,
        nutritionViewModel: NutritionViewModel,
        coachContext: InsightsCoachContext?
    ) -> InsightsSnapshot {
        let calendarWeekDays = records.map { shortWeekday(for: $0.date) }
        let fallback = InsightsSnapshot.fallback
        let dataQuality = makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)
        let storyCandidates = InsightsStoryEngine.topStories(
            records: records,
            recoverySleepRecords: recoverySleepRecords,
            dataQuality: dataQuality
        )
        let stories = storyCandidates.map(\.displayStory)
        let story = storyCandidates.first ?? InsightsStoryEngine.fallbackStory(records: records, recoverySleepRecords: recoverySleepRecords, dataQuality: dataQuality)
        let domainPages = InsightsDomainIntelligenceEngine.pages(
            records: records,
            recoverySleepRecords: recoverySleepRecords,
            dataQuality: dataQuality
        )
        let hero = story.trend
        let heroWeekDays = hero.domain == .recovery || hero.domain == .sleep
            ? ["", "", "", "", "", "", ""]
            : calendarWeekDays
        let evidence = story.evidence
        let supportCards = [story.driver]
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
            stories: stories,
            domainPages: domainPages,
            evidence: evidence,
            whyItems: [],
            nextActions: [],
            supportCards: supportCards,
            learnings: makeLearnings(
                records: records,
                recoverySleepRecords: recoverySleepRecords,
                dataQuality: dataQuality,
                hero: hero
            ),
            opportunity: makeOpportunity(
                records: records,
                recoverySleepRecords: recoverySleepRecords,
                hero: hero,
                coachContext: coachContext
            ),
            weeklyScores: makeWeeklyScores(records: records, recoverySleepRecords: recoverySleepRecords),
            trends: trends,
            hydrationImpact: makeHydrationImpact(records: records),
            weeklyReflection: reflection,
            focusNext: story.action,
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

    private func makeTopStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality
    ) -> InsightsStoryCandidate {
        if let winner = makeTopStories(
            records: records,
            recoverySleepRecords: recoverySleepRecords,
            dataQuality: dataQuality
        ).first {
            return winner
        }

        return fallbackStory(records: records, recoverySleepRecords: recoverySleepRecords, dataQuality: dataQuality)
    }

    private func makeTopStories(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality
    ) -> [InsightsStoryCandidate] {
        let ranked = makeStoryCandidates(
            records: records,
            recoverySleepRecords: recoverySleepRecords
        )
        .sorted { lhs, rhs in
            if lhs.impactScore != rhs.impactScore {
                return lhs.impactScore > rhs.impactScore
            }
            return lhs.confidence > rhs.confidence
        }

        guard !ranked.isEmpty else {
            return [fallbackStory(records: records, recoverySleepRecords: recoverySleepRecords, dataQuality: dataQuality)]
        }

        var selected: [InsightsStoryCandidate] = []
        var usedDomains: Set<InsightsDomain> = []

        for story in ranked {
            guard !usedDomains.contains(story.trend.domain) else { continue }
            selected.append(story)
            usedDomains.insert(story.trend.domain)

            if selected.count == 2 {
                break
            }
        }

        return selected.isEmpty ? Array(ranked.prefix(1)) : selected
    }

    private func fallbackStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality
    ) -> InsightsStoryCandidate {
        if hasEnoughStableContext(dataQuality) {
            let hero = noMajorChangeHero(records: records, recoverySleepRecords: recoverySleepRecords)
            let driver = InsightSupportCard(
                role: .strongestPattern,
                domain: .consistency,
                title: "No dominant driver",
                text: "No signal changed enough to earn hero placement.",
                icon: "checkmark.seal.fill",
                accent: hero.accent,
                metrics: [
                    InsightTrendMetric(label: "Story", value: "stable", direction: .stable, detail: "no anomaly", benchmark: "30-day review")
                ]
            )
            let action = InsightsFocusNext(
                label: "ACTION",
                title: "Maintain the current routine",
                text: "No major risk or opportunity is visible in the current 30-day pattern.",
                action: "Do not increase training volume by more than 10% over the next 7 days.",
                icon: hero.icon,
                accent: hero.accent,
                domain: .consistency,
                actionTitle: "Open Coach",
                actionDestination: .tab(.coach)
            )
            return InsightsStoryCandidate(
                id: "stable.no_major_change",
                impactScore: 35,
                confidence: confidence(from: dataQuality),
                trend: hero,
                driver: driver,
                action: action
            )
        }

        let hero = missingDataHero(records: records, recoverySleepRecords: recoverySleepRecords)
        let driver = InsightSupportCard(
            role: .strongestPattern,
            domain: .missingData,
            title: "Insufficient overlap",
            text: "Insights needs more overlapping sleep, recovery, training and nutrition data before ranking stories.",
            icon: "sparkles",
            accent: hero.accent,
            metrics: [
                InsightTrendMetric(label: "Read", value: "building", direction: .stable, detail: "not enough data", benchmark: "complete 7 days")
            ]
        )
        let action = InsightsFocusNext(
            label: "ACTION",
            title: "Build a complete baseline",
            text: "A cleaner week gives Insights enough overlap to rank real stories.",
            action: "Log sleep, meals, drinks and activity every day for the next 7 days.",
            icon: "sparkles",
            accent: hero.accent,
            domain: .missingData,
            actionTitle: "Log Today",
            actionDestination: .tab(.today)
        )
        return InsightsStoryCandidate(
            id: "baseline.insufficient_overlap",
            impactScore: 20,
            confidence: confidence(from: dataQuality),
            trend: hero,
            driver: driver,
            action: action
        )
    }

    private func makeStoryCandidates(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> [InsightsStoryCandidate] {
        [
            recoveryDeclineStory(records: records, recoverySleepRecords: recoverySleepRecords),
            recoveryReboundStory(records: records, recoverySleepRecords: recoverySleepRecords),
            recoveryPlateauStory(records: records, recoverySleepRecords: recoverySleepRecords),
            sleepDebtStory(records: records, recoverySleepRecords: recoverySleepRecords),
            weekendSleepStory(records: records, recoverySleepRecords: recoverySleepRecords),
            trainingLoadStory(records: records, recoverySleepRecords: recoverySleepRecords),
            activeCaloriesDeclineStory(records: records, recoverySleepRecords: recoverySleepRecords),
            proteinConsistencyStory(records: records, recoverySleepRecords: recoverySleepRecords),
            hydrationHardDayStory(records: records, recoverySleepRecords: recoverySleepRecords)
        ]
        .compactMap { $0 }
        .filter { isCausalStory($0) }
        .filter { $0.impactScore >= 45 }
    }

    private func isCausalStory(_ story: InsightsStoryCandidate) -> Bool {
        guard story.trend.domain != .missingData else { return true }
        return !(story.trend.domain == story.driver.domain && story.driver.domain == story.action.domain)
    }

    private func recoveryDeclineStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        guard recoveryRecords.count >= 14 else { return nil }

        let recent = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baseline = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let delta = recent - baseline
        guard baseline > 0, delta <= -4 else { return nil }

        let latest = recoveryRecords.last?.recoveryScore ?? Int(recent.rounded())
        let driver = strongestRecoveryDriver(records: records, recoverySleepRecords: recoverySleepRecords, delta: delta)
        let impact = min(96, 58 + abs(delta) * 4 + (recent < 68 ? 12 : 0))
        let confidenceValue = storyConfidence(primaryDays: recoveryRecords.count, pairedDays: recoverySleepRecords.filter { $0.recoveryScore > 0 && $0.sleepMinutes > 0 }.count)

        return InsightsStoryCandidate(
            id: "recovery.decline",
            impactScore: impact,
            confidence: confidenceValue,
            trend: InsightsHeroInsight(
                label: "TREND",
                title: latest >= 72 ? "Recovery remains healthy but is declining" : "Recovery is losing momentum",
                subtitle: "Recovery is down \(Int(abs(delta).rounded())) points versus baseline.",
                takeaway: "Stabilize recovery before increasing load.",
                timeframe: "Last 30 Days",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: "72 target",
                badgeValue: "\(latest)",
                badgeLabel: "Recovery",
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForStory(
                title: driver.domain == .sleep ? "Restore sleep before increasing load" : "Stabilize the driver before adding load",
                text: "The 30-day story shows recovery moving in the wrong direction.",
                action: driver.domain == .sleep
                    ? "Sleep at least 7 hours on 5 of the next 7 nights."
                    : "Keep every workout easy or Zone 2 for the next 7 days.",
                icon: driver.icon,
                accent: driver.accent,
                domain: driver.domain,
                destination: driver.domain == .activity ? .detail(.activity) : .detail(.recovery)
            )
        )
    }

    private func recoveryReboundStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        guard recoveryRecords.count >= 14 else { return nil }

        let recent = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baseline = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let delta = recent - baseline
        guard baseline > 0, delta >= 5 else { return nil }

        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
        let volume = trainingVolumeSummary(records)
        let loadChange = workloadBaselineChange(volume)
        let driver: InsightSupportCard
        if recentSleep >= 7 {
            driver = InsightSupportCard(
                role: .resilience,
                domain: .sleep,
                title: "Sleep Consistency",
                text: "Sleep is at the level that supports recovery.",
                icon: "moon.fill",
                accent: WeekFitTheme.purple,
                metrics: [
                    InsightTrendMetric(label: "Sleep", value: "\(formatOneDecimal(recentSleep))h", direction: .stable, detail: "average", benchmark: "Target: 7h")
                ]
            )
        } else if volume.hasMeaningfulLoad, loadChange <= 10 {
            driver = InsightSupportCard(
                role: .workload,
                domain: .activity,
                title: "Controlled Load",
                text: "Training load has stayed controlled while recovery improved.",
                icon: "figure.run",
                accent: WeekFitTheme.orange,
                metrics: [
                    workloadSignificanceMetric(volume)
                ]
            )
        } else {
            return nil
        }

        return InsightsStoryCandidate(
            id: "recovery.rebound",
            impactScore: min(88, 52 + delta * 4),
            confidence: storyConfidence(primaryDays: recoveryRecords.count, pairedDays: max(sleepRecords.count, records.filter(\.hasActivitySignal).count)),
            trend: InsightsHeroInsight(
                label: "TREND",
                title: "Recovery resilience is improving",
                subtitle: "Recovery has rebounded \(Int(delta.rounded())) points versus baseline.",
                takeaway: "Protect the routine that created the rebound.",
                timeframe: "Last 30 Days",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: "72 target",
                badgeValue: "\(Int(recent.rounded()))",
                badgeLabel: "Recovery",
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForStory(
                title: driver.domain == .sleep ? "Protect the sleep routine" : "Keep load increases gradual",
                text: "The trend has turned positive; the goal is to preserve it.",
                action: driver.domain == .sleep
                    ? "Keep sleep above 7 hours on 5 of the next 7 nights."
                    : "Do not increase training volume by more than 10% over the next 7 days.",
                icon: driver.icon,
                accent: driver.accent,
                domain: driver.domain,
                destination: driver.domain == .activity ? .detail(.activity) : .detail(.recovery)
            )
        )
    }

    private func recoveryPlateauStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        guard recoveryRecords.count >= 21 else { return nil }

        let firstWindow = average(Array(recoveryRecords.prefix(10)).map { Double($0.recoveryScore) })
        let middleWindow = average(Array(recoveryRecords.dropFirst(10).prefix(10)).map { Double($0.recoveryScore) })
        let recent = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        guard middleWindow - firstWindow >= 4, abs(recent - middleWindow) <= 2 else { return nil }

        let driver = InsightSupportCard(
            role: .resilience,
            domain: .recovery,
            title: "Recovery plateau",
            text: "Recovery improved earlier, then flattened over the recent window.",
            icon: "equal.circle.fill",
            accent: WeekFitTheme.meal,
            metrics: [
                InsightTrendMetric(label: "Recent trend", value: "flat", direction: .stable, detail: "after improvement", benchmark: "plateau")
            ]
        )

        return InsightsStoryCandidate(
            id: "recovery.plateau",
            impactScore: 64,
            confidence: storyConfidence(primaryDays: recoveryRecords.count, pairedDays: recoveryRecords.count),
            trend: InsightsHeroInsight(
                label: "TREND",
                title: "Recovery plateau detected",
                subtitle: "Recovery improved, then stopped progressing.",
                takeaway: "Find the next limiter before adding load.",
                timeframe: "Last 30 Days",
                icon: "equal.circle.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: "72 target",
                badgeValue: "\(Int(recent.rounded()))",
                badgeLabel: "Recovery",
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForStory(
                title: "Hold training volume while testing the next limiter",
                text: "A plateau means the first improvement has already been absorbed.",
                action: "Keep training volume flat for the next 7 days.",
                icon: "target",
                accent: WeekFitTheme.meal,
                domain: .recovery,
                destination: .detail(.recovery)
            )
        )
    }

    private func sleepDebtStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        guard sleepRecords.count >= 7, recoveryRecords.count >= 7 else { return nil }

        let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
        let baselineSleep = average(Array(sleepRecords.dropLast(7)).map(\.sleepHours))
        let declining = baselineSleep > 0 && recentSleep <= baselineSleep - 0.25
        guard recentSleep < 6.9 || declining else { return nil }

        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baselineRecovery = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryDelta = recentRecovery - baselineRecovery
        let recoveryIsStable = baselineRecovery > 0 && abs(recoveryDelta) <= 3
        let recoveryIsDeclining = baselineRecovery > 0 && recoveryDelta <= -3
        guard recoveryIsStable || recoveryIsDeclining else { return nil }

        let latestRecovery = recoveryRecords.last?.recoveryScore ?? Int(recentRecovery.rounded())
        let impact = min(82, 46 + max(0, 7.0 - recentSleep) * 10 + (declining ? 8 : 0) + (recoveryIsDeclining ? 14 : 0))
        let driver = InsightSupportCard(
            role: .limitingFactor,
            domain: .sleep,
            title: "Sleep Duration",
            text: "Sleep has fallen below the level that protects recovery.",
            icon: "moon.fill",
            accent: WeekFitTheme.purple,
            metrics: [
                InsightTrendMetric(label: "Sleep", value: "\(formatOneDecimal(recentSleep))h", direction: declining ? .decreasing : .stable, detail: "average", benchmark: "Target: 7h")
            ]
        )

        return InsightsStoryCandidate(
            id: "recovery.sleep_pressure",
            impactScore: impact,
            confidence: storyConfidence(primaryDays: sleepRecords.count, pairedDays: recoverySleepRecords.filter { $0.sleepMinutes > 0 && $0.recoveryScore > 0 }.count),
            trend: InsightsHeroInsight(
                label: "TREND",
                title: recoveryIsDeclining ? "Recovery is starting to lose support" : "Recovery is holding despite short sleep",
                subtitle: recoveryIsDeclining
                    ? "Recovery is down \(Int(abs(recoveryDelta).rounded())) points while sleep is below target."
                    : "Sleep is below target, but recovery has not dropped yet.",
                takeaway: "Restore sleep before increasing training load.",
                timeframe: "Last 30 Days",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: "72 target",
                badgeValue: "\(latestRecovery)",
                badgeLabel: "Recovery",
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForStory(
                title: "Restore sleep before increasing load",
                text: "Sleep is the driver to fix before changing training.",
                action: "Sleep at least 7 hours on 5 of the next 7 nights.",
                icon: "moon.zzz.fill",
                accent: WeekFitTheme.purple,
                domain: .sleep,
                destination: .detail(.recovery)
            )
        )
    }

    private func weekendSleepStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let paired = recoverySleepRecords.filter { $0.sleepMinutes > 0 && $0.recoveryScore > 0 }
        let weekend = paired.filter { Calendar.current.isDateInWeekend($0.date) }
        let weekday = paired.filter { !Calendar.current.isDateInWeekend($0.date) }
        guard weekend.count >= 4, weekday.count >= 8 else { return nil }

        let weekendSleep = average(weekend.map(\.sleepHours))
        let weekdaySleep = average(weekday.map(\.sleepHours))
        let weekendRecovery = average(weekend.map { Double($0.recoveryScore) })
        let weekdayRecovery = average(weekday.map { Double($0.recoveryScore) })
        let recoveryGap = weekdayRecovery - weekendRecovery
        guard weekendSleep <= weekdaySleep - 0.35, recoveryGap >= 4 else { return nil }
        let recentRecovery = Int(average(Array(paired.suffix(7)).map { Double($0.recoveryScore) }).rounded())

        let driver = InsightSupportCard(
            role: .limitingFactor,
            domain: .sleep,
            title: "Weekend sleep",
            text: "Weekend sleep is lower than weekdays.",
            icon: "calendar",
            accent: WeekFitTheme.purple,
            metrics: [
                InsightTrendMetric(label: "Weekend gap", value: "-\(Int(recoveryGap.rounded()))", direction: .decreasing, detail: "recovery points", benchmark: "vs weekdays")
            ]
        )

        return InsightsStoryCandidate(
            id: "sleep.weekend_disruption",
            impactScore: min(86, 54 + recoveryGap * 3),
            confidence: storyConfidence(primaryDays: paired.count, pairedDays: weekend.count),
            trend: InsightsHeroInsight(
                label: "TREND",
                title: "Weekend recovery is weaker",
                subtitle: "Weekend recovery is \(Int(recoveryGap.rounded())) points lower than weekdays.",
                takeaway: "Protect weekend wake time.",
                timeframe: "Last 30 Days",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(paired.suffix(30)))),
                targetValue: 0.72,
                targetLabel: "72 target",
                badgeValue: "\(recentRecovery)",
                badgeLabel: "Recovery",
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForStory(
                title: "Protect weekend sleep timing",
                text: "The weekly dip is concentrated around weekends.",
                action: "Keep weekend wake time within 60 minutes of weekdays for the next 2 weekends.",
                icon: "alarm.fill",
                accent: WeekFitTheme.purple,
                domain: .sleep,
                destination: .detail(.recovery)
            )
        )
    }

    private func trainingLoadStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let volume = trainingVolumeSummary(records)
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baselineRecovery = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryDelta = recentRecovery - baselineRecovery
        guard volume.hasMeaningfulLoad, recoveryRecords.count >= 7 else { return nil }
        let loadPressure = workloadBaselineChange(volume)
        guard loadPressure >= 15, (recentRecovery < 70 || recoveryDelta <= -3) else { return nil }

        let driver = InsightSupportCard(
            role: .workload,
            domain: .activity,
            title: "Training Load",
            text: "Training load is outpacing the recovery response.",
            icon: "figure.run",
            accent: WeekFitTheme.orange,
            metrics: [
                InsightTrendMetric(label: "Load", value: workloadCategory(volume), direction: .increasing, detail: volume.badgeValue, benchmark: "above recent base")
            ]
        )

        return InsightsStoryCandidate(
            id: "training.load_outrunning_recovery",
            impactScore: min(94, 58 + loadPressure * 0.5 + max(0, -recoveryDelta) * 3),
            confidence: storyConfidence(primaryDays: records.filter(\.hasActivitySignal).count, pairedDays: recoveryRecords.count),
            trend: InsightsHeroInsight(
                label: "TREND",
                title: "Recovery is not keeping up with load",
                subtitle: "Recovery is soft while training load is elevated.",
                takeaway: "Hold training volume until recovery stabilizes.",
                timeframe: "Last 30 Days",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: "72 target",
                visualization: .correlation(
                    primary: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                    secondary: smoothedTrendValues(recoverySleepRecords.map(\.activityLoadGraphValue)),
                    primaryLabel: "recovery",
                    secondaryLabel: "load"
                ),
                badgeValue: "\(Int(recentRecovery.rounded()))",
                badgeLabel: "Recovery",
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForStory(
                title: "Hold current training volume",
                text: "Recovery needs to catch up before more load is useful.",
                action: "Do not add sessions or increase volume for the next 7 days.",
                icon: "bolt.shield.fill",
                accent: WeekFitTheme.orange,
                domain: .activity,
                destination: .detail(.activity)
            )
        )
    }

    private func activeCaloriesDeclineStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let calorieRecords = recoverySleepRecords.filter { $0.metrics.activeCalories > 0 }
        guard calorieRecords.count >= 14 else { return nil }
        let recent = average(Array(calorieRecords.suffix(7)).map(\.metrics.activeCalories))
        let baseline = average(Array(calorieRecords.dropLast(7)).map(\.metrics.activeCalories))
        guard baseline > 0, recent <= baseline * 0.75 else { return nil }

        let drop = baseline - recent
        let driver = InsightSupportCard(
            role: .workload,
            domain: .activity,
            title: "Active Calories",
            text: "Active calories have declined meaningfully versus baseline.",
            icon: "flame.fill",
            accent: WeekFitTheme.orange,
            metrics: [
                InsightTrendMetric(label: "Active calories", value: "-\(Int(drop.rounded()))", direction: .decreasing, detail: "per day", benchmark: "vs baseline")
            ]
        )

        return InsightsStoryCandidate(
            id: "activity.active_calories_declining",
            impactScore: min(78, 46 + (drop / max(baseline, 1)) * 80),
            confidence: storyConfidence(primaryDays: calorieRecords.count, pairedDays: calorieRecords.count),
            trend: InsightsHeroInsight(
                label: "TREND",
                title: "Active calories are declining",
                subtitle: "Daily active calories are down versus baseline.",
                takeaway: "Rebuild activity consistency before adding intensity.",
                timeframe: "Last 30 Days",
                icon: "flame.fill",
                accent: WeekFitTheme.orange,
                graphValues: smoothedTrendValues(calorieRecords.map { min(max($0.metrics.activeCalories / max(baseline, 1), 0), 1) }),
                targetValue: 0.85,
                targetLabel: "baseline",
                badgeValue: "\(Int(recent.rounded()))",
                badgeLabel: "cal/day",
                domain: .activity,
                actionDestination: .detail(.activity)
            ),
            driver: driver,
            action: actionForStory(
                title: "Rebuild activity consistency",
                text: "The decline is volume-based, not intensity-based.",
                action: "Complete 30 minutes of Zone 2 activity on 4 of the next 7 days.",
                icon: "figure.walk",
                accent: WeekFitTheme.orange,
                domain: .activity,
                destination: .detail(.activity)
            )
        )
    }

    private func proteinConsistencyStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let nutritionRecords = records.filter { $0.mealCount > 0 || $0.proteinGrams > 0 }
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let proteinGoal = records.last?.nutritionGoals?.protein ?? 0
        guard nutritionRecords.count >= 4, recoveryRecords.count >= 7, proteinGoal > 0 else { return nil }

        let hitDays = nutritionRecords.filter { $0.proteinGrams >= proteinGoal }.count
        let averageProtein = average(nutritionRecords.map(\.proteinGrams))
        guard hitDays < 5 || averageProtein < proteinGoal * 0.75 else { return nil }

        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baselineRecovery = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryDelta = recentRecovery - baselineRecovery
        guard baselineRecovery == 0 || recoveryDelta <= 3 else { return nil }

        let impact = min(74, 44 + Double(max(0, 6 - hitDays)) * 4 + max(0, 1 - averageProtein / proteinGoal) * 16 + (recoveryDelta <= -3 ? 10 : 0))
        let driver = InsightSupportCard(
            role: .limitingFactor,
            domain: .nutrition,
            title: "Protein Consistency",
            text: "Protein consistency is below the level needed to support adaptation.",
            icon: "fork.knife",
            accent: WeekFitTheme.meal,
            metrics: [
                InsightTrendMetric(label: "Protein", value: "\(hitDays)/7", direction: .decreasing, detail: "target days", benchmark: "Target: 6 of 7 days")
            ]
        )

        return InsightsStoryCandidate(
            id: "nutrition.protein_consistency",
            impactScore: impact,
            confidence: storyConfidence(primaryDays: nutritionRecords.count, pairedDays: nutritionRecords.count),
            trend: InsightsHeroInsight(
                label: "TREND",
                title: recoveryDelta <= -3 ? "Recovery support is getting weaker" : "Recovery is missing a nutrition signal",
                subtitle: "Protein target was hit on \(hitDays) of the last 7 logged days.",
                takeaway: "Make protein consistent before changing training.",
                timeframe: "Last 30 Days",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(recoveryRecords.suffix(30)))),
                targetValue: 0.72,
                targetLabel: "72 target",
                badgeValue: "\(Int(recentRecovery.rounded()))",
                badgeLabel: "Recovery",
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForStory(
                title: "Use protein to support recovery",
                text: "Protein is the driver to stabilize before training changes.",
                action: "Hit your protein target on at least 6 of the next 7 days.",
                icon: "takeoutbag.and.cup.and.straw.fill",
                accent: WeekFitTheme.meal,
                domain: .nutrition,
                destination: .detail(.nutrition)
            )
        )
    }

    private func hydrationHardDayStory(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsStoryCandidate? {
        let paired = records.filter { $0.waterLiters > 0 && $0.hasActivitySignal && $0.recoveryScore > 0 }
        guard paired.count >= 4 else { return nil }

        let highLoadDays = paired.filter { $0.activityLoadScore >= 55 }
        guard highLoadDays.count >= 2 else { return nil }

        let lowerHydration = highLoadDays.filter { $0.waterLiters < max($0.waterGoal, 2.4) * 0.7 }
        let betterHydration = highLoadDays.filter { $0.waterLiters >= max($0.waterGoal, 2.4) * 0.7 }
        guard !lowerHydration.isEmpty, !betterHydration.isEmpty else { return nil }

        let lowerRecovery = average(lowerHydration.map { Double($0.recoveryScore) })
        let betterRecovery = average(betterHydration.map { Double($0.recoveryScore) })
        let lift = betterRecovery - lowerRecovery
        guard abs(lift) >= 5 else { return nil }

        let recentRecovery = Int(average(Array(paired.suffix(7)).map { Double($0.recoveryScore) }).rounded())
        let driver = InsightSupportCard(
            role: .relationship,
            domain: .hydration,
            title: "Hydration on hard days",
            text: "Hydration is separating recovery after higher-load days.",
            icon: "drop.fill",
            accent: WeekFitTheme.blue,
            metrics: [
                InsightTrendMetric(label: "Hard days", value: lift > 0 ? "+\(Int(lift.rounded()))" : "\(Int(lift.rounded()))", direction: lift > 0 ? .increasing : .decreasing, detail: "recovery points", benchmark: "hydrated vs low-fluid")
            ]
        )

        return InsightsStoryCandidate(
            id: "hydration.hard_day_effect",
            impactScore: min(76, 46 + abs(lift) * 4),
            confidence: storyConfidence(primaryDays: paired.count, pairedDays: highLoadDays.count),
            trend: InsightsHeroInsight(
                label: "TREND",
                title: "Hard-day recovery is uneven",
                subtitle: "Recovery changes by \(Int(abs(lift).rounded())) points based on hard-day hydration.",
                takeaway: "Prioritize fluids around hard training.",
                timeframe: "Last 30 Days",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: smoothedTrendValues(normalizedRecoveryValues(Array(paired.suffix(30)))),
                targetValue: 0.72,
                targetLabel: "72 target",
                badgeValue: "\(recentRecovery)",
                badgeLabel: "Recovery",
                domain: .recovery,
                actionDestination: .detail(.recovery)
            ),
            driver: driver,
            action: actionForStory(
                title: "Prioritize fluids around hard sessions",
                text: "Hydration is the driver to control around high load.",
                action: "Drink at least 750ml in the 2 hours after each hard session this week.",
                icon: "drop.fill",
                accent: WeekFitTheme.blue,
                domain: .hydration,
                destination: .detail(.nutrition)
            )
        )
    }

    private func strongestRecoveryDriver(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        delta: Double
    ) -> InsightSupportCard {
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
        let baselineSleep = average(Array(sleepRecords.dropLast(7)).map(\.sleepHours))
        if recentSleep > 0, recentSleep < 7 || (baselineSleep > 0 && recentSleep <= baselineSleep - 0.25) {
            return InsightSupportCard(
                role: .limitingFactor,
                domain: .sleep,
                title: "Sleep Duration",
                text: "Recovery decline is most strongly associated with reduced sleep duration.",
                icon: "moon.fill",
                accent: WeekFitTheme.purple,
                metrics: [
                    InsightTrendMetric(label: "Sleep", value: "\(formatOneDecimal(recentSleep))h", direction: .decreasing, detail: "average", benchmark: "Target: 7h")
                ]
            )
        }

        let volume = trainingVolumeSummary(records)
        if volume.hasMeaningfulLoad, workloadBaselineChange(volume) >= 15 {
            return InsightSupportCard(
                role: .workload,
                domain: .activity,
                title: "Training Load",
                text: "Recovery decline is most strongly associated with training load.",
                icon: "figure.run",
                accent: WeekFitTheme.orange,
                metrics: [
                    workloadSignificanceMetric(volume)
                ]
            )
        }

        return InsightSupportCard(
            role: .resilience,
            domain: .recovery,
            title: "Recovery Consistency",
            text: "Recovery consistency is the strongest signal in the 30-day pattern.",
            icon: "heart.fill",
            accent: WeekFitTheme.meal,
            metrics: [
                InsightTrendMetric(label: "Recovery", value: "\(Int(delta.rounded()))", direction: .decreasing, detail: "vs baseline", benchmark: "recent 7 days")
            ]
        )
    }

    private func actionForStory(
        title: String,
        text: String,
        action: String,
        icon: String,
        accent: Color,
        domain: InsightsDomain,
        destination: InsightsActionDestination?
    ) -> InsightsFocusNext {
        InsightsFocusNext(
            label: "ACTION",
            title: title,
            text: text,
            action: action,
            icon: icon,
            accent: accent,
            domain: domain,
                actionTitle: storyActionTitle(for: destination),
            actionDestination: destination
        )
    }

    private func storyActionTitle(for destination: InsightsActionDestination?) -> String {
        switch destination {
        case .detail(.recovery):
            return "View Recovery Analysis"
        case .detail(.activity):
            return "Review Training Trends"
        case .detail(.nutrition):
            return "Explore Nutrition Details"
        case .tab(.coach):
            return "Open Coach"
        case .tab(.today):
            return "Log Today"
        case .tab(.meals):
            return "Open Nutrition"
        case .tab(.calendar):
            return "Open Plan"
//        case .tab(.highlights):
//            return "Open Highlights"
        case nil:
            return "Review Details"
        }
    }

    private func storyConfidence(primaryDays: Int, pairedDays: Int) -> Double {
        let primary = min(Double(primaryDays) / 21.0, 1.0)
        let paired = min(Double(pairedDays) / 14.0, 1.0)
        return min(max(0.42 + primary * 0.34 + paired * 0.24, 0.35), 0.94)
    }

    private func hasEnoughStableContext(_ quality: InsightsDataQuality) -> Bool {
        quality.recoveryDays >= 14 ||
            quality.sleepDays >= 14 ||
            quality.activityDays >= 7 ||
            quality.mealDays >= 7
    }

    private func makeHero(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        nutritionViewModel: NutritionViewModel,
        coachContext: InsightsCoachContext?
    ) -> InsightsHeroInsight {
        let validRecovery = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let validSleep = recoverySleepRecords.filter { $0.sleepHours > 0 }
        let validNutrition = records.filter { $0.mealCount > 0 }
        let validActivity = records.filter { $0.hasActivitySignal }
        let recoveryValues = smoothedTrendValues(normalizedRecoveryValues(Array(validRecovery.suffix(30))))
        let recentRecoveryAverage = average(Array(validRecovery.suffix(7)).map { Double($0.recoveryScore) })
        let priorRecoveryAverage = average(Array(validRecovery.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryTrend = trendDirection(recent: recentRecoveryAverage, baseline: priorRecoveryAverage, threshold: 2.0)
        var candidates: [InsightsHeroCandidate] = []

        if validRecovery.count >= 14,
           validSleep.count >= 14 {
            let recentSleep = average(Array(validSleep.suffix(7)).map(\.sleepHours))
            let priorSleep = average(Array(validSleep.dropLast(7)).map(\.sleepHours))
            let sleepTrend = trendDirection(recent: recentSleep, baseline: priorSleep, threshold: 0.15)

            if recentSleep > 0,
               recentSleep < 6.7,
               recentRecoveryAverage > 0,
               recentRecoveryAverage <= priorRecoveryAverage - 2 {
                candidates.append(InsightsHeroCandidate(priority: 50, insight: InsightsHeroInsight(
                label: "MAIN INSIGHT",
                title: "Sleep is your next recovery opportunity",
                subtitle: "Sleep remains below target.",
                takeaway: "Watch whether earlier nights change recovery.",
                timeframe: observationWindowText(for: .sleep, quality: makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)),
                icon: "bed.double.fill",
                accent: WeekFitTheme.purple,
                graphValues: sleepScoreTrendValues(validSleep),
                targetValue: 0.70,
                targetLabel: "70 sleep score",
                badgeValue: "\(formatOneDecimal(recentSleep))h",
                badgeLabel: sleepTrend == .decreasing ? "falling" : "recent avg",
                domain: .sleep
                )))
            }
        }

        if validRecovery.count >= 7,
           let first = validRecovery.first?.recoveryScore,
           let last = validRecovery.last?.recoveryScore,
           last - first <= -8 || (priorRecoveryAverage > 0 && recentRecoveryAverage <= priorRecoveryAverage - 5) {
            candidates.append(InsightsHeroCandidate(priority: 10, insight: InsightsHeroInsight(
                label: "MAIN INSIGHT",
                title: "Recovery is losing momentum",
                subtitle: "Recovery has started to slide.",
                takeaway: "Watch whether a steadier week helps it rebound.",
                timeframe: observationWindowText(for: .recovery, quality: makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                graphValues: recoveryValues,
                targetValue: 0.72,
                targetLabel: "72 target",
                badgeValue: "\(last)",
                badgeLabel: "latest",
                domain: .recovery
            )))
        }

        if validActivity.count == 7, validRecovery.count >= 7 {
            let averageLoad = average(validActivity.map(\.activityLoadScore))
            if averageLoad >= 72, recentRecoveryAverage > 0, recentRecoveryAverage < 68 {
                let volume = trainingVolumeSummary(records)
                candidates.append(InsightsHeroCandidate(priority: recoveryTrend == .decreasing ? 20 : 40, insight: InsightsHeroInsight(
                    label: "MAIN INSIGHT",
                    title: recoveryTrend == .decreasing ? "Training may be outrunning recovery" : "Recovery is absorbing a demanding week",
                    subtitle: recoveryTrend == .decreasing
                        ? "Load is pressing your recovery."
                        : "Recovery is holding up.",
                    takeaway: recoveryTrend == .decreasing ? "Watch the next recovery response." : "Keep the rhythm steady.",
                    timeframe: observationWindowText(for: .activity, quality: makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)),
                    icon: "figure.run",
                    accent: WeekFitTheme.orange,
                    graphValues: smoothedTrendValues(recoverySleepRecords.map(\.activityLoadGraphValue)),
                    targetValue: 0.70,
                    targetLabel: "high load",
                    visualization: .correlation(
                        primary: recoveryValues,
                        secondary: smoothedTrendValues(recoverySleepRecords.map(\.activityLoadGraphValue)),
                        primaryLabel: "recovery",
                        secondaryLabel: "load"
                    ),
                    badgeValue: volume.badgeValue,
                    badgeLabel: "weekly load",
                    domain: .activity
                )))
            }
        }

        if validNutrition.count == 7, let proteinGoal = records.last?.nutritionGoals?.protein, proteinGoal > 0 {
            let averageProtein = average(validNutrition.map(\.proteinGrams))
            if averageProtein < proteinGoal * 0.65 {
                candidates.append(InsightsHeroCandidate(priority: 20, insight: InsightsHeroInsight(
                    label: "MAIN INSIGHT",
                    title: "Nutrition is becoming the limiting factor",
                    subtitle: "Protein support is inconsistent.",
                    takeaway: "Watch whether better workout meals change recovery.",
                    timeframe: observationWindowText(for: .nutrition, quality: makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)),
                    icon: "fork.knife",
                    accent: WeekFitTheme.meal,
                    graphValues: smoothedTrendValues(records.map(\.proteinGraphValue)),
                    targetValue: 0.80,
                    targetLabel: "protein target",
                    visualization: .trendLine(
                        values: smoothedTrendValues(records.map(\.proteinGraphValue)),
                        target: 0.80,
                        targetLabel: "protein target"
                    ),
                    badgeValue: "\(Int(averageProtein.rounded()))g",
                    badgeLabel: "avg protein",
                    domain: .nutrition
                )))
            }
        }

        let validHydration = records.filter { $0.waterLiters > 0 }
        if validHydration.count >= 5 {
            let recentHydration = average(validHydration.map(\.waterLiters))
            let waterGoal = records.last?.waterGoal ?? 0
            let hydrationTarget = waterGoal > 0 ? waterGoal : 2.4

            if hydrationTarget > 0, recentHydration < hydrationTarget * 0.62 {
                candidates.append(InsightsHeroCandidate(priority: 70, insight: InsightsHeroInsight(
                    label: "MAIN INSIGHT",
                    title: "Hydration is the clearest support gap",
                    subtitle: "Fluids are falling short after harder days.",
                    takeaway: "Watch fluids around your highest-load sessions.",
                    timeframe: observationWindowText(for: .hydration, quality: makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)),
                    icon: "drop.fill",
                    accent: WeekFitTheme.blue,
                    graphValues: smoothedTrendValues(records.map(\.hydrationGraphValue)),
                    targetValue: 0.70,
                    targetLabel: "target",
                    visualization: .trendLine(
                        values: smoothedTrendValues(records.map(\.hydrationGraphValue)),
                        target: 0.70,
                        targetLabel: "target"
                    ),
                    badgeValue: formatLiters(recentHydration),
                    badgeLabel: "avg water",
                    domain: .hydration
                )))
            }
        }

        if validSleep.count >= 7 {
            let averageSleepHours = average(validSleep.map(\.sleepHours))
            let recentSleep = average(Array(validSleep.suffix(7)).map(\.sleepHours))
            let baselineSleep = average(Array(validSleep.dropLast(7)).map(\.sleepHours))
            let sleepTrend = trendDirection(recent: recentSleep, baseline: baselineSleep, threshold: 0.15)
            let sleepLooksLow = averageSleepHours < 7
            let recoveryLooksStrong = recentRecoveryAverage >= 72
            let sleepPriority = sleepTrend == .decreasing ? 24 : 30
            let sleepHasMeaningfulStory = sleepLooksLow ||
                sleepTrend != .stable ||
                (baselineSleep > 0 && abs(recentSleep - baselineSleep) >= 0.25)
            let sleepSubtitle: String
            let sleepTitle: String
            let sleepTakeaway: String
            if averageSleepHours >= 7 {
                sleepTitle = "Sleep is supporting recovery"
                sleepSubtitle = "Sleep is in a solid range."
                sleepTakeaway = "Watch whether steady timing keeps recovery stable."
            } else if recoveryLooksStrong {
                sleepTitle = "Sleep is your next recovery opportunity"
                sleepSubtitle = "Sleep remains below target."
                sleepTakeaway = "Test one earlier bedtime and watch whether recovery gets easier."
            } else if sleepTrend == .increasing {
                sleepTitle = "Sleep is starting to recover"
                sleepSubtitle = "Sleep remains below target."
                sleepTakeaway = "Keep the improvement going for three more nights."
            } else {
                sleepTitle = sleepLooksLow ? "Sleep is limiting recovery" : "Sleep is your biggest recovery opportunity"
                sleepSubtitle = "Sleep remains below target."
                sleepTakeaway = "Aim for one more 7+ hour night."
            }
            if sleepHasMeaningfulStory {
                candidates.append(InsightsHeroCandidate(priority: sleepPriority, insight: InsightsHeroInsight(
                    label: "MAIN INSIGHT",
                    title: sleepTitle,
                    subtitle: sleepSubtitle,
                    takeaway: sleepTakeaway,
                    timeframe: observationWindowText(for: .sleep, quality: makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)),
                    icon: "moon.fill",
                    accent: WeekFitTheme.purple,
                    graphValues: sleepScoreTrendValues(validSleep),
                    targetValue: 0.70,
                    targetLabel: "70 sleep score",
                    badgeValue: "\(formatOneDecimal(averageSleepHours))h",
                    badgeLabel: "avg sleep",
                    domain: .sleep
                )))
            }
        }

        if validRecovery.count >= 7 {
            let averageRecovery = Int(average(validRecovery.map { Double($0.recoveryScore) }).rounded())
            let recoveryRebounded = priorRecoveryAverage > 0 && recentRecoveryAverage >= priorRecoveryAverage + 5
            let recoveryIsLow = averageRecovery < 68

            if recoveryRebounded || recoveryIsLow {
                candidates.append(InsightsHeroCandidate(priority: recoveryRebounded ? 25 : 18, insight: InsightsHeroInsight(
                    label: "MAIN INSIGHT",
                    title: recoveryRebounded ? "Recovery has rebounded" : "Recovery needs a lighter week",
                    subtitle: recoveryRebounded
                        ? "Recovery has improved meaningfully over the last month."
                        : "Recovery is running low.",
                    takeaway: recoveryRebounded
                        ? "Hold the routine that supported the rebound."
                        : "Watch whether a lighter week helps it rebound.",
                    timeframe: observationWindowText(for: .recovery, quality: makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)),
                    icon: "heart.fill",
                    accent: WeekFitTheme.meal,
                    graphValues: recoveryValues,
                    targetValue: 0.72,
                    targetLabel: "72 target",
                    badgeValue: "\(averageRecovery)",
                    badgeLabel: "Recovery",
                    domain: .recovery
                )))
            }
        }

        if let best = candidates.sorted(by: { $0.priority < $1.priority }).first {
            return best.insight
        }

        let quality = makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)
        let hasEnoughStableContext = quality.recoveryDays >= 14 ||
            quality.sleepDays >= 14 ||
            quality.activityDays >= 7 ||
            quality.mealDays >= 7

        if hasEnoughStableContext {
            return noMajorChangeHero(records: records, recoverySleepRecords: recoverySleepRecords)
        }

        return missingDataHero(records: records, recoverySleepRecords: recoverySleepRecords)
    }

    private func noMajorChangeHero(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsHeroInsight {
        let quality = makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)

        return InsightsHeroInsight(
            label: "TREND",
            title: "No major 30-day change detected",
            subtitle: "Core signals are stable. Insights will surface a hero when a meaningful change, risk, opportunity or anomaly appears.",
            takeaway: "Keep the current routine stable.",
            timeframe: observationWindowText(for: .consistency, quality: quality),
            icon: "checkmark.seal.fill",
            accent: WeekFitTheme.meal,
            graphValues: [],
            targetValue: nil,
            targetLabel: nil,
            visualization: .contributionBreakdown(segments: [
                InsightContribution(label: "recovery", value: min(Double(quality.recoveryDays) / 30.0, 0.34), color: WeekFitTheme.meal),
                InsightContribution(label: "sleep", value: min(Double(quality.sleepDays) / 30.0, 0.30), color: WeekFitTheme.purple),
                InsightContribution(label: "training", value: min(Double(quality.activityDays) / 7.0, 0.26), color: WeekFitTheme.orange)
            ]),
            badgeValue: "Stable",
            badgeLabel: "30 days",
            domain: .consistency,
            actionDestination: .tab(.coach)
        )
    }

    private func missingDataHero(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsHeroInsight {
        let quality = makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)

        let unlockCopy: String
        if quality.mealDays < 7 {
            let needed = max(1, 7 - quality.mealDays)
            unlockCopy = WeekFitCountPluralization.insightsUnlockMealDaysSubtitle(needed: needed)
        } else if quality.activityDays < 7 {
            let needed = max(1, 7 - quality.activityDays)
            unlockCopy = WeekFitCountPluralization.insightsUnlockActivityDaysSubtitle(needed: needed)
        } else if quality.recoveryDays < 7 {
            let needed = max(1, 7 - quality.recoveryDays)
            unlockCopy = WeekFitCountPluralization.insightsUnlockRecoveryDaysSubtitle(needed: needed)
        } else if quality.sleepDays < 7 {
            let needed = max(1, 7 - quality.sleepDays)
            unlockCopy = WeekFitCountPluralization.insightsUnlockSleepNightsSubtitle(needed: needed)
        } else if quality.hydrationDays < 7 {
            unlockCopy = "Core patterns are forming. More drink logs can add hydration context later."
        } else {
            unlockCopy = "Log sleep, meals, drinks and activities for a few more days to unlock trends."
        }

        return InsightsHeroInsight(
            label: "BUILDING PATTERNS",
            title: "Building your patterns",
            subtitle: unlockCopy,
            takeaway: "Keep logging consistently.",
            timeframe: "Recent data",
            icon: "brain.head.profile",
            accent: WeekFitTheme.meal,
            graphValues: [],
            targetValue: nil,
            targetLabel: nil,
            visualization: .contributionBreakdown(segments: [
                InsightContribution(label: "recovery", value: min(Double(quality.recoveryDays) / 7.0, 0.34), color: WeekFitTheme.meal),
                InsightContribution(label: "sleep", value: min(Double(quality.sleepDays) / 7.0, 0.30), color: WeekFitTheme.purple),
                InsightContribution(label: "training", value: min(Double(quality.activityDays) / 7.0, 0.26), color: WeekFitTheme.orange)
            ]),
            badgeValue: "—",
            badgeLabel: "patterns",
            domain: .missingData,
            actionDestination: .tab(.today)
        )
    }

    private func insightTitle(for coachContext: InsightsCoachContext) -> String {
        let lowercasedTitle = coachContext.title.lowercased()
        if lowercasedTitle.contains("recovery") && lowercasedTitle.contains("lead") {
            return "Recovery is the clearest read"
        }

        if lowercasedTitle.contains("hydration") && lowercasedTitle.contains("lead") {
            return "Hydration is shaping the pattern"
        }

        if lowercasedTitle.contains("training") && lowercasedTitle.contains("lead") {
            return "Training load is the main signal"
        }

        if lowercasedTitle.contains("nutrition") || lowercasedTitle.contains("fuel") {
            return coachContext.domain == .nutrition ? "Fueling is shaping recovery" : coachContext.title
        }

        return coachContext.title
    }

    private func makeEvidence(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality,
        hero: InsightsHeroInsight,
        coachContext: InsightsCoachContext?
    ) -> InsightsEvidence {
        let sourceSummary = confidenceBasisText(dataQuality)
        let recency = observationWindowText(for: hero.domain, quality: dataQuality)

        let heroFacts = evidenceBullets(
            records: records,
            recoverySleepRecords: recoverySleepRecords,
            heroDomain: hero.domain,
            dataQuality: dataQuality
        )

        return InsightsEvidence(
            label: "WHY THIS SIGNAL",
            confidenceLabel: confidenceLabel(confidence(from: dataQuality)),
            confidenceValue: confidence(from: dataQuality),
            sourceSummary: sourceSummary,
            recencyText: recency,
            bullets: Array(heroFacts.prefix(2))
        )
    }

    private func evidenceBullets(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        heroDomain: InsightsDomain,
        dataQuality: InsightsDataQuality
    ) -> [String] {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let activityRecords = records.filter(\.hasActivitySignal)
        let hydrationRecords = records.filter { $0.waterLiters > 0 }

        switch heroDomain {
        case .recovery:
            let averageRecovery = Int(average(recoveryRecords.map { Double($0.recoveryScore) }).rounded())
            let activeDays = activityRecords.count
            return [
                averageRecovery > 0 ? "Recovery has enough recent history to judge direction." : "Recovery history is still building.",
                activeDays > 0 ? "Training context shows what recovery is reacting to." : "Training context is limited."
            ]
        case .sleep:
            let averageSleep = average(sleepRecords.map(\.sleepHours))
            let averageRecovery = average(recoveryRecords.map { Double($0.recoveryScore) })
            return [
                averageSleep > 0 ? "Sleep has been below target often enough to count as a pattern." : "Sleep history is still building.",
                averageRecovery > 0 ? "Recovery shows whether this is a limiter or an opportunity." : "Recovery context is still building."
            ]
        case .activity:
            let averageRecovery = average(recoveryRecords.map { Double($0.recoveryScore) })
            let volume = trainingVolumeSummary(records)
            return [
                volume.hasMeaningfulLoad ? "Training has enough shape to interpret." : "Training volume is still too light to interpret.",
                averageRecovery > 0 ? "Recovery shows whether the work is being absorbed." : "Recovery context is limited."
            ]
        case .nutrition:
            let proteinGoal = records.last?.nutritionGoals?.protein ?? 0
            return [
                dataQuality.mealDays >= 5 ? "Meal history is consistent enough to read." : "Nutrition history is limited.",
                proteinGoal > 0 ? "Protein stands out from general meal noise." : "Meal consistency is the clearest nutrition signal."
            ]
        case .hydration:
            return [
                dataQuality.hydrationDays >= 5 ? "Drink history is complete enough to read." : "Hydration history is still building.",
                hydrationRecords.isEmpty ? "Paired drink and recovery days are limited." : "Hydration is only considered when it changes recovery context."
            ]
        case .consistency, .missingData:
            return [
                "The available data is not complete enough yet.",
                "More overlap across sleep, recovery, training and nutrition will clarify what changed."
            ]
        }
    }

    private func makeWhyItems(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight,
        evidence: InsightsEvidence,
        supportCards: [InsightSupportCard],
        coachContext: InsightsCoachContext?
    ) -> [InsightsWhyItem] {
        var items: [InsightsWhyItem] = []

        if let coachContext, coachContext.shouldLeadInsights {
            items.append(
                InsightsWhyItem(
                    title: "Current pattern",
                    value: compactValue(for: hero.domain, records: records, recoverySleepRecords: recoverySleepRecords),
                    detail: coachContext.evidence.first ?? coachContext.message,
                    icon: coachContext.icon,
                    domain: hero.domain
                )
            )
        }

        items.append(contentsOf: domainWhyItems(
            records: records,
            recoverySleepRecords: recoverySleepRecords,
            hero: hero
        ))

        if items.count < 2 {
            items.append(contentsOf: supportCards.prefix(2).map { card in
                InsightsWhyItem(
                    title: card.title,
                    value: card.metrics.first?.value ?? compactValue(for: card.domain, records: records, recoverySleepRecords: recoverySleepRecords),
                    detail: card.text,
                    icon: card.icon,
                    domain: card.domain
                )
            })
        }

        if items.isEmpty {
            items = evidence.bullets.prefix(3).map { bullet in
                InsightsWhyItem(
                    title: "The pattern is still forming",
                    value: "Keep logging",
                    detail: bullet,
                    icon: "sparkles",
                    domain: .missingData
                )
            }
        }

        return deduplicatedWhyItems(items)
    }

    private func domainWhyItems(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight
    ) -> [InsightsWhyItem] {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let sleepRecords = recoverySleepRecords.filter { $0.sleepHours > 0 }
        let mealRecords = records.filter { $0.mealCount > 0 }
        let averageRecovery = average(recoveryRecords.map { Double($0.recoveryScore) })
        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baselineRecovery = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryDirection = trendDirection(recent: recentRecovery, baseline: baselineRecovery, threshold: 2.0)
        let averageSleep = average(sleepRecords.map(\.sleepHours))
        let volume = trainingVolumeSummary(records)
        let today = records.last
        let waterGoal = today?.waterGoal ?? 0
        let waterLiters = today?.waterLiters ?? 0
        let proteinGoal = today?.nutritionGoals?.protein ?? 0
        let averageProtein = average(mealRecords.map(\.proteinGrams))

        switch hero.domain {
        case .recovery:
            return compact([
                averageRecovery > 0 ? InsightsWhyItem(
                    title: averageRecovery >= 72 ? "Recovery is holding up" : "Recovery is under strain",
                    value: "\(Int(averageRecovery.rounded()))",
                    detail: recoveryDirection == .decreasing ? "Readiness has started to slip, so tonight should protect recovery." : "Recovery has enough history to guide the next training choice.",
                    icon: "heart.fill",
                    domain: .recovery
                ) : nil,
                volume.hasMeaningfulLoad ? InsightsWhyItem(
                    title: "Recent load matters",
                    value: formatDuration(Int((volume.hours * 60).rounded())),
                    detail: averageRecovery >= 72 ? "The current load looks manageable if recovery stays steady." : "More intensity would mostly add fatigue right now.",
                    icon: "figure.run",
                    domain: .activity
                ) : nil,
                averageSleep > 0 && averageSleep < 7 ? InsightsWhyItem(
                    title: "Sleep can help recovery",
                    value: "\(formatOneDecimal(averageSleep))h",
                    detail: "A longer night is the simplest way to support readiness.",
                    icon: "moon.fill",
                    domain: .sleep
                ) : nil
            ])

        case .sleep:
            return compact([
                averageSleep > 0 ? InsightsWhyItem(
                    title: averageSleep >= 7 ? "Sleep is supporting you" : "Sleep is below target",
                    value: "\(formatOneDecimal(averageSleep))h",
                    detail: averageSleep >= 7 ? "Keep the timing steady so recovery has a stable base." : "Short nights make recovery harder to sustain.",
                    icon: "moon.fill",
                    domain: .sleep
                ) : nil,
                averageRecovery > 0 ? InsightsWhyItem(
                    title: "Recovery shows the cost",
                    value: "\(Int(averageRecovery.rounded()))",
                    detail: "Readiness tells you whether sleep is just low or actually limiting the day.",
                    icon: "heart.fill",
                    domain: .recovery
                ) : nil,
                volume.hasMeaningfulLoad ? InsightsWhyItem(
                    title: "Training raises the sleep need",
                    value: workloadCategory(volume),
                    detail: "Harder weeks need more sleep before more work.",
                    icon: "figure.run",
                    domain: .activity
                ) : nil
            ])

        case .activity:
            return compact([
                InsightsWhyItem(
                    title: "Training load is the main signal",
                    value: formatDuration(Int((volume.hours * 60).rounded())),
                    detail: workloadSignificanceText(volume),
                    icon: "figure.run",
                    domain: .activity
                ),
                averageRecovery > 0 ? InsightsWhyItem(
                    title: "Recovery decides the next move",
                    value: "\(Int(averageRecovery.rounded()))",
                    detail: averageRecovery >= 72 ? "You can repeat the rhythm before adding more." : "Readiness is low enough to favor restraint.",
                    icon: "heart.fill",
                    domain: .recovery
                ) : nil,
                averageSleep > 0 && averageSleep < 7 ? InsightsWhyItem(
                    title: "Sleep adds pressure",
                    value: "\(formatOneDecimal(averageSleep))h",
                    detail: "Short sleep makes the same session cost more.",
                    icon: "moon.fill",
                    domain: .sleep
                ) : nil
            ])

        case .hydration:
            let gap = waterGoal > 0 ? waterLiters - waterGoal : waterLiters
            return compact([
                InsightsWhyItem(
                    title: waterGoal > 0 && gap < 0 ? "Hydration is behind target" : "Hydration is the clearest lever",
                    value: waterGoal > 0 ? targetGapText(value: waterLiters, target: waterGoal, unit: "L") : formatLiters(waterLiters),
                    detail: waterGoal > 0 && gap < 0 ? "Fluid intake is below the recent target pattern." : "Fluids matter most after harder sessions.",
                    icon: "drop.fill",
                    domain: .hydration
                ),
                volume.hasMeaningfulLoad ? InsightsWhyItem(
                    title: "Training increases fluid needs",
                    value: workloadCategory(volume),
                    detail: "Harder sessions make hydration matter sooner.",
                    icon: "figure.run",
                    domain: .activity
                ) : nil,
                averageRecovery > 0 ? InsightsWhyItem(
                    title: "Recovery is the check",
                    value: "\(Int(averageRecovery.rounded()))",
                    detail: "Watch whether readiness stays steadier after better fluids.",
                    icon: "heart.fill",
                    domain: .recovery
                ) : nil
            ])

        case .nutrition:
            return compact([
                InsightsWhyItem(
                    title: proteinGoal > 0 && averageProtein < proteinGoal * 0.8 ? "Fueling is under target" : "Fueling supports the next session",
                    value: averageProtein > 0 ? "\(Int(averageProtein.rounded()))g" : "\(mealRecords.count) meals",
                    detail: proteinGoal > 0 && averageProtein < proteinGoal * 0.8 ? "Protein is low enough to slow recovery from harder work." : "Consistent meals make recovery easier to interpret.",
                    icon: "fork.knife",
                    domain: .nutrition
                ),
                volume.hasMeaningfulLoad ? InsightsWhyItem(
                    title: "Training makes food matter",
                    value: workloadCategory(volume),
                    detail: "Harder weeks need recovery-focused meals, not just calories.",
                    icon: "figure.run",
                    domain: .activity
                ) : nil,
                averageRecovery > 0 ? InsightsWhyItem(
                    title: "Recovery is the outcome",
                    value: "\(Int(averageRecovery.rounded()))",
                    detail: "Use readiness to judge whether fueling is enough.",
                    icon: "heart.fill",
                    domain: .recovery
                ) : nil
            ])

        case .consistency, .missingData:
            let quality = makeDataQuality(records: records, recoverySleepRecords: recoverySleepRecords)
            return [
                InsightsWhyItem(
                    title: "Core signals need overlap",
                    value: "\(max(quality.sleepDays, quality.recoveryDays))/7",
                    detail: "Sleep and recovery need several shared days before the read is personal.",
                    icon: "sparkles",
                    domain: .missingData
                ),
                InsightsWhyItem(
                    title: "Training context is still forming",
                    value: "\(quality.activityDays) days",
                    detail: "A week of activity makes load easier to coach.",
                    icon: "figure.run",
                    domain: .activity
                ),
                InsightsWhyItem(
                    title: "Meals complete the picture",
                    value: "\(quality.mealDays) days",
                    detail: "Food logs help explain whether recovery is supported.",
                    icon: "fork.knife",
                    domain: .nutrition
                )
            ]
        }
    }

    private func makeNextActions(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight,
        coachContext: InsightsCoachContext?
    ) -> [InsightsNextAction] {
        var actions: [InsightsNextAction] = []

        if let coachContext, coachContext.shouldLeadInsights {
            actions.append(InsightsNextAction(
                title: primaryActionTitle(for: hero.domain, recommendation: coachContext.recommendation),
                detail: shortDetail(coachContext.recommendation),
                icon: coachContext.icon,
                destination: coachContext.actionDestination
            ))
        }

        actions.append(contentsOf: domainNextActions(
            records: records,
            recoverySleepRecords: recoverySleepRecords,
            hero: hero
        ))

        return deduplicatedNextActions(actions)
    }

    private func domainNextActions(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight
    ) -> [InsightsNextAction] {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let sleepRecords = recoverySleepRecords.filter { $0.sleepHours > 0 }
        let averageRecovery = average(recoveryRecords.map { Double($0.recoveryScore) })
        let averageSleep = average(sleepRecords.map(\.sleepHours))
        let volume = trainingVolumeSummary(records)
        let today = records.last
        let proteinGoal = today?.nutritionGoals?.protein ?? 0
        let protein = today?.proteinGrams ?? 0

        switch hero.domain {
        case .recovery:
            return compact([
                InsightsNextAction(
                    title: "Prioritize recovery tonight",
                    detail: averageRecovery > 0 && averageRecovery < 68 ? "Keep the evening low stress." : "Keep the rhythm steady.",
                    icon: "heart.fill",
                    destination: .detail(.recovery)
                ),
                volume.hasMeaningfulLoad ? InsightsNextAction(
                    title: "Watch recovery before adding load",
                    detail: "Compare readiness after harder days this week.",
                    icon: "figure.cooldown",
                    destination: .detail(.activity)
                ) : nil,
                averageSleep > 0 && averageSleep < 7 ? InsightsNextAction(
                    title: "Protect sleep tonight",
                    detail: "Aim for a clear 7+ hour window.",
                    icon: "moon.zzz.fill",
                    destination: .detail(.recovery)
                ) : nil
            ])

        case .sleep:
            return [
                InsightsNextAction(title: "Protect sleep tonight", detail: "Aim for a clear 7+ hour window.", icon: "moon.zzz.fill", destination: .detail(.recovery)),
                InsightsNextAction(title: "Set an earlier cutoff", detail: "Move the last screen or work block earlier.", icon: "alarm.fill", destination: .detail(.recovery))
            ]

        case .activity:
            return [
                InsightsNextAction(title: "Adjust the next session", detail: averageRecovery > 0 && averageRecovery < 68 ? "Keep it easy or move it." : "Progress only if recovery stays steady.", icon: "slider.horizontal.3", destination: .tab(.coach)),
                InsightsNextAction(title: "Keep intensity controlled", detail: "Make the next workout repeatable.", icon: "bolt.shield.fill", destination: .detail(.activity))
            ]

        case .hydration:
            return [
                InsightsNextAction(
                    title: "Watch fluids after high-load days",
                    detail: "Compare next-morning recovery after better fluid timing.",
                    icon: "drop.fill",
                    destination: .detail(.nutrition)
                ),
                InsightsNextAction(title: "Add fluids after training", detail: "Hard sessions need a deliberate refill.", icon: "bottle.fill", destination: .detail(.nutrition))
            ]

        case .nutrition:
            return compact([
                InsightsNextAction(title: "Watch meals around harder sessions", detail: "Compare recovery after better-timed meals.", icon: "fork.knife", destination: .detail(.nutrition)),
                proteinGoal > 0 && protein < proteinGoal ? InsightsNextAction(title: "Add protein to the next meal", detail: "Close the biggest recovery gap first.", icon: "takeoutbag.and.cup.and.straw.fill", destination: .detail(.nutrition)) : nil
            ])

        case .consistency, .missingData:
            return [
                InsightsNextAction(title: "Log consistently for 7 days", detail: "Sleep, meals, drinks and training are enough.", icon: "checkmark.circle.fill", destination: .tab(.today)),
                InsightsNextAction(title: "Build one complete week", detail: "A clean 7-day window beats scattered history.", icon: "calendar", destination: .tab(.today))
            ]
        }
    }

    private func narrativeConsistentWhyItems(_ items: [InsightsWhyItem], hero: InsightsHeroInsight) -> [InsightsWhyItem] {
        let filtered = items.filter { item in
            guard hero.domain != .hydration else { return true }
            return item.domain != .hydration
        }

        let allowed = filtered.filter { item in
            item.domain == hero.domain || supportingDomains(for: hero.domain).contains(item.domain)
        }

        let preferred = allowed.sorted { lhs, rhs in
            if lhs.domain == hero.domain, rhs.domain != hero.domain { return true }
            if rhs.domain == hero.domain, lhs.domain != hero.domain { return false }
            return false
        }

        return Array(deduplicatedWhyItems(preferred).prefix(3))
    }

    private func narrativeConsistentNextActions(_ actions: [InsightsNextAction], hero: InsightsHeroInsight) -> [InsightsNextAction] {
        Array(deduplicatedNextActions(actions).prefix(3))
    }

    private func supportingDomains(for domain: InsightsDomain) -> Set<InsightsDomain> {
        switch domain {
        case .recovery:
            return [.recovery, .sleep, .activity, .nutrition, .missingData, .consistency]
        case .sleep:
            return [.sleep, .recovery, .activity, .missingData, .consistency]
        case .activity:
            return [.activity, .recovery, .sleep, .nutrition, .missingData, .consistency]
        case .hydration:
            return [.hydration, .activity, .recovery, .missingData, .consistency]
        case .nutrition:
            return [.nutrition, .activity, .recovery, .missingData, .consistency]
        case .consistency, .missingData:
            return [.missingData, .consistency, .recovery, .sleep, .activity, .nutrition]
        }
    }

    private func defaultAction(for domain: InsightsDomain, destination: InsightsActionDestination?) -> InsightsNextAction {
        let resolvedDestination = destination ?? defaultDestination(for: domain)
        switch domain {
        case .recovery:
            return InsightsNextAction(title: "Prioritize recovery tonight", detail: nil, icon: "heart.fill", destination: resolvedDestination)
        case .sleep:
            return InsightsNextAction(title: "Protect sleep tonight", detail: nil, icon: "moon.zzz.fill", destination: resolvedDestination)
        case .hydration:
            return InsightsNextAction(title: "Watch fluids after high-load days", detail: nil, icon: "drop.fill", destination: resolvedDestination)
        case .nutrition:
            return InsightsNextAction(title: "Watch meals around harder sessions", detail: nil, icon: "fork.knife", destination: resolvedDestination)
        case .activity:
            return InsightsNextAction(title: "Adjust the next session", detail: nil, icon: "slider.horizontal.3", destination: resolvedDestination)
        case .consistency, .missingData:
            return InsightsNextAction(title: "Log consistently for 7 days", detail: nil, icon: "checkmark.circle.fill", destination: resolvedDestination)
        }
    }

    private func defaultDestination(for domain: InsightsDomain) -> InsightsActionDestination? {
        switch domain {
        case .activity:
            return .detail(.activity)
        case .nutrition, .hydration:
            return .detail(.nutrition)
        case .recovery, .sleep:
            return .detail(.recovery)
        case .consistency, .missingData:
            return .tab(.today)
        }
    }

    private func compactValue(
        for domain: InsightsDomain,
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> String {
        switch domain {
        case .recovery:
            let averageRecovery = average(recoverySleepRecords.filter { $0.recoveryScore > 0 }.map { Double($0.recoveryScore) })
            return averageRecovery > 0 ? "\(Int(averageRecovery.rounded()))" : InsightsLocalization.Section.building
        case .sleep:
            let averageSleep = average(recoverySleepRecords.filter { $0.sleepHours > 0 }.map(\.sleepHours))
            return averageSleep > 0 ? "\(formatOneDecimal(averageSleep))h" : InsightsLocalization.Section.building
        case .activity:
            let volume = trainingVolumeSummary(records)
            return volume.hasMeaningfulLoad ? formatDuration(Int((volume.hours * 60).rounded())) : InsightsLocalization.Section.building
        case .hydration:
            return formatLiters(records.last?.waterLiters ?? 0)
        case .nutrition:
            let protein = records.last?.proteinGrams ?? 0
            return protein > 0 ? "\(Int(protein.rounded()))g" : InsightsLocalization.Section.building
        case .consistency, .missingData:
            return InsightsLocalization.Section.building
        }
    }

    private func primaryActionTitle(for domain: InsightsDomain, recommendation: String) -> String {
        if recommendation.count <= 34 {
            return recommendation
        }

        return defaultAction(for: domain, destination: nil).title
    }

    private func shortDetail(_ text: String) -> String? {
        guard text.count > 34 else { return nil }
        return text.count <= 82 ? text : nil
    }

    private func deduplicatedWhyItems(_ items: [InsightsWhyItem]) -> [InsightsWhyItem] {
        var seen: Set<String> = []
        return items.filter { item in
            let key = item.title.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func deduplicatedNextActions(_ actions: [InsightsNextAction]) -> [InsightsNextAction] {
        var seen: Set<String> = []
        return actions.filter { action in
            let key = action.title.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    private func compact<T>(_ values: [T?]) -> [T] {
        values.compactMap { $0 }
    }

    private func confidenceBasisText(_ quality: InsightsDataQuality) -> String {
        let sleepText = quality.sleepDays >= 21 ? "consistent sleep history" : quality.sleepDays >= 7 ? "recent sleep history" : "limited sleep history"
        let recoveryText = quality.recoveryDays >= 21 ? "consistent recovery history" : quality.recoveryDays >= 7 ? "recent recovery history" : "limited recovery history"
        let trainingText = quality.activityDays >= 5 ? "a full recent training week" : "limited training history"
        let nutritionText = quality.mealDays >= 5 ? "useful nutrition context" : "limited nutrition data"
        return "Based on \(sleepText), \(recoveryText), \(trainingText) and \(nutritionText)."
    }

    private func observationWindowText(for domain: InsightsDomain, quality: InsightsDataQuality) -> String {
        switch domain {
        case .sleep:
            return quality.sleepDays >= 21 ? "Last month" : "Recent sleep"
        case .recovery:
            return quality.recoveryDays >= 21 ? "Last month" : "Recent recovery"
        case .activity:
            return quality.activityDays >= 5 ? "Recent training" : "Building training"
        case .nutrition:
            return quality.mealDays >= 5 ? "Recent nutrition" : "Building nutrition"
        case .hydration:
            return quality.hydrationDays >= 5 ? "Recent hydration" : "Building hydration"
        case .consistency:
            return "Recent pattern"
        case .missingData:
            return "Building your pattern"
        }
    }

    private func confidence(from quality: InsightsDataQuality) -> Double {
        let recovery = min(Double(quality.recoveryDays) / 7.0, 1.0)
        let sleep = min(Double(quality.sleepDays) / 7.0, 1.0)
        let activity = min(Double(quality.activityDays) / 7.0, 1.0)
        let meals = min(Double(quality.mealDays) / 7.0, 1.0)
        let hydration = min(Double(quality.hydrationDays) / 7.0, 1.0)
        return clamp((recovery * 0.28) + (sleep * 0.20) + (activity * 0.22) + (meals * 0.20) + (hydration * 0.10))
    }

    private func confidenceLabel(_ confidence: Double) -> String {
        switch confidence {
        case 0.78...:
            return "High"
        case 0.55..<0.78:
            return "Medium"
        default:
            return "Building"
        }
    }

    private func confidencePercent(_ confidence: Double) -> String {
        "\(Int((clamp(confidence) * 100).rounded()))%"
    }

    private func makeSupportCards(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight,
        coachContext: InsightsCoachContext?
    ) -> [InsightSupportCard] {
        switch hero.insightType {
        case .sleep:
            return sleepSupportCards(records: records, recoverySleepRecords: recoverySleepRecords, hero: hero)
        case .training:
            return trainingSupportCards(records: records, recoverySleepRecords: recoverySleepRecords, hero: hero)
        case .recovery:
            return recoverySupportCards(records: records, recoverySleepRecords: recoverySleepRecords, hero: hero)
        case .nutrition:
            return nutritionSupportCards(records: records, recoverySleepRecords: recoverySleepRecords, hero: hero)
        case .hydration:
            return hydrationSupportCards(records: records, recoverySleepRecords: recoverySleepRecords, hero: hero)
        case .consistency, .missingData:
            return genericSupportCards(records: records, recoverySleepRecords: recoverySleepRecords, hero: hero, coachContext: coachContext)
        }
    }

    private func sleepSupportCards(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight
    ) -> [InsightSupportCard] {
        let sleepRecords = recoverySleepRecords.filter { $0.sleepHours > 0 }
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let isOpportunity = recentSleep < 7 && recentRecovery >= 72
        let paired = recoverySleepRecords.filter { $0.sleepHours > 0 && $0.recoveryScore > 0 }
        let shortRecovery = average(paired.filter { $0.sleepHours < 6.75 }.map { Double($0.recoveryScore) })
        let longerRecovery = average(paired.filter { $0.sleepHours >= 7.0 }.map { Double($0.recoveryScore) })
        let recoveryLift = Int((longerRecovery - shortRecovery).rounded())

        var cards = [
            InsightSupportCard(
                role: .relationship,
                domain: .recovery,
                title: "Recovery response",
                text: sleepRecoveryContradictionText(recentSleep: recentSleep, recoveryLift: recoveryLift, recoveryRecords: recoveryRecords),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                metrics: [
                    InsightTrendMetric(label: "After longer sleep", value: recoveryLift > 0 ? "higher" : "steady", direction: recoveryLift >= 4 ? .increasing : .stable, detail: recoveryLift > 0 ? "recovery usually improves" : "no clear lift yet", benchmark: "compared with shorter nights")
                ]
            ),
            InsightSupportCard(
                role: .workload,
                domain: .activity,
                title: "Training context",
                text: isOpportunity
                    ? "Training is not forcing a recovery drop right now, which makes this an opportunity rather than a warning."
                    : trainingCoachingMeaning(trainingVolumeSummary(records), recoveryStable: false),
                icon: "figure.run",
                accent: WeekFitTheme.orange,
                metrics: [
                    workloadSignificanceMetric(trainingVolumeSummary(records))
                ]
            ),
            InsightSupportCard(
                role: .experiment,
                domain: .consistency,
                title: "Try this next",
                text: isOpportunity
                    ? "Go to bed 30 minutes earlier for the next 3 nights. If this is the opportunity, recovery should feel easier to sustain. Review after the third morning."
                    : "Go to bed 30 minutes earlier for the next 3 nights. If this is the limiter, recovery should start to rebound. Review after the third morning.",
                icon: "testtube.2",
                accent: hero.accent,
                metrics: coachingExperimentMetrics(action: "earlier bedtime", outcome: "easier recovery", window: "3 nights")
            )
        ]

        if nutritionMeaningfullyContributes(records) {
            cards.insert(
                InsightSupportCard(
                    role: .limitingFactor,
                    domain: .nutrition,
                    title: "Nutrition contribution",
                    text: nutritionContextText(records),
                    icon: "fork.knife",
                    accent: WeekFitTheme.blue,
                    metrics: [nutritionSupportMetric(records)]
                ),
                at: cards.count - 1
            )
        }

        return cards
    }

    private func trainingSupportCards(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight
    ) -> [InsightSupportCard] {
        let volume = trainingVolumeSummary(records)
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baselineRecovery = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryDirection = trendDirection(recent: recentRecovery, baseline: baselineRecovery, threshold: 2.0)
        let absorbing = recentRecovery >= baselineRecovery - 2 && recentRecovery > 0

        var cards = [
            InsightSupportCard(
                role: .adaptation,
                domain: .recovery,
                title: "Recovery response",
                text: workloadRecoveryContradictionText(volume: volume, absorbing: absorbing),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                metrics: [
                    InsightTrendMetric(label: "Recovery response", value: recoveryDirection == .decreasing ? "softening" : "holding", direction: recoveryDirection, detail: trendPhrase(recoveryDirection, improving: "starting to climb", declining: "starting to slip", stable: "holding steady"), benchmark: "watch the response after harder days")
                ]
            ),
            InsightSupportCard(
                role: .workload,
                domain: .activity,
                title: "Training meaning",
                text: trainingCoachingMeaning(volume, recoveryStable: absorbing),
                icon: "figure.run",
                accent: hero.accent,
                metrics: [
                    workloadSignificanceMetric(volume)
                ]
            ),
            InsightSupportCard(
                role: .progression,
                domain: .consistency,
                title: "What to try",
                text: nextTrainingProgression(volume, recoveryStable: absorbing),
                icon: "arrow.up.right",
                accent: hero.accent,
                metrics: [
                    InsightTrendMetric(label: "Try", value: volume.hours >= 3 ? "small bump" : "steady base", direction: .increasing, detail: "next week", benchmark: "only if recovery stays stable")
                ]
            )
        ]

        if nutritionMeaningfullyContributes(records) {
            cards.append(
                InsightSupportCard(
                    role: .risk,
                    domain: .nutrition,
                    title: "Nutrition contribution",
                    text: absorbing ? "Protein looks steady enough that nutrition is not the main explanation for the training response." : "Protein consistency may help explain why recovery is struggling with the current training week.",
                    icon: "fork.knife",
                    accent: WeekFitTheme.blue,
                    metrics: [nutritionSupportMetric(records)]
                )
            )
        } else {
            cards.append(
                InsightSupportCard(
                    role: .risk,
                    domain: .sleep,
                    title: "Sleep risk",
                    text: "Sleep context helps determine whether workload is truly the problem or recovery is being limited upstream.",
                    icon: "moon.fill",
                    accent: WeekFitTheme.purple,
                    metrics: [
                        InsightTrendMetric(label: "Sleep context", value: absorbing ? "contained" : "watch", direction: absorbing ? .stable : .increasing, detail: absorbing ? "recovery is holding" : "watch the next few nights", benchmark: "helps separate fatigue from poor sleep")
                    ]
                )
            )
        }

        return cards
    }

    private func recoverySupportCards(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight
    ) -> [InsightSupportCard] {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baselineRecovery = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let recoveryDirection = trendDirection(recent: recentRecovery, baseline: baselineRecovery, threshold: 2.0)
        let sleepRecords = recoverySleepRecords.filter { $0.sleepHours > 0 }
        let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
        let volume = trainingVolumeSummary(records)

        var cards = [
            InsightSupportCard(role: .resilience, domain: .recovery, title: "Recovery response", text: recoveryDirection == .decreasing ? "Recovery is starting to soften, so the next few days should protect readiness." : "Recovery is holding steady enough to treat this as a manageable week.", icon: "heart.fill", accent: hero.accent, metrics: [
                InsightTrendMetric(label: "Recovery feel", value: recoveryDirection == .decreasing ? "softening" : "steady", direction: recoveryDirection, detail: trendPhrase(recoveryDirection, improving: "starting to climb", declining: "starting to slip", stable: "holding steady"), benchmark: "watch how it reacts after training")
            ]),
            InsightSupportCard(role: .limitingFactor, domain: recentSleep < 7 ? .sleep : .activity, title: "What may be driving it", text: recentSleep < 7 ? "Short sleep is the clearest upstream pressure, especially if recovery is already under strain." : trainingCoachingMeaning(volume, recoveryStable: recentRecovery >= 72), icon: recentSleep < 7 ? "moon.fill" : "figure.run", accent: recentSleep < 7 ? WeekFitTheme.purple : WeekFitTheme.orange, metrics: [
                InsightTrendMetric(label: recentSleep < 7 ? "Sleep duration" : "Training week", value: recentSleep < 7 ? "\(formatOneDecimal(recentSleep))h" : workloadCategory(volume), direction: recentSleep < 7 ? .decreasing : .increasing, detail: recentSleep < 7 ? "below target" : "load needs managing", benchmark: recentSleep < 7 ? "below 7h target" : workloadCategoryDescription(volume))
            ]),
            InsightSupportCard(role: .opportunity, domain: .consistency, title: "What to watch", text: recentRecovery >= 72 ? "Keep the rhythm steady and only add a small progression if recovery still feels good." : "Give recovery room first; add load only after readiness stops sliding.", icon: "target", accent: hero.accent, metrics: [
                InsightTrendMetric(label: "Watch", value: recentRecovery >= 72 ? "steady rhythm" : "rebound", direction: recentRecovery >= 72 ? .increasing : .stable, detail: "next week", benchmark: "let recovery guide the change")
            ])
        ]

        if nutritionMeaningfullyContributes(records) {
            cards.insert(
                InsightSupportCard(role: .recoveryDriver, domain: .nutrition, title: "Nutrition contribution", text: nutritionContextText(records), icon: "fork.knife", accent: WeekFitTheme.blue, metrics: [
                    nutritionSupportMetric(records)
                ]),
                at: cards.count - 1
            )
        }

        return cards
    }

    private func nutritionSupportCards(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight
    ) -> [InsightSupportCard] {
        let proteinRecords = records.filter { $0.proteinGrams > 0 }
        let proteinGoal = records.last?.nutritionGoals?.protein ?? 0
        let averageProtein = average(proteinRecords.map(\.proteinGrams))
        let targetRatio = proteinGoal > 0 ? averageProtein / proteinGoal : 0
        return [
            InsightSupportCard(role: .strongestPattern, domain: .nutrition, title: "Nutrition contribution", text: targetRatio >= 0.8 ? "Protein looks close enough to support adaptation, so nutrition is not the main limiter right now." : "Protein remains below target and may be limiting adaptation around training.", icon: "fork.knife", accent: hero.accent, metrics: [
                InsightTrendMetric(label: "Protein support", value: targetRatio >= 0.8 ? "supportive" : "needs attention", direction: targetRatio >= 0.8 ? .stable : .decreasing, detail: targetRatio >= 0.8 ? "close enough" : "below target", benchmark: proteinGoal > 0 ? "use workout meals first" : "target unavailable")
            ]),
            InsightSupportCard(role: .experiment, domain: .consistency, title: "Try this next", text: coachingExperimentText(action: "Anchor protein around workouts for the next week.", outcome: "Recovery should become easier to read after harder sessions.", window: "Review after 7 days."), icon: "testtube.2", accent: hero.accent, metrics: coachingExperimentMetrics(action: "protein anchor", outcome: "clearer recovery", window: "7 days"))
        ]
    }

    private func nutritionContextText(_ records: [InsightsDayRecord]) -> String {
        let proteinRecords = records.filter { $0.proteinGrams > 0 }
        let proteinGoal = records.last?.nutritionGoals?.protein ?? 0
        let averageProtein = average(proteinRecords.map(\.proteinGrams))

        guard proteinGoal > 0, averageProtein > 0 else {
            return "There is not enough consistent nutrition data yet to draw a strong conclusion."
        }

        if averageProtein >= proteinGoal * 0.8 {
            return "Protein looks close enough that nutrition does not currently explain the recovery pattern."
        }

        return "Protein remains below target and may be limiting adaptation, especially around harder training."
    }

    private func nutritionMeaningfullyContributes(_ records: [InsightsDayRecord]) -> Bool {
        let proteinRecords = records.filter { $0.proteinGrams > 0 }
        let proteinGoal = records.last?.nutritionGoals?.protein ?? 0
        let averageProtein = average(proteinRecords.map(\.proteinGrams))

        guard proteinGoal > 0, proteinRecords.count >= 4, averageProtein > 0 else {
            return false
        }

        return averageProtein < proteinGoal * 0.8 || averageProtein >= proteinGoal * 0.95
    }

    private func nutritionSupportMetric(_ records: [InsightsDayRecord]) -> InsightTrendMetric {
        let proteinRecords = records.filter { $0.proteinGrams > 0 }
        let proteinGoal = records.last?.nutritionGoals?.protein ?? 0
        let averageProtein = average(proteinRecords.map(\.proteinGrams))
        let ratio = proteinGoal > 0 ? averageProtein / proteinGoal : 0

        return InsightTrendMetric(
            label: "Nutrition read",
            value: averageProtein > 0 ? (ratio >= 0.8 ? "supportive" : "limiting") : "not enough",
            direction: ratio >= 0.8 ? .stable : .decreasing,
            detail: ratio >= 0.8 ? "less likely to explain it" : "may limit adaptation",
            benchmark: proteinGoal > 0 ? "focus around workouts" : "log meals around training"
        )
    }

    private func hydrationSupportCards(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight
    ) -> [InsightSupportCard] {
        let waterRecords = records.filter { $0.waterLiters > 0 }
        let averageWater = average(waterRecords.map(\.waterLiters))
        return [
            InsightSupportCard(role: .relationship, domain: .hydration, title: "Hydration context", text: "Hydration only earns attention when it changes recovery after harder sessions.", icon: "drop.fill", accent: hero.accent, metrics: [
                InsightTrendMetric(label: "Fluid timing", value: averageWater > 0 ? "watch" : "unclear", direction: .stable, detail: "after hard days", benchmark: "fluids matter most after harder sessions")
            ]),
            InsightSupportCard(role: .experiment, domain: .consistency, title: "Try this next", text: coachingExperimentText(action: "Prioritize fluids around higher-load days.", outcome: "Recovery should stay steadier after harder sessions.", window: "Review after 1 training week."), icon: "testtube.2", accent: hero.accent, metrics: coachingExperimentMetrics(action: "target fluids", outcome: "steadier recovery", window: "1 week"))
        ]
    }

    private func workloadSignificanceText(_ volume: TrainingVolumeSummary) -> String {
        InsightsLocalization.VM.workloadSignificanceText(for: workloadCategory(volume))
    }

    private func trainingCoachingMeaning(_ volume: TrainingVolumeSummary, recoveryStable: Bool) -> String {
        switch workloadCategory(volume) {
        case "Recovery Week":
            return "Training is light enough that a coach would look beyond load for the main explanation."
        case "Light Week":
            return recoveryStable
                ? "This week looks easy to absorb, so the opportunity is building rhythm rather than pushing intensity."
                : "Because training is light, a recovery dip points toward sleep, stress or nutrition before load."
        case "Normal Week":
            return recoveryStable
                ? "This looks sustainable; repeatability matters more than adding another hard day."
                : "A normal week should be absorbable, so the recovery dip deserves attention."
        case "Productive Week":
            return recoveryStable
                ? "This is useful fitness-building work, and recovery holding steady means the load is currently productive."
                : "The week is productive on paper, but recovery says the next move should be restraint."
        case "Heavy Week":
            return recoveryStable
                ? "You handled a demanding week without a recovery drop, which is a strong adaptation sign."
                : "This is enough work that a coach would reduce intensity before adding more."
        default:
            return recoveryStable
                ? "You absorbed a very demanding week, so the smartest move is consolidation, not escalation."
                : "This is a very demanding week; recovery should decide the plan before motivation does."
        }
    }

    private func workloadSignificanceMetric(_ volume: TrainingVolumeSummary) -> InsightTrendMetric {
        let change = workloadBaselineChange(volume)
        let direction: InsightTrendDirection = change > 8 ? .increasing : change < -8 ? .decreasing : .stable
        return InsightTrendMetric(
            label: "Training week",
            value: workloadCategory(volume),
            direction: direction,
            detail: workloadCategoryDescription(volume),
            benchmark: direction == .increasing ? "watch recovery after hard days" : "use this to build rhythm"
        )
    }

    private func workloadCategory(_ volume: TrainingVolumeSummary) -> String {
        if volume.hours < 1.0 && volume.activeCalories < 900 {
            return "Recovery Week"
        }

        if volume.hours < 2.0 && volume.activeCalories < 1_800 {
            return "Light Week"
        }

        if volume.hours < 4.0 && volume.activeCalories < 3_500 {
            return "Normal Week"
        }

        if volume.hours < 6.5 && volume.activeCalories < 5_800 {
            return "Productive Week"
        }

        if volume.hours < 9.0 && volume.activeCalories < 8_000 {
            return "Heavy Week"
        }

        return "Very High Load Week"
    }

    private func workloadCategoryDescription(_ volume: TrainingVolumeSummary) -> String {
        switch workloadCategory(volume) {
        case "Recovery Week":
            return "mostly restorative"
        case "Light Week":
            return "easy to absorb"
        case "Normal Week":
            return "sustainable work"
        case "Productive Week":
            return "fitness-building load"
        case "Heavy Week":
            return "needs recovery support"
        default:
            return "requires restraint"
        }
    }

    private func workloadBaselineChange(_ volume: TrainingVolumeSummary) -> Double {
        let hourRatio = volume.hours / 3.0
        let calorieRatio = Double(volume.activeCalories) / 2_800.0
        let ratio = max(hourRatio, calorieRatio)
        return (ratio - 1.0) * 100.0
    }

    private func sleepRecoveryContradictionText(
        recentSleep: Double,
        recoveryLift: Int,
        recoveryRecords: [InsightsDayRecord]
    ) -> String {
        let recentRecovery = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        if recentSleep < 7, recentRecovery >= 72 {
            return "Interesting: sleep is low, but recovery remains strong. That makes this a coaching question, not a guaranteed limiter."
        }

        if recoveryLift >= 4 {
            return "Recovery is about \(recoveryLift) points higher after longer sleep, which supports the hero story."
        }

        return "Recovery does not show a strong lift after longer sleep yet, so the conclusion stays cautious."
    }

    private func workloadRecoveryContradictionText(volume: TrainingVolumeSummary, absorbing: Bool) -> String {
        let highWorkload = workloadBaselineChange(volume) > 15
        if highWorkload, absorbing {
            return "Interesting: this was a demanding training week, but recovery stayed stable. That is a stronger adaptation signal than workload alone."
        }

        if absorbing {
            return "Recovery stayed stable despite the workload, which suggests good adaptation."
        }

        return "Recovery is trending down against this workload, which suggests the load may need restraint."
    }

    private func coachingExperimentText(action: String, outcome: String, window: String) -> String {
        "\(action) \(outcome) \(window)"
    }

    private func coachingExperimentMetrics(action: String, outcome: String, window: String) -> [InsightTrendMetric] {
        [
            InsightTrendMetric(label: "Action", value: action, direction: .increasing, detail: "keep it simple", benchmark: "try this"),
            InsightTrendMetric(label: "Expected", value: outcome, direction: .increasing, detail: "watch the response", benchmark: "look for"),
            InsightTrendMetric(label: "Review", value: window, direction: .stable, detail: "check back", benchmark: "after")
        ]
    }

    private func genericSupportCards(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight,
        coachContext: InsightsCoachContext?
    ) -> [InsightSupportCard] {
        [
            InsightSupportCard(role: .strongestPattern, domain: .missingData, title: "What is missing", text: "Insights needs enough overlapping sleep, recovery, training and nutrition to explain what changed over the last month.", icon: "sparkles", accent: hero.accent, metrics: [
                InsightTrendMetric(label: "Read", value: coachContext == nil ? "building" : "today", direction: .stable, detail: "not enough overlap yet", benchmark: "keep logging the core signals")
            ]),
            InsightSupportCard(role: .opportunity, domain: .consistency, title: "Pattern to build", text: "The next useful signal is a cleaner 7-day window inside the 30-day history.", icon: "target", accent: hero.accent, metrics: [
                InsightTrendMetric(label: "Watch", value: "logging rhythm", direction: .stable, detail: "build the picture", benchmark: "sleep, recovery, training, meals")
            ])
        ]
    }

    private func trendDirection(recent: Double, baseline: Double, threshold: Double) -> InsightTrendDirection {
        guard baseline > 0, recent > 0 else { return .stable }
        if recent - baseline >= threshold { return .increasing }
        if baseline - recent >= threshold { return .decreasing }
        return .stable
    }

    private func trendPhrase(
        _ direction: InsightTrendDirection,
        improving: String,
        declining: String,
        stable: String
    ) -> String {
        switch direction {
        case .increasing:
            return improving
        case .decreasing:
            return declining
        case .stable:
            return stable
        }
    }

    private func benchmarkText(recent: Double, baseline: Double, unit: String) -> String {
        guard baseline > 0, recent > 0 else { return "baseline is still forming" }
        let change = recent - baseline
        if abs(change) < 0.1 {
            return "stable vs baseline"
        }

        let prefix = change > 0 ? "higher than baseline by" : "below baseline by"
        return "\(prefix) \(formatOneDecimal(abs(change)))\(unit)"
    }

    private func targetGapText(value: Double, target: Double, unit: String) -> String {
        let gap = value - target
        if abs(gap) < 0.05 { return "on target" }
        return gap > 0 ? "+\(formatOneDecimal(gap))\(unit)" : "-\(formatOneDecimal(abs(gap)))\(unit)"
    }

    private struct TrainingVolumeSummary {
        let hours: Double
        let activeCalories: Int
        let sessions: Int

        var hasMeaningfulLoad: Bool {
            hours >= 1.0 || activeCalories >= 900 || sessions >= 2
        }

        var sentence: String {
            if sessions > 0 {
                return "Workload has enough shape to learn from."
            }

            return "Training rhythm is still forming."
        }

        var badgeValue: String {
            "\(formattedHours)h"
        }

        private var formattedHours: String {
            String(format: "%.1f", hours)
        }
    }

    private func trainingVolumeSummary(_ records: [InsightsDayRecord]) -> TrainingVolumeSummary {
        let hours = records.reduce(0.0) { total, record in
            let minutes = max(Double(record.metrics.exerciseMinutes), Double(record.completedWorkoutMinutes))
            return total + minutes / 60.0
        }
        let calories = records.reduce(0.0) { $0 + recordActiveCalories($1) }
        let sessions = records.reduce(0) { $0 + $1.completedWorkoutCount }

        return TrainingVolumeSummary(
            hours: hours,
            activeCalories: Int(calories.rounded()),
            sessions: sessions
        )
    }

    private func recordActiveCalories(_ record: InsightsDayRecord) -> Double {
        record.metrics.activeCalories
    }

    private func trainingLoadTier(_ volume: TrainingVolumeSummary) -> String {
        if volume.hours >= 6.0 || volume.activeCalories >= 5_500 {
            return "advanced-amateur-level load"
        }

        if volume.hours >= 3.0 || volume.activeCalories >= 2_800 {
            return "solid recreational load"
        }

        if volume.hours >= 1.0 || volume.activeCalories >= 900 {
            return "light base-building load"
        }

        return "early training load"
    }

    private func nextTrainingProgression(_ volume: TrainingVolumeSummary, recoveryStable: Bool) -> String {
        if !recoveryStable {
            return InsightsLocalization.text("insights.vm.progression.holdUntilRecovery")
        }

        if volume.hours >= 6.0 || volume.activeCalories >= 5_500 {
            return InsightsLocalization.text("insights.vm.progression.betterDistribution")
        }

        if volume.hours >= 3.0 || volume.activeCalories >= 2_800 {
            return InsightsLocalization.text("insights.vm.progression.controlledSession")
        }

        return InsightsLocalization.text("insights.vm.progression.buildThreeHours")
    }

    private func makeLearnings(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        dataQuality: InsightsDataQuality,
        hero: InsightsHeroInsight
    ) -> [InsightsLearning] {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let activityRecords = records.filter(\.hasActivitySignal)
        let mealRecords = records.filter { $0.mealCount > 0 }
        let averageRecovery = average(recoveryRecords.map { Double($0.recoveryScore) })
        let averageSleep = average(sleepRecords.map(\.sleepHours))

        var learnings: [InsightsLearning] = []

        if activityRecords.count >= 6, averageRecovery >= 72 {
            let volume = trainingVolumeSummary(records)
            learnings.append(InsightsLearning(
                label: InsightsLocalization.Section.strongestPattern,
                title: InsightsLocalization.text("insights.vm.learnings.absorbingWorkload.title"),
                text: InsightsLocalization.format(
                    "insights.vm.learnings.absorbingWorkload.textFormat",
                    workloadSignificanceText(volume)
                ),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                domain: .recovery
            ))
        } else if activityRecords.count >= 5, averageRecovery > 0, averageRecovery < 68 {
            let volume = trainingVolumeSummary(records)
            learnings.append(InsightsLearning(
                label: InsightsLocalization.Section.strongestPattern,
                title: InsightsLocalization.text("insights.vm.learnings.loadPressing.title"),
                text: InsightsLocalization.format(
                    "insights.vm.learnings.loadPressing.textFormat",
                    workloadSignificanceText(volume)
                ),
                icon: "figure.run",
                accent: WeekFitTheme.orange,
                domain: .activity
            ))
        } else if recoveryRecords.count >= 7 {
            learnings.append(InsightsLearning(
                label: InsightsLocalization.Section.strongestPattern,
                title: averageRecovery >= 72
                    ? InsightsLocalization.text("insights.vm.learnings.recoveryStable.title")
                    : InsightsLocalization.text("insights.vm.learnings.recoveryWatch.title"),
                text: averageRecovery >= 72
                    ? InsightsLocalization.text("insights.vm.learnings.recoveryStable.text")
                    : InsightsLocalization.text("insights.vm.learnings.recoveryWatch.text"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                domain: .recovery
            ))
        }

        if sleepRecords.count >= 7 {
            let recentSleep = average(Array(sleepRecords.suffix(7)).map(\.sleepHours))
            let earlierSleep = average(Array(sleepRecords.prefix(max(0, sleepRecords.count - 7))).map(\.sleepHours))
            let sleepText: String
            if earlierSleep > 0, recentSleep - earlierSleep >= 0.25 {
                sleepText = InsightsLocalization.text("insights.vm.learnings.sleepImproved.text")
            } else if averageSleep < 7 {
                sleepText = InsightsLocalization.text("insights.vm.learnings.sleepBelowTarget.text")
            } else {
                sleepText = InsightsLocalization.text("insights.vm.learnings.sleepConsistent.text")
            }

            learnings.append(InsightsLearning(
                label: InsightsLocalization.Section.emergingTrend,
                title: averageSleep < 7
                    ? InsightsLocalization.text("insights.vm.learnings.sleepLever.title")
                    : InsightsLocalization.text("insights.vm.learnings.sleepBase.title"),
                text: sleepText,
                icon: "moon.fill",
                accent: WeekFitTheme.purple,
                domain: .sleep
            ))
        }

        if let shortSleepLearning = shortSleepRecoveryLearning(from: recoverySleepRecords) {
            learnings.append(shortSleepLearning)
        }

        if mealRecords.count < 5 {
            learnings.append(InsightsLearning(
                label: InsightsLocalization.Section.weakestSignal,
                title: InsightsLocalization.text("insights.vm.learnings.nutritionUnclear.title"),
                text: InsightsLocalization.text("insights.vm.learnings.nutritionUnclear.text"),
                icon: "fork.knife",
                accent: WeekFitTheme.blue,
                domain: .nutrition
            ))
        }

        if learnings.isEmpty {
            learnings.append(InsightsLearning(
                label: InsightsLocalization.Section.whatWeLearned,
                title: InsightsLocalization.text("insights.vm.learnings.patternForming.title"),
                text: InsightsLocalization.text("insights.vm.learnings.patternForming.text"),
                icon: "sparkles",
                accent: WeekFitTheme.meal,
                domain: .missingData
            ))
        }

        let distinct = deduplicatedLearnings(learnings, avoiding: hero.domain)
        if distinct.isEmpty {
            return [
                InsightsLearning(
                    label: InsightsLocalization.Section.adjacentSignal,
                    title: InsightsLocalization.text("insights.vm.learnings.adjacent.title"),
                    text: InsightsLocalization.text("insights.vm.learnings.adjacent.text"),
                    icon: "sparkles",
                    accent: WeekFitTheme.meal,
                    domain: .missingData
                )
            ]
        }

        return Array(distinct.prefix(4))
    }

    private func shortSleepRecoveryLearning(from records: [InsightsDayRecord]) -> InsightsLearning? {
        let paired = records.filter { $0.sleepHours > 0 && $0.recoveryScore > 0 }
        let shortSleep = paired.filter { $0.sleepHours < 6.75 }
        let enoughSleep = paired.filter { $0.sleepHours >= 7.0 }

        guard shortSleep.count >= 3, enoughSleep.count >= 3 else { return nil }

        let shortRecovery = average(shortSleep.map { Double($0.recoveryScore) })
        let enoughRecovery = average(enoughSleep.map { Double($0.recoveryScore) })
        let difference = Int((enoughRecovery - shortRecovery).rounded())

        guard difference >= 4 else { return nil }

        return InsightsLearning(
            label: InsightsLocalization.Section.recoveryClue,
            title: InsightsLocalization.text("insights.vm.learnings.shortSleep.title"),
            text: InsightsLocalization.format("insights.vm.learnings.shortSleep.textFormat", difference),
            icon: "bed.double.fill",
            accent: WeekFitTheme.purple,
            domain: .sleep
        )
    }

    private func deduplicatedLearnings(
        _ learnings: [InsightsLearning],
        avoiding heroDomain: InsightsDomain
    ) -> [InsightsLearning] {
        var seenLabels: Set<String> = []
        return learnings.filter { learning in
            let key = "\(learning.label).\(learning.domain)"
            guard !seenLabels.contains(key) else { return false }
            seenLabels.insert(key)
            return learning.domain != heroDomain || learning.domain == .missingData
        }
    }

    private func makeOpportunity(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        hero: InsightsHeroInsight,
        coachContext: InsightsCoachContext?
    ) -> InsightsOpportunity? {
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let averageSleep = average(sleepRecords.map(\.sleepHours))
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let averageRecovery = average(recoveryRecords.map { Double($0.recoveryScore) })
        let mealDays = records.filter { $0.mealCount > 0 }.count

        switch hero.domain {
        case .sleep where averageSleep > 0 && averageSleep < 7:
            return InsightsOpportunity(
                label: InsightsLocalization.Section.biggestOpportunity,
                title: InsightsLocalization.text("insights.vm.opportunity.sleepBottleneck.title"),
                text: InsightsLocalization.text("insights.vm.opportunity.sleepBottleneck.text"),
                icon: "moon.zzz.fill",
                accent: WeekFitTheme.purple,
                domain: .sleep,
                actionDestination: .detail(.recovery)
            )
        case .activity where averageRecovery > 0 && averageRecovery < 68:
            return InsightsOpportunity(
                label: InsightsLocalization.Section.biggestOpportunity,
                title: InsightsLocalization.text("insights.vm.opportunity.proveLoad.title"),
                text: InsightsLocalization.text("insights.vm.opportunity.proveLoad.text"),
                icon: "bolt.shield.fill",
                accent: WeekFitTheme.orange,
                domain: .activity,
                actionDestination: .detail(.activity)
            )
        case .nutrition where mealDays < 7:
            return InsightsOpportunity(
                label: InsightsLocalization.Section.biggestOpportunity,
                title: InsightsLocalization.text("insights.vm.opportunity.nutritionVisible.title"),
                text: InsightsLocalization.text("insights.vm.opportunity.nutritionVisible.text"),
                icon: "fork.knife",
                accent: WeekFitTheme.blue,
                domain: .nutrition,
                actionDestination: .detail(.nutrition)
            )
        case .recovery where averageRecovery >= 72:
            return InsightsOpportunity(
                label: InsightsLocalization.Section.mostLikelyNextImprovement,
                title: InsightsLocalization.text("insights.vm.opportunity.keepRhythm.title"),
                text: InsightsLocalization.text("insights.vm.opportunity.keepRhythm.text"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                domain: .recovery,
                actionDestination: .detail(.recovery)
            )
        default:
            return nil
        }
    }

    private func coachVisualization(
        for domain: InsightsDomain,
        records: [InsightsDayRecord],
        historyRecords: [InsightsDayRecord],
        recoveryValues: [Double]
    ) -> InsightVisualization {
        switch domain {
        case .activity:
            return .correlation(
                primary: recoveryValues,
                secondary: smoothedTrendValues(historyRecords.map(\.activityLoadGraphValue)),
                primaryLabel: "recovery",
                secondaryLabel: "load"
            )
        case .nutrition:
            return .trendLine(
                values: smoothedTrendValues(records.map(\.proteinGraphValue)),
                target: 0.80,
                targetLabel: "protein target"
            )
        case .hydration:
            return .trendLine(
                values: smoothedTrendValues(records.map(\.hydrationGraphValue)),
                target: 0.70,
                targetLabel: "hydration target"
            )
        case .consistency:
            return .consistency(
                values: records.map(\.hasActivitySignal),
                positiveLabel: "signal",
                negativeLabel: "gap"
            )
        case .missingData:
            return .contributionBreakdown(segments: [
                InsightContribution(label: "recovery", value: 0.30, color: WeekFitTheme.meal),
                InsightContribution(label: "sleep", value: 0.24, color: WeekFitTheme.purple),
                InsightContribution(label: "training", value: 0.18, color: WeekFitTheme.orange)
            ])
        case .sleep, .recovery:
            return .trendLine(
                values: recoveryValues,
                target: targetValue(for: domain),
                targetLabel: targetLabel(for: domain)
            )
        }
    }

    private func targetValue(for domain: InsightsDomain) -> Double? {
        switch domain {
        case .sleep:
            return 0.70
        case .recovery:
            return 0.72
        case .activity:
            return 0.70
        case .nutrition:
            return 0.80
        case .hydration:
            return 0.70
        case .consistency, .missingData:
            return nil
        }
    }

    private func targetLabel(for domain: InsightsDomain) -> String? {
        switch domain {
        case .sleep:
            return "70 sleep score"
        case .recovery:
            return "72 target"
        case .activity:
            return "high load"
        case .nutrition:
            return "protein target"
        case .hydration:
            return "hydration target"
        case .consistency, .missingData:
            return nil
        }
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
                title: InsightsLocalization.Section.recovery,
                value: recoveryRecords.count > 0 ? "\(Int(recoveryAverage.rounded()))" : "—",
                detail: recoveryRecords.count >= 21
                    ? InsightsLocalization.text("insights.vm.weekly.consistentHistory")
                    : InsightsLocalization.text("insights.vm.weekly.recentHistory"),
                missingDetail: InsightsLocalization.text("insights.vm.weekly.connectHealth"),
                destination: .recovery
            ),
            weeklyMetric(
                icon: "moon.fill",
                iconColor: WeekFitTheme.purple,
                title: InsightsLocalization.Section.sleep,
                value: sleepRecords.count > 0 ? "\(formatOneDecimal(averageSleepHours))h" : "—",
                detail: sleepRecords.count >= 21
                    ? InsightsLocalization.text("insights.vm.weekly.consistentHistory")
                    : InsightsLocalization.text("insights.vm.weekly.recentHistory"),
                missingDetail: InsightsLocalization.text("insights.vm.weekly.connectSleep"),
                destination: .recovery
            ),
            weeklyMetric(
                icon: "bolt.fill",
                iconColor: WeekFitTheme.orange,
                title: InsightsLocalization.Section.training,
                value: activeDays > 0 ? "\(activeDays)" : "—",
                detail: activeDays >= 5
                    ? InsightsLocalization.text("insights.vm.weekly.fullRecentWeek")
                    : InsightsLocalization.text("insights.vm.weekly.syncOrLog"),
                missingDetail: InsightsLocalization.text("insights.vm.weekly.syncOrLog"),
                destination: .activity
            ),
            weeklyMetric(
                icon: "fork.knife",
                iconColor: WeekFitTheme.blue,
                title: InsightsLocalization.Section.nutrition,
                value: proteinRecords.count > 0 ? "\(proteinRecords.count)" : "—",
                detail: proteinGoal > 0 && proteinTargetDays >= 5
                    ? InsightsLocalization.text("insights.vm.weekly.proteinConsistent")
                    : InsightsLocalization.text("insights.vm.weekly.loggingBuilding"),
                missingDetail: InsightsLocalization.text("insights.vm.weekly.logMeals"),
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
            makeRecoveryTrendInsight(recoverySleepRecords: recoverySleepRecords),
            makeTrainingRecoveryInsight(records: records, recoverySleepRecords: recoverySleepRecords),
            makeNutritionInsight(records: records, recoverySleepRecords: recoverySleepRecords)
        ]
    }

    private func makeRecoveryTrendInsight(
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsTrendCard {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let recoveryValues = recoveryRecords.map { Double($0.recoveryScore) }
        let recent = average(Array(recoveryRecords.suffix(7)).map { Double($0.recoveryScore) })
        let baseline = average(Array(recoveryRecords.dropLast(7)).map { Double($0.recoveryScore) })
        let latest = recoveryRecords.last?.recoveryScore ?? 0
        let direction = trendDirection(recent: recent, baseline: baseline, threshold: 2.0)

        guard recoveryRecords.count >= 7 else {
            return InsightsTrendCard(
                accent: WeekFitTheme.meal,
                label: InsightsLocalization.Section.recoveryResponse,
                title: InsightsLocalization.text("insights.vm.trend.recoveryBuilding.title"),
                subtitle: InsightsLocalization.text("insights.vm.trend.recoveryBuilding.subtitle"),
                takeaway: InsightsLocalization.text("insights.vm.trend.recoveryBuilding.takeaway"),
                icon: "heart.fill",
                domain: .recovery,
                actionDestination: .detail(.recovery)
            )
        }

        let title: String
        let takeaway: String
        switch direction {
        case .decreasing:
            title = InsightsLocalization.text("insights.vm.trend.recoveryLosing.title")
            takeaway = InsightsLocalization.text("insights.vm.trend.recoveryLosing.takeaway")
        case .increasing:
            title = InsightsLocalization.text("insights.vm.trend.recoveryRebounding.title")
            takeaway = InsightsLocalization.text("insights.vm.trend.recoveryRebounding.takeaway")
        case .stable:
            title = recent >= 72
                ? InsightsLocalization.text("insights.vm.trend.recoveryResilient.title")
                : InsightsLocalization.text("insights.vm.trend.recoveryStableNotHigh.title")
            takeaway = recent >= 72
                ? InsightsLocalization.text("insights.vm.trend.recoveryResilient.takeaway")
                : InsightsLocalization.text("insights.vm.trend.recoveryStableNotHigh.takeaway")
        }

        let subtitle: String
        if baseline > 0 {
            subtitle = InsightsLocalization.format(
                "insights.vm.trend.recoveryCompareFormat",
                Int(recent.rounded()),
                Int(baseline.rounded()),
                latest
            )
        } else {
            subtitle = InsightsLocalization.format(
                "insights.vm.trend.recoveryDaysFormat",
                recoveryValues.count,
                latest
            )
        }

        return InsightsTrendCard(
            accent: WeekFitTheme.meal,
            label: InsightsLocalization.Section.recoveryResponse,
            title: title,
            subtitle: subtitle,
            takeaway: takeaway,
            icon: "chart.line.uptrend.xyaxis",
            domain: .recovery,
            actionDestination: .detail(.recovery)
        )
    }

    private func makeTrainingRecoveryInsight(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord]
    ) -> InsightsTrendCard {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let averageRecovery = average(recoveryRecords.map { Double($0.recoveryScore) })
        let volume = trainingVolumeSummary(records)

        guard volume.hasMeaningfulLoad else {
            return InsightsTrendCard(
                accent: WeekFitTheme.orange,
                label: InsightsLocalization.Section.trainingAndRecovery,
                title: InsightsLocalization.text("insights.vm.trend.trainingForming.title"),
                subtitle: InsightsLocalization.text("insights.vm.trend.trainingForming.subtitle"),
                takeaway: InsightsLocalization.text("insights.vm.trend.trainingForming.takeaway"),
                icon: "figure.run",
                domain: .activity,
                actionDestination: .detail(.activity)
            )
        }

        guard recoveryRecords.count >= 7 else {
            return InsightsTrendCard(
                accent: WeekFitTheme.orange,
                label: InsightsLocalization.Section.trainingAndRecovery,
                title: InsightsLocalization.text("insights.vm.trend.trainingMissingContext.title"),
                subtitle: workloadSignificanceText(volume),
                takeaway: InsightsLocalization.text("insights.vm.trend.trainingMissingContext.takeaway"),
                icon: "figure.run",
                domain: .activity,
                actionDestination: .detail(.activity)
            )
        }

        if averageRecovery >= 72 {
            return InsightsTrendCard(
                accent: WeekFitTheme.orange,
                label: InsightsLocalization.Section.trainingAndRecovery,
                title: InsightsLocalization.text("insights.vm.trend.trainingKeepingUp.title"),
                subtitle: InsightsLocalization.format(
                    "insights.vm.trend.trainingKeepingUp.subtitleFormat",
                    workloadSignificanceText(volume)
                ),
                takeaway: nextTrainingProgression(volume, recoveryStable: true),
                icon: "figure.run",
                domain: .activity,
                actionDestination: .detail(.activity)
            )
        }

        return InsightsTrendCard(
            accent: WeekFitTheme.orange,
            label: InsightsLocalization.Section.trainingAndRecovery,
            title: InsightsLocalization.text("insights.vm.trend.trainingLighterWeek.title"),
            subtitle: InsightsLocalization.format(
                "insights.vm.trend.trainingLighterWeek.subtitleFormat",
                workloadSignificanceText(volume)
            ),
            takeaway: nextTrainingProgression(volume, recoveryStable: false),
            icon: "figure.run",
            domain: .activity,
            actionDestination: .detail(.activity)
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
                label: InsightsLocalization.Section.nutritionInsight,
                title: InsightsLocalization.text("insights.vm.trend.nutritionNotEnough.title"),
                subtitle: WeekFitCountPluralization.insightsLogMealsOnMoreDaysSubtitle(needed: needed),
                takeaway: InsightsLocalization.text("insights.vm.trend.nutritionNotEnough.takeaway"),
                icon: "fork.knife",
                domain: .nutrition,
                actionDestination: .detail(.nutrition)
            )
        }

        if proteinGoal > 0, proteinTargetDays < 4 {
            return InsightsTrendCard(
                accent: WeekFitTheme.meal,
                label: InsightsLocalization.Section.nutritionInsight,
                title: InsightsLocalization.text("insights.vm.trend.proteinLimiting.title"),
                subtitle: InsightsLocalization.format(
                    "insights.vm.trend.proteinLimiting.subtitleFormat",
                    proteinTargetDays
                ),
                takeaway: InsightsLocalization.text("insights.vm.trend.proteinLimiting.takeaway"),
                icon: "fork.knife",
                domain: .nutrition,
                actionDestination: .detail(.nutrition)
            )
        }

        if recoveryRecords.count >= 7 {
            return InsightsTrendCard(
                accent: WeekFitTheme.meal,
                label: InsightsLocalization.Section.nutritionInsight,
                title: InsightsLocalization.text("insights.vm.trend.nutritionSupporting.title"),
                subtitle: proteinGoal > 0
                    ? InsightsLocalization.format("insights.vm.trend.nutritionSupporting.proteinFormat", proteinTargetDays)
                    : InsightsLocalization.text("insights.vm.trend.nutritionSupporting.mealsConsistent"),
                takeaway: InsightsLocalization.text("insights.vm.trend.nutritionSupporting.takeaway"),
                icon: "fork.knife",
                domain: .nutrition,
                actionDestination: .detail(.nutrition)
            )
        }

        return InsightsTrendCard(
            accent: WeekFitTheme.meal,
            label: InsightsLocalization.Section.nutritionInsight,
            title: InsightsLocalization.text("insights.vm.trend.nutritionImproving.title"),
            subtitle: proteinGoal > 0
                ? InsightsLocalization.format("insights.vm.trend.nutritionSupporting.proteinFormat", proteinTargetDays)
                : InsightsLocalization.text("insights.vm.trend.nutritionSupporting.mealsConsistent"),
            takeaway: InsightsLocalization.text("insights.vm.trend.nutritionImproving.takeaway"),
            icon: "fork.knife",
            domain: .nutrition,
            actionDestination: .detail(.nutrition)
        )
    }

    private func makeHydrationImpact(records: [InsightsDayRecord]) -> InsightsCorrelationCard {
        let paired = records.filter { $0.waterLiters > 0 && $0.recoveryScore > 0 }
        let hydrationValues = lastThreeValues(records.map(\.waterLiters), formatter: formatLiters)
        let recoveryValues = lastThreeValues(records.map { Double($0.recoveryScore) }, formatter: { value in
            value > 0 ? "\(Int(value.rounded()))" : "—"
        })

        let rows = [
            InsightsCorrelationRow(icon: "drop.fill", title: InsightsLocalization.text("insights.vm.hydration.waterEvidence"), values: hydrationValues, color: WeekFitTheme.blue),
            InsightsCorrelationRow(icon: "heart.fill", title: InsightsLocalization.text("insights.vm.hydration.recoveryContext"), values: recoveryValues, color: WeekFitTheme.meal)
        ]

        guard paired.count == 7 else {
            let needed = max(1, 7 - paired.count)
            return InsightsCorrelationCard(
                label: InsightsLocalization.Section.hydrationInsight,
                title: InsightsLocalization.text("insights.vm.hydration.unavailable.title"),
                subtitle: WeekFitCountPluralization.insightsLogDrinksOnMoreDaysSubtitle(needed: needed),
                rows: rows
            )
        }

        let sorted = paired.sorted { $0.waterLiters < $1.waterLiters }
        let splitIndex = sorted.count / 2
        let lower = Array(sorted.prefix(splitIndex))
        let higher = Array(sorted.suffix(sorted.count - splitIndex))

        guard lower.count >= 2, higher.count >= 2 else {
            return InsightsCorrelationCard(
                label: InsightsLocalization.Section.hydrationInsight,
                title: InsightsLocalization.text("insights.vm.hydration.cleanerSample.title"),
                subtitle: InsightsLocalization.text("insights.vm.hydration.cleanerSample.subtitle"),
                rows: rows
            )
        }

        let lowerRecovery = average(lower.map { Double($0.recoveryScore) })
        let higherRecovery = average(higher.map { Double($0.recoveryScore) })
        let difference = Int((higherRecovery - lowerRecovery).rounded())

        if abs(difference) < 5 {
            return InsightsCorrelationCard(
                label: InsightsLocalization.Section.hydrationInsight,
                title: InsightsLocalization.text("insights.vm.hydration.notLimiter.title"),
                subtitle: InsightsLocalization.text("insights.vm.hydration.notLimiter.subtitle"),
                rows: rows
            )
        }

        return InsightsCorrelationCard(
            label: InsightsLocalization.Section.hydrationInsight,
            title: difference > 0
                ? InsightsLocalization.text("insights.vm.hydration.helping.title")
                : InsightsLocalization.text("insights.vm.hydration.notRecoveryLimiter.title"),
            subtitle: difference > 0
                ? InsightsLocalization.format("insights.vm.hydration.helping.subtitleFormat", difference)
                : InsightsLocalization.text("insights.vm.hydration.notRecoveryLimiter.subtitle"),
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
            return InsightsReflection(
                label: InsightsLocalization.Section.weeklyReflection,
                text: InsightsLocalization.text("insights.vm.reflection.needsDays"),
                domain: .missingData,
                actionDestination: .tab(.today)
            )
        }

        let domainCounts: [(domain: InsightsDomain, name: String, count: Int, target: Int)] = [
            (.recovery, InsightsLocalization.text("insights.vm.reflection.domain.recovery"), recoveryDays, 7),
            (.sleep, InsightsLocalization.text("insights.vm.reflection.domain.sleep"), sleepDays, 7),
            (.hydration, InsightsLocalization.text("insights.vm.reflection.domain.hydration"), hydrationDays, 7),
            (.nutrition, InsightsLocalization.text("insights.vm.reflection.domain.nutrition"), mealDays, 7),
            (.activity, InsightsLocalization.text("insights.vm.reflection.domain.activity"), activityDays, 7)
        ]

        if let unlock = domainCounts
            .filter({ $0.count < $0.target && !usedDomains.contains($0.domain) })
            .sorted(by: { ($0.target - $0.count) > ($1.target - $1.count) })
            .first {
            let needed = max(1, unlock.target - unlock.count)
            return InsightsReflection(
                label: InsightsLocalization.Section.weeklyReflection,
                text: WeekFitCountPluralization.insightsMoreDomainDaysReflection(
                    needed: needed,
                    domainName: unlock.name
                ),
                domain: unlock.domain
            )
        }

        if let coachInsight = nutritionViewModel.nutritionResult?.activeInsights.first,
           let coachDomain = domain(for: coachInsight),
           !usedDomains.contains(coachDomain) {
            return InsightsReflection(
                label: InsightsLocalization.Section.weeklyReflection,
                text: InsightsLocalization.format(
                    "insights.vm.reflection.coachPatternFormat",
                    coachInsight.title
                ),
                domain: coachDomain
            )
        }

        let strongest = strongestDomainName(from: domainCounts)
        return InsightsReflection(
            label: InsightsLocalization.Section.weeklyReflection,
            text: InsightsLocalization.format(
                "insights.vm.reflection.clearestPatternFormat",
                strongest.capitalized
            ),
            domain: .missingData
        )
    }

    private func makeFocusNext(
        records: [InsightsDayRecord],
        recoverySleepRecords: [InsightsDayRecord],
        coachContext: InsightsCoachContext?
    ) -> InsightsFocusNext {
        let recoveryRecords = recoverySleepRecords.filter { $0.recoveryScore > 0 }
        let sleepRecords = recoverySleepRecords.filter { $0.sleepMinutes > 0 }
        let nutritionRecords = records.filter { $0.mealCount > 0 }
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
                action: "Sleep at least 7 hours on 5 of the next 7 nights.",
                icon: "moon.zzz.fill",
                accent: WeekFitTheme.purple,
                domain: .sleep,
                actionTitle: "Open recovery",
                actionDestination: .detail(.recovery)
            )
        }

        if recoveryRecords.count >= 7, recoveryAverage > 0, recoveryAverage < 68 {
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Let recovery catch up",
                text: "Recovery is low enough that adding more training is unlikely to help right now.",
                action: "Keep every workout easy or Zone 2 for the next 7 days.",
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                domain: .recovery,
                actionTitle: "Open recovery",
                actionDestination: .detail(.recovery)
            )
        }

        if nutritionRecords.count < 7 {
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Make nutrition visible",
                text: "Meal logging is too inconsistent to connect food with recovery yet.",
                action: "Log every meal for the next 7 days.",
                icon: "fork.knife",
                accent: WeekFitTheme.meal,
                domain: .nutrition,
                actionTitle: "Open nutrition",
                actionDestination: .detail(.nutrition)
            )
        }

        if proteinGoal > 0, proteinTargetDays < 4 {
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Make protein more consistent",
                text: "Protein is inconsistent enough that recovery changes are harder to explain.",
                action: "Hit your protein target on at least 6 of the next 7 days.",
                icon: "takeoutbag.and.cup.and.straw.fill",
                accent: WeekFitTheme.meal,
                domain: .nutrition,
                actionTitle: "Open nutrition",
                actionDestination: .detail(.nutrition)
            )
        }

        let volume = trainingVolumeSummary(records)
        if !volume.hasMeaningfulLoad {
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Build a real training rhythm",
                text: "\(workloadSignificanceText(volume)) The next useful step is more total work, not intensity.",
                action: "Complete 3 hours of total activity over the next 7 days.",
                icon: "figure.run",
                accent: WeekFitTheme.orange,
                domain: .activity,
                actionTitle: "Open activity",
                actionDestination: .detail(.activity)
            )
        }

        if recoveryAverage >= 72 {
            return InsightsFocusNext(
                label: "FOCUS NEXT",
                title: "Current load looks sustainable",
                text: "Recovery is stable and your recent routine looks manageable.",
                action: "Do not increase training volume by more than 10% over the next 7 days.",
                icon: "checkmark.seal.fill",
                accent: WeekFitTheme.meal,
                domain: .consistency,
                actionTitle: "Open Coach",
                actionDestination: .tab(.coach)
            )
        }

        return InsightsFocusNext(
            label: "FOCUS NEXT",
            title: "Keep building the picture",
            text: "One more consistent week will make the next recommendation clearer.",
            action: "Log sleep, meals, drinks and activity every day for the next 7 days.",
            icon: "sparkles",
            accent: WeekFitTheme.orange,
            domain: .missingData,
            actionTitle: "Open Today",
            actionDestination: .tab(.today)
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

    private func sleepScoreTrendValues(_ records: [InsightsDayRecord]) -> [Double] {
        smoothedTrendValues(Array(records.suffix(30)).map { record in
            Double(record.sleepScore) / 100.0
        })
    }

    private func smoothedTrendValues(_ values: [Double], maxPoints: Int = 10) -> [Double] {
        let valid = values.filter { $0 > 0 }
        guard valid.count > 2 else { return values }

        let smoothed = valid.indices.map { index in
            let start = max(0, index - 1)
            let end = min(valid.count - 1, index + 1)
            return average(Array(valid[start...end]))
        }

        guard smoothed.count > maxPoints else { return smoothed }

        return (0..<maxPoints).map { point in
            let index = Int((Double(point) * Double(smoothed.count - 1) / Double(maxPoints - 1)).rounded())
            return smoothed[index]
        }
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
        WeekFitCountPluralization.noun(count: count, category: .day)
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

struct InsightsDayRecord {
    let date: Date
    let metrics: ActivityMetricsSnapshot
    let activities: [PlannedActivity]
    let syncedWorkouts: [InsightsSyncedWorkout]
    let todayNutrition: DailyNutritionMetrics?
    let nutritionGoals: NutritionGoals?

    var recoveryScore: Int { metrics.recoveryPercent }
    var sleepMinutes: Int { metrics.sleepMinutes }
    var sleepScore: Int { metrics.sleepScore }
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

    var hydrationGraphValue: Double {
        if waterGoal > 0 {
            return min(max(waterLiters / waterGoal, 0.12), 0.92)
        }

        return waterLiters > 0 ? min(max(waterLiters / 3.0, 0.12), 0.92) : 0.12
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
        QuickLogActivityPortions.totalWaterLiters(from: activities)
    }

    private var completedNutritionActivities: [PlannedActivity] {
        activities.filter { activity in
            activity.isCompleted &&
            !activity.isSkipped &&
            activity.imageName != "hydration" &&
            (activity.type.lowercased() == "meal" || activity.type.lowercased() == "drink" || activity.type.lowercased() == "snack")
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
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var coachInputProvider: CoachInputProvider
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]
    @StateObject private var viewModel: InsightsViewModel
    @StateObject private var userSettings = WeekFitUserSettings.shared
    @State private var showContent = false
    @State private var showProfile = false
    @State private var selectedDetail: InsightsDetailDestination?
    @State private var nutritionDetailsDate = Date()
    @State private var selectedStoryID: String?

    private let usesFixedSnapshot: Bool
    private let onSelectTab: (WeekFitTab) -> Void

    private let cardBackground = WeekFitTheme.cardBackground
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let elevatedCard = WeekFitTheme.elevatedCard

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText

    private let softShadow = WeekFitTheme.cardShadow

    private var snapshot: InsightsSnapshot {
        viewModel.snapshot
    }

    private var visibleStories: [InsightsStory] {
        if snapshot.stories.isEmpty {
            return [
                InsightsStory(
                    id: "snapshot.hero",
                    impactScore: 0,
                    trend: snapshot.hero,
                    driver: snapshot.supportCards.first ?? fallbackSupportCard(for: snapshot.hero.domain),
                    action: snapshot.focusNext,
                    evidence: snapshot.evidence
                )
            ]
        }

        return Array(snapshot.stories.prefix(2))
    }

    private var visibleDomainPages: [InsightsDomainPage] {
        snapshot.domainPages.isEmpty ? InsightsDomainPage.fallbackPages : snapshot.domainPages
    }

    private var selectedStory: InsightsStory {
        if let selectedStoryID,
           let story = visibleStories.first(where: { $0.id == selectedStoryID }) {
            return story
        }

        return visibleStories[0]
    }

    private var selectedDomainPage: InsightsDomainPage {
        if let selectedStoryID,
           let page = visibleDomainPages.first(where: { $0.id == selectedStoryID }) {
            return page
        }

        return visibleDomainPages[0]
    }

    private var shouldShowSnapshotContent: Bool {
        usesFixedSnapshot || viewModel.hasLoadedSnapshot
    }

    init(
        authViewModel: AuthViewModel,
        previewSnapshot: InsightsSnapshot? = nil,
        onSelectTab: @escaping (WeekFitTab) -> Void = { _ in }
    ) {
        self.authViewModel = authViewModel
        self.onSelectTab = onSelectTab
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
            nutritionViewModel.coachStateRefreshID.uuidString,
            coachCoordinator.state.id.uuidString,
            coachInputProvider.lastInput?.metricsSnapshotID?.uuidString ?? "noCoachInput",
            languageManager.selectedLanguage.rawValue
        ].joined(separator: "|")
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack(alignment: .top) {
            WeekFitTheme.appBackground
                .ignoresSafeArea()
            ambientBackground

            WeekFitScreenContainer {
                WeekFitScreenHeader(
                    title: InsightsLocalization.View.screenTitle,
                    subtitle: InsightsLocalization.View.screenSubtitle,
                    initials: userSettings.profileInitials,
                    showAvatar: true
                ) {
                    showProfile = true
                }
            }content: {
                if shouldShowSnapshotContent {
                    VStack(spacing: 8) {

                        storyPager
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 8)

                        pageIndicator
                    }
                    .padding(.bottom, 4)

                } else {
                    insightsLoadingState
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            showContent = true
            selectedStoryID = visibleDomainPages.first?.id
        }
        .onChange(of: snapshot.domainPages.map(\.id)) { _, pageIDs in
            guard let selectedStoryID,
                  pageIDs.contains(selectedStoryID) else {
                self.selectedStoryID = visibleDomainPages.first?.id
                return
            }
        }
        .task(id: refreshSignature) {
            guard !usesFixedSnapshot else { return }

            if coachInputProvider.lastInput == nil {
                await coachInputProvider.refresh(
                    selectedDate: Date(),
                    plannedActivities: plannedActivities,
                    healthManager: healthManager,
                    nutritionViewModel: nutritionViewModel,
                    coachCoordinator: coachCoordinator,
                    source: "InsightsView",
                    refreshHealth: false
                )
            }

            await viewModel.refresh(
                healthManager: healthManager,
                nutritionViewModel: nutritionViewModel,
                plannedActivities: plannedActivities,
                coachContext: currentCoachContext
            )
        }
        .weekFitSettingsSheet(isPresented: $showProfile)
        .fullScreenCover(item: $selectedDetail) { destination in
            detailView(for: destination)
        }
    }
    
    private var pageIndicator: some View {
        HStack(spacing: 7) {
            ForEach(Array(visibleDomainPages.enumerated()), id: \.element.id) { _, page in

                let isSelected = page.id == selectedStoryID

                Group {
                    if isSelected {
                        Capsule()
                            .fill(page.accent)
                            .frame(width: 18, height: 6)
                    } else {
                        Circle()
                            .fill(WeekFitTheme.whiteOpacity(0.14))
                            .frame(width: 6, height: 6)
                    }
                }
                .animation(.spring(duration: 0.25), value: selectedStoryID)
            }
        }
    }

    private var insightsLoadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(WeekFitTheme.meal)

            Text(WeekFitLocalizedString("insights.loading.readingPatterns"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(textSecondary.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
        .padding(.bottom, 95)
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

        case .recovery:
            RecoveryDetailsView(
                selectedDate: Date(),
                recoveryScore: healthManager.recoveryPercent,
                recoveryBreakdown: healthManager.recoveryBreakdown
            )
        }
    }

    private func perform(action destination: InsightsActionDestination?) {
        guard let destination else { return }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch destination {
        case .detail(let detail):
            if detail == .nutrition {
                nutritionDetailsDate = Date()
            }
            selectedDetail = detail
        case .tab(let tab):
            onSelectTab(tab)
        }
    }

    private var caloriesGoal: Double {
        nutritionViewModel.nutritionBudget.totalCalories > 0
            ? nutritionViewModel.nutritionBudget.totalCalories
            : 2761.0
    }
    private var proteinGoal: Double { nutritionViewModel.nutritionResult?.goals.protein ?? 153.0 }
    private var carbsGoal: Double { nutritionViewModel.nutritionResult?.goals.carbs ?? 330.0 }
    private var fatsGoal: Double { nutritionViewModel.nutritionResult?.goals.fats ?? 90.0 }
    private var fiberGoal: Double { nutritionViewModel.nutritionResult?.goals.fiber ?? 35.0 }
    private var waterGoal: Double { nutritionViewModel.nutritionResult?.goals.waterLiters ?? 4.46 }

    private var currentCoachContext: InsightsCoachContext? {
        makeCoachContext(
            state: coachCoordinator.state,
            input: coachInputProvider.lastInput
        )
    }

    private func makeCoachContext(
        state: CoachState,
        input: CoachInputSnapshot?
    ) -> InsightsCoachContext? {
        guard let v6 = state.coachUIPresentation else { return nil }

        let domain = insightsDomain(for: v6.scenario)
        let actionDestination: InsightsActionDestination = v6.urgencyLevel >= .protective
            ? .tab(.coach)
            : .detail(detailDestination(for: domain))
        let evidence = v6.supportingSignals.isEmpty
            ? [v6.assessment].filter { !$0.isEmpty }
            : v6.supportingSignals

        return InsightsCoachContext(
            title: v6.todayTitle,
            message: v6.todayMessage,
            stateLabel: v6.statusLabel,
            icon: v6.icon,
            accent: v6.accentColor,
            confidence: insightsConfidence(for: v6),
            evidence: evidence.isEmpty ? [v6.recommendation] : evidence,
            recommendation: v6.recommendation,
            actionTitle: actionTitle(for: actionDestination),
            domain: domain,
            actionDestination: actionDestination,
            shouldLeadInsights: shouldLeadInsights(v6: v6, input: input)
        )
    }

    private func insightsConfidence(for v6: CoachUIPresentation) -> Double {
        switch v6.alertSeverity {
        case .none:
            return 0.72
        case .elevated:
            return 0.84
        case .critical:
            return 0.92
        }
    }

    private func shouldLeadInsights(v6: CoachUIPresentation, input: CoachInputSnapshot?) -> Bool {
        if v6.urgencyLevel >= .protective { return true }
        if v6.alertSeverity == .critical { return true }
        switch v6.scenario {
        case .tomorrowProtection, .protectTomorrowFresh, .recoveryAfterHeavyYesterday:
            return true
        default:
            break
        }
        if input?.dayPriorityModel.tomorrowDemand == .hard { return true }
        return false
    }

    private func insightsDomain(for scenario: CoachScenarioKey) -> InsightsDomain {
        switch scenario {
        case .morningReadiness, .lowRecoveryPrep, .recoveryAfterHeavyYesterday:
            return .recovery
        case .tomorrowProtection, .protectTomorrowFresh:
            return .activity
        case .saunaPreparation, .saunaActive:
            return .hydration
        case .walkLightDay, .walkAfterHeavyLoad, .walkRecoveryAction, .walkEveningWindDown:
            return .recovery
        case .activeEndurance, .activeRacket, .activeStrength, .activeRecovery,
             .duringEndurance, .duringRacket, .duringStrength, .duringRecovery,
             .postEnduranceImmediate, .postRacketImmediate, .postStrengthImmediate, .postRecoveryImmediate,
             .postEnduranceSettled, .postRacketSettled, .postStrengthSettled, .postRecoverySettled,
             .eveningAfterEndurance, .eveningAfterRacket, .eveningAfterStrength, .eveningAfterRecovery:
            return .activity
        case .saunaRecovery:
            return .recovery
        case .stableDay:
            return .consistency
        }
    }

    private func detailDestination(for domain: InsightsDomain) -> InsightsDetailDestination {
        switch domain {
        case .activity:
            return .activity
        case .nutrition, .hydration:
            return .nutrition
        case .recovery, .sleep, .consistency, .missingData:
            return .recovery
        }
    }

    private func actionTitle(for destination: InsightsActionDestination) -> String {
        InsightsLocalization.View.actionTitle(for: destination)
    }

    private func nutritionMeals(for date: Date) -> [PlannedActivity] {
        plannedActivities
            .filter {
                Calendar.current.isDate($0.date, inSameDayAs: date)
                && ($0.type.lowercased() == "meal" || $0.type.lowercased() == "drink" || $0.type.lowercased() == "snack")
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
        let catalog = userSettings.customMealsCatalog
        return nutritionMeals(for: date).reduce(0.0) { total, activity in
            total + Double(PlannedActivityNutritionResolver.resolvedFiber(for: activity, in: catalog))
        }
    }

    private func nutritionWater(for date: Date) -> Double {
        if Calendar.current.isDateInToday(date),
           let waterLiters = nutritionViewModel.currentMetrics?.waterLiters {
            return waterLiters
        }

        let dayActivities = plannedActivities.filter {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }
        return QuickLogActivityPortions.totalWaterLiters(from: dayActivities)
    }
}

// MARK: - Strategic Story

private enum StoryCardProminence {
    case primary
    case secondary
    case tertiary

    var contentSpacing: CGFloat {
        switch self {
        case .primary:
            return 10
        case .secondary:
            return 7
        case .tertiary:
            return 7
        }
    }

    var padding: CGFloat {
        switch self {
        case .primary:
            return 14
        case .secondary:
            return 11
        case .tertiary:
            return 11
        }
    }

    var labelSize: CGFloat {
        switch self {
        case .primary:
            return 10.8
        case .secondary, .tertiary:
            return 10.2
        }
    }

    var labelIconSize: CGFloat {
        switch self {
        case .primary:
            return 12.5
        case .secondary, .tertiary:
            return 11.5
        }
    }

    var accentOpacity: Double {
        switch self {
        case .primary:
            return 0.070
        case .secondary:
            return 0.040
        case .tertiary:
            return 0.030
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .primary:
            return 0.50
        case .secondary:
            return 0.26
        case .tertiary:
            return 0.18
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .primary:
            return 14
        case .secondary:
            return 9
        case .tertiary:
            return 7
        }
    }

    var shadowY: CGFloat {
        switch self {
        case .primary:
            return 7
        case .secondary:
            return 4
        case .tertiary:
            return 3
        }
    }
}

private extension InsightsView {

    var storyPager: some View {
        TabView(selection: $selectedStoryID) {
            ForEach(visibleDomainPages) { page in
                domainPageView(page)
                    .tag(Optional(page.id))
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 560)
    }

    func domainPageView(_ page: InsightsDomainPage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(page.label)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.42)
                        .foregroundStyle(page.accent.opacity(0.88))

                    Text(page.headline)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text(page.standoutText)
                        .font(.system(size: 13.2, weight: .semibold))
                        .foregroundStyle(textSecondary.opacity(0.80))
                        .lineLimit(2)
                }

                Spacer(minLength: 16)

                Text(page.scoreValue)
                    .font(.system(size: 54, weight: .heavy))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                    .monospacedDigit()
            }

            domainChart(page)
                .frame(height: 176)

            whyThisScoreSection(page)

            monthlyReviewTextSection(
                title: InsightsLocalization.Section.nextFocus,
                text: page.focusText,
                accent: page.accent,
                isFocus: true
            )
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            page.accent.opacity(0.16),
                            WeekFitTheme.whiteOpacity(0.052),
                            WeekFitTheme.whiteOpacity(0.030)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                }
        }
    }

    func domainChart(_ page: InsightsDomainPage) -> some View {
        let zones = chartZones(for: page.domain)

        return PremiumInsightAreaChart(
            values: page.chartValues,
            target: zones.middleBoundary,
            targetLabel: zones.middle,
            accent: page.accent,
            upperZoneLabel: zones.upper,
            middleZoneLabel: zones.middle,
            lowerZoneLabel: zones.lower,
            upperBoundary: zones.upperBoundary,
            middleBoundary: zones.middleBoundary
        )
    }

    func chartZones(for domain: InsightsDomain) -> (upper: String, middle: String, lower: String, upperBoundary: Double, middleBoundary: Double) {
        InsightsLocalization.View.chartZones(for: domain)
    }

    func whyThisScoreSection(_ page: InsightsDomainPage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(InsightsLocalization.Section.whyThisScore)
                .font(.system(size: 10.2, weight: .bold))
                .tracking(0.36)
                .foregroundStyle(textSecondary.opacity(0.62))

            VStack(spacing: 7) {
                ForEach(page.keySignals.prefix(3)) { signal in
                    scoreDriverCard(signal, accent: page.accent)
                }
            }
        }
    }

    func scoreDriverCard(_ signal: InsightsKeySignal, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(signal.label)
                .font(.system(size: 12.2, weight: .bold))
                .foregroundStyle(textPrimary.opacity(0.94))
                .lineLimit(1)

            Text(signal.value)
                .font(.system(size: 11.6, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.74))
                .lineLimit(2)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(accent.opacity(0.095))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(accent.opacity(0.16), lineWidth: 1)
            }
        }
    }

    func monthlyReviewTextSection(title: String, text: String, accent: Color, isFocus: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10.2, weight: .bold))
                .tracking(0.36)
                .foregroundStyle(isFocus ? accent.opacity(0.82) : textSecondary.opacity(0.62))

            Text(text)
                .font(.system(size: isFocus ? 14.5 : 13.2, weight: isFocus ? .bold : .semibold))
                .foregroundStyle(textPrimary.opacity(isFocus ? 0.96 : 0.76))
                .lineLimit(2)
        }
    }

    func domainLineVisualization(values rawValues: [Double], target: Double?, accent: Color) -> some View {
        GeometryReader { geo in
            ZStack {
                let scale = graphScale(primary: rawValues, secondary: nil)

                if let target {
                    Path { path in
                        let y = geo.size.height * CGFloat(1 - scaledGraphValue(target, scale: scale))
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(textSecondary.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }

                let values = scaledGraphValues(rawValues, scale: scale)
                linePath(values: values, geo: geo)
                    .stroke(accent.opacity(0.86), style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round))
            }
        }
    }

    func trendSection(_ story: InsightsStory) -> some View {
        storyCard(label: InsightsLocalization.Section.trend, icon: story.trend.icon, accent: story.trend.accent, prominence: .primary) {
            VStack(alignment: .leading, spacing: 14) {
                Text(trendTitle(for: story))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                heroScoreExplanation(for: story)

                Text(trendDeltaText(for: story))
                    .font(.system(size: 10.6, weight: .bold))
                    .foregroundStyle(story.trend.accent.opacity(0.84))

                heroVisualization(for: story.trend)
                    .frame(height: 48)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            perform(action: story.trend.actionDestination)
        }
    }

    func heroScoreExplanation(for story: InsightsStory) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(heroMetricName(for: story.trend))
                    .font(.system(size: 10.4, weight: .bold))
                    .foregroundStyle(textSecondary.opacity(0.72))

                Spacer(minLength: 8)

                Text(heroMetricValue(for: story.trend))
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(textPrimary.opacity(0.96))
                    .multilineTextAlignment(.trailing)
            }

            Text(heroTargetExplanation(for: story.trend))
                .font(.system(size: 10.8, weight: .bold))
                .foregroundStyle(story.trend.accent.opacity(0.88))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(WeekFitTheme.whiteOpacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func driverSection(_ story: InsightsStory) -> some View {
        let driver = story.driver
        let metric = driver.metrics.first

        return storyCard(label: InsightsLocalization.Section.driver, icon: driver.icon, accent: driver.accent, prominence: .secondary) {
            VStack(alignment: .leading, spacing: 5) {
                Text(driverName(for: driver))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text(driverValue(for: driver))
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(textPrimary.opacity(0.94))
                    .lineLimit(1)

                Text(driverTargetText(metric: metric, domain: driver.domain))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(driver.accent.opacity(0.84))
                    .lineLimit(1)

                Text(compactDriverStatement(for: story))
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.80))
                    .lineLimit(2)

                Text(confidenceText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(textSecondary.opacity(0.58))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            perform(action: supportActionDestination(for: driver))
        }
    }

    func actionSection(_ story: InsightsStory) -> some View {
        let focus = story.action

        return Button {
            perform(action: focus.actionDestination)
        } label: {
            storyCard(label: InsightsLocalization.Section.action, icon: focus.icon, accent: focus.accent, prominence: .tertiary) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(focus.title)
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)

                    VStack(alignment: .leading, spacing: 5) {
                        actionLine(label: InsightsLocalization.Section.goal, text: focus.action, accent: focus.accent)
                        actionLine(label: InsightsLocalization.Section.expectedOutcome, text: expectedOutcomeText(for: story), accent: focus.accent)
                    }

                    HStack(spacing: 8) {
                        Text(refinedActionTitle(for: focus.actionDestination, fallback: focus.actionTitle))
                            .font(.system(size: 10.8, weight: .bold))
                            .foregroundStyle(focus.accent.opacity(0.92))
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(textPrimary.opacity(0.86))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(focus.accent.opacity(0.075))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(focus.actionDestination == nil)
    }

    func storyCard<Content: View>(
        label: String,
        icon: String,
        accent: Color,
        prominence: StoryCardProminence,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: prominence.contentSpacing) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: prominence.labelIconSize, weight: .bold))

                Text(label)
                    .font(.system(size: prominence.labelSize, weight: .bold))
                    .tracking(0.42)

                Spacer()
            }
            .foregroundStyle(accent.opacity(0.86))

            content()
        }
        .padding(prominence.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    accent.opacity(prominence.accentOpacity),
                    cardBackground.opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.055), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(prominence.shadowOpacity), radius: prominence.shadowRadius, y: prominence.shadowY)
    }

    func actionLine(label: String, text: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label):")
                .font(.system(size: 9.8, weight: .bold))
                .foregroundStyle(accent.opacity(0.78))

            Text(text)
                .font(.system(size: 12.8, weight: .bold))
                .foregroundStyle(textPrimary.opacity(0.94))
                .lineLimit(2)
                .minimumScaleFactor(0.88)
        }
    }

    var primaryDriver: InsightSupportCard {
        snapshot.supportCards.first ?? fallbackSupportCard(for: snapshot.hero.domain)
    }

    func trendTitle(for story: InsightsStory) -> String {
        story.trend.title
    }

    func heroMetricName(for hero: InsightsHeroInsight) -> String {
        switch hero.domain {
        case .recovery:
            return InsightsLocalization.View.recoveryScore
        case .sleep:
            return hero.badgeValue.localizedCaseInsensitiveContains("h")
                ? InsightsLocalization.View.sleepDuration
                : InsightsLocalization.View.sleepScore
        case .activity:
            return InsightsLocalization.View.trainingLoad
        case .nutrition:
            return InsightsLocalization.View.nutritionSignal
        case .hydration:
            return InsightsLocalization.View.hydrationSignal
        case .consistency:
            return InsightsLocalization.View.consistency
        case .missingData:
            return InsightsLocalization.View.patternReadiness
        }
    }

    func heroMetricValue(for hero: InsightsHeroInsight) -> String {
        if hero.domain == .sleep, hero.badgeValue.localizedCaseInsensitiveContains("h") {
            return InsightsLocalization.format("insights.view.hero.averageSuffix", hero.badgeValue)
        }

        guard (hero.domain == .recovery || hero.domain == .sleep),
              let score = numericHeroValue(for: hero),
              score <= 100 else {
            return hero.badgeValue
        }

        return InsightsLocalization.format("insights.view.hero.scoreOutOf100Format", Int(score.rounded()))
    }

    func heroTargetExplanation(for hero: InsightsHeroInsight) -> String {
        if hero.domain == .sleep, hero.badgeValue.localizedCaseInsensitiveContains("h") {
            let sleepHours = numericHeroValue(for: hero) ?? 0
            let targetHours = 7.0
            let gap = sleepHours - targetHours
            let gapText = gap >= 0 ? "+\(String(format: "%.1f", gap))h" : "\(String(format: "%.1f", gap))h"
            return InsightsLocalization.format("insights.view.hero.sleepTargetGapFormat", gapText)
        }

        guard (hero.domain == .recovery || hero.domain == .sleep),
              let score = numericHeroValue(for: hero),
              let target = hero.targetValue,
              score <= 100 else {
            return hero.badgeLabel == "patterns" ? InsightsLocalization.View.notEnoughDataYet : hero.badgeLabel
        }

        let targetScore = Int((target * 100).rounded())
        let delta = Int((score - Double(targetScore)).rounded())
        if delta >= 0 {
            return InsightsLocalization.format("insights.view.hero.aboveTargetFormat", delta)
        }

        return InsightsLocalization.format("insights.view.hero.belowTargetFormat", delta)
    }

    func numericHeroValue(for hero: InsightsHeroInsight) -> Double? {
        let filtered = hero.badgeValue.filter { character in
            character.isNumber || character == "." || character == "-"
        }

        return Double(filtered)
    }

    func trendDeltaText(for story: InsightsStory) -> String {
        if story.trend.domain == .consistency,
           story.trend.title.localizedCaseInsensitiveContains("no major") {
            return InsightsLocalization.View.trendNoChange
        }

        guard trendValues(for: story.trend).count >= 2 else {
            return InsightsLocalization.View.trendBuildsWithData
        }

        switch validatedTrendDirection(for: story) {
        case .increasing:
            return InsightsLocalization.View.trendImproving
        case .decreasing:
            return InsightsLocalization.View.trendDeclining
        case .stable:
            return InsightsLocalization.View.trendStable
        }
    }

    func validatedTrendDirection(for story: InsightsStory) -> InsightTrendDirection {
        let values = trendValues(for: story.trend)
        guard let first = values.first, let last = values.last, values.count >= 2 else {
            return .stable
        }

        let delta = (last - first) * 100
        if delta >= 3 {
            return .increasing
        }
        if delta <= -3 {
            return .decreasing
        }
        return .stable
    }

    func trendValues(for hero: InsightsHeroInsight) -> [Double] {
        switch hero.visualization {
        case .trendLine(let values, _, _):
            return values
        case .correlation(let primary, _, _, _), .relationshipGraph(let primary, _, _):
            return primary
        case .weeklyPattern(let values, _), .distribution(let values, _):
            return values
        case .trendChange(_, let after, _):
            return after
        case .signalStrength(let strength, _):
            return [strength]
        case .comparison, .consistency, .contributionBreakdown:
            return hero.graphValues
        }
    }

    var confidenceText: String {
        InsightsLocalization.Confidence.withPercent(value: snapshot.evidence.confidenceValue)
    }

    var confidenceLevelText: String {
        InsightsLocalization.Confidence.label(for: snapshot.evidence.confidenceValue)
    }

    var driverName: String {
        driverName(for: primaryDriver)
    }

    func driverName(for driver: InsightSupportCard) -> String {
        switch driver.domain {
        case .sleep:
            return InsightsLocalization.View.driverSleepDuration
        case .activity:
            return InsightsLocalization.View.driverTrainingLoad
        case .nutrition:
            return InsightsLocalization.View.driverProteinConsistency
        case .recovery:
            return InsightsLocalization.View.driverRecoveryConsistency
        case .hydration:
            return InsightsLocalization.View.driverHydration
        case .consistency, .missingData:
            return InsightsLocalization.View.driverLoggingConsistency
        }
    }

    var driverValue: String {
        driverValue(for: primaryDriver)
    }

    func driverValue(for driver: InsightSupportCard) -> String {
        guard let metric = driver.metrics.first else {
            return compactValue(for: driver.domain)
        }

        switch driver.domain {
        case .sleep:
            return metric.value.contains("h")
                ? InsightsLocalization.format("insights.view.hero.averageSuffix", metric.value)
                : metric.value
        case .activity, .nutrition, .recovery, .hydration, .consistency, .missingData:
            return metric.value
        }
    }

    var driverExplanation: String {
        driverExplanation(for: selectedStory)
    }

    func compactDriverStatement(for story: InsightsStory) -> String {
        story.driver.text
    }

    func driverExplanation(for story: InsightsStory) -> String {
        switch story.driver.domain {
        case .sleep:
            return validatedTrendDirection(for: story) == .decreasing
                ? InsightsLocalization.View.driverExplanationSleepDecline
                : InsightsLocalization.View.driverExplanationSleepSupport
        case .activity:
            return validatedTrendDirection(for: story) == .decreasing
                ? InsightsLocalization.View.driverExplanationActivityDecline
                : InsightsLocalization.View.driverExplanationActivitySupport
        case .nutrition:
            return InsightsLocalization.View.driverExplanationNutrition
        case .recovery:
            return InsightsLocalization.View.driverExplanationRecovery
        case .hydration:
            return InsightsLocalization.View.driverExplanationHydration
        case .consistency, .missingData:
            return InsightsLocalization.View.driverExplanationMissingData
        }
    }

    func driverTargetText(metric: InsightTrendMetric?, domain: InsightsDomain) -> String {
        switch domain {
        case .sleep:
            return InsightsLocalization.View.targetSleep7h
        case .nutrition:
            return InsightsLocalization.View.targetProtein6of7
        case .activity:
            return InsightsLocalization.View.targetStableWeeklyLoad
        case .recovery:
            return InsightsLocalization.View.targetRecovery72
        case .hydration:
            return InsightsLocalization.View.targetConsistentIntake
        case .consistency, .missingData:
            return metric?.benchmark ?? InsightsLocalization.View.targetCompleteLogs
        }
    }

    func expectedOutcomeText(for story: InsightsStory) -> String {
        guard !story.action.text.isEmpty else {
            return InsightsLocalization.View.expectedOutcomeFallback
        }

        return story.action.text
    }

    func refinedActionTitle(for destination: InsightsActionDestination?, fallback: String) -> String {
        InsightsLocalization.View.refinedActionTitle(for: destination, fallback: fallback)
    }

    func compactValue(for domain: InsightsDomain) -> String {
        switch domain {
        case .recovery:
            return snapshot.weeklyScores.first { $0.title == InsightsLocalization.Section.recovery }?.value ?? InsightsLocalization.Section.building
        case .sleep:
            return snapshot.weeklyScores.first { $0.title == InsightsLocalization.Section.sleep }?.value ?? InsightsLocalization.Section.building
        case .activity:
            return snapshot.weeklyScores.first { $0.title == InsightsLocalization.Section.training }?.value ?? InsightsLocalization.Section.building
        case .nutrition:
            return snapshot.weeklyScores.first { $0.title == InsightsLocalization.Section.nutrition }?.value ?? InsightsLocalization.Section.building
        case .hydration:
            return snapshot.hydrationImpact.rows.first?.values.last ?? InsightsLocalization.Section.building
        case .consistency, .missingData:
            return InsightsLocalization.Section.building
        }
    }
}

// MARK: - Hero

private extension InsightsView {

    var heroInsightCard: some View {
        ZStack(alignment: .topLeading) {
            cardBackground.opacity(0.98)

            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: snapshot.hero.icon)
                        .font(.system(size: 12, weight: .bold))

                    Text(snapshot.hero.label)
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.35)

                    Spacer()
                }
                .foregroundStyle(snapshot.hero.accent.opacity(0.86))

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(snapshot.hero.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(textPrimary)

                        Text(snapshot.hero.subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textSecondary.opacity(0.82))
                            .lineSpacing(2)
                    }

                    Spacer(minLength: 4)

                    heroMetricBadge
                }

                heroGraph

                if snapshot.hero.actionDestination != nil {
                    HStack(spacing: 7) {
                        Text(snapshot.hero.takeaway)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(snapshot.hero.accent.opacity(0.92))
                            .lineLimit(2)

                        Spacer(minLength: 6)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(textPrimary.opacity(0.86))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .background(snapshot.hero.accent.opacity(0.075))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
        .frame(minHeight: 218)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.055), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.45), radius: 12, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            perform(action: snapshot.hero.actionDestination)
        }
    }

    var heroGraph: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(heroGraphLabel)
                    .font(.system(size: 9.4, weight: .bold))
                    .tracking(0.25)
                    .foregroundStyle(textSecondary.opacity(0.72))

                Spacer(minLength: 0)

                if let targetLabel = visualizationCaption {
                    Text(targetLabel)
                        .font(.system(size: 9.4, weight: .bold))
                        .foregroundStyle(textSecondary.opacity(0.62))
                }
            }

            heroVisualization
                .frame(height: 58)

            if shouldShowWeekLabels {
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
    }

    @ViewBuilder
    var heroVisualization: some View {
        switch snapshot.hero.visualization {
        case .trendLine(let values, let target, _):
            lineVisualization(values: values, target: target, secondary: nil)
        case .comparison(let primaryLabel, let primaryValue, let secondaryLabel, let secondaryValue, let delta):
            comparisonVisualization(
                primaryLabel: primaryLabel,
                primaryValue: primaryValue,
                secondaryLabel: secondaryLabel,
                secondaryValue: secondaryValue,
                delta: delta
            )
        case .distribution(let values, let highlightIndex):
            distributionVisualization(values: values, highlightIndex: highlightIndex)
        case .correlation(let primary, let secondary, _, _):
            lineVisualization(values: primary, target: nil, secondary: secondary)
        case .consistency(let values, let positiveLabel, let negativeLabel):
            consistencyVisualization(values: values, positiveLabel: positiveLabel, negativeLabel: negativeLabel)
        case .weeklyPattern(let values, let labels):
            weeklyPatternVisualization(values: values, labels: labels)
        case .contributionBreakdown(let segments):
            contributionVisualization(segments: segments)
        case .relationshipGraph(let primary, let secondary, _):
            lineVisualization(values: primary, target: nil, secondary: secondary)
        case .trendChange(let before, let after, _):
            trendChangeVisualization(before: before, after: after)
        case .signalStrength(let strength, let label):
            signalStrengthVisualization(strength: strength, label: label)
        }
    }

    @ViewBuilder
    func heroVisualization(for hero: InsightsHeroInsight) -> some View {
        switch hero.visualization {
        case .trendLine(let values, let target, _):
            lineVisualization(values: values, target: target, secondary: nil)
        case .comparison(let primaryLabel, let primaryValue, let secondaryLabel, let secondaryValue, let delta):
            comparisonVisualization(
                primaryLabel: primaryLabel,
                primaryValue: primaryValue,
                secondaryLabel: secondaryLabel,
                secondaryValue: secondaryValue,
                delta: delta
            )
        case .distribution(let values, let highlightIndex):
            distributionVisualization(values: values, highlightIndex: highlightIndex)
        case .correlation(let primary, let secondary, _, _):
            lineVisualization(values: primary, target: nil, secondary: secondary)
        case .consistency(let values, let positiveLabel, let negativeLabel):
            consistencyVisualization(values: values, positiveLabel: positiveLabel, negativeLabel: negativeLabel)
        case .weeklyPattern(let values, let labels):
            weeklyPatternVisualization(values: values, labels: labels)
        case .contributionBreakdown(let segments):
            contributionVisualization(segments: segments)
        case .relationshipGraph(let primary, let secondary, _):
            lineVisualization(values: primary, target: nil, secondary: secondary)
        case .trendChange(let before, let after, _):
            trendChangeVisualization(before: before, after: after)
        case .signalStrength(let strength, let label):
            signalStrengthVisualization(strength: strength, label: label)
        }
    }

    var visualizationCaption: String? {
        switch snapshot.hero.visualization {
        case .trendLine(_, _, let targetLabel):
            return targetLabel
        case .comparison(_, _, _, _, let delta):
            return delta
        case .distribution:
            return InsightsLocalization.View.graphCaptionDistribution
        case .correlation(_, _, let primaryLabel, let secondaryLabel):
            return InsightsLocalization.format(
                "insights.view.graphCaption.correlationFormat",
                primaryLabel,
                secondaryLabel
            )
        case .consistency(_, let positiveLabel, let negativeLabel):
            return InsightsLocalization.format(
                "insights.view.graphCaption.consistencyFormat",
                positiveLabel,
                negativeLabel
            )
        case .weeklyPattern:
            return InsightsLocalization.View.graphCaptionWeeklyPattern
        case .contributionBreakdown:
            return InsightsLocalization.View.graphCaptionContributors
        case .relationshipGraph(_, _, let insightLabel):
            return insightLabel
        case .trendChange(_, _, let label):
            return label
        case .signalStrength(_, let label):
            return label
        }
    }

    var shouldShowWeekLabels: Bool {
        return false
    }

    var heroGraphLabel: String {
        switch snapshot.hero.visualization {
        case .trendLine:
            break
        case .comparison:
            return InsightsLocalization.View.graphComparison
        case .distribution:
            return InsightsLocalization.View.graphDistribution
        case .correlation:
            return InsightsLocalization.View.graphPairedSignals
        case .consistency:
            return InsightsLocalization.View.graphConsistency
        case .weeklyPattern:
            return InsightsLocalization.View.graphWeeklyPattern
        case .contributionBreakdown:
            return InsightsLocalization.View.graphSignalStrength
        case .relationshipGraph:
            return InsightsLocalization.View.graphPairedSignals
        case .trendChange:
            return InsightsLocalization.View.graphTrendChange
        case .signalStrength:
            return InsightsLocalization.View.graphSignalStrength
        }

        switch snapshot.hero.domain {
        case .sleep:
            return InsightsLocalization.View.graphMonthlySleep
        case .recovery:
            return InsightsLocalization.View.graphMonthlyRecovery
        case .activity:
            return InsightsLocalization.View.graphMonthlyTraining
        case .nutrition:
            return InsightsLocalization.View.graphMonthlyNutrition
        case .hydration:
            return InsightsLocalization.View.graphMonthlyHydration
        case .consistency, .missingData:
            return InsightsLocalization.View.graphPatternBuilding
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

            Text(snapshot.hero.timeframe)
                .font(.system(size: 8.8, weight: .bold))
                .foregroundStyle(textSecondary.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(width: 118, alignment: .trailing)
        .frame(minHeight: 58, alignment: .trailing)
        .background(WeekFitTheme.whiteOpacity(0.050))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    func lineVisualization(
        values rawValues: [Double],
        target: Double?,
        secondary secondaryValues: [Double]?
    ) -> some View {
        GeometryReader { geo in
            ZStack {
                let scale = graphScale(primary: rawValues, secondary: secondaryValues)

                if let target {
                    Path { path in
                        let y = geo.size.height * CGFloat(1 - scaledGraphValue(target, scale: scale))
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(
                        textSecondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
                }

                if let secondaryValues {
                    linePath(values: scaledGraphValues(secondaryValues, scale: scale), geo: geo)
                        .stroke(
                            textSecondary.opacity(0.34),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                }

                let values = scaledGraphValues(rawValues, scale: scale)
                linePath(values: values, geo: geo)
                    .stroke(
                        snapshot.hero.accent.opacity(0.76),
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                    )

                ForEach(values.indices, id: \.self) { index in
                    heroDot(index: index, values: values, geo: geo)
                }
            }
        }
    }

    func linePath(values: [Double], geo: GeometryProxy) -> Path {
        Path { path in
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
        values.map { min(max($0, 0.08), 0.92) }
    }

    func graphScale(primary: [Double], secondary: [Double]?) -> ClosedRange<Double> {
        let values = primary + (secondary ?? [])
        let clamped = values.map { min(max($0, 0), 1) }
        guard let minValue = clamped.min(), let maxValue = clamped.max() else {
            return 0...1
        }

        let minimumSpan = 0.18
        let observedSpan = max(maxValue - minValue, minimumSpan)
        let midpoint = (minValue + maxValue) / 2.0
        let paddedSpan = min(max(observedSpan * 1.35, minimumSpan), 1.0)
        let lower = max(0, midpoint - paddedSpan / 2.0)
        let upper = min(1, midpoint + paddedSpan / 2.0)

        if upper - lower < minimumSpan {
            return max(0, upper - minimumSpan)...upper
        }

        return lower...upper
    }

    func scaledGraphValues(_ values: [Double], scale: ClosedRange<Double>) -> [Double] {
        values.map { scaledGraphValue($0, scale: scale) }
    }

    func scaledGraphValue(_ value: Double, scale: ClosedRange<Double>) -> Double {
        let span = max(scale.upperBound - scale.lowerBound, 0.01)
        let scaled = (min(max(value, 0), 1) - scale.lowerBound) / span
        return min(max(scaled, 0.08), 0.92)
    }

    func comparisonVisualization(
        primaryLabel: String,
        primaryValue: String,
        secondaryLabel: String,
        secondaryValue: String,
        delta: String
    ) -> some View {
        HStack(spacing: 10) {
            comparisonBlock(label: primaryLabel, value: primaryValue, accent: snapshot.hero.accent)
            comparisonBlock(label: secondaryLabel, value: secondaryValue, accent: textSecondary)
            Text(delta)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(snapshot.hero.accent.opacity(0.92))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(snapshot.hero.accent.opacity(0.10))
                .clipShape(Capsule(style: .continuous))
        }
    }

    func comparisonBlock(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(textSecondary.opacity(0.70))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(WeekFitTheme.whiteOpacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    func distributionVisualization(values rawValues: [Double], highlightIndex: Int?) -> some View {
        let values = normalizedGraphValues(rawValues)
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(values.indices, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index == highlightIndex ? snapshot.hero.accent.opacity(0.82) : textSecondary.opacity(0.28))
                    .frame(maxWidth: .infinity)
                    .frame(height: 12 + 42 * CGFloat(values[index]))
            }
        }
    }

    func consistencyVisualization(values: [Bool], positiveLabel: String, negativeLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(values.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(values[index] ? snapshot.hero.accent.opacity(0.78) : textSecondary.opacity(0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .overlay {
                            Image(systemName: values[index] ? "checkmark" : "minus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(textPrimary.opacity(values[index] ? 0.88 : 0.34))
                        }
                }
            }

            Text("\(values.filter { $0 }.count) \(positiveLabel.lowercased()) • \(values.filter { !$0 }.count) \(negativeLabel.lowercased())")
                .font(.system(size: 10.4, weight: .bold))
                .foregroundStyle(textSecondary.opacity(0.68))
        }
    }

    func weeklyPatternVisualization(values rawValues: [Double], labels: [String]) -> some View {
        let values = normalizedGraphValues(rawValues)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(values.indices, id: \.self) { index in
                VStack(spacing: 5) {
                    Capsule(style: .continuous)
                        .fill(snapshot.hero.accent.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: 12 + 38 * CGFloat(values[index]))
                    Text(index < labels.count ? labels[index] : "")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(textSecondary.opacity(0.68))
                }
            }
        }
    }

    func contributionVisualization(segments: [InsightContribution]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(segments) { segment in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(segment.color.opacity(0.78))
                            .frame(width: max(6, geo.size.width * CGFloat(min(max(segment.value, 0), 1))))
                    }
                }
            }
            .frame(height: 18)

            HStack(spacing: 10) {
                ForEach(segments.prefix(3)) { segment in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(segment.color.opacity(0.82))
                            .frame(width: 6, height: 6)
                        Text(segment.label)
                            .font(.system(size: 9.8, weight: .bold))
                            .foregroundStyle(textSecondary.opacity(0.72))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    func trendChangeVisualization(before: [Double], after: [Double]) -> some View {
        HStack(spacing: 10) {
            lineVisualization(values: before, target: nil, secondary: nil)
                .opacity(0.58)

            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(textSecondary.opacity(0.54))

            lineVisualization(values: after, target: nil, secondary: nil)
        }
    }

    func signalStrengthVisualization(strength: Double, label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(textSecondary.opacity(0.14))

                    Capsule(style: .continuous)
                        .fill(snapshot.hero.accent.opacity(0.82))
                        .frame(width: geo.size.width * CGFloat(min(max(strength, 0), 1)))
                }
            }
            .frame(height: 14)

            Text(label)
                .font(.system(size: 10.4, weight: .bold))
                .foregroundStyle(textSecondary.opacity(0.70))
                .lineLimit(1)
        }
    }

}

// MARK: - Evidence

private extension InsightsView {

    var whyWeBelieveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(WeekFitLocalizedString("Why this matters"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textPrimary)

            VStack(spacing: 8) {
                ForEach(Array(snapshot.evidence.bullets.prefix(3).enumerated()), id: \.offset) { _, evidence in
                    evidenceRow(evidence, accent: snapshot.hero.accent)
                }
            }
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardBackground.opacity(0.92))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
        }
    }

    func evidenceRow(_ text: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(accent.opacity(0.72))
                .frame(width: 5, height: 5)
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 11.7, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.84))
                .lineSpacing(1.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(WeekFitTheme.whiteOpacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Weekly Scores

private extension InsightsView {

    var narrativeSupportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(supportSectionTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textPrimary)

            VStack(spacing: 8) {
                ForEach(visibleSupportCards) { card in
                    supportCardRow(card)
                }
            }
        }
    }

    var supportSectionTitle: String {
        InsightsLocalization.text("insights.view.supportSectionTitle")
    }

    var visibleSupportCards: [InsightSupportCard] {
        let filtered = snapshot.supportCards.filter { card in
            guard card.role != .experiment, card.domain != .consistency else {
                return false
            }

            return card.domain != snapshot.hero.domain &&
                supportDomains(for: snapshot.hero.domain).contains(card.domain)
        }

        let sorted = filtered.sorted { lhs, rhs in
            let lhsRank = supportDomainRank(lhs.domain, for: snapshot.hero.domain)
            let rhsRank = supportDomainRank(rhs.domain, for: snapshot.hero.domain)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return false
        }

        var seen: Set<InsightsDomain> = []
        let distinct = sorted.filter { card in
            guard !seen.contains(card.domain) else { return false }
            seen.insert(card.domain)
            return true
        }

        let visible = Array(distinct.prefix(2))
        return visible.isEmpty ? [fallbackSupportCard(for: snapshot.hero.domain)] : visible
    }

    func fallbackSupportCard(for domain: InsightsDomain) -> InsightSupportCard {
        switch domain {
        case .sleep:
            return InsightSupportCard(
                role: .relationship,
                domain: .recovery,
                title: InsightsLocalization.text("insights.view.fallbackSupport.recoveryResponse.title"),
                text: InsightsLocalization.text("insights.view.fallbackSupport.recoveryResponse.sleep.text"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                metrics: [InsightTrendMetric(label: "Watch", value: "recovery", direction: .stable, detail: "next mornings", benchmark: "after longer sleep")]
            )
        case .activity:
            return InsightSupportCard(
                role: .adaptation,
                domain: .recovery,
                title: InsightsLocalization.text("insights.view.fallbackSupport.recoveryResponse.title"),
                text: InsightsLocalization.text("insights.view.fallbackSupport.recoveryResponse.activity.text"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                metrics: [InsightTrendMetric(label: "Watch", value: "readiness", direction: .stable, detail: "after hard days", benchmark: "before adding load")]
            )
        case .nutrition:
            return InsightSupportCard(
                role: .recoveryDriver,
                domain: .recovery,
                title: InsightsLocalization.text("insights.view.fallbackSupport.recoveryResponse.title"),
                text: InsightsLocalization.text("insights.view.fallbackSupport.recoveryResponse.nutrition.text"),
                icon: "heart.fill",
                accent: WeekFitTheme.meal,
                metrics: [InsightTrendMetric(label: "Watch", value: "adaptation", direction: .stable, detail: "after workout meals", benchmark: "over the next week")]
            )
        case .hydration:
            return InsightSupportCard(
                role: .workload,
                domain: .activity,
                title: InsightsLocalization.text("insights.view.fallbackSupport.trainingContext.title"),
                text: InsightsLocalization.text("insights.view.fallbackSupport.trainingContext.hydration.text"),
                icon: "figure.run",
                accent: WeekFitTheme.orange,
                metrics: [InsightTrendMetric(label: "Watch", value: "hard days", direction: .stable, detail: "fluid timing", benchmark: "compare recovery")]
            )
        case .recovery:
            return InsightSupportCard(
                role: .workload,
                domain: .activity,
                title: InsightsLocalization.text("insights.view.fallbackSupport.trainingContext.title"),
                text: InsightsLocalization.text("insights.view.fallbackSupport.trainingContext.recovery.text"),
                icon: "figure.run",
                accent: WeekFitTheme.orange,
                metrics: [InsightTrendMetric(label: "Watch", value: "load", direction: .stable, detail: "next week", benchmark: "keep it repeatable")]
            )
        case .consistency, .missingData:
            return InsightSupportCard(
                role: .opportunity,
                domain: .consistency,
                title: InsightsLocalization.text("insights.view.fallbackSupport.patternToBuild.title"),
                text: InsightsLocalization.text("insights.view.fallbackSupport.patternToBuild.text"),
                icon: "sparkles",
                accent: snapshot.hero.accent,
                metrics: [InsightTrendMetric(label: "Watch", value: "consistency", direction: .stable, detail: "7 days", benchmark: "sleep, recovery, training, meals")]
            )
        }
    }

    func supportDomainRank(_ domain: InsightsDomain, for heroDomain: InsightsDomain) -> Int {
        let order: [InsightsDomain]
        switch heroDomain {
        case .sleep:
            order = [.recovery, .activity, .nutrition, .hydration, .consistency]
        case .activity:
            order = [.recovery, .sleep, .nutrition, .hydration, .consistency]
        case .recovery:
            order = [.activity, .sleep, .nutrition, .hydration, .consistency]
        case .nutrition:
            order = [.recovery, .activity, .sleep, .hydration, .consistency]
        case .hydration:
            order = [.recovery, .activity, .sleep, .nutrition, .consistency]
        case .consistency, .missingData:
            order = [.recovery, .activity, .sleep, .nutrition, .hydration, .consistency]
        }

        return order.firstIndex(of: domain) ?? Int.max
    }

    func supportDomains(for domain: InsightsDomain) -> Set<InsightsDomain> {
        switch domain {
        case .recovery:
            return [.activity, .sleep, .nutrition, .hydration, .consistency]
        case .sleep:
            return [.recovery, .activity, .nutrition, .hydration, .consistency]
        case .activity:
            return [.recovery, .sleep, .nutrition, .hydration, .consistency]
        case .hydration:
            return [.activity, .recovery, .sleep, .nutrition, .consistency]
        case .nutrition:
            return [.activity, .recovery, .sleep, .hydration, .consistency]
        case .consistency, .missingData:
            return [.recovery, .sleep, .activity, .nutrition, .consistency, .missingData]
        }
    }

    func supportCardRow(_ card: InsightSupportCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 11) {
                ZStack {
                    Circle()
                        .fill(card.accent.opacity(0.11))
                        .frame(width: 34, height: 34)

                    Image(systemName: card.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(card.accent.opacity(0.84))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.system(size: 13.3, weight: .bold))
                        .foregroundStyle(textPrimary.opacity(0.95))

                    Text(card.text)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(textSecondary.opacity(0.78))
                        .lineSpacing(1.5)
                }

                Spacer(minLength: 0)

                if supportActionDestination(for: card) != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(textSecondary.opacity(0.48))
                        .padding(.top, 3)
                }
            }

            if let metric = card.metrics.first {
                supportMetricRow(metric, accent: card.accent)
                    .padding(.top, 1)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground.opacity(0.94))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.04), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            perform(action: supportActionDestination(for: card))
        }
    }

    func supportActionDestination(for card: InsightSupportCard) -> InsightsActionDestination? {
        switch card.domain {
        case .recovery:
            return .detail(.recovery)
        case .activity:
            return .detail(.activity)
        case .nutrition:
            return .detail(.nutrition)
        case .sleep, .hydration, .consistency, .missingData:
            return nil
        }
    }

    func supportMetricRow(_ metric: InsightTrendMetric, accent: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(metric.direction.symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(accent.opacity(0.82))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.label)
                    .font(.system(size: 10.2, weight: .bold))
                    .foregroundStyle(textSecondary.opacity(0.70))
                Text(metric.benchmark)
                    .font(.system(size: 9.7, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.56))
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text(metric.value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(textPrimary.opacity(0.92))
                Text(metric.detail)
                    .font(.system(size: 9.7, weight: .bold))
                    .foregroundStyle(textSecondary.opacity(0.62))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WeekFitTheme.whiteOpacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    var tryThisNextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("insights.tryThisNext"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textPrimary)

            tryThisNextCard
        }
    }

    var tryThisNextCard: some View {
        let focus = insightExperiment
        return Button {
            perform(action: focus.destination)
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(focus.accent.opacity(0.12))
                            .frame(width: 42, height: 42)

                        Image(systemName: focus.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(focus.accent.opacity(0.88))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(focus.title)
                            .font(.system(size: 14.2, weight: .bold))
                            .foregroundStyle(textPrimary.opacity(0.96))

                        Text(focus.text)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(textSecondary.opacity(0.80))
                            .lineSpacing(1.5)
                    }

                    Spacer(minLength: 0)
                }

                ForEach(focus.metrics) { metric in
                    supportMetricRow(metric, accent: focus.accent)
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(focus.accent.opacity(0.065))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(focus.accent.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(focus.destination == nil)
    }

    var insightExperiment: (title: String, text: String, icon: String, accent: Color, destination: InsightsActionDestination?, metrics: [InsightTrendMetric]) {
        if let card = snapshot.supportCards.first(where: { $0.role == .experiment || $0.domain == .consistency }) {
            return (
                card.title,
                card.text,
                card.icon,
                card.accent,
                supportActionDestination(for: card),
                card.metrics.isEmpty ? defaultExperiment(for: snapshot.hero.domain).metrics : card.metrics
            )
        }

        if let opportunity = snapshot.opportunity,
           opportunity.domain == snapshot.hero.domain || supportDomains(for: snapshot.hero.domain).contains(opportunity.domain) {
            return (
                opportunity.title,
                experimentText(from: opportunity.text, domain: opportunity.domain),
                opportunity.icon,
                opportunity.accent,
                opportunity.actionDestination,
                defaultExperiment(for: opportunity.domain).metrics
            )
        }

        if let learning = snapshot.learnings.first(where: { learning in
            learning.domain == snapshot.hero.domain || supportDomains(for: snapshot.hero.domain).contains(learning.domain)
        }) {
            return (
                learning.title,
                experimentText(from: learning.text, domain: learning.domain),
                learning.icon,
                learning.accent,
                nil,
                defaultExperiment(for: learning.domain).metrics
            )
        }

        return defaultExperiment(for: snapshot.hero.domain)
    }

    func experimentText(from text: String, domain: InsightsDomain) -> String {
        if text.count <= 118 {
            return text
        }

        return defaultExperiment(for: domain).text
    }

    func defaultExperiment(for domain: InsightsDomain) -> (title: String, text: String, icon: String, accent: Color, destination: InsightsActionDestination?, metrics: [InsightTrendMetric]) {
        switch domain {
        case .recovery:
            return ("Watch the recovery response", "Keep the next training week steady and compare recovery after harder days.", "heart.fill", WeekFitTheme.meal, .detail(.recovery), viewExperimentMetrics(action: "steady week", outcome: "steadier recovery", window: "7 days"))
        case .sleep:
            return ("Test one earlier night", "Move bedtime earlier twice this week and watch whether recovery feels easier.", "moon.zzz.fill", WeekFitTheme.purple, .detail(.recovery), viewExperimentMetrics(action: "earlier bedtime", outcome: "easier recovery", window: "3 nights"))
        case .activity:
            return ("Compare load and recovery", "Keep intensity less clustered this week and watch the recovery response.", "figure.run", WeekFitTheme.orange, .detail(.activity), viewExperimentMetrics(action: "spread intensity", outcome: "steadier recovery", window: "1 week"))
        case .hydration:
            return ("Watch fluids after load", "Track fluids around harder sessions this week and compare recovery the next morning.", "drop.fill", WeekFitTheme.blue, .detail(.nutrition), viewExperimentMetrics(action: "fluids after load", outcome: "steadier recovery", window: "1 week"))
        case .nutrition:
            return ("Test meal timing", "Move one late meal earlier and watch sleep quality the next morning.", "fork.knife", WeekFitTheme.blue, .detail(.nutrition), viewExperimentMetrics(action: "earlier dinner", outcome: "better sleep", window: "2 nights"))
        case .consistency, .missingData:
            return ("Build a clearer pattern", "Log the core signals for a week so Insights can separate signal from noise.", "sparkles", snapshot.hero.accent, .tab(.today), viewExperimentMetrics(action: "complete logs", outcome: "clearer pattern", window: "7 days"))
        }
    }

    func viewExperimentMetrics(action: String, outcome: String, window: String) -> [InsightTrendMetric] {
        [
            InsightTrendMetric(label: "Action", value: action, direction: .increasing, detail: "keep it simple", benchmark: "try this"),
            InsightTrendMetric(label: "Expected", value: outcome, direction: .increasing, detail: "watch the response", benchmark: "look for"),
            InsightTrendMetric(label: "Review", value: window, direction: .stable, detail: "check back", benchmark: "after")
        ]
    }

    var whatWeLearnedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("insights.whatWeLearned"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textPrimary)

            VStack(spacing: 8) {
                ForEach(snapshot.learnings) { learning in
                    learningRow(learning)
                }
            }
        }
    }

    func learningRow(_ learning: InsightsLearning) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                Circle()
                    .fill(learning.accent.opacity(0.11))
                    .frame(width: 34, height: 34)

                Image(systemName: learning.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(learning.accent.opacity(0.84))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(learning.label)
                    .font(.system(size: 9.2, weight: .bold))
                    .tracking(0.28)
                    .foregroundStyle(learning.accent.opacity(0.78))

                Text(learning.title)
                    .font(.system(size: 13.3, weight: .bold))
                    .foregroundStyle(textPrimary.opacity(0.95))

                Text(learning.text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.78))
                    .lineSpacing(1.5)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground.opacity(0.94))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.04), lineWidth: 1)
        }
    }

    @ViewBuilder
    var opportunitySection: some View {
        if let opportunity = snapshot.opportunity {
            Button {
                perform(action: opportunity.actionDestination)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(opportunity.accent.opacity(0.12))
                            .frame(width: 42, height: 42)

                        Image(systemName: opportunity.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(opportunity.accent.opacity(0.88))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(opportunity.label)
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.32)
                            .foregroundStyle(opportunity.accent.opacity(0.78))

                        Text(opportunity.title)
                            .font(.system(size: 14.2, weight: .bold))
                            .foregroundStyle(textPrimary.opacity(0.96))

                        Text(opportunity.text)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(textSecondary.opacity(0.80))
                            .lineSpacing(1.5)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(opportunity.accent.opacity(0.065))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(opportunity.accent.opacity(0.08), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(opportunity.actionDestination == nil)
        }
    }
}

// MARK: - Trends

private extension InsightsView {

    var recoveryTrendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("insights.recoveryTrend"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textPrimary)

            if let trend = trend(for: .recovery) {
                trendButton(trend)
            }
        }
    }

    var activityLoadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(InsightsLocalization.View.activityLoad)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textPrimary)

            if let trend = trend(for: .activity) {
                trendButton(trend)
            }
        }
    }

    var secondaryInsightSection: some View {
        Group {
            if let insight = secondaryInsight {
                trendButton(insight, label: InsightsLocalization.Section.secondarySignal)
            }
        }
    }

    func trend(for domain: InsightsDomain) -> InsightsTrendCard? {
        snapshot.trends.first { trend in
            trend.domain == domain &&
                !trend.title.localizedCaseInsensitiveContains("unavailable") &&
                !trend.title.localizedCaseInsensitiveContains("not enough") &&
                !trend.title.localizedCaseInsensitiveContains("not complete")
        }
    }

    var secondaryInsight: InsightsTrendCard? {
        snapshot.trends.first { trend in
            trend.domain != snapshot.hero.domain &&
                trend.domain != .missingData &&
                !trend.title.localizedCaseInsensitiveContains("unavailable") &&
                !trend.title.localizedCaseInsensitiveContains("not enough") &&
                !trend.title.localizedCaseInsensitiveContains("not complete")
        }
    }

    var trendsSection: some View {
        VStack(spacing: 10) {
            ForEach(snapshot.trends.indices, id: \.self) { index in
                let trend = snapshot.trends[index]
                trendButton(trend)
            }
        }
    }

    func trendButton(_ trend: InsightsTrendCard, label: String? = nil) -> some View {
        Button {
            perform(action: trend.actionDestination)
        } label: {
            trendCard(
                accent: trend.accent,
                label: label ?? trend.label,
                title: trend.title,
                subtitle: trend.subtitle,
                takeaway: trend.takeaway,
                icon: trend.icon
            )
        }
        .buttonStyle(.plain)
        .disabled(trend.actionDestination == nil)
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

                    Text(subtitle)
                        .font(.system(size: 10.4, weight: .semibold))
                        .foregroundStyle(textSecondary.opacity(0.76))
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
                .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.65), radius: 10, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .background(accent.opacity(0.045))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.032), lineWidth: 1)
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

                Text(snapshot.hydrationImpact.subtitle)
                    .font(.system(size: 10.4, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.76))
                    .lineSpacing(1.5)
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
                .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.65), radius: 10, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            perform(action: snapshot.weeklyReflection.actionDestination)
        }
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
                .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.65), radius: 10, y: 5)
    }

    var dataCoverageCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(InsightsLocalization.Section.dataCoverage)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.35)
                    .foregroundStyle(textSecondary.opacity(0.70))

                Spacer()

                Text(snapshot.dataQuality.hasAnySignal ? InsightsLocalization.Section.trustMeter : InsightsLocalization.Section.building)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(snapshot.hero.accent.opacity(0.82))
            }

            HStack(spacing: 8) {
                coverageColumn(title: InsightsLocalization.Section.recovery, value: snapshot.dataQuality.recoveryDays, target: 30, color: WeekFitTheme.meal)
                coverageColumn(title: InsightsLocalization.Section.sleep, value: snapshot.dataQuality.sleepDays, target: 30, color: WeekFitTheme.purple)
                coverageColumn(title: InsightsLocalization.Section.activity, value: snapshot.dataQuality.activityDays, target: 7, color: WeekFitTheme.orange)
                coverageColumn(title: InsightsLocalization.Section.meals, value: snapshot.dataQuality.mealDays, target: 7, color: WeekFitTheme.meal)
                coverageColumn(title: InsightsLocalization.Section.water, value: snapshot.dataQuality.hydrationDays, target: 7, color: WeekFitTheme.blue)
            }
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(cardBackground.opacity(0.94))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.04), lineWidth: 1)
        }
    }

    func coverageColumn(title: String, value: Int, target: Int, color: Color) -> some View {
        let progress = min(Double(value) / Double(max(target, 1)), 1)

        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9.2, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(WeekFitTheme.whiteOpacity(0.055))
                    .frame(height: 5)

                Capsule(style: .continuous)
                    .fill(color.opacity(0.78))
                    .frame(width: 44 * CGFloat(progress), height: 5)
            }

            Text("\(min(value, target))/\(target)")
                .font(.system(size: 10.4, weight: .bold))
                .foregroundStyle(textPrimary.opacity(0.88))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

                Text(snapshot.focusNext.text)
                    .font(.system(size: 11.3, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.78))
                    .lineSpacing(1.5)

                Text(snapshot.focusNext.action)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(snapshot.focusNext.accent.opacity(0.90))
                    .padding(.top, 1)

                HStack(spacing: 6) {
                    Text(snapshot.focusNext.actionTitle)
                        .font(.system(size: 11, weight: .bold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(textPrimary.opacity(0.90))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(snapshot.focusNext.accent.opacity(0.12))
                .clipShape(Capsule(style: .continuous))
                .padding(.top, 2)
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
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            perform(action: snapshot.focusNext.actionDestination)
        }
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
                .stroke(WeekFitTheme.whiteOpacity(0.04), lineWidth: 1)
        }
    }
}

private struct PremiumInsightAreaChart: View {
    let values: [Double]
    let target: Double?
    let targetLabel: String?
    let accent: Color
    let upperZoneLabel: String
    let middleZoneLabel: String
    let lowerZoneLabel: String
    let upperBoundary: Double
    let middleBoundary: Double

    var body: some View {
        GeometryReader { geometry in
            let axisHeight: CGFloat = 14
            let rowSpacing: CGFloat = 8
            let labelSpacing: CGFloat = 12
            let labelWidth: CGFloat = min(86, max(70, geometry.size.width * 0.20))
            let plotWidth = max(geometry.size.width - labelWidth - labelSpacing, 1)
            let plotHeight = max(geometry.size.height - axisHeight - rowSpacing, 1)
            let plotSize = CGSize(width: plotWidth, height: plotHeight)

            VStack(spacing: rowSpacing) {
                HStack(alignment: .top, spacing: labelSpacing) {
                let points = chartPoints(in: plotSize)
                let upperBoundaryY = yPosition(for: upperBoundary, in: plotSize)
                let lowerBoundaryY = yPosition(for: middleBoundary, in: plotSize)
                let topZoneY = yPosition(for: (upperBoundary + 1) / 2, in: plotSize)
                let middleZoneY = yPosition(for: (upperBoundary + middleBoundary) / 2, in: plotSize)
                let lowerZoneY = yPosition(for: middleBoundary / 2, in: plotSize)

                    ZStack {
                        zoneLine(y: upperBoundaryY, width: plotWidth, opacity: 0.09)
                        zoneLine(y: lowerBoundaryY, width: plotWidth, opacity: 0.08)
                        zoneLine(y: topZoneY, width: plotWidth, opacity: 0.06)
                        targetLine(y: middleZoneY, width: plotWidth)
                        zoneLine(y: lowerZoneY, width: plotWidth, opacity: 0.08)

                        areaPath(points: points, bottomY: plotSize.height)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.045),
                                        accent.opacity(0.006)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        smoothPath(points: points)
                            .stroke(
                                accent.opacity(0.30),
                                style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)
                            )
                            .blur(radius: 8)

                        smoothPath(points: points)
                            .stroke(
                                accent.opacity(0.94),
                                style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round)
                            )

                        endMarker(points: points)
                    }
                    .frame(width: plotWidth, height: plotSize.height)
                    .clipped()

                    zoneLabels(
                        width: labelWidth,
                        topY: topZoneY,
                        middleY: middleZoneY,
                        lowerY: lowerZoneY
                    )
                }

                HStack(alignment: .top, spacing: labelSpacing) {
                    HStack {
                        Text(InsightsLocalization.View.chart30dAgo)
                        Spacer()
                        Text(InsightsLocalization.View.chart15d)
                        Spacer()
                        Text(WeekFitLocalizedString("Today"))
                    }
                    .frame(width: plotWidth)
                    .font(.system(size: 9.8, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))

                    Color.clear
                        .frame(width: labelWidth, height: axisHeight)
                }
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        let normalizedValues = values.isEmpty ? [0.5, 0.5] : values.map { min(max($0, 0), 1) }
        let displayValues = normalizedValues.count == 1 ? [normalizedValues[0], normalizedValues[0]] : normalizedValues
        let step = size.width / CGFloat(max(displayValues.count - 1, 1))

        return displayValues.indices.map { index in
            CGPoint(
                x: CGFloat(index) * step,
                y: yPosition(for: displayValues[index], in: size)
            )
        }
    }

    private func yPosition(for value: Double, in size: CGSize) -> CGFloat {
        let clampedValue = min(max(value, 0), 1)
        let topInset: CGFloat = 12
        let bottomInset: CGFloat = 18
        let drawableHeight = max(size.height - topInset - bottomInset, 1)
        return topInset + drawableHeight * CGFloat(1 - clampedValue)
    }

    private func zoneLine(y: CGFloat, width: CGFloat, opacity: Double) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        .stroke(WeekFitTheme.whiteOpacity(opacity), lineWidth: 1)
    }

    private func targetLine(y: CGFloat, width: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
        }
        .stroke(
            WeekFitTheme.whiteOpacity(0.22),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [5, 7])
        )
    }

    private func zoneLabels(width: CGFloat, topY: CGFloat, middleY: CGFloat, lowerY: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            zoneLabel(upperZoneLabel, accent: false)
                .position(x: width / 2, y: max(10, topY - 11))

            zoneLabel(targetLabel ?? middleZoneLabel, accent: true)
                .position(x: width / 2, y: max(14, middleY - 13))

            zoneLabel(lowerZoneLabel, accent: false)
                .position(x: width / 2, y: max(10, lowerY - 11))
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
    }

    private func zoneLabel(_ label: String, accent isAccent: Bool) -> some View {
        Text(label)
            .font(.system(size: isAccent ? 10.6 : 9.4, weight: isAccent ? .bold : .semibold))
            .foregroundStyle(isAccent ? accent.opacity(0.92) : WeekFitTheme.whiteOpacity(0.34))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func endMarker(points: [CGPoint]) -> some View {
        let point = points.last ?? .zero

        return ZStack {
            Circle()
                .stroke(accent.opacity(0.26), lineWidth: 7)
                .frame(width: 20, height: 20)
                .blur(radius: 2)

            Circle()
                .fill(accent)
                .frame(width: 8.5, height: 8.5)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.72), lineWidth: 1.2)
                }
        }
        .position(point)
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        Path { path in
            addSmoothCurve(to: &path, points: points)
        }
    }

    private func areaPath(points: [CGPoint], bottomY: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: bottomY))
            path.addLine(to: first)
            addSmoothCurve(to: &path, points: points, moveToFirstPoint: false)
            path.addLine(to: CGPoint(x: last.x, y: bottomY))
            path.closeSubpath()
        }
    }

    private func addSmoothCurve(to path: inout Path, points: [CGPoint], moveToFirstPoint: Bool = true) {
        guard let first = points.first else { return }
        if moveToFirstPoint {
            path.move(to: first)
        }
        guard points.count > 1 else { return }

        for index in 0..<(points.count - 1) {
            let p0 = index > 0 ? points[index - 1] : points[index]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = index + 2 < points.count ? points[index + 2] : p2
            let tension: CGFloat = 0.92

            var control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * tension / 6,
                y: p1.y + (p2.y - p0.y) * tension / 6
            )
            var control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * tension / 6,
                y: p2.y - (p3.y - p1.y) * tension / 6
            )

            let minY = min(p1.y, p2.y)
            let maxY = max(p1.y, p2.y)
            control1.y = min(max(control1.y, minY), maxY)
            control2.y = min(max(control2.y, minY), maxY)

            path.addCurve(to: p2, control1: control1, control2: control2)
        }
    }
}
