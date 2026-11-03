import SwiftUI

/// Activity / Nutrition / Recovery ring with a micro-icon and label.
struct OnboardingLabeledRing: View {
    let progress: CGFloat
    let color: Color
    let percentText: String
    let icon: String
    let title: String
    var size: CGFloat = 54
    var strokeWidth: CGFloat = 3.2
    var ink: Color
    var labelInk: Color

    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 9
    @ScaledMetric(relativeTo: .caption2) private var iconSize: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var percentSize: CGFloat = 11

    var body: some View {
        VStack(spacing: 6) {
            WeekFitProgressRing(
                progress: min(max(progress, 0), 1),
                color: color,
                size: size,
                strokeWidth: strokeWidth
            ) {
                Text(percentText)
                    .font(.system(size: percentSize, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }

            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(labelInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
            }
            .frame(maxWidth: size + 18)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(percentText)")
    }
}

enum OnboardingMetricKind: CaseIterable {
    case activity
    case nutrition
    case recovery

    var color: Color {
        switch self {
        case .activity: WeekFitProgressRingColor.activity
        case .nutrition: WeekFitProgressRingColor.nutrition
        case .recovery: WeekFitProgressRingColor.recovery
        }
    }

    var icon: String {
        switch self {
        case .activity: "figure.run"
        case .nutrition: "fork.knife"
        case .recovery: "moon.fill"
        }
    }

    var title: String {
        switch self {
        case .activity: WeekFitLocalizedString("onboarding.metric.activity")
        case .nutrition: WeekFitLocalizedString("onboarding.metric.nutrition")
        case .recovery: WeekFitLocalizedString("onboarding.metric.recovery")
        }
    }
}
