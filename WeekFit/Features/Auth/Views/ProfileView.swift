import SwiftUI
import SwiftData

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var languageManager: AppLanguageManager
    @EnvironmentObject private var healthManager: HealthManager
    @EnvironmentObject private var nightComfort: NightComfortController
    @EnvironmentObject private var authViewModel: AuthViewModel

    @StateObject private var viewModel = ProfileViewModel()
    @State private var showResetConfirmation = false
    @State private var showResetFailure = false
    @State private var resetFailureMessage = ""
    @State private var isResettingLocalData = false

    @AppStorage(CoachDebugSettings.logLevelKey)
    private var coachLogLevelRaw = CoachLogLevel.off.rawValue

    private let background = Color.black

    private var textPrimary: Color { WeekFitTheme.primaryText }
    private let textSecondary = WeekFitTheme.whiteOpacity(0.54)
    private let textTertiary = WeekFitTheme.whiteOpacity(0.28)

    private let accentGreen = Color(red: 0.55, green: 0.80, blue: 0.58)
    private let accentBlue = Color(red: 0.56, green: 0.68, blue: 0.90)
    private let destructiveRed = Color(red: 255/255, green: 83/255, blue: 88/255)

    private var isShowingDialog: Bool {
        showResetConfirmation || showResetFailure
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ProfilePremiumBackground(accent: accentGreen)

            profileContent
                .blur(radius: isShowingDialog ? 3 : 0)
                .scaleEffect(isShowingDialog ? 0.985 : 1)
                .animation(.easeOut(duration: 0.18), value: isShowingDialog)

            resetDialogOverlay
        }
        .weekFitTabSwitchModalOverlay()
        .task {
            await refreshHealthPermissionState()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await refreshHealthPermissionState()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $viewModel.destination) { destination in
            switch destination {
            case .editName:
                EditNameView(viewModel: viewModel)
                    .settingsNavigationPush()

            case .notifications:
                NotificationSettingsView()
                    .settingsNavigationPush()

            case .language:
                LanguageSettingsView()
                    .settingsNavigationPush()

            case .nightComfort:
                NightComfortSettingsView()
                    .environmentObject(nightComfort)
                    .settingsNavigationPush()

            case .nutritionGoal:
                NutritionGoalSettingsView(viewModel: viewModel)
                    .environmentObject(appSession)
                    .environmentObject(healthManager)
                    .settingsNavigationPush()

            case .healthAccess:
                HealthAccessView()
                    .environmentObject(healthManager)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
                    .settingsNavigationPush()

            case .account:
                AccountSettingsView(profileViewModel: viewModel)
                    .environmentObject(authViewModel)
                    .environmentObject(nutritionViewModel)
                    .environmentObject(coachCoordinator)
                    .environmentObject(appSession)
                    .environmentObject(healthManager)
                    .settingsNavigationPush()

            case .helpSupport:
                HelpSupportView()
                    .settingsNavigationPush()

            case .termsPrivacy:
                TermsPrivacyView()
                    .settingsNavigationPush()
            }
        }
    }
}

// MARK: - Main UI

private extension ProfileView {

    var profileContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                headerSection

                settingsBlock(
                    title: nil,
                    items: viewModel.accountSettings,
                    showHealthStatus: false
                )

                settingsBlock(
                    title: nil,
                    items: viewModel.healthSettings,
                    showHealthStatus: true
                )

                settingsBlock(
                    title: AppText.Settings.Root.preferencesSection,
                    items: viewModel.preferenceSettings,
                    showHealthStatus: false
                )

                privacyDataSection

                settingsBlock(
                    title: AppText.Settings.Profile.supportSection,
                    items: viewModel.supportSettings,
                    showHealthStatus: false
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    var resetDialogOverlay: some View {
        if showResetConfirmation {
            ConfirmationDialogView(
                icon: "exclamationmark.triangle.fill",
                iconTint: destructiveRed,
                title: WeekFitLocalizedString("settings.profile.resetConfirm.title"),
                message: WeekFitLocalizedString("settings.profile.resetConfirm.message"),
                secondaryTitle: WeekFitLocalizedString("common.action.cancel"),
                primaryTitle: WeekFitLocalizedString("settings.profile.resetConfirm.primary"),
                isPrimaryDestructive: true,
                onSecondary: {
                    withDialogAnimation {
                        showResetConfirmation = false
                    }
                },
                onPrimary: {
                    withDialogAnimation {
                        showResetConfirmation = false
                    }

                    Task {
                        await resetLocalData()
                    }
                }
            )
        } else if showResetFailure {
            ConfirmationDialogView(
                icon: "exclamationmark.circle.fill",
                iconTint: destructiveRed,
                title: WeekFitLocalizedString("settings.profile.resetFailed.title"),
                message: resetFailureMessage,
                primaryTitle: WeekFitLocalizedString("common.action.ok"),
                dismissOnBackgroundTap: true,
                onSecondary: {
                    withDialogAnimation {
                        showResetFailure = false
                    }
                },
                onPrimary: {
                    withDialogAnimation {
                        showResetFailure = false
                    }
                }
            )
        }
    }

    var ambientBackground: some View {
        ZStack {
            Circle()
                .fill(accentGreen.opacity(0.052))
                .frame(width: 260, height: 260)
                .blur(radius: 130)
                .offset(x: -130, y: -70)

            Circle()
                .fill(Color.purple.opacity(0.026))
                .frame(width: 260, height: 260)
                .blur(radius: 140)
                .offset(x: 140, y: 90)

            Circle()
                .fill(accentBlue.opacity(0.022))
                .frame(width: 220, height: 220)
                .blur(radius: 130)
                .offset(x: 120, y: 360)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    var headerSection: some View {
        ProfilePremiumHeader(
            title: WeekFitLocalizedString("settings.root.title"),
            titleSize: 24,
            accent: accentGreen
        ) {
            dismiss()
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
    }

    func settingsBlock(
        title: LocalizedStringResource?,
        items: [ProfileItem],
        showHealthStatus: Bool
    ) -> some View {
        SettingsGroupedSection(title: title) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button {
                    viewModel.handleTap(item)
                } label: {
                    profileRow(
                        item,
                        showHealthStatus: showHealthStatus && isHealthSignalsItem(item)
                    )
                }
                .buttonStyle(PressableScaleButtonStyle())
                .accessibilityIdentifier(accessibilityID(for: item))
                .accessibilityLabel(accessibilityLabel(for: item, showHealthStatus: showHealthStatus && isHealthSignalsItem(item)))
                .accessibilityHint(WeekFitLocalizedString("settings.a11y.opensDetail"))

                if index < items.count - 1 {
                    SettingsGroupDivider()
                }
            }
        }
    }

    func profileRow(
        _ item: ProfileItem,
        showHealthStatus: Bool = false
    ) -> some View {
        HStack(spacing: 13) {
            rowIcon(for: item)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle(for: item))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = displaySubtitle(for: item, showHealthStatus: showHealthStatus) {
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(textSecondary)
                        .lineLimit(showHealthStatus ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            if showHealthStatus && !healthManager.isHealthAccessGranted {
                healthStatusBadge
            }

            if item.type == .nutritionGoal && nutritionGoalNeedsSetup {
                nutritionGoalSetupBadge
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .settingsRowTouchTarget(minHeight: showHealthStatus || item.type == .nutritionGoal ? 64 : 52)
    }

    func rowIcon(for item: ProfileItem) -> some View {
        ZStack {
            Circle()
                .fill(rowTint(for: item).opacity(0.13))

            Image(systemName: normalizedIcon(for: item))
                .font(.body.weight(.semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(rowTint(for: item).opacity(0.96))
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }

    var privacyDataSection: some View {
        let showReset = AccountSessionController.shared.mode != .reviewDemo
        let legalItems = viewModel.privacyLegalSettings

        return SettingsGroupedSection(title: AppText.Settings.Profile.privacyDataSection) {
            if showReset {
                Button {
                    withDialogAnimation {
                        showResetConfirmation = true
                    }
                } label: {
                    profileActionRow(
                        icon: "arrow.counterclockwise",
                        iconColor: destructiveRed.opacity(0.96),
                        iconBackground: destructiveRed.opacity(0.16),
                        title: isResettingLocalData
                            ? AppText.Settings.Profile.resettingLocalData
                            : AppText.Settings.Profile.resetLocalData,
                        titleColor: destructiveRed.opacity(0.94)
                    )
                }
                .buttonStyle(PressableScaleButtonStyle())
                .disabled(isResettingLocalData)
                .opacity(isResettingLocalData ? 0.72 : 1)
                .accessibilityIdentifier("settings.resetLocalData")
                .accessibilityLabel(Text(AppText.Settings.Profile.resetLocalData))
                .accessibilityHint(WeekFitLocalizedString("settings.a11y.resetLocalData.hint"))

                if !legalItems.isEmpty {
                    SettingsGroupDivider()
                }
            }

            ForEach(Array(legalItems.enumerated()), id: \.element.id) { index, item in
                Button {
                    viewModel.handleTap(item)
                } label: {
                    profileRow(item, showHealthStatus: false)
                }
                .buttonStyle(PressableScaleButtonStyle())
                .accessibilityIdentifier(accessibilityID(for: item))
                .accessibilityLabel(accessibilityLabel(for: item, showHealthStatus: false))
                .accessibilityHint(WeekFitLocalizedString("settings.a11y.opensDetail"))

                if index < legalItems.count - 1 {
                    SettingsGroupDivider()
                }
            }
        }
    }

    private func profileActionRow(
        icon: String,
        iconColor: Color,
        iconBackground: Color,
        title: LocalizedStringResource,
        titleColor: Color
    ) -> some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(iconBackground)

                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(iconColor)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(titleColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .settingsRowTouchTarget(minHeight: 52)
    }

    @ViewBuilder
    var healthStatusBadge: some View {
        if !healthManager.isHealthAccessGranted {
            Text(AppText.Settings.Profile.setupBadge)
                .font(.system(size: 11.1, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(.white.opacity(0.05))
                }
        }
    }

    var nutritionGoalNeedsSetup: Bool {
        viewModel.bodyGoalNeedsSetup(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm
        )
    }

    var nutritionGoalSetupBadge: some View {
        Text(AppText.Settings.Profile.setupBadge)
            .font(.system(size: 11.1, weight: .bold, design: .rounded))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(.white.opacity(0.05))
            }
    }

    var coachDebugToggle: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.13))

                Image(systemName: "stethoscope")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.purple.opacity(0.96))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("Coach Debug")
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Text(coachDebugEnabled ? "Verbose Coach logs enabled" : "Enable verbose Coach decision logs")
                    .font(.system(size: 12.6, weight: .medium))
                    .foregroundStyle(textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: coachDebugBinding)
                .labelsHidden()
                .tint(accentGreen.opacity(0.88))
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
        .background {
            Color.clear
                .profilePremiumSectionCard(cornerRadius: 20)
        }
    }
}

// MARK: - Helpers

private extension ProfileView {

    var nightComfortPreferenceLabel: String {
        switch nightComfort.preference {
        case .automatic:
            return WeekFitLocalizedString("settings.nightComfort.option.automatic")
        case .alwaysOn:
            return WeekFitLocalizedString("settings.nightComfort.option.alwaysOn")
        case .off:
            return WeekFitLocalizedString("settings.nightComfort.option.off")
        }
    }

    var coachDebugEnabled: Bool {
        CoachLogLevel(rawValue: coachLogLevelRaw) == .verbose
    }

    var coachDebugBinding: Binding<Bool> {
        Binding(
            get: {
                coachDebugEnabled
            },
            set: { isEnabled in
                coachLogLevelRaw = isEnabled ? CoachLogLevel.verbose.rawValue : CoachLogLevel.off.rawValue
                appSession.triggerCoachRefresh(source: "profileCoachDebugToggle")

                #if DEBUG
                CoachLogger.verbose(
                    "[CoachDebugSettings]",
                    "Profile toggle changed verboseLoggingEnabled=\(isEnabled)"
                )
                #endif
            }
        )
    }

    func withDialogAnimation(_ updates: @escaping () -> Void) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            updates()
        }
    }

    func resetLocalData() async {
        guard !isResettingLocalData else { return }
        isResettingLocalData = true

        do {
            let resetService = LocalDataResetService(modelContext: modelContext)
            resetService.beforeDeletingPlannedActivities = {
                CoachSnapshotInvalidator.invalidate(
                    coordinator: coachCoordinator,
                    nutritionViewModel: nutritionViewModel,
                    reason: "localDataReset"
                )
            }
            try await resetService.resetAllLocalData()

            ActivityConfirmationState.shared.pendingActivity = nil
            nutritionViewModel.resetLocalState()
            viewModel.reloadUserProfile()

            appSession.triggerLocalDataResetCompleted()
            appSession.triggerReturnToToday()
            appSession.triggerHealthRefresh(source: "localDataReset")
            appSession.triggerCoachRefresh(source: "localDataReset")

            dismiss()
        } catch {
            #if DEBUG
            print("[LocalDataReset][Failure] UI reset flow: \(error)")
            #endif
            resetFailureMessage = error.localizedDescription
            withDialogAnimation {
                showResetFailure = true
            }
        }

        isResettingLocalData = false
    }

    func isHealthSignalsItem(_ item: ProfileItem) -> Bool {
        item.type == .healthAccess || item.type == .appleHealth
    }

    func displayTitle(for item: ProfileItem) -> String {
        switch item.type {
        case .notifications:
            return WeekFitLocalizedString("settings.profile.item.notifications")
        case .language:
            return WeekFitLocalizedString("settings.language.title")
        case .nightComfort:
            return WeekFitLocalizedString("settings.nightComfort.title")
        case .nutritionGoal:
            return WeekFitLocalizedString("settings.nutritionGoal.title")
        case .healthAccess, .appleHealth:
            return WeekFitLocalizedString("settings.root.appleHealth")
        case .help:
            return WeekFitLocalizedString("settings.profile.item.helpSupport")
        case .terms:
            return WeekFitLocalizedString("settings.profile.item.termsPrivacy")
        case .account:
            return WeekFitLocalizedString("settings.account.title")
        case .units:
            return item.title
        }
    }

    func displaySubtitle(for item: ProfileItem, showHealthStatus: Bool) -> String? {
        if showHealthStatus {
            return profileHealthSignalsRowSubtitle(for: healthManager.healthDataConnectionState)
        }

        switch item.type {
        case .notifications:
            return WeekFitLocalizedString("settings.profile.item.notifications.subtitle")
        case .language:
            return String(
                format: WeekFitLocalizedString("settings.language.currentFormat"),
                localizedTitle(for: languageManager.selectedLanguage)
            )
        case .nightComfort:
            return nightComfortPreferenceLabel
        case .nutritionGoal:
            return nutritionGoalRowSubtitle
        case .healthAccess, .appleHealth:
            return WeekFitLocalizedString("settings.profile.item.healthSignals.subtitle")
        case .help:
            return WeekFitLocalizedString("settings.profile.item.helpSupport.subtitle")
        case .terms:
            return WeekFitLocalizedString("settings.profile.item.termsPrivacy.subtitle")
        case .account:
            return viewModel.accountRowSubtitle()
        default:
            return item.subtitle
        }
    }

    var nutritionGoalRowSubtitle: String {
        if nutritionGoalNeedsSetup {
            return WeekFitLocalizedString("settings.nutritionGoal.setupSubtitle")
        }
        let goal = viewModel.resolvedNutritionGoal(
            weightKg: healthManager.weight,
            heightCm: healthManager.heightCm
        )
        return NutritionGoalDisplay.title(for: goal)
    }

    func rowTint(for item: ProfileItem) -> Color {
        switch item.type {
        case .notifications:
            return accentGreen

        case .language:
            return accentBlue

        case .nightComfort:
            return Color(red: 0.62, green: 0.54, blue: 0.92)

        case .nutritionGoal:
            return Color(red: 0.95, green: 0.62, blue: 0.38)

        case .healthAccess, .appleHealth:
            return Color(red: 255/255, green: 89/255, blue: 119/255)

        case .help:
            return .cyan

        case .terms:
            return .orange

        case .account:
            return accentBlue

        default:
            return accentGreen
        }
    }

    func normalizedIcon(for item: ProfileItem) -> String {
        switch item.type {
        case .healthAccess, .appleHealth:
            return "heart.fill"

        case .help:
            return "questionmark"

        case .terms:
            return "doc.text.fill"

        default:
            return item.icon
        }
    }

    func localizedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return WeekFitLocalizedString("settings.language.option.english")
        case .russian:
            return WeekFitLocalizedString("settings.language.option.russian")
        }
    }

    func profileHealthSignalsRowSubtitle(for state: HealthDataConnectionState) -> String {
        switch state {
        case .notRequested:
            return WeekFitLocalizedString("settings.profile.item.healthSignals.setupSubtitle")
        case .denied:
            return WeekFitLocalizedString("healthAccess.hero.needsSettings.subtitle")
        case .connectedWaitingForData:
            return WeekFitLocalizedString("healthAccess.hero.connected.needsMoreData")
        case .connectedPartial:
            return WeekFitLocalizedString("healthAccess.hero.connected.partial")
        case .connected:
            return WeekFitLocalizedString("settings.profile.item.healthSignals.connectedSubtitle")
        }
    }

    func accessibilityID(for item: ProfileItem) -> String {
        switch item.type {
        case .account: return "settings.account"
        case .appleHealth, .healthAccess: return "settings.appleHealth"
        case .notifications: return "settings.notifications"
        case .language: return "settings.language"
        case .nightComfort: return "settings.nightComfort"
        case .nutritionGoal: return "settings.nutritionGoal"
        case .help: return "settings.help"
        case .terms: return "settings.terms"
        case .units: return "settings.units"
        }
    }

    func accessibilityLabel(for item: ProfileItem, showHealthStatus: Bool) -> String {
        let title = displayTitle(for: item)
        guard let subtitle = displaySubtitle(for: item, showHealthStatus: showHealthStatus),
              !subtitle.isEmpty else {
            return title
        }
        return "\(title), \(subtitle)"
    }

    func refreshHealthPermissionState() async {
        healthManager.updateAuthorizationStatus()
        let actualAccess = await healthManager.checkReadAuthorizationStatus()

        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                healthManager.isHealthAccessGranted = actualAccess
            }
        }
    }
}

// MARK: - Button Style

private struct PressableScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
