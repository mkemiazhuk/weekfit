import SwiftUI
import SwiftData

struct AccountSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var nutritionViewModel: NutritionViewModel
    @EnvironmentObject private var coachCoordinator: CoachCoordinator
    @EnvironmentObject private var appSession: AppSessionState
    @EnvironmentObject private var healthManager: HealthManager

    @ObservedObject var profileViewModel: ProfileViewModel

    @State private var showEditName = false
    @State private var showDeleteConfirmation = false
    @State private var showDeleteFailure = false
    @State private var showDeleteSuccess = false
    @State private var isDeletingAccount = false
    @State private var deleteFailureMessage = ""

    /// Optional injection for tests; production creates `AccountDeletionService` on demand.
    private let deletionServiceOverride: AccountDeletionServicing?

    private let background = Color.black
    private var textPrimary: Color { WeekFitTheme.primaryText }
    private let textSecondary = WeekFitTheme.whiteOpacity(0.54)
    private let destructiveRed = Color(red: 255/255, green: 83/255, blue: 88/255)

    private var isShowingDialog: Bool {
        showDeleteConfirmation || showDeleteFailure || showDeleteSuccess
    }

    private var profile: UserProfile {
        profileViewModel.userProfile
    }

    init(
        profileViewModel: ProfileViewModel,
        deletionService: AccountDeletionServicing? = nil
    ) {
        self.profileViewModel = profileViewModel
        self.deletionServiceOverride = deletionService
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ProfilePremiumBackground(accent: destructiveRed.opacity(0.55))

            accountContent
                .blur(radius: isShowingDialog || isDeletingAccount ? 3 : 0)
                .scaleEffect(isShowingDialog || isDeletingAccount ? 0.985 : 1)
                .animation(.easeOut(duration: 0.18), value: isShowingDialog || isDeletingAccount)

            if isDeletingAccount {
                deletingOverlay
            }

            dialogOverlay
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showEditName) {
            EditNameView(viewModel: profileViewModel)
                .settingsNavigationPush()
        }
        .onChange(of: showEditName) { _, isPresented in
            if !isPresented {
                profileViewModel.reloadUserProfile()
            }
        }
    }
}

// MARK: - Content

private extension AccountSettingsView {

    var accountContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header

                accountSummaryCard

                accountActionsGroup

                deleteAccountSection

                appleHealthPrivacyNote
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .disabled(isDeletingAccount)
    }

    var header: some View {
        ProfilePremiumHeader(
            title: WeekFitLocalizedString("settings.account.title"),
            titleSize: 24,
            accent: WeekFitStyle.brandGreen
        ) {
            dismiss()
        }
    }

    var accountSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WeekFitLocalizedString("settings.account.summary.headline"))
                .font(.headline)
                .foregroundStyle(textPrimary)

            Text(accountIdentityLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(WeekFitLocalizedString("settings.account.summary.body"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(textSecondary.opacity(0.88))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .profilePremiumSectionCard(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    var accountIdentityLabel: String {
        let email = profile.email.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        if AppReviewDemoCredentials.hasActiveSession {
            return AppReviewDemoCredentials.email
        }
        if !email.isEmpty { return email }
        if !name.isEmpty { return name }
        if AuthSessionStore.hasPersistedAppleSession {
            return WeekFitLocalizedString("settings.account.summary.appleSignIn")
        }
        return WeekFitLocalizedString("settings.account.summary.signedIn")
    }

    var accountActionsGroup: some View {
        SettingsGroupedSection {
            editNameButton
            SettingsGroupDivider()
            signOutButton
        }
    }

    var editNameButton: some View {
        Button {
            showEditName = true
        } label: {
            accountRow(
                icon: "pencil",
                iconTint: WeekFitStyle.brandGreen,
                title: WeekFitLocalizedString("settings.editName.title"),
                titleColor: textPrimary,
                showsChevron: true
            )
        }
        .buttonStyle(AccountPressableButtonStyle())
        .accessibilityIdentifier("settings.editName")
        .accessibilityLabel(WeekFitLocalizedString("settings.editName.title"))
        .accessibilityHint(WeekFitLocalizedString("settings.a11y.opensDetail"))
        .disabled(isDeletingAccount)
    }

    var signOutButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            authViewModel.signOut()
        } label: {
            accountRow(
                icon: "rectangle.portrait.and.arrow.right",
                iconTint: WeekFitTheme.whiteOpacity(0.88),
                iconBackground: WeekFitTheme.whiteOpacity(0.10),
                title: WeekFitLocalizedString("settings.profile.signOut"),
                titleColor: WeekFitTheme.whiteOpacity(0.86),
                showsChevron: false
            )
        }
        .buttonStyle(AccountPressableButtonStyle())
        .accessibilityIdentifier("settings.signOut")
        .accessibilityLabel(Text(AppText.Settings.Profile.signOut))
        .accessibilityHint(WeekFitLocalizedString("settings.a11y.signOut.hint"))
        .disabled(isDeletingAccount)
    }

    var deleteAccountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WeekFitLocalizedString("settings.account.dangerZone"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(textSecondary.opacity(0.72))
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.leading, 4)
                .accessibilityAddTraits(.isHeader)

            SettingsGroupedSection {
                Button {
                    withDialogAnimation {
                        showDeleteConfirmation = true
                    }
                } label: {
                    accountRow(
                        icon: "trash.fill",
                        iconTint: destructiveRed.opacity(0.96),
                        iconBackground: destructiveRed.opacity(0.16),
                        title: WeekFitLocalizedString("settings.account.deleteAccount"),
                        titleColor: destructiveRed.opacity(0.94),
                        showsChevron: false
                    )
                }
                .buttonStyle(AccountPressableButtonStyle())
                .accessibilityIdentifier("account.deleteAccount")
                .accessibilityLabel(Text(AppText.Settings.Account.deleteAccount))
                .accessibilityHint(WeekFitLocalizedString("settings.a11y.deleteAccount.hint"))
                .disabled(isDeletingAccount)
            }
        }
        .padding(.top, 10)
    }

    func accountRow(
        icon: String,
        iconTint: Color,
        iconBackground: Color? = nil,
        title: String,
        titleColor: Color,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(iconBackground ?? iconTint.opacity(0.14))

                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(iconTint)
            }
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)

            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(titleColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.28))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .settingsRowTouchTarget(minHeight: 52)
    }

    var appleHealthPrivacyNote: some View {
        Text(WeekFitLocalizedString("settings.account.healthPrivacyNote"))
            .font(.footnote.weight(.medium))
            .foregroundStyle(textSecondary.opacity(0.64))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    var deletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white.opacity(0.9))
                    .scaleEffect(1.1)

                Text(WeekFitLocalizedString("settings.account.deleting"))
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(0.92))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.72))
                    .background {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(WeekFitTheme.backgroundColor.opacity(0.92))
                    }
            }
        }
        .accessibilityLabel(WeekFitLocalizedString("settings.account.deleting"))
        .zIndex(15)
    }

    @ViewBuilder
    var dialogOverlay: some View {
        if showDeleteConfirmation {
            ConfirmationDialogView(
                icon: "trash.fill",
                iconTint: destructiveRed,
                title: WeekFitLocalizedString("settings.account.deleteConfirm.title"),
                message: WeekFitLocalizedString("settings.account.deleteConfirm.message"),
                secondaryTitle: WeekFitLocalizedString("common.action.cancel"),
                primaryTitle: WeekFitLocalizedString("settings.account.deleteConfirm.primary"),
                isPrimaryDestructive: true,
                dismissOnBackgroundTap: false,
                onSecondary: {
                    withDialogAnimation {
                        showDeleteConfirmation = false
                    }
                },
                onPrimary: {
                    withDialogAnimation {
                        showDeleteConfirmation = false
                    }
                    Task {
                        await performAccountDeletion()
                    }
                }
            )
        } else if showDeleteFailure {
            ConfirmationDialogView(
                icon: "exclamationmark.circle.fill",
                iconTint: destructiveRed,
                title: WeekFitLocalizedString("settings.account.deleteFailed.title"),
                message: deleteFailureMessage,
                secondaryTitle: WeekFitLocalizedString("common.action.cancel"),
                primaryTitle: WeekFitLocalizedString("common.action.retry"),
                isPrimaryDestructive: true,
                dismissOnBackgroundTap: false,
                onSecondary: {
                    withDialogAnimation {
                        showDeleteFailure = false
                    }
                },
                onPrimary: {
                    withDialogAnimation {
                        showDeleteFailure = false
                    }
                    Task {
                        await performAccountDeletion()
                    }
                }
            )
        } else if showDeleteSuccess {
            ConfirmationDialogView(
                icon: "checkmark.circle.fill",
                iconTint: WeekFitStyle.brandGreen,
                title: WeekFitLocalizedString("settings.account.deleteSuccess.title"),
                message: WeekFitLocalizedString("settings.account.deleteSuccess.message"),
                secondaryTitle: WeekFitLocalizedString("settings.account.deleteSuccess.openSettings"),
                primaryTitle: WeekFitLocalizedString("common.action.ok"),
                dismissOnBackgroundTap: false,
                onSecondary: {
                    openSystemSettingsForPermissionRevocation()
                    finishDeletionAndReturnToLogin()
                },
                onPrimary: {
                    finishDeletionAndReturnToLogin()
                }
            )
        }
    }

    func openSystemSettingsForPermissionRevocation() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func withDialogAnimation(_ updates: @escaping () -> Void) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            updates()
        }
    }

    func performAccountDeletion() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true

        do {
            let service = deletionServiceOverride ?? AccountDeletionService()
            try await service.deleteAccount(
                modelContext: modelContext,
                nutritionViewModel: nutritionViewModel,
                coachCoordinator: coachCoordinator
            )

            // Do NOT call triggerLocalDataResetCompleted here — that dismisses the
            // Profile sheet (via TodayView) before the user can confirm success and
            // leaves isLoggedIn == true on the main app UI.
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            withDialogAnimation {
                showDeleteSuccess = true
            }
        } catch {
            deleteFailureMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withDialogAnimation {
                showDeleteFailure = true
            }
        }

        isDeletingAccount = false
    }

    func finishDeletionAndReturnToLogin() {
        withDialogAnimation {
            showDeleteSuccess = false
        }
        // Sign out first so ContentView swaps to LoginView and tears down the sheet tree.
        authViewModel.completeAccountDeletionSignOut()
    }
}

private struct AccountPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
