import SwiftUI

// MARK: - Screen

struct RecoveryDetailsScrollScreen: View {
    @Binding var activeDate: Date
    let snapshot: RecoveryDaySnapshot
    let stressIndex: StressIndexResult
    let isLoading: Bool
    let onClose: () -> Void
    let onOpenStress: () -> Void

    @Environment(\.weekFitPalette) private var palette
    @State private var showsAllFactors = false
    @State private var headerMinY: CGFloat = 0

    private var isCollapsed: Bool { headerMinY < -28 }

    var body: some View {
        ZStack {
            canvas.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                RecoveryDetailsPage(
                    activeDate: $activeDate,
                    snapshot: snapshot,
                    stressIndex: stressIndex,
                    showsAllFactors: $showsAllFactors,
                    onClose: onClose,
                    onOpenStress: onOpenStress
                )
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: RecoveryDetailsScrollOffsetKey.self,
                            value: proxy.frame(in: .named(RecoveryDetailsScrollSpace.name)).minY
                        )
                    }
                }
            }
            .coordinateSpace(name: RecoveryDetailsScrollSpace.name)
            .onPreferenceChange(RecoveryDetailsScrollOffsetKey.self) { headerMinY = $0 }

            if isLoading {
                ProgressView()
                    .tint(palette.isLight ? WeekFitSemanticMetricTokens.recovery : .white.opacity(0.75))
            }
        }
        .overlay(alignment: .top) {
            if isCollapsed {
                RecoveryDetailsCompactHeader(
                    title: WeekFitLocalizedString("recovery.details.screenTitle"),
                    onClose: onClose
                )
                .background(canvas.ignoresSafeArea(edges: .top))
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isCollapsed)
        .accessibilityIdentifier("recovery.details.screen")
    }

    private var canvas: Color {
        palette.isLight ? HealthDetailsSoftChrome.canvas : RecoveryStyle.screenBackground
    }
}

private enum RecoveryDetailsScrollSpace {
    static let name = "recoveryDetailsScroll"
}

private struct RecoveryDetailsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct RecoveryDetailsPage: View {
    @Binding var activeDate: Date
    let snapshot: RecoveryDaySnapshot
    let stressIndex: StressIndexResult
    @Binding var showsAllFactors: Bool
    let onClose: () -> Void
    let onOpenStress: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            RecoveryDetailsHeader(
                title: WeekFitLocalizedString("recovery.details.screenTitle"),
                subtitle: RecoveryDetailsDateTitle.string(from: activeDate),
                onClose: onClose
            )

            HealthDetailsWeekPicker(
                selectedDate: $activeDate,
                accentColor: palette.isLight
                    ? WeekFitSemanticMetricTokens.recovery
                    : RecoveryStyle.recoveryColor,
                density: .compact
            ) { _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .accessibilityIdentifier("recovery.details.weekPicker")

            VStack(spacing: 12) {
                RecoveryHeroCard(snapshot: snapshot)
                RecoveryLoadIndexCard(result: stressIndex, onTap: onOpenStress)
                RecoverySleepNightCard(snapshot: snapshot)
                RecoveryFactorsCard(
                    snapshot: snapshot,
                    showsAll: $showsAllFactors
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Header

private struct RecoveryDetailsHeader: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RecoveryDetailsCloseButton(action: onClose)
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }
}

private struct RecoveryDetailsCompactHeader: View {
    let title: String
    let onClose: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            RecoveryDetailsCloseButton(action: onClose)
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.vertical, 2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.isLight ? WeekFitLightTokens.divider.opacity(0.45) : WeekFitTheme.whiteOpacity(0.08))
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct RecoveryDetailsCloseButton: View {
    let action: () -> Void
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(
                            palette.isLight
                                ? Color.white.opacity(0.94)
                                : WeekFitTheme.whiteOpacity(0.08)
                        )
                }
                .overlay {
                    Circle()
                        .stroke(
                            palette.isLight
                                ? WeekFitLightTokens.shadowContact.opacity(0.08)
                                : WeekFitTheme.whiteOpacity(0.10),
                            lineWidth: 1
                        )
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppText.Common.Action.close))
    }
}

enum RecoveryDetailsDateTitle {
    static func string(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d")
        let raw = formatter.string(from: date)
        guard let first = raw.first else { return raw }
        return String(first).uppercased() + raw.dropFirst()
    }
}

// MARK: - Hero

private struct RecoveryHeroCard: View {
    let snapshot: RecoveryDaySnapshot
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weekFitPalette) private var palette

    private var tier: RecoveryScoreEngine.RecoveryStatusTier {
        guard let input = snapshot.recoveryInput else { return .noData }
        return RecoveryScoreEngine.statusTier(
            score: snapshot.recoveryScore,
            input: input,
            breakdown: snapshot.recoveryBreakdown
        )
    }

    private var showsScore: Bool { tier != .noData && snapshot.recoveryScore > 0 }

    private var highlights: RecoveryFactorHighlights {
        RecoveryFactorHighlights.select(
            breakdown: snapshot.recoveryBreakdown,
            hasSleep: snapshot.asleepMinutes > 0
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        scoreRing
                        statusBlock
                    }
                } else {
                    HStack(alignment: .center, spacing: 14) {
                        scoreRing
                        statusBlock
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .accessibilityElement(children: .combine)

            Rectangle()
                .fill(palette.isLight ? WeekFitLightTokens.divider.opacity(0.7) : WeekFitTheme.whiteOpacity(0.10))
                .frame(height: 0.5)
                .padding(.horizontal, 16)
                .accessibilityHidden(true)

            physiologyRow
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 16)
        }
        .recoveryDetailsCard()
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(WeekFitLocalizedString("recovery.details.screenTitle"))
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(RecoveryStyle.recoveryColor)

            Text(statusText)
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let explanation = RecoveryFactorCopy.heroExplanation(
                hasSleep: snapshot.asleepMinutes > 0,
                highlights: highlights
            ) {
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoreRing: some View {
        let progress = showsScore ? CGFloat(min(snapshot.recoveryScore, 100)) / 100 : 0
        return ZStack {
            Circle()
                .stroke(RecoveryStyle.recoveryColor.opacity(palette.isLight ? 0.16 : 0.28), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    RecoveryStyle.recoveryColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(showsScore ? "\(snapshot.recoveryScore)" : "—")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.textPrimary)
                    .monospacedDigit()
                Text(WeekFitLocalizedString("recovery.details.score.outOf"))
                    .font(.caption2)
                    .foregroundStyle(palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 8)
        }
        .frame(width: 78, height: 78)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var physiologyRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .center, spacing: 12) {
                physiologyColumn(
                    title: WeekFitLocalizedString("today.status.metric.hrv"),
                    value: hrvValue,
                    icon: "waveform.path.ecg",
                    color: RecoveryStyle.recoveryColor
                )
                physiologyColumn(
                    title: WeekFitLocalizedString("recovery.details.breakdown.restingHeartRate"),
                    value: restingHeartRateValue,
                    icon: "heart.fill",
                    color: RecoveryStyle.red
                )
            }
        } else {
            HStack(alignment: .center, spacing: 12) {
                physiologyColumn(
                    title: WeekFitLocalizedString("today.status.metric.hrv"),
                    value: hrvValue,
                    icon: "waveform.path.ecg",
                    color: RecoveryStyle.recoveryColor
                )
                physiologyColumn(
                    title: WeekFitLocalizedString("recovery.details.breakdown.restingHeartRate"),
                    value: restingHeartRateValue,
                    icon: "heart.fill",
                    color: RecoveryStyle.red
                )
            }
        }
    }

    private var hrvValue: String {
        guard let hrv = snapshot.hrv, hrv > 0 else {
            return WeekFitLocalizedString("recovery.details.metricUnavailable")
        }
        return "\(Int(hrv.rounded())) \(WeekFitLocalizedString("common.unit.millisecondShort"))"
    }

    private var restingHeartRateValue: String {
        guard let restingHeartRate = snapshot.restingHeartRate, restingHeartRate > 0 else {
            return WeekFitLocalizedString("recovery.details.metricUnavailable")
        }
        return "\(Int(restingHeartRate.rounded())) \(WeekFitLocalizedString("common.unit.bpm"))"
    }

    private func physiologyColumn(
        title: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        switch tier {
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

// MARK: - Load index

private struct RecoveryLoadIndexCard: View {
    let result: StressIndexResult
    let onTap: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(WeekFitLocalizedString("recovery.stressIndex.title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.textTertiary)
                }

                scoreRow

                Text(StressIndexCopy.compactInterpretation(for: result))
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .recoveryDetailsCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(StressIndexCopy.accessibilityLabel(for: result)))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var scoreRow: some View {
        switch result.confidence {
        case .unavailable:
            Text(WeekFitLocalizedString("recovery.stressIndex.empty.title"))
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case .low:
            if let level = result.level {
                Text(StressIndexCopy.levelTitle(level))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .medium, .high:
            HStack(alignment: .center, spacing: 8) {
                if let score = result.score {
                    Text("\(score)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(palette.textPrimary)
                        .monospacedDigit()
                }
                if let level = result.level {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 6, height: 6)
                        Text(StressIndexCopy.levelTitle(level))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(statusColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var statusColor: Color {
        StressIndexStyle.color(for: result.level, confidence: result.confidence)
    }
}

// MARK: - Sleep tonight

private struct RecoverySleepNightCard: View {
    let snapshot: RecoveryDaySnapshot
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weekFitPalette) private var palette

    private var hasSleep: Bool { snapshot.asleepMinutes > 0 }

    private var hasStageData: Bool {
        snapshot.recoveryBreakdown.sleepArchitectureGrade != nil
            || snapshot.deepSleepMinutes > 0
            || snapshot.remSleepMinutes > 0
            || snapshot.coreSleepMinutes > 0
    }

    private var stageTotal: Int {
        snapshot.deepSleepMinutes + snapshot.remSleepMinutes + snapshot.coreSleepMinutes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasSleep {
                sleepSummary
            } else {
                Text(WeekFitLocalizedString("recovery.details.section.sleepTonight"))
                    .font(.headline)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }

            if hasSleep {

                if hasStageData, stageTotal > 0 {
                    stageBar
                    stageRows
                } else {
                    Text(WeekFitLocalizedString("recovery.details.sleep.stagesUnavailable"))
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                footer
            } else {
                Text(WeekFitLocalizedString("recovery.details.metricUnavailable"))
                    .font(.body)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .recoveryDetailsCard()
    }

    @ViewBuilder
    private var sleepSummary: some View {
        let duration = Text(RecoveryFormat.duration(snapshot.asleepMinutes))
            .font(.title2.weight(.bold))
            .foregroundStyle(palette.textPrimary)
            .monospacedDigit()
        let title = Text(WeekFitLocalizedString("recovery.details.section.sleepTonight"))
            .font(.headline)
            .foregroundStyle(palette.textPrimary)
            .accessibilityAddTraits(.isHeader)

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                title
                duration
                sleepContext
            }
        } else {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    title
                    duration
                }
                Spacer(minLength: 8)
                sleepContext
            }
        }
    }

    @ViewBuilder
    private var sleepContext: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
            if let interval = sleepInterval {
                Text(interval)
                    .font(.subheadline)
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            }
            if snapshot.timeInBedMinutes > 0 {
                let caption = WeekFitLocalizedString("recovery.details.sleep.timeInBedCaption")
                let duration = RecoveryFormat.duration(snapshot.timeInBedMinutes)
                ViewThatFits(in: .horizontal) {
                    Text("\(caption) · \(duration)")
                        .lineLimit(1)
                    VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 0) {
                        Text(caption)
                        Text(duration)
                    }
                }
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var sleepInterval: String? {
        let bed = snapshot.bedStart.map { RecoveryFormat.time($0) }
        let wake = snapshot.wakeTime.map { RecoveryFormat.time($0) }
        switch (bed, wake) {
        case let (bed?, wake?):
            return "\(bed) – \(wake)"
        case let (bed?, nil):
            return "\(WeekFitLocalizedString("recovery.details.sleep.wentToBed")) \(bed)"
        case let (nil, wake?):
            return "\(WeekFitLocalizedString("recovery.details.sleep.wokeUp")) \(wake)"
        default:
            return nil
        }
    }

    private var stageBar: some View {
        let segments: [(Int, Color)] = [
            (snapshot.deepSleepMinutes, RecoveryStyle.deepBlue),
            (snapshot.remSleepMinutes, RecoveryStyle.purple),
            (snapshot.coreSleepMinutes, RecoveryStyle.recoveryColor.opacity(0.72))
        ]
        return GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    if segment.0 > 0 {
                        Rectangle()
                            .fill(segment.1)
                            .frame(width: proxy.size.width * CGFloat(segment.0) / CGFloat(stageTotal))
                    }
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private var stageRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            stageRow(
                title: WeekFitLocalizedString("recovery.details.sleep.stage.deep"),
                minutes: snapshot.deepSleepMinutes,
                color: RecoveryStyle.deepBlue
            )
            stageRow(
                title: WeekFitLocalizedString("recovery.details.sleep.stage.rem"),
                minutes: snapshot.remSleepMinutes,
                color: RecoveryStyle.purple
            )
            stageRow(
                title: WeekFitLocalizedString("recovery.details.sleep.stage.core"),
                minutes: snapshot.coreSleepMinutes,
                color: RecoveryStyle.recoveryColor.opacity(0.72)
            )
        }
    }

    private func stageRow(title: String, minutes: Int, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    dimensions.height * 0.8
                }
                .accessibilityHidden(true)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            Text(RecoveryFormat.measuredDuration(minutes))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .monospacedDigit()

            Text("\(displayPercent(minutes))%")
                .font(.caption)
                .foregroundStyle(palette.textSecondary)
                .monospacedDigit()
                .frame(minWidth: 40, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func displayPercent(_ minutes: Int) -> Int {
        guard stageTotal > 0 else { return 0 }
        return Int((Double(minutes) / Double(stageTotal) * 100).rounded())
    }

    @ViewBuilder
    private var footer: some View {
        let awake = HStack(spacing: 6) {
            Image(systemName: "eye")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RecoveryStyle.amber)
                .accessibilityHidden(true)
            Text(WeekFitLocalizedString("recovery.details.sleep.awake"))
            Text(RecoveryFormat.measuredDuration(snapshot.awakeMinutes))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.footnote)
        .foregroundStyle(palette.textPrimary)
        .accessibilityElement(children: .combine)

        let awakenings = HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
                .accessibilityHidden(true)
            Text(WeekFitLocalizedString("recovery.details.sleep.awakeMoments"))
            Text("\(snapshot.awakeningsCount)")
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.footnote)
        .foregroundStyle(palette.textPrimary)
        .accessibilityElement(children: .combine)

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                awake
                awakenings
            }
        } else {
            HStack(spacing: 10) {
                awake
                Rectangle()
                    .fill(palette.isLight ? WeekFitLightTokens.divider : WeekFitTheme.whiteOpacity(0.12))
                    .frame(width: 0.6, height: 14)
                awakenings
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Factors

private struct RecoveryFactorsCard: View {
    let snapshot: RecoveryDaySnapshot
    @Binding var showsAll: Bool

    @Environment(\.weekFitPalette) private var palette

    private var highlights: RecoveryFactorHighlights {
        RecoveryFactorHighlights.select(
            breakdown: snapshot.recoveryBreakdown,
            hasSleep: snapshot.asleepMinutes > 0
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(WeekFitLocalizedString("recovery.details.section.whatAffected"))
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if showsAll {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(RecoveryBreakdownSignal.displayedQualitySignals, id: \.self) { signal in
                        RecoveryFactorRow(
                            signal: signal,
                            grade: RecoveryFactorCopy.grade(for: signal, snapshot: snapshot),
                            role: role(for: signal),
                            showsScale: true
                        )
                    }
                }
            } else {
                highlightedRows
            }

            if showsAll {
                Text(WeekFitLocalizedString("recovery.details.score.explanation"))
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !snapshot.recoveryBreakdown.unavailableSignals.isEmpty {
                    Text(RecoveryFactorCopy.unavailableSignalsText(snapshot.recoveryBreakdown))
                        .font(.footnote)
                        .foregroundStyle(palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                showsAll.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text(
                        showsAll
                            ? WeekFitLocalizedString("recovery.details.factors.showLess")
                            : WeekFitLocalizedString("recovery.details.factors.showAll")
                    )
                    .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Image(systemName: showsAll ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(RecoveryStyle.recoveryColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recovery.details.factors.toggle")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .recoveryDetailsCard()
    }

    @ViewBuilder
    private var highlightedRows: some View {
        if highlights.supporting == nil && highlights.limiting == nil {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                if let supporting = highlights.supporting {
                    RecoveryFactorRow(
                        signal: supporting,
                        grade: RecoveryFactorCopy.grade(for: supporting, snapshot: snapshot),
                        role: .supporting
                    )
                }
                if let limiting = highlights.limiting {
                    RecoveryFactorRow(
                        signal: limiting,
                        grade: RecoveryFactorCopy.grade(for: limiting, snapshot: snapshot),
                        role: .limiting
                    )
                }
            }
        }
    }

    private func role(for signal: RecoveryBreakdownSignal) -> RecoveryFactorRole? {
        if highlights.supporting == signal { return .supporting }
        if highlights.limiting == signal { return .limiting }
        return nil
    }
}

private enum RecoveryFactorRole {
    case supporting
    case limiting
}

private struct RecoveryFactorRow: View {
    let signal: RecoveryBreakdownSignal
    let grade: Int?
    let role: RecoveryFactorRole?
    var showsScale = false

    @Environment(\.weekFitPalette) private var palette

    private var attributeColor: Color {
        RecoveryFactorCopy.color(for: signal)
    }

    private var scoreColor: Color {
        switch role {
        case .limiting:
            return RecoveryStyle.amber
        case .supporting:
            return RecoveryStyle.recoveryColor
        case nil:
            return attributeColor
        }
    }

    private var wellColor: Color {
        role == .limiting ? RecoveryStyle.amber : attributeColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: RecoveryFactorCopy.symbol(for: signal))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(grade == nil ? wellColor.opacity(0.45) : wellColor)
                    .frame(width: 28, height: 28)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(wellColor.opacity(palette.isLight ? 0.12 : 0.20))
                    }
                    .accessibilityHidden(true)

                Text(RecoveryFactorCopy.title(for: signal))
                    .font(.subheadline)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if let grade {
                    Text("\(grade)/\(RecoveryScoreBreakdown.maxQualityGrade)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(scoreColor)
                        .monospacedDigit()
                } else {
                    Text(WeekFitLocalizedString("recovery.details.metricUnavailable"))
                        .font(.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }

            if showsScale, let grade {
                RecoveryFactorScale(value: grade, color: attributeColor)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let name = RecoveryFactorCopy.title(for: signal)
        let value = grade.map { "\($0)/\(RecoveryScoreBreakdown.maxQualityGrade)" }
            ?? WeekFitLocalizedString("recovery.details.metricUnavailable")
        switch role {
        case .supporting:
            return "\(WeekFitLocalizedString("recovery.details.factors.supportedMark")). \(name). \(value)"
        case .limiting:
            return "\(WeekFitLocalizedString("recovery.details.factors.limitingMark")). \(name). \(value)"
        case nil:
            return "\(name). \(value)"
        }
    }
}

private struct RecoveryFactorScale: View {
    let value: Int
    let color: Color
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let progress = CGFloat(min(max(value, 0), RecoveryScoreBreakdown.maxQualityGrade))
                / CGFloat(RecoveryScoreBreakdown.maxQualityGrade)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.isLight ? WeekFitLightTokens.inactiveTrack : WeekFitTheme.whiteOpacity(0.10))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

// MARK: - Copy and color

enum RecoveryFactorCopy {
    static func heroExplanation(
        hasSleep: Bool,
        highlights: RecoveryFactorHighlights
    ) -> String? {
        let parts = [
            highlights.supporting.map(supportSentence),
            highlights.limiting.map(limitSentence)
        ].compactMap { $0 }
        guard !parts.isEmpty else {
            return hasSleep ? nil : WeekFitLocalizedString("recovery.empty.text")
        }
        return parts.joined(separator: " ")
    }

    static func supportSentence(_ signal: RecoveryBreakdownSignal) -> String {
        String(
            format: WeekFitLocalizedString("recovery.details.hero.supportsFormat"),
            title(for: signal)
        )
    }

    static func limitSentence(_ signal: RecoveryBreakdownSignal) -> String {
        switch signal {
        case .sleepDuration:
            return WeekFitLocalizedString("recovery.details.hero.limit.sleepDuration")
        case .sleepConsistency:
            return WeekFitLocalizedString("recovery.details.hero.limit.sleepConsistency")
        case .sleepContinuity:
            return WeekFitLocalizedString("recovery.details.hero.limit.sleepContinuity")
        case .sleepArchitecture:
            return WeekFitLocalizedString("recovery.details.hero.limit.sleepArchitecture")
        case .hrv:
            return WeekFitLocalizedString("recovery.details.hero.limit.hrv")
        case .restingHeartRate:
            return WeekFitLocalizedString("recovery.details.hero.limit.restingHeartRate")
        }
    }

    static func title(for signal: RecoveryBreakdownSignal) -> String {
        switch signal {
        case .sleepDuration:
            return WeekFitLocalizedString("recovery.details.breakdown.sleepDuration")
        case .sleepConsistency:
            return WeekFitLocalizedString("recovery.details.breakdown.sleepConsistency")
        case .sleepContinuity:
            return WeekFitLocalizedString("recovery.details.breakdown.sleepContinuity")
        case .sleepArchitecture:
            return WeekFitLocalizedString("recovery.details.breakdown.sleepArchitecture")
        case .hrv:
            return WeekFitLocalizedString("today.status.metric.hrv")
        case .restingHeartRate:
            return WeekFitLocalizedString("recovery.details.breakdown.restingHeartRate")
        }
    }

    static func grade(
        for signal: RecoveryBreakdownSignal,
        snapshot: RecoveryDaySnapshot
    ) -> Int? {
        let breakdown = snapshot.recoveryBreakdown
        switch signal {
        case .sleepDuration:
            guard snapshot.asleepMinutes > 0 else { return nil }
            return breakdown.sleepDurationGrade
        case .sleepConsistency:
            return breakdown.sleepConsistencyGrade
        case .sleepContinuity:
            return breakdown.sleepContinuityGrade
        case .sleepArchitecture:
            return breakdown.sleepArchitectureGrade
        case .hrv:
            return breakdown.hrvGrade
        case .restingHeartRate:
            return breakdown.restingHeartRateGrade
        }
    }

    static func symbol(for signal: RecoveryBreakdownSignal) -> String {
        switch signal {
        case .sleepDuration: return "moon.zzz.fill"
        case .sleepConsistency: return "clock.fill"
        case .sleepContinuity: return "waveform.path"
        case .sleepArchitecture: return "bed.double.fill"
        case .hrv: return "waveform.path.ecg"
        case .restingHeartRate: return "heart.fill"
        }
    }

    static func color(for signal: RecoveryBreakdownSignal) -> Color {
        switch signal {
        case .sleepDuration:
            return RecoveryStyle.recoveryColor
        case .sleepConsistency:
            return RecoveryStyle.purple
        case .sleepContinuity:
            return RecoveryStyle.blue
        case .sleepArchitecture:
            return RecoveryStyle.deepBlue
        case .hrv:
            return RecoveryStyle.recoveryColor
        case .restingHeartRate:
            return RecoveryStyle.red
        }
    }

    static func unavailableSignalsText(_ breakdown: RecoveryScoreBreakdown) -> String {
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
            case .bedtimeConsistency:
                return WeekFitLocalizedString("recovery.details.breakdown.sleepConsistency")
            case .sleepContinuity:
                return WeekFitLocalizedString("recovery.details.breakdown.sleepContinuity")
            }
        }
        return String(
            format: WeekFitLocalizedString("recovery.details.unavailableSignalsFormat"),
            labels.joined(separator: ", ")
        )
    }
}

private extension View {
    func recoveryDetailsCard() -> some View {
        modifier(RecoveryDetailsCardChrome())
    }
}

private struct RecoveryDetailsCardChrome: ViewModifier {
    @Environment(\.weekFitPalette) private var palette

    func body(content: Content) -> some View {
        content.healthDetailsSoftCard(
            isLight: palette.isLight,
            cornerRadius: 24,
            darkGlow: .clear
        )
    }
}
