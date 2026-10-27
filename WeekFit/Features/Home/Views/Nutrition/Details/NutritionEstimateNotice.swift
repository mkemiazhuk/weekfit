import SwiftUI

struct NutritionEstimateNotice: View {
    let message: String

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle")
                .nutritionReading(14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
                .padding(.top, 1)

            Text(message)
                .nutritionReading(14, weight: .regular, relativeTo: .subheadline)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
