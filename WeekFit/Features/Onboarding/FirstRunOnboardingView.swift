import SwiftUI
import HealthKit

/// Guided product experience — promise → aim → trust → proof → coach.
/// Flow v13: promise → goal → health → understanding → ready.
struct FirstRunOnboardingView: View {

    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var languageManager: AppLanguageManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .title2) private var editorialTitleSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var editorialBodySize: CGFloat = 15

    @State private var step: Step
    @State private var selectedGoal: NutritionGoal
    @State private var contentVisible = false
    @State private var isRequestingHealth = false
    @State private var primaryPressed = false
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
        case health
        case understanding
        case ready

        var id: Int { rawValue }

        var analyticsName: String {
            switch self {
            case .promise: return "promise"
            case .goal: return "goal"
            case .health: return "health"
            case .understanding: return "understanding"
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
                progressHeader
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ZStack {
                    stepContent
                        .id(step)
                        .transition(stepTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(backSwipeGesture)
                .accessibilityAction(.escape) {
                    goBack()
                }

                bottomBar
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
            .opacity(contentVisible ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .task {
            OnboardingAnalytics.started()
            OnboardingAnalytics.stepViewed(step.analyticsName)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) {
                    contentVisible = true
                }
            }
        }
        .onChange(of: step) { _, new in
            OnboardingStore.persistedStepRawValue = new.rawValue
            OnboardingAnalytics.stepViewed(new.analyticsName)
            if new == .goal {
                applySuggestedGoalIfNeeded()
            }
        }
        .id(languageManager.selectedLanguage)
        .onAppear {
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

    private var canGoBack: Bool {
        step != .promise && !isRequestingHealth && !advanceLocked
    }

    private var backSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 28, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                // Back only: clearly horizontal, finger dragged right.
                guard canGoBack else { return }
                guard abs(dx) > abs(dy) * 1.6, dx > 72 else { return }
                goBack()
            }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .promise: promiseStep
        case .goal: goalStep
        case .health: healthStep
        case .understanding: understandingStep
        case .ready: readyStep
        }
    }

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ambientForStep
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.4), value: step)
        }
    }

    @ViewBuilder
    private var ambientForStep: some View {
        switch step {
        case .promise, .ready:
            RadialGradient(
                colors: [WeekFitTheme.brandGold.opacity(0.14), Color.clear],
                center: UnitPoint(x: 0.78, y: 0.18),
                startRadius: 10,
                endRadius: 320
            )
        case .goal, .understanding:
            RadialGradient(
                colors: [WeekFitTheme.brandGold.opacity(0.06), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.28),
                startRadius: 16,
                endRadius: 280
            )
        case .health:
            WeekFitTheme.healthAmbient
        }
    }

    private var needsScroll: Bool {
        dynamicTypeSize.isAccessibilitySize
            || step == .promise
            || step == .understanding
            || step == .goal
            || step == .ready
            || step == .health
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
        page {
            OnboardingPromiseMark()
                .padding(.top, 4)
        }
    }

    var goalStep: some View {
        page {
            VStack(alignment: .leading, spacing: 0) {
                editorialTitle(WeekFitLocalizedString("onboarding.v11.goal.title"))
                editorialBody(WeekFitLocalizedString("onboarding.v11.goal.body"))
                    .padding(.top, 8)

                BodyGoalPickerSection(
                    selectedGoal: $selectedGoal,
                    hasHealthBiometrics: hasHealthBiometrics,
                    suggestedGoal: suggestedGoal == selectedGoal ? nil : suggestedGoal,
                    showsMissingHealthNote: false,
                    footerOverride: WeekFitLocalizedString("onboarding.v11.goal.footer")
                )
                .padding(.top, 22)
                .onChange(of: selectedGoal) { _, _ in
                    didPersistGoal = false
                    didUserChangeGoal = true
                    #if !targetEnvironment(simulator)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                }

                Spacer(minLength: 12)
            }
        }
    }

    var understandingStep: some View {
        page {
            VStack(alignment: .leading, spacing: 0) {
                editorialTitle(WeekFitLocalizedString("onboarding.v12.understanding.title"))
                editorialBody(understandingBody)
                    .padding(.top, 10)

                OnboardingLiveChangeStage()
                    .padding(.top, 16)

                Spacer(minLength: 8)
            }
        }
    }

    var healthStep: some View {
        page {
            VStack(alignment: .leading, spacing: 0) {
                editorialTitle(WeekFitLocalizedString("onboarding.v10.health.title"))
                editorialBody(WeekFitLocalizedString("onboarding.v12.health.body"))
                    .padding(.top, 8)

                Spacer(minLength: 20)

                OnboardingHealthSignalsStage()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                Spacer(minLength: 8)
            }
        }
    }

    var readyStep: some View {
        page {
            OnboardingReadyClimax(
                recoveryPercent: readyRecoveryPercent,
                activityPercent: readyActivityPercent,
                nutritionPercent: readyNutritionPercent,
                greetingTitle: readyCoachPreview.greetingTitle,
                greetingSubtitle: readyCoachPreview.supportingMessage,
                mirrorLine: readyCoachPreview.mirrorLine,
                trainLine: readyCoachPreview.primaryAction,
                mealLine: readyCoachPreview.secondaryAction,
                recoveryLine: readyCoachPreview.recoveryAction,
                bodyLine: readyCoachPreview.footer
            )
            .padding(.top, 4)
        }
    }

    var understandingBody: String {
        switch selectedGoal {
        case .fatLoss:
            return WeekFitLocalizedString("onboarding.v12.understanding.body.fatLoss")
        case .maintenance:
            return WeekFitLocalizedString("onboarding.v12.understanding.body.maintenance")
        case .muscleGain:
            return WeekFitLocalizedString("onboarding.v12.understanding.body.muscleGain")
        }
    }

    func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let body = content()
            .padding(.horizontal, 28)

        return Group {
            if needsScroll {
                ScrollView(showsIndicators: false) { body }
            } else {
                body
            }
        }
    }
}

// MARK: - Chrome

private extension FirstRunOnboardingView {

    var progressHeader: some View {
        Group {
            if step == .promise {
                Color.clear.frame(height: 14)
            } else {
                HStack(spacing: 12) {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(WeekFitTheme.whiteOpacity(0.55))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canGoBack)
                    .opacity(canGoBack ? 1 : 0.35)
                    .accessibilityLabel(WeekFitLocalizedString("onboarding.v12.nav.back"))

                    GeometryReader { geo in
                        let functionalIndex = max(step.rawValue, 1)
                        let progress = CGFloat(functionalIndex) / CGFloat(Step.allCases.count - 1)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(WeekFitTheme.whiteOpacity(0.07))
                                .frame(height: 3.5)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [WeekFitTheme.brandGold, WeekFitTheme.brandGoldDeep],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(16, geo.size.width * progress), height: 3.5)
                                .animation(reduceMotion ? nil : .easeInOut(duration: 0.32), value: step)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 14)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        Text(
                            String(
                                format: WeekFitLocalizedString("onboarding.progress.format"),
                                step.rawValue,
                                Step.allCases.count - 1
                            )
                        )
                    )
                }
                .frame(height: 32)
            }
        }
    }

    var bottomBar: some View {
        VStack(spacing: 8) {
            primaryButton

            if step == .health, !healthManager.isHealthAccessGranted {
                Button {
                    guard !advanceLocked else { return }
                    #if !targetEnvironment(simulator)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    OnboardingAnalytics.healthSkipped()
                    advance(to: .understanding)
                } label: {
                    Text(WeekFitLocalizedString("onboarding.health.notNow"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.42))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    var primaryButton: some View {
        Button {
            guard !advanceLocked, !isRequestingHealth else { return }
            #if !targetEnvironment(simulator)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
            handlePrimary()
        } label: {
            HStack(spacing: 8) {
                if isRequestingHealth {
                    ProgressView()
                        .tint(Color.black.opacity(0.7))
                }
                Text(primaryTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.black.opacity(0.82))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [WeekFitTheme.brandGold, WeekFitTheme.brandGoldDeep.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(primaryPressed ? 0.985 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isRequestingHealth || advanceLocked)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in primaryPressed = true }
                .onEnded { _ in primaryPressed = false }
        )
    }

    func editorialTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: editorialTitleSize, weight: .bold, design: .rounded))
            .foregroundStyle(WeekFitTheme.primaryText)
            .tracking(-0.35)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    func editorialBody(_ text: String) -> some View {
        Text(text)
            .font(.system(size: editorialBodySize, weight: .medium))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.50))
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
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
                health: health
            )
        )
    }

    var primaryTitle: String {
        switch step {
        case .promise:
            return WeekFitLocalizedString("onboarding.v10.promise.cta")
        case .goal:
            return WeekFitLocalizedString("onboarding.v12.cta.createPlan")
        case .health:
            return healthManager.isHealthAccessGranted
                ? WeekFitLocalizedString("onboarding.v12.cta.seeItLive")
                : WeekFitLocalizedString("onboarding.v10.health.connect")
        case .understanding:
            return WeekFitLocalizedString("onboarding.v12.cta.meetCoach")
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
            advance(to: .health)
        case .health:
            if healthManager.isHealthAccessGranted {
                advance(to: .understanding)
            } else {
                connectHealth()
            }
        case .understanding:
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
            advance(to: .understanding)
            return
        }
        guard AccountSessionController.shared.mode != .reviewDemo else {
            OnboardingAnalytics.healthAuthorization(result: "demo_blocked")
            advance(to: .understanding)
            return
        }
        guard !isRequestingHealth else { return }

        OnboardingAnalytics.healthConnectTapped()
        isRequestingHealth = true

        let action = healthManager.beginHealthAuthorizationFromUserAction(
            source: "onboarding.health",
            includeSupplementaryPermissions: true
        ) {
            Task { @MainActor in
                isRequestingHealth = false
                let granted = await healthManager.checkReadAuthorizationStatus()
                healthManager.isHealthAccessGranted = granted
                OnboardingAnalytics.healthAuthorization(result: granted ? "granted" : "denied")
                if granted {
                    await healthManager.loadHealthData()
                    appSession.triggerHealthRefresh(source: "onboarding.health.connected")
                    appSession.triggerCoachRefresh(source: "onboarding.health.connected")
                }
                advance(to: .understanding)
            }
        }

        switch action {
        case .startedAuthorizationPrompt:
            break
        case .unavailable, .blockedByDemoMode:
            isRequestingHealth = false
            OnboardingAnalytics.healthAuthorization(result: "unavailable")
            advance(to: .understanding)
        }
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

#Preview("Onboarding") {
    FirstRunOnboardingView()
        .environmentObject(AppSessionState())
        .environmentObject(HealthManager())
        .environmentObject(AppLanguageManager())
}
