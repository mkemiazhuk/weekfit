import SwiftUI

struct NutritionQualityCard: View {
    let qualityScore: Int
    let primaryInsightText: String
    let primaryInsight: NutritionQualityPresenter.PrimaryInsight

    private var progress: CGFloat {
        CGFloat(min(max(qualityScore, 0), 100)) / 100.0
    }

    private var artworkName: String {
        NutritionQualityArtwork.assetName(for: primaryInsight)
    }

    var body: some View {
        NutritionDetailsCard(padding: NutritionDetailsDesign.cardPadding) {
            HStack(alignment: .center, spacing: 10) {
                scoreRing
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        Text(
                            String(
                                format: WeekFitLocalizedString("nutrition.details.quality.scoreFormat"),
                                qualityScore
                            )
                        )
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(WeekFitLocalizedString("nutrition.details.quality.title").uppercased())
                        .font(NutritionDetailsDesign.Typography.eyebrow)
                        .tracking(0.6)
                        .foregroundStyle(NutritionDetailsDesign.nutritionAccent)

                    Text(primaryInsightText)
                        .font(NutritionDetailsDesign.Typography.insight)
                        .foregroundStyle(WeekFitLightTokens.textPrimary)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                NutritionDetailsSoftArtwork(assetName: artworkName, size: 66)
                    .animation(.easeInOut(duration: 0.25), value: artworkName)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var scoreRing: some View {
        WeekFitProgressRing(
            progress: progress,
            color: NutritionDetailsDesign.nutritionAccent,
            size: NutritionDetailsDesign.qualityRingSize,
            strokeWidth: NutritionDetailsDesign.qualityRingStroke
        ) {
            VStack(spacing: -1) {
                Text("\(qualityScore)")
                    .font(NutritionDetailsDesign.Typography.score)
                    .foregroundStyle(WeekFitLightTokens.textPrimary)
                    .monospacedDigit()

                Text("/100")
                    .font(NutritionDetailsDesign.Typography.scoreDenom)
                    .foregroundStyle(WeekFitLightTokens.textQuaternary)
            }
        }
    }
}
