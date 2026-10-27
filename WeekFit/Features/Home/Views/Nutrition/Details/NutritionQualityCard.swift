import SwiftUI

struct NutritionQualityCard: View {
    let qualityScore: Int
    let primaryInsightText: String

    @Environment(\.weekFitPalette) private var palette

    private var scoreText: String {
        String(
            format: WeekFitLocalizedString("nutrition.details.quality.scoreFormat"),
            locale: WeekFitCurrentLocale(),
            qualityScore
        )
    }

    var body: some View {
        NutritionDetailsCard(padding: 16) {
            VStack(alignment: .leading, spacing: 7) {
                header
                insightText
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                titleText
                    .fixedSize(horizontal: true, vertical: true)
                Spacer(minLength: 12)
                scoreLabel
                    .fixedSize(horizontal: true, vertical: true)
            }
            VStack(alignment: .leading, spacing: 4) {
                titleText
                scoreLabel
            }
        }
    }

    private var titleText: some View {
        Text(WeekFitLocalizedString("nutrition.details.quality.title"))
            .nutritionReading(14, weight: .medium, relativeTo: .subheadline)
            .foregroundStyle(palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var insightText: some View {
        Text(primaryInsightText)
            .nutritionReading(18, weight: .semibold, relativeTo: .title3)
            .foregroundStyle(palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var scoreLabel: some View {
        Text(scoreText)
            .nutritionReading(15, weight: .semibold, design: .rounded, relativeTo: .body)
            .foregroundStyle(palette.textSecondary)
            .monospacedDigit()
    }
}
