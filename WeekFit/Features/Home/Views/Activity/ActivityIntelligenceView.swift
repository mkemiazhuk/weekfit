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

    var shouldShowElapsedTime: Bool {
        elapsedDurationSeconds > workoutDurationSeconds + 60
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
    @EnvironmentObject private var languageManager: AppLanguageManager

    private var snapshot: ActivityDaySnapshot {
        viewModel.selectedSnapshot
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack {
            ActivityStyle.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 9) {
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
                    .padding(.horizontal, 18)
                    .padding(.top, 5)
                    .padding(.bottom, 36)
                }
            }

            if viewModel.isLoading && viewModel.weekSnapshots.isEmpty {
                ProgressView()
                    .tint(.white.opacity(0.75))
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
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
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(activityDetailsDateTitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.56))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(WeekFitTheme.whiteOpacity(0.075)))
                    .overlay {
                        Circle().stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppText.Common.Action.close))
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

    private var progress: CGFloat {
        CGFloat(min(max(snapshot.activityPercent, 0), 100)) / 100
    }

    var body: some View {
        HStack(spacing: 15) {
            activityRing

            VStack(alignment: .leading, spacing: 5) {
                Text(WeekFitLocalizedString("activity.activityScore"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(ActivityStyle.activityColor)

                Text(WeekFitLocalizedString(statusText))
                    .font(.system(size: ActivityTypography.heroTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(WeekFitLocalizedString(insightText))
                    .font(.system(size: ActivityTypography.heroText, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
        .activityCard(glow: ActivityStyle.activityColor.opacity(0.08))
    }

    private var activityRing: some View {
        WeekFitProgressRing(
            progress: progress,
            color: WeekFitProgressRingColor.activity,
            size: 70,
            strokeWidth: 4,
            gradientColors: [
                WeekFitProgressRingColor.activity.opacity(0.80),
                WeekFitProgressRingColor.activity,
                Color(red: 0.36, green: 0.90, blue: 0.38),
                Color(red: 0.22, green: 0.84, blue: 0.88).opacity(0.94)
            ]
        ) {
            VStack(spacing: -2) {
                Text("\(snapshot.activityPercent)")
                    .font(.system(size: ActivityTypography.heroScore, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text("activity.score")
                    .font(.system(size: ActivityTypography.heroScoreLabel, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.40))
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
        .activityCard(glow: ActivityStyle.activityColor.opacity(0.035))
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
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(WeekFitTheme.whiteOpacity(0.026))
        }
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
        .activityCard(glow: ActivityStyle.activityColor.opacity(0.045))
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

        guard weekAverage > 0 else { return .white.opacity(0.46) }

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
                        color: .white.opacity(0.44),
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
        .activityCard(glow: ActivityStyle.activityColor.opacity(0.035))
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
                            .foregroundStyle(item.isSelected ? ActivityStyle.activityColor.opacity(0.95) : .white.opacity(0.42))
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
                            .foregroundStyle(item.isSelected ? ActivityStyle.activityColor.opacity(0.95) : .white.opacity(0.42))
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
        let colors: [Color] = item.isSelected
        ? [ActivityStyle.activityColor, ActivityStyle.teal.opacity(0.75)]
        : [WeekFitTheme.whiteOpacity(0.38), WeekFitTheme.whiteOpacity(0.18)]

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

struct ActivitySessionDetailView: View {
    let session: ActivitySessionSnapshot
    @ObservedObject var healthManager: HealthManager

    @Environment(\.dismiss) private var dismiss
    @State private var loadedDetail: ActivitySessionDetailSnapshot?
    @State private var isHeartRateLoading = false
    @State private var isRouteLoading = false
    @State private var isRouteMapPresented = false
    @State private var isRoutePreviewEnabled = true
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

    private var routeMapRenderIdentity: String {
        guard let first = routePoints.first, let last = routePoints.last else {
            return "route-empty"
        }

        return "route-\(routePoints.count)-\(first.latitude)-\(first.longitude)-\(last.latitude)-\(last.longitude)"
    }

    private var sessionDurationSeconds: TimeInterval {
        detail?.workoutDurationSeconds ?? Double(session.durationMinutes * 60)
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

    private var heartRateZoneDefinitions: [HeartRateZoneDefinition] {
        [
            HeartRateZoneDefinition(
                title: WeekFitLocalizedString("activity.heartRate.zone1"),
                lowerBound: 40,
                upperBound: 120,
                color: ActivityStyle.blue
            ),
            HeartRateZoneDefinition(
                title: WeekFitLocalizedString("activity.heartRate.zone2"),
                lowerBound: 120,
                upperBound: 140,
                color: ActivityStyle.green
            ),
            HeartRateZoneDefinition(
                title: WeekFitLocalizedString("activity.heartRate.zone3"),
                lowerBound: 140,
                upperBound: 160,
                color: ActivityStyle.yellow
            ),
            HeartRateZoneDefinition(
                title: WeekFitLocalizedString("activity.heartRate.zone4"),
                lowerBound: 160,
                upperBound: 180,
                color: ActivityStyle.orange
            ),
            HeartRateZoneDefinition(
                title: WeekFitLocalizedString("activity.heartRate.zone5"),
                lowerBound: 180,
                upperBound: 220,
                color: ActivityStyle.red
            )
        ]
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
                    metricsCard

                    if isHeartRateLoading || !heartRateSamples.isEmpty {
                        heartRateCard
                    }

                    if isRouteLoading || routePoints.count > 1 {
                        routeCard
                    }

                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $isRouteMapPresented) {
            WorkoutRouteDetailMapView(
                points: routePoints,
                color: session.color,
                title: session.title
            )
        }
        .onDisappear {
            isRouteMapPresented = false
            isRoutePreviewEnabled = false
        }
        .task(id: session.id) {
            await loadSupplementalDetails()
        }
    }

    private var closeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            closeDetail()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                .frame(width: 36, height: 36)
                .background(Circle().fill(WeekFitTheme.whiteOpacity(0.075)))
                .overlay {
                    Circle().stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppText.Common.Action.close))
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
                        .foregroundStyle(.white)
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
                    Image(systemName: "applewatch")
                        .font(.system(size: 11, weight: .bold))

                    Text(syncedText)
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

    private var activityDateText: String {
        localizedDetailsDate(session.startDate)
    }

    private var syncedText: String {
        let source = detail?.source ?? WeekFitLocalizedString("activity.data.source.appleHealth")
        return String(format: WeekFitLocalizedString("activity.syncedFrom"), source)
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
        .activityCard(glow: session.color.opacity(0.035))
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
            }

            VStack(spacing: 7) {
                ForEach(heartRateZones) { zone in
                    HeartRateZoneLegendRow(zone: zone)
                }
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .activityCard(glow: ActivityStyle.red.opacity(0.035))
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
                } else if isRoutePreviewEnabled {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        isRouteMapPresented = true
                    } label: {
                        WorkoutRouteMapPreview(points: routePoints, color: session.color)
                            .id(routeMapRenderIdentity)
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
                            value: MetricFormatter.elevation(elevationGain),
                            icon: "mountain.2.fill",
                            color: ActivityStyle.amber
                        )
                    }

                    if let distanceKm = detail?.distanceKm {
                        routeMetric(
                            title: "activity.metric.distance",
                            value: MetricFormatter.distance(distanceKm),
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
        .activityCard(glow: session.color.opacity(0.035))
    }

    private var timeInZonesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionLabel("activity.timeInZones")

            HStack(spacing: 14) {
                ZoneDonutView(zones: heartRateZones)
                    .frame(width: 96, height: 96)

                VStack(spacing: 7) {
                    ForEach(heartRateZones) { zone in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(zone.color)
                                .frame(width: 8, height: 8)

                            Text(zone.title)
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
        .activityCard(glow: ActivityStyle.red.opacity(0.025))
    }

    private var footer: some View {
        Text(String(format: WeekFitLocalizedString("activity.dataFrom"), detail?.source ?? WeekFitLocalizedString("activity.data.source.appleHealth")))
            .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.38))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 3)
    }

    private var metricItems: [SessionMetricItem] {
        var items: [SessionMetricItem] = [
            SessionMetricItem(
                title: detail?.shouldShowElapsedTime == true
                    ? "activity.metric.workoutTime"
                    : "activity.metric.duration",
                value: MetricFormatter.compactDashboardDuration(sessionDurationSeconds),
                unit: "",
                icon: "clock",
                color: ActivityStyle.activityColor
            )
        ]

        if let detail, detail.shouldShowElapsedTime {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.elapsedTime",
                    value: MetricFormatter.compactDashboardDuration(detail.elapsedDurationSeconds),
                    unit: "",
                    icon: "timer",
                    color: ActivityStyle.teal
                )
            )
        }

        if let distanceKm = detail?.distanceKm {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.distance",
                    value: MetricFormatter.compactDistance(distanceKm),
                    unit: WeekFitLocalizedString("common.unit.kilometer"),
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

        if let speed = detail?.averageSpeedKmh {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.avgSpeed",
                    value: MetricFormatter.compactSpeed(speed),
                    unit: WeekFitLocalizedString("common.unit.kilometerPerHour"),
                    icon: "speedometer",
                    color: ActivityStyle.green
                )
            )
        }

        if let maxSpeedKmh {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.maxSpeed",
                    value: MetricFormatter.compactSpeed(maxSpeedKmh),
                    unit: WeekFitLocalizedString("common.unit.kilometerPerHour"),
                    icon: "speedometer",
                    color: ActivityStyle.green
                )
            )
        }

        if let elevationGain = detail?.elevationGain {
            items.append(
                SessionMetricItem(
                    title: "activity.metric.elevationGain",
                    value: "\(Int(elevationGain.rounded()))",
                    unit: WeekFitLocalizedString("common.unit.meter"),
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
        guard routePoints.count > 1 else { return nil }

        let speeds = zip(routePoints, routePoints.dropFirst()).compactMap { start, end -> Double? in
            let interval = end.timestamp.timeIntervalSince(start.timestamp)
            guard interval > 0, interval <= 120 else { return nil }

            let distance = WorkoutRouteGeometry.distance(from: start, to: end)
            let speed = distance / interval * 3.6
            return speed.isFinite && speed > 0 ? speed : nil
        }

        return speeds.max()
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
        let zoneSeconds = heartRateZoneDefinitions.map { definition in
            (definition, secondsInZone { definition.contains($0) })
        }
        let rawTotalSeconds = zoneSeconds.map(\.1).reduce(0, +)
        let scale = rawTotalSeconds > sessionDurationSeconds && rawTotalSeconds > 0
            ? sessionDurationSeconds / rawTotalSeconds
            : 1
        let durationForPercentage = max(sessionDurationSeconds, 1)

        return zoneSeconds.map { definition, seconds in
            let cappedSeconds = seconds * scale

            return HeartRateZoneSummary(
                title: definition.title,
                range: definition.range,
                color: definition.color,
                minutes: Int(cappedSeconds / 60.0),
                percentage: min(100, Int((cappedSeconds / durationForPercentage * 100.0).rounded()))
            )
        }
    }

    private func secondsInZone(_ contains: (Double) -> Bool) -> TimeInterval {
        guard heartRateSamples.count > 1 else { return 0 }

        let startDate = detail?.startDate ?? session.startDate
        let endDate = detail?.endDate ?? session.endDate

        return zip(heartRateSamples, heartRateSamples.dropFirst()).reduce(0.0) { total, pair in
            guard contains(pair.0.beatsPerMinute) else { return total }

            let intervalStart = max(pair.0.timestamp, startDate)
            let intervalEnd = min(pair.1.timestamp, endDate)
            let interval = intervalEnd.timeIntervalSince(intervalStart)

            return total + max(0, min(interval, 60))
        }
    }

    private func loadSupplementalDetails() async {
        guard let workoutID = session.workoutID else { return }

        let baseDetail = detail
        let activityType = baseDetail?.activityType ?? .other
        let start = baseDetail?.startDate ?? session.startDate
        let end = baseDetail?.endDate ?? session.endDate
        let expectsRoute = ActivityRouteExpectation.expectsRoute(for: activityType)

        if let cached = ActivitySessionDetailCache.detail(
            for: workoutID,
            activityType: activityType
        ) {
            loadedDetail = cached
            return
        }

        supplementalMetricsSettled = false
        routeLoadingSettled = !expectsRoute
        isHeartRateLoading = true
        isRouteLoading = expectsRoute
        remainingSupplementalLoads = 2

        Task {
            let metrics = await healthManager.loadWorkoutSupplementalMetrics(
                for: workoutID,
                start: start,
                end: end,
                activityType: activityType
            )

            await MainActor.run {
                if let metrics {
                    mergeSupplementalDetails(metrics)
                }

                finishMetricsSupplementalLoad(for: workoutID)
            }
        }

        Task {
            let heartRate = await healthManager.loadWorkoutHeartRateDetails(
                start: start,
                end: end
            )

            await MainActor.run {
                isHeartRateLoading = false

                if !heartRate.heartRateSamples.isEmpty {
                    mergeSupplementalDetails(heartRate)
                }

                finishMetricsSupplementalLoad(for: workoutID)
            }
        }

        if expectsRoute {
            Task {
                await loadRouteDetailsWithRetry(
                    workoutID: workoutID,
                    start: start,
                    end: end
                )
            }
        }
    }

    private func loadRouteDetailsWithRetry(
        workoutID: UUID,
        start: Date,
        end: Date
    ) async {
        let retryDelaysSeconds: [TimeInterval] = [0, 1.5, 3, 6, 10, 15]
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

            await MainActor.run {
                if let route, loadedRoute {
                    mergeSupplementalDetails(route)
                    isRoutePreviewEnabled = true
                }

                let isLastAttempt = attemptIndex == retryDelaysSeconds.count - 1
                if loadedRoute || isLastAttempt {
                    isRouteLoading = false
                    routeLoadingSettled = true
                    cacheDetailIfReady(for: workoutID)
                }
            }

            if loadedRoute {
                return
            }
        }
    }

    private func finishMetricsSupplementalLoad(for workoutID: UUID) {
        remainingSupplementalLoads = max(remainingSupplementalLoads - 1, 0)

        if remainingSupplementalLoads == 0 {
            supplementalMetricsSettled = true
            cacheDetailIfReady(for: workoutID)
        }
    }

    private func cacheDetailIfReady(for workoutID: UUID) {
        guard supplementalMetricsSettled, routeLoadingSettled, let loadedDetail else { return }
        ActivitySessionDetailCache.store(loadedDetail, for: workoutID)
    }

    private func mergeSupplementalDetails(_ supplemental: WorkoutHealthDetailSnapshot) {
        let base = detail

        loadedDetail = ActivitySessionDetailSnapshot(
            title: base?.title ?? session.title,
            activityType: base?.activityType ?? .other,
            startDate: base?.startDate ?? session.startDate,
            endDate: base?.endDate ?? session.endDate,
            durationMinutes: base?.durationMinutes ?? session.durationMinutes,
            workoutDurationSeconds: base?.workoutDurationSeconds ?? Double(session.durationMinutes * 60),
            elapsedDurationSeconds: base?.elapsedDurationSeconds ?? session.endDate.timeIntervalSince(session.startDate),
            source: supplemental.source ?? base?.source,
            icon: base?.icon ?? session.icon,
            color: base?.color ?? session.color,
            activeCalories: supplemental.activeCalories ?? base?.activeCalories,
            distanceKm: supplemental.distanceKm ?? base?.distanceKm,
            averageHeartRate: supplemental.averageHeartRate ?? base?.averageHeartRate,
            maxHeartRate: supplemental.maxHeartRate ?? base?.maxHeartRate,
            heartRateSamples: supplemental.heartRateSamples.isEmpty
                ? (base?.heartRateSamples ?? [])
                : supplemental.heartRateSamples,
            routePoints: supplemental.routePoints.isEmpty
                ? (base?.routePoints ?? [])
                : supplemental.routePoints,
            elevationGain: supplemental.elevationGain ?? base?.elevationGain,
            steps: supplemental.steps ?? base?.steps,
            cadence: supplemental.cadence ?? base?.cadence
        )

        if supplemental.routePoints.count > 1 {
            isRoutePreviewEnabled = true
        }
    }
}

private struct HeartRateZoneDefinition: Identifiable, Hashable {
    var id: String { title }

    let title: String
    let lowerBound: Double
    let upperBound: Double
    let color: Color

    var range: String {
        if lowerBound <= 40 {
            return String(format: WeekFitLocalizedString("common.unit.bpmLessThanFormat"), Int(upperBound))
        }

        if upperBound >= 220 {
            return String(format: WeekFitLocalizedString("common.unit.bpmPlusFormat"), Int(lowerBound))
        }

        return String(format: WeekFitLocalizedString("common.unit.bpmRangeFormat"), Int(lowerBound), Int(upperBound - 1))
    }

    func contains(_ beatsPerMinute: Double) -> Bool {
        beatsPerMinute >= lowerBound && beatsPerMinute < upperBound
    }
}

@MainActor
private enum ActivityRouteExpectation {
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
private enum ActivitySessionDetailCache {
    private static var details: [UUID: ActivitySessionDetailSnapshot] = [:]

    static func detail(
        for workoutID: UUID,
        activityType: HKWorkoutActivityType
    ) -> ActivitySessionDetailSnapshot? {
        guard let cached = details[workoutID] else { return nil }

        if ActivityRouteExpectation.expectsRoute(for: activityType),
           cached.routePoints.count <= 1 {
            return nil
        }

        return cached
    }

    static func store(_ detail: ActivitySessionDetailSnapshot, for workoutID: UUID) {
        details[workoutID] = detail
    }
}

private struct HeartRateZoneSummary: Identifiable {
    var id: String { title }

    let title: String
    let range: String
    let color: Color
    let minutes: Int
    let percentage: Int
}

private struct HeartRateZoneLegendRow: View {
    let zone: HeartRateZoneSummary

    private var isActive: Bool {
        zone.minutes > 0 || zone.percentage > 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(zone.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(WeekFitLocalizedString(zone.title))
                    .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(isActive ? 0.74 : 0.44))
                    .lineLimit(1)

                Text(zone.range)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(isActive ? 0.42 : 0.28))
                    .lineLimit(1)
            }
            .frame(width: 70, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(WeekFitTheme.whiteOpacity(0.055))

                    Capsule()
                        .fill(zone.color.opacity(isActive ? 0.95 : 0.20))
                        .frame(width: proxy.size.width * CGFloat(zone.percentage) / 100.0)
                }
            }
            .frame(height: 7)

            Text(String(format: WeekFitLocalizedString("common.unit.minuteFormat"), zone.minutes))
                .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(isActive ? 0.70 : 0.40))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 58, alignment: .trailing)
                .monospacedDigit()

            Text(String(format: WeekFitLocalizedString("activity.percentFormat"), zone.percentage))
                .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(isActive ? 0.48 : 0.34))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 34, alignment: .trailing)
                .monospacedDigit()
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
        VStack(alignment: .leading, spacing: 5) {
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
            .frame(minHeight: 26, alignment: .topLeading)

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
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text("activity.min")
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

private struct RouteMapRenderGate<Content: View>: View {

    @State private var canRender = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            if canRender, proxy.size.width > 2, proxy.size.height > 2 {
                content()
            } else {
                ActivityStyle.cardBackground
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                canRender = true
            }
        }
        .onDisappear {
            canRender = false
        }
    }
}

private struct WorkoutRouteMapPreview: View {
    let points: [WorkoutRoutePoint]
    let color: Color

    @State private var cameraPosition: MapCameraPosition = .automatic

    private var coordinates: [CLLocationCoordinate2D] {
        WorkoutRouteGeometry.downsampledCoordinates(from: points, maximumCount: 260)
    }

    private var mapRegion: MKCoordinateRegion? {
        WorkoutRouteGeometry.mapRegion(for: points, paddingFactor: 1.18)
    }

    var body: some View {
        ZStack {
            RouteMapRenderGate {
                if let mapRegion {
                    Map(position: $cameraPosition, interactionModes: []) {
                        routeContent
                    }
                    .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                    .colorScheme(.dark)
                } else {
                    ActivityStyle.cardBackground
                }
            }

            LinearGradient(
                colors: [
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
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                        .padding(7)
                        .background {
                            Circle()
                                .fill(.black.opacity(0.52))
                                .overlay {
                                    Circle()
                                        .stroke(WeekFitTheme.whiteOpacity(0.16), lineWidth: 1)
                                }
                        }
                        .padding(8)
                }
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            updateCameraPosition()
        }
        .onChange(of: points.count) { _, _ in
            updateCameraPosition()
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
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var canRenderMap = false
    @State private var isDismissing = false

    private var coordinates: [CLLocationCoordinate2D] {
        WorkoutRouteGeometry.coordinates(from: points)
    }

    var body: some View {
        ZStack {
            ActivityStyle.screenBackground
                .ignoresSafeArea()

            if canRenderMap, !isDismissing {
                Map(position: $cameraPosition) {
                    routeContent
                }
                .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                    MapUserLocationButton()
                }
                .colorScheme(.dark)
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                header
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let region = WorkoutRouteGeometry.mapRegion(for: points) {
                cameraPosition = .region(region)
            }

            DispatchQueue.main.async {
                canRenderMap = true
            }
        }
        .onChange(of: points.count) { _, _ in
            if let region = WorkoutRouteGeometry.mapRegion(for: points) {
                cameraPosition = .region(region)
            }
        }
        .onDisappear {
            canRenderMap = false
            isDismissing = false
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WeekFitLocalizedString("activity.details.route.title"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                closeRouteMap()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(WeekFitTheme.whiteOpacity(0.075)))
                    .overlay {
                        Circle().stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppText.Common.Action.close))
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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
                Text("activity.noWorkoutsRecorded")
                    .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))

                Text("activity.activityTotalsAreShownFromAppleHealth")
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
        Text(text)
            .font(.system(size: ActivityTypography.sectionLabel, weight: .bold, design: .rounded))
            .tracking(1.8)
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.68))
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
    static var screenBackground: Color { WeekFitTheme.backgroundColor }
    static var cardBackground: Color { Color(red: 0.045, green: 0.048, blue: 0.055) }
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
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? "м" : "m"
    }

    private static var compactHourUnit: String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? "ч" : "h"
    }

    static func compactSteps(_ steps: Int) -> String {
        if steps >= 1_000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }

        return "\(steps)"
    }

    static func distance(_ kilometers: Double) -> String {
        String(format: "%.2f km", kilometers)
    }

    static func compactDistance(_ kilometers: Double) -> String {
        String(format: kilometers >= 10 ? "%.1f" : "%.2f", kilometers)
    }

    static func heartRate(_ beatsPerMinute: Double) -> String {
        String(format: WeekFitLocalizedString("common.unit.bpmValueFormat"), Int(beatsPerMinute.rounded()))
    }

    static func pace(_ minutesPerKilometer: Double) -> String {
        let totalSeconds = Int((minutesPerKilometer * 60).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    static func speed(_ kilometersPerHour: Double) -> String {
        String(format: "%.1f km/h", kilometersPerHour)
    }

    static func compactSpeed(_ kilometersPerHour: Double) -> String {
        String(format: "%.1f", kilometersPerHour)
    }

    static func elevation(_ meters: Double) -> String {
        "\(Int(meters.rounded())) m"
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
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ActivityStyle.cardBackground)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WeekFitTheme.whiteOpacity(0.030),
                                WeekFitTheme.whiteOpacity(0.004)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if glow != .clear {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [glow, .clear],
                                center: .trailing,
                                startRadius: 12,
                                endRadius: 170
                            )
                        )
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(ActivityStyle.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
    }

    func innerActivityCard(cornerRadius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(ActivityStyle.innerCardBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
        }
    }
}
