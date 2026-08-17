import SwiftUI

/// One causal story: recovery changes → Coach notices → plan adapts.
struct OnboardingAdaptationStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase = 0

    private var morning: Int { OnboardingSampleData.morningRecoveryPercent }
    private var afternoon: Int { OnboardingSampleData.afternoonRecoveryPercent }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            recoveryCard
                .opacity(phase >= 0 ? 1 : 0)

            if phase >= 1 {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WeekFitTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .transition(.opacity)

                coachCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear { run() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        [
            WeekFitLocalizedString("onboarding.understanding.demo.recovery"),
            WeekFitLocalizedString("onboarding.understanding.demo.adjusted"),
            WeekFitLocalizedString("onboarding.understanding.demo.strength"),
            WeekFitLocalizedString("onboarding.understanding.demo.calories"),
            WeekFitLocalizedString("onboarding.understanding.demo.lunch")
        ].joined(separator: ". ")
    }

    private var recoveryCard: some View {
        HStack(spacing: 14) {
            WeekFitProgressRing(
                progress: OnboardingSampleData.afternoonRecoveryProgress,
                color: WeekFitProgressRingColor.recovery,
                size: 52,
                strokeWidth: 3.4
            ) {
                Text("\(afternoon)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
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

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(morning)%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .monospacedDigit()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WeekFitTheme.tertiaryText)
                    Text("\(afternoon)%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(OnboardingLayout.cardRowHorizontal)
        .weekFitPremiumCard(
            accent: WeekFitProgressRingColor.recovery,
            cornerRadius: OnboardingLayout.cardCornerRadius,
            featured: false
        )
    }

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(WeekFitLocalizedString("onboarding.understanding.demo.adjusted"))
                .font(.system(size: OnboardingLayout.CardTitle.size, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                adaptationRow(
                    icon: "figure.strengthtraining.traditional",
                    color: WeekFitProgressRingColor.activity,
                    text: WeekFitLocalizedString("onboarding.understanding.demo.strength")
                )
                adaptationRow(
                    icon: "flame.fill",
                    color: WeekFitProgressRingColor.nutrition,
                    text: WeekFitLocalizedString("onboarding.understanding.demo.calories")
                )
                adaptationRow(
                    icon: "fork.knife",
                    color: WeekFitProgressRingColor.nutrition,
                    text: WeekFitLocalizedString("onboarding.understanding.demo.lunch")
                )
            }
        }
        .padding(OnboardingLayout.cardRowHorizontal)
        .weekFitPremiumCard(
            accent: WeekFitTheme.coachAccent,
            cornerRadius: OnboardingLayout.cardCornerRadius,
            featured: true
        )
    }

    private func adaptationRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background {
                    Circle().fill(color.opacity(0.14))
                }

            Text(text)
                .font(.system(size: OnboardingLayout.CardSecondary.size, weight: .medium))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func run() {
        if reduceMotion {
            phase = 1
            return
        }
        phase = 0
        withAnimation(.easeOut(duration: 0.35).delay(0.55)) {
            phase = 1
        }
    }
}
