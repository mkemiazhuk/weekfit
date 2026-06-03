import SwiftUI
import Charts
import HealthKit
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

struct ActivitySessionSnapshot: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let startDate: Date
    let durationMinutes: Int
    let icon: String
    let color: Color
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
        historicalSameWeekdayPoints: []
    )
}

struct ActivityIntelligenceView: View {

    let selectedDate: Date
    @ObservedObject var healthManager: HealthManager
    let plannedActivities: [PlannedActivity]

    @StateObject private var viewModel = ActivityIntelligenceViewModel()
    @Environment(\.dismiss) private var dismiss

    private var snapshot: ActivityDaySnapshot {
        viewModel.selectedSnapshot
    }

    var body: some View {
        ZStack {
            ActivityStyle.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ActivityDayPicker(
                    selectedDate: viewModel.selectedDate,
                    snapshots: viewModel.weekSnapshots
                ) { snapshot in
                    select(snapshot)
                }
                .padding(.horizontal, 18)
                .padding(.top, 9)
                .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 9) {
                        ActivityHeroCard(snapshot: snapshot)
                        ActivityTimelineCard(points: snapshot.hourlyActivityPoints)
                        WeeklyContextCard(
                            selectedSnapshot: snapshot,
                            weekSnapshots: viewModel.weekSnapshots
                        )
                        SessionsCard(sessions: snapshot.sessions)
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
        .task {
            await viewModel.load(
                selectedDate: selectedDate,
                healthManager: healthManager,
                plannedActivities: plannedActivities
            )
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.white.opacity(0.075)))
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Activity Details")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Text(viewModel.selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 11)
        .background {
            ActivityStyle.screenBackground.ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
        }
    }

    private func select(_ snapshot: ActivityDaySnapshot) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            await viewModel.select(
                snapshot,
                healthManager: healthManager,
                plannedActivities: plannedActivities
            )
        }
    }
}

// MARK: - Day Picker

private struct ActivityDayPicker: View {
    let selectedDate: Date
    let snapshots: [ActivityDaySnapshot]
    let onSelect: (ActivityDaySnapshot) -> Void

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 8) {
            ForEach(snapshots) { snapshot in
                dayCell(snapshot)
            }
        }
    }

    private func dayCell(_ snapshot: ActivityDaySnapshot) -> some View {
        let isSelected = calendar.isDate(snapshot.date, inSameDayAs: selectedDate)

        return Button {
            onSelect(snapshot)
        } label: {
            VStack(spacing: 6) {
                Text(snapshot.date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.40))

                Text(snapshot.date.formatted(.dateTime.day()))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .black : .white.opacity(0.68))
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(isSelected ? ActivityStyle.activityColor : Color.white.opacity(0.055))
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(isSelected ? ActivityStyle.activityColor.opacity(0.11) : Color.white.opacity(0.022))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isSelected ? ActivityStyle.activityColor.opacity(0.22) : Color.white.opacity(0.04), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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
                Text("ACTIVITY SCORE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(ActivityStyle.activityColor)

                Text(statusText)
                    .font(.system(size: ActivityTypography.heroTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(insightText)
                    .font(.system(size: ActivityTypography.heroText, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineSpacing(2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
        .activityCard(glow: ActivityStyle.activityColor.opacity(0.08))
    }

    private var activityRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.075), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            ActivityStyle.activityColor.opacity(0.60),
                            ActivityStyle.activityColor,
                            ActivityStyle.green,
                            ActivityStyle.teal.opacity(0.85)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: ActivityStyle.activityColor.opacity(0.15), radius: 4)

            VStack(spacing: -2) {
                Text("\(snapshot.activityPercent)")
                    .font(.system(size: ActivityTypography.heroScore, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text("score")
                    .font(.system(size: ActivityTypography.heroScoreLabel, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.40))
            }
        }
        .frame(width: 70, height: 70)
    }

    private var statusText: String {
        switch snapshot.activityPercent {
        case 100...:
            return "Target achieved"
        case 80..<100:
            return "Almost there"
        case 45..<80:
            return "Active day"
        case 20..<45:
            return "Lightly active"
        case 1..<20:
            return "Low activity"
        default:
            return "No activity yet"
        }
    }

    private var insightText: String {
        if snapshot.activityGoal <= 0 {
            return "Activity data is shown from Apple Health when available."
        }

        switch snapshot.activityPercent {
        case 100...:
            return "You reached today's movement target with \(snapshot.activeCalories.formatted()) active kcal."
        case 80..<100:
            return "You are close to your target. A short walk may complete the day."
        case 45..<80:
            return "Good movement volume today. Keep activity steady through the day."
        case 20..<45:
            return "\(snapshot.activeCalories.formatted()) active kcal completed so far. There is room to build."
        case 1..<20:
            return "Only \(snapshot.activityPercent)% of your daily movement target has been completed so far."
        default:
            return "No meaningful movement has been recorded yet today."
        }
    }
}

// MARK: - Timeline

private struct ActivityTimelineCard: View {
    let points: [ActivityTimelinePoint]

    private var maxCalories: Double {
        max(points.map(\.activeCalories).max() ?? 0, 1)
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
            SectionLabel("ACTIVITY TIMELINE")

            HStack(spacing: 10) {
                activityMetric(
                    title: "Peak",
                    value: peakText,
                    icon: "chart.bar.fill",
                    color: ActivityStyle.activityColor
                )

                activityMetric(
                    title: "Active kcal",
                    value: "\(peakCalories)",
                    icon: "flame.fill",
                    color: ActivityStyle.green
                )
            }

            Chart(points) { point in
                BarMark(
                    x: .value("Hour", point.hour),
                    y: .value("Calories", point.activeCalories),
                    width: .fixed(8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .foregroundStyle(barGradient(for: point.activeCalories))
            }
            .chartXAxis {
                AxisMarks(values: [0, 3, 6, 9, 12, 15, 18, 21]) { value in
                    AxisValueLabel {
                        if let hour = value.as(Int.self) {
                            Text(String(format: "%02d", hour))
                                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.045))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text("\(Int(number))")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.38))
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
                Text(title)
                    .font(.system(size: ActivityTypography.metricSecondary, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(1)

                Text(value)
                    .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func barGradient(for value: Double) -> LinearGradient {
        let ratio = value / maxCalories

        let colors: [Color]

        if value <= 0 {
            colors = [
                Color.white.opacity(0.04),
                Color.white.opacity(0.015)
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
                Color.white.opacity(0.05)
            ]
        }

        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
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
    
    private var isToday: Bool {
        Calendar.current.isDate(selectedSnapshot.date, inSameDayAs: Date())
    }

    private var isEarlyToday: Bool {
        isToday && Calendar.current.component(.hour, from: Date()) < 12
    }

    private var weekDeltaText: String {
        if isEarlyToday {
            return "Day is still early"
        }

        return deltaText(
            current: selectedSnapshot.activeCalories,
            baseline: weekAverage,
            label: "week average"
        )
    }
    
    private var typicalDeltaText: String? {
        if isEarlyToday {
            return "Weekly comparison will be more useful later today"
        }

        guard hasTypicalBaseline else { return nil }

        return deltaText(
            current: selectedSnapshot.activeCalories,
            baseline: typicalSameWeekdayAverage,
            label: "typical \(weekdayName)"
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

    private var weekdayName: String {
        selectedSnapshot.date.formatted(.dateTime.weekday(.wide))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel("THIS WEEK")

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(weekDeltaText)
                        .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                        .foregroundStyle(deltaColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    if let typicalDeltaText {
                        Text(typicalDeltaText)
                            .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Chart(chartItems) { item in
                    BarMark(
                        x: .value("Day", item.label),
                        y: .value("Calories", item.calories),
                        width: .fixed(11)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .foregroundStyle(
                        item.isSelected
                        ? ActivityStyle.activityColor
                        : Color.white.opacity(0.30)
                    )
                    .annotation(position: .top, alignment: .center) {
                        Text(shortCalories(item.calories))
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                item.isSelected
                                ? ActivityStyle.activityColor.opacity(0.95)
                                : .white.opacity(0.48)
                            )
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        isSelectedLabel(label)
                                        ? ActivityStyle.activityColor.opacity(0.95)
                                        : .white.opacity(0.42)
                                    )
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .frame(width: 166, height: 96)
                .transaction {
                    $0.animation = nil
                }
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .activityCard(glow: ActivityStyle.activityColor.opacity(0.035))
    }

    private func deltaText(
        current: Int,
        baseline: Int,
        label: String
    ) -> String {
        guard baseline > 0 else { return "No baseline yet" }

        let ratio = Double(current) / Double(max(baseline, 1))
        let delta = Int(abs((ratio - 1.0) * 100.0).rounded())

        if delta == 0 {
            return "In line with \(label)"
        }

        return ratio >= 1.0
            ? "↑ \(delta)% vs \(label)"
            : "↓ \(delta)% vs \(label)"
    }

    private func shortWeekday(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
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

// MARK: - Sessions

private struct SessionsCard: View {
    let sessions: [ActivitySessionSnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                SectionLabel("ACTIVITY LOG")

                Spacer()

                if !sessions.isEmpty {
                    Text("\(sessions.count) sessions")
                        .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }

            if sessions.isEmpty {
                EmptySessionsRow()
            } else {
                VStack(spacing: 9) {
                    ForEach(sessions) { session in
                        SessionRow(session: session)
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

    private var endDate: Date {
        Calendar.current.date(byAdding: .minute, value: session.durationMinutes, to: session.startDate) ?? session.startDate
    }

    private var timeRange: String {
        let start = session.startDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        let end = endDate.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
        return "\(start) – \(end)"
    }

    var body: some View {
        HStack(spacing: 11) {
            CircleIcon(systemName: session.icon, color: session.color, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                Text(timeRange)
                    .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()

            Text(DurationFormatter.fullMinutes(session.durationMinutes))
                .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .monospacedDigit()
        }
        .padding(12)
        .innerActivityCard(cornerRadius: 15)
    }
}

private struct EmptySessionsRow: View {
    var body: some View {
        HStack(spacing: 11) {
            CircleIcon(systemName: "figure.walk", color: ActivityStyle.activityColor, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text("No workouts recorded")
                    .font(.system(size: ActivityTypography.metricValue, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))

                Text("Activity totals are shown from Apple Health.")
                    .font(.system(size: ActivityTypography.helperText, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.46))
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
            .foregroundStyle(.white.opacity(0.68))
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
    static let screenBackground = Color(red: 0.018, green: 0.019, blue: 0.022)
    static let cardBackground = Color(red: 0.045, green: 0.048, blue: 0.055)
    static let innerCardBackground = Color.white.opacity(0.035)
    static let border = Color.white.opacity(0.065)

    static let activityColor = Color(red: 0.16, green: 0.80, blue: 0.43)
    static let green = Color(red: 0.45, green: 0.78, blue: 0.45)
    static let teal = Color(red: 0.25, green: 0.78, blue: 0.82)
    static let blue = Color(red: 0.30, green: 0.72, blue: 0.95)
    static let purple = Color(red: 0.58, green: 0.40, blue: 0.95)
    static let amber = Color(red: 0.92, green: 0.68, blue: 0.30)
    static let red = Color(red: 0.96, green: 0.42, blue: 0.42)
}

private enum DurationFormatter {
    static func compact(_ minutes: Int) -> String {
        guard minutes >= 90 else { return "\(minutes)m" }

        let hours = minutes / 60
        let remainder = minutes % 60

        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    static func fullMinutes(_ minutes: Int) -> String {
        "\(minutes) min"
    }
}

private enum MetricFormatter {
    static func compactSteps(_ steps: Int) -> String {
        if steps >= 1_000 {
            return String(format: "%.1fk", Double(steps) / 1000.0)
        }

        return "\(steps)"
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
                                Color.white.opacity(0.030),
                                Color.white.opacity(0.004)
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
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
    }
}
