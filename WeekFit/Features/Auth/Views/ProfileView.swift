import SwiftUI

struct ProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var healthManager = HealthManager()

    private let background = Color.black

    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.52)
    private let textTertiary = Color.white.opacity(0.24)

    private let accentGreen = Color(red: 0.55, green: 0.80, blue: 0.58)
    private let destructiveRed = Color(red: 255/255, green: 83/255, blue: 88/255)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ambientBackground

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection

                    accountSection

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

                    resetLocalDataButton

                    footerSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        .task {
            // Принудительно запускаем проверку реального чтения Apple Health при каждом открытии профиля
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

    var ambientBackground: some View {
        ZStack {
            Circle()
                .fill(accentGreen.opacity(0.045))
                .frame(width: 220, height: 220)
                .blur(radius: 120)
                .offset(x: -110, y: -40)

            Circle()
                .fill(Color.purple.opacity(0.035))
                .frame(width: 240, height: 240)
                .blur(radius: 130)
                .offset(x: 130, y: 80)
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
                                    .stroke(.white.opacity(0.07), lineWidth: 1)
                            }

                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
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

    var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Account")
            accountCard(viewModel.userProfile)
        }
    }

    func accountCard(_ profile: UserProfile) -> some View {
        let cleanName = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasName = !cleanName.isEmpty
        let isHealthConnected = healthManager.isHealthAccessGranted

        return Button {
            viewModel.openProfileEditor()
        } label: {
            HStack(spacing: 14) {
                simpleAvatar(initials: hasName ? profile.initials : "P")

                VStack(alignment: .leading, spacing: 4) {
                    Text(hasName ? cleanName : "Profile")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)

                    Text(isHealthConnected ? "Health profile synced" : "Health profile not connected")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(isHealthConnected ? accentGreen.opacity(0.82) : textSecondary)

                    Text(isHealthConnected ? "Apple Health connected" : "Connect Apple Health for insights")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(textSecondary.opacity(0.78))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(textTertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 82)
            .background {
                premiumCardBackground(cornerRadius: 24)
            }
        }
        .buttonStyle(PressableScaleButtonStyle())
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
        .frame(width: 50, height: 50)
        .overlay {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
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
                            showHealthStatus: showHealthStatus && item.title == "Apple Health"
                        )
                    }
                    .buttonStyle(PressableScaleButtonStyle())
                }
            }
        }
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(textPrimary)
    }

    func profileRow(
        _ item: ProfileItem,
        showHealthStatus: Bool = false
    ) -> some View {
        HStack(spacing: 13) {
            rowIcon(for: item)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)

                if let subtitle = item.subtitle, !showHealthStatus {
                    Text(subtitle)
                        .font(.system(size: 12.8, weight: .medium))
                        .foregroundStyle(textSecondary)
                        .lineLimit(1)
                }
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
        .frame(height: 68)
        .background {
            premiumCardBackground(cornerRadius: 23)
        }
        .contentShape(Rectangle())
    }

    func rowIcon(for item: ProfileItem) -> some View {
        ZStack {
            Circle()
                .fill(rowTint(for: item).opacity(0.13))

            if item.title == "Apple Health" {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 255/255, green: 45/255, blue: 85/255),
                                Color(red: 255/255, green: 99/255, blue: 72/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                Image(systemName: normalizedIcon(for: item))
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(rowTint(for: item).opacity(0.95))
            }
        }
        .frame(width: 34, height: 34)
    }

    func premiumCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.046),
                        Color.white.opacity(0.022)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.058), lineWidth: 1)
            }
    }

    @ViewBuilder
    var healthStatusBadge: some View {
        if healthManager.isHealthAccessGranted {
            HStack(spacing: 5) {
                Circle()
                    .fill(accentGreen.opacity(0.9))
                    .frame(width: 6, height: 6)

                Text("Connected")
                    .font(.system(size: 11.2, weight: .bold, design: .rounded))
            }
            .foregroundStyle(accentGreen.opacity(0.88))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(accentGreen.opacity(0.10))
                    .overlay {
                        Capsule()
                            .stroke(accentGreen.opacity(0.10), lineWidth: 1)
                    }
            }
        } else {
            Text("Not connected")
                .font(.system(size: 11.2, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))
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
            viewModel.resetLocalData()
        } label: {
            Text("Reset local data")
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .foregroundStyle(destructiveRed.opacity(0.82))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(destructiveRed.opacity(0.035))
                        .overlay {
                            RoundedRectangle(cornerRadius: 23, style: .continuous)
                                .stroke(destructiveRed.opacity(0.13), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(PressableScaleButtonStyle())
    }

    var footerSection: some View {
        VStack(spacing: 4) {
            Text("WeekFit")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.7))

            Text("Private by design. Stored on your device.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textSecondary.opacity(0.48))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }
}

// MARK: - Helpers

private extension ProfileView {

    func rowTint(for item: ProfileItem) -> Color {
        switch item.title {
        case "Notifications":
            return accentGreen
        case "Apple Health":
            return Color(red: 255/255, green: 45/255, blue: 85/255)
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
