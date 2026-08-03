import SwiftUI

/// Shared Light soft-chrome for Activity / Recovery / Nutrition-style details screens.
/// Dark Appearance must keep legacy premium cards unchanged.
enum HealthDetailsSoftChrome {

    static var canvas: Color { NutritionDetailsDesign.canvas }
    static var cardSurface: Color { NutritionDetailsDesign.cardSurface }
    static var horizontalPadding: CGFloat { NutritionDetailsDesign.horizontalPadding }
    static var sectionSpacing: CGFloat { NutritionDetailsDesign.sectionSpacing }

    static var recoveryTint: Color { WeekFitLightTokens.recoverySoft }
    static var activityTint: Color { WeekFitLightTokens.activitySoft }
    static var nestedTile: Color { WeekFitLightTokens.internalTile }

    static func softCardBackground(
        cornerRadius: CGFloat = NutritionDetailsDesign.largeCorner,
        fill: Color = NutritionDetailsDesign.cardSurface
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.black.opacity(NutritionDetailsDesign.cardBorderOpacity), lineWidth: 0.7)
            }
            .shadow(color: NutritionDetailsDesign.cardShadowAmbient, radius: 12, y: 5)
            .shadow(color: NutritionDetailsDesign.cardShadowContact, radius: 2, y: 1)
    }
}

extension View {
    /// Soft pearl card in Light; falls through to existing premium card styling in Dark.
    @ViewBuilder
    func healthDetailsSoftCard(
        isLight: Bool,
        cornerRadius: CGFloat = NutritionDetailsDesign.largeCorner,
        fill: Color = NutritionDetailsDesign.cardSurface,
        darkGlow: Color = .clear
    ) -> some View {
        if isLight {
            self.background {
                HealthDetailsSoftChrome.softCardBackground(cornerRadius: cornerRadius, fill: fill)
            }
        } else {
            self.weekFitPremiumCard(
                emphasis: darkGlow == .clear ? .standard : .accent,
                accent: darkGlow == .clear ? nil : darkGlow,
                cornerRadius: cornerRadius
            )
        }
    }

    func healthDetailsNestedTile(isLight: Bool, cornerRadius: CGFloat = 15) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    isLight
                        ? HealthDetailsSoftChrome.nestedTile
                        : WeekFitTheme.whiteOpacity(0.026)
                )
        }
    }
}

struct HealthDetailsSectionTitle: View {
    let text: String
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        Text(text)
            .font(
                palette.isLight
                    ? NutritionDetailsDesign.Typography.sectionTitle
                    : .system(size: 11, weight: .bold, design: .rounded)
            )
            .tracking(palette.isLight ? 0 : 1.8)
            .textCase(palette.isLight ? nil : .uppercase)
            .foregroundStyle(
                palette.isLight
                    ? WeekFitLightTokens.textPrimary
                    : WeekFitTheme.whiteOpacity(0.68)
            )
            .accessibilityAddTraits(.isHeader)
    }
}
