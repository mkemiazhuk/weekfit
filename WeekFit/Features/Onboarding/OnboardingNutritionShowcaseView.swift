import SwiftUI

/// Sells WeekFit nutrition with the real meal card: photo in, calories out.
struct OnboardingNutritionShowcaseView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weekFitPalette) private var palette

    @State private var phase = 0

    var body: some View {
        showcaseCard
            .opacity(phase >= 1 ? 1 : 0)
            .scaleEffect(phase >= 1 ? 1 : 0.96)
            .offset(y: phase >= 1 ? 0 : 12)
            .onAppear { run() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityIdentifier("onboarding.nutrition.showcase")
    }

    private var accessibilitySummary: String {
        [
            WeekFitLocalizedString("onboarding.v17.nutrition.meal"),
            WeekFitLocalizedString("onboarding.v17.nutrition.kcal"),
            WeekFitLocalizedString("onboarding.v17.nutrition.protein"),
            WeekFitLocalizedString("onboarding.v17.nutrition.logged")
        ].joined(separator: ". ")
    }

    private var showcaseCard: some View {
        VStack(spacing: 0) {
            photoHero

            VStack(alignment: .leading, spacing: 10) {
                Text(WeekFitLocalizedString("onboarding.v17.nutrition.meal"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .tracking(-0.35)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    metaChip(icon: "fork.knife", text: WeekFitMealSlot.breakfast.title)
                    metaChip(
                        icon: "sparkles",
                        text: WeekFitLocalizedString("today.photoLog.confirm.estimatedNutrition")
                    )
                }

                macros
                    .opacity(phase >= 2 ? 1 : 0)
                    .offset(y: phase >= 2 ? 0 : 6)

                loggedRow
                    .opacity(phase >= 2 ? 1 : 0)

                capabilities
                    .opacity(phase >= 3 ? 1 : 0)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .weekFitPremiumCard(
            accent: WeekFitProgressRingColor.nutrition,
            cornerRadius: 24,
            featured: true
        )
    }

    private var photoHero: some View {
        ZStack(alignment: .topLeading) {
            Image("onboarding-meal-photo")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 208)
                .clipped()
                .accessibilityHidden(true)

            assistantBadge
                .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 208)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(10)
    }

    private var assistantBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
            Text(WeekFitLocalizedString("today.photoLog.aiAssistant.title"))
                .font(.system(size: OnboardingLayout.SmallLabel.size, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(.black.opacity(0.46))
        }
        .accessibilityHidden(true)
    }

    private func metaChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(WeekFitTheme.secondaryText)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(WeekFitTheme.secondaryText.opacity(palette.isLight ? 0.08 : 0.14))
        }
    }

    private var macros: some View {
        HStack(spacing: 0) {
            macroValue(
                WeekFitLocalizedString("onboarding.v17.nutrition.kcal"),
                color: WeekFitProgressRingColor.nutrition
            )
            macroDivider
            macroValue(
                WeekFitLocalizedString("onboarding.v17.nutrition.protein"),
                color: WeekFitTheme.primaryText
            )
        }
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WeekFitProgressRingColor.nutrition.opacity(palette.isLight ? 0.08 : 0.14))
        }
    }

    private func macroValue(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
    }

    private var macroDivider: some View {
        Rectangle()
            .fill(WeekFitTheme.secondaryText.opacity(0.12))
            .frame(width: 1, height: 16)
    }

    private var loggedRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WeekFitTheme.brandGold)
            Text(WeekFitLocalizedString("onboarding.v17.nutrition.logged"))
                .font(.system(size: OnboardingLayout.CardSecondary.size, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WeekFitTheme.brandGold.opacity(palette.isLight ? 0.10 : 0.16))
        }
    }

    private var capabilities: some View {
        HStack(spacing: 8) {
            capabilityChip(
                icon: "camera.fill",
                title: WeekFitLocalizedString("onboarding.v17.nutrition.chip.photo")
            )
            capabilityChip(
                icon: "barcode.viewfinder",
                title: WeekFitLocalizedString("onboarding.v17.nutrition.chip.barcode")
            )
            capabilityChip(
                icon: "fork.knife",
                title: WeekFitLocalizedString("onboarding.v17.nutrition.chip.meals")
            )
        }
    }

    private func capabilityChip(icon: String, title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(WeekFitProgressRingColor.nutrition)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background {
            Capsule(style: .continuous)
                .fill(WeekFitProgressRingColor.nutrition.opacity(palette.isLight ? 0.12 : 0.18))
        }
    }

    private func run() {
        if reduceMotion {
            phase = 3
            return
        }
        phase = 0
        withAnimation(.spring(response: 0.52, dampingFraction: 0.82).delay(0.06)) {
            phase = 1
        }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84).delay(0.38)) {
            phase = 2
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.68)) {
            phase = 3
        }
    }
}
