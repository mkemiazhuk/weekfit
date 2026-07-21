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

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.55))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                        .background {
                            Circle()
                                .fill(WeekFitTheme.whiteOpacity(0.08))
                        }
                }
                // Required so the close control receives taps inside SwiftUI List rows.
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(AppText.Common.Action.close))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.whiteOpacity(0.075),
                            WeekFitTheme.whiteOpacity(0.040)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 1)
        }
    }

    private func dismiss() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onDismiss()
    }
}
