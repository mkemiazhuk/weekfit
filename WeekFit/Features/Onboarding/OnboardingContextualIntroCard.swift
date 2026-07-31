import SwiftUI

/// One-time, dismissible intro used inside tabs — not in first-run onboarding.
struct OnboardingContextualIntroCard: View {
    let title: String
    let message: String
    let accent: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.56))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                WeekFitCloseButton(size: .compact, usesBorderlessStyle: true, action: dismiss)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .weekFitPremiumCard(emphasis: .standard, accent: accent, cornerRadius: 20)
    }

    private func dismiss() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onDismiss()
    }
}
