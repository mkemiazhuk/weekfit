import SwiftUI

struct LanguageSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager

    private var background: Color { WeekFitTheme.backgroundColor }
    private let cardBackground = Color(red: 24/255, green: 24/255, blue: 28/255)
    private let rowBackground = WeekFitTheme.whiteOpacity(0.065)
    private var textPrimary: Color { WeekFitTheme.primaryText }
    private let textSecondary = WeekFitTheme.whiteOpacity(0.54)
    /// Calm app green — avoid the OLED neon settingsAccent in Dark Mode.
    private var accentGreen: Color { WeekFitTheme.primaryGreen }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ProfilePremiumBackground(accent: accentGreen)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppText.Settings.Language.subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 0) {
                            ForEach(AppLanguage.allCases) { language in
                                languageRow(language)

                                if language.id != AppLanguage.allCases.last?.id {
                                    softDivider
                                }
                            }
                        }
                        .profilePremiumCard(cornerRadius: 24)
                    }

                    footerNote
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 36)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private extension LanguageSettingsView {

    var ambientBackground: some View {
        VStack {
            Circle()
                .fill(accentGreen.opacity(0.06))
                .frame(width: 220, height: 220)
                .blur(radius: 120)
                .offset(x: 84, y: 22)

            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    var headerSection: some View {
        ProfilePremiumHeader(
            title: WeekFitLocalizedString("settings.language.title"),
            accent: accentGreen
        ) {
            dismiss()
        }
    }

    func languageRow(_ language: AppLanguage) -> some View {
        Button {
            languageManager.selectedLanguage = language
            ProductAnalytics.languageChanged(
                AppLanguageAnalyticsCode(languageCode: language.rawValue)
            )
        } label: {
            HStack(spacing: 14) {
                languageGlyph(language)

                Text(language.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Spacer(minLength: 8)

                if languageManager.selectedLanguage == language {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentGreen.opacity(0.92))
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func languageGlyph(_ language: AppLanguage) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(WeekFitTheme.coachSoftSurface)

            Text(language == .english ? "EN" : "RU")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(accentGreen.opacity(0.95))
                .tracking(0.4)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    var softDivider: some View {
        Rectangle()
            .fill(WeekFitTheme.borderSoft.opacity(0.55))
            .frame(height: 0.5)
            .padding(.leading, 68)
    }

    var footerNote: some View {
        Text(AppText.Settings.Language.footer)
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.34))
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .padding(.horizontal, 16)
    }
}
