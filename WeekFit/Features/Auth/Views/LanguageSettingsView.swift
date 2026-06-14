import SwiftUI

struct LanguageSettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager

    private let background = Color.black
    private let cardBackground = Color(red: 24/255, green: 24/255, blue: 28/255)
    private let rowBackground = Color.white.opacity(0.065)
    private let textPrimary = Color.white
    private let textSecondary = Color.white.opacity(0.54)
    private let accentGreen = Color(red: 170/255, green: 255/255, blue: 70/255)

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ambientBackground

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
                        .background {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(cardBackground)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(.white.opacity(0.04), lineWidth: 1)
                                }
                        }
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
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(rowBackground)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.08), lineWidth: 1)
                        }

                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                }
                .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(AppText.Common.Action.back))

            Spacer()

            Text(AppText.Settings.Language.title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            Spacer()

            Color.clear
                .frame(width: 48, height: 48)
        }
    }

    func languageRow(_ language: AppLanguage) -> some View {
        Button {
            languageManager.selectedLanguage = language
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(.white.opacity(0.045))

                    Image(systemName: "globe")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(accentGreen)
                }
                .frame(width: 40, height: 40)

                Text(language.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)

                Spacer(minLength: 8)

                if languageManager.selectedLanguage == language {
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

    var softDivider: some View {
        Divider()
            .overlay(.white.opacity(0.035))
            .padding(.leading, 68)
    }

    var footerNote: some View {
        Text(AppText.Settings.Language.footer)
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.34))
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .padding(.horizontal, 16)
    }
}
