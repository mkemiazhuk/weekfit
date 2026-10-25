import SwiftUI

/// First-run demo: plate photo → ingredients in grams → calories & macros.
struct OnboardingPhotoMealStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            photoCard
                .opacity(phase >= 0 ? 1 : 0)

            if phase >= 1 {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(WeekFitTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .transition(.opacity)

                breakdownCard
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear { run() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        [
            WeekFitLocalizedString("onboarding.v13.photo.demo.meal"),
            WeekFitLocalizedString("onboarding.v13.photo.demo.calories"),
            WeekFitLocalizedString("onboarding.v13.photo.demo.protein"),
            WeekFitLocalizedString("onboarding.v13.photo.demo.ing.chicken"),
            WeekFitLocalizedString("onboarding.v13.photo.demo.ing.rice"),
            WeekFitLocalizedString("onboarding.v13.photo.demo.ing.broccoli")
        ].joined(separator: ". ")
    }

    private var photoCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(WeekFitProgressRingColor.nutrition.opacity(0.14))
                    .frame(width: 64, height: 64)

                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(WeekFitProgressRingColor.nutrition)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(WeekFitLocalizedString("onboarding.v13.photo.demo.capture"))
                    .font(.system(size: OnboardingLayout.Eyebrow.size, weight: .bold, design: .rounded))
                    .tracking(OnboardingLayout.Eyebrow.tracking)
                    .textCase(.uppercase)
                    .foregroundStyle(WeekFitProgressRingColor.nutrition)

                Text(WeekFitLocalizedString("onboarding.v13.photo.demo.meal"))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(OnboardingLayout.cardRowHorizontal)
        .weekFitPremiumCard(
            accent: WeekFitProgressRingColor.nutrition,
            cornerRadius: OnboardingLayout.cardCornerRadius,
            featured: false
        )
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(WeekFitLocalizedString("onboarding.v13.photo.demo.calories"))
                    .font(.system(size: OnboardingLayout.CardTitle.size, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .monospacedDigit()

                Text(WeekFitLocalizedString("onboarding.v13.photo.demo.protein"))
                    .font(.system(size: OnboardingLayout.CardSecondary.size, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 8) {
                ingredientRow(
                    title: WeekFitLocalizedString("onboarding.v13.photo.demo.ing.chicken"),
                    grams: 140
                )
                ingredientRow(
                    title: WeekFitLocalizedString("onboarding.v13.photo.demo.ing.rice"),
                    grams: 180
                )
                ingredientRow(
                    title: WeekFitLocalizedString("onboarding.v13.photo.demo.ing.broccoli"),
                    grams: 90
                )
            }

            Text(WeekFitLocalizedString("onboarding.v13.photo.demo.footnote"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(OnboardingLayout.cardRowHorizontal)
        .weekFitPremiumCard(
            accent: WeekFitTheme.meal,
            cornerRadius: OnboardingLayout.cardCornerRadius,
            featured: true
        )
    }

    private func ingredientRow(title: String, grams: Int) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(WeekFitProgressRingColor.nutrition.opacity(0.18))
                .frame(width: 8, height: 8)

            Text(title)
                .font(.system(size: OnboardingLayout.CardSecondary.size, weight: .medium))
                .foregroundStyle(WeekFitTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(format: WeekFitLocalizedString("common.unit.gramFormat"), grams))
                .font(.system(size: OnboardingLayout.CardSecondary.size, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .monospacedDigit()
        }
    }

    private func run() {
        if reduceMotion {
            phase = 1
            return
        }
        phase = 0
        withAnimation(.easeOut(duration: 0.35).delay(0.45)) {
            phase = 1
        }
    }
}
