import SwiftUI
import SwiftData

struct HighlightsView: View {

    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    @StateObject private var viewModel = HighlightsViewModel()
    @StateObject private var userSettings = WeekFitUserSettings.shared
    @State private var showProfile = false
    @State private var showContent = false

    private var refreshSignature: String {
        let activitySignature = plannedActivities
            .map { "\($0.id).\($0.isCompleted).\($0.isSkipped).\($0.date.timeIntervalSince1970)" }
            .joined(separator: "|")

        return [
            activitySignature,
            nutritionViewModel.coachStateRefreshID.uuidString,
            "\(healthManager.isHealthAccessRequested)",
            languageManager.selectedLanguage.rawValue
        ].joined(separator: "::")
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack(alignment: .top) {
            WeekFitTheme.appBackground
                .ignoresSafeArea()
            ambientBackground

            WeekFitScreenContainer {
                WeekFitScreenHeader(
                    title: WeekFitLocalizedString("highlights.title"),
                    subtitle: WeekFitLocalizedString("highlights.range.last30Days"),
                    initials: userSettings.profileInitials,
                    showAvatar: true
                ) {
                    showProfile = true
                }
            } content: {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        heroCard
                        chartCard
                        driverGrid
                    }
                    .padding(.bottom, 102)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 8)
                    .animation(.interactiveSpring(response: 0.42, dampingFraction: 0.88), value: showContent)
                }
            }

            if viewModel.isLoading && viewModel.dailyMetrics.isEmpty {
                loadingState
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            showContent = true
        }
        .weekFitSettingsSheet(isPresented: $showProfile)
        .task(id: refreshSignature) {
            await viewModel.refresh(
                healthManager: healthManager,
                nutritionViewModel: nutritionViewModel,
                plannedActivities: plannedActivities
            )
        }
    }
}

private extension HighlightsView {

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                metricIcon(viewModel.story.primaryMetric)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(metricColor(viewModel.story.primaryMetric))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(metricColor(viewModel.story.primaryMetric).opacity(0.16)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(AppText.Highlights.monthlyStory)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.42)
                        .foregroundStyle(WeekFitTheme.secondaryText)

                    Text(metricLabel(viewModel.story.primaryMetric))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(metricColor(viewModel.story.primaryMetric))
                }

                Spacer()

                percentageBadge
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(viewModel.story.headline)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .tracking(-0.35)
                    .fixedSize(horizontal: false, vertical: true)

                Text(viewModel.story.bodyNarrative)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .lineSpacing(4)
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(accentCardBackground(metricColor(viewModel.story.primaryMetric)))
    }

    var percentageBadge: some View {
        HStack(spacing: 4) {
            Text(viewModel.story.trendLabel)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(metricColor(viewModel.story.primaryMetric))
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Capsule().fill(metricColor(viewModel.story.primaryMetric).opacity(0.15)))
        .overlay {
            Capsule()
                .stroke(metricColor(viewModel.story.primaryMetric).opacity(0.16), lineWidth: 1)
        }
    }

    var chartCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chartTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)

//                    Text("Last 30 days")
//                        .font(.system(size: 13, weight: .medium, design: .rounded))
//                        .foregroundStyle(WeekFitTheme.secondaryText)
                }

                Spacer()

                metricIcon(viewModel.story.focusChartMetric)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(metricColor(viewModel.story.focusChartMetric))
            }

            InsightLineChart(
                values: chartValues,
                accent: metricColor(viewModel.story.focusChartMetric)
            )
            .frame(height: 176)

            whyStoryBlock
        }
        .padding(18)
        .background(standardCardBackground)
    }

    var driverGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            ForEach(viewModel.story.snapshots, id: \.metric) { snapshot in
                driverCard(snapshot)
            }
        }
    }

    func driverCard(_ snapshot: MetricSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                metricIcon(snapshot.metric)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(metricColor(snapshot.metric))
                    .frame(width: 25, height: 25)
                    .background(Circle().fill(metricColor(snapshot.metric).opacity(0.12)))

                Text(metricLabel(snapshot.metric))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.84))
            }

            Text(String(format: WeekFitLocalizedString("highlights.viewMetricAnalysisFormat"), metricLabel(snapshot.metric)))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText.opacity(0.90))
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 82, alignment: .topLeading)
        .padding(.vertical, 13)
        .padding(.horizontal, 13)
        .background(standardCardBackground(cornerRadius: 20))
    }

    var chartValues: [Double] {
        let metrics = viewModel.dailyMetrics.suffix(30)
        guard !metrics.isEmpty else { return Array(repeating: 0.12, count: 30) }

        switch viewModel.story.focusChartMetric {
        case .recovery:
            return metrics.map { Double($0.recoveryScore) / 100.0 }
        case .nutrition:
            return metrics.map { Double($0.nutritionScore) / 100.0 }
        case .sleep:
            return metrics.map { Double($0.sleepConsistency) / 100.0 }
        case .activity:
            let maxLoad = max(metrics.map(\.activityVolume).max() ?? 0, 1)
            return metrics.map { Double($0.activityVolume) / Double(maxLoad) }
        }
    }

    var chartTitle: String {
        metricLabel(viewModel.story.focusChartMetric)
    }

    var focusedSnapshot: MetricSnapshot? {
        viewModel.story.snapshots.first { $0.metric == viewModel.story.focusChartMetric }
    }

    var whyStoryBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(String(format: WeekFitLocalizedString("highlights.whyMetricFormat"), metricLabel(viewModel.story.primaryMetric)))
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText.opacity(0.94))

            VStack(alignment: .leading, spacing: 7) {
                ForEach(whySignals, id: \.self) { signal in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(metricColor(viewModel.story.primaryMetric).opacity(0.88))
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)

                        Text(signal)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.90))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 1)
    }

    var whySignals: [String] {
        let recovery = snapshot(for: .recovery)
        let sleep = snapshot(for: .sleep)
        let activity = snapshot(for: .activity)
        let nutrition = snapshot(for: .nutrition)

        var signals: [String] = []

        if let sleep, sleep.currentBaseline > 0 {
            switch sleep.trend {
            case .up:
                signals.append(WeekFitLocalizedString("highlights.signal.sleepMoreConsistent"))
            case .stable:
                signals.append(WeekFitLocalizedString("highlights.signal.sleepStayedConsistent"))
            case .down:
                signals.append(WeekFitLocalizedString("highlights.signal.sleepUnevenHeld"))
            }
        }

        if let recovery, recovery.currentBaseline > 0 {
            signals.append(WeekFitLocalizedString("highlights.signal.recoveryHeld"))
        }

        if let activity, activity.currentBaseline > 0 {
            switch activity.trend {
            case .up:
                signals.append(WeekFitLocalizedString("highlights.signal.activityIncreased"))
            case .stable:
                signals.append(WeekFitLocalizedString("highlights.signal.activityPredictable"))
            case .down:
                signals.append(WeekFitLocalizedString("highlights.signal.activityLighter"))
            }
        }

        if signals.count < 3, let nutrition, nutrition.currentBaseline > 0 {
            switch nutrition.trend {
            case .up:
                signals.append(WeekFitLocalizedString("highlights.signal.fuelingImproved"))
            case .stable:
                signals.append(WeekFitLocalizedString("highlights.signal.fuelingConsistent"))
            case .down:
                signals.append(WeekFitLocalizedString("highlights.signal.fuelingMixed"))
            }
        }

        if signals.isEmpty {
            signals.append(WeekFitLocalizedString("highlights.signal.notEnoughData"))
        }

        return Array(signals.prefix(3))
    }

    var standardCardBackground: some View {
        standardCardBackground()
    }

    func standardCardBackground(cornerRadius: CGFloat = 24) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(WeekFitTheme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(WeekFitTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: WeekFitTheme.cardShadow.opacity(0.55), radius: 18, y: 10)
    }

    func accentCardBackground(_ accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.105),
                        WeekFitTheme.cardBackground.opacity(0.98)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(WeekFitTheme.whiteOpacity(0.055), lineWidth: 1)
            }
            .shadow(color: WeekFitTheme.cardShadow.opacity(0.62), radius: 22, y: 12)
    }

    var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(WeekFitTheme.meal)

            Text(AppText.Highlights.loading)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 146)
    }

    var ambientBackground: some View {
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
}

private extension HighlightsView {

    func metricLabel(_ metric: HealthMetric) -> String {
        switch metric {
        case .recovery: return WeekFitLocalizedString("highlights.metric.recovery")
        case .activity: return WeekFitLocalizedString("highlights.metric.activity")
        case .nutrition: return WeekFitLocalizedString("highlights.metric.nutrition")
        case .sleep: return WeekFitLocalizedString("highlights.metric.sleep")
        }
    }

    func metricIcon(_ metric: HealthMetric) -> Image {
        switch metric {
        case .recovery: return Image(systemName: "heart.fill")
        case .activity: return Image(systemName: "figure.run")
        case .nutrition: return Image(systemName: "fork.knife")
        case .sleep: return Image(systemName: "moon.fill")
        }
    }

    func metricColor(_ metric: HealthMetric) -> Color {
        switch metric {
        case .recovery: return WeekFitTheme.meal
        case .activity: return WeekFitTheme.orange
        case .nutrition: return WeekFitTheme.blue
        case .sleep: return WeekFitTheme.purple
        }
    }

    func snapshot(for metric: HealthMetric) -> MetricSnapshot? {
        viewModel.story.snapshots.first { $0.metric == metric }
    }

}

private struct InsightLineChart: View {

    let values: [Double]
    let accent: Color

    private var plotValues: [Double] {
        let clamped = values.map { min(max($0, 0.08), 0.92) }
        return clamped.count >= 2 ? clamped : [0.45, 0.45]
    }

    var body: some View {
        GeometryReader { proxy in
            let point = Self.point(
                for: plotValues.indices.last ?? 0,
                values: plotValues,
                size: proxy.size
            )

            ZStack {
                ReferenceBandLines()
                    .stroke(WeekFitTheme.whiteOpacity(0.065), style: StrokeStyle(lineWidth: 1, dash: [3, 10]))

                ReferenceBandLabels()
                    .foregroundStyle(WeekFitTheme.tertiaryText.opacity(0.52))

                LineAreaShape(values: plotValues)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.18),
                                accent.opacity(0.025)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                LinePathShape(values: plotValues)
                    .stroke(
                        accent.opacity(0.95),
                        style: StrokeStyle(lineWidth: 2.7, lineCap: .round, lineJoin: .round)
                    )

                Circle()
                    .fill(accent.opacity(0.26))
                    .frame(width: 34, height: 34)
                    .blur(radius: 8)
                    .position(point)

                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle()
                            .stroke(Color.black.opacity(0.55), lineWidth: 2)
                    }
                    .shadow(color: accent.opacity(0.55), radius: 10, y: 0)
                    .position(point)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
    }

    static func point(for index: Int, values: [Double], size: CGSize) -> CGPoint {
        guard values.count > 1 else {
            return CGPoint(x: size.width, y: size.height / 2)
        }

        let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
        let y = size.height - (size.height * CGFloat(values[index]))
        return CGPoint(x: x, y: y)
    }
}

private struct LinePathShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }

        var previousPoint = point(for: values.startIndex, in: rect)
        path.move(to: previousPoint)

        for index in values.indices.dropFirst() {
            let currentPoint = point(for: index, in: rect)
            let midpoint = CGPoint(
                x: (previousPoint.x + currentPoint.x) / 2,
                y: (previousPoint.y + currentPoint.y) / 2
            )

            path.addQuadCurve(to: midpoint, control: previousPoint)
            previousPoint = currentPoint
        }

        path.addLine(to: previousPoint)
        return path
    }

    private func point(for index: Int, in rect: CGRect) -> CGPoint {
        let x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
        let y = rect.maxY - rect.height * CGFloat(values[index])
        return CGPoint(x: x, y: y)
    }
}

private struct LineAreaShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = LinePathShape(values: values).path(in: rect)
        guard values.count > 1 else { return path }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ReferenceBandLines: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        [0.25, 0.50, 0.75].forEach { ratio in
            let y = rect.minY + rect.height * ratio
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}

private struct ReferenceBandLabels: View {
    var body: some View {
        GeometryReader { proxy in
            Group {
                bandLabel(WeekFitLocalizedString("health.high"), y: proxy.size.height * 0.18)
                bandLabel(WeekFitLocalizedString("highlights.chart.average"), y: proxy.size.height * 0.48)
                bandLabel(WeekFitLocalizedString("health.low"), y: proxy.size.height * 0.78)
            }
        }
        .allowsHitTesting(false)
    }

    private func bandLabel(_ text: String, y: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 9.8, weight: .bold, design: .rounded))
            .tracking(0.2)
            .position(x: 30, y: y)
    }
}

#if DEBUG
#Preview {
    HighlightsView()
        .environmentObject(HealthManager())
        .environmentObject(NutritionViewModel())
        .modelContainer(for: PlannedActivity.self, inMemory: true)
}
#endif
