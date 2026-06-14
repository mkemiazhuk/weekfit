import SwiftUI
import SwiftData

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var languageManager: AppLanguageManager

    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var healthManager = HealthManager()
    @State private var showResetConfirmation = false
    @State private var showResetFailure = false
    @State private var resetFailureMessage = ""
    @State private var isResettingLocalData = false

    @AppStorage(CoachDebugSettings.logLevelKey)
    private var coachLogLevelRaw = CoachLogLevel.off.rawValue

    private let background = Color.black

    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.54)
    private let textTertiary = Color.white.opacity(0.28)

    private let accentGreen = Color(red: 0.55, green: 0.80, blue: 0.58)
    private let accentBlue = Color(red: 0.56, green: 0.68, blue: 0.90)
    private let destructiveRed = Color(red: 255/255, green: 83/255, blue: 88/255)

    private var isShowingDialog: Bool {
        showResetConfirmation || showResetFailure
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ambientBackground

            profileContent
                .blur(radius: isShowingDialog ? 3 : 0)
                .scaleEffect(isShowingDialog ? 0.985 : 1)
                .animation(.easeOut(duration: 0.18), value: isShowingDialog)

            resetDialogOverlay
        }
        .task {
            let actualAccess = await healthManager.checkReadAuthorizationStatus()

            await MainActor.run {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    healthManager.isHealthAccessGranted = actualAccess
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $viewModel.destination) { destination in
            switch destination {
            case .editProfile:
                EditUserProfileView(viewModel: viewModel)

            case .notifications:
                NotificationSettingsView()

            case .language:
                LanguageSettingsView()

            case .healthAccess:
                HealthAccessView()
                    .environmentObject(healthManager)
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)

            case .privacy:
                PrivacySettingsView()

            case .helpSupport:
                HelpSupportView()

            case .termsPrivacy:
                TermsPrivacyView()
            }
        }
    }
}

// MARK: - Main UI

private extension ProfileView {

    var profileContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                healthSystemSection

                settingsBlock(
                    title: AppText.Settings.Profile.settingsSection,
                    items: viewModel.mainSettings + viewModel.connectedSystems,
                    showHealthStatus: true
                )

                settingsBlock(
                    title: AppText.Settings.Profile.supportSection,
                    items: viewModel.supportSettings,
                    showHealthStatus: false
                )

                developerSection

                footerSection
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
        ZStack {
            Text(AppText.Settings.Profile.title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            HStack {
                Button {
                    dismiss()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.055))
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.075), lineWidth: 1)
                            }

                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .frame(width: 46, height: 46)
                }
                .buttonStyle(PressableScaleButtonStyle())
                .accessibilityLabel(Text(AppText.Common.Action.close))

                Spacer()
            }
        }
        .padding(.top, 2)
    }

    var healthSystemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(AppText.Settings.Profile.systemSection, prominent: true)
            healthSystemCard(viewModel.userProfile)
        }
    }

    func healthSystemCard(_ profile: UserProfile) -> some View {
        let cleanName = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasName = !cleanName.isEmpty
        let isConnected = healthManager.isHealthAccessGranted

        return Button {
            viewModel.openProfileEditor()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    simpleAvatar(initials: profile.initials)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(hasName ? cleanName : WeekFitLocalizedString("settings.profile.healthSystemFallback"))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.92)

                        Text(isConnected ? WeekFitLocalizedString("settings.profile.recoverySystemActive") : WeekFitLocalizedString("settings.profile.healthSetupNeeded"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isConnected ? accentGreen.opacity(0.92) : textSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(isConnected ? WeekFitLocalizedString("settings.profile.appleHealthConnected") : WeekFitLocalizedString("settings.profile.connectHealthPlanning"))
                            .font(.system(size: 11.8, weight: .medium))
                            .foregroundStyle(textSecondary.opacity(0.68))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(textTertiary)
                        .padding(.top, 6)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    compactSignal(
                        icon: "heart.fill",
                        text: AppText.Settings.Profile.healthSignal,
                        tint: accentGreen,
                        isHighlighted: false
                    )

                    compactSignal(
                        icon: "sparkles",
                        text: AppText.Settings.Profile.adaptiveSignal,
                        tint: accentBlue,
                        isHighlighted: true
                    )

                    compactSignal(
                        icon: "lock.fill",
                        text: AppText.Settings.Profile.privateSignal,
                        tint: accentGreen,
                        isHighlighted: false
                    )
                }
            }
            .padding(15)
            .background {
                heroCardBackground(isConnected: isConnected)
            }
        }
        .buttonStyle(PressableScaleButtonStyle())
    }

    func compactSignal(
        icon: String,
        text: LocalizedStringResource,
        tint: Color,
        isHighlighted: Bool
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint.opacity(isHighlighted ? 0.95 : 0.85))

            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(isHighlighted ? 0.86 : 0.74))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(isHighlighted ? tint.opacity(0.105) : Color.white.opacity(0.035))
        }
    }

    func simpleAvatar(initials: String) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 248/255, green: 229/255, blue: 188/255),
                            Color(red: 217/255, green: 177/255, blue: 105/255)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(initials.isEmpty ? "P" : initials)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
        }
        .frame(width: 52, height: 52)
        .overlay {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    func settingsBlock(
        title: LocalizedStringResource,
        items: [ProfileItem],
        showHealthStatus: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(title)

            VStack(spacing: 10) {
                ForEach(items) { item in
                    Button {
                        viewModel.handleTap(item)
                    } label: {
                        profileRow(
                            item,
                            showHealthStatus: showHealthStatus && isHealthSignalsItem(item)
                        )
                    }
                    .buttonStyle(PressableScaleButtonStyle())
                }
            }
        }
    }

    func sectionTitle(_ title: LocalizedStringResource, prominent: Bool = false) -> some View {
        Text(title)
            .font(
                .system(
                    size: prominent ? 17 : 15,
                    weight: prominent ? .bold : .semibold,
                    design: .rounded
                )
            )
            .foregroundStyle(prominent ? textPrimary : textPrimary.opacity(0.92))
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    func profileRow(
        _ item: ProfileItem,
        showHealthStatus: Bool = false
    ) -> some View {
        HStack(spacing: 13) {
            rowIcon(for: item)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle(for: item))
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.94)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = displaySubtitle(for: item, showHealthStatus: showHealthStatus) {
                    Text(subtitle)
                        .font(.system(size: 12.6, weight: .medium))
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

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: showHealthStatus ? 76 : 68)
        .background {
            premiumCardBackground(cornerRadius: 23)
        }
        .contentShape(Rectangle())
    }

    func rowIcon(for item: ProfileItem) -> some View {
        ZStack {
            Circle()
                .fill(rowTint(for: item).opacity(0.13))

            Image(systemName: normalizedIcon(for: item))
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(rowTint(for: item).opacity(0.96))
        }
        .frame(width: 34, height: 34)
    }

    func heroCardBackground(isConnected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        isConnected ? accentGreen.opacity(0.12) : Color.white.opacity(0.052),
                        Color.white.opacity(0.026)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(
                color: isConnected ? accentGreen.opacity(0.048) : .clear,
                radius: 18,
                y: 8
            )
    }

    func premiumCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.042),
                        Color.white.opacity(0.020)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    var developerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(AppText.Settings.Profile.privacyDataSection)
//            coachDebugToggle
            resetLocalDataButton
        }
    }

    @ViewBuilder
    var healthStatusBadge: some View {
        if !healthManager.isHealthAccessGranted {
            Text(AppText.Settings.Profile.setupBadge)
                .font(.system(size: 11.1, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(.white.opacity(0.05))
                }
        }
    }

    var resetLocalDataButton: some View {
        Button {
            withDialogAnimation {
                showResetConfirmation = true
            }
        } label: {
            Text(isResettingLocalData ? AppText.Settings.Profile.resettingLocalData : AppText.Settings.Profile.resetLocalData)
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(destructiveRed.opacity(0.62))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(destructiveRed.opacity(0.024))
                }
        }
        .buttonStyle(PressableScaleButtonStyle())
        .disabled(isResettingLocalData)
        .opacity(isResettingLocalData ? 0.62 : 1)
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
            premiumCardBackground(cornerRadius: 23)
        }
    }

    var footerSection: some View {
        VStack(spacing: 4) {
            Text("WeekFit")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.64))

            Text(AppText.Settings.Profile.footerPrivacy)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textSecondary.opacity(0.44))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }
}

// MARK: - Helpers

private extension ProfileView {

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
            print("[LocalDataReset][Failure] UI reset flow: \(error)")
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
        case .healthAccess, .appleHealth:
            return WeekFitLocalizedString("settings.profile.item.healthSignals")
        case .help:
            return WeekFitLocalizedString("settings.profile.item.helpSupport")
        case .terms:
            return WeekFitLocalizedString("settings.profile.item.termsPrivacy")
        case .privacy:
            return WeekFitLocalizedString("settings.profile.item.privacy")
        case .units:
            return item.title
        }
    }

    func displaySubtitle(for item: ProfileItem, showHealthStatus: Bool) -> String? {
        if showHealthStatus {
            return healthManager.isHealthAccessGranted
                ? WeekFitLocalizedString("settings.profile.item.healthSignals.connectedSubtitle")
                : WeekFitLocalizedString("settings.profile.item.healthSignals.setupSubtitle")
        }

        switch item.type {
        case .notifications:
            return WeekFitLocalizedString("settings.profile.item.notifications.subtitle")
        case .language:
            return String(
                format: WeekFitLocalizedString("settings.language.currentFormat"),
                localizedTitle(for: languageManager.selectedLanguage)
            )
        case .healthAccess, .appleHealth:
            return WeekFitLocalizedString("settings.profile.item.healthSignals.subtitle")
        case .help:
            return WeekFitLocalizedString("settings.profile.item.helpSupport.subtitle")
        case .terms:
            return WeekFitLocalizedString("settings.profile.item.termsPrivacy.subtitle")
        case .privacy:
            return WeekFitLocalizedString("settings.profile.item.privacy.subtitle")
        default:
            return item.subtitle
        }
    }

    func rowTint(for item: ProfileItem) -> Color {
        switch item.type {
        case .notifications:
            return accentGreen

        case .language:
            return accentBlue

        case .healthAccess, .appleHealth:
            return Color(red: 255/255, green: 89/255, blue: 119/255)

        case .help:
            return .cyan

        case .terms:
            return .orange

        case .privacy:
            return .indigo

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
