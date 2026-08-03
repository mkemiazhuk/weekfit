import SwiftUI

/// Soft decorative artwork for Nutrition Details — never louder than copy.
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

    static func softOpacity(for assetName: String) -> Double {
        0.72
    }

    static func softSaturation(for assetName: String) -> Double {
        0.78
    }
}

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
            .saturation(saturationOverride ?? NutritionQualityArtwork.softSaturation(for: assetName))
            .brightness(0.04)
            .opacity(opacityOverride ?? NutritionQualityArtwork.softOpacity(for: assetName))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
