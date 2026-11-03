import SwiftUI

/// Maya as an AI coach — voice, not a surprise phone call.
struct OnboardingMayaIdentityRow: View {
    var embedded = false

    @Environment(\.weekFitPalette) private var palette
    @ScaledMetric(relativeTo: .callout) private var nameSize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption) private var roleSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption) private var chipSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WeekFitTheme.brandGold)
                .frame(width: 28, height: 28)
                .background {
                    Circle().fill(WeekFitTheme.brandGold.opacity(palette.isLight ? 0.14 : 0.18))
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(WeekFitLocalizedString("planner.voice.maya"))
                    .font(.system(size: nameSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                Text(WeekFitLocalizedString("today.maya.subtitle"))
                    .font(.system(size: roleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)

            Text(WeekFitLocalizedString("onboarding.v16.maya.voice"))
                .font(.system(size: chipSize, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.brandGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule(style: .continuous)
                        .strokeBorder(WeekFitTheme.brandGold.opacity(0.55), lineWidth: 1)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .modifier(OnboardingMayaIdentityChrome(embedded: embedded))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(WeekFitLocalizedString("planner.voice.maya")). \(WeekFitLocalizedString("today.maya.subtitle")). \(WeekFitLocalizedString("onboarding.v16.maya.voice"))"
        )
    }
}

private struct OnboardingMayaIdentityChrome: ViewModifier {
    let embedded: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if embedded {
            content
        } else {
            content.weekFitPremiumCard(emphasis: .compact, cornerRadius: 16)
        }
    }
}
