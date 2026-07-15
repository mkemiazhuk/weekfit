import SwiftUI
import HealthKit
internal import Combine

struct RecoveryDetailsView: View {

    let selectedDate: Date

    @StateObject private var viewModel = RecoveryDetailsViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager
    @EnvironmentObject private var healthManager: HealthManager
    @State private var activeDate: Date

    // Kept for compatibility with existing navigation from Today.
    // The details screen recalculates recovery for the selected date.
    let recoveryScore: Int
    let recoveryBreakdown: RecoveryScoreBreakdown

    init(
        selectedDate: Date,
        recoveryScore: Int,
        recoveryBreakdown: RecoveryScoreBreakdown
    ) {
        self.selectedDate = selectedDate
        self.recoveryScore = recoveryScore
        self.recoveryBreakdown = recoveryBreakdown
        _activeDate = State(initialValue: selectedDate)
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack {
            RecoveryStyle.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                HealthDetailsWeekPicker(
                    selectedDate: $activeDate,
                    accentColor: RecoveryStyle.recoveryColor
                ) { date in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                .padding(.horizontal, 18)
                .padding(.top, 9)
                .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 9) {
                        RecoveryHeroCard(snapshot: viewModel.snapshot)
                        RecoveryVitalsCard(snapshot: viewModel.snapshot)
                        RecoveryBreakdownCard(snapshot: viewModel.snapshot)
                        SleepDetailsCard(snapshot: viewModel.snapshot)
                        SleepStagesCard(snapshot: viewModel.snapshot)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 5)
                    .padding(.bottom, 36)
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .tint(.white.opacity(0.75))
            }
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
        .task {
            await load(date: activeDate)
        }
        .onChange(of: activeDate) { newDate in
            Task {
                await load(date: newDate)
            }
        }
        .onChange(of: languageManager.selectedLanguage) { _, _ in
            Task {
                await load(date: activeDate)
            }
        }
    }

    private func load(date: Date) async {
        await viewModel.load(for: date, healthManager: healthManager)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WeekFitLocalizedString("recovery.details.title"))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(recoveryDetailsDateTitle)
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
            RecoveryStyle.screenBackground.ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WeekFitTheme.whiteOpacity(0.04))
                .frame(height: 1)
        }
    }

    private var recoveryDetailsDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        return formatter.string(from: activeDate)
    }
}

// MARK: - Cards

private struct RecoveryHeroCard: View {
    let snapshot: RecoveryDaySnapshot

    private var progress: CGFloat {
        CGFloat(min(max(snapshot.recoveryScore, 0), 100)) / 100
    }

    var body: some View {
        HStack(spacing: 15) {
            recoveryRing

            VStack(alignment: .leading, spacing: 5) {
                Text(WeekFitLocalizedString("recovery.details.score.title").uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(RecoveryStyle.recoveryColor)

                Text(statusText)
                    .font(.system(size: RecoveryTypography.heroTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(snapshot.insightText)
                    .font(.system(size: RecoveryTypography.heroText, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
        .recoveryCard(glow: RecoveryStyle.recoveryColor.opacity(0.08))
    }

    private var recoveryRing: some View {
        WeekFitProgressRing(
            progress: progress,
            color: WeekFitProgressRingColor.recovery,
            size: 70,
            strokeWidth: 4,
            gradientColors: [
                WeekFitProgressRingColor.recovery.opacity(0.80),
                WeekFitProgressRingColor.recovery,
                Color(red: 0.28, green: 0.92, blue: 1.00),
                WeekFitProgressRingColor.recovery.opacity(0.94)
            ]
        ) {
            VStack(spacing: -2) {
                Text("\(snapshot.recoveryScore)")
                    .font(.system(size: RecoveryTypography.heroScore, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(WeekFitLocalizedString("common.unit.score"))
                    .font(.system(size: RecoveryTypography.heroScoreLabel, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.40))
            }
        }
    }

    private var statusText: String {
        guard let input = snapshot.recoveryInput else {
            return WeekFitLocalizedString("recovery.details.status.noData")
        }

        switch RecoveryScoreEngine.statusTier(
            score: snapshot.recoveryScore,
            input: input,
            breakdown: snapshot.recoveryBreakdown
        ) {
        case .wellRecovered:
            return WeekFitLocalizedString("recovery.details.status.wellRecovered")
        case .moderatelyReady:
            return WeekFitLocalizedString("recovery.details.status.moderatelyReady")
        case .takeItEasier:
            return WeekFitLocalizedString("recovery.details.status.takeItEasier")
        case .recoveryPriority:
            return WeekFitLocalizedString("recovery.details.status.recoveryPriority")
        case .noData:
            return WeekFitLocalizedString("recovery.details.status.noData")
        }
    }
}

private struct RecoveryVitalsCard: View {
    let snapshot: RecoveryDaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(WeekFitLocalizedString("recovery.details.section.keyVitals"))

            HStack(alignment: .top, spacing: 8) {
                compactVital(
                    title: WeekFitLocalizedString("today.status.metric.deep"),
                    value: RecoveryFormat.duration(snapshot.deepSleepMinutes),
                    icon: "moon.zzz.fill",
                    color: RecoveryStyle.deepBlue
                )

                compactVital(
                    title: WeekFitLocalizedString("today.status.metric.hrv"),
                    value: hrvText,
                    icon: "waveform.path.ecg",
                    color: RecoveryStyle.recoveryColor
                )

                compactVital(
                    title: WeekFitLocalizedString("today.status.metric.rhr"),
                    value: rhrText,
                    icon: "heart.fill",
                    color: RecoveryStyle.red
                )
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .recoveryCard(glow: RecoveryStyle.recoveryColor.opacity(0.035))
    }

    private var hrvText: String {
        guard let hrv = snapshot.hrv, hrv > 0 else { return "—" }
        return "\(Int(hrv.rounded())) \(WeekFitLocalizedString("common.unit.millisecondShort"))"
    }

    private var rhrText: String {
        guard let rhr = snapshot.restingHeartRate, rhr > 0 else { return "—" }
        return "\(Int(rhr.rounded())) \(WeekFitLocalizedString("common.unit.bpm"))"
    }

    private func compactVital(
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
                    .font(.system(size: RecoveryTypography.metricValue, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                    .lineLimit(2)
                    .minimumScaleFactor(0.70)
                    .multilineTextAlignment(.center)
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

private struct RecoveryBreakdownCard: View {
    let snapshot: RecoveryDaySnapshot

    private var breakdown: RecoveryScoreBreakdown {
        snapshot.recoveryBreakdown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header

            VStack(spacing: 9) {
                breakdownRow(title: WeekFitLocalizedString("recovery.details.breakdown.sleepDuration"), value: breakdown.sleepDuration, maxValue: RecoveryScoreBreakdown.maxSleepDurationContribution, icon: "clock.fill", color: RecoveryStyle.recoveryColor)
                breakdownRow(title: WeekFitLocalizedString("recovery.details.breakdown.sleepConsistency"), value: breakdown.sleepConsistency, maxValue: RecoveryScoreBreakdown.maxSleepConsistencyContribution, icon: "moon.zzz.fill", color: RecoveryStyle.purple)
                breakdownRow(title: WeekFitLocalizedString("recovery.details.breakdown.sleepContinuity"), value: breakdown.sleepContinuity, maxValue: RecoveryScoreBreakdown.maxSleepContinuityContribution, icon: "waveform.path", color: RecoveryStyle.blue)
                breakdownRow(title: WeekFitLocalizedString("recovery.details.breakdown.sleepArchitecture"), value: breakdown.sleepArchitecture, maxValue: RecoveryScoreBreakdown.maxSleepArchitectureContribution, icon: "bed.double.fill", color: RecoveryStyle.deepBlue)
                breakdownRow(title: WeekFitLocalizedString("today.status.metric.hrv"), value: breakdown.hrv, maxValue: RecoveryScoreBreakdown.maxHRVContribution, icon: "heart.text.square.fill", color: RecoveryStyle.recoveryColor)
                breakdownRow(title: WeekFitLocalizedString("recovery.details.breakdown.restingHeartRate"), value: breakdown.restingHeartRate, maxValue: RecoveryScoreBreakdown.maxRestingHeartRateContribution, icon: "heart.fill", color: RecoveryStyle.red)

                if breakdown.trainingLoadModifier < 0 {
                    breakdownRow(
                        title: WeekFitLocalizedString("recovery.details.breakdown.trainingLoad"),
                        value: breakdown.trainingLoadModifier,
                        maxValue: 0,
                        icon: "figure.run",
                        color: RecoveryStyle.red,
                        showsNegative: true
                    )
                }
            }

            explanation

            if !breakdown.unavailableSignals.isEmpty {
                unavailableSignalsNote
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .recoveryCard(glow: RecoveryStyle.purple.opacity(0.045))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(WeekFitLocalizedString("recovery.details.section.breakdown"))

            Text(dynamicExplanationTitle)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    private var dynamicExplanationTitle: String {
        let items: [(String, Int, Int)] = [
            (WeekFitLocalizedString("recovery.details.breakdown.sleepDuration"), breakdown.sleepDuration, RecoveryScoreBreakdown.maxSleepDurationContribution),
            (WeekFitLocalizedString("recovery.details.breakdown.sleepConsistency"), breakdown.sleepConsistency, RecoveryScoreBreakdown.maxSleepConsistencyContribution),
            (WeekFitLocalizedString("recovery.details.breakdown.sleepContinuity"), breakdown.sleepContinuity, RecoveryScoreBreakdown.maxSleepContinuityContribution),
            (WeekFitLocalizedString("recovery.details.breakdown.sleepArchitecture"), breakdown.sleepArchitecture, RecoveryScoreBreakdown.maxSleepArchitectureContribution),
            (WeekFitLocalizedString("today.status.metric.hrv"), breakdown.hrv, RecoveryScoreBreakdown.maxHRVContribution),
            (WeekFitLocalizedString("recovery.details.breakdown.restingHeartRate"), breakdown.restingHeartRate, RecoveryScoreBreakdown.maxRestingHeartRateContribution)
        ]

        let strongest = items.max {
            scoreRatio(value: $0.1, maxValue: $0.2) < scoreRatio(value: $1.1, maxValue: $1.2)
        }?.0 ?? WeekFitLocalizedString("recovery.details.breakdown.sleep")

        return String(format: WeekFitLocalizedString("recovery.details.mostPointsFormat"), strongest)
    }

    private var explanation: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.34))
                .padding(.top, 1)

            Text(WeekFitLocalizedString("recovery.details.score.explanation"))
                .font(.system(size: RecoveryTypography.helperText, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.39))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 1)
    }

    private var unavailableSignalsNote: some View {
        Text(unavailableSignalsText)
            .font(.system(size: RecoveryTypography.helperText, weight: .medium, design: .rounded))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.36))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var unavailableSignalsText: String {
        let labels = breakdown.unavailableSignals.map { signal in
            switch signal {
            case .hrv:
                return WeekFitLocalizedString("today.status.metric.hrv")
            case .restingHeartRate:
                return WeekFitLocalizedString("recovery.details.breakdown.restingHeartRate")
            case .deepSleep:
                return WeekFitLocalizedString("today.status.metric.deep")
            case .remSleep:
                return WeekFitLocalizedString("recovery.details.sleep.rem")
            case .priorDayLoad:
                return WeekFitLocalizedString("recovery.details.breakdown.trainingLoad")
            }
        }

        return String(
            format: WeekFitLocalizedString("recovery.details.unavailableSignalsFormat"),
            labels.joined(separator: ", ")
        )
    }

    private func breakdownRow(
        title: String,
        value: Int,
        maxValue: Int,
        icon: String,
        color: Color,
        showsNegative: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 11) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.13))
                    .frame(width: 25, height: 25)

                Image(systemName: icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: RecoveryTypography.metricTitle, weight: .semibold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.86))
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)

                    Spacer(minLength: 8)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(value)")
                            .font(.system(size: RecoveryTypography.metricValue, weight: .bold, design: .rounded))
                            .foregroundStyle(color)

                        if !showsNegative {
                            Text("/ \(maxValue)")
                                .font(.system(size: RecoveryTypography.metricSecondary, weight: .medium, design: .rounded))
                                .foregroundStyle(WeekFitTheme.whiteOpacity(0.40))
                        }
                    }
                    .monospacedDigit()
                }

                if !showsNegative {
                    MiniProgressBar(value: value, maxValue: maxValue, color: color)
                        .frame(height: 3.5)
                }
            }
        }
    }

    private func scoreRatio(value: Int, maxValue: Int) -> Double {
        guard maxValue > 0 else { return 0 }
        return min(max(Double(value) / Double(maxValue), 0), 1)
    }

}

private struct SleepDetailsCard: View {
    let snapshot: RecoveryDaySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(WeekFitLocalizedString("recovery.details.section.sleepDetails"))

            HStack(alignment: .top, spacing: 8) {
                compactSleepMetric(title: WeekFitLocalizedString("recovery.details.sleep.asleep"), value: RecoveryFormat.duration(snapshot.asleepMinutes), icon: "moon.zzz.fill", color: RecoveryStyle.recoveryColor)
                compactSleepMetric(title: WeekFitLocalizedString("recovery.details.sleep.inBed"), value: RecoveryFormat.duration(snapshot.timeInBedMinutes), icon: "bed.double.fill", color: RecoveryStyle.purple)
                compactSleepMetric(title: WeekFitLocalizedString("recovery.details.sleep.awake"), value: RecoveryFormat.duration(snapshot.awakeMinutes), icon: "eye.fill", color: RecoveryStyle.amber)
            }

            Rectangle()
                .fill(WeekFitTheme.whiteOpacity(0.045))
                .frame(height: 1)

            VStack(spacing: 7) {
                SleepTimeRow(title: WeekFitLocalizedString("recovery.details.sleep.wentToBed"), value: RecoveryFormat.time(snapshot.bedStart))
                SleepTimeRow(title: WeekFitLocalizedString("recovery.details.sleep.wokeUp"), value: RecoveryFormat.time(snapshot.wakeTime))
                SleepTimeRow(title: WeekFitLocalizedString("recovery.details.sleep.awakeMoments"), value: "\(snapshot.awakeningsCount)")
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .recoveryCard()
    }

    private func compactSleepMetric(
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
                    .font(.system(size: RecoveryTypography.metricValue, weight: .bold, design: .rounded))
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

private struct SleepStagesCard: View {
    let snapshot: RecoveryDaySnapshot

    private var total: Int {
        max(snapshot.deepSleepMinutes + snapshot.remSleepMinutes + snapshot.coreSleepMinutes, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(WeekFitLocalizedString("recovery.details.section.sleepQuality"))
            stageBar
            stageRows
        }
        .padding(17)
        .recoveryCard()
    }

    private var stageBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            HStack(spacing: 4) {
                Capsule()
                    .fill(RecoveryStyle.deepBlue)
                    .frame(width: segmentWidth(snapshot.deepSleepMinutes, totalWidth: width))

                Capsule()
                    .fill(RecoveryStyle.purple)
                    .frame(width: segmentWidth(snapshot.remSleepMinutes, totalWidth: width))

                Capsule()
                    .fill(RecoveryStyle.recoveryColor.opacity(0.75))
                    .frame(width: segmentWidth(snapshot.coreSleepMinutes, totalWidth: width))
            }
        }
        .frame(height: 11)
    }

    private var stageRows: some View {
        VStack(spacing: 7) {
            SleepStageRow(title: WeekFitLocalizedString("recovery.details.sleep.deep"), value: RecoveryFormat.duration(snapshot.deepSleepMinutes), percent: stagePercent(snapshot.deepSleepMinutes), color: RecoveryStyle.deepBlue)
            SleepStageRow(title: WeekFitLocalizedString("recovery.details.sleep.rem"), value: RecoveryFormat.duration(snapshot.remSleepMinutes), percent: stagePercent(snapshot.remSleepMinutes), color: RecoveryStyle.purple)
            SleepStageRow(title: WeekFitLocalizedString("recovery.details.sleep.core"), value: RecoveryFormat.duration(snapshot.coreSleepMinutes), percent: stagePercent(snapshot.coreSleepMinutes), color: RecoveryStyle.recoveryColor)
        }
    }

    private func segmentWidth(_ minutes: Int, totalWidth: CGFloat) -> CGFloat {
        let availableWidth = max(totalWidth - 8, 1)
        let ratio = CGFloat(minutes) / CGFloat(total)
        return max(8, availableWidth * ratio)
    }

    private func stagePercent(_ minutes: Int) -> Int {
        Int((Double(minutes) / Double(total) * 100).rounded())
    }
}

// MARK: - Small Components

private struct SleepTimeRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: RecoveryTypography.metricTitle, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.44))

            Spacer()

            Text(value)
                .font(.system(size: RecoveryTypography.metricValue, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.86))
                .monospacedDigit()
        }
    }
}

private struct SleepStageRow: View {
    let title: String
    let value: String
    let percent: Int
    let color: Color

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(color)
                .frame(width: 7.5, height: 7.5)

            Text(title)
                .font(.system(size: RecoveryTypography.metricTitle, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.82))

            Spacer()

            Text(value)
                .font(.system(size: RecoveryTypography.metricValue, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.90))
                .monospacedDigit()

            Text("\(percent)%")
                .font(.system(size: RecoveryTypography.metricSecondary, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.42))
                .frame(width: 38, alignment: .trailing)
                .monospacedDigit()
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
            .font(.system(size: RecoveryTypography.sectionLabel, weight: .bold, design: .rounded))
            .tracking(1.8)
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.68))
    }
}

// MARK: - Style

private enum RecoveryTypography {
    static let sectionLabel: CGFloat = 11

    static let heroTitle: CGFloat = 18
    static let heroText: CGFloat = 12
    static let heroScore: CGFloat = 26
    static let heroScoreLabel: CGFloat = 9

    static let metricTitle: CGFloat = 12
    static let metricValue: CGFloat = 14
    static let metricSecondary: CGFloat = 12
    static let helperText: CGFloat = 11.5
}

private enum RecoveryStyle {
    static var screenBackground: Color { WeekFitTheme.backgroundColor }
    static var cardBackground: Color { Color(red: 0.045, green: 0.048, blue: 0.055) }
    static var border: Color { WeekFitTheme.border }

    static var recoveryColor: Color { WeekFitTheme.accent(Color(red: 0.18, green: 0.74, blue: 0.89)) }
    static var blue: Color { WeekFitTheme.accent(Color(red: 0.30, green: 0.72, blue: 0.95)) }
    static var deepBlue: Color { WeekFitTheme.accent(Color(red: 0.22, green: 0.42, blue: 0.95)) }
    static var purple: Color { WeekFitTheme.accent(Color(red: 0.58, green: 0.40, blue: 0.95)) }
    static var amber: Color { WeekFitTheme.accent(Color(red: 0.92, green: 0.68, blue: 0.30)) }
    static var red: Color { WeekFitTheme.accent(Color(red: 0.96, green: 0.42, blue: 0.42)) }
}

private enum RecoveryFormat {
    static func duration(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }

        let hours = minutes / 60
        let remainder = minutes % 60

        if hours > 0 && remainder > 0 {
            return String(format: WeekFitLocalizedString("common.duration.hoursMinutesShortFormat"), hours, remainder)
        }

        if hours > 0 {
            return String(format: WeekFitLocalizedString("common.duration.hoursShortFormat"), hours)
        }

        return String(format: WeekFitLocalizedString("common.duration.minutesShortFormat"), minutes)
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "—" }

        return date.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
        )
    }
}

private extension View {
    func recoveryCard(
        cornerRadius: CGFloat = 22,
        glow: Color = .clear
    ) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(RecoveryStyle.cardBackground)

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
                .stroke(RecoveryStyle.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
    }
}

private struct MiniProgressBar: View {
    let value: Int
    let maxValue: Int
    let color: Color

    private var progress: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(min(max(Double(value) / Double(maxValue), 0), 1))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WeekFitTheme.whiteOpacity(0.085))

                Capsule()
                    .fill(color)
                    .frame(width: max(6, proxy.size.width * progress))
            }
        }
    }
}
