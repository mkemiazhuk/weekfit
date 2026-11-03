import SwiftUI
import HealthKit

/// Guided product experience — promise → goal → nutrition → health → understanding → Maya → ready.
struct FirstRunOnboardingView: View {

    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weekFitPalette) private var palette

    @State private var step: Step
    @State private var selectedGoal: NutritionGoal
    @State private var contentVisible = false
    @State private var isRequestingHealth = false
    @State private var didPersistGoal = false
    @State private var didUserChangeGoal = false
    @State private var advanceLocked = false
    @State private var navigationDirection: NavigationDirection = .forward

    private enum NavigationDirection {
        case forward
        case backward
    }

    enum Step: Int, CaseIterable, Hashable, Identifiable {
        case promise
        case goal
        case nutritionShowcase
        case health
        case understanding
        case mayaCall
        case ready

        var id: Int { rawValue }

        var analyticsName: String {
            switch self {
            case .promise: return "promise"
            case .goal: return "goal"
            case .nutritionShowcase: return "nutrition_showcase"
            case .health: return "health"
            case .understanding: return "understanding"
            case .mayaCall: return "maya_call"
            case .ready: return "ready"
            }
        }
    }

    private var hasHealthBiometrics: Bool {
        UserNutritionProfile.hasSufficientHealthDataForAutoGoal(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm
        )
    }

    private var suggestedGoal: NutritionGoal? {
        guard hasHealthBiometrics else { return nil }
        return UserNutritionProfile.suggestedGoal(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm
        )
    }

    init() {
        let profile = ProfileService()
        let restoredGoal = profile.loadManualNutritionGoal() ?? .maintenance
        _selectedGoal = State(initialValue: restoredGoal)

        if let raw = OnboardingStore.persistedStepRawValue,
           let restored = Step(rawValue: raw) {
            _step = State(initialValue: restored)
        } else {
            _step = State(initialValue: .promise)
        }
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                OnboardingNavBar(
                    progress: navProgress,
                    progressAccessibilityLabel: navProgressAccessibilityLabel,
                    showsBack: canGoBack,
                    showsSkip: canSkip,
                    onBack: goBack,
                    onSkip: skipOnboarding
                )

                ZStack {
                    stepContent
                        .id(step)
                        .transition(stepTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                // Left-edge pan only — full-width simultaneousGesture loses to ScrollView.
                .overlay(alignment: .leading) {
                    if canGoBack {
                        Color.clear
                            .frame(width: Self.backEdgeSwipeWidth)
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .gesture(backEdgeSwipeGesture)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityAction(.escape) {
                    goBack()
                }

                bottomBar
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    .padding(.top, OnboardingLayout.ctaTopPadding)
                    .padding(.bottom, OnboardingLayout.ctaBottomPadding)
            }
            .opacity(contentVisible ? 1 : 0)
        }
        .interactiveDismissDisabled()
        .accessibilityIdentifier("screen.onboarding")
        .task {
            OnboardingAnalytics.started()
            OnboardingAnalytics.stepViewed(step.analyticsName)
            OnboardingFunnelAnalytics.shared.trackStartedIfNeeded()
            if let analyticsStep = OnboardingAnalyticsStep(rawValue: step.analyticsName) {
                OnboardingFunnelAnalytics.shared.trackStepViewedIfNeeded(analyticsStep)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) {
                    contentVisible = true
                }
            }
        }
        .onChange(of: step) { _, new in
            OnboardingStore.persistedStepRawValue = new.rawValue
            OnboardingAnalytics.stepViewed(new.analyticsName)
            if let analyticsStep = OnboardingAnalyticsStep(rawValue: new.analyticsName) {
                OnboardingFunnelAnalytics.shared.trackStepViewedIfNeeded(analyticsStep)
            }
            if new == .goal {
                applySuggestedGoalIfNeeded()
            }
        }
        .id(languageManager.selectedLanguage)
        .onAppear {
            languageManager.syncWithDeviceLanguageIfNeeded()
            ProductAnalytics.trackScreen(.onboarding)
            if step == .goal { applySuggestedGoalIfNeeded() }
        }
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        switch navigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            )
        case .backward:
            return .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .leading)),
                removal: .opacity.combined(with: .move(edge: .trailing))
            )
        }
    }

    private static let backEdgeSwipeWidth: CGFloat = 44

    private var canGoBack: Bool {
        step != .promise && !isRequestingHealth && !advanceLocked
    }

    /// Skip exits the whole flow (not just the Health step's "Not now").
    private var canSkip: Bool {
        step != .ready && !isRequestingHealth && !advanceLocked
    }

    private var navProgress: CGFloat? {
        guard step != .promise else { return nil }
        let functionalIndex = max(step.rawValue, 1)
        return CGFloat(functionalIndex) / CGFloat(Step.allCases.count - 1)
    }

    private var navProgressAccessibilityLabel: String {
        guard step != .promise else { return "" }
        return String(
            format: WeekFitLocalizedString("onboarding.progress.format"),
            step.rawValue,
            Step.allCases.count - 1
        )
    }

    private var backEdgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard canGoBack else { return }
                // Edge swipe: rightward and mostly horizontal.
                guard dx > 56, abs(dx) > abs(dy) * 1.15 else { return }
                goBack()
            }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .promise: promiseStep
        case .goal: goalStep
        case .nutritionShowcase: nutritionShowcaseStep
        case .health: healthStep
        case .understanding: understandingStep
        case .mayaCall: mayaCallStep
        case .ready: readyStep
        }
    }

    private var background: some View {
        ZStack {
            WeekFitTheme.backgroundColor.ignoresSafeArea()
            ambientForStep
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: step)
        }
    }

    @ViewBuilder
    private var ambientForStep: some View {
        switch step {
        case .promise:
            ZStack {
                RadialGradient(
                    colors: [
                        WeekFitProgressRingColor.activity.opacity(palette.isLight ? 0.16 : 0.22),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.18, y: 0.48),
                    startRadius: 8,
                    endRadius: 220
                )
                RadialGradient(
                    colors: [
                        WeekFitProgressRingColor.nutrition.opacity(palette.isLight ? 0.18 : 0.24),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.50, y: 0.42),
                    startRadius: 8,
                    endRadius: 240
                )
                RadialGradient(
                    colors: [
                        WeekFitProgressRingColor.recovery.opacity(palette.isLight ? 0.16 : 0.22),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.82, y: 0.48),
                    startRadius: 8,
                    endRadius: 220
                )
            }
        case .ready:
            RadialGradient(
                colors: [
                    WeekFitTheme.brandGold.opacity(palette.isLight ? 0.09 : 0.14),
                    Color.clear
                ],
                center: UnitPoint(x: 0.78, y: 0.18),
                startRadius: 10,
                endRadius: 320
            )
        case .goal, .nutritionShowcase, .understanding, .mayaCall:
            RadialGradient(
                colors: [
                    WeekFitTheme.brandGold.opacity(palette.isLight ? 0.04 : 0.06),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.28),
                startRadius: 16,
                endRadius: 280
            )
        case .health:
            WeekFitTheme.healthAmbient
        }
    }

    private func applySuggestedGoalIfNeeded() {
        guard !didUserChangeGoal, !didPersistGoal else { return }
        guard let suggested = suggestedGoal else { return }
        selectedGoal = suggested
    }
}

// MARK: - Steps

private extension FirstRunOnboardingView {

    var promiseStep: some View {
        OnboardingPage {
            OnboardingWelcomeView()
        }
    }

    var goalStep: some View {
        OnboardingPage(
            title: WeekFitLocalizedString("onboarding.v11.goal.title"),
            subtitle: WeekFitLocalizedString("onboarding.v11.goal.body"),
            helper: WeekFitLocalizedString("onboarding.v11.goal.footer")
        ) {
            BodyGoalPickerSection(
                selectedGoal: $selectedGoal,
                hasHealthBiometrics: hasHealthBiometrics,
                suggestedGoal: suggestedGoal == selectedGoal ? nil : suggestedGoal,
                showsMissingHealthNote: false,
                showsSectionTitle: false,
                showsFooter: false
            )
            .onChange(of: selectedGoal) { _, _ in
                didPersistGoal = false
                didUserChangeGoal = true
                #if !targetEnvironment(simulator)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
        }
    }

    var nutritionShowcaseStep: some View {
        OnboardingPage(
            title: WeekFitLocalizedString("onboarding.v17.nutrition.title"),
            subtitle: WeekFitLocalizedString("onboarding.v17.nutrition.body"),
            helper: WeekFitLocalizedString("onboarding.v17.nutrition.helper")
        ) {
            OnboardingNutritionShowcaseView()
        }
    }

    var understandingStep: some View {
        OnboardingPage(
            title: WeekFitLocalizedString("onboarding.v12.understanding.title"),
            subtitle: WeekFitLocalizedString("onboarding.v12.understanding.body")
        ) {
            OnboardingAdaptationStage()
        }
    }

    var mayaCallStep: some View {
        OnboardingPage(
            title: WeekFitLocalizedString("onboarding.v16.maya.title"),
            subtitle: WeekFitLocalizedString("onboarding.v16.maya.body"),
            helper: WeekFitLocalizedString("onboarding.v17.maya.helper")
        ) {
            OnboardingMayaCallStage()
        }
    }

    var healthStep: some View {
        OnboardingPage(
            title: WeekFitLocalizedString("onboarding.v16.health.title"),
            subtitle: WeekFitLocalizedString("onboarding.v16.health.body")
        ) {
            OnboardingHealthSignalsStage()
                .frame(maxWidth: .infinity)
        }
    }

    var readyStep: some View {
        OnboardingPage {
            OnboardingReadyClimax(
                recoveryPercent: readyRecoveryPercent,
                activityPercent: readyActivityPercent,
                nutritionPercent: readyNutritionPercent,
                greetingTitle: readyGreetingTitle,
                reasoningLine: readyCoachPreview.mirrorLine,
                trainLine: readyCoachPreview.primaryAction,
                mealLine: readyCoachPreview.secondaryAction,
                recoveryLine: readyCoachPreview.recoveryAction,
                footerLine: readyCoachPreview.footer
            )
        }
    }

    /// Same source of truth as Settings → Profile → Name (`ProfileService`).
    private var readyPersistedFirstName: String {
        let given = ProfileService.resolvedGivenName()
        if !given.isEmpty { return given }
        return ProfileService.resolvedFullName()
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init) ?? ""
    }

    private var readyGreetingTitle: String {
        let first = readyPersistedFirstName
        if first.isEmpty {
            return WeekFitLocalizedString("onboarding.v12.ready.title.youreReady")
        }
        return String(
            format: WeekFitLocalizedString("onboarding.v12.ready.title.youreReady.named"),
            first
        )
    }
}

// MARK: - Chrome

private extension FirstRunOnboardingView {

    var bottomBar: some View {
        VStack(spacing: OnboardingLayout.ctaSecondarySpacing) {
            OnboardingPrimaryButton(
                title: primaryTitle,
                isLoading: isRequestingHealth,
                isEnabled: !advanceLocked && !isRequestingHealth
            ) {
                guard !advanceLocked, !isRequestingHealth else { return }
                #if !targetEnvironment(simulator)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                #endif
                handlePrimary()
            }

            if step == .promise {
                welcomeTrust
            }

            if step == .health, !healthManager.isHealthAccessGranted {
                OnboardingTextButton(title: WeekFitLocalizedString("onboarding.health.notNow")) {
                    guard !advanceLocked else { return }
                    #if !targetEnvironment(simulator)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    OnboardingAnalytics.healthSkipped()
                    OnboardingFunnelAnalytics.shared.trackHealthConnectionDeclined()
                    advance(to: .understanding)
                }
            }
        }
    }

    private var welcomeTrust: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 12, weight: .semibold))
                Text(WeekFitLocalizedString("onboarding.v18.welcome.trust"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(WeekFitTheme.secondaryText)
            Text(WeekFitLocalizedString("onboarding.v18.welcome.privacy"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WeekFitTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Actions

private extension FirstRunOnboardingView {

    enum ReadyState {
        case healthReady
        case healthLimited
        case noHealth
    }

    var readyState: ReadyState {
        if !healthManager.isHealthAccessGranted { return .noHealth }
        if healthManager.hasSettledMetrics(for: Date()) { return .healthReady }
        return .healthLimited
    }

    var readyUsesLiveHealth: Bool {
        readyState == .healthReady || readyState == .healthLimited
    }

    var readyRecoveryPercent: Int? {
        guard readyUsesLiveHealth, healthManager.recoveryPercent > 0 else { return nil }
        return healthManager.recoveryPercent
    }

    var readyActivityPercent: Int? {
        guard readyUsesLiveHealth else { return nil }
        let active = healthManager.activeCalories
        guard active > 0 else { return OnboardingSampleData.activityPercent }
        return min(100, Int((active / 600.0) * 100))
    }

    var readyNutritionPercent: Int? {
        guard readyUsesLiveHealth else { return nil }
        let eaten = healthManager.calories
        guard eaten > 0 else { return OnboardingSampleData.nutritionPercent }
        return min(100, Int((eaten / 2000.0) * 100))
    }

    var readyCoachPreview: OnboardingCoachPreview.Output {
        let health: OnboardingCoachPreview.HealthAvailability
        switch readyState {
        case .healthReady: health = .connected
        case .healthLimited: health = .limited
        case .noHealth: health = .unavailable
        }

        let sleepHours: Double? = {
            guard readyUsesLiveHealth, healthManager.sleepHours > 0 else { return nil }
            return healthManager.sleepHours
        }()

        let activeCalories: Double? = {
            guard readyUsesLiveHealth, healthManager.activeCalories > 0 else { return nil }
            return healthManager.activeCalories
        }()

        let steps: Int? = {
            guard readyUsesLiveHealth, healthManager.steps > 0 else { return nil }
            return healthManager.steps
        }()

        return OnboardingCoachPreview.build(
            .init(
                goal: selectedGoal,
                recoveryPercent: readyRecoveryPercent,
                sleepHours: sleepHours,
                activeCalories: activeCalories,
                steps: steps,
                health: health,
                firstName: ProfileService.resolvedGivenName()
            )
        )
    }

    var primaryTitle: String {
        switch step {
        case .promise:
            return WeekFitLocalizedString("onboarding.v10.promise.cta")
        case .goal:
            return WeekFitLocalizedString("onboarding.v12.cta.createPlan")
        case .nutritionShowcase, .understanding, .mayaCall:
            return WeekFitLocalizedString("onboarding.action.continue")
        case .health:
            return healthManager.isHealthAccessGranted
                ? WeekFitLocalizedString("onboarding.action.continue")
                : WeekFitLocalizedString("onboarding.v10.health.connect")
        case .ready:
            return WeekFitLocalizedString("onboarding.v12.cta.openToday")
        }
    }

    func handlePrimary() {
        switch step {
        case .promise:
            advance(to: .goal)
        case .goal:
            persistGoalIfNeeded()
            advance(to: .nutritionShowcase)
        case .nutritionShowcase:
            advance(to: .health)
        case .health:
            if healthManager.isHealthAccessGranted {
                advance(to: .understanding)
            } else {
                connectHealth()
            }
        case .understanding:
            advance(to: .mayaCall)
        case .mayaCall:
            advance(to: .ready)
        case .ready:
            finish()
        }
    }

    func advance(to next: Step) {
        guard !advanceLocked else { return }
        advanceLocked = true
        navigationDirection = .forward
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            step = next
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            advanceLocked = false
        }
    }

    func goBack() {
        guard canGoBack else { return }
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        advanceLocked = true
        navigationDirection = .backward
        OnboardingAnalytics.stepBack(from: step.analyticsName, to: previous.analyticsName)
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            step = previous
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            advanceLocked = false
        }
    }

    func persistGoalIfNeeded() {
        guard !didPersistGoal else { return }
        ProfileService().saveManualNutritionGoal(selectedGoal)
        appSession.triggerCoachRefresh(source: "onboarding.goal")
        appSession.triggerHealthRefresh(source: "onboarding.goal")
        didPersistGoal = true
    }

    func connectHealth() {
        guard HKHealthStore.isHealthDataAvailable() else {
            OnboardingAnalytics.healthAuthorization(result: "unavailable")
            OnboardingFunnelAnalytics.shared.trackHealthConnectionFailed(reason: .unavailable)
            advance(to: .understanding)
            return
        }
        guard AccountSessionController.shared.mode != .reviewDemo else {
            OnboardingAnalytics.healthAuthorization(result: "demo_blocked")
            OnboardingFunnelAnalytics.shared.trackHealthConnectionFailed(reason: .configurationError)
            advance(to: .understanding)
            return
        }
        guard !isRequestingHealth else { return }

        OnboardingAnalytics.healthConnectTapped()
        OnboardingFunnelAnalytics.shared.trackHealthConnectionStarted()
        isRequestingHealth = true

        let action = healthManager.beginHealthAuthorizationFromUserAction(
            source: "onboarding.health",
            includeSupplementaryPermissions: true
        ) {
            Task { @MainActor in
                isRequestingHealth = false
                let granted = healthManager.isHealthAccessGranted
                OnboardingAnalytics.healthAuthorization(result: granted ? "granted" : "denied")
                if granted {
                    OnboardingFunnelAnalytics.shared.trackHealthConnectionCompleted()
                    appSession.triggerHealthRefresh(source: "onboarding.health.connected")
                    appSession.triggerCoachRefresh(source: "onboarding.health.connected")
                } else if healthManager.lastHealthAuthorizationHadError {
                    OnboardingFunnelAnalytics.shared.trackHealthConnectionFailed(reason: .authorizationError)
                }
                // Probe false with no HK error: system sheet finished without usable
                // read access. Not WeekFit UI decline, and not a known technical failure —
                // intentionally no completed/declined/failed terminal event.
                advance(to: .understanding)
            }
        }

        switch action {
        case .startedAuthorizationPrompt:
            break
        case .unavailable:
            isRequestingHealth = false
            OnboardingAnalytics.healthAuthorization(result: "unavailable")
            OnboardingFunnelAnalytics.shared.trackHealthConnectionFailed(reason: .unavailable)
            advance(to: .understanding)
        case .blockedByDemoMode:
            isRequestingHealth = false
            OnboardingAnalytics.healthAuthorization(result: "unavailable")
            OnboardingFunnelAnalytics.shared.trackHealthConnectionFailed(reason: .configurationError)
            advance(to: .understanding)
        }
    }

    func skipOnboarding() {
        guard canSkip else { return }
        advanceLocked = true
        OnboardingAnalytics.skipped(from: step.analyticsName)
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        persistGoalIfNeeded()
        OnboardingStore.markCompleted()
        OnboardingAnalytics.completed()
        appSession.completeOnboarding(opening: .today)
        healthManager.retryPendingWorkoutRouteAuthorizationIfNeeded()
    }

    func finish() {
        OnboardingAnalytics.finalCTATapped()
        persistGoalIfNeeded()
        OnboardingStore.markCompleted()
        OnboardingAnalytics.completed()
        appSession.completeOnboarding(opening: .today)
        // Route auth is deferred while the onboarding cover is up; retry once the root settles.
        healthManager.retryPendingWorkoutRouteAuthorizationIfNeeded()
    }
}

//#Preview("Onboarding") {
//    FirstRunOnboardingView()
//        .environmentObject(AppSessionState())
//        .environmentObject(HealthManager())
//        .environmentObject(AppLanguageManager())
//}

