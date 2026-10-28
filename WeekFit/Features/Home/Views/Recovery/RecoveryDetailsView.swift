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

        RecoveryDetailsScrollScreen(
            activeDate: $activeDate,
            snapshot: viewModel.snapshot,
            stressIndex: viewModel.stressIndex,
            isLoading: viewModel.isLoading,
            onClose: { dismiss() },
            onOpenStress: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showStressIndexSheet = true
                AppAnalytics.shared.track(.stressIndexDetailsOpened)
            }
        )
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
        .fullScreenCover(isPresented: $showStressIndexSheet) {
            StressIndexDetailSheet(
                result: viewModel.stressIndex,
                recoveryScore: viewModel.snapshot.recoveryScore
            )
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

enum StressIndexStyle {
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

enum RecoveryStyle {
    static var screenBackground: Color { WeekFitTheme.appScreenBackground }
    static var cardBackground: Color { WeekFitTheme.cardSurface }
    static var border: Color { WeekFitTheme.border }

    static var recoveryColor: Color { WeekFitProgressRingColor.recovery }
    static var blue: Color { WeekFitTheme.accent(Color(red: 0.30, green: 0.72, blue: 0.95)) }
    static var deepBlue: Color { WeekFitTheme.accent(Color(red: 0.22, green: 0.42, blue: 0.95)) }
    static var purple: Color { WeekFitTheme.accent(Color(red: 0.58, green: 0.40, blue: 0.95)) }
    static var amber: Color { WeekFitTheme.accent(Color(red: 0.92, green: 0.68, blue: 0.30)) }
    static var red: Color { WeekFitTheme.accent(Color(red: 0.96, green: 0.42, blue: 0.42)) }
}

enum RecoveryFormat {
    /// Known measurement, including a real zero. Missing values stay an em dash via `duration`.
    static func measuredDuration(_ minutes: Int) -> String {
        if minutes <= 0 {
            return String(format: WeekFitLocalizedString("common.duration.minutesShortFormat"), 0)
        }
        return duration(minutes)
    }

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
