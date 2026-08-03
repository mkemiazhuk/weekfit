import SwiftUI

struct NutritionMetricCard: View {
    enum Kind {
        case water
        case calories
    }

    let kind: Kind
    let title: String
    let valueText: String
    let percentOfGoal: Int?
    let progress: Double
    let statusText: String?
    let statusColor: Color?

    private var accent: Color {
        switch kind {
        case .water: return NutritionDetailsDesign.waterAccent
        case .calories: return NutritionDetailsDesign.nutritionAccent
        }
    }

    private var fill: Color {
        switch kind {
        case .water: return NutritionDetailsDesign.waterTint
        case .calories: return NutritionDetailsDesign.caloriesTint
        }
    }

    private var iconName: String {
        switch kind {
        case .water: return "drop.fill"
        case .calories: return "flame.fill"
        }
    }

    var body: some View {
        NutritionDetailsCard(
            cornerRadius: NutritionDetailsDesign.metricCorner,
            fill: fill,
            borderOpacity: 0.035,
            padding: NutritionDetailsDesign.metricCardPadding
        ) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    Image(systemName: iconName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)

                    Text(title)
                        .font(NutritionDetailsDesign.Typography.metricLabel)
                        .foregroundStyle(accent)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if let statusText, let statusColor {
                        Text(statusText)
                            .font(NutritionDetailsDesign.Typography.statusPill)
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.12))
                            .clipShape(Capsule())
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(valueText)
                        .font(NutritionDetailsDesign.Typography.metricValue)
                        .foregroundStyle(WeekFitLightTokens.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    if let percentOfGoal {
                        Text(
                            String(
                                format: WeekFitLocalizedString("nutrition.details.metric.percentOfGoal"),
                                percentOfGoal
                            )
                        )
                        .font(NutritionDetailsDesign.Typography.metricSecondary)
                        .foregroundStyle(WeekFitLightTokens.textTertiary)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(accent.opacity(0.14))

                        Capsule()
                            .fill(accent)
                            .frame(width: max(3, geo.size.width * CGFloat(min(max(progress, 0), 1))))
                    }
                }
                .frame(height: 3)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var accessibilityLabelText: String {
        var parts = [title, valueText]
        if let percentOfGoal {
            parts.append(
                String(
                    format: WeekFitLocalizedString("nutrition.details.metric.percentOfGoal"),
                    percentOfGoal
                )
            )
        }
        if let statusText {
            parts.append(statusText)
        }
        return parts.joined(separator: ", ")
    }
}
