import SwiftUI

/// Compact single-row nutrition summary for meal builder and meal details.
struct MealNutritionSummaryStrip: View {

    enum Style {
        case embedded
        case standalone
    }

    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let fiber: Int
    var accent: Color = WeekFitTheme.meal
    var style: Style = .standalone

    @EnvironmentObject private var languageManager: AppLanguageManager

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText

    var body: some View {
        let _ = languageManager.selectedLanguage

        VStack(spacing: 0) {
            if style == .embedded {
                Rectangle()
                    .fill(WeekFitTheme.whiteOpacity(0.045))
                    .frame(height: 1)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 0) {
                calorieSegment
                    .frame(maxWidth: .infinity)

                columnDivider

                macroSegment(labelKey: "meals.nutrition.label.proteinShort", value: protein)
                    .frame(maxWidth: .infinity)

                columnDivider

                macroSegment(labelKey: "meals.nutrition.label.carbsShort", value: carbs)
                    .frame(maxWidth: .infinity)

                columnDivider

                macroSegment(labelKey: "meals.nutrition.label.fatsShort", value: fats)
                    .frame(maxWidth: .infinity)

                columnDivider

                macroSegment(labelKey: "meals.nutrition.label.fiberShort", value: fiber)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 28)
        }
        .padding(.horizontal, style == .embedded ? 0 : 8)
        .padding(.vertical, style == .embedded ? 0 : 0)
        .background {
            if style == .standalone {
                stripBackground
            }
        }
    }

    private var calorieSegment: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("\(calories)")
                .font(.system(size: 13.0, weight: .bold, design: .rounded))
                .foregroundStyle(accent.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(WeekFitLocalizedString("common.unit.kcal"))
                .font(.system(size: 8.8, weight: .semibold, design: .rounded))
                .foregroundStyle(accent.opacity(0.70))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }

    private func macroSegment(labelKey: String, value: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(WeekFitLocalizedString(labelKey))
                .font(.system(size: 9.6, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.48))
                .lineLimit(1)

            Text("\(value)")
                .font(.system(size: 12.4, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.90))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(WeekFitLocalizedString("common.unit.gramShort"))
                .font(.system(size: 8.8, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(WeekFitTheme.whiteOpacity(0.045))
            .frame(width: 1, height: 12)
    }

    private var stripBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        WeekFitTheme.whiteOpacity(0.040),
                        WeekFitTheme.whiteOpacity(0.020)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                WeekFitTheme.whiteOpacity(0.060),
                                WeekFitTheme.whiteOpacity(0.028)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
    }
}
