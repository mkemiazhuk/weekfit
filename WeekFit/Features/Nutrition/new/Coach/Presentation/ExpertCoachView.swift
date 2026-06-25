import SwiftUI

struct ExpertCoachView: View {

    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var languageManager: AppLanguageManager

    @StateObject private var userSettings = WeekFitUserSettings.shared

    @State private var showProfile = false

    private let coachContentHorizontalInset: CGFloat = 0

    private let cardBackground = WeekFitTheme.cardBackground
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText

    init(authViewModel: AuthViewModel) {
        _ = authViewModel
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        return ZStack(alignment: .top) {
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
        .sheet(isPresented: $showProfile) {
            NavigationStack {
                ProfileView()
            }
            .environmentObject(healthManager)
            .environmentObject(nutritionViewModel)
            .environmentObject(appSession)
            .environmentObject(languageManager)
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .weekFitSheetChrome(cornerRadius: 36)
        }
    }

    // MARK: - Coach State

    private var coachState: CoachState {
        coachCoordinator.state
    }

    private var coachUIPresentation: CoachUIPresentation? {
        coachState.coachUIPresentation
    }

    private var coachPresentation: CoachScreenPresentation? {
        coachState.coachPresentation
    }

    private var todayPresentation: CoachTodayPresentation {
        coachState.todayPresentation
    }

    private var isRegistryGap: Bool {
        coachState.todayCoachInsightHiddenReason == .registryGap
    }

    private var shouldSurfaceCoach: Bool {
        coachState.hasValidGuidance || coachUIPresentation != nil
    }

    private var heroSemanticColor: Color {
        coachUIPresentation?.semanticColor.uiColor
            ?? coachPresentation?.color
            ?? todayPresentation.color
    }

    private var coachIcon: String {
        coachUIPresentation?.icon
            ?? coachPresentation?.icon
            ?? todayPresentation.icon
    }

    private var coachDisplayStateLabel: String {
        if let ui = coachUIPresentation {
            return ui.statusLabel.uppercased()
        }

        let label = coachPresentation?.stateLabel.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return label.isEmpty ? todayPresentation.statusLabel.uppercased() : label.uppercased()
    }

    private var coachRenderedTitle: String {
        coachUIPresentation?.coachTitle
            ?? coachPresentation?.title
            ?? todayPresentation.title
    }

    private var selectedDateTitle: String {
        WeekFitShortWeekdayMonthDay(Date())
    }

    private var shouldShowHealthConnectPrompt: Bool {
        !hasTodayRecoverySignals &&
        (
            !healthManager.isHealthAccessRequested ||
            (!healthManager.isHealthAccessGranted && healthManager.hasCompletedHealthAccessCheck)
        )
    }

    private var hasTodayRecoverySignals: Bool {
        healthManager.sleepMinutes > 0 ||
        healthManager.timeInBedMinutes > 0 ||
        healthManager.hrvSDNN > 0 ||
        healthManager.restingHeartRate > 0
    }

    // MARK: - Background

    private var ambientBackground: some View {
        WeekFitTheme.coachAmbient
            .blur(radius: 30)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    // MARK: - Coach Content

    private var coachContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .center, spacing: WeekFitScreenLayout.rootSpacing) {
                if shouldSurfaceCoach {
                    coachCard
                    storySupportSection
                } else if isRegistryGap {
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
        let renderedTitle = coachRenderedTitle
        let read = ui?.assessment.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let recommendation = ui?.recommendation.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? coachPresentation?.recommendation.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        let risk = ui?.avoid.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nextAction = ui?.nextAction.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let warningMessage = ui?.warningMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ZStack(alignment: .topTrailing) {
            Image(systemName: coachIcon)
                .font(.system(size: 68, weight: .regular))
                .foregroundStyle(heroSemanticColor.opacity(0.058))
                .offset(x: -4, y: 22)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                stateBadge

                if !warningMessage.isEmpty {
                    coachWarningBanner(warningMessage)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(renderedTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .tracking(-0.8)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        if !read.isEmpty {
                            coachHeroTextBlock(
                                label: WeekFitLocalizedString("coach.hero.myRead"),
                                text: ui?.assessment ?? read
                            )
                        }

                        if !recommendation.isEmpty {
                            coachHeroTextBlock(
                                label: WeekFitLocalizedString("coach.hero.myRecommendation"),
                                text: ui?.recommendation ?? coachPresentation?.recommendation ?? recommendation
                            )
                        }

                        if !risk.isEmpty {
                            coachHeroTextBlock(
                                label: WeekFitLocalizedString("coach.hero.beCarefulWith"),
                                text: ui?.avoid ?? risk
                            )
                        }

                        if !nextAction.isEmpty {
                            coachHeroTextBlock(
                                label: coachNextActionLabel,
                                text: nextAction
                            )
                        }
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
                            heroSemanticColor.opacity(0.138),
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
                                    heroSemanticColor.opacity(0.05),
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
                                    heroSemanticColor.opacity(0.26),
                                    Color.white.opacity(0.055)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.25
                        )
                )
        )
        .shadow(color: heroSemanticColor.opacity(0.092), radius: 18, y: 8)
        .shadow(color: Color.black.opacity(0.19), radius: 14, y: 7)
    }

    private var stateBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: coachIcon)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(heroSemanticColor)

            Text(coachDisplayStateLabel)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(heroSemanticColor)
        }
        .padding(.horizontal, 11)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(heroSemanticColor.opacity(0.09))
                .overlay(
                    Capsule()
                        .stroke(heroSemanticColor.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var coachNextActionLabel: String {
        WeekFitCurrentLocale().identifier.hasPrefix("ru") ? "Следующий шаг" : "Next step"
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
                .background(Circle().fill(Color.white.opacity(0.05)))

            VStack(alignment: .leading, spacing: 4) {
                Text(WeekFitLocalizedString(shouldShowHealthConnectPrompt ? "coach.unavailable.title" : "coach.unavailable.sleepSync.title"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(WeekFitLocalizedString(shouldShowHealthConnectPrompt ? "coach.unavailable.message" : "coach.unavailable.sleepSync.message"))
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
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var registryGapSection: some View {
        HStack(spacing: 12) {
            Image(systemName: todayPresentation.icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(todayPresentation.color)
                .frame(width: 30, height: 30)
                .background(Circle().fill(todayPresentation.color.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(todayPresentation.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(todayPresentation.message)
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
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Story Support

    private var storySupportSection: some View {
        let whyRows = coachPresentation?.whyRows ?? []
        let supportActions = coachPresentation?.supportActions ?? []

        return VStack(alignment: .leading, spacing: 13) {
            if !whyRows.isEmpty {
                presentationWhySection(whyRows)
            }

            if !supportActions.isEmpty {
                primaryActionsSection(supportActions)
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

    private func primaryActionsSection(_ actions: [CoachSupportAction]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            supportGroupHeader(
                title: WeekFitLocalizedString("coach.whatToDo"),
                subtitle: WeekFitLocalizedString("coach.whatToDo.subtitle")
            )

            VStack(spacing: 5) {
                ForEach(Array(actions.prefix(3))) { action in
                    coachDecisionRow(
                        action.title,
                        color: action.color,
                        icon: action.icon
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
                        .stroke(Color.white.opacity(0.035), lineWidth: 1)
                )
        )
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
