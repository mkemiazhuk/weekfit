import SwiftUI
import Charts
import HealthKit
import CoreLocation
import MapKit
import WeekFitWorkoutMetrics
internal import Combine

struct ActivityHistoricalPoint: Identifiable, Hashable {
    var id: Date { date }

    let date: Date
    let activeCalories: Int
}

struct ActivityTimelinePoint: Identifiable, Hashable {
    let id = UUID()
    let hour: Int
    let activeCalories: Double
}

struct ActivitySessionDetailSnapshot: Hashable {
    let title: String
    let activityType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let durationMinutes: Int
    let workoutDurationSeconds: TimeInterval
    let elapsedDurationSeconds: TimeInterval
    let source: String?
    let icon: String
    let color: Color
    let activeCalories: Double?
    let distanceKm: Double?
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let heartRateSamples: [WorkoutHeartRateSample]
    let routePoints: [WorkoutRoutePoint]
    let elevationGain: Double?
    let steps: Int?
    let cadence: Double?
    var activeHeartRateIntervals: [DateInterval] = []

    var averageSpeedKmh: Double? {
        guard let distanceKm, distanceKm > 0, workoutDurationSeconds > 0 else {
            return nil
        }

        return distanceKm / (workoutDurationSeconds / 3600.0)
    }

    var averagePaceMinutesPerKm: Double? {
        guard let distanceKm, distanceKm > 0, workoutDurationSeconds > 0 else {
            return nil
        }

        return (workoutDurationSeconds / 60.0) / distanceKm
    }

    var shouldShowPace: Bool {
        switch activityType {
        case .hiking, .walking, .running:
            return true
        default:
            return false
        }
    }

    var shouldShowElapsedTime: Bool {
        elapsedDurationSeconds > workoutDurationSeconds + 60
    }

    var shouldShowDistanceMetrics: Bool {
        !ActivityDistanceMetricsExpectation.suppresses(
            activityType: activityType,
            title: title,
            icon: icon
        )
    }

    func merging(_ supplemental: WorkoutHealthDetailSnapshot) -> ActivitySessionDetailSnapshot {
        ActivitySessionDetailSnapshot(
            title: title,
            activityType: activityType,
            startDate: startDate,
            endDate: endDate,
            durationMinutes: durationMinutes,
            workoutDurationSeconds: workoutDurationSeconds,
            elapsedDurationSeconds: elapsedDurationSeconds,
            source: supplemental.source ?? source,
            icon: icon,
            color: color,
            activeCalories: supplemental.activeCalories ?? activeCalories,
            distanceKm: supplemental.distanceKm ?? distanceKm,
            averageHeartRate: supplemental.averageHeartRate ?? averageHeartRate,
            maxHeartRate: supplemental.maxHeartRate ?? maxHeartRate,
            heartRateSamples: supplemental.heartRateSamples.isEmpty
                ? heartRateSamples
                : supplemental.heartRateSamples,
            routePoints: supplemental.routePoints.isEmpty
                ? routePoints
                : supplemental.routePoints,
            elevationGain: supplemental.elevationGain ?? elevationGain,
            steps: supplemental.steps ?? steps,
            cadence: supplemental.cadence ?? cadence,
            activeHeartRateIntervals: supplemental.activeHeartRateIntervals.isEmpty
                ? activeHeartRateIntervals
                : supplemental.activeHeartRateIntervals
        )
    }

    /// Prefer non-empty collections and filled optionals from either side.
    func mergingCached(_ other: ActivitySessionDetailSnapshot) -> ActivitySessionDetailSnapshot {
        ActivitySessionDetailSnapshot(
            title: title,
            activityType: activityType,
            startDate: startDate,
            endDate: endDate,
            durationMinutes: durationMinutes,
            workoutDurationSeconds: workoutDurationSeconds,
            elapsedDurationSeconds: elapsedDurationSeconds,
            source: source ?? other.source,
            icon: icon,
            color: color,
            activeCalories: activeCalories ?? other.activeCalories,
            distanceKm: distanceKm ?? other.distanceKm,
            averageHeartRate: averageHeartRate ?? other.averageHeartRate,
            maxHeartRate: maxHeartRate ?? other.maxHeartRate,
            heartRateSamples: heartRateSamples.isEmpty ? other.heartRateSamples : heartRateSamples,
            routePoints: routePoints.count > 1
                ? routePoints
                : (other.routePoints.count > 1 ? other.routePoints : routePoints),
            elevationGain: elevationGain ?? other.elevationGain,
            steps: steps ?? other.steps,
            cadence: cadence ?? other.cadence,
            activeHeartRateIntervals: activeHeartRateIntervals.isEmpty
                ? other.activeHeartRateIntervals
                : activeHeartRateIntervals
        )
    }
}

struct ActivitySessionSnapshot: Identifiable, Hashable {
    let id = UUID()
    let workoutID: UUID?
    let title: String
    let startDate: Date
    let durationMinutes: Int
    let icon: String
    let color: Color
    let detail: ActivitySessionDetailSnapshot?
    /// Stable PlannedActivity.id when this session was opened from Plan / Up Next.
    let plannedActivityId: String?

    init(
        workoutID: UUID?,
        title: String,
        startDate: Date,
        durationMinutes: Int,
        icon: String,
        color: Color,
        detail: ActivitySessionDetailSnapshot?,
        plannedActivityId: String? = nil
    ) {
        self.workoutID = workoutID
        self.title = title
        self.startDate = startDate
        self.durationMinutes = durationMinutes
        self.icon = icon
        self.color = color
        self.detail = detail
        self.plannedActivityId = plannedActivityId
    }
}

struct ActivityDaySnapshot: Identifiable, Hashable {
    var id: Date { date }

    var date: Date
    let activeCalories: Int
    let activityGoal: Int
    let activityPercent: Int
    let exerciseMinutes: Int
    let standHours: Int
    let steps: Int
    let distanceKm: Double
    let vo2Max: Double
    let recoveryPercent: Int
    let sessions: [ActivitySessionSnapshot]
    let hourlyActivityPoints: [ActivityTimelinePoint]
    let historicalSameWeekdayPoints: [ActivityHistoricalPoint]
    /// Primary sleep session associated with this calendar day (typically the prior night).
    let sleepInterval: DateInterval?

    static let empty = ActivityDaySnapshot(
        date: Date(),
        activeCalories: 0,
        activityGoal: 0,
        activityPercent: 0,
        exerciseMinutes: 0,
        standHours: 0,
        steps: 0,
        distanceKm: 0,
        vo2Max: 0,
        recoveryPercent: 0,
        sessions: [],
        hourlyActivityPoints: (0...23).map { ActivityTimelinePoint(hour: $0, activeCalories: 0) },
        historicalSameWeekdayPoints: [],
        sleepInterval: nil
    )
}

private enum ActivityWeekdayWidth {
    case wide
    case abbreviated
}

private func localizedDetailsDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = WeekFitCurrentLocale()
    formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
    return formatter.string(from: date)
}

private func localizedWeekday(_ date: Date, width: ActivityWeekdayWidth) -> String {
    let formatter = DateFormatter()
    formatter.locale = WeekFitCurrentLocale()
    formatter.setLocalizedDateFormatFromTemplate(width == .wide ? "EEEE" : "EEE")
    return formatter.string(from: date)
}

struct ActivityIntelligenceView: View {

    let selectedDate: Date
    @ObservedObject var healthManager: HealthManager
    let plannedActivities: [PlannedActivity]

    @StateObject private var viewModel = ActivityIntelligenceViewModel()
    @State private var selectedSession: ActivitySessionSnapshot?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var languageManager: AppLanguageManager

    private var snapshot: ActivityDaySnapshot {
        viewModel.selectedSnapshot
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack {
            (palette.isLight ? HealthDetailsSoftChrome.canvas : ActivityStyle.screenBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if palette.isLight {
                    NutritionDetailsHeader(
                        title: WeekFitLocalizedString("activity.activityDetails"),
                        subtitle: activityDetailsDateTitle,
                        onClose: { dismiss() }
                    )

                    NutritionWeekSelector(
                        selectedDate: Binding(
                            get: { viewModel.selectedDate },
                            set: { select($0) }
                        ),
                        accentColor: WeekFitLightTokens.activity
                    )
                    .padding(.horizontal, HealthDetailsSoftChrome.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                } else {
                    header

                    HealthDetailsWeekPicker(
                        selectedDate: Binding(
                            get: { viewModel.selectedDate },
                            set: { select($0) }
                        ),
                        accentColor: ActivityStyle.activityColor
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 9)
                    .padding(.bottom, 8)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: palette.isLight ? HealthDetailsSoftChrome.sectionSpacing : 9) {
                        ActivityHeroCard(snapshot: snapshot)
                        ActivityDailyMetricsCard(snapshot: snapshot)
                        ActivityTimelineCard(
                            points: snapshot.hourlyActivityPoints,
                            totalActiveCalories: snapshot.activeCalories,
                            activityGoal: snapshot.activityGoal,
                            dayStart: Calendar.current.startOfDay(for: snapshot.date),
                            sleepInterval: snapshot.sleepInterval
                        )
                        WeeklyContextCard(
                            selectedSnapshot: snapshot,
                            weekSnapshots: viewModel.weekSnapshots
                        )
                        SessionsCard(sessions: snapshot.sessions) { session in
                            selectedSession = session
                        }
                    }
                    .padding(.horizontal, palette.isLight ? HealthDetailsSoftChrome.horizontalPadding : 18)
                    .padding(.top, palette.isLight ? 8 : 5)
                    .padding(.bottom, palette.isLight ? 24 : 36)
                }
            }

            if viewModel.isLoading && viewModel.weekSnapshots.isEmpty {
                ProgressView()
                    .tint(palette.isLight ? WeekFitLightTokens.activity : .white.opacity(0.75))
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(item: $selectedSession) { session in
            ActivitySessionDetailView(
                session: session,
                healthManager: healthManager
            )
        }
        .task {
            await viewModel.load(
                selectedDate: selectedDate,
                healthManager: healthManager,
                plannedActivities: plannedActivities
            )
        }
        .onChange(of: languageManager.selectedLanguage) { _, _ in
            Task {
                await viewModel.load(
                    selectedDate: viewModel.selectedDate,
                    healthManager: healthManager,
                    plannedActivities: plannedActivities
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WeekFitLocalizedString("activity.activityDetails"))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(activityDetailsDateTitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.56))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            WeekFitCloseButton(size: .large) {
                dismiss()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 11)
        .background {
            ActivityStyle.screenBackground.ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WeekFitTheme.whiteOpacity(0.04))
                .frame(height: 1)
        }
    }

    private var activityDetailsDateTitle: String {
        localizedDetailsDate(viewModel.selectedDate)
    }

    private func select(_ date: Date) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            await viewModel.load(
                selectedDate: date,
                healthManager: healthManager,
                plannedActivities: plannedActivities
            )
        }
    }
}

// MARK: - Hero

private struct ActivityHeroCard: View {
    let snapshot: ActivityDaySnapshot
    @Environment(\.weekFitPalette) private var palette

    private var progress: CGFloat {
        CGFloat(min(max(snapshot.activityPercent, 0), 100)) / 100
    }

    var body: some View {
        HStack(spacing: palette.isLight ? 12 : 15) {
            activityRing

            VStack(alignment: .leading, spacing: palette.isLight ? 4 : 5) {
                Text(WeekFitLocalizedString("activity.activityScore"))
                    .font(
                        palette.isLight
                            ? NutritionDetailsDesign.Typography.eyebrow
                            : .system(size: 10, weight: .bold, design: .rounded)
                    )
                    .tracking(palette.isLight ? 0.6 : 1.8)
                    .foregroundStyle(
                        palette.isLight ? WeekFitLightTokens.activity : ActivityStyle.activityColor
                    )

                Text(WeekFitLocalizedString(statusText))
                    .font(
                        palette.isLight
                            ? NutritionDetailsDesign.Typography.insight
                            : .system(size: ActivityTypography.heroTitle, weight: .bold, design: .rounded)
                    )
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(WeekFitLocalizedString(insightText))
                    .font(
                        palette.isLight
                            ? NutritionDetailsDesign.Typography.metricSecondary
                            : .system(size: ActivityTypography.heroText, weight: .medium, design: .rounded)
                    )
                    .foregroundStyle(
                        palette.isLight
                            ? WeekFitLightTokens.textSecondary
                            : WeekFitTheme.whiteOpacity(0.52)
                    )
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, palette.isLight ? 14 : 17)
        .padding(.vertical, palette.isLight ? 12 : 14)
        .healthDetailsSoftCard(
            isLight: palette.isLight,
            darkGlow: ActivityStyle.activityColor
        )
    }

    private var activityRing: some View {
        WeekFitProgressRing(
            progress: progress,
            color: WeekFitProgressRingColor.activity,
            size: palette.isLight ? 58 : 70,
            strokeWidth: palette.isLight ? 4.5 : 4,
            gradientColors: [
                WeekFitProgressRingColor.activity.opacity(0.80),
                WeekFitProgressRingColor.activity,
                Color(red: 0.36, green: 0.90, blue: 0.38),
                Color(red: 0.22, green: 0.84, blue: 0.88).opacity(0.94)
            ]
        ) {
            VStack(spacing: -2) {
                Text("\(snapshot.activityPercent)")
                    .font(
                        palette.isLight
                            ? NutritionDetailsDesign.Typography.score
                            : .system(size: ActivityTypography.heroScore, weight: .bold, design: .rounded)
                    )
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .monospacedDigit()

                Text(WeekFitLocalizedString("activity.score"))
                    .font(
                        palette.isLight
                            ? NutritionDetailsDesign.Typography.scoreDenom
                            : .system(size: ActivityTypography.heroScoreLabel, weight: .bold, design: .rounded)
                    )
                    .foregroundStyle(
                        palette.isLight
                            ? WeekFitLightTokens.textQuaternary
                            : WeekFitTheme.whiteOpacity(0.40)
                    )
            }
        }
    }

    private var statusText: String {
        switch snapshot.activityPercent {
        case 100...:
            return WeekFitLocalizedString("activity.targetAchieved")
        case 80..<100:
            return WeekFitLocalizedString("activity.almostThere")
        case 45..<80:
            return WeekFitLocalizedString("activity.activeDay")
        case 20..<45:
            return WeekFitLocalizedString("activity.lightlyActive")
        case 1..<20:
            return WeekFitLocalizedString("activity.lowActivity")
        default:
            return WeekFitLocalizedString("activity.noActivityYet")
        }
    }

    private var insightText: String {
        if snapshot.activityGoal <= 0 {
            return WeekFitLocalizedString("activity.activityDataIsShownFromAppleHealthWhenAvailable")
        }

        switch snapshot.activityPercent {
        case 100...:
            return String(
                format: WeekFitLocalizedString("activity.youReachedTodaySMovementTargetWithActiveKcal"),
                snapshot.activeCalories.formatted()
            )
        case 80..<100:
            return WeekFitLocalizedString("activity.youAreCloseToYourTargetAShortWalk")
        case 45..<80:
            return WeekFitLocalizedString("activity.goodMovementVolumeTodayKeepActivitySteadyThroughThe")
        case 20..<45:
            return String(
                format: WeekFitLocalizedString("activity.activeKcalCompletedSoFarThereIsRoomTo"),
                snapshot.activeCalories.formatted()
            )
        case 1..<20:
            return String(
                format: WeekFitLocalizedString("activity.onlyLldOfYourDailyMovementTargetHasBeen"),
                snapshot.activityPercent
            )
        default:
            return WeekFitLocalizedString("activity.noMeaningfulMovementHasBeenRecordedYetToday")
        }
    }
}

// MARK: - Daily Metrics

private struct ActivityDailyMetricsCard: View {
    let snapshot: ActivityDaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(WeekFitLocalizedString("activity.details.section.keyMetrics"))

            HStack(alignment: .top, spacing: 8) {
                compactMetric(
                    title: WeekFitLocalizedString("today.status.metric.exercise"),
                    value: exerciseText,
                    icon: "figure.run",
                    color: ActivityStyle.activityColor
                )

                compactMetric(
                    title: WeekFitLocalizedString("today.status.metric.stand"),
                    value: standText,
                    icon: "figure.stand",
                    color: ActivityStyle.green
                )

                compactMetric(
                    title: WeekFitLocalizedString("common.unit.vo2"),
                    value: vo2Text,
                    icon: "lungs.fill",
                    color: ActivityStyle.teal
                )
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .activityCard(glow: ActivityStyle.activityColor)
    }

    private var exerciseText: String {
        let minutes = max(0, snapshot.exerciseMinutes)

        if minutes <= 0 {
            return "—"
        }

        if minutes < 60 {
            return String(format: WeekFitLocalizedString("common.duration.minutesShortFormat"), minutes)
        }

        return String(format: "%.1f %@", Double(minutes) / 60.0, WeekFitLocalizedString("common.unit.hoursShort"))
    }

    private var standText: String {
        snapshot.standHours > 0 ? "\(snapshot.standHours)/12" : "—"
    }

    private var vo2Text: String {
        snapshot.vo2Max > 0 ? String(format: "%.1f", snapshot.vo2Max) : "—"
    }

    private func compactMetric(
        title: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 30, height: 30)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.50))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(value)
                    .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .padding(.horizontal, 5)
        .healthDetailsNestedTile(isLight: WeekFitPaletteStore.current.isLight)
    }
}

// MARK: - Timeline

private struct ActivityTimelineCard: View {
    let points: [ActivityTimelinePoint]
    let totalActiveCalories: Int
    let activityGoal: Int
    let dayStart: Date
    let sleepInterval: DateInterval?

    private static let sleepNoiseThresholdKcal = 8.0
    private static let minimumChartScaleKcal = 60.0

    private var maxCalories: Double {
        points.map { displayCalories(for: $0) }.max() ?? 0
    }

    private var chartYAxisMax: Double {
        let peak = max(maxCalories, 1)
        let goalBaseline = Double(max(activityGoal, 300)) * 0.12
        return max(peak * 1.15, goalBaseline, Self.minimumChartScaleKcal)
    }

    private var peakPoint: ActivityTimelinePoint? {
        points.max { $0.activeCalories < $1.activeCalories }
    }

    private var peakCalories: Int {
        Int((peakPoint?.activeCalories ?? 0).rounded())
    }

    private var peakText: String {
        guard let point = peakPoint, point.activeCalories > 0 else { return "—" }
        let next = min(point.hour + 1, 24)
        return "\(String(format: "%02d:00", point.hour))–\(String(format: "%02d:00", next))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(WeekFitLocalizedString("activity.activityTimeline"))

            HStack(spacing: 10) {
                activityMetric(
                    title: WeekFitLocalizedString("activity.metric.peak"),
                    value: peakText,
                    icon: "chart.bar.fill",
                    color: ActivityStyle.activityColor
                )

                activityMetric(
                    title: WeekFitLocalizedString("activity.metric.activeKcal"),
                    value: "\(totalActiveCalories)",
                    icon: "flame.fill",
                    color: ActivityStyle.green
                )
            }

            Chart(points) { point in
                BarMark(
                    x: .value("Hour", point.hour),
                    y: .value("Calories", displayCalories(for: point)),
                    width: .fixed(8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .foregroundStyle(barGradient(for: point))
            }
            .chartYScale(domain: 0...chartYAxisMax)
            .chartXAxis {
                AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(String(format: "%02d", hour))
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundStyle(WeekFitTheme.whiteOpacity(0.45))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(WeekFitTheme.whiteOpacity(0.045))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text("\(Int(number))")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
                        }
                    }
                }
            }
            .frame(height: 118)
            .transaction {
                $0.animation = nil
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .activityCard(glow: ActivityStyle.activityColor)
    }

    private func activityMetric(
        title: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 30, height: 30)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(WeekFitLocalizedString(title))
                    .font(.system(size: ActivityTypography.metricSecondary, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.50))
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barGradient(for point: ActivityTimelinePoint) -> LinearGradient {
        let value = displayCalories(for: point)
        let ratio = value / chartYAxisMax

        let colors: [Color]

        if value <= 0 {
            colors = [
                WeekFitTheme.whiteOpacity(0.04),
                WeekFitTheme.whiteOpacity(0.015)
            ]
        } else if isSleepNoise(point) {
            colors = [
                WeekFitTheme.whiteOpacity(0.06),
                WeekFitTheme.whiteOpacity(0.02)
            ]
        } else if ratio >= 0.75 {
            colors = [
                ActivityStyle.activityColor,
                ActivityStyle.teal.opacity(0.70)
            ]
        } else if ratio >= 0.35 {
            colors = [
                ActivityStyle.activityColor.opacity(0.80),
                ActivityStyle.green.opacity(0.48)
            ]
        } else {
            colors = [
                ActivityStyle.teal.opacity(0.45),
                WeekFitTheme.whiteOpacity(0.05)
            ]
        }

        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private func displayCalories(for point: ActivityTimelinePoint) -> Double {
        guard point.activeCalories > 0 else { return 0 }
        if isSleepNoise(point) { return 0 }
        return point.activeCalories
    }

    private func isSleepNoise(_ point: ActivityTimelinePoint) -> Bool {
        guard point.activeCalories < Self.sleepNoiseThresholdKcal else { return false }
        return hourIntersectsSleep(point.hour)
    }

    private func hourIntersectsSleep(_ hour: Int) -> Bool {
        guard let sleepInterval else { return false }

        let calendar = Calendar.current
        guard let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
              let hourEnd = calendar.date(byAdding: .hour, value: hour + 1, to: dayStart) else {
            return false
        }

        return sleepInterval.intersects(DateInterval(start: hourStart, end: hourEnd))
    }
}

// MARK: - Weekly Context

private struct WeeklyContextCard: View {
    let selectedSnapshot: ActivityDaySnapshot
    let weekSnapshots: [ActivityDaySnapshot]

    private let calendar = Calendar.current

    private var sortedWeekSnapshots: [ActivityDaySnapshot] {
        weekSnapshots.sorted { $0.date < $1.date }
    }

    private var chartItems: [WeeklyContextItem] {
        sortedWeekSnapshots.map { snapshot in
            WeeklyContextItem(
                id: snapshot.date,
                label: shortWeekday(for: snapshot.date),
                calories: snapshot.activeCalories,
                isSelected: calendar.isDate(snapshot.date, inSameDayAs: selectedSnapshot.date)
            )
        }
    }

    private var weekAverage: Int {
        guard !sortedWeekSnapshots.isEmpty else { return 0 }
        let total = sortedWeekSnapshots.map(\.activeCalories).reduce(0, +)
        return Int((Double(total) / Double(sortedWeekSnapshots.count)).rounded())
    }

    private var typicalSameWeekdayAverage: Int {
        guard !selectedSnapshot.historicalSameWeekdayPoints.isEmpty else { return 0 }

        let total = selectedSnapshot.historicalSameWeekdayPoints
            .map(\.activeCalories)
            .reduce(0, +)

        return Int((Double(total) / Double(selectedSnapshot.historicalSameWeekdayPoints.count)).rounded())
    }

    private var hasTypicalBaseline: Bool {
        selectedSnapshot.historicalSameWeekdayPoints.count >= 3
    }

    private var maxWeeklyCalories: Int {
        max(chartItems.map(\.calories).max() ?? 0, 1)
    }
    
    private var isToday: Bool {
        Calendar.current.isDate(selectedSnapshot.date, inSameDayAs: Date())
    }

    private var isEarlyToday: Bool {
        isToday && Calendar.current.component(.hour, from: Date()) < 12
    }

    private var weekDeltaText: String {
        if isEarlyToday {
            return WeekFitLocalizedString("activity.comparison.dayEarly")
        }

        return deltaText(
            current: selectedSnapshot.activeCalories,
            baseline: weekAverage,
            label: WeekFitLocalizedString("activity.comparison.weekAverage")
        )
    }
    
    private var typicalDeltaText: String? {
        if isEarlyToday {
            return WeekFitLocalizedString("activity.comparison.weeklyLater")
        }

        guard hasTypicalBaseline else { return nil }

        return deltaText(
            current: selectedSnapshot.activeCalories,
            baseline: typicalSameWeekdayAverage,
            label: String(format: WeekFitLocalizedString("activity.comparison.typicalWeekdayFormat"), weekdayName)
        )
    }
    
    private var deltaColor: Color {
        if isEarlyToday {
            return ActivityStyle.activityColor
        }

        guard weekAverage > 0 else { return WeekFitTheme.tertiaryText }

        return selectedSnapshot.activeCalories >= weekAverage
            ? ActivityStyle.activityColor
            : ActivityStyle.purple
    }

    private var weekDeltaIcon: String {
        if isEarlyToday {
            return "clock.fill"
        }

        guard weekAverage > 0 else { return "minus" }

        return selectedSnapshot.activeCalories >= weekAverage
            ? "arrow.up.right"
            : "arrow.down.right"
    }

    private var weekdayName: String {
        localizedWeekday(selectedSnapshot.date, width: .wide)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(WeekFitLocalizedString("activity.thisWeek"))

            VStack(alignment: .leading, spacing: 8) {
                comparisonRow(
                    text: weekDeltaText,
                    icon: weekDeltaIcon,
                    color: deltaColor,
                    prominence: .primary
                )

                if let typicalDeltaText {
                    comparisonRow(
                        text: typicalDeltaText,
                        icon: "calendar",
                        color: WeekFitTheme.secondaryText,
                        prominence: .secondary
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .innerActivityCard(cornerRadius: 16)

            weeklyBarChart
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .activityCard(glow: ActivityStyle.activityColor)
    }

    private func comparisonRow(
        text: String,
        icon: String,
        color: Color,
        prominence: WeeklyComparisonProminence
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 16, height: 16)
                .padding(.top, 1)

            Text(text)
                .font(
                    .system(
                        size: prominence == .primary ? ActivityTypography.metricValue : ActivityTypography.helperText,
                        weight: prominence == .primary ? .bold : .medium,
                        design: .rounded
                    )
                )
                .foregroundStyle(color)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var weeklyBarChart: some View {
        GeometryReader { proxy in
            let chartHeight = max(proxy.size.height - 34, 1)

            HStack(alignment: .bottom, spacing: 7) {
                ForEach(chartItems) { item in
                    VStack(spacing: 4) {
                        Text(shortCalories(item.calories))
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(item.isSelected ? ActivityStyle.activityColor.opacity(0.95) : WeekFitTheme.tertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(WeekFitTheme.whiteOpacity(item.isSelected ? 0.075 : 0.040))
                                .frame(width: item.isSelected ? 13 : 10, height: chartHeight)

                            Capsule()
                                .fill(barFill(for: item))
                                .frame(width: item.isSelected ? 13 : 10, height: barHeight(for: item.calories, maxHeight: chartHeight))
                                .shadow(color: item.isSelected ? ActivityStyle.activityColor.opacity(0.18) : .clear, radius: 5, x: 0, y: 2)
                        }

                        Text(item.label)
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(item.isSelected ? ActivityStyle.activityColor.opacity(0.95) : WeekFitTheme.tertiaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 112)
        .padding(.horizontal, 2)
    }

    private func barHeight(for calories: Int, maxHeight: CGFloat) -> CGFloat {
        guard calories > 0 else { return 3 }
        return max(8, maxHeight * CGFloat(calories) / CGFloat(maxWeeklyCalories))
    }

    private func barFill(for item: WeeklyContextItem) -> LinearGradient {
        let colors: [Color]
        if item.isSelected {
            colors = [ActivityStyle.activityColor, ActivityStyle.teal.opacity(0.75)]
        } else if WeekFitPaletteStore.current.isLight {
            colors = [
                WeekFitLightTokens.iconSecondary,
                WeekFitLightTokens.iconInactive
            ]
        } else {
            colors = [WeekFitTheme.whiteOpacity(0.38), WeekFitTheme.whiteOpacity(0.18)]
        }

        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private func deltaText(
        current: Int,
        baseline: Int,
        label: String
    ) -> String {
        guard baseline > 0 else { return WeekFitLocalizedString("activity.comparison.noBaseline") }

        let ratio = Double(current) / Double(max(baseline, 1))
        let delta = Int(abs((ratio - 1.0) * 100.0).rounded())

        if delta == 0 {
            return String(format: WeekFitLocalizedString("activity.comparison.inLineFormat"), label)
        }

        return ratio >= 1.0
            ? String(format: WeekFitLocalizedString("activity.comparison.aboveFormat"), delta, label)
            : String(format: WeekFitLocalizedString("activity.comparison.belowFormat"), delta, label)
    }

    private func shortWeekday(for date: Date) -> String {
        localizedWeekday(date, width: .abbreviated).uppercased(with: WeekFitCurrentLocale())
    }

    private func isSelectedLabel(_ label: String) -> Bool {
        label == shortWeekday(for: selectedSnapshot.date)
    }

    private func shortCalories(_ value: Int) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", Double(value) / 1000.0)
        }

        return "\(value)"
    }
}

private struct WeeklyContextItem: Identifiable {
    let id: Date
    let label: String
    let calories: Int
    let isSelected: Bool
}

private enum WeeklyComparisonProminence {
    case primary
    case secondary
}

// MARK: - Sessions

private struct SessionsCard: View {
    let sessions: [ActivitySessionSnapshot]
    let onSelect: (ActivitySessionSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                SectionLabel(WeekFitLocalizedString("activity.activityLog"))

                Spacer()

                if !sessions.isEmpty {
                    Text(WeekFitCountPluralization.phrase(count: sessions.count, category: .session))
                        .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.42))
                }
            }

            if sessions.isEmpty {
                EmptySessionsRow()
            } else {
                VStack(spacing: 9) {
                    ForEach(sessions) { session in
                        SessionRow(session: session) {
                            onSelect(session)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .activityCard()
    }
}

private struct SessionRow: View {
    let session: ActivitySessionSnapshot
    let onTap: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            HStack(spacing: 11) {
                CircleIcon(systemName: session.icon, color: session.color, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))

                    Text(session.timeRange)
                        .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.46))
                }

                Spacer()

                HStack(spacing: 6) {
                    Text(DurationFormatter.fullMinutes(session.durationMinutes))
                        .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.86))
                        .monospacedDigit()

                    Image(systemName: "chevron.right")
                        .font(.system(size: ActivityTypography.helperText, weight: .bold))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.24))
                }
            }
        }
        .padding(12)
        .innerActivityCard(cornerRadius: 15)
        .buttonStyle(.plain)
    }
}

// MARK: - Session Detail

private struct ActivitySessionSourcePresentation {
    enum Kind {
        case appleWatch
        case healthKit
        case planner
        case planned
        case other(String)
    }

    let kind: Kind

    init(source: String?) {
        let trimmed = source?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalized = trimmed.lowercased()

        switch normalized {
        case "apple watch", "applewatch":
            kind = .appleWatch
        case "planned":
            kind = .planned
        case "planner", "today":
            kind = .planner
        case "apple health", "applehealth", "healthkit", "appleworkout":
            kind = .healthKit
        case "":
            kind = .healthKit
        default:
            if normalized.contains("watch") {
                kind = .appleWatch
            } else {
                kind = .other(trimmed.isEmpty ? normalized : trimmed)
            }
        }
    }

    var badgeSystemImage: String {
        switch kind {
        case .appleWatch:
            return "applewatch"
        case .healthKit:
            return "heart.text.square.fill"
        case .planner:
            return "calendar.badge.checkmark"
        case .planned:
            return "calendar"
        case .other:
            return "arrow.triangle.2.circlepath"
        }
    }

    var badgeText: String {
        switch kind {
        case .appleWatch:
            return String(
                format: WeekFitLocalizedString("activity.syncedFrom"),
                WeekFitLocalizedString("activity.data.source.appleWatch")
            )
        case .healthKit:
            return String(
                format: WeekFitLocalizedString("activity.syncedFrom"),
                WeekFitLocalizedString("activity.data.source.appleHealth")
            )
        case .planner:
            return WeekFitLocalizedString("activity.loggedFromPlan")
        case .planned:
            return WeekFitLocalizedString("activity.plannedInPlan")
        case .other(let name):
            return String(format: WeekFitLocalizedString("activity.syncedFrom"), name)
        }
    }

    var footerText: String {
        switch kind {
        case .planner:
            return WeekFitLocalizedString("activity.dataFromPlan")
        case .planned:
            return WeekFitLocalizedString("activity.dataFromPlanned")
        case .appleWatch:
            return String(
                format: WeekFitLocalizedString("activity.dataFrom"),
                WeekFitLocalizedString("activity.data.source.appleWatch")
            )
        case .healthKit:
            return String(
                format: WeekFitLocalizedString("activity.dataFrom"),
                WeekFitLocalizedString("activity.data.source.appleHealth")
            )
        case .other(let name):
            return String(format: WeekFitLocalizedString("activity.dataFrom"), name)
        }
    }
}

struct ActivitySessionDetailView: View {
    let session: ActivitySessionSnapshot
    @ObservedObject var healthManager: HealthManager
    @EnvironmentObject private var unitsStore: WeekFitUnitsStore

    @Environment(\.dismiss) private var dismiss
    @State private var loadedDetail: ActivitySessionDetailSnapshot?
    @State private var isHeartRateLoading = false
    @State private var isRouteLoading = false
    @State private var isRouteMapPresented = false
    @State private var isRoutePreviewEnabled = false
    @State private var expectsRouteData = false
    @State private var isClosing = false
    @State private var remainingSupplementalLoads = 0
    @State private var supplementalMetricsSettled = false
    @State private var routeLoadingSettled = false

    private var detail: ActivitySessionDetailSnapshot? {
        loadedDetail ?? session.detail
    }

    private var heartRateSamples: [WorkoutHeartRateSample] {
        detail?.heartRateSamples ?? []
    }

    private var routePoints: [WorkoutRoutePoint] {
        detail?.routePoints ?? []
    }

    private var sessionDurationSeconds: TimeInterval {
        if let seconds = detail?.workoutDurationSeconds, seconds > 0 {
            return seconds
        }
        return Double(max(session.durationMinutes, 1) * 60)
    }

    /// Upcoming plan item opened before completion — no finished-session metrics yet.
    private var isUnfinishedPlannedSession: Bool {
        if session.workoutID != nil { return false }
        if case .planned = sourcePresentation.kind { return true }
        if let detail, detail.elapsedDurationSeconds <= 0, detail.activeCalories == nil {
            return detail.source?.lowercased() == "planned"
        }
        return false
    }

    private var sessionDurationMinutes: Double {
        max(sessionDurationSeconds / 60.0, 1)
    }

    private var heartRateChartPoints: [HeartRateChartPoint] {
        let samples = downsampleHeartRateSamples(heartRateSamples, maximumCount: 220)
        let startDate = detail?.startDate ?? session.startDate
        let elapsedSeconds = max(detail?.elapsedDurationSeconds ?? session.endDate.timeIntervalSince(session.startDate), 1)

        return samples.map {
            let elapsedOffset = max(0, min($0.timestamp.timeIntervalSince(startDate), elapsedSeconds))
            let workoutMinute = elapsedOffset / elapsedSeconds * sessionDurationMinutes

            return HeartRateChartPoint(
                timestamp: $0.timestamp,
                minute: workoutMinute,
                beatsPerMinute: $0.beatsPerMinute
            )
        }
    }

    private var relativeMinuteMarks: [Double] {
        let duration = sessionDurationMinutes
        return [0, 0.25, 0.5, 0.75, 1.0].map {
            (duration * $0).rounded()
        }
    }

    private var heartRateVisibleDomain: ClosedRange<Double> {
        let values = heartRateSamples.map(\.beatsPerMinute)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 60...180
        }

        let lowerZoneBoundary = allHeartRateThresholds.last(where: { $0 <= minValue }) ?? minValue
        let upperZoneBoundary = allHeartRateThresholds.first(where: { $0 >= maxValue }) ?? maxValue
        var lower = max(40, floor(min(minValue, lowerZoneBoundary) / 10) * 10 - 10)
        var upper = min(220, ceil(max(maxValue, upperZoneBoundary) / 10) * 10 + 10)

        if upper - lower < 40 {
            let midpoint = (upper + lower) / 2
            lower = max(40, midpoint - 20)
            upper = min(220, midpoint + 20)
        }

        return lower...upper
    }

    private var heartRateZoneProfile: HeartRateZones.Profile {
        HeartRateZones.Profile.apple(
            age: healthManager.age,
            restingHeartRate: healthManager.restingHeartRate
        )
    }

    private var heartRateZoneDefinitions: [HeartRateZoneDefinition] {
        HeartRateZones.definitions(for: heartRateZoneProfile).map { definition in
            HeartRateZoneDefinition(
                title: "activity.heartRate.zone\(definition.number)",
                number: definition.number,
                lowerBound: definition.lowerBound,
                upperBound: definition.upperBound,
                range: definition.bpmRangeLabel,
                color: HeartRateZones.color(for: definition.number)
            )
        }
    }

    private var allHeartRateThresholds: [Double] {
        heartRateZoneDefinitions
            .dropFirst()
            .map(\.lowerBound)
    }

    private var heartRateThresholds: [Double] {
        allHeartRateThresholds
            .filter { heartRateVisibleDomain.contains($0) }
    }

    private var heartRateYAxisValues: [Double] {
        let values = heartRateThresholds + [
            heartRateVisibleDomain.lowerBound,
            heartRateVisibleDomain.upperBound
        ]

        return Array(Set(values.map { ($0 / 10).rounded() * 10 })).sorted()
    }

    private var heartRateLineSegments: [HeartRateLineSegment] {
        guard let first = heartRateChartPoints.first else { return [] }

        var segments: [HeartRateLineSegment] = []
        var currentZone = heartRateZone(for: first.beatsPerMinute)
        var currentPoints: [HeartRateChartPoint] = [first]

        for point in heartRateChartPoints.dropFirst() {
            let zone = heartRateZone(for: point.beatsPerMinute)

            if zone.id != currentZone.id {
                currentPoints.append(point)
                segments.append(
                    HeartRateLineSegment(
                        zone: currentZone,
                        points: currentPoints
                    )
                )
                currentZone = zone
                currentPoints = [point]
            } else {
                currentPoints.append(point)
            }
        }

        if currentPoints.count > 1 {
            segments.append(
                HeartRateLineSegment(
                    zone: currentZone,
                    points: currentPoints
                )
            )
        }

        return segments
    }

    private func heartRateZone(for beatsPerMinute: Double) -> HeartRateZoneDefinition {
        heartRateZoneDefinitions.first { zone in
            beatsPerMinute >= zone.lowerBound && beatsPerMinute < zone.upperBound
        } ?? heartRateZoneDefinitions.last!
    }

    var body: some View {
        ZStack {
            ActivityStyle.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 9) {
                    sessionHeroCard

                    // Planned-but-not-started sessions should not show workout metrics
                    // (avoids confusing "1m" from zeroed finished-session fields).
                    if !isUnfinishedPlannedSession {
                        metricsCard
                    }

                    if let coachAdjustment {
                        CoachAdjustmentDetailSection(adjustment: coachAdjustment)
                            .onAppear {
                                ProductAnalytics.morningProposalAdjustedItemViewed(
                                    changeKind: coachAdjustment.kind,
                                    source: .activityDetail
                                )
                            }
                    }

                    if !isUnfinishedPlannedSession, isHeartRateLoading || !heartRateSamples.isEmpty {
                        heartRateCard
                    }

                    if !isUnfinishedPlannedSession, expectsRouteData {
                        routeCard
                    }

                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .fullScreenCover(isPresented: $isRouteMapPresented) {
            WorkoutRouteDetailMapView(
                points: routePoints,
                color: session.color,
                title: session.title
            )
        }
        .onDisappear {
            isRouteMapPresented = false
        }
        .task(id: session.id) {
            // Run before route auth so HealthKit permission sheets do not stack.
            await healthManager.ensureHeartRateZonePhysiology()
            await loadSupplementalDetails()
        }
    }

    private var closeButton: some View {
        WeekFitCloseButton(size: .regular) {
            closeDetail()
        }
    }

    private func closeDetail() {
        guard !isClosing else { return }

        isClosing = true
        isRouteMapPresented = false
        isRoutePreviewEnabled = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dismiss()
        }
    }

    private var sessionHeroCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(session.color.opacity(0.12))
                    .frame(width: 84, height: 84)

                Circle()
                    .stroke(session.color.opacity(0.90), lineWidth: 2)
                    .frame(width: 84, height: 84)

                Image(systemName: session.icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(session.color)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 8) {
                    Text(session.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 0)

                    closeButton
                }

                Text(activityDateText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.56))
                    .lineLimit(1)

                Text(detailTimeRange)
                    .font(.system(size: ActivityTypography.heroText, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)

                HStack(spacing: 5) {
                    Image(systemName: sourcePresentation.badgeSystemImage)
                        .font(.system(size: 11, weight: .bold))

                    Text(sourcePresentation.badgeText)
                        .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(WeekFitTheme.whiteOpacity(0.045))
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    private var sourcePresentation: ActivitySessionSourcePresentation {
        ActivitySessionSourcePresentation(source: detail?.source)
    }

    private var coachAdjustment: AppliedCoachAdjustment? {
        guard let plannedId = session.plannedActivityId else { return nil }
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: session.startDate)
        return CoachProvenanceLookupCache.adjustment(forActivityId: plannedId, dayKey: dayKey)
    }

    private var activityDateText: String {
        localizedDetailsDate(session.startDate)
    }

    private var detailTimeRange: String {
        let startDate = detail?.startDate ?? session.startDate
        let endDate = detail?.endDate ?? session.endDate
        let start = startDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        let end = endDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return "\(start) – \(end)"
    }

    private var metricsCard: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 0),
                count: metricsColumnCount
            ),
            spacing: 0
        ) {
            ForEach(metricItems) { item in
                SessionMetricGridCell(item: item)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .activityCard(glow: session.color)
    }

    private var heartRateCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                SectionLabel(WeekFitLocalizedString("activity.heartRate"))

                Spacer()

                HStack(spacing: 10) {
                    if let averageHeartRate = detail?.averageHeartRate {
                        Text(String(format: WeekFitLocalizedString("activity.heartRate.averageFormat"), Int(averageHeartRate.rounded())))
                    }

                    if let maxHeartRate = detail?.maxHeartRate {
                        Text(String(format: WeekFitLocalizedString("activity.heartRate.maxFormat"), Int(maxHeartRate.rounded())))
                    }
                }
                .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
                .monospacedDigit()
            }

            if isHeartRateLoading && heartRateSamples.isEmpty {
                SessionDetailSkeletonLine(color: ActivityStyle.red)
                    .frame(height: 118)
                    .innerActivityCard(cornerRadius: 15)

                VStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        SessionDetailSkeletonLine(color: ActivityStyle.red.opacity(0.45))
                            .frame(height: 14)
                    }
                }
            } else {
                Chart {
                    ForEach(heartRateThresholds, id: \.self) { threshold in
                        RuleMark(y: .value("Threshold", threshold))
                            .foregroundStyle(heartRateZone(for: threshold).color.opacity(0.14))
                            .lineStyle(StrokeStyle(lineWidth: 0.65, dash: [3, 5]))
                    }

                    ForEach(heartRateLineSegments) { segment in
                        ForEach(segment.points) { sample in
                            LineMark(
                                x: .value("Minute", sample.minute),
                                y: .value("BPM", sample.beatsPerMinute),
                                series: .value("Zone Segment", segment.id.uuidString)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(segment.zone.color)
                            .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                        }
                    }
                }
                .chartXScale(domain: 0...max(sessionDurationMinutes, 1))
                .chartYScale(domain: heartRateVisibleDomain)
                .chartXAxis {
                    AxisMarks(values: relativeMinuteMarks) { value in
                        AxisValueLabel {
                            if let minute = value.as(Double.self) {
                                Text(String(format: WeekFitLocalizedString("common.unit.minuteFormat"), Int(minute.rounded())))
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: heartRateYAxisValues) { value in
                        AxisGridLine().foregroundStyle(WeekFitTheme.whiteOpacity(0.055))
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text("\(Int(number))")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
                            }
                        }
                    }
                }
                .frame(height: 164)
                .transaction {
                    $0.animation = nil
                }

                VStack(spacing: 8) {
                    ForEach(heartRateZones) { zone in
                        HeartRateZoneLegendRow(
                            zone: zone,
                            maxSeconds: heartRateZoneMaxSeconds
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .activityCard(glow: ActivityStyle.red)
    }

    private var routeCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionLabel(WeekFitLocalizedString("activity.route"))

            HStack(spacing: 12) {
                if isRouteLoading && routePoints.isEmpty {
                    SessionDetailSkeletonLine(color: session.color)
                        .frame(height: 132)
                        .frame(maxWidth: .infinity)
                        .innerActivityCard(cornerRadius: 15)
                } else if isRoutePreviewEnabled, routePoints.count > 1 {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isRouteMapPresented = true
                    } label: {
                        WorkoutRouteMapPreview(points: routePoints, color: session.color)
                            .frame(height: 132)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                session.color.opacity(0.55),
                                                WeekFitTheme.whiteOpacity(0.14),
                                                session.color.opacity(0.22)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                            .shadow(color: session.color.opacity(0.18), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(WeekFitLocalizedString("activity.route.viewMap")))
                    .accessibilityHint(Text(WeekFitLocalizedString("activity.route.expandHint")))
                } else if routeLoadingSettled {
                    routeUnavailablePlaceholder
                } else {
                    SessionDetailSkeletonLine(color: session.color)
                        .frame(height: 132)
                        .frame(maxWidth: .infinity)
                        .innerActivityCard(cornerRadius: 15)
                }

                VStack(alignment: .leading, spacing: 12) {
                    if let elevationGain = detail?.elevationGain {
                        routeMetric(
                            title: "activity.metric.elevation",
                            value: MetricFormatter.elevation(elevationGain, system: unitsStore.resolvedSystem),
                            icon: "mountain.2.fill",
                            color: ActivityStyle.amber
                        )
                    }

                    if let detail, detail.shouldShowDistanceMetrics,
                       let distanceKm = detail.distanceKm {
                        routeMetric(
                            title: "activity.metric.distance",
                            value: MetricFormatter.distance(distanceKm, system: unitsStore.resolvedSystem),
                            icon: "mappin.and.ellipse",
                            color: ActivityStyle.blue
                        )
                    }
                }
                .frame(width: 112, alignment: .leading)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .activityCard(glow: session.color)
    }

    private var routeUnavailablePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: healthManager.hasWorkoutRouteReadAccess() ? "map" : "lock.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(session.color.opacity(0.72))

            Text(
                healthManager.hasWorkoutRouteReadAccess()
                    ? WeekFitLocalizedString("activity.route.noGpsData")
                    : WeekFitLocalizedString("activity.route.permissionRequired")
            )
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .innerActivityCard(cornerRadius: 15)
    }

    private var timeInZonesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionLabel(WeekFitLocalizedString("activity.timeInZones"))

            HStack(spacing: 14) {
                ZoneDonutView(zones: heartRateZones)
                    .frame(width: 96, height: 96)

                VStack(spacing: 7) {
                    ForEach(heartRateZones) { zone in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 8, height: 8)

                            Text(WeekFitLocalizedString(zone.title))
                                .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                                .foregroundStyle(WeekFitTheme.whiteOpacity(0.72))
                                .frame(width: 42, alignment: .leading)
                                .lineLimit(1)

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(WeekFitTheme.whiteOpacity(0.065))

                                    Capsule()
                                        .fill(zone.color)
                                        .frame(width: proxy.size.width * CGFloat(zone.percentage) / 100)
                                }
                            }
                            .frame(height: 7)

                            Text(String(format: WeekFitLocalizedString("common.unit.minuteFormat"), zone.minutes))
                                .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                                .foregroundStyle(WeekFitTheme.whiteOpacity(0.70))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(width: 58, alignment: .trailing)
                                .monospacedDigit()

                            Text(String(format: WeekFitLocalizedString("activity.percentFormat"), zone.percentage))
                                .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                                .foregroundStyle(WeekFitTheme.whiteOpacity(0.44))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .frame(width: 34, alignment: .trailing)
                                .monospacedDigit()
                        }
                        .frame(height: 16)
                    }
                }
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .activityCard(glow: ActivityStyle.red)
    }

    private var footer: some View {
        Text(sourcePresentation.footerText)
            .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 3)
    }

    private var metricItems: [SessionMetricItem] {
        let system = unitsStore.resolvedSystem
        var items: [SessionMetricItem] = [
            SessionMetricItem(
                title: detail?.shouldShowElapsedTime == true
                    ? "activity.metric.workoutTime"
                    : "activity.metric.duration",
                value: WorkoutHeartRateAnalytics.durationLabel(seconds: sessionDurationSeconds),
                unit: "",
                icon: "clock",
                color: ActivityStyle.activityColor
            )
        ]

        if let detail, detail.shouldShowElapsedTime {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.elapsedTime",
                    value: WorkoutHeartRateAnalytics.durationLabel(seconds: detail.elapsedDurationSeconds),
                    unit: "",
                    icon: "timer",
                    color: ActivityStyle.teal
                )
            )
        }

        if let detail, detail.shouldShowDistanceMetrics, let distanceKm = detail.distanceKm {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.distance",
                    value: MetricFormatter.compactDistance(distanceKm, system: system),
                    unit: WeekFitUnitPolicy.distanceUnitLabel(for: system),
                    icon: "mappin.circle.fill",
                    color: ActivityStyle.green
                )
            )
        }

        if let activeCalories = detail?.activeCalories {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.activeCalories",
                    value: "\(Int(activeCalories.rounded()))",
                    unit: WeekFitLocalizedString("common.unit.kcal"),
                    icon: "flame.fill",
                    color: ActivityStyle.amber
                )
            )
        }

        if let averageHeartRate = detail?.averageHeartRate {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.avgHeartRate",
                    value: "\(Int(averageHeartRate.rounded()))",
                    unit: WeekFitLocalizedString("common.unit.bpm"),
                    icon: "heart.fill",
                    color: ActivityStyle.red
                )
            )
        }

        if let detail, detail.shouldShowDistanceMetrics {
            if detail.shouldShowPace, let pace = detail.averagePaceMinutesPerKm {
                items.append(
                    SessionMetricItem(
                        title: "activity.metric.avgPace",
                        value: MetricFormatter.compactPace(pace, system: system),
                        unit: WeekFitUnitPolicy.paceUnitLabel(for: system),
                        icon: "speedometer",
                        color: ActivityStyle.green
                    )
                )
            } else if let speed = detail.averageSpeedKmh {
                items.append(
                    SessionMetricItem(
                        title: "activity.metric.avgSpeed",
                        value: MetricFormatter.compactSpeed(speed, system: system),
                        unit: WeekFitUnitPolicy.speedUnitLabel(for: system),
                        icon: "speedometer",
                        color: ActivityStyle.green
                    )
                )
            }
        }

        if let detail, detail.shouldShowDistanceMetrics, !detail.shouldShowPace, let maxSpeedKmh {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.maxSpeed",
                    value: MetricFormatter.compactSpeed(maxSpeedKmh, system: system),
                    unit: WeekFitUnitPolicy.speedUnitLabel(for: system),
                    icon: "speedometer",
                    color: ActivityStyle.green
                )
            )
        }

        if let elevationGain = detail?.elevationGain {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.elevationGain",
                    value: MetricFormatter.compactElevation(elevationGain, system: system),
                    unit: WeekFitUnitPolicy.elevationUnitLabel(for: system),
                    icon: "mountain.2.fill",
                    color: ActivityStyle.activityColor
                )
            )
        }

        if let cadence = detail?.cadence {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.avgCadence",
                    value: "\(Int(cadence.rounded()))",
                    unit: WeekFitLocalizedString("common.unit.rpm"),
                    icon: "chart.bar.xaxis",
                    color: ActivityStyle.purple
                )
            )
        }

        if let steps = detail?.steps, items.count < 8 {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.steps",
                    value: MetricFormatter.compactSteps(steps),
                    unit: "",
                    icon: "shoeprints.fill",
                    color: ActivityStyle.blue
                )
            )
        }

        return items
    }

    private var metricsColumnCount: Int {
        let count = metricItems.count

        if count >= 6 {
            return 3
        }

        if count >= 4 {
            return 3
        }

        return max(count, 1)
    }

    private var maxSpeedKmh: Double? {
        guard detail?.shouldShowDistanceMetrics != false else { return nil }
        guard routePoints.count > 1 else { return nil }

        return WorkoutRouteMaxSpeedCalculator.maxSpeedKmh(
            from: routePoints,
            averageSpeedKmh: detail?.averageSpeedKmh,
            absoluteCeilingKmh: maxSpeedAbsoluteCeilingKmh
        )
    }

    private var maxSpeedAbsoluteCeilingKmh: Double {
        switch detail?.activityType {
        case .cycling, .handCycling:
            return WorkoutRouteMaxSpeedCalculator.AbsoluteCeilingKmh.cycling
        case .running:
            return WorkoutRouteMaxSpeedCalculator.AbsoluteCeilingKmh.running
        case .walking, .wheelchairWalkPace:
            return WorkoutRouteMaxSpeedCalculator.AbsoluteCeilingKmh.walking
        case .hiking:
            return WorkoutRouteMaxSpeedCalculator.AbsoluteCeilingKmh.hiking
        case .swimming, .paddleSports, .rowing:
            return WorkoutRouteMaxSpeedCalculator.AbsoluteCeilingKmh.swimming
        default:
            return WorkoutRouteMaxSpeedCalculator.AbsoluteCeilingKmh.outdoorDefault
        }
    }

    private func routeMetric(
        title: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(WeekFitLocalizedString(title))
                    .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.46))

                Text(value)
                    .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                    .monospacedDigit()
            }
        }
    }

    private var heartRateZones: [HeartRateZoneSummary] {
        let startDate = detail?.startDate ?? session.startDate
        let endDate = detail?.endDate ?? session.endDate
        let intervals = {
            let stored = detail?.activeHeartRateIntervals ?? []
            if stored.isEmpty {
                return [DateInterval(start: startDate, end: endDate)]
            }
            return stored
        }()
        let zoneSeconds = heartRateZoneDefinitions.map { definition in
            (definition, WorkoutHeartRateAnalytics.secondsInZone(
                samples: heartRateSamples,
                activeIntervals: intervals,
                contains: { definition.contains($0) }
            ))
        }
        let durationForPercentage = max(sessionDurationSeconds, 1)

        return zoneSeconds.map { definition, seconds in
            HeartRateZoneSummary(
                title: definition.title,
                range: definition.range,
                color: definition.color,
                seconds: seconds,
                percentage: min(100, Int((seconds / durationForPercentage * 100.0).rounded()))
            )
        }
    }

    private var heartRateZoneMaxSeconds: TimeInterval {
        max(heartRateZones.map(\.seconds).max() ?? 1, 1)
    }

    private func applyPreloadedDemoDetailIfAvailable() {
        guard let existing = session.detail else { return }

        loadedDetail = existing
        expectsRouteData = ActivityRouteExpectation.expectsRoute(for: existing.activityType)
        isHeartRateLoading = false
        isRouteLoading = false
        routeLoadingSettled = true
        supplementalMetricsSettled = true
        isRoutePreviewEnabled = existing.routePoints.count > 1
    }

    private func loadSupplementalDetails() async {
        if healthManager.isAppReviewDemoActive {
            applyPreloadedDemoDetailIfAvailable()
            return
        }

        guard let workoutID = session.workoutID else { return }

        let baseDetail = detail
        let activityType = baseDetail?.activityType ?? .other
        let start = baseDetail?.startDate ?? session.startDate
        let end = baseDetail?.endDate ?? session.endDate
        let expectsRoute = ActivityRouteExpectation.expectsRoute(for: activityType)
        expectsRouteData = expectsRoute

        if let cached = ActivitySessionDetailCache.detail(
            for: workoutID,
            activityType: activityType
        ) {
            loadedDetail = cached
            supplementalMetricsSettled = true
            let needsHeartRate = cached.heartRateSamples.isEmpty
                && !ActivitySessionDetailCache.heartRateIsResolved(workoutID)
            isHeartRateLoading = needsHeartRate
            isRoutePreviewEnabled = cached.routePoints.count > 1

            let needsRoute = expectsRoute
                && cached.routePoints.count <= 1
                && !ActivitySessionDetailCache.routeIsResolved(workoutID)
            isRouteLoading = needsRoute
            routeLoadingSettled = !needsRoute

            if !needsHeartRate && !needsRoute {
                return
            }

            if needsHeartRate {
                remainingSupplementalLoads = 1
            }

            async let heartRate: WorkoutHealthDetailSnapshot? = {
                guard needsHeartRate else { return nil }
                return await healthManager.loadWorkoutHeartRateDetails(
                    for: workoutID,
                    start: start,
                    end: end
                )
            }()

            if needsRoute {
                async let routeLoad: Void = loadRouteDetailsWithRetry(
                    workoutID: workoutID,
                    start: start,
                    end: end
                )

                if needsHeartRate, let heartRate = await heartRate {
                    guard !Task.isCancelled else { return }
                    isHeartRateLoading = false
                    if !heartRate.heartRateSamples.isEmpty || heartRate.averageHeartRate != nil {
                        mergeSupplementalDetails(heartRate)
                    }
                    ActivitySessionDetailCache.markHeartRateResolved(workoutID)
                    finishMetricsSupplementalLoad(for: workoutID)
                }

                await routeLoad
            } else if needsHeartRate, let heartRate = await heartRate {
                guard !Task.isCancelled else { return }
                isHeartRateLoading = false
                if !heartRate.heartRateSamples.isEmpty || heartRate.averageHeartRate != nil {
                    mergeSupplementalDetails(heartRate)
                }
                ActivitySessionDetailCache.markHeartRateResolved(workoutID)
                finishMetricsSupplementalLoad(for: workoutID)
            }
            return
        }

        supplementalMetricsSettled = false
        routeLoadingSettled = !expectsRoute
        isHeartRateLoading = true
        isRouteLoading = expectsRoute
        remainingSupplementalLoads = 2

        async let metrics = healthManager.loadWorkoutSupplementalMetrics(
            for: workoutID,
            start: start,
            end: end,
            activityType: activityType
        )
        async let heartRate = healthManager.loadWorkoutHeartRateDetails(
            for: workoutID,
            start: start,
            end: end
        )
        async let routeLoad: Void = {
            guard expectsRoute else { return }
            await loadRouteDetailsWithRetry(
                workoutID: workoutID,
                start: start,
                end: end
            )
        }()

        if let metrics = await metrics {
            guard !Task.isCancelled else { return }
            mergeSupplementalDetails(metrics)
        }
        finishMetricsSupplementalLoad(for: workoutID)

        let loadedHeartRate = await heartRate
        guard !Task.isCancelled else { return }
        isHeartRateLoading = false
        if !loadedHeartRate.heartRateSamples.isEmpty || loadedHeartRate.averageHeartRate != nil {
            mergeSupplementalDetails(loadedHeartRate)
        }
        ActivitySessionDetailCache.markHeartRateResolved(workoutID)
        finishMetricsSupplementalLoad(for: workoutID)

        await routeLoad
    }

    private func loadRouteDetailsWithRetry(
        workoutID: UUID,
        start: Date,
        end: Date
    ) async {
        if let route = await healthManager.loadWorkoutRouteDetails(
            for: workoutID,
            start: start,
            end: end
        ), route.routePoints.count > 1 {
            await applyLoadedRoute(route, workoutID: workoutID)
            return
        }

        if Task.isCancelled { return }

        _ = await healthManager.ensureWorkoutRouteAuthorization(presentationDelay: 0)

        // Allow HealthKit a few seconds after the user grants workout routes.
        let retryDelaysSeconds: [TimeInterval] = [0, 0.25, 0.75, 1.5, 3.0]
        let retryStart = Date()

        for (attemptIndex, scheduledOffset) in retryDelaysSeconds.enumerated() {
            if Task.isCancelled { return }

            let elapsed = Date().timeIntervalSince(retryStart)
            let wait = scheduledOffset - elapsed
            if wait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }

            if Task.isCancelled { return }

            let route = await healthManager.loadWorkoutRouteDetails(
                for: workoutID,
                start: start,
                end: end
            )
            let loadedRoute = (route?.routePoints.count ?? 0) > 1

            if let route, loadedRoute {
                await applyLoadedRoute(route, workoutID: workoutID)
                return
            }

            if attemptIndex == retryDelaysSeconds.count - 1 {
                await MainActor.run {
                    isRouteLoading = false
                    routeLoadingSettled = true
                    isRoutePreviewEnabled = false
                    ActivitySessionDetailCache.markRouteResolved(workoutID)
                    cacheDetailIfReady(for: workoutID)
                }
            }
        }
    }

    @MainActor
    private func applyLoadedRoute(_ route: WorkoutHealthDetailSnapshot, workoutID: UUID) {
        mergeSupplementalDetails(route)
        isRoutePreviewEnabled = true
        isRouteLoading = false
        routeLoadingSettled = true
        ActivitySessionDetailCache.markRouteResolved(workoutID)
        cacheDetailIfReady(for: workoutID)
    }

    private func finishMetricsSupplementalLoad(for workoutID: UUID) {
        remainingSupplementalLoads = max(remainingSupplementalLoads - 1, 0)

        if remainingSupplementalLoads == 0 {
            supplementalMetricsSettled = true
            cacheDetailIfReady(for: workoutID)
        }
    }

    private func cacheDetailIfReady(for workoutID: UUID) {
        guard supplementalMetricsSettled, let loadedDetail else { return }
        ActivitySessionDetailCache.store(loadedDetail, for: workoutID)
    }

    private func mergeSupplementalDetails(_ supplemental: WorkoutHealthDetailSnapshot) {
        let base = detail ?? ActivitySessionDetailSnapshot(
            title: session.title,
            activityType: .other,
            startDate: session.startDate,
            endDate: session.endDate,
            durationMinutes: session.durationMinutes,
            workoutDurationSeconds: Double(session.durationMinutes * 60),
            elapsedDurationSeconds: session.endDate.timeIntervalSince(session.startDate),
            source: nil,
            icon: session.icon,
            color: session.color,
            activeCalories: nil,
            distanceKm: nil,
            averageHeartRate: nil,
            maxHeartRate: nil,
            heartRateSamples: [],
            routePoints: [],
            elevationGain: nil,
            steps: nil,
            cadence: nil,
            activeHeartRateIntervals: []
        )

        loadedDetail = base.merging(supplemental)

        if supplemental.routePoints.count > 1 {
            isRoutePreviewEnabled = true
        }
    }
}

private struct HeartRateZoneDefinition: Identifiable, Hashable {
    var id: String { title }

    let title: String
    let number: Int
    let lowerBound: Double
    let upperBound: Double
    let range: String
    let color: Color

    func contains(_ beatsPerMinute: Double) -> Bool {
        beatsPerMinute >= lowerBound && beatsPerMinute < upperBound
    }
}

@MainActor
private enum ActivityDistanceMetricsExpectation {
    static func suppresses(
        activityType: HKWorkoutActivityType,
        title: String,
        icon: String
    ) -> Bool {
        switch activityType {
        case .traditionalStrengthTraining,
             .functionalStrengthTraining,
             .yoga,
             .flexibility,
             .coreTraining,
             .pilates,
             .mindAndBody,
             .cooldown:
            return true
        default:
            break
        }

        let haystack = [title, icon].joined(separator: " ").lowercased()

        if containsAny(haystack, [
            "upper body", "lower body", "full body", "strength", "gym",
            "weights", "dumbbell", "barbell", "сил", "зал", "трениров",
            "figure.strengthtraining", "figure.core.training"
        ]) {
            return true
        }

        if containsAny(haystack, ["yoga", "йога", "figure.yoga"]) {
            return true
        }

        if containsAny(haystack, [
            "stretch", "stretching", "flexibility", "mobility", "растяж", "мобил",
            "cooldown", "figure.cooldown"
        ]) {
            return true
        }

        return false
    }

    private static func containsAny(_ text: String, _ tokens: [String]) -> Bool {
        tokens.contains { text.contains($0) }
    }
}

@MainActor
enum ActivityRouteExpectation {
    static func expectsRoute(for activityType: HKWorkoutActivityType) -> Bool {
        switch activityType {
        case .running, .walking, .hiking, .cycling,
             .wheelchairWalkPace, .wheelchairRunPace,
             .crossCountrySkiing, .downhillSkiing, .snowboarding,
             .skatingSports, .rowing, .paddleSports:
            return true
        default:
            return false
        }
    }
}

@MainActor
enum ActivitySessionDetailCache {
    private static var details: [UUID: ActivitySessionDetailSnapshot] = [:]
    private static var heartRateResolvedIDs: Set<UUID> = []
    private static var routeResolvedIDs: Set<UUID> = []

    static func detail(
        for workoutID: UUID,
        activityType _: HKWorkoutActivityType
    ) -> ActivitySessionDetailSnapshot? {
        guard let cached = details[workoutID] else { return nil }
        return cached
    }

    /// Monotonic merge: never drop a richer HR/route/metrics entry.
    static func store(_ detail: ActivitySessionDetailSnapshot, for workoutID: UUID) {
        if let existing = details[workoutID] {
            details[workoutID] = detail.mergingCached(existing)
        } else {
            details[workoutID] = detail
        }

        if let stored = details[workoutID] {
            if !stored.heartRateSamples.isEmpty {
                heartRateResolvedIDs.insert(workoutID)
            }
            if stored.routePoints.count > 1 {
                routeResolvedIDs.insert(workoutID)
            }
        }
    }

    static func markHeartRateResolved(_ workoutID: UUID) {
        heartRateResolvedIDs.insert(workoutID)
    }

    static func markRouteResolved(_ workoutID: UUID) {
        routeResolvedIDs.insert(workoutID)
    }

    static func heartRateIsResolved(_ workoutID: UUID) -> Bool {
        heartRateResolvedIDs.contains(workoutID)
    }

    static func routeIsResolved(_ workoutID: UUID) -> Bool {
        routeResolvedIDs.contains(workoutID)
    }

    static func needsPrefetch(
        for workoutID: UUID,
        activityType: HKWorkoutActivityType
    ) -> Bool {
        let cached = details[workoutID]
        let needsHeartRate = (cached?.heartRateSamples.isEmpty ?? true)
            && !heartRateResolvedIDs.contains(workoutID)

        let needsRoute = ActivityRouteExpectation.expectsRoute(for: activityType)
            && (cached?.routePoints.count ?? 0) <= 1
            && !routeResolvedIDs.contains(workoutID)

        return needsHeartRate || needsRoute
    }
}

/// Warms `ActivitySessionDetailCache` for a day's sessions so opening a workout
/// can show heart rate / route without waiting on HealthKit.
@MainActor
enum ActivitySessionDetailPrefetcher {
    private static let maxConcurrentPrefetches = 2

    static func prefetch(
        sessions: [ActivitySessionSnapshot],
        healthManager: HealthManager
    ) async {
        guard !healthManager.isAppReviewDemoActive else { return }

        // Newest first — users usually open the latest session of the day.
        let candidates: [(workoutID: UUID, detail: ActivitySessionDetailSnapshot)] = sessions
            .sorted { $0.startDate > $1.startDate }
            .compactMap { session in
                guard let workoutID = session.workoutID,
                      let detail = session.detail,
                      ActivitySessionDetailCache.needsPrefetch(
                        for: workoutID,
                        activityType: detail.activityType
                      )
                else {
                    return nil
                }

                return (workoutID, detail)
            }

        guard !candidates.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            var iterator = candidates.makeIterator()
            let initialCount = min(maxConcurrentPrefetches, candidates.count)

            for _ in 0..<initialCount {
                guard let next = iterator.next() else { break }
                group.addTask {
                    await prefetchSession(
                        workoutID: next.workoutID,
                        base: next.detail,
                        healthManager: healthManager
                    )
                }
            }

            while await group.next() != nil {
                guard !Task.isCancelled else {
                    group.cancelAll()
                    break
                }

                guard let next = iterator.next() else { continue }
                group.addTask {
                    await prefetchSession(
                        workoutID: next.workoutID,
                        base: next.detail,
                        healthManager: healthManager
                    )
                }
            }
        }
    }

    private static func prefetchSession(
        workoutID: UUID,
        base: ActivitySessionDetailSnapshot,
        healthManager: HealthManager
    ) async {
        guard !Task.isCancelled else { return }

        let cached = ActivitySessionDetailCache.detail(
            for: workoutID,
            activityType: base.activityType
        )
        let current = cached ?? base

        let expectsRoute = ActivityRouteExpectation.expectsRoute(for: base.activityType)
        let needsHeartRateLoad = current.heartRateSamples.isEmpty
            && !ActivitySessionDetailCache.heartRateIsResolved(workoutID)
        let needsRouteLoad = expectsRoute
            && current.routePoints.count <= 1
            && !ActivitySessionDetailCache.routeIsResolved(workoutID)

        guard needsHeartRateLoad || needsRouteLoad else { return }

        async let heartRate = loadHeartRateIfNeeded(
            needsHeartRate: needsHeartRateLoad,
            workoutID: workoutID,
            base: base,
            healthManager: healthManager
        )
        // Query only — never prompt for route authorization during prefetch.
        async let route = loadRouteIfNeeded(
            needsRoute: needsRouteLoad,
            workoutID: workoutID,
            base: base,
            healthManager: healthManager
        )

        let loadedHeartRate = await heartRate
        if needsHeartRateLoad {
            guard !Task.isCancelled else { return }
            if let loadedHeartRate,
               !loadedHeartRate.heartRateSamples.isEmpty || loadedHeartRate.averageHeartRate != nil {
                let baseForMerge = ActivitySessionDetailCache.detail(
                    for: workoutID,
                    activityType: base.activityType
                ) ?? current
                ActivitySessionDetailCache.store(baseForMerge.merging(loadedHeartRate), for: workoutID)
            }
            ActivitySessionDetailCache.markHeartRateResolved(workoutID)
        }

        let loadedRoute = await route
        if needsRouteLoad {
            guard !Task.isCancelled else { return }
            if let loadedRoute, loadedRoute.routePoints.count > 1 {
                let baseForMerge = ActivitySessionDetailCache.detail(
                    for: workoutID,
                    activityType: base.activityType
                ) ?? current
                ActivitySessionDetailCache.store(baseForMerge.merging(loadedRoute), for: workoutID)
                // Only mark resolved when we actually have a route. Empty during
                // prefetch may just mean route auth has not been granted yet.
                ActivitySessionDetailCache.markRouteResolved(workoutID)
            }
        }
    }

    private static func loadHeartRateIfNeeded(
        needsHeartRate: Bool,
        workoutID: UUID,
        base: ActivitySessionDetailSnapshot,
        healthManager: HealthManager
    ) async -> WorkoutHealthDetailSnapshot? {
        guard needsHeartRate else { return nil }
        return await healthManager.loadWorkoutHeartRateDetails(
            for: workoutID,
            start: base.startDate,
            end: base.endDate
        )
    }

    private static func loadRouteIfNeeded(
        needsRoute: Bool,
        workoutID: UUID,
        base: ActivitySessionDetailSnapshot,
        healthManager: HealthManager
    ) async -> WorkoutHealthDetailSnapshot? {
        guard needsRoute else { return nil }
        return await healthManager.loadWorkoutRouteDetails(
            for: workoutID,
            start: base.startDate,
            end: base.endDate
        )
    }
}

private struct HeartRateZoneSummary: Identifiable {
    var id: String { title }

    let title: String
    let range: String
    let color: Color
    let seconds: TimeInterval
    let percentage: Int

    var minutes: Int {
        Int((seconds / 60.0).rounded(.towardZero))
    }

    var durationLabel: String {
        WorkoutHeartRateAnalytics.durationLabel(seconds: seconds)
    }
}

private struct HeartRateZoneLegendRow: View {
    let zone: HeartRateZoneSummary
    let maxSeconds: TimeInterval

    private var isActive: Bool {
        zone.seconds >= 0.5 || zone.percentage > 0
    }

    private var barFraction: CGFloat {
        guard maxSeconds > 0 else { return 0 }
        return CGFloat(min(max(zone.seconds / maxSeconds, 0), 1))
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(WeekFitLocalizedString(zone.title))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(zone.color)
                .lineLimit(1)
                .frame(width: 58, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WeekFitTheme.whiteOpacity(0.08))

                    Capsule()
                        .fill(zone.color.opacity(isActive ? 1 : 0.22))
                        .frame(width: max(proxy.size.width * barFraction, isActive ? 4 : 0))
                }
            }
            .frame(height: 10)

            Text(zone.durationLabel)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(isActive ? 0.92 : 0.42))
                .monospacedDigit()
                .frame(width: 58, alignment: .trailing)

            Text(zone.range)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(isActive ? 0.48 : 0.30))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(width: 92, alignment: .trailing)
        }
        .frame(height: 22)
    }
}

private struct HeartRateChartPoint: Identifiable {
    var id: Date { timestamp }

    let timestamp: Date
    let minute: Double
    let beatsPerMinute: Double
}

private struct HeartRateLineSegment: Identifiable {
    let id = UUID()
    let zone: HeartRateZoneDefinition
    let points: [HeartRateChartPoint]
}

private struct SessionDetailSkeletonLine: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let midY = size.height * 0.54
            let width = max(size.width - 24, 1)
            let startX: CGFloat = 12

            path.move(to: CGPoint(x: startX, y: midY))

            for step in 0...8 {
                let x = startX + width * CGFloat(step) / 8
                let y = midY + (step.isMultiple(of: 2) ? -10 : 10)
                path.addLine(to: CGPoint(x: x, y: y))
            }

            context.stroke(
                path,
                with: .color(color.opacity(0.30)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(WeekFitTheme.whiteOpacity(0.018))
        }
    }
}

private func downsampleHeartRateSamples(
    _ samples: [WorkoutHeartRateSample],
    maximumCount: Int
) -> [WorkoutHeartRateSample] {
    guard samples.count > maximumCount, maximumCount > 1 else {
        return samples
    }

    let stride = Double(samples.count - 1) / Double(maximumCount - 1)

    return (0..<maximumCount).map { index in
        let sourceIndex = min(Int((Double(index) * stride).rounded()), samples.count - 1)
        return samples[sourceIndex]
    }
}

private struct SessionMetricItem: Identifiable {
    var id: String { title }

    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
}

private struct SessionMetricGridCell: View {
    let item: SessionMetricItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.color)
                    .frame(width: 14)
                    .padding(.top, 1)

                Text(WeekFitLocalizedString(item.title))
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(item.value)
                    .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                if !item.unit.isEmpty {
                    Text(item.unit)
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
                        .lineLimit(1)
                }
            }
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
    }
}

private struct ZoneDonutView: View {
    let zones: [HeartRateZoneSummary]

    private var totalMinutes: Int {
        max(zones.map(\.minutes).reduce(0, +), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(WeekFitTheme.whiteOpacity(0.07), lineWidth: 12)

            ForEach(donutSegments) { segment in
                Circle()
                    .trim(from: segment.start, to: segment.end)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: -1) {
                Text("\(totalMinutes)")
                    .font(.system(size: ActivityTypography.heroTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .monospacedDigit()

                Text(WeekFitLocalizedString("activity.min"))
                    .font(.system(size: ActivityTypography.helperText, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.48))
            }
        }
    }

    private var donutSegments: [DonutSegment] {
        var start: CGFloat = 0

        return zones.map { zone in
            let fraction = CGFloat(zone.minutes) / CGFloat(totalMinutes)
            let segment = DonutSegment(
                id: zone.id,
                start: start,
                end: start + fraction,
                color: zone.color
            )
            start += fraction
            return segment
        }
    }
}

private struct DonutSegment: Identifiable {
    let id: String
    let start: CGFloat
    let end: CGFloat
    let color: Color
}

private enum WorkoutRouteGeometry {
    static func coordinates(from points: [WorkoutRoutePoint]) -> [CLLocationCoordinate2D] {
        points.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    static func downsampledCoordinates(
        from points: [WorkoutRoutePoint],
        maximumCount: Int
    ) -> [CLLocationCoordinate2D] {
        guard points.count > maximumCount, maximumCount > 1 else {
            return coordinates(from: points)
        }

        let stride = Double(points.count - 1) / Double(maximumCount - 1)

        return (0..<maximumCount).map { index in
            let sourceIndex = min(Int((Double(index) * stride).rounded()), points.count - 1)
            let point = points[sourceIndex]
            return CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        }
    }

    static func mapRegion(
        for points: [WorkoutRoutePoint],
        paddingFactor: Double = 1.22
    ) -> MKCoordinateRegion? {
        guard
            let minLatitude = points.map(\.latitude).min(),
            let maxLatitude = points.map(\.latitude).max(),
            let minLongitude = points.map(\.longitude).min(),
            let maxLongitude = points.map(\.longitude).max()
        else {
            return nil
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let latitudeDelta = max((maxLatitude - minLatitude) * paddingFactor, 0.0025)
        let longitudeDelta = max((maxLongitude - minLongitude) * paddingFactor, 0.0025)

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    static func distance(from start: WorkoutRoutePoint, to end: WorkoutRoutePoint) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLocation.distance(from: endLocation)
    }
}

private struct WorkoutRouteMapPreview: View {
    let points: [WorkoutRoutePoint]
    let color: Color

    @Environment(\.weekFitPalette) private var palette
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isMapVisible = false

    private var coordinates: [CLLocationCoordinate2D] {
        WorkoutRouteGeometry.downsampledCoordinates(from: points, maximumCount: 260)
    }

    private var mapRegion: MKCoordinateRegion? {
        WorkoutRouteGeometry.mapRegion(for: points, paddingFactor: 1.18)
    }

    var body: some View {
        GeometryReader { proxy in
            let layoutReady = proxy.size.width > 2 && proxy.size.height > 2

            ZStack {
                ActivityStyle.cardBackground

                if layoutReady, isMapVisible, let mapRegion {
                    Map(position: $cameraPosition, interactionModes: []) {
                        routeContent
                    }
                    .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                    .colorScheme(palette.isLight ? .light : .dark)
                    .transition(.opacity.animation(.easeOut(duration: 0.22)))
                }

                LinearGradient(
                    colors: palette.isLight
                        ? [
                            Color.black.opacity(0.10),
                            Color.clear,
                            Color.black.opacity(0.08)
                        ]
                        : [
                            Color.black.opacity(0.34),
                            Color.clear,
                            Color.black.opacity(0.28)
                        ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(
                                palette.isLight
                                    ? WeekFitTheme.primaryText.opacity(0.86)
                                    : WeekFitTheme.whiteOpacity(0.92)
                            )
                            .padding(7)
                            .background {
                                Circle()
                                    .fill(
                                        palette.isLight
                                            ? Color.white.opacity(0.88)
                                            : Color.black.opacity(0.52)
                                    )
                                    .overlay {
                                        Circle()
                                            .stroke(
                                                palette.isLight
                                                    ? WeekFitLightTokens.divider.opacity(0.55)
                                                    : WeekFitTheme.whiteOpacity(0.16),
                                                lineWidth: 1
                                            )
                                    }
                            }
                            .padding(8)
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear {
                // Defer until the next layout pass so MapKit never mounts at size 0.
                DispatchQueue.main.async {
                    scheduleMapReveal(layoutReady: proxy.size.width > 2 && proxy.size.height > 2)
                }
            }
            .onChange(of: proxy.size) { _, newSize in
                let ready = newSize.width > 2 && newSize.height > 2
                if ready {
                    DispatchQueue.main.async {
                        scheduleMapReveal(layoutReady: true)
                    }
                } else {
                    isMapVisible = false
                }
            }
            .onDisappear {
                isMapVisible = false
            }
        }
        .onAppear {
            updateCameraPosition()
        }
        .onChange(of: points.count) { _, _ in
            updateCameraPosition()
            if points.count > 1 {
                DispatchQueue.main.async {
                    scheduleMapReveal(layoutReady: true)
                }
            }
        }
    }

    private func scheduleMapReveal(layoutReady: Bool) {
        guard layoutReady, mapRegion != nil else {
            return
        }

        updateCameraPosition()

        // Keep placeholder visible briefly, then fade map in once Metal has a valid size.
        if !isMapVisible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                isMapVisible = true
            }
        }
    }

    private func updateCameraPosition() {
        if let mapRegion {
            cameraPosition = .region(mapRegion)
        }
    }

    @MapContentBuilder
    private var routeContent: some MapContent {
        MapPolyline(coordinates: coordinates)
            .stroke(
                LinearGradient(
                    colors: [color.opacity(0.92), color, ActivityStyle.teal.opacity(0.95)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )

        if let start = coordinates.first {
            Annotation("", coordinate: start, anchor: .center) {
                Circle()
                    .fill(color)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .stroke(WeekFitTheme.whiteOpacity(0.92), lineWidth: 2)
                    }
            }
        }

        if let finish = coordinates.last, coordinates.count > 1 {
            Annotation("", coordinate: finish, anchor: .center) {
                Circle()
                    .stroke(WeekFitTheme.whiteOpacity(0.95), lineWidth: 2)
                    .background(Circle().fill(color.opacity(0.35)))
                    .frame(width: 11, height: 11)
            }
        }
    }
}

private struct WorkoutRouteDetailMapView: View {
    let points: [WorkoutRoutePoint]
    let color: Color
    let title: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var canRenderMap = false
    @State private var isDismissing = false

    private var coordinates: [CLLocationCoordinate2D] {
        WorkoutRouteGeometry.coordinates(from: points)
    }

    var body: some View {
        GeometryReader { proxy in
            let layoutReady = proxy.size.width > 2 && proxy.size.height > 2

            ZStack {
                ActivityStyle.screenBackground
                    .ignoresSafeArea()

                if layoutReady, canRenderMap, !isDismissing {
                    Map(position: $cameraPosition) {
                        routeContent
                    }
                    .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                        MapUserLocationButton()
                    }
                    .colorScheme(palette.isLight ? .light : .dark)
                    .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    header
                    Spacer()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .onAppear {
                if let region = WorkoutRouteGeometry.mapRegion(for: points) {
                    cameraPosition = .region(region)
                }

                guard layoutReady else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    canRenderMap = true
                }
            }
            .onChange(of: proxy.size) { _, newSize in
                let ready = newSize.width > 2 && newSize.height > 2
                if ready, !canRenderMap, !isDismissing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        canRenderMap = true
                    }
                }
            }
        }
        .onChange(of: points.count) { _, _ in
            if let region = WorkoutRouteGeometry.mapRegion(for: points) {
                cameraPosition = .region(region)
            }
        }
        .onDisappear {
            isDismissing = true
            canRenderMap = false
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WeekFitLocalizedString("activity.details.route.title"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            WeekFitCloseButton(size: .large) {
                closeRouteMap()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background {
            LinearGradient(
                colors: [
                    ActivityStyle.screenBackground.opacity(0.96),
                    ActivityStyle.screenBackground.opacity(0.72),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private func closeRouteMap() {
        isDismissing = true
        canRenderMap = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
        }
    }

    @MapContentBuilder
    private var routeContent: some MapContent {
        MapPolyline(coordinates: coordinates)
            .stroke(
                LinearGradient(
                    colors: [color.opacity(0.95), color, ActivityStyle.teal],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )

        if let start = coordinates.first {
            Annotation("", coordinate: start, anchor: .center) {
                RouteEndpointMarker(color: color, style: .start)
            }
        }

        if let finish = coordinates.last, coordinates.count > 1 {
            Annotation("", coordinate: finish, anchor: .center) {
                RouteEndpointMarker(color: color, style: .finish)
            }
        }
    }
}

private struct RouteEndpointMarker: View {
    enum Style {
        case start
        case finish
    }

    let color: Color
    let style: Style

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(style == .start ? 1 : 0.28))
                .frame(width: style == .start ? 14 : 16, height: style == .start ? 14 : 16)

            Circle()
                .stroke(WeekFitTheme.whiteOpacity(0.95), lineWidth: 2)
                .frame(width: style == .start ? 14 : 16, height: style == .start ? 14 : 16)

            if style == .finish {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
        }
        .shadow(color: color.opacity(0.35), radius: 6, y: 2)
    }
}

private struct EmptySessionsRow: View {
    var body: some View {
        HStack(spacing: 11) {
            CircleIcon(systemName: "figure.walk", color: ActivityStyle.activityColor, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(WeekFitLocalizedString("activity.noWorkoutsRecorded"))
                    .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))

                Text(WeekFitLocalizedString("activity.activityTotalsAreShownFromAppleHealth"))
                    .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.46))
            }

            Spacer()
        }
        .padding(12)
        .innerActivityCard(cornerRadius: 15)
    }
}

// MARK: - Shared UI

private struct CircleIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: size, height: size)

            Image(systemName: systemName)
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(color.opacity(0.95))
        }
    }
}

private struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HealthDetailsSectionTitle(text: text)
    }
}

// MARK: - Style

private enum ActivityTypography {
    static let sectionLabel: CGFloat = 11

    static let heroTitle: CGFloat = 20
    static let heroText: CGFloat = 12
    static let heroScore: CGFloat = 26
    static let heroScoreLabel: CGFloat = 9

    static let metricTitle: CGFloat = 12
    static let metricValue: CGFloat = 14
    static let metricSecondary: CGFloat = 12
    static let helperText: CGFloat = 11.5
}

private enum ActivityStyle {
    static var screenBackground: Color { WeekFitTheme.appScreenBackground }
    static var cardBackground: Color { WeekFitTheme.cardSurface }
    static var innerCardBackground: Color { WeekFitTheme.cardTertiary }
    static var border: Color { WeekFitTheme.border }

    static var activityColor: Color { WeekFitTheme.accent(Color(red: 0.16, green: 0.80, blue: 0.43)) }
    static var green: Color { WeekFitTheme.accent(Color(red: 0.45, green: 0.78, blue: 0.45)) }
    static var teal: Color { WeekFitTheme.accent(Color(red: 0.25, green: 0.78, blue: 0.82)) }
    static var blue: Color { WeekFitTheme.accent(Color(red: 0.30, green: 0.72, blue: 0.95)) }
    static var purple: Color { WeekFitTheme.accent(Color(red: 0.58, green: 0.40, blue: 0.95)) }
    static var yellow: Color { WeekFitTheme.accent(Color(red: 0.96, green: 0.86, blue: 0.20)) }
    static var orange: Color { WeekFitTheme.accent(Color(red: 0.96, green: 0.54, blue: 0.16)) }
    static var amber: Color { WeekFitTheme.accent(Color(red: 0.92, green: 0.68, blue: 0.30)) }
    static var red: Color { WeekFitTheme.accent(Color(red: 0.96, green: 0.42, blue: 0.42)) }
}

private enum DurationFormatter {
    static func compact(_ minutes: Int) -> String {
        guard minutes >= 90 else {
            return String(format: WeekFitLocalizedString("common.unit.minuteCompactFormat"), minutes)
        }

        let hours = minutes / 60
        let remainder = minutes % 60

        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    static func fullMinutes(_ minutes: Int) -> String {
        String(format: WeekFitLocalizedString("common.unit.minuteFormat"), minutes)
    }
}

private enum MetricFormatter {
    static func compactDashboardDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60.0).rounded()))

        guard minutes >= 60 else {
            return "\(minutes)\(compactMinuteUnit)"
        }

        return String(format: "%.1f%@", Double(minutes) / 60.0, compactHourUnit)
    }

    private static var compactMinuteUnit: String {
        WeekFitUsesRussianLanguage() ? "м" : "m"
    }

    private static var compactHourUnit: String {
        WeekFitUsesRussianLanguage() ? "ч" : "h"
    }

    static func compactSteps(_ steps: Int) -> String {
        if steps >= 1_000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }

        return "\(steps)"
    }

    static func distance(_ kilometers: Double, system: WeekFitResolvedUnitSystem) -> String {
        WeekFitUnitPolicy.formatDistance(kilometers: kilometers, system: system)
    }

    static func compactDistance(_ kilometers: Double, system: WeekFitResolvedUnitSystem) -> String {
        WeekFitUnitPolicy.formatCompactDistance(kilometers: kilometers, system: system)
    }

    static func heartRate(_ beatsPerMinute: Double) -> String {
        String(format: WeekFitLocalizedString("common.unit.bpmValueFormat"), Int(beatsPerMinute.rounded()))
    }

    static func pace(_ minutesPerKilometer: Double, system: WeekFitResolvedUnitSystem) -> String {
        WeekFitUnitPolicy.formatPace(minutesPerKilometer: minutesPerKilometer, system: system)
    }

    static func speed(_ kilometersPerHour: Double, system: WeekFitResolvedUnitSystem) -> String {
        WeekFitUnitPolicy.formatSpeed(kilometersPerHour: kilometersPerHour, system: system)
    }

    static func compactSpeed(_ kilometersPerHour: Double, system: WeekFitResolvedUnitSystem) -> String {
        WeekFitUnitPolicy.formatCompactSpeed(kilometersPerHour: kilometersPerHour, system: system)
    }

    static func compactPace(_ minutesPerKilometer: Double, system: WeekFitResolvedUnitSystem) -> String {
        let minutesPerUnit: Double
        switch system {
        case .metric:
            minutesPerUnit = minutesPerKilometer
        case .uk, .us:
            minutesPerUnit = minutesPerKilometer * 1.60934
        }

        let totalSeconds = Int((minutesPerUnit * 60).rounded())
        return String(format: "%d'%02d\"", totalSeconds / 60, totalSeconds % 60)
    }

    static func elevation(_ meters: Double, system: WeekFitResolvedUnitSystem) -> String {
        WeekFitUnitPolicy.formatElevation(meters: meters, system: system)
    }

    static func compactElevation(_ meters: Double, system: WeekFitResolvedUnitSystem) -> String {
        WeekFitUnitPolicy.formatCompactElevation(meters: meters, system: system)
    }
}

private extension ActivitySessionSnapshot {
    var endDate: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startDate) ?? startDate
    }

    var timeRange: String {
        let start = startDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        let end = endDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return "\(start) – \(end)"
    }
}

private extension View {
    func activityCard(
        cornerRadius: CGFloat = 22,
        glow: Color = .clear
    ) -> some View {
        modifier(ActivityCardChrome(cornerRadius: cornerRadius, glow: glow))
    }

    func innerActivityCard(cornerRadius: CGFloat) -> some View {
        modifier(ActivityInnerCardChrome(cornerRadius: cornerRadius))
    }
}

private struct ActivityCardChrome: ViewModifier {
    @Environment(\.weekFitPalette) private var palette
    var cornerRadius: CGFloat
    var glow: Color

    func body(content: Content) -> some View {
        content.healthDetailsSoftCard(
            isLight: palette.isLight,
            cornerRadius: palette.isLight ? NutritionDetailsDesign.largeCorner : cornerRadius,
            darkGlow: glow
        )
    }
}

private struct ActivityInnerCardChrome: ViewModifier {
    @Environment(\.weekFitPalette) private var palette
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if palette.isLight {
            content.healthDetailsNestedTile(isLight: true, cornerRadius: cornerRadius)
        } else {
            content.weekFitPremiumCard(
                emphasis: .compact,
                accent: nil,
                cornerRadius: cornerRadius
            )
        }
    }
}
