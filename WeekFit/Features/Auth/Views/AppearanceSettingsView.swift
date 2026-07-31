import SwiftUI

struct AppearanceSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearance: WeekFitAppearanceController
    @Environment(\.weekFitPalette) private var palette

    private var accent: Color { WeekFitTheme.primaryGreen }

    var body: some View {
        ZStack {
            WeekFitTheme.backgroundColor.ignoresSafeArea()
            ProfilePremiumBackground(accent: accent)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text(WeekFitLocalizedString("settings.appearance.subtitle"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 0) {
                            ForEach(WeekFitAppearancePreference.allCases) { option in
                                preferenceRow(option)

                                if option.id != WeekFitAppearancePreference.allCases.last?.id {
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
        .transaction { $0.animation = nil }
    }
}

private extension AppearanceSettingsView {

    var headerSection: some View {
        ProfilePremiumHeader(
            title: WeekFitLocalizedString("settings.appearance.title"),
            accent: accent
        ) {
            dismiss()
        }
    }

    func preferenceRow(_ option: WeekFitAppearancePreference) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appearance.setPreference(option)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(palette.isLight ? accent.opacity(0.10) : .white.opacity(0.045))

                    Image(systemName: icon(for: option))
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title(for: option))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary)

                    Text(subtitle(for: option))
                        .font(.system(size: 12.6, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if appearance.preference == option {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var softDivider: some View {
        Rectangle()
            .fill(WeekFitTheme.borderSoft.opacity(0.55))
            .frame(height: 1)
            .padding(.leading, 71)
    }

    var footerNote: some View {
        Text(WeekFitLocalizedString("settings.appearance.footer"))
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    func icon(for option: WeekFitAppearancePreference) -> String {
        switch option {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    func title(for option: WeekFitAppearancePreference) -> String {
        switch option {
        case .system: return WeekFitLocalizedString("settings.appearance.option.system")
        case .light: return WeekFitLocalizedString("settings.appearance.option.light")
        case .dark: return WeekFitLocalizedString("settings.appearance.option.dark")
        }
    }

    func subtitle(for option: WeekFitAppearancePreference) -> String {
        switch option {
        case .system: return WeekFitLocalizedString("settings.appearance.option.systemSubtitle")
        case .light: return WeekFitLocalizedString("settings.appearance.option.lightSubtitle")
        case .dark: return WeekFitLocalizedString("settings.appearance.option.darkSubtitle")
        }
    }
}
