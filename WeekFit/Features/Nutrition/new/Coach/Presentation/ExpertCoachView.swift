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
    @State private var isWhyExpanded = false
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
            ? (palette.isLight ? 0.94 : 0.92)
            : (palette.isLight ? 0.88 : 0.86)
        return textPrimary.opacity(opacity)
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
                    showAvatar: true,
                    avatarProminence: .subdued
                ) {
                    showProfile = true
                }
            } content: {
                coachContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background {
                        // Transparent so Root's shared Weather-like sky shows through.
                        // Live HR zone color stays on the ZONE chip — not a full-screen wash.
                        Color.clear
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
        .overlay(alignment: .bottom) {
            askCoachPill
                .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                .padding(.bottom, WeekFitScreenLayout.tabBarClearance + 10)
        }
        .sheet(isPresented: $showBeliefDebug) {
            NavigationStack {
                CoachBeliefDebugView(coachState: coachCoordinator.state)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        #endif
        .onChange(of: coachUIPresentation?.scenario) { _, _ in
            isWhyExpanded = false
        }
    }

    #if DEBUG
    private var askCoachPill: some View {
        Button {
            showBeliefDebug = true
        } label: {
            HStack(spacing: 6) {
                Text("✦")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text(WeekFitLocalizedString("coach.askCoach"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(textPrimary.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(minHeight: 36)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial.opacity(palette.isLight ? 0.82 : 0.48))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(
                                WeekFitTheme.whiteOpacity(palette.isLight ? 0.14 : 0.12),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: Color.black.opacity(palette.isLight ? 0.04 : 0.16), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityIdentifier("coach.beliefDebug")
        .accessibilityLabel(WeekFitLocalizedString("coach.askCoach"))
    }
    #endif

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
                    if isLiveWorkoutZoneChrome {
                        // Active session: guidance first, challenge stays reachable below.
                        coachCard
                        if recoveryChallengeHeaderEntry != .hidden {
                            RecoveryChallengeHeaderEntryChip(
                                entry: recoveryChallengeHeaderEntry,
                                onTap: {
                                    openRecoveryChallenge(source: "coach")
                                }
                            )
                        }
                        discoverySpotlightSection
                    } else {
                        if recoveryChallengeHeaderEntry != .hidden {
                            RecoveryChallengeHeaderEntryChip(
                                entry: recoveryChallengeHeaderEntry,
                                onTap: {
                                    openRecoveryChallenge(source: "coach")
                                }
                            )
                        }
                        coachCard
                        discoverySpotlightSection
                        // All card states own Why inline — no second Why card.
                    }
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
        let live = isLiveWorkoutZoneChrome
        // Live HR zone color stays on the outline — not a tinted card matte.
        let cardAccent = live ? nil : (ui?.accentColor ?? WeekFitTheme.coachAccent)

        return VStack(alignment: .leading, spacing: 0) {
            stateBadge

            if let warningMessage = ui?.warningMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
               !warningMessage.isEmpty {
                coachWarningBanner(warningMessage)
                    .padding(.top, 10)
            }

            if live {
                liveSessionGuidanceBody(ui)
            } else {
                // Every non-live Coach state shares sectioned rows + ? Why.
                sectionedGuidanceBody(ui)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPrimaryCard(
            accent: cardAccent,
            featured: true
        )
        .overlay {
            if let zoneBorder = liveZoneBorderColor {
                RoundedRectangle(cornerRadius: WeekFitSurface.primaryRadius, style: .continuous)
                    .strokeBorder(
                        zoneBorder.opacity(palette.isLight ? 0.32 : 0.40),
                        lineWidth: 1.25
                    )
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: activityCoordinator.liveHeartRateZone)
        .animation(.easeInOut(duration: 0.45), value: coachUIPresentation?.semanticColor)
    }

    /// STATE → ACTION → TARGET → CONTEXT → WHY → NEXT
    @ViewBuilder
    private func liveSessionGuidanceBody(_ ui: CoachUIPresentation?) -> some View {
        let hierarchy = liveGuidanceHierarchy(ui)
        let whyRows = Array((ui?.whyRows ?? []).prefix(2))
        let nextAction = ui?.nextAction.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let chips = liveMetricChips(for: ui)

        VStack(alignment: .leading, spacing: 10) {
            if let meta = liveStateMetaLabel {
                Text(meta)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.78))
                    .padding(.top, 8)
            }

            if !hierarchy.action.isEmpty {
                Text(hierarchy.action)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.9)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, liveStateMetaLabel == nil ? 10 : 2)
            }

            if !hierarchy.target.isEmpty {
                Text(hierarchy.target)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(0.94))
                    .tracking(-0.3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .onAppear { recordCoachRecommendationOpenIfNeeded(ui) }
            }

            if !hierarchy.context.isEmpty {
                Text(hierarchy.context)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(palette.isLight ? 0.62 : 0.68))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !chips.isEmpty {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        coachMetricChip(chip)
                    }
                }
                .padding(.top, 2)
            }

            if !whyRows.isEmpty {
                coachWhyDisclosure(whyRows)
                    .padding(.top, 4)
            }

            if !nextAction.isEmpty,
               !CoachUIPresentationDedup.isNearDuplicate(nextAction, hierarchy.action),
               !CoachUIPresentationDedup.isNearDuplicate(nextAction, hierarchy.target),
               !CoachUIPresentationDedup.isNearDuplicate(nextAction, hierarchy.context) {
                coachNextSection(nextAction)
                    .padding(.top, 2)
            }
        }
    }

    /// All non-live Coach states:
    /// STATUS → HEADLINE → EXPLANATION → recommendation / don’t rush / next / ? why
    @ViewBuilder
    private func sectionedGuidanceBody(_ ui: CoachUIPresentation?) -> some View {
        let coachTitle = ui?.coachTitle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let todayMessage = ui?.todayMessage.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let assessment = ui?.assessment.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Post-session: keep a warm completion headline when title is thin/generic.
        let headline: String = {
            if isPostSessionGuidance {
                if !coachTitle.isEmpty { return coachTitle }
                return WeekFitLocalizedString("coach.completed.niceWork")
            }
            return coachTitle
        }()
        let explanation: String = {
            if !assessment.isEmpty { return assessment }
            if !todayMessage.isEmpty,
               !CoachUIPresentationDedup.isNearDuplicate(todayMessage, headline) {
                return todayMessage
            }
            return ""
        }()
        let recommendation = ui?.recommendation.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let avoid = ui?.avoid.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextRaw = ui?.nextAction.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextSplit = splitNextActionPresentation(nextRaw)

        VStack(alignment: .leading, spacing: 0) {
            if !headline.isEmpty {
                Text(headline)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.6)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)
                    .accessibilityAddTraits(.isHeader)
            }

            if !explanation.isEmpty,
               !CoachUIPresentationDedup.isNearDuplicate(explanation, headline) {
                Text(explanation)
                    .font(.system(size: 15.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(palette.isLight ? 0.68 : 0.74))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)
            }

            VStack(alignment: .leading, spacing: 22) {
                if !recommendation.isEmpty,
                   !CoachUIPresentationDedup.isNearDuplicate(recommendation, explanation) {
                    recoveringGuidanceRow(
                        icon: "leaf.fill",
                        iconColor: CoachPalette.good,
                        label: WeekFitLocalizedString("coach.hero.myRecommendation"),
                        text: recommendation,
                        emphasis: false
                    )
                    .onAppear { recordCoachRecommendationOpenIfNeeded(ui) }
                }

                if !avoid.isEmpty,
                   !CoachUIPresentationDedup.isNearDuplicate(avoid, recommendation),
                   !CoachUIPresentationDedup.isNearDuplicate(avoid, explanation) {
                    recoveringGuidanceRow(
                        icon: "pause.fill",
                        iconColor: textSecondary.opacity(0.85),
                        label: WeekFitLocalizedString("coach.hero.dontRush"),
                        text: avoid,
                        emphasis: false
                    )
                }

                if !nextSplit.action.isEmpty,
                   !CoachUIPresentationDedup.isNearDuplicate(nextSplit.action, recommendation),
                   !CoachUIPresentationDedup.isNearDuplicate(nextSplit.action, avoid) {
                    recoveringGuidanceRow(
                        icon: nextStepIcon(for: nextRaw),
                        iconColor: nextStepAccent(for: nextRaw),
                        label: WeekFitLocalizedString("coach.hero.nextStep"),
                        text: nextSplit.action,
                        emphasis: true,
                        supporting: nextSplit.reason
                    )
                }

                let whyRows = Array((ui?.whyRows ?? []).prefix(2))
                if let primaryWhy = whyRows.first {
                    recoveringGuidanceRow(
                        icon: "questionmark",
                        iconColor: WeekFitTheme.coachAccent.opacity(0.85),
                        label: WeekFitLocalizedString("coach.why"),
                        text: primaryWhy.title,
                        emphasis: false,
                        supporting: whyRows.dropFirst().first?.title
                    )
                }
            }
            .padding(.top, 26)

            CoachReflectionContinuationView(offer: coachState.reflectionOffer)
                .padding(.top, 14)
        }
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

    /// Zone chrome only while Coach is in a live workout session — never during meals.
    private var isLiveWorkoutZoneChrome: Bool {
        coachUIPresentation?.semanticColor.isLiveSessionChrome == true
    }

    private var isPostSessionGuidance: Bool {
        guard let scenario = coachUIPresentation?.scenario else { return false }
        switch scenario {
        case .postEnduranceImmediate, .postEnduranceSettled,
             .postRacketImmediate, .postRacketSettled,
             .postStrengthImmediate, .postStrengthSettled,
             .postRecoveryImmediate, .postRecoverySettled,
             .saunaRecovery:
            return true
        case .walkRecoveryAction, .walkAfterHeavyLoad, .walkEveningWindDown, .walkLightDay:
            return isWalkCompletedChrome
        default:
            return false
        }
    }

    /// Evening / settled recovering chrome — RECOVERING badge + “Recovering now” family.
    private var isRecoveringCalmGuidance: Bool {
        guard !isLiveWorkoutZoneChrome, !isPostSessionGuidance else { return false }
        let status = coachUIPresentation?.statusLabel.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = coachUIPresentation?.coachTitle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let recoveringStatus =
            status.compare("RECOVERING", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            || status.compare("ВОССТАНАВЛИВАЕМСЯ", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        let recoveringTitle =
            title.compare("Recovering now", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            || title.compare("Восстанавливаемся", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        return recoveringStatus || recoveringTitle
    }

    /// Walk scenarios reuse completed headlines from existing presentation helpers — no invented copy.
    private var isWalkCompletedChrome: Bool {
        guard let title = coachUIPresentation?.coachTitle else { return false }
        let recoveryTitles = [false, true].flatMap { hike in
            [false, true].map { russian in
                CoachWalkRecoveryActionPresentation.coachHeadline(
                    for: .completed,
                    isHike: hike,
                    russian: russian
                )
            }
        }
        if recoveryTitles.contains(title) { return true }
        let lowered = title.lowercased()
        return lowered.contains("complete")
            || lowered.contains("done")
            || lowered.contains("завершен")
    }

    /// Same live zone color as the zone outline — drives the card outline only.
    private var liveZoneBorderColor: Color? {
        guard isLiveWorkoutZoneChrome else { return nil }
        if let zone = activityCoordinator.liveHeartRateZone {
            return HeartRateZones.color(for: zone)
        }
        return coachUIPresentation?.accentColor
    }

    private var stateBadge: some View {
        let isLimitedRecovery = coachUIPresentation?.showsLimitedConfidenceBadge == true
        let isLiveChrome = isLiveWorkoutZoneChrome
        let isCompleted = !isLiveChrome && isPostSessionGuidance
        let isRecovering = !isLiveChrome && !isCompleted && isRecoveringCalmGuidance
        let zone = activityCoordinator.liveHeartRateZone

        let accent: Color = {
            if isLimitedRecovery { return textSecondary.opacity(0.72) }
            if isLiveChrome, let zone {
                return HeartRateZones.color(for: zone)
            }
            if isCompleted || isRecovering {
                return CoachPalette.recovery
            }
            return coachUIPresentation?.accentColor ?? WeekFitTheme.secondaryText
        }()

        let label: String = {
            if isLimitedRecovery {
                return coachUIPresentation?.statusLabel ?? ""
            }
            if isLiveChrome {
                return liveStateBadgeLabel
            }
            if isCompleted {
                return WeekFitLocalizedString("coach.sessionComplete")
            }
            return coachUIPresentation?.statusLabel ?? ""
        }()

        let iconName: String = {
            if isLimitedRecovery { return "moon.zzz.fill" }
            if isCompleted { return "checkmark" }
            return coachUIPresentation?.icon ?? "sparkles"
        }()

        return HStack(spacing: isRecovering ? 6 : 7) {
            Image(systemName: iconName)
                .font(.system(size: isLimitedRecovery ? 9 : (isRecovering ? 10 : 10.5), weight: .semibold))

            Text(isLimitedRecovery ? label : label.uppercased())
                .font(.system(
                    size: isLimitedRecovery ? 9 : (isRecovering ? 10 : 10.5),
                    weight: isLimitedRecovery ? .semibold : .bold,
                    design: .rounded
                ))
                .tracking(isLimitedRecovery ? 0.2 : (isRecovering ? 0.7 : 0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, isLimitedRecovery ? 8 : (isRecovering ? 9 : 10))
        .frame(height: isLimitedRecovery ? 20 : (isRecovering ? 24 : 26))
        .background(
            Capsule()
                .fill(accent.opacity(isLimitedRecovery ? 0.08 : (isRecovering ? 0.09 : 0.10)))
                .overlay(
                    Capsule()
                        .stroke(
                            accent.opacity(isLimitedRecovery ? 0.14 : (isRecovering ? 0.20 : 0.24)),
                            lineWidth: 1
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

    // MARK: - Hierarchy helpers

    private struct GuidanceHierarchy {
        let action: String
        let target: String
        let context: String
    }

    private var liveStateBadgeLabel: String {
        guard let ui = coachUIPresentation else { return "" }
        let russian = WeekFitUsesRussianLanguage()
        switch ui.scenario {
        case .walkEveningWindDown, .walkRecoveryAction, .walkAfterHeavyLoad, .walkLightDay:
            return CoachWalkRecoveryActionPresentation.coachHeadline(
                for: .upcoming,
                isHike: focusedActivityIsHikeLike,
                russian: russian
            )
        case .duringRecovery:
            // Mindful recovery must not reuse walk chrome ("Recovery walk").
            return CoachMindfulRecoveryPresentation.liveStateBadge(
                activityType: focusedLiveActivityType,
                russian: russian
            )
        default:
            return ui.coachTitle
        }
    }

    private var liveStateMetaLabel: String? {
        guard isLiveWorkoutZoneChrome else { return nil }
        // Breath / yoga / stretch: calm cues, not zone meta.
        guard CoachMindfulRecoveryPresentation.usesHeartRateZoneChrome(focusedLiveActivityType) else {
            return nil
        }
        guard let zone = activityCoordinator.liveHeartRateZone else { return nil }
        let zoneLabel = HeartRateZones.badgeLabel(zone: zone)
        let effort = HeartRateZones.localizedEffort(for: zone)
        if effort.localizedCaseInsensitiveContains("easy")
            || effort.localizedCaseInsensitiveContains("лёгк")
            || effort.localizedCaseInsensitiveContains("легк")
            || zone <= 2 {
            return String(
                format: WeekFitLocalizedString("coach.meta.easyZoneFormat"),
                zoneLabel
            )
        }
        return "\(effort) · \(zoneLabel)"
    }

    private var focusedLiveActivity: CoachPlannedActivitySnapshot? {
        guard let input = coachState.input else { return nil }
        let now = input.now
        return input.dayContext.allActivities
            .filter { !$0.isSkipped && !$0.isCompleted && $0.durationMinutes > 0 }
            .min(by: { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) })
    }

    private var focusedActivityIsHikeLike: Bool {
        guard let focus = focusedLiveActivity else { return false }
        return CoachActivityClassification.isHikeLike(focus)
    }

    private var focusedLiveActivityType: CoachActivityType {
        guard let focus = focusedLiveActivity else { return .none }
        return CoachActivityClassifier.type(for: focus)
    }

    private func liveGuidanceHierarchy(_ ui: CoachUIPresentation?) -> GuidanceHierarchy {
        let todayMessage = ui?.todayMessage.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let coachTitle = ui?.coachTitle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let recommendation = ui?.recommendation.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let assessment = ui?.assessment.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Live teaser lands in todayMessage — that is the action verb ("Keep this one easy.").
        let action = !todayMessage.isEmpty ? todayMessage : coachTitle
        let split = splitRecommendationTarget(recommendation)

        var contextParts: [String] = []
        if let remainder = split.remainder, !remainder.isEmpty {
            contextParts.append(remainder)
        }
        if !assessment.isEmpty,
           !CoachUIPresentationDedup.isNearDuplicate(assessment, action),
           !CoachUIPresentationDedup.isNearDuplicate(assessment, split.target) {
            contextParts.append(assessment)
        }

        return GuidanceHierarchy(
            action: action,
            target: split.target,
            context: contextParts.first ?? ""
        )
    }

    private func splitRecommendationTarget(_ recommendation: String) -> (target: String, remainder: String?) {
        let trimmed = recommendation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", nil) }

        let separators = [" and ", " и ", " — ", " - "]
        for separator in separators {
            guard let range = trimmed.range(of: separator) else { continue }
            let head = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let tail = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard mentionsHeartRate(head), !tail.isEmpty else { continue }
            return (head, sentenceCase(tail))
        }
        return (trimmed, nil)
    }

    private func mentionsHeartRate(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("bpm")
            || lower.contains("уд")
            || lower.contains("heart")
            || lower.contains("пульс")
    }

    private func sentenceCase(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private func liveMetricChips(for ui: CoachUIPresentation?) -> [String] {
        var chips: [String] = []
        if let bpm = liveBPMChipLabel(for: ui) {
            chips.append(bpm)
        }
        if let duration = liveDurationChipLabel {
            chips.append(duration)
        }
        return chips
    }

    private func liveBPMChipLabel(for ui: CoachUIPresentation?) -> String? {
        guard let ui else { return nil }
        // Mindful recovery: duration chip only — "<133 bpm" reads as a workout target.
        guard CoachMindfulRecoveryPresentation.usesHeartRateZoneChrome(focusedLiveActivityType) else {
            return nil
        }

        let recommendation = ui.recommendation.lowercased()
        let isWalkRecoveryEasy: Bool = {
            switch ui.scenario {
            case .walkEveningWindDown, .walkRecoveryAction, .walkAfterHeavyLoad, .walkLightDay:
                return true
            default:
                return false
            }
        }()

        if isWalkRecoveryEasy || mentionsHeartRate(recommendation) {
            let label = HeartRateZones.bpmRangeLabel(for: 1)
            return label.isEmpty ? nil : label
        }
        if let zone = activityCoordinator.liveHeartRateZone {
            let label = HeartRateZones.bpmRangeLabel(for: zone)
            return label.isEmpty ? nil : label
        }
        return nil
    }

    private var liveDurationChipLabel: String? {
        guard isLiveWorkoutZoneChrome else { return nil }
        guard let minutes = focusedLiveDurationMinutes, minutes > 0 else { return nil }
        return String(format: WeekFitLocalizedString("common.unit.minutesFormat"), Int64(minutes))
    }

    private var focusedLiveDurationMinutes: Int? {
        guard let input = coachState.input else { return nil }
        let now = input.now
        let candidates = input.dayContext.allActivities.filter {
            !$0.isSkipped && !$0.isCompleted && $0.durationMinutes > 0
        }
        guard let focus = candidates.min(by: {
            abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now))
        }) else { return nil }
        return focus.durationMinutes
    }

    private func coachMetricChip(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11.5, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(textPrimary.opacity(0.88))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(WeekFitTheme.whiteOpacity(palette.isLight ? 0.06 : 0.08))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                    )
            )
            .accessibilityLabel(text)
    }

    private func coachWhyDisclosure(
        _ rows: [CoachPresentationWhyRow],
        compact: Bool = false
    ) -> some View {
        let count = rows.count
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isWhyExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(WeekFitLocalizedString("coach.whyThis"))
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(textSecondary.opacity(0.78))
                        .textCase(.uppercase)

                    Spacer(minLength: 8)

                    Text(
                        String(
                            format: WeekFitLocalizedString("coach.signalsCountFormat"),
                            Int64(count)
                        )
                    )
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.68))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(textSecondary.opacity(0.55))
                        .rotationEffect(.degrees(isWhyExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WeekFitLocalizedString("coach.whyThis"))
            .accessibilityValue(
                String(format: WeekFitLocalizedString("coach.signalsCountFormat"), Int64(count))
            )
            .accessibilityAddTraits(.isButton)

            if isWhyExpanded {
                VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        coachDecisionRow(
                            row.title,
                            color: row.color,
                            icon: row.icon
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func coachNextSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(WeekFitLocalizedString("coach.next"))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(textSecondary.opacity(0.72))
                .textCase(.uppercase)

            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.90))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func recordCoachRecommendationOpenIfNeeded(_ ui: CoachUIPresentation?) {
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

    private func recoveringGuidanceRow(
        icon: String,
        iconColor: Color,
        label: String,
        text: String,
        emphasis: Bool,
        supporting: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(iconColor.opacity(emphasis ? 0.92 : 0.78))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(emphasis ? 0.14 : 0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(iconColor.opacity(emphasis ? 0.22 : 0.12), lineWidth: 1)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: emphasis ? 5 : 4) {
                Text(label.uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .tracking(0.55)
                    .foregroundStyle(coachSectionLabelColor)

                Text(text)
                    .font(.system(
                        size: emphasis ? 15.5 : 14.5,
                        weight: emphasis ? .semibold : .medium,
                        design: .rounded
                    ))
                    .foregroundStyle(
                        emphasis
                            ? textPrimary.opacity(0.96)
                            : coachBodyTextColor
                    )
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let supporting, !supporting.isEmpty {
                    Text(supporting)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.82))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(text)\(supporting.map { ". \($0)" } ?? "")")
    }

    private func splitNextActionPresentation(_ text: String) -> (action: String, reason: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", nil) }

        let separators = [" — ", " – ", " - "]
        for separator in separators {
            guard let range = trimmed.range(of: separator) else { continue }
            let head = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let tail = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !head.isEmpty, !tail.isEmpty else { continue }
            return (head, sentenceCase(tail))
        }
        return (trimmed, nil)
    }

    private func nextStepIcon(for text: String) -> String {
        if CoachCopyQualityAudit.mentionsHydration(text) {
            return "drop.fill"
        }
        if CoachCopyQualityAudit.mentionsFuel(text) {
            return "fork.knife"
        }
        return "arrow.forward.circle.fill"
    }

    private func nextStepAccent(for text: String) -> Color {
        if CoachCopyQualityAudit.mentionsHydration(text) {
            return CoachPalette.hydration
        }
        if CoachCopyQualityAudit.mentionsFuel(text) {
            return CoachPalette.fueling
        }
        return CoachPalette.recovery
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


    private func coachDecisionRow(
        _ text: String,
        color: Color,
        icon: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color.opacity(0.88))
                .frame(width: 18, height: 18)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 13.2, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.94))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
