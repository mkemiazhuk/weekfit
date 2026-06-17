import SwiftUI

struct PrivacySettingsView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProfilePremiumBackground(accent: WeekFitStyle.brandGreen)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(WeekFitStyle.brandGreen)

                        Text(WeekFitLocalizedString("privacy.settings.headline"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(WeekFitLocalizedString("privacy.settings.body"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .profilePremiumCard(cornerRadius: 24, glow: WeekFitStyle.brandGreen.opacity(0.040))
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        ProfilePremiumHeader(
            title: WeekFitLocalizedString("privacy.settings.title"),
            accent: WeekFitStyle.brandGreen
        ) {
            dismiss()
        }
    }
}

