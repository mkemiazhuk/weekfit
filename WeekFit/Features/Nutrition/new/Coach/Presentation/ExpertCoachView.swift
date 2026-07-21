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
            WeekFitTheme.appBackground
                .ignoresSafeArea()

            ambientBackground

            WeekFitScreenContainer {
                WeekFitScreenHeader(
                    title: WeekFitLocalizedString("common.tab.coach"),
                    subtitle: selectedDateTitle,
                    initials: userSettings.profileInitials,
                    showAvatar: true
                ) {
                    showProfile = true
                }
            } content: {
                coachContent
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.coach")
        .weekFitSettingsSheet(isPresented: $showProfile)
        #if DEBUG
        .overlay(alignment: .bottomTrailing) {
            Button {
                showBeliefDebug = true
            } label: {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.purple.opacity(0.92))
                    .padding(10)
                    .background {
                        Circle()
                            .fill(Color.black.opacity(0.55))
                    }
            }
            .padding(.trailing, 18)
            .padding(.bottom, 118)
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

    // MARK: - Background

    private var ambientBackground: some View {
        WeekFitTheme.coachAmbient
            .ignoresSafeArea()
            .allowsHitTesting(false)
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
            .padding(.bottom, 110)
        }
    }

    // MARK: - Coach Card

    private var coachCard: some View {
        let ui = coachUIPresentation

        return ZStack(alignment: .topTrailing) {
            Image(systemName: ui?.icon ?? "sparkles")
                .font(.system(size: 68, weight: .regular))
                .foregroundStyle((ui?.accentColor ?? WeekFitTheme.secondaryText).opacity(0.058))
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
                        .font(.system(size: 22, weight: .bold, design: .rounded))
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
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            (ui?.accentColor ?? WeekFitTheme.secondaryText).opacity(0.138),
                            cardBackground.opacity(0.52),
                            cardBackground.opacity(0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (ui?.accentColor ?? WeekFitTheme.secondaryText).opacity(0.05),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: UnitPoint(x: 0.72, y: 0.58)
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    (ui?.accentColor ?? WeekFitTheme.secondaryText).opacity(0.26),
                                    WeekFitTheme.whiteOpacity(0.055)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.25
                        )
                )
        )
        .shadow(color: (ui?.accentColor ?? WeekFitTheme.secondaryText).opacity(0.092), radius: 18, y: 8)
        .shadow(color: Color.black.opacity(0.19), radius: 14, y: 7)
    }

    private var stateBadge: some View {
        let isLimitedRecovery = coachUIPresentation?.showsLimitedConfidenceBadge == true
        let accent = isLimitedRecovery
            ? textSecondary.opacity(0.72)
            : (coachUIPresentation?.accentColor ?? WeekFitTheme.secondaryText)
        let label = coachUIPresentation?.statusLabel ?? ""

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
        .background(cardBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.05), lineWidth: 1)
        )
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
        .background(cardBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.05), lineWidth: 1)
        )
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
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            Text(subtitle)
                .font(.system(size: 12.1, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.62))
        }
    }

    private func coachDecisionRow(
        _ text: String,
        color: Color,
        icon: String
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.10))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(color)
            }

            Text(text)
                .font(.system(size: 13.8, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.94))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(cardBackground.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(WeekFitTheme.whiteOpacity(0.035), lineWidth: 1)
                )
        )
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
    static let stable = Color(red: 0.16, green: 0.80, blue: 0.43)
    static let protection = Color(red: 0.58, green: 0.52, blue: 0.95)
    static let stress = Color(red: 1.00, green: 0.47, blue: 0.47)

    static let good = stable
    static let activity = training
}
