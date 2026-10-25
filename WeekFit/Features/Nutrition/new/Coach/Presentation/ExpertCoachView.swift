import SwiftUI
import SwiftData
import UIKit
import WeekFitPlanner

struct ExpertCoachView: View {

    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var languageManager: AppLanguageManager
    @EnvironmentObject private var eveningSummary: CoachEveningSummaryCoordinator
    @EnvironmentObject private var coachInputProvider: CoachInputProvider
    @ObservedObject private var activityCoordinator = WeekFitActivityCoordinator.shared
    @Environment(\.tabIsActive) private var tabIsActive
    @Environment(\.weekFitPalette) private var palette
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PlannedActivity.date, order: .forward)
    private var plannedActivities: [PlannedActivity]

    @ObservedObject private var userSettings = WeekFitUserSettings.shared
    @ObservedObject private var pendingRecoveryChallengeOpen = PendingRecoveryChallengeOpen.shared

    @State private var showProfile = false
    @State private var didRecordCoachRecommendationOpen = false
    @State private var discoverySpotlightDismissedLocally = false
    @State private var showRecoveryChallenge = false
    @State private var recoveryChallengeOpenSource = "coach"
    @State private var recoveryChallengeHeaderEntry: RecoveryChallengePresenter.HeaderEntry = .hidden
    @State private var didHandleDebugOpenRecoveryChallenge = false
    @State private var isWhyExpanded = false
    @State private var showCoachAssistant = false
    @State private var coachAssistantLaunch: CoachAssistantViewModel.Launch = .fresh
    @State private var todaysAssistantConversation: CoachAssistantConversation?
    @State private var askCoachActiveFocus: AskCoachWeeklyFocus?
    @State private var askCoachReviewableFocus: AskCoachWeeklyFocus?
    @State private var eveningRecapActivity = CoachEveningRecapActivitySummary.emptyWithoutHealth
    @State private var eveningRecapSignals: [CoachEveningRecapSignal] = []
    @State private var eveningRecapFingerprint = ""
    @State private var eveningRecapFeeling: CoachFeelingKind?
    @State private var eveningRecapDayComparisonFact: String?
    @State private var eveningRecapLoadTask: Task<Void, Never>?
    @State private var eveningRecapLoadGeneration = 0
    @State private var eveningRecapBoundaryEpoch = 0
    @ObservedObject private var unitsStore = WeekFitUnitsStore.shared
    @AppStorage(OnboardingStore.Keys.introCoach) private var coachIntroDismissed = false
    #if DEBUG
    @State private var showBeliefDebug = false
    #endif

    private let coachContentHorizontalInset: CGFloat = 0
    /// Stays at or under 19pt so the headline and body share SF Pro Text.
    @ScaledMetric(relativeTo: .body) private var coachHeadlineSize: CGFloat = 19
    @ScaledMetric(relativeTo: .body) private var coachCopySize: CGFloat = 17

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
        // Match Today/Meals: tear down the heavy Coach tree while inactive.
        // Keeping it at opacity 0 still rebuilt on HealthKit / @Query / HR publishes
        // and made every other tab feel sticky after Coach was opened once.
        Group {
            if tabIsActive {
                activeCoachBody
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            guard tabIsActive else { return }
            prepareCoachTabSurface(source: "coachTab.onAppear")
        }
        .onChange(of: tabIsActive) { _, active in
            if active {
                prepareCoachTabSurface(source: "coachTab.tabActive")
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
        .fullScreenCover(isPresented: $showCoachAssistant, onDismiss: {
            coachAssistantLaunch = .fresh
            refreshAskCoachFocus()
            refreshAssistantConversation()
        }) {
            CoachAssistantSheetHost(
                healthManager: healthManager,
                plannedActivities: plannedActivities,
                nutritionContext: nutritionViewModel.coachMetricsSnapshot?.nutritionContext,
                launch: coachAssistantLaunch,
                onAction: { action in
                    handleAssistantAction(action)
                }
            )
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
        .onChange(of: activityCoordinator.liveWorkout?.id) { _, _ in
            guard tabIsActive else { return }
            reconcileLiveWorkoutIfNeeded()
            refreshLiveCoachSession()
        }
        .task(id: liveCoachRefreshLoopID) {
            guard liveCoachRefreshLoopID != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                refreshLiveCoachSession(recompute: false)
            }
        }
        .task(id: "eveningRecapBoundary.\(eveningRecapBoundaryEpoch)") {
            await waitForEveningRecapBoundaryAndRefresh()
        }
    }

    private var liveCoachRefreshLoopID: String? {
        guard tabIsActive else { return nil }
        guard coachState.hasValidGuidance else { return nil }
        guard isLiveWorkoutZoneChrome else { return nil }
        return coachState.fingerprint?.rawValue ?? "live"
    }

    private func reconcileLiveWorkoutIfNeeded() {
        // Early-start walks only reconcile on Planner unless Coach also links the live Watch session.
        activityCoordinator.reconcileLiveWorkout(
            with: Array(plannedActivities),
            modelContext: modelContext
        )
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
                    // Evening: full champagne avatar; other Coach states stay subdued.
                    avatarProminence: shouldShowEveningRecap ? .standard : .subdued
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
        .background {
            if shouldShowEveningRecap {
                CoachEveningAtmosphereBackground(
                    isLight: palette.isLight,
                    ambientOpacity: palette.ambientOpacity
                )
                .ignoresSafeArea()
            }
        }
        .weekFitSettingsSheet(isPresented: $showProfile)
        .onChange(of: coachState.discoveryOffer?.id) { _, newID in
            if newID != nil {
                discoverySpotlightDismissedLocally = false
            }
        }
        #if DEBUG
        .overlay(alignment: .bottom) {
            if !shouldShowEveningRecap {
                beliefDebugPill
                    .padding(.horizontal, WeekFitScreenLayout.horizontalPadding)
                    .padding(.bottom, WeekFitScreenLayout.tabBarClearance + 10)
            }
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
    private var beliefDebugPill: some View {
        Button {
            showBeliefDebug = true
        } label: {
            HStack(spacing: 6) {
                Text("✦")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text(WeekFitLocalizedString("coach.debug.beliefs"))
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
        .accessibilityLabel(WeekFitLocalizedString("coach.debug.beliefs"))
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
                MissingSleepMorningNoticeHost(
                    surface: .coach,
                    now: Date(),
                    isHealthAccessGranted: healthManager.isHealthAccessGranted,
                    hasSettledMetrics: healthManager.hasSettledMetrics(for: Date()),
                    isLoadingMetrics: healthManager.isLoadingDisplayDayMetrics,
                    sleepReadConfirmed: healthManager.sleepSampleReadConfirmed,
                    hasSleepRecords: healthManager.sleepMinutes > 0 || healthManager.timeInBedMinutes > 0,
                    isScreenActive: tabIsActive,
                    onCheckConnection: { appSession.presentHealthAccess() }
                )
                .padding(.horizontal, 16)

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

                if isLiveWorkoutZoneChrome, shouldSurfaceCoach {
                    // 1) Live session owns Coach.
                    coachCard
                    if recoveryChallengeHeaderEntry != .hidden {
                        RecoveryChallengeHeaderEntryChip(
                            entry: recoveryChallengeHeaderEntry,
                            onTap: {
                                openRecoveryChallenge(source: "coach")
                            }
                        )
                    }
                    if showsAssistantEntry {
                        assistantEntrySection
                    }
                    discoverySpotlightSection
                } else if shouldShowEveningRecap {
                    // 3) Evening recap replaces the big recommendation card.
                    CoachEveningRecapView(
                        activitySummary: eveningRecapActivity,
                        daySignals: eveningRecapSignals,
                        commentary: eveningSummary.displayCommentary,
                        isLoadingCommentary: eveningSummary.isRefreshing
                            && eveningSummary.displayCommentary == nil
                            && eveningRecapFeeling == nil,
                        commentaryFailed: eveningSummary.lastRefreshFailed
                            && eveningSummary.displayCommentary == nil
                            && eveningRecapFeeling == nil,
                        selectedFeeling: eveningRecapFeeling,
                        unitSystem: unitsStore.resolvedSystem,
                        showsHealthConnect: shouldShowHealthConnectPrompt,
                        onSelectFeeling: saveEveningRecapFeeling,
                        onConnectHealth: connectAppleHealthFromCoach
                    )
                    if recoveryChallengeHeaderEntry != .hidden {
                        RecoveryChallengeHeaderEntryChip(
                            entry: recoveryChallengeHeaderEntry,
                            onTap: {
                                openRecoveryChallenge(source: "coach")
                            }
                        )
                    }
                } else if shouldSurfaceCoach {
                    // 2 / 4) Upcoming prep or other existing Coach states.
                    if recoveryChallengeHeaderEntry != .hidden {
                        RecoveryChallengeHeaderEntryChip(
                            entry: recoveryChallengeHeaderEntry,
                            onTap: {
                                openRecoveryChallenge(source: "coach")
                            }
                        )
                    }
                    coachCard
                    if showsAssistantEntry {
                        assistantEntrySection
                    }
                    discoverySpotlightSection
                } else if isRegistryGap || shouldShowCoachPreparingState {
                    registryGapSection
                        .padding(.top, 12)
                    if showsAssistantEntry {
                        assistantEntrySection
                    }
                } else {
                    coachUnavailableSection
                        .padding(.top, 12)
                    if showsAssistantEntry {
                        assistantEntrySection
                    }
                }
            }
            .padding(.horizontal, coachContentHorizontalInset)
            .frame(maxWidth: .infinity)
            .padding(.bottom, WeekFitScreenLayout.tabBarClearance)
        }
        .weekFitTransparentScrollBackground(fillsCanvas: false)
        // Evening recap refresh is owned by `prepareCoachTabSurface` / plan+locale observers
        // below — avoid a second onAppear/tabActive path that cancels in-flight HK work.
        .onChange(of: plannedActivitiesSignature) { _, _ in
            refreshEveningRecapIfNeeded(source: "coachContent.planChange", force: true)
        }
        .onChange(of: isLiveWorkoutZoneChrome) { _, _ in
            refreshEveningRecapIfNeeded(source: "coachContent.liveChange", force: true)
        }
        .onChange(of: languageManager.selectedLanguage) { _, _ in
            eveningRecapFingerprint = ""
            applyEveningRecapSignals(activity: eveningRecapActivity)
            refreshEveningRecapIfNeeded(source: "coachContent.languageChange", force: true)
        }
        .onChange(of: unitsStore.selectedPreference) { _, _ in
            eveningRecapFingerprint = ""
            applyEveningRecapSignals(activity: eveningRecapActivity)
            refreshEveningRecapIfNeeded(source: "coachContent.unitsChange", force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshEveningRecapIfNeeded(source: "coachContent.foreground", force: true)
        }
    }

    private func prepareCoachTabSurface(source: String) {
        refreshEveningRecapIfNeeded(source: source)
        reconcileLiveWorkoutIfNeeded()
        // Live HR recompute is irrelevant (and expensive) during evening recap.
        if !shouldShowEveningRecap {
            refreshLiveCoachSession()
        }
        refreshRecoveryChallengeEntry()
        refreshAskCoachFocus()
        refreshAssistantConversation()
        openPendingRecoveryChallengeIfNeeded()
    }

    private var shouldShowEveningRecap: Bool {
        guard CoachEveningSummaryPolicy.isCoachSurfaceEnabled else { return false }
        guard !isLiveWorkoutZoneChrome else { return false }
        return CoachEveningRecapEligibility.shouldShowEveningRecap(
            now: Date(),
            plannedActivities: Array(plannedActivities)
        )
    }

    private var plannedActivitiesSignature: String {
        PlannedActivityRefreshSignature.make(from: Array(plannedActivities))
    }

    private func waitForEveningRecapBoundaryAndRefresh() async {
        let target = CoachEveningRecapEligibility.nextRecheckDate()
        let delay = target.timeIntervalSinceNow + 0.25
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        guard !Task.isCancelled else { return }
        refreshEveningRecapIfNeeded(source: "eveningRecap.boundary")
        eveningRecapBoundaryEpoch &+= 1
    }

    private func refreshEveningRecapIfNeeded(source: String, force: Bool = false) {
        CoachEveningSummaryDiagnostics.event(
            "recap.refresh",
            detail: "source=\(source) tabActive=\(tabIsActive) eligible=\(shouldShowEveningRecap) force=\(force)"
        )
        eveningRecapFeeling = CoachFeelingCheckInStore.latest(on: Date())?.feeling

        guard shouldShowEveningRecap else {
            eveningRecapLoadTask?.cancel()
            eveningRecapLoadTask = nil
            return
        }

        if let owner = WorkspaceOwnerStore.currentIdentityToken(),
           AccountSessionController.shared.mode == .realUser {
            eveningSummary.restore(owner: owner)
        }

        // Coalesce bursty first-open triggers so we don't cancel/restart HK mid-flight.
        if !force, eveningRecapLoadTask != nil {
            CoachEveningSummaryDiagnostics.event(
                "recap.refresh.coalesced",
                detail: "source=\(source)"
            )
            return
        }

        eveningRecapLoadTask?.cancel()
        eveningRecapLoadGeneration &+= 1
        let generation = eveningRecapLoadGeneration
        eveningRecapLoadTask = Task { @MainActor in
            defer {
                if eveningRecapLoadGeneration == generation {
                    eveningRecapLoadTask = nil
                }
            }
            await loadEveningRecapActivityAndMaybeGenerate(source: source, generation: generation)
        }
    }

    @MainActor
    private func loadEveningRecapActivityAndMaybeGenerate(source: String, generation: Int) async {
        let now = Date()
        let activities = Array(plannedActivities)
        guard CoachEveningRecapEligibility.shouldShowEveningRecap(
            now: now,
            plannedActivities: activities
        ) else { return }

        let granted = healthManager.isHealthAccessGranted
        if !granted {
            eveningRecapActivity = .emptyWithoutHealth
            eveningRecapSignals = CoachEveningRecapSignalBuilder.build(
                activity: .emptyWithoutHealth,
                sleepHours: 0,
                recoveryPercent: 0,
                nutrition: nutritionViewModel.coachMetricsSnapshot?.nutritionContext,
                unitSystem: unitsStore.resolvedSystem
            )
            eveningRecapFingerprint = "noHealth"
            return
        }

        // Instant first paint from Today-cached metrics + Plan recovery (no HK wait).
        paintEveningRecapSeed(activities: activities, now: now)

        let snapshotProvider = ActivityIntelligenceSnapshotProvider()
        async let todayBundle = snapshotProvider.buildEveningRecapDayBundle(
            for: now,
            healthManager: healthManager,
            plannedActivities: activities
        )
        async let priorMetrics = CoachEveningRecapDayComparison.loadPriorMetrics(
            relativeTo: now,
            healthManager: healthManager
        )

        let bundle = await todayBundle
        let priors = await priorMetrics
        guard !Task.isCancelled, eveningRecapLoadGeneration == generation else { return }

        // Include Plan recovery (sauna / breath / yoga) even when HealthKit has no row.
        let daySessions = snapshotProvider.sessionsForEveningRecap(
            snapshotSessions: bundle.sessions,
            plannedActivities: activities,
            day: now
        )
        let comparison = CoachEveningRecapDayComparison.compute(
            todayDistanceKm: bundle.distanceKm,
            priorDayMetrics: priors
        )
        eveningRecapDayComparisonFact = comparison?.aiFactText

        let summary = CoachEveningRecapActivityAggregator.build(
            steps: bundle.steps,
            dayWalkingRunningDistanceKm: bundle.distanceKm,
            sessions: daySessions,
            healthAccessGranted: true,
            unitSystem: unitsStore.resolvedSystem,
            dayComparison: comparison
        )
        let fingerprint = CoachEveningRecapActivityAggregator.fingerprint(
            steps: bundle.steps,
            distanceKm: bundle.distanceKm,
            sessions: daySessions,
            comparisonDeltaKm: comparison?.deltaKm
        )
        eveningRecapActivity = summary
        eveningRecapFingerprint = fingerprint
        applyEveningRecapSignals(activity: summary)

        guard AccountSessionController.shared.mode == .realUser,
              let owner = WorkspaceOwnerStore.currentIdentityToken() else { return }

        // Prefer already-built coach input; only refresh when missing.
        // Avoid invalidate+full Understanding rebuild on every tab open.
        if coachInputProvider.lastInput == nil {
            await coachInputProvider.refresh(
                selectedDate: now,
                plannedActivities: activities,
                healthManager: healthManager,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator,
                source: "eveningRecap.\(source)",
                refreshHealth: false
            )
            guard !Task.isCancelled, eveningRecapLoadGeneration == generation else { return }
            applyEveningRecapSignals(activity: summary)
        }

        guard CoachEveningRecapEligibility.shouldShowEveningRecap(
            now: Date(),
            plannedActivities: Array(plannedActivities)
        ) else { return }

        let locale = languageManager.selectedLanguage.rawValue
        guard let input = coachInputProvider.lastInput,
              let request = CoachEveningSummaryInputBuilder.build(
                input: input,
                presentation: nil,
                activities: Array(plannedActivities),
                locale: locale,
                now: Date(),
                dayComparisonFact: eveningRecapDayComparisonFact
              ) else {
            if let owner = WorkspaceOwnerStore.currentIdentityToken() {
                eveningSummary.noteInputUnavailable(owner: owner, reason: "buildReturnedNil")
            }
            return
        }

        if CoachEveningSummaryPolicy.allowsManualRefreshAnytime {
            // DEBUG unrestricted: always mint a new cloud summary for prompt/locale testing.
            eveningSummary.refresh(
                input: request,
                owner: owner,
                now: Date(),
                source: "coach.\(source).unrestricted"
            )
        } else {
            eveningSummary.ensureUpToDate(
                input: request,
                owner: owner,
                fingerprint: fingerprint,
                now: Date(),
                isStillEligible: { [plannedActivities] in
                    CoachEveningRecapEligibility.shouldShowEveningRecap(
                        now: Date(),
                        plannedActivities: Array(plannedActivities)
                    )
                }
            )
        }
    }

    /// Synchronous shell so Coach doesn't sit empty while HK settles.
    @MainActor
    private func paintEveningRecapSeed(activities: [PlannedActivity], now: Date) {
        guard eveningRecapFingerprint.isEmpty || eveningRecapActivity.hero == nil else { return }

        let provider = ActivityIntelligenceSnapshotProvider()
        let planSessions = provider.sessionsForEveningRecap(
            snapshotSessions: [],
            plannedActivities: activities,
            day: now
        )
        let seed = CoachEveningRecapActivityAggregator.build(
            steps: healthManager.steps,
            dayWalkingRunningDistanceKm: healthManager.distanceKm,
            sessions: planSessions,
            healthAccessGranted: true,
            unitSystem: unitsStore.resolvedSystem,
            dayComparison: nil
        )
        eveningRecapActivity = seed
        applyEveningRecapSignals(activity: seed)
    }

    private func saveEveningRecapFeeling(_ feeling: CoachFeelingKind) {
        // One choice for the evening — once settled, do not allow edits.
        if eveningRecapFeeling != nil { return }

        let now = Date()
        if let existing = CoachFeelingCheckInStore.latest(on: now) {
            eveningRecapFeeling = existing.feeling
            return
        }

        let checkIn = CoachFeelingCheckIn(
            id: UUID().uuidString,
            createdAt: now,
            updatedAt: now,
            feeling: feeling,
            clarification: nil,
            outcome: .insufficient,
            evidence: .empty,
            analysisVersion: CoachFeelingEvidenceRules.analysisVersion,
            followUpAnswers: []
        )
        CoachFeelingCheckInStore.upsert(checkIn)
        eveningRecapFeeling = feeling
        trackEveningRecapFeeling(feeling)
        CoachSnapshotInvalidator.invalidate(
            coordinator: coachCoordinator,
            nutritionViewModel: nutritionViewModel,
            inputProvider: coachInputProvider,
            reason: "eveningRecap.feeling"
        )
    }

    private func trackEveningRecapFeeling(_ feeling: CoachFeelingKind) {
        let event: AnalyticsEvent
        switch feeling {
        case .tired, .low:
            event = .coachEveningFeelingTired
        case .okay:
            event = .coachEveningFeelingGood
        case .energized:
            event = .coachEveningFeelingEnergized
        }
        AppAnalytics.shared.track(event)
    }

    private func applyEveningRecapSignals(activity: CoachEveningRecapActivitySummary) {
        let recovery = coachInputProvider.lastInput?.recoveryContext
        let sleepHours: Double = {
            if let hours = recovery?.sleepHours, hours > 0 { return hours }
            if healthManager.sleepHours > 0 { return healthManager.sleepHours }
            return Double(max(healthManager.sleepMinutes, 0)) / 60.0
        }()
        let recoveryPercent = recovery?.recoveryPercent ?? healthManager.recoveryPercent
        eveningRecapSignals = CoachEveningRecapSignalBuilder.build(
            activity: activity,
            sleepHours: sleepHours,
            recoveryPercent: recoveryPercent,
            nutrition: coachInputProvider.lastInput?.nutritionContext
                ?? nutritionViewModel.coachMetricsSnapshot?.nutritionContext,
            unitSystem: unitsStore.resolvedSystem
        )
    }

    private func connectAppleHealthFromCoach() {
        appSession.presentHealthAccess()
    }

    // MARK: - WeekFit Coach Assistant

    /// Temporarily off on Coach — flip to `true` when Assistant entry is ready again.
    private let showsAssistantEntry = false

    private var assistantEntrySection: some View {
        CoachAssistantInvitationSection(
            activeConversation: todaysAssistantConversation,
            onOpen: {
                // Reuse today’s conversation even if it is still greeting-only.
                if let id = todaysAssistantConversation?.id {
                    coachAssistantLaunch = .continueConversation(id: id)
                } else {
                    coachAssistantLaunch = .fresh
                }
                showCoachAssistant = true
            }
        )
        // Match Coach card spacing within the shared root VStack.
        .padding(.top, 0)
    }

    private func refreshAskCoachFocus() {
        askCoachActiveFocus = AskCoachFocusStore.activeFocus()
        askCoachReviewableFocus = AskCoachFocusStore.reviewableFocus()
    }

    private func refreshAssistantConversation() {
        todaysAssistantConversation = CoachAssistantConversationStore.latest()
    }

    private func handleAssistantAction(_ action: CoachAssistantChoiceAction) {
        switch action {
        case .openMealsTab, .openMealBuilder:
            showCoachAssistant = false
            appSession.requestRootTab(.meals)
        case .openGoalSettings:
            showCoachAssistant = false
            showProfile = true
        case .proposePlanEase:
            showCoachAssistant = false
            let dayKey = ProposalInputFingerprintBuilder.dayKey(for: Date())
            PendingMorningProposalReview.shared.requestOpen(dayKey: dayKey)
            appSession.requestRootTab(.today)
        case .setWeeklyFocus, .startNewConversation, .skipCheckIn:
            break
        }
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
                    .font(WeekFitType.captionEmphasized)
                    .fontDesign(.rounded)
                    .foregroundStyle(textSecondary.opacity(0.78))
                    .padding(.top, 8)
            }

            if !hierarchy.action.isEmpty {
                Text(hierarchy.action)
                    // Keep live guidance more expressive than resting sectionTitle.
                    .font(WeekFitType.activeTimer.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary)
                    .tracking(-0.9)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, liveStateMetaLabel == nil ? 10 : 2)
            }

            if !hierarchy.target.isEmpty {
                Text(hierarchy.target)
                    .font(WeekFitType.compactCardTitle)
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary.opacity(0.94))
                    .tracking(-0.3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .onAppear { recordCoachRecommendationOpenIfNeeded(ui) }
            }

            if !hierarchy.context.isEmpty {
                Text(hierarchy.context)
                    .font(WeekFitType.secondary.weight(.medium))
                    .fontDesign(.rounded)
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
                    .font(.system(size: coachHeadlineSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.3)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22)
                    .accessibilityAddTraits(.isHeader)
            }

            if !explanation.isEmpty,
               !CoachUIPresentationDedup.isNearDuplicate(explanation, headline) {
                Text(explanation)
                    .font(.system(size: coachCopySize, weight: .regular, design: .rounded))
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

    /// Zone chrome while Coach is in a live workout session — never during meals.
    /// Walk scenarios use recovery chrome until HR arrives; also trust
    /// `isCoachLiveSession` so the live layout opens before the first BPM sample.
    private var isLiveWorkoutZoneChrome: Bool {
        if coachUIPresentation?.semanticColor.isLiveSessionChrome == true {
            return true
        }
        // Meals stay out: isCoachLiveSession requires family != .none.
        guard let input = coachState.input else { return false }
        return input.plannedActivities.contains {
            CoachSessionPhaseStability.isCoachLiveSession($0, now: input.now)
        }
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

    /// Finished recovery, stretch, breath work, or sauna — not a training session.
    private var isCompletedRecovery: Bool {
        guard let scenario = coachUIPresentation?.scenario else { return false }
        switch scenario {
        case .postRecoveryImmediate, .postRecoverySettled, .saunaRecovery:
            return true
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
            || lowered.contains("logged")
            || lowered.contains("завершен")
            || lowered == "прогулка"
            || lowered == "хайкинг"
    }

    /// Same live zone color as the zone outline — drives the card outline only.
    private var liveZoneBorderColor: Color? {
        guard isLiveWorkoutZoneChrome else { return nil }
        if let zone = activityCoordinator.liveHeartRateZone {
            return HeartRateZones.color(for: zone)
        }
        return coachUIPresentation?.accentColor
    }

    @ViewBuilder
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
                let status = coachUIPresentation?.statusLabel ?? ""
                let title = coachUIPresentation?.coachTitle ?? ""
                if status.compare(title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame {
                    return ""
                }
                return status
            }
            if isLiveChrome {
                return liveStateBadgeLabel
            }
            if isCompleted {
                return isCompletedRecovery
                    ? WeekFitLocalizedString("coach.recoveryComplete")
                    : WeekFitLocalizedString("coach.sessionComplete")
            }
            return coachUIPresentation?.statusLabel ?? ""
        }()

        let iconName: String = {
            if isLimitedRecovery { return "moon.zzz.fill" }
            if isCompleted { return "checkmark" }
            return coachUIPresentation?.icon ?? "sparkles"
        }()

        if !label.isEmpty {
        HStack(spacing: isRecovering ? 6 : 7) {
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
    }

    private func coachWarningBanner(_ message: String) -> some View {
        let accent = coachUIPresentation?.alertSeverity.uiAccentColor ?? CoachPalette.warning

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(accent)

            Text(message)
                .font(WeekFitType.secondary.weight(.semibold))
                .fontDesign(.rounded)
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
            CoachSessionPhaseStability.isCoachLiveSession($0, now: now)
        }
        guard let focus = candidates.max(by: { $0.date < $1.date }) else { return nil }
        // Today / Quick Start: chip follows real elapsed, not the soft default duration.
        if focus.isUserStartedLiveSession(now: now) {
            return max(1, Int(now.timeIntervalSince(focus.date) / 60))
        }
        return max(focus.durationMinutes, 1)
    }

    private func coachMetricChip(_ text: String) -> some View {
        Text(text.uppercased())
            .font(WeekFitType.captionEmphasized.weight(.bold))
            .fontDesign(.rounded)
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
                        .font(WeekFitType.captionEmphasized.weight(.bold))
                        .fontDesign(.rounded)
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
                    .font(WeekFitType.captionEmphasized)
                    .fontDesign(.rounded)
                    .foregroundStyle(textSecondary.opacity(0.68))

                    Image(systemName: "chevron.right")
                        .font(WeekFitType.captionEmphasized.weight(.bold))
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
                .font(WeekFitType.captionEmphasized.weight(.bold))
                .fontDesign(.rounded)
                .tracking(0.6)
                .foregroundStyle(textSecondary.opacity(0.72))
                .textCase(.uppercase)

            Text(text)
                .font(WeekFitType.button)
                .fontDesign(.rounded)
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
                    .font(WeekFitType.captionEmphasized.weight(.bold))
                    .fontDesign(.rounded)
                    .tracking(0.55)
                    .foregroundStyle(coachSectionLabelColor)

                Text(text)
                    .font(.system(size: coachCopySize, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        emphasis
                            ? textPrimary.opacity(0.96)
                            : coachBodyTextColor
                    )
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let supporting, !supporting.isEmpty {
                    Text(supporting)
                        .font(.system(size: coachCopySize, weight: .medium, design: .rounded))
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
                    .font(WeekFitType.compactCardTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary)

                Text(WeekFitLocalizedString(coachUnavailableMessageKey))
                    .font(WeekFitType.secondary.weight(.medium))
                    .fontDesign(.rounded)
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
                    .font(WeekFitType.compactCardTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(textPrimary)

                Text(CoachState.registryGapMessage)
                    .font(WeekFitType.secondary.weight(.medium))
                    .fontDesign(.rounded)
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
                .font(WeekFitType.secondary.weight(.medium))
                .fontDesign(.rounded)
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
