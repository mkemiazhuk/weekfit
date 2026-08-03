import SwiftUI

struct NutritionDetailsHeader: View {
    let title: String
    let subtitle: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NutritionDetailsDesign.Typography.screenTitle)
                    .foregroundStyle(WeekFitLightTokens.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(NutritionDetailsDesign.Typography.screenSubtitle)
                    .foregroundStyle(WeekFitLightTokens.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            WeekFitCloseButton(size: .large, action: onClose)
        }
        .padding(.horizontal, NutritionDetailsDesign.horizontalPadding)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(NutritionDetailsDesign.canvas.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(NutritionDetailsDesign.divider.opacity(0.75))
                .frame(height: 0.7)
        }
    }
}
