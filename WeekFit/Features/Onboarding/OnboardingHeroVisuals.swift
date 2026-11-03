import SwiftUI

/// Health trust beat — three reasons, then the recovery card the user will see.
struct OnboardingHealthSignalsStage: View {
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                OnboardingTrustPoint(
                    icon: "moon.zzz.fill",
                    color: WeekFitProgressRingColor.recovery,
                    title: WeekFitLocalizedString("onboarding.v16.health.sleep.title"),
                    subtitle: WeekFitLocalizedString("onboarding.v16.health.sleep.body")
                )
                OnboardingChoiceDivider()
                OnboardingTrustPoint(
                    icon: "figure.run",
                    color: WeekFitProgressRingColor.activity,
                    title: WeekFitLocalizedString("onboarding.v16.health.activity.title"),
                    subtitle: WeekFitLocalizedString("onboarding.v16.health.activity.body")
                )
                OnboardingChoiceDivider()
                OnboardingTrustPoint(
                    icon: "lock.shield.fill",
                    color: WeekFitTheme.brandGold,
                    title: WeekFitLocalizedString("onboarding.v16.health.privacy.title"),
                    subtitle: WeekFitLocalizedString("onboarding.v16.health.privacy.body")
                )
            }
            .profilePremiumCard(cornerRadius: OnboardingLayout.cardCornerRadius)

            recoveryPreview
        }
        .accessibilityElement(children: .contain)
    }

    private var recoveryPreview: some View {
        HStack(spacing: 14) {
            WeekFitProgressRing(
                progress: OnboardingSampleData.morningRecoveryProgress,
                color: WeekFitProgressRingColor.recovery,
                size: 64,
                strokeWidth: 4
            ) {
                Text("\(OnboardingSampleData.morningRecoveryPercent)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(WeekFitLocalizedString("today.status.recovery"))
                    .font(.system(size: OnboardingLayout.Eyebrow.size, weight: .bold, design: .rounded))
                    .tracking(OnboardingLayout.Eyebrow.tracking)
                    .textCase(.uppercase)
                    .foregroundStyle(WeekFitProgressRingColor.recovery)

                Text(WeekFitLocalizedString("recovery.details.status.wellRecovered"))
                    .font(.system(size: OnboardingLayout.CardTitle.size, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(WeekFitLocalizedString("onboarding.v16.health.sleep.title"))
                    .font(.system(size: OnboardingLayout.CardSecondary.size, weight: .medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(OnboardingLayout.cardRowHorizontal)
        .weekFitPremiumCard(
            accent: WeekFitProgressRingColor.recovery,
            cornerRadius: OnboardingLayout.cardCornerRadius,
            featured: true
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(WeekFitLocalizedString("today.status.recovery")). \(OnboardingSampleData.morningRecoveryPercent). \(WeekFitLocalizedString("recovery.details.status.wellRecovered"))"
        )
    }
}

struct OnboardingTrustPoint: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    @Environment(\.weekFitPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = OnboardingLayout.CardTitle.size
    @ScaledMetric(relativeTo: .footnote) private var subtitleSize: CGFloat = OnboardingLayout.CardSecondary.size
    @ScaledMetric(relativeTo: .body) private var iconSide: CGFloat = 32

    var body: some View {
        HStack(alignment: .top, spacing: OnboardingLayout.cardRowSpacing) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: iconSide, height: iconSide)
                .background {
                    Circle().fill(color.opacity(palette.isLight ? 0.14 : 0.18))
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.system(size: subtitleSize, weight: .medium))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, OnboardingLayout.cardRowHorizontal)
        .padding(.vertical, OnboardingLayout.cardRowVertical)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

typealias OnboardingWatchToTodayStage = OnboardingHealthSignalsStage
