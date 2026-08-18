import SwiftUI
import WeekFitWidgetShared

struct WeekFitWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme

    let entry: WeekFitWidgetEntry

    var body: some View {
        let _ = WeekFitWidgetCopy.applyLanguage(entry.snapshot.languageCode)
        Group {
            switch family {
            case .systemMedium:
                WeekFitMediumWidgetView(snapshot: entry.snapshot, colorScheme: colorScheme)
            default:
                WeekFitSmallWidgetView(snapshot: entry.snapshot, colorScheme: colorScheme)
            }
        }
        .containerBackground(for: .widget) {
            widgetCanvas
        }
        .widgetURL(WeekFitWidgetDeepLink.todayURL)
    }

    private var widgetCanvas: some View {
        LinearGradient(
            colors: [
                WeekFitWidgetPalette.background(for: colorScheme),
                WeekFitWidgetPalette.backgroundSecondary(for: colorScheme)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Small

struct WeekFitSmallWidgetView: View {
    let snapshot: WeekFitWidgetSnapshot
    let colorScheme: ColorScheme

    private var presentation: WeekFitSmallPresentation {
        .make(from: snapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                WeekFitMetricBlock(
                    title: WeekFitWidgetCopy.metricMoveTitle(),
                    value: WeekFitWidgetCopy.percentLabel(snapshot.activityProgress, enabled: snapshot.hasActivitySignal),
                    progress: snapshot.activityProgress,
                    color: WeekFitWidgetPalette.activity,
                    enabled: snapshot.hasActivitySignal,
                    colorScheme: colorScheme,
                    ringSize: 31,
                    lineWidth: 3.0,
                    valueFontSize: 10,
                    titleFontSize: 9,
                    style: .progress
                )
                WeekFitMetricBlock(
                    title: WeekFitWidgetCopy.metricFuelTitle(),
                    value: WeekFitWidgetCopy.percentLabel(snapshot.nutritionProgress, enabled: snapshot.hasNutritionSignal),
                    progress: snapshot.nutritionProgress,
                    color: WeekFitWidgetPalette.nutrition,
                    enabled: snapshot.hasNutritionSignal,
                    colorScheme: colorScheme,
                    ringSize: 31,
                    lineWidth: 3.0,
                    valueFontSize: 10,
                    titleFontSize: 9,
                    style: .progress
                )
                WeekFitMetricBlock(
                    title: WeekFitWidgetCopy.metricReadyTitle(),
                    value: snapshot.hasRecoverySignal
                        ? "\(WeekFitWidgetCopy.recoveryDisplay(score: snapshot.recoveryScore))%"
                        : "—",
                    progress: recoveryRingProgress,
                    color: WeekFitWidgetPalette.recovery,
                    enabled: snapshot.hasRecoverySignal,
                    colorScheme: colorScheme,
                    ringSize: 31,
                    lineWidth: 2.8,
                    valueFontSize: 10,
                    titleFontSize: 9,
                    style: .readiness
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.stateLabel.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.75)
                    .foregroundStyle(WeekFitWidgetPalette.modeTint(for: snapshot.dayMode))

                Text(presentation.hero)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .tracking(-0.3)
                    .foregroundStyle(WeekFitWidgetPalette.primaryText(for: colorScheme))

            }
            .padding(.top, 14)

            Spacer(minLength: 12)

            if presentation.showsNext {
                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.nextHeader.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(WeekFitWidgetPalette.tertiaryText(for: colorScheme))

                    HStack(spacing: 5) {
                        Image(systemName: WeekFitWidgetCopy.nextActionIcon(for: presentation.nextKind))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(goldAccent)
                        Text(presentation.nextTitle)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(WeekFitWidgetPalette.primaryText(for: colorScheme))
                    }
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.top, 13)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var goldAccent: Color {
        colorScheme == .dark ? WeekFitWidgetPalette.brandGold : WeekFitWidgetPalette.brandGoldDark
    }

    private var recoveryRingProgress: Double {
        guard let score = snapshot.recoveryScore else { return 0 }
        return Double(score) / 100.0
    }
}

// MARK: - Medium

struct WeekFitMediumWidgetView: View {
    let snapshot: WeekFitWidgetSnapshot
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leftColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Rectangle()
                .fill(WeekFitWidgetPalette.hairline(for: colorScheme))
                .frame(width: 1)
                .padding(.vertical, 2)
                .padding(.horizontal, 12)

            nextColumn
                .frame(width: 116, alignment: .topLeading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(WeekFitWidgetCopy.dayModeTitle(snapshot.dayMode).uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(WeekFitWidgetPalette.modeTint(for: snapshot.dayMode))

            Text(headline)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .tracking(-0.45)
                .foregroundStyle(WeekFitWidgetPalette.primaryText(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)

            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitWidgetPalette.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                WeekFitMetricBlock(
                    title: WeekFitWidgetCopy.metricMoveTitle(),
                    value: WeekFitWidgetCopy.percentLabel(snapshot.activityProgress, enabled: snapshot.hasActivitySignal),
                    progress: snapshot.activityProgress,
                    color: WeekFitWidgetPalette.activity,
                    enabled: snapshot.hasActivitySignal,
                    colorScheme: colorScheme
                )
                WeekFitMetricBlock(
                    title: WeekFitWidgetCopy.metricFuelTitle(),
                    value: WeekFitWidgetCopy.percentLabel(snapshot.nutritionProgress, enabled: snapshot.hasNutritionSignal),
                    progress: snapshot.nutritionProgress,
                    color: WeekFitWidgetPalette.nutrition,
                    enabled: snapshot.hasNutritionSignal,
                    colorScheme: colorScheme
                )
                WeekFitMetricBlock(
                    title: WeekFitWidgetCopy.metricReadyTitle(),
                    value: snapshot.hasRecoverySignal
                        ? "\(WeekFitWidgetCopy.recoveryDisplay(score: snapshot.recoveryScore))%"
                        : "—",
                    progress: recoveryRingProgress,
                    color: WeekFitWidgetPalette.recovery,
                    enabled: snapshot.hasRecoverySignal,
                    colorScheme: colorScheme
                )
            }
        }
    }

    private var nextColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(WeekFitWidgetCopy.mediumNextSectionTitle(phase: snapshot.nextActionPhase).uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(WeekFitWidgetPalette.tertiaryText(for: colorScheme))

            if snapshot.hasNextAction {
                ZStack {
                    Circle()
                        .fill(WeekFitWidgetPalette.brandGold.opacity(colorScheme == .dark ? 0.20 : 0.16))
                        .frame(width: 32, height: 32)
                    Image(systemName: WeekFitWidgetCopy.nextActionIcon(for: snapshot.nextActionKind))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(goldAccent)
                }
                .padding(.top, 10)

                Text(nextTitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tracking(-0.2)
                    .foregroundStyle(WeekFitWidgetPalette.primaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                if !nextMeta.isEmpty {
                    Text(nextMeta)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(goldAccent)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            } else {
                Text("Nothing queued")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitWidgetPalette.secondaryText(for: colorScheme))
                    .padding(.top, 12)
            }

            Spacer(minLength: 0)

            if snapshot.totalItems > 0 {
                Text(snapshot.progressSummary)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitWidgetPalette.tertiaryText(for: colorScheme))
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var goldAccent: Color {
        colorScheme == .dark ? WeekFitWidgetPalette.brandGold : WeekFitWidgetPalette.brandGoldDark
    }

    private var headline: String {
        WeekFitWidgetCopy.mediumHeadline(raw: snapshot.dayGuidance, mode: snapshot.dayMode)
    }

    private var detail: String {
        WeekFitWidgetCopy.mediumDetail(raw: snapshot.dayGuidanceDetail, mode: snapshot.dayMode)
    }

    private var nextTitle: String {
        WeekFitWidgetCopy.mediumNextTitle(
            raw: snapshot.nextActionTitle,
            kind: snapshot.nextActionKind
        )
    }

    private var nextMeta: String {
        // Builder may already compose subtitle as the full meta line.
        if snapshot.nextActionTime == nil,
           let subtitle = Optional(snapshot.nextActionSubtitle),
           !subtitle.isEmpty,
           subtitle.contains("·") || subtitle.contains("min") {
            return WeekFitWidgetCopy.mediumNextMeta(subtitle: subtitle, time: nil)
        }
        return WeekFitWidgetCopy.mediumNextMeta(
            subtitle: snapshot.nextActionSubtitle,
            time: snapshot.nextActionTime
        )
    }

    private var recoveryRingProgress: Double {
        guard let score = snapshot.recoveryScore else { return 0 }
        return Double(score) / 100.0
    }
}

// MARK: - Shared chrome

private struct WeekFitMetricBlock: View {
    enum Style {
        case progress
        case readiness
    }

    let title: String
    let value: String
    let progress: Double
    let color: Color
    let enabled: Bool
    let colorScheme: ColorScheme
    var ringSize: CGFloat = 44
    var lineWidth: CGFloat = 4.2
    var valueFontSize: CGFloat? = nil
    var titleFontSize: CGFloat = 10
    var style: Style = .progress

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(fillOpacity))
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .stroke(
                        WeekFitWidgetPalette.track(for: colorScheme),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: enabled ? WeekFitWidgetSnapshot.clamp01(progress) : 0)
                    .stroke(
                        AngularGradient(
                            colors: gradientColors,
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))

                Text(displayValue)
                    .font(.system(size: resolvedValueFontSize, weight: .bold, design: .rounded))
                    .tracking(-0.3)
                    .foregroundStyle(enabled ? WeekFitWidgetPalette.primaryText(for: colorScheme) : WeekFitWidgetPalette.secondaryText(for: colorScheme))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
            }

            Text(title)
                .font(.system(size: titleFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitWidgetPalette.secondaryText(for: colorScheme))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var fillOpacity: Double {
        guard enabled else { return 0.05 }
        if style == .readiness {
            return colorScheme == .dark ? 0.12 : 0.08
        }
        return colorScheme == .dark ? 0.16 : 0.11
    }

    private var gradientColors: [Color] {
        if style == .readiness {
            return [
                color.opacity(0.55),
                color.opacity(0.92),
                color.opacity(0.70)
            ]
        }
        return [
            color.opacity(0.70),
            color,
            color.opacity(0.88)
        ]
    }

    /// Keep `%` visible for Move / Fuel / Ready; drop it only for 100% so “100%” still fits.
    private var displayValue: String {
        guard enabled else { return "—" }
        if value == "100%" { return "100" }
        return value
    }

    private var resolvedValueFontSize: CGFloat {
        if let valueFontSize { return valueFontSize }
        return displayValue.count >= 4 ? 11 : 13
    }
}

#if DEBUG
private struct SmallPreviewHost: View {
    let entry: WeekFitWidgetEntry
    let scheme: ColorScheme

    var body: some View {
        WeekFitWidgetEntryView(entry: entry)
            .frame(width: 158, height: 158)
            .environment(\.colorScheme, scheme)
            .preferredColorScheme(scheme)
    }
}

#Preview("Small A · Good · Light") {
    SmallPreviewHost(entry: .smallGoodToGo(), scheme: .light)
}

#Preview("Small A · Good · Dark") {
    SmallPreviewHost(entry: .smallGoodToGo(), scheme: .dark)
}

#Preview("Small B · Before Sauna · Light") {
    SmallPreviewHost(entry: .smallBeforeSauna(), scheme: .light)
}

#Preview("Small B · Before Sauna · Dark") {
    SmallPreviewHost(entry: .smallBeforeSauna(), scheme: .dark)
}

#Preview("Small C · Take It Easy · Light") {
    SmallPreviewHost(entry: .smallTakeItEasy(), scheme: .light)
}

#Preview("Small C · Take It Easy · Dark") {
    SmallPreviewHost(entry: .smallTakeItEasy(), scheme: .dark)
}

#Preview("Small D · All Clear · Light") {
    SmallPreviewHost(entry: .smallAllClear(), scheme: .light)
}

#Preview("Small D · All Clear · Dark") {
    SmallPreviewHost(entry: .smallAllClear(), scheme: .dark)
}

#Preview("Medium · Easy") {
    WeekFitWidgetEntryView(entry: .smallTakeItEasy())
        .frame(width: 338, height: 158)
}

#Preview("Medium · Empty") {
    WeekFitWidgetEntryView(entry: .smallAllClear())
        .frame(width: 338, height: 158)
}
#endif
