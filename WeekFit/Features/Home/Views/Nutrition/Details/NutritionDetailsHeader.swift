import SwiftUI

/// Shared header for the Nutrition, Recovery, and Activity detail sheets.
struct NutritionDetailsHeader: View {
    let title: String
    let subtitle: String
    var background: Color? = nil
    let onClose: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(dateColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            WeekFitCloseButton(size: .large, action: onClose)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 11)
        .background((background ?? palette.appScreenBackground).ignoresSafeArea(edges: .top))
    }

    private var dateColor: Color {
        palette.isLight ? palette.textSecondary : WeekFitTheme.whiteOpacity(0.56)
    }
}
