import SwiftUI

struct UnitsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var unitsStore: WeekFitUnitsStore
    @EnvironmentObject private var languageManager: AppLanguageManager

    private var background: Color { WeekFitTheme.backgroundColor }
    private var textPrimary: Color { WeekFitTheme.primaryText }
    private var textSecondary: Color { WeekFitTheme.secondaryText }
    private var accent: Color { WeekFitTheme.settingsAccent }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ProfilePremiumBackground(accent: accent)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerSection

                    VStack(spacing: 0) {
                        ForEach(WeekFitUnitPreference.allCases, id: \.id) { preference in
                            preferenceRow(preference)
                            if preference.id != WeekFitUnitPreference.allCases.last?.id {
                                softDivider
                            }
                        }
                    }
                    .profilePremiumCard(cornerRadius: 24)

                    footerNote
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 36)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .id(languageManager.selectedLanguage)
    }
}

private extension UnitsSettingsView {
    var headerSection: some View {
        ProfilePremiumHeader(
            title: WeekFitLocalizedString("settings.units.title"),
            subtitle: WeekFitLocalizedString("settings.units.subtitle"),
            titleSize: 24,
            accent: accent
        ) {
            dismiss()
        }
    }

    var softDivider: some View {
        Rectangle()
            .fill(WeekFitTheme.borderSoft.opacity(0.55))
            .frame(height: 0.5)
            .padding(.leading, 68)
    }

    var footerNote: some View {
        Text(WeekFitLocalizedString("settings.units.footer"))
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(WeekFitTheme.tertiaryText)
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .padding(.horizontal, 16)
    }

    func preferenceRow(_ preference: WeekFitUnitPreference) -> some View {
        let isSelected = unitsStore.selectedPreference == preference
        let isRecommended = preference == .automatic

        return Button {
            unitsStore.setSelectedPreference(preference)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(WeekFitTheme.settingsIconWell)

                    Image(systemName: icon(for: preference))
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(accent)
                        .symbolRenderingMode(.monochrome)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 5) {
                    Text(preference.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .allowsTightening(true)

                    if isRecommended {
                        Text(WeekFitLocalizedString("settings.units.recommended"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(WeekFitTheme.settingsAccent)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background {
                                Capsule().fill(WeekFitTheme.settingsIconWell)
                            }
                    }

                    Text(preference.subtitle)
                        .font(.system(size: 12.6, weight: .medium))
                        .foregroundStyle(textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                } else {
                    Color.clear.frame(width: 18, height: 18)
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel(for: preference)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    func icon(for preference: WeekFitUnitPreference) -> String {
        switch preference {
        case .automatic: return "arrow.triangle.2.circlepath"
        case .metric: return "ruler"
        case .uk: return "map"
        // Prefer a widely available glyph; `globe.americas.fill` can render blank on some OS builds.
        case .us: return "flag.fill"
        }
    }

    func accessibilityLabel(for preference: WeekFitUnitPreference) -> String {
        let isSelected = unitsStore.selectedPreference == preference
        let isRecommended = preference == .automatic

        var parts = [preference.displayName, preference.subtitle]
        if isSelected {
            parts.append(WeekFitLocalizedString("settings.units.a11y.selected"))
        }
        if isRecommended {
            parts.append(WeekFitLocalizedString("settings.units.recommended"))
        }
        return parts.joined(separator: ". ")
    }
}
