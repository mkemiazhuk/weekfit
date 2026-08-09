import SwiftUI

struct ExpertCoachView: View {

    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Environment(\.tabIsActive) private var tabIsActive

    @StateObject private var userSettings = WeekFitUserSettings.shared

    @State private var showProfile = false
    @State private var keepCoachMounted = false
    @State private var didRecordCoachRecommendationOpen = false
    @AppStorage(OnboardingStore.Keys.introCoach) private var coachIntroDismissed = false
    #if DEBUG
    @State private var showBeliefDebug = false
    #endif

    private let coachContentHorizontalInset: CGFloat = 0

    private let cardBackground = WeekFitTheme.cardBackground
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText

    init(authViewModel: AuthViewModel) {
        _ = authViewModel
    }

    var body: some View {
        Group {
            if tabIsActive || keepCoachMounted {
                activeCoachBody
                    .opacity(tabIsActive ? 1 : 0)
                    .allowsHitTesting(tabIsActive)
                    .accessibilityHidden(!tabIsActive)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            keepCoachMounted = true
        }
    }

    @ViewBuilder
    private var activeCoachBody: some View {
        let _ = languageManager.selectedLanguage

        ZStack(alignment: .top) {
            // Root already paints `appScreenBackground` + tab ambient.
            // Do not add a second canvas — ScrollView must show through to the same plane.
            WeekFitScreenContainer {
                WeekFitScreenHeader(
                    title: WeekFitLocalizedString("common.tab.coach"),
                    subtitle: selectedDateTitle,
                    initials: userSettings.profileInitials,
                    hasProfileName: userSettings.hasProfileName,
                    showAvatar: true
                ) {
                    showProfile = true
                }
            } content: {
                coachContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(WeekFitTheme.appScreenBackground)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.coach")
        .weekFitSettingsSheet(isPresented: $showProfile)
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            Button {
                showBeliefDebug = true
            } label: {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.coachAccent)
                    .padding(11)
                    .background {
                        Circle()
                            .fill(WeekFitLightTokens.coachPurpleSoft)
                            .overlay {
                                Circle()
                                    .stroke(WeekFitTheme.coachAccent.opacity(0.28), lineWidth: 1)
                            }
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
            }
            .padding(.trailing, WeekFitScreenLayout.horizontalPadding)
            .padding(.bottom, WeekFitScreenLayout.tabBarClearance + 18)
            .accessibilityIdentifier("coach.beliefDebug")
        }
        .sheet(isPresented: $showBeliefDebug) {
            NavigationStack {
                CoachBeliefDebugView(coachState: coachCoordinator.state)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        #endif
    }

    // MARK: - Coach State

    private var coachState: CoachState {
        coachCoordinator.state
    }

    private var coachUIPresentation: CoachUIPresentation? {
        coachState.coachUIPresentation
    }

    private var isRegistryGap: Bool {
        coachState.todayCoachInsightHiddenReason == .registryGap
    }

    private var shouldSurfaceCoach: Bool {
        coachState.hasValidGuidance
    }

    private var selectedDateTitle: String {
        WeekFitShortWeekdayMonthDay(Date())
    }

    private var shouldShowHealthConnectPrompt: Bool {
        !hasTodayRecoverySignals &&
        !healthManager.isHealthAccessGranted &&
        (
            healthManager.isHealthAuthorizationInFlight ||
            !healthManager.isHealthAccessRequested ||
            healthManager.hasCompletedHealthAccessCheck
        )
    }

    private var hasTodayRecoverySignals: Bool {
        healthManager.sleepMinutes > 0 ||
        healthManager.timeInBedMinutes > 0 ||
        healthManager.hrvSDNN > 0 ||
        healthManager.restingHeartRate > 0
    }

    private var shouldShowCoachPreparingState: Bool {
        hasTodayRecoverySignals &&
            coachState.todayCoachInsightHiddenReason == .settling
    }

    private var coachUnavailableTitleKey: String {
        if shouldShowHealthConnectPrompt {
            return "coach.unavailable.title"
        }
        if !hasTodayRecoverySignals {
            return "today.coach.settling.title"
        }
        return "coach.unavailable.sleepSync.title"
    }

    private var coachUnavailableMessageKey: String {
        if shouldShowHealthConnectPrompt {
            return "coach.unavailable.message"
        }
        if !hasTodayRecoverySignals {
            return "today.coach.settling.message.sleep"
        }
        return "coach.unavailable.sleepSync.message"
    }

    // MARK: - Coach Content

    private var coachContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .center, spacing: WeekFitScreenLayout.rootSpacing) {
                if !coachIntroDismissed {
                    OnboardingContextualIntroCard(
                        title: WeekFitLocalizedString("onboarding.intro.coach.title"),
                        message: WeekFitLocalizedString("onboarding.intro.coach.body"),
                        accent: WeekFitTheme.coachAccent
                    ) {
                        coachIntroDismissed = true
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }

                if shouldSurfaceCoach {
                    coachCard
                    storySupportSection
                } else if isRegistryGap || shouldShowCoachPreparingState {
                    registryGapSection
                        .padding(.top, 12)
                } else {
                    coachUnavailableSection
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, coachContentHorizontalInset)
            .frame(maxWidth: .infinity)
            .padding(.bottom, WeekFitScreenLayout.tabBarClearance)
        }
        .weekFitTransparentScrollBackground()
    }

    // MARK: - Coach Card

    private var coachCard: some View {
        let ui = coachUIPresentation
        let accent = ui?.accentColor ?? WeekFitTheme.coachAccent

        return ZStack(alignment: .topTrailing) {
            Image(systemName: ui?.icon ?? "sparkles")
                .font(.system(size: 68, weight: .regular))
                .foregroundStyle(accent.opacity(0.058))
                .offset(x: -4, y: 22)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                stateBadge

                if let warningMessage = ui?.warningMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !warningMessage.isEmpty {
                    coachWarningBanner(warningMessage)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(ui?.coachTitle ?? "")
                        .font(WeekFitType.cardTitle)
                        .foregroundStyle(textPrimary)
                        .tracking(-0.8)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        if let read = ui?.assessment.trimmingCharacters(in: .whitespacesAndNewlines), !read.isEmpty {
                            coachHeroTextBlock(
                                label: WeekFitLocalizedString("coach.hero.myRead"),
                                text: read
                            )
                        }

                        if let recommendation = ui?.recommendation.trimmingCharacters(in: .whitespacesAndNewlines),
                           !recommendation.isEmpty {
                            coachHeroTextBlock(
                                label: WeekFitLocalizedString("coach.hero.myRecommendation"),
                                text: recommendation
                            )
                            .onAppear {
                                guard !didRecordCoachRecommendationOpen else { return }
                                guard let ui else { return }
                                didRecordCoachRecommendationOpen = true
                                ReviewEngagement.record(.coachRecommendationOpened)
                                ProductAnalytics.coachRecommendationViewed(
                                    scenario: ui.scenario,
                                    warningAlert: ui.warningAlert
                                )
                                if ui.planAdjustmentMode == .appliedExecuting {
                                    let dayKey = ProposalInputFingerprintBuilder.dayKey(for: Date())
                                    MorningProposalPresenter.markAppliedAcknowledgmentShown(dayKey: dayKey)
                                    MorningProposalAnalytics.coachAcknowledgmentViewed(dayKey: dayKey)
                                    coachCoordinator.forceRecompute(reason: "appliedAcknowledgmentViewed.coach")
                                }
                            }
                        }

                        if let risk = ui?.avoid.trimmingCharacters(in: .whitespacesAndNewlines), !risk.isEmpty {
                            coachHeroTextBlock(
                                label: WeekFitLocalizedString("coach.hero.beCarefulWith"),
                                text: risk
                            )
                        }

                        if let nextAction = ui?.nextAction.trimmingCharacters(in: .whitespacesAndNewlines),
                           !nextAction.isEmpty {
                            coachHeroTextBlock(
                                label: WeekFitLocalizedString("coach.hero.nextStep"),
                                text: nextAction
                            )
                        }

                        CoachReflectionContinuationView(offer: coachState.reflectionOffer)
                    }
                }
                .padding(.top, 14)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPrimaryCard(
            accent: accent,
            featured: true
        )
    }

    private var stateBadge: some View {
        let isLimitedRecovery = coachUIPresentation?.showsLimitedConfidenceBadge == true
        let accent = isLimitedRecovery
            ? textSecondary.opacity(0.72)
            : (coachUIPresentation?.accentColor ?? WeekFitTheme.secondaryText)
        let baseLabel = coachUIPresentation?.statusLabel ?? ""
        let bpm = WeekFitActivityCoordinator.shared.liveHeartRateBPM
        let zone = WeekFitActivityCoordinator.shared.liveHeartRateZone
        let label: String = {
            guard !isLimitedRecovery, let bpm, let zone else { return baseLabel }
            let isLiveChrome: Bool = {
                switch coachUIPresentation?.semanticColor {
                case .live, .liveZone1, .liveZone2, .liveZone3, .liveElevated, .liveCritical:
                    return true
                default:
                    return false
                }
            }()
            guard isLiveChrome else { return baseLabel }
            return HeartRateZones.badgeLabel(zone: zone, bpm: bpm)
        }()

        return HStack(spacing: isLimitedRecovery ? 5 : 8) {
            Image(systemName: isLimitedRecovery ? "moon.zzz.fill" : (coachUIPresentation?.icon ?? "sparkles"))
                .font(.system(size: isLimitedRecovery ? 9 : 11.5, weight: .semibold))

            Text(isLimitedRecovery ? label : label.uppercased())
                .font(.system(
                    size: isLimitedRecovery ? 9 : 10,
                    weight: isLimitedRecovery ? .semibold : .black,
                    design: .rounded
                ))
                .tracking(isLimitedRecovery ? 0.2 : 1.4)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, isLimitedRecovery ? 8 : 11)
        .frame(height: isLimitedRecovery ? 20 : 24)
        .background(
            Capsule()
                .fill(accent.opacity(isLimitedRecovery ? 0.08 : 0.09))
                .overlay(
                    Capsule()
                        .stroke(accent.opacity(isLimitedRecovery ? 0.14 : 0.22), lineWidth: 1)
                )
        )
    }

    private func coachWarningBanner(_ message: String) -> some View {
        let accent = coachUIPresentation?.alertSeverity.uiAccentColor ?? CoachPalette.warning

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)

            Text(message)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.92))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
    }

    private func coachHeroTextBlock(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .black, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(textSecondary.opacity(0.42))

            Text(text)
                .font(.system(size: 13.4, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.76))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Unavailable / Registry Gap

    private var coachUnavailableSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(WeekFitTheme.whiteOpacity(0.05)))

            VStack(alignment: .leading, spacing: 4) {
                Text(WeekFitLocalizedString(coachUnavailableTitleKey))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(WeekFitLocalizedString(coachUnavailableMessageKey))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .weekFitPrimaryCard(accent: WeekFitTheme.coachAccent)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var registryGapSection: some View {
        HStack(spacing: 12) {
            Image(systemName: CoachState.registryGapIcon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CoachState.registryGapColor)
                .frame(width: 30, height: 30)
                .background(Circle().fill(CoachState.registryGapColor.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(CoachState.registryGapTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(CoachState.registryGapMessage)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .weekFitPrimaryCard(accent: CoachState.registryGapColor)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Story Support

    private var storySupportSection: some View {
        let whyRows = coachUIPresentation?.whyRows ?? []

        return VStack(alignment: .leading, spacing: 13) {
            if !whyRows.isEmpty {
                presentationWhySection(whyRows)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func presentationWhySection(_ rows: [CoachPresentationWhyRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: WeekFitLocalizedString("coach.why"),
                subtitle: WeekFitLocalizedString("coach.why.subtitle")
            )

            VStack(spacing: 5) {
                ForEach(Array(rows.prefix(3).enumerated()), id: \.offset) { _, row in
                    coachDecisionRow(
                        row.title,
                        color: row.color,
                        icon: row.icon
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func supportGroupHeader(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            // Same eyebrow language as coachHeroTextBlock labels inside the hero card.
            Text(subtitle.uppercased())
                .font(.system(size: 9.5, weight: .black, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(textSecondary.opacity(0.42))
        }
    }

    private func coachDecisionRow(
        _ text: String,
        color: Color,
        icon: String
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: WeekFitSurface.iconWellRadius, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
            }

            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, WeekFitSurface.compactHorizontalPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitCompactRowCard(accent: color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

enum CoachPalette {
    static let recovery = Color(red: 0.18, green: 0.74, blue: 0.89)
    static let hydration = Color(red: 0.40, green: 0.72, blue: 0.98)
    static let warning = Color(red: 1.00, green: 0.76, blue: 0.26)
    static let fueling = WeekFitTheme.orange
    static let training = WeekFitTheme.workout
    static let stable = WeekFitLightTokens.success
    static let protection = WeekFitTheme.coachAccent
    static let stress = WeekFitLightTokens.critical
    /// Live HR zone accents (aliases of `HeartRateZones.color`).
    static let liveElevated = HeartRateZones.color(for: 4)
    static let liveCritical = HeartRateZones.color(for: 5)

    static let good = stable
    static let activity = training
}
