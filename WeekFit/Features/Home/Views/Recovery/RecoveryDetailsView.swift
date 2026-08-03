import SwiftUI
import HealthKit
internal import Combine

struct RecoveryDetailsView: View {

    let selectedDate: Date

    @StateObject private var viewModel = RecoveryDetailsViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var languageManager: AppLanguageManager
    @EnvironmentObject private var healthManager: HealthManager
    @State private var activeDate: Date
    @State private var didRecordRecoveryDetailsView = false
    @State private var didRecordStressIndexView = false
    @State private var showStressIndexSheet = false

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
            (palette.isLight ? HealthDetailsSoftChrome.canvas : RecoveryStyle.screenBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if palette.isLight {
                    NutritionDetailsHeader(
                        title: WeekFitLocalizedString("recovery.details.title"),
                        subtitle: recoveryDetailsDateTitle,
                        onClose: { dismiss() }
                    )

                    NutritionWeekSelector(
                        selectedDate: $activeDate,
                        accentColor: WeekFitLightTokens.recovery
                    ) { _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .padding(.horizontal, HealthDetailsSoftChrome.horizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                } else {
                    header

                    HealthDetailsWeekPicker(
                        selectedDate: $activeDate,
                        accentColor: RecoveryStyle.recoveryColor
                    ) { _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 9)
                    .padding(.bottom, 8)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: palette.isLight ? HealthDetailsSoftChrome.sectionSpacing : 9) {
                        RecoveryHeroCard(snapshot: viewModel.snapshot)
                        StressIndexCompactCard(
                            result: viewModel.stressIndex,
                            bedtimeDeviationMinutes: viewModel.snapshot.recoveryInput?.bedtimeDeviationMinutes
                        ) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showStressIndexSheet = true
                            AppAnalytics.shared.track(.stressIndexDetailsOpened)
                        }
                        RecoveryVitalsCard(snapshot: viewModel.snapshot)
                        RecoveryBreakdownCard(snapshot: viewModel.snapshot)
                        SleepDetailsCard(snapshot: viewModel.snapshot)
                        SleepStagesCard(snapshot: viewModel.snapshot)
                    }
                    .padding(.horizontal, palette.isLight ? HealthDetailsSoftChrome.horizontalPadding : 18)
                    .padding(.top, palette.isLight ? 8 : 5)
                    .padding(.bottom, palette.isLight ? 24 : 36)
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .tint(palette.isLight ? WeekFitLightTokens.recovery : .white.opacity(0.75))
            }
        }
        .navigationBarBackButtonHidden(true)
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
        .sheet(isPresented: $showStressIndexSheet) {
            StressIndexDetailSheet(
                result: viewModel.stressIndex,
                recoveryScore: viewModel.snapshot.recoveryScore
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func load(date: Date) async {
        await viewModel.load(for: date, healthManager: healthManager)
        // Engagement is based on opening Recovery after Health processing — never on score values.
        guard !didRecordRecoveryDetailsView, !viewModel.authorizationFailed else { return }
        didRecordRecoveryDetailsView = true
        ReviewEngagement.record(.recoveryDetailsViewed)

        if !didRecordStressIndexView {
            didRecordStressIndexView = true
            AppAnalytics.shared.track(.stressIndexViewed)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text(WeekFitLocalizedString("recovery.details.title"))
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(recoveryDetailsDateTitle)
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
    @Environment(\.weekFitPalette) private var palette

    private var progress: CGFloat {
        CGFloat(min(max(snapshot.recoveryScore, 0), 100)) / 100
    }

    var body: some View {
        HStack(spacing: palette.isLight ? 12 : 15) {
            recoveryRing

            VStack(alignment: .leading, spacing: palette.isLight ? 4 : 5) {
                Text(WeekFitLocalizedString("recovery.details.score.title").uppercased())
                    .font(
                        palette.isLight
                            ? NutritionDetailsDesign.Typography.eyebrow
                            : .system(size: 10, weight: .bold, design: .rounded)
                    )
                    .tracking(palette.isLight ? 0.6 : 1.8)
                    .foregroundStyle(
                        palette.isLight ? WeekFitLightTokens.recovery : RecoveryStyle.recoveryColor
                    )

                Text(statusText)
                    .font(
                        palette.isLight
                            ? NutritionDetailsDesign.Typography.insight
                            : .system(size: RecoveryTypography.heroTitle, weight: .bold, design: .rounded)
                    )
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(snapshot.insightText)
                    .font(
                        palette.isLight
                            ? NutritionDetailsDesign.Typography.metricSecondary
                            : .system(size: RecoveryTypography.heroText, weight: .medium, design: .rounded)
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
            darkGlow: RecoveryStyle.recoveryColor
        )
    }

    private var recoveryRing: some View {
        WeekFitProgressRing(
            progress: progress,
            color: WeekFitProgressRingColor.recovery,
            size: palette.isLight ? 58 : 70,
            strokeWidth: palette.isLight ? 4.5 : 4,
            gradientColors: [
                WeekFitProgressRingColor.recovery.opacity(0.80),
                WeekFitProgressRingColor.recovery,
                Color(red: 0.28, green: 0.92, blue: 1.00),
                WeekFitProgressRingColor.recovery.opacity(0.94)
            ]
        ) {
            VStack(spacing: -2) {
                Text("\(snapshot.recoveryScore)")
                    .font(
                        palette.isLight
                            ? NutritionDetailsDesign.Typography.score
                            : .system(size: RecoveryTypography.heroScore, weight: .bold, design: .rounded)
                    )
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .monospacedDigit()

                Text(WeekFitLocalizedString("common.unit.score"))
                    .font(
                        palette.isLight
                            ? NutritionDetailsDesign.Typography.scoreDenom
                            : .system(size: RecoveryTypography.heroScoreLabel, weight: .bold, design: .rounded)
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

// MARK: - Stress Index

private struct StressIndexCompactCard: View {
    let result: StressIndexResult
    var bedtimeDeviationMinutes: Int? = nil
    let onTap: () -> Void
    @Environment(\.weekFitPalette) private var palette

    private var accentColor: Color {
        StressIndexStyle.color(for: result.level, confidence: result.confidence)
    }

    private var softFill: Color {
        guard palette.isLight else {
            return HealthDetailsSoftChrome.cardSurface
        }
        return StressIndexStyle.softFill(for: result.level, confidence: result.confidence)
    }

    private var contributorLabels: [String] {
        StressIndexCopy.compactContributorLabels(
            for: result,
            bedtimeDeviationMinutes: bedtimeDeviationMinutes
        )
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                topRow
                scoreRow

                if result.confidence != .unavailable {
                    Text(StressIndexCopy.compactInterpretation(for: result))
                        .font(
                            palette.isLight
                                ? NutritionDetailsDesign.Typography.metricSecondary
                                : .system(size: RecoveryTypography.helperText, weight: .medium, design: .rounded)
                        )
                        .foregroundStyle(
                            palette.isLight
                                ? WeekFitLightTokens.textSecondary
                                : WeekFitTheme.whiteOpacity(0.52)
                        )
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !contributorLabels.isEmpty {
                        contributorsRow
                    }
                } else {
                    Text(StressIndexCopy.compactInterpretation(for: result))
                        .font(.system(size: RecoveryTypography.helperText, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            palette.isLight
                                ? WeekFitLightTokens.textSecondary
                                : WeekFitTheme.whiteOpacity(0.48)
                        )
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, palette.isLight ? 14 : 16)
            .padding(.vertical, palette.isLight ? 13 : 14)
            .healthDetailsSoftCard(
                isLight: palette.isLight,
                fill: softFill,
                darkGlow: accentColor.opacity(0.45)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
        .accessibilityAddTraits(.isButton)
    }

    private var topRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(WeekFitLocalizedString("recovery.stressIndex.title").uppercased())
                .font(
                    palette.isLight
                        ? NutritionDetailsDesign.Typography.eyebrow
                        : .system(size: 10, weight: .bold, design: .rounded)
                )
                .tracking(palette.isLight ? 0.6 : 1.4)
                .foregroundStyle(accentColor.opacity(0.92))

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    palette.isLight
                        ? WeekFitLightTokens.textQuaternary
                        : WeekFitTheme.whiteOpacity(0.28)
                )
        }
    }

    @ViewBuilder
    private var scoreRow: some View {
        switch result.confidence {
        case .unavailable:
            Text(WeekFitLocalizedString("recovery.stressIndex.empty.title"))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    palette.isLight
                        ? WeekFitLightTokens.textPrimary
                        : WeekFitTheme.whiteOpacity(0.78)
                )
                .lineLimit(1)

        case .low:
            if let level = result.level {
                Text(StressIndexCopy.levelTitle(level))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
            }

        case .medium, .high:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let score = result.score {
                    Text("\(score)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            palette.isLight
                                ? WeekFitLightTokens.textPrimary
                                : WeekFitTheme.primaryText
                        )
                        .monospacedDigit()
                        .tracking(-0.8)
                }

                if let level = result.level {
                    Text(StressIndexCopy.levelTitle(level))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.bottom, 2)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var contributorsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(contributorLabels.enumerated()), id: \.offset) { _, label in
                HStack(alignment: .center, spacing: 7) {
                    Circle()
                        .fill(accentColor.opacity(0.55))
                        .frame(width: 4, height: 4)

                    Text(label)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            palette.isLight
                                ? WeekFitLightTokens.textPrimary.opacity(0.82)
                                : WeekFitTheme.whiteOpacity(0.70)
                        )
                        .lineLimit(1)
                }
            }
        }
        .padding(.top, 1)
    }

    private var accessibilitySummary: String {
        var parts = [StressIndexCopy.accessibilityLabel(for: result)]
        parts.append(contentsOf: contributorLabels)
        return parts.joined(separator: ". ")
    }
}

private struct StressIndexDetailSheet: View {
    let result: StressIndexResult
    let recoveryScore: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showCalculationSheet = false

    private var accent: Color {
        StressIndexStyle.color(for: result.level, confidence: result.confidence)
    }

    private var topDrivers: [StressIndexContributor] {
        Array(result.contributors.prefix(2))
    }

    private var canShowDrivers: Bool {
        !topDrivers.isEmpty && result.confidence != .unavailable
    }

    var body: some View {
        ZStack {
            RecoveryStyle.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    sheetHeader
                    heroCard

                    if result.confidence != .unavailable {
                        meaningCard
                    } else {
                        unavailableMeaningCard
                    }

                    if canShowDrivers {
                        driversCard
                    }

                    confidenceCard

                    calculationRow

                    Text(WeekFitLocalizedString("recovery.stressIndex.disclaimer"))
                        .font(.system(size: RecoveryTypography.helperText, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.42))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                        .accessibilitySortPriority(-1)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showCalculationSheet) {
            StressIndexCalculationSheet(
                usedKinds: result.usedSignalKinds.isEmpty
                    ? [.hrv, .restingHeartRate, .sleep, .trainingLoad]
                    : result.usedSignalKinds
            )
            .presentationDetents([.medium])
        }
    }

    private var sheetHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(WeekFitLocalizedString("recovery.stressIndex.title"))
                .font(.system(size: RecoveryTypography.stressSheetTitle, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            WeekFitCloseButton(
                size: .large,
                playsHaptic: false,
                accessibilityLabel: WeekFitLocalizedString("recovery.stressIndex.close.a11y")
            ) {
                dismiss()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch result.confidence {
            case .unavailable:
                Text(WeekFitLocalizedString("recovery.stressIndex.empty.title"))
                    .font(.system(size: RecoveryTypography.stressSectionTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)

                Text(WeekFitLocalizedString("recovery.stressIndex.empty.supporting"))
                    .font(.system(size: RecoveryTypography.stressBody, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.62))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

            case .low:
                if let level = result.level {
                    Text(StressIndexCopy.levelTitle(level))
                        .font(.system(size: RecoveryTypography.stressScore, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .accessibilityLabel(
                            Text("\(WeekFitLocalizedString("recovery.stressIndex.title")), \(StressIndexCopy.levelTitle(level).lowercased()).")
                        )
                }

                Text(WeekFitLocalizedString("recovery.stressIndex.confidence.low.summary"))
                    .font(.system(size: RecoveryTypography.stressBody, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.62))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

            case .medium, .high:
                scoreAndLevelRow
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(StressIndexCopy.accessibilityLabel(for: result)))

                Text(StressIndexCopy.summarySentence(for: result))
                    .font(.system(size: RecoveryTypography.stressBody, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.64))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .recoveryCard(glow: accent.opacity(0.40))
    }

    @ViewBuilder
    private var scoreAndLevelRow: some View {
        let scoreText = result.score.map(String.init) ?? ""
        let levelText = result.level.map(StressIndexCopy.levelTitle) ?? ""

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                Text(scoreText)
                    .font(.system(size: RecoveryTypography.stressScore, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .monospacedDigit()

                Text(levelText)
                    .font(.system(size: RecoveryTypography.stressLevel, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
            }
        } else {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(scoreText)
                    .font(.system(size: RecoveryTypography.stressScore, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .monospacedDigit()

                Text(levelText)
                    .font(.system(size: RecoveryTypography.stressLevel, weight: .semibold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }

    private var meaningCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(WeekFitLocalizedString("recovery.stressIndex.sheet.meaningTitle"))
                .font(.system(size: RecoveryTypography.stressSectionTitle, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)

            Text(StressIndexCopy.meaningBody(for: result, recoveryScore: recoveryScore))
                .font(.system(size: RecoveryTypography.stressBody, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.62))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .recoveryCard()
    }

    private var unavailableMeaningCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(WeekFitLocalizedString("recovery.stressIndex.sheet.meaningTitle"))
                .font(.system(size: RecoveryTypography.stressSectionTitle, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)

            Text(WeekFitLocalizedString("recovery.stressIndex.meaning.unavailable"))
                .font(.system(size: RecoveryTypography.stressBody, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.62))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .recoveryCard()
    }

    private var driversCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(WeekFitLocalizedString("recovery.stressIndex.sheet.driversTitle"))
                .font(.system(size: RecoveryTypography.stressSectionTitle, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(topDrivers, id: \.kind) { contributor in
                    contributorRow(contributor)
                }
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .recoveryCard()
    }

    private func contributorRow(_ contributor: StressIndexContributor) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: driverSymbol(for: contributor.tone))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(toneColor(contributor.tone))
                .frame(width: 22, height: 22)
                .background {
                    Circle().fill(toneColor(contributor.tone).opacity(0.16))
                }
                .accessibilityLabel(Text(StressIndexCopy.iconAccessibilityLabel(for: contributor.tone)))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(StressIndexCopy.contributorHeadline(for: contributor))
                        .font(.system(size: RecoveryTypography.stressSecondary, weight: .semibold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Text(StressIndexCopy.impactTitle(contributor.impact))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(toneColor(contributor.tone).opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Text(StressIndexCopy.contributorDetail(for: contributor))
                    .font(.system(size: RecoveryTypography.helperText, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.56))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(StressIndexCopy.contributorAccessibilityLabel(for: contributor)))
    }

    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(WeekFitLocalizedString("recovery.stressIndex.sheet.confidenceTitle"))
                .font(.system(size: RecoveryTypography.stressSectionTitle, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)

            Text(StressIndexCopy.confidenceTitle(result.confidence))
                .font(.system(size: RecoveryTypography.stressSecondary, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.88))

            Text(
                StressIndexCopy.confidenceExplanation(
                    result.confidence,
                    baselineSampleDays: result.baselineSampleDays
                )
            )
            .font(.system(size: RecoveryTypography.helperText, weight: .medium, design: .rounded))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.54))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .recoveryCard()
    }

    private var calculationRow: some View {
        Button {
            showCalculationSheet = true
        } label: {
            HStack(spacing: 10) {
                Text(WeekFitLocalizedString("recovery.stressIndex.sheet.calculationTitle"))
                    .font(.system(size: RecoveryTypography.stressSecondary, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.88))

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.32))
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .recoveryCard()
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(WeekFitLocalizedString("recovery.stressIndex.calculation.a11yHint")))
    }

    private func driverSymbol(for tone: StressIndexContributorTone) -> String {
        switch tone {
        case .elevating:
            return "arrow.up"
        case .neutral:
            return "minus"
        case .stabilizing:
            return "arrow.down"
        }
    }

    private func toneColor(_ tone: StressIndexContributorTone) -> Color {
        switch tone {
        case .elevating:
            return StressIndexStyle.elevated
        case .neutral:
            return StressIndexStyle.moderate
        case .stabilizing:
            return StressIndexStyle.low
        }
    }
}

private struct StressIndexCalculationSheet: View {
    let usedKinds: [StressIndexContributorKind]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RecoveryStyle.screenBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Text(WeekFitLocalizedString("recovery.stressIndex.sheet.calculationTitle"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    WeekFitCloseButton(
                        size: .large,
                        playsHaptic: false,
                        accessibilityLabel: WeekFitLocalizedString("recovery.stressIndex.close.a11y")
                    ) {
                        dismiss()
                    }
                }

                Text(StressIndexCopy.calculationBody(usedKinds: usedKinds))
                    .font(.system(size: RecoveryTypography.stressBody, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.64))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(WeekFitLocalizedString("recovery.stressIndex.calculation.vsRecovery"))
                    .font(.system(size: RecoveryTypography.stressSecondary, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
    }
}

private enum StressIndexStyle {
    static let low = WeekFitTheme.accent(Color(red: 0.42, green: 0.66, blue: 0.58))
    static let moderate = WeekFitTheme.accent(Color(red: 0.86, green: 0.68, blue: 0.40))
    static let elevated = WeekFitTheme.accent(Color(red: 0.90, green: 0.58, blue: 0.36))
    static let high = WeekFitTheme.accent(Color(red: 0.88, green: 0.48, blue: 0.44))
    static let unavailable = WeekFitTheme.whiteOpacity(0.42)

    /// Very soft semantic washes — calm, never alarming blocks.
    static let softLow = Color(red: 0.925, green: 0.960, blue: 0.942)
    static let softModerate = Color(red: 0.985, green: 0.960, blue: 0.925)
    static let softElevated = Color(red: 0.988, green: 0.945, blue: 0.922)
    static let softHigh = Color(red: 0.985, green: 0.938, blue: 0.935)

    static func color(for level: StressIndexLevel?, confidence: StressIndexConfidence) -> Color {
        guard confidence != .unavailable, let level else { return unavailable }
        switch level {
        case .low: return low
        case .moderate: return moderate
        case .elevated: return elevated
        case .high: return high
        }
    }

    static func softFill(for level: StressIndexLevel?, confidence: StressIndexConfidence) -> Color {
        guard confidence != .unavailable, let level else {
            return HealthDetailsSoftChrome.cardSurface
        }
        switch level {
        case .low: return softLow
        case .moderate: return softModerate
        case .elevated: return softElevated
        case .high: return softHigh
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
        .recoveryCard(glow: RecoveryStyle.recoveryColor)
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
        .healthDetailsNestedTile(isLight: WeekFitPaletteStore.current.isLight)
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
        .recoveryCard(glow: RecoveryStyle.purple)
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
        .healthDetailsNestedTile(isLight: WeekFitPaletteStore.current.isLight)
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
        HealthDetailsSectionTitle(text: text)
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

    static let stressSheetTitle: CGFloat = 24
    static let stressScore: CGFloat = 40
    static let stressLevel: CGFloat = 17
    static let stressSectionTitle: CGFloat = 15.5
    static let stressBody: CGFloat = 14.5
    static let stressSecondary: CGFloat = 13.5
}

private enum RecoveryStyle {
    static var screenBackground: Color { WeekFitTheme.appScreenBackground }
    static var cardBackground: Color { WeekFitTheme.cardSurface }
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
        modifier(RecoveryCardChrome(cornerRadius: cornerRadius, glow: glow))
    }
}

private struct RecoveryCardChrome: ViewModifier {
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
                    .fill(WeekFitPaletteStore.current.isLight ? WeekFitLightTokens.inactiveTrack : WeekFitTheme.whiteOpacity(0.085))

                Capsule()
                    .fill(color)
                    .frame(width: max(6, proxy.size.width * progress))
            }
        }
    }
}
