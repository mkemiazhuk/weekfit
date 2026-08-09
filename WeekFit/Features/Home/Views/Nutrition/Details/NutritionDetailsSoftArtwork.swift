import SwiftUI

/// Soft decorative artwork for Nutrition Details quality card.
/// Assets use solid soft backgrounds (no cutout alpha) and are circle-clipped in UI.
enum NutritionQualityArtwork {
    static func assetName(for insight: NutritionQualityPresenter.PrimaryInsight) -> String {
        switch insight {
        case .noMealsLogged:
            return "nutrition-art-empty"
        case .proteinWellBelowTarget, .proteinBelowTarget, .sufficientCaloriesLowProtein:
            return "nutrition-art-protein"
        case .greatProteinIntake:
            return "nutrition-art-protein"
        case .fiberLow, .fiberBelowTarget:
            return "nutrition-art-fiber"
        case .carbsLow, .carbsBelowTarget:
            return "nutrition-art-carbs"
        case .fatsLow, .fatsBelowTarget:
            return "nutrition-art-fats"
        case .macrosWellBalanced:
            return "nutrition-art-balanced"
        }
    }
}

struct NutritionDetailsInsightArtwork: View {
    let insight: NutritionQualityPresenter.PrimaryInsight
    var size: CGFloat = 66

    private var assetName: String {
        NutritionQualityArtwork.assetName(for: insight)
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 0.8)
            }
            .saturation(0.92)
            .opacity(0.96)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .animation(.easeInOut(duration: 0.25), value: assetName)
    }
}

/// Soft decorative PNG for the estimate notice only.
struct NutritionDetailsSoftArtwork: View {
    let assetName: String
    var size: CGFloat = 68
    var opacityOverride: Double? = nil
    var saturationOverride: Double? = nil

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .saturation(saturationOverride ?? 0.78)
            .brightness(0.04)
            .opacity(opacityOverride ?? 0.72)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
