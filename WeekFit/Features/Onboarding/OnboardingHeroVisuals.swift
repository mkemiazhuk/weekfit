import SwiftUI

/// Health trust beat — constellation, not another card stack.
struct OnboardingHealthSignalsStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(WeekFitProgressRingColor.recovery.opacity(0.06))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)

                // Orbit signals
                orbitIcon("figure.run", color: WeekFitProgressRingColor.activity, angle: -50, radius: 78)
                orbitIcon("flame.fill", color: WeekFitProgressRingColor.nutrition, angle: 30, radius: 82)
                orbitIcon("moon.fill", color: WeekFitProgressRingColor.recovery, angle: 140, radius: 74)
                orbitIcon("heart.fill", color: Color(red: 1.0, green: 0.30, blue: 0.40), angle: 220, radius: 70)

                // Center Health mark
                Image(systemName: "heart.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.28, blue: 0.38),
                                        Color(red: 0.88, green: 0.12, blue: 0.42)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.red.opacity(0.35), radius: 16, y: 6)
                    }
                    .scaleEffect(phase > 0.1 ? 1 : 0.86)
                    .opacity(phase > 0.05 ? 1 : 0)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Label {
                    Text(WeekFitLocalizedString("onboarding.v10.health.watchLine"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.68))
                        .multilineTextAlignment(.center)
                } icon: {
                    Image(systemName: "applewatch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.primaryText)
                }
                .labelStyle(.titleAndIcon)
                .opacity(phase > 0.4 ? 1 : 0)

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(WeekFitLocalizedString("onboarding.v10.health.privacy"))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.40))
                .opacity(phase > 0.55 ? 1 : 0)
            }
            .padding(.horizontal, 8)
        }
        .onAppear {
            if reduceMotion {
                phase = 1
            } else {
                withAnimation(.easeOut(duration: 0.85)) {
                    phase = 1
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            WeekFitLocalizedString("onboarding.v10.health.title")
            + ". "
            + WeekFitLocalizedString("onboarding.v10.health.watchLine")
        )
    }

    private func orbitIcon(_ name: String, color: Color, angle: Double, radius: CGFloat) -> some View {
        let rad = angle * .pi / 180
        return Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background {
                Circle()
                    .fill(WeekFitTheme.whiteOpacity(0.06))
                    .overlay { Circle().stroke(color.opacity(0.35), lineWidth: 1) }
            }
            .offset(x: cos(rad) * radius, y: sin(rad) * radius)
            .opacity(phase > 0.2 ? 1 : 0)
            .scaleEffect(phase > 0.2 ? 1 : 0.7)
    }
}

typealias OnboardingWatchToTodayStage = OnboardingHealthSignalsStage
