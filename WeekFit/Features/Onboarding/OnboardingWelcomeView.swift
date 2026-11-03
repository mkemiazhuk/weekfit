import SwiftUI

/// First-run killer page: one place for activity, food, and recovery — and what to do next.
struct OnboardingWelcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weekFitPalette) private var palette
    @ScaledMetric(relativeTo: .title) private var headlineSize: CGFloat = 32
    @ScaledMetric(relativeTo: .subheadline) private var subheadSize: CGFloat = 15

    @State private var logoVisible = false
    @State private var copyVisible = false
    @State private var cardVisible = false
    @State private var ringProgress: CGFloat = 0

    private let brandGreen = Color(red: 0.33, green: 0.58, blue: 0.43)

    var body: some View {
        VStack(spacing: 0) {
            brandMark
                .opacity(logoVisible ? 1 : 0)
                .padding(.bottom, 16)

            copyBlock
                .opacity(copyVisible ? 1 : 0)
                .offset(y: copyVisible ? 0 : 8)

            showcaseCard
                .padding(.top, 22)
                .opacity(cardVisible ? 1 : 0)
                .scaleEffect(cardVisible ? 1 : 0.96, anchor: .center)
                .offset(y: cardVisible ? 0 : 18)
        }
        .frame(maxWidth: .infinity)
        .onAppear { runEntrance() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("onboarding.welcome")
    }

    private var accessibilitySummary: String {
        [
            WeekFitLocalizedString("onboarding.v18.welcome.title"),
            WeekFitLocalizedString("onboarding.v18.welcome.body"),
            WeekFitLocalizedString("onboarding.v18.welcome.source"),
            WeekFitLocalizedString("onboarding.v18.welcome.bridge"),
            WeekFitLocalizedString("onboarding.v18.welcome.focus")
        ].joined(separator: ". ")
    }

    private var brandMark: some View {
        Text("Week\(Text("Fit").foregroundStyle(brandGreen))")
            .foregroundStyle(WeekFitTheme.primaryText)
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .tracking(-0.3)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var copyBlock: some View {
        VStack(spacing: 10) {
            Text(WeekFitLocalizedString("onboarding.v18.welcome.title"))
                .font(.system(size: headlineSize, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .tracking(-0.6)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(WeekFitLocalizedString("onboarding.v18.welcome.body"))
                .font(.system(size: subheadSize, weight: .medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var showcaseCard: some View {
        VStack(spacing: 14) {
            sourceRow
            bridgeRow
            pillarRow
            focusBadge
            insightLine
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 16)
        .background { cardChrome }
    }

    private var sourceRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.primaryText)
                Text(WeekFitLocalizedString("onboarding.v18.welcome.source"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 8) {
                sourceChip("moon.zzz.fill", WeekFitProgressRingColor.recovery)
                sourceChip("heart.fill", Color(red: 0.86, green: 0.42, blue: 0.48))
                sourceChip("figure.walk", WeekFitProgressRingColor.activity)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WeekFitLocalizedString("onboarding.v18.welcome.source"))
    }

    private func sourceChip(_ icon: String, _ color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)
            .background {
                Circle()
                    .fill(color.opacity(palette.isLight ? 0.14 : 0.22))
            }
            .accessibilityHidden(true)
    }

    private var bridgeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background {
                    Circle().fill(WeekFitProgressRingColor.nutrition)
                }
            Text(WeekFitLocalizedString("onboarding.v18.welcome.bridge"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WeekFitProgressRingColor.nutrition.opacity(palette.isLight ? 0.10 : 0.16))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WeekFitLocalizedString("onboarding.v18.welcome.bridge"))
    }

    private var pillarRow: some View {
        HStack(spacing: 8) {
            metricRing(
                progress: OnboardingSampleData.activityProgress,
                color: WeekFitProgressRingColor.activity,
                title: OnboardingMetricKind.activity.title,
                center: .iconAndPercent("figure.run", OnboardingSampleData.activityPercent)
            )
            metricRing(
                progress: 0.86,
                color: WeekFitProgressRingColor.nutrition,
                title: WeekFitLocalizedString("onboarding.v18.welcome.metric.nutrition"),
                center: .nutritionPhoto
            )
            metricRing(
                progress: OnboardingSampleData.morningRecoveryProgress,
                color: WeekFitProgressRingColor.recovery,
                title: OnboardingMetricKind.recovery.title,
                center: .iconAndPercent("moon.fill", OnboardingSampleData.morningRecoveryPercent)
            )
        }
    }

    private var focusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(WeekFitProgressRingColor.activity)
                .frame(width: 7, height: 7)
            Text(WeekFitLocalizedString("onboarding.v18.welcome.focus"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(brandGreen)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(WeekFitProgressRingColor.activity.opacity(palette.isLight ? 0.14 : 0.20))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WeekFitLocalizedString("onboarding.v18.welcome.focus"))
    }

    private var insightLine: some View {
        Text(WeekFitLocalizedString("onboarding.v18.welcome.insight"))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(WeekFitTheme.secondaryText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private enum RingCenter {
        case iconAndPercent(String, Int)
        case nutritionPhoto
    }

    private func metricRing(
        progress: CGFloat,
        color: Color,
        title: String,
        center: RingCenter
    ) -> some View {
        let size: CGFloat = 74
        let stroke: CGFloat = 5.5

        return VStack(spacing: 8) {
            WeekFitProgressRing(
                progress: ringProgress * progress,
                color: color,
                size: size,
                strokeWidth: stroke
            ) {
                switch center {
                case .iconAndPercent(let icon, let value):
                    VStack(spacing: 1) {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color)
                        Text("\(value)%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(WeekFitTheme.primaryText)
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                case .nutritionPhoto:
                    ZStack(alignment: .bottomTrailing) {
                        Image("onboarding-meal-photo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: size - stroke * 2 - 8, height: size - stroke * 2 - 8)
                            .clipShape(Circle())
                        Image(systemName: "camera.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(color))
                            .offset(x: 2, y: 2)
                    }
                }
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    private var cardChrome: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WeekFitProgressRingColor.activity.opacity(palette.isLight ? 0.14 : 0.18),
                                Color.white.opacity(palette.isLight ? 0.38 : 0.04),
                                WeekFitProgressRingColor.nutrition.opacity(palette.isLight ? 0.10 : 0.12),
                                WeekFitProgressRingColor.recovery.opacity(palette.isLight ? 0.16 : 0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(palette.isLight ? 0.72 : 0.18), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(palette.isLight ? 0.07 : 0.28), radius: 20, y: 10)
    }

    private func runEntrance() {
        if reduceMotion {
            logoVisible = true
            copyVisible = true
            cardVisible = true
            ringProgress = 1
            return
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
            logoVisible = true
        }
        withAnimation(.spring(response: 0.58, dampingFraction: 0.86).delay(0.12)) {
            copyVisible = true
        }
        withAnimation(.spring(response: 0.68, dampingFraction: 0.80).delay(0.26)) {
            cardVisible = true
        }
        withAnimation(.easeOut(duration: 1.05).delay(0.42)) {
            ringProgress = 1
        }
    }
}

typealias OnboardingPromiseMark = OnboardingWelcomeView
