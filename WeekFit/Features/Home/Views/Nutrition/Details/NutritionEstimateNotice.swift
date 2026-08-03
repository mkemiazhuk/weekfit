import SwiftUI

struct NutritionEstimateNotice: View {
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(WeekFitLightTokens.brandGoldDark.opacity(0.80))
                .accessibilityHidden(true)

            Text(message)
                .font(NutritionDetailsDesign.Typography.notice)
                .foregroundStyle(WeekFitLightTokens.textSecondary)
                .lineSpacing(1.5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            NutritionDetailsSoftArtwork(
                assetName: "nutrition-estimate-chart",
                size: 44,
                opacityOverride: 0.48,
                saturationOverride: 0.55
            )
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: NutritionDetailsDesign.noticeCorner, style: .continuous)
                .fill(NutritionDetailsDesign.noticeTint)
                .overlay {
                    RoundedRectangle(cornerRadius: NutritionDetailsDesign.noticeCorner, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.035), lineWidth: 0.7)
                }
        }
        .accessibilityElement(children: .combine)
    }
}
