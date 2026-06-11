import SwiftUI
import SwiftData

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel

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
                    title: "Settings",
                    items: viewModel.mainSettings + viewModel.connectedSystems,
                    showHealthStatus: true
                )

                settingsBlock(
                    title: "Support",
                    items: viewModel.supportSettings,
                    showHealthStatus: false
                )

                developerSection

                footerSection
            }
            .padding(.horizontal, 24)
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
                title: "Reset local data?",
                message: "This will delete meals, logs, activities, coach history, cached images, and local preferences stored on this device. This cannot be undone.",
                secondaryTitle: "Cancel",
                primaryTitle: "Reset Data",
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
                title: "Reset failed",
                message: resetFailureMessage,
                primaryTitle: "OK",
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
            Text("Profile")
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
                .accessibilityLabel("Close")

                Spacer()
            }
        }
        .padding(.top, 2)
    }

    var healthSystemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Your system", prominent: true)
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    simpleAvatar(initials: profile.initials)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(hasName ? cleanName : "Your health system")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary)
                            .lineLimit(1)

                        Text(isConnected ? "Recovery system active" : "Health setup needed")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(isConnected ? accentGreen.opacity(0.92) : textSecondary)

                        Text(isConnected ? "Apple Health connected" : "Connect Health for smarter planning")
                            .font(.system(size: 11.8, weight: .medium))
                            .foregroundStyle(textSecondary.opacity(0.68))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    systemStatusBadge(isConnected: isConnected)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(textTertiary)
                }

                HStack(spacing: 8) {
                    compactSignal(
                        icon: "heart.fill",
                        text: "Health",
                        tint: accentGreen,
                        isHighlighted: false
                    )

                    compactSignal(
                        icon: "sparkles",
                        text: "Adaptive",
                        tint: accentBlue,
                        isHighlighted: true
                    )

                    compactSignal(
                        icon: "lock.fill",
                        text: "Private",
                        tint: accentGreen,
                        isHighlighted: false
                    )
                }
                .padding(.leading, 72)
            }
            .padding(13)
            .background {
                heroCardBackground(isConnected: isConnected)
            }
        }
        .buttonStyle(PressableScaleButtonStyle())
    }

    func compactSignal(
        icon: String,
        text: String,
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
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(isHighlighted ? tint.opacity(0.105) : .white.opacity(0.04))
                .overlay {
                    Capsule()
                        .stroke(isHighlighted ? tint.opacity(0.16) : .white.opacity(0.045), lineWidth: 1)
                }
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

    func systemStatusBadge(isConnected: Bool) -> some View {
        Image(systemName: isConnected ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
            .font(.system(size: 17, weight: .bold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isConnected ? accentGreen.opacity(0.9) : textSecondary)
    }

    func settingsBlock(
        title: String,
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

    func sectionTitle(_ title: String, prominent: Bool = false) -> some View {
        Text(title)
            .font(
                .system(
                    size: prominent ? 17 : 15,
                    weight: prominent ? .bold : .semibold,
                    design: .rounded
                )
            )
            .foregroundStyle(prominent ? textPrimary : textPrimary.opacity(0.92))
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
                    .lineLimit(1)

//                if let subtitle = displaySubtitle(for: item, showHealthStatus: showHealthStatus) {
//                    Text(subtitle)
//                        .font(.system(size: 12.6, weight: .medium))
//                        .foregroundStyle(textSecondary)
//                        .lineLimit(showHealthStatus ? 2 : 1)
//                        .fixedSize(horizontal: false, vertical: true)
//                }
            }

            Spacer(minLength: 8)

            if showHealthStatus {
                healthStatusBadge
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(textTertiary)
        }
        .padding(.horizontal, 16)
        .frame(height: showHealthStatus ? 72 : 68)
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
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        isConnected ? accentGreen.opacity(0.15) : Color.white.opacity(0.065),
                        lineWidth: 1
                    )
            }
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
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.054), lineWidth: 1)
            }
    }

    var developerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Privacy & Data")
//            coachDebugToggle
            resetLocalDataButton
        }
    }

    @ViewBuilder
    var healthStatusBadge: some View {
        if healthManager.isHealthAccessGranted {
            HStack(spacing: 5) {
                Circle()
                    .fill(accentGreen.opacity(0.9))
                    .frame(width: 5.5, height: 5.5)

                Text("Connected")
                    .font(.system(size: 11.1, weight: .bold, design: .rounded))
            }
            .foregroundStyle(accentGreen.opacity(0.88))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(accentGreen.opacity(0.095))
                    .overlay {
                        Capsule()
                            .stroke(accentGreen.opacity(0.10), lineWidth: 1)
                    }
            }
        } else {
            Text("Setup")
                .font(.system(size: 11.1, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(.white.opacity(0.05))
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.06), lineWidth: 1)
                        }
                }
        }
    }

    var resetLocalDataButton: some View {
        Button {
            withDialogAnimation {
                showResetConfirmation = true
            }
        } label: {
            Text(isResettingLocalData ? "Resetting..." : "Reset Local Data")
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(destructiveRed.opacity(0.62))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(destructiveRed.opacity(0.024))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(destructiveRed.opacity(0.10), lineWidth: 1)
                        }
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

            Text("Private by design. Stored on your device.")
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
        item.title == "Health Signals" || item.title == "Apple Health"
    }

    func displayTitle(for item: ProfileItem) -> String {
        switch item.title {
        case "Apple Health":
            return "Health Signals"
        default:
            return item.title
        }
    }

    func displaySubtitle(for item: ProfileItem, showHealthStatus: Bool) -> String? {
        if showHealthStatus {
            return healthManager.isHealthAccessGranted
                ? "Sleep, workouts and recovery connected."
                : "Connect Health to improve recommendations."
        }

        switch item.title {
        case "Notifications":
            return "Recovery and workout reminders"

        case "Help & Support":
            return "Help, guides and feedback"

        case "Terms & Privacy":
            return "Privacy and permissions"

        case "Privacy":
            return "Control how WeekFit handles your data"

        default:
            return item.subtitle
        }
    }

    func rowTint(for item: ProfileItem) -> Color {
        switch item.title {
        case "Notifications":
            return accentGreen

        case "Health Signals", "Apple Health":
            return Color(red: 255/255, green: 89/255, blue: 119/255)

        case "Help & Support":
            return .cyan

        case "Terms & Privacy":
            return .orange

        case "Privacy":
            return .indigo

        default:
            return accentGreen
        }
    }

    func normalizedIcon(for item: ProfileItem) -> String {
        switch item.title {
        case "Health Signals", "Apple Health":
            return "heart.fill"

        case "Help & Support":
            return "questionmark"

        case "Terms & Privacy":
            return "doc.text.fill"

        default:
            return item.icon
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
