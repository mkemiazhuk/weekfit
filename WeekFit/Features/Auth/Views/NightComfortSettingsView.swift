import SwiftUI

struct NightComfortSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var nightComfort: NightComfortController

    private let background = Color.black
    private var textPrimary: Color { WeekFitTheme.primaryText }
    private let textSecondary = WeekFitTheme.whiteOpacity(0.54)
    private let accentGreen = Color(red: 170/255, green: 255/255, blue: 70/255)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ProfilePremiumBackground(accent: accentGreen)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text(WeekFitLocalizedString("settings.nightComfort.subtitle"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 0) {
                            ForEach(NightComfortPreference.allCases) { option in
                                preferenceRow(option)

                                if option.id != NightComfortPreference.allCases.last?.id {
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

private extension NightComfortSettingsView {

    var headerSection: some View {
        ProfilePremiumHeader(
            title: WeekFitLocalizedString("settings.nightComfort.title"),
            accent: accentGreen
        ) {
            dismiss()
        }
    }

    func preferenceRow(_ option: NightComfortPreference) -> some View {
        Button {
            nightComfort.setPreference(option)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(.white.opacity(0.045))

                    Image(systemName: icon(for: option))
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(accentGreen)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title(for: option))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)

                    Text(subtitle(for: option))
                        .font(.system(size: 12.6, weight: .medium))
                        .foregroundStyle(textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if nightComfort.preference == option {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentGreen)
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func icon(for option: NightComfortPreference) -> String {
        switch option {
        case .automatic: return "moon.stars.fill"
        case .alwaysOn: return "moon.fill"
        case .off: return "sun.max.fill"
        }
    }

    func title(for option: NightComfortPreference) -> String {
        switch option {
        case .automatic: return WeekFitLocalizedString("settings.nightComfort.option.automatic")
        case .alwaysOn: return WeekFitLocalizedString("settings.nightComfort.option.alwaysOn")
        case .off: return WeekFitLocalizedString("settings.nightComfort.option.off")
        }
    }

    func subtitle(for option: NightComfortPreference) -> String {
        switch option {
        case .automatic: return WeekFitLocalizedString("settings.nightComfort.option.automaticSubtitle")
        case .alwaysOn: return WeekFitLocalizedString("settings.nightComfort.option.alwaysOnSubtitle")
        case .off: return WeekFitLocalizedString("settings.nightComfort.option.offSubtitle")
        }
    }

    var softDivider: some View {
        Divider()
            .overlay(.white.opacity(0.035))
            .padding(.leading, 68)
    }

    var footerNote: some View {
        Text(WeekFitLocalizedString("settings.nightComfort.footer"))
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.34))
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .padding(.horizontal, 16)
    }
}
