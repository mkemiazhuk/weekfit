import SwiftUI

struct ExpertCoachView: View {

    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var languageManager: AppLanguageManager
    @ObservedObject private var activityCoordinator = WeekFitActivityCoordinator.shared
    @Environment(\.tabIsActive) private var tabIsActive
    @Environment(\.weekFitPalette) private var palette
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @ObservedObject private var userSettings = WeekFitUserSettings.shared
    @ObservedObject private var pendingRecoveryChallengeOpen = PendingRecoveryChallengeOpen.shared

    @State private var showProfile = false
    @State private var keepCoachMounted = false
    @State private var didRecordCoachRecommendationOpen = false
    @State private var discoverySpotlightDismissedLocally = false
    @State private var showRecoveryChallenge = false
    @State private var recoveryChallengeOpenSource = "coach"
    @State private var recoveryChallengeHeaderEntry: RecoveryChallengePresenter.HeaderEntry = .hidden
    @State private var didHandleDebugOpenRecoveryChallenge = false
    @AppStorage(OnboardingStore.Keys.introCoach) private var coachIntroDismissed = false
    #if DEBUG
    @State private var showBeliefDebug = false
    #endif

    private let coachContentHorizontalInset: CGFloat = 0

    private let cardBackground = WeekFitTheme.cardBackground
    private var textPrimary: Color { palette.textPrimary }
    private var textSecondary: Color { palette.textSecondary }

    private var coachSectionLabelColor: Color {
        let opacity: CGFloat = colorSchemeContrast == .increased
            ? (palette.isLight ? 0.72 : 0.78)
            : (palette.isLight ? 0.58 : 0.68)
        return textSecondary.opacity(opacity)
    }

    private var coachBodyTextColor: Color {
        let opacity: CGFloat = colorSchemeContrast == .increased
            ? (palette.isLight ? 0.92 : 0.90)
            : (palette.isLight ? 0.82 : 0.84)
        return textSecondary.opacity(opacity)
    }

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
            refreshLiveCoachSession()
            refreshRecoveryChallengeEntry()
            openPendingRecoveryChallengeIfNeeded()
        }
        .onChange(of: tabIsActive) { _, active in
            if active {
                refreshLiveCoachSession()
                refreshRecoveryChallengeEntry()
                openPendingRecoveryChallengeIfNeeded()
            }
        }
        .onChange(of: pendingRecoveryChallengeOpen.shouldOpen) { _, shouldOpen in
            guard shouldOpen else { return }
            openPendingRecoveryChallengeIfNeeded()
        }
        .onChange(of: showProfile) { _, isPresented in
            if !isPresented {
                openPendingRecoveryChallengeIfNeeded()
            }
        }
        .sheet(isPresented: $showRecoveryChallenge, onDismiss: {
            refreshRecoveryChallengeEntry()
        }) {
            RecoveryChallengeView(source: recoveryChallengeOpenSource) {
                refreshRecoveryChallengeEntry()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(false)
        }
        .onChange(of: activityCoordinator.liveHeartRateZone) { previous, zone in
            guard tabIsActive, previous != zone else { return }
            // Zone flips must rebuild live copy (assessment / recommendation / teaser), not just the badge.
            coachCoordinator.forceRecomputeLiveHeartRate(
                reason: "coachTab.liveHeartRateZone",
                bpm: activityCoordinator.liveHeartRateBPM,
                zone: zone
            )
        }
        .task(id: liveCoachRefreshLoopID) {
            guard liveCoachRefreshLoopID != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                refreshLiveCoachSession(recompute: false)
            }
        }
    }

    private var liveCoachRefreshLoopID: String? {
        guard tabIsActive else { return nil }
        guard coachState.hasValidGuidance else { return nil }
        guard coachUIPresentation?.semanticColor.isLiveSessionChrome == true else { return nil }
        return coachState.fingerprint?.rawValue ?? "live"
    }

    private func refreshLiveCoachSession(recompute: Bool = true) {
        Task {
            await healthManager.ensureHeartRateZonePhysiology()
            activityCoordinator.refreshLiveHeartRate()
            if recompute {
                coachCoordinator.forceRecompute(reason: "coachTab.liveHeartRateRefresh")
            }
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
                    .background {
                        // Transparent so Root's shared Weather-like sky shows through.
                        // Keep only the live-zone wash when an active session color is present.
                        Group {
                            if let liveZoneScreenColor {
                                liveZoneScreenColor
                                    .opacity(palette.isLight ? 0.16 : 0.24)
                            } else {
                                Color.clear
                            }
                        }
                        .animation(
                            .easeInOut(duration: 0.45),
                            value: coachUIPresentation?.semanticColor
                        )
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.coach")
        .weekFitSettingsSheet(isPresented: $showProfile)
        .onChange(of: coachState.discoveryOffer?.id) { _, newID in
            if newID != nil {
                discoverySpotlightDismissedLocally = false
            }
        }
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

                if recoveryChallengeHeaderEntry != .hidden {
                    RecoveryChallengeHeaderEntryChip(
                        entry: recoveryChallengeHeaderEntry,
                        onTap: {
                            openRecoveryChallenge(source: "coach")
                        }
                    )
                }

                if shouldSurfaceCoach {
                    coachCard
                    discoverySpotlightSection
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
        .weekFitTransparentScrollBackground(fillsCanvas: false)
    }

    // MARK: - Recovery Challenge

    private func refreshRecoveryChallengeEntry() {
        #if DEBUG
        _ = RecoveryChallengeConfig.prepareDebugPreviewSessionIfNeeded()
        #endif
        recoveryChallengeHeaderEntry = RecoveryChallengeStore.headerEntry()

        #if DEBUG
        if !didHandleDebugOpenRecoveryChallenge,
           RecoveryChallengeConfig.launchArgumentsContain(
            RecoveryChallengeConfig.debugOpenLaunchArgument
           ) {
            didHandleDebugOpenRecoveryChallenge = true
            openRecoveryChallenge(source: "debug")
        }
        #endif
    }

    private func openRecoveryChallenge(source: String) {
        guard RecoveryChallengeConfig.isFeatureAvailable else { return }
        guard !showRecoveryChallenge else { return }
        guard !showProfile else {
            PendingRecoveryChallengeOpen.shared.requestOpen()
            return
        }

        recoveryChallengeOpenSource = source
        DispatchQueue.main.async {
            guard !self.showRecoveryChallenge else { return }
            self.showRecoveryChallenge = true
        }
    }

    private func openPendingRecoveryChallengeIfNeeded() {
        guard PendingRecoveryChallengeOpen.shared.shouldOpen else { return }
        guard RecoveryChallengeConfig.isFeatureAvailable else {
            _ = PendingRecoveryChallengeOpen.shared.consume()
            return
        }
        guard tabIsActive else { return }
        guard !showProfile,
              !appSession.isPresentingOnboarding,
              !appSession.isPresentingHealthAccess
        else { return }

        _ = PendingRecoveryChallengeOpen.shared.consume()
        openRecoveryChallenge(source: "deeplink")
    }

    // MARK: - Coach Card

    private var coachCard: some View {
        let ui = coachUIPresentation
        let accent = ui?.accentColor ?? WeekFitTheme.coachAccent

        return ZStack(alignment: .topTrailing) {
            Image(systemName: ui?.icon ?? "sparkles")
                .font(.system(size: 68, weight: .regular))
                .foregroundStyle(accent.opacity(liveZoneScreenColor == nil ? 0.058 : 0.16))
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
        .overlay {
            if liveZoneScreenColor != nil {
                RoundedRectangle(cornerRadius: WeekFitSurface.primaryRadius, style: .continuous)
                    .strokeBorder(accent.opacity(palette.isLight ? 0.42 : 0.55), lineWidth: 1.6)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: coachUIPresentation?.semanticColor)
    }

    @ViewBuilder
    private var discoverySpotlightSection: some View {
        if let offer = coachState.discoveryOffer, !discoverySpotlightDismissedLocally {
            CoachDiscoverySpotlightSection(offer: offer) {
                discoverySpotlightDismissedLocally = true
                CoachDiscoveryStore.markOfferDisplayed(offer)
                coachCoordinator.forceRecompute(reason: "discoverySpotlightDismissed")
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity.combined(with: .scale(scale: 0.98))
            ))
        }
    }

    private var liveZoneScreenColor: Color? {
        if let zone = activityCoordinator.liveHeartRateZone,
           coachUIPresentation?.semanticColor.isLiveSessionChrome == true {
            return HeartRateZones.color(for: zone)
        }
        guard let semantic = coachUIPresentation?.semanticColor,
              HeartRateZones.isLiveZoneColor(semantic) else {
            return nil
        }
        return coachUIPresentation?.accentColor
    }

    private var stateBadge: some View {
        let isLimitedRecovery = coachUIPresentation?.showsLimitedConfidenceBadge == true
        let zone = activityCoordinator.liveHeartRateZone
        let isLiveChrome = coachUIPresentation?.semanticColor.isLiveSessionChrome == true
        // Larger outdoor-readable chip while a live workout zone is active (bike / outdoor).
        let isLiveZoneBadge = !isLimitedRecovery && isLiveChrome && zone != nil
        // Drive accent from live zone immediately (Fitness-style), not from last coach recompute.
        let accent: Color = {
            if isLimitedRecovery { return textSecondary.opacity(0.72) }
            if isLiveChrome, let zone {
                return HeartRateZones.color(for: zone)
            }
            return coachUIPresentation?.accentColor ?? WeekFitTheme.secondaryText
        }()
        let baseLabel = coachUIPresentation?.statusLabel ?? ""
        let label: String = {
            guard !isLimitedRecovery, let zone, isLiveChrome else { return baseLabel }
            return HeartRateZones.badgeLabel(zone: zone)
        }()

        let iconSize: CGFloat = isLimitedRecovery ? 9 : (isLiveZoneBadge ? 17 : 11.5)
        let textSize: CGFloat = isLimitedRecovery ? 9 : (isLiveZoneBadge ? 16 : 10)
        let badgeHeight: CGFloat = isLimitedRecovery ? 20 : (isLiveZoneBadge ? 40 : 24)
        let horizontalPadding: CGFloat = isLimitedRecovery ? 8 : (isLiveZoneBadge ? 16 : 11)
        let stackSpacing: CGFloat = isLimitedRecovery ? 5 : (isLiveZoneBadge ? 10 : 8)

        return HStack(spacing: stackSpacing) {
            Image(systemName: isLimitedRecovery ? "moon.zzz.fill" : (coachUIPresentation?.icon ?? "sparkles"))
                .font(.system(size: iconSize, weight: .semibold))

            Text(isLimitedRecovery ? label : label.uppercased())
                .font(.system(
                    size: textSize,
                    weight: isLimitedRecovery ? .semibold : .black,
                    design: .rounded
                ))
                .tracking(isLimitedRecovery ? 0.2 : (isLiveZoneBadge ? 1.1 : 1.4))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, horizontalPadding)
        .frame(height: badgeHeight)
        .background(
            Capsule()
                .fill(accent.opacity(isLimitedRecovery ? 0.08 : (isLiveZoneBadge ? 0.16 : 0.09)))
                .overlay(
                    Capsule()
                        .stroke(
                            accent.opacity(isLimitedRecovery ? 0.14 : (isLiveZoneBadge ? 0.38 : 0.22)),
                            lineWidth: isLiveZoneBadge ? 1.5 : 1
                        )
                )
        )
        .accessibilityLabel(Text(label))
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
                .foregroundStyle(coachSectionLabelColor)

            Text(text)
                .font(.system(size: 13.4, weight: .medium, design: .rounded))
                .foregroundStyle(coachBodyTextColor)
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
        VStack(alignment: .leading, spacing: 6) {
            Text(WeekFitLocalizedString("coach.why"))
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.88))

            VStack(spacing: 4) {
                ForEach(Array(rows.prefix(2).enumerated()), id: \.offset) { _, row in
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color.opacity(0.82))
                .frame(width: 18)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.92))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
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
