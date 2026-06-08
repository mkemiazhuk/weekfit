import SwiftUI
import UIKit

struct BuiltMealPlateView: View {

    let items: [MealBuilderImageItem]
    var plateSize: CGFloat
    var itemScale: CGFloat
    var offsetScale: CGFloat
    var plateOpacity: CGFloat = 0.28
    var shadowOpacity: CGFloat = 0.20
    var customFoodImage: UIImage? = nil
    var customFoodInitial: String? = nil

    var body: some View {
        let sortedItems = items.sorted { $0.zIndex < $1.zIndex }
        let hasCustomFoodVisual = customFoodImage != nil || customFoodInitial != nil
        let hasFoodItems = sortedItems.contains { !$0.id.hasPrefix("drink_") } || hasCustomFoodVisual
        let isStandalone = sortedItems.count == 1

        ZStack {
            if hasFoodItems {
                Ellipse()
                    .fill(Color.black.opacity(0.14))
                    .frame(width: plateSize * 0.98, height: plateSize * 0.21)
                    .blur(radius: 9)
                    .offset(y: plateSize * 0.26)

                Image("plate-dark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: plateSize, height: plateSize)
                    .blendMode(.multiply)
                    .opacity(plateOpacity)
            }

            if hasCustomFoodVisual {
                customFoodPlateVisual
                    .offset(y: -plateSize * 0.03)
                    .shadow(color: Color.black.opacity(shadowOpacity), radius: 6, y: 3)
                    .zIndex(1)
            }

            ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: previewItemWidth(item, isStandalone: isStandalone))
                    .offset(
                        x: hasFoodItems ? previewItemOffsetX(item, index: index, items: sortedItems, isStandalone: isStandalone) : 0,
                        y: hasFoodItems ? previewItemOffsetY(item, index: index, items: sortedItems, isStandalone: isStandalone) : 0
                    )
                    .rotationEffect(.degrees(hasFoodItems ? previewItemRotation(item, isStandalone: isStandalone) : 0))
                    .shadow(color: Color.black.opacity(shadowOpacity), radius: 6, y: 3)
                    .zIndex(Double(item.zIndex))
            }
        }
        .frame(width: plateSize, height: plateSize)
    }

    private var customFoodPlateVisual: some View {
        MealAvatarView(
            image: customFoodImage,
            placeholderInitial: customFoodInitial ?? "F",
            size: plateSize * 0.54,
            imageScale: 0.66,
            fallbackSystemImage: "fork.knife"
        )
    }

    private func previewItemWidth(_ item: MealBuilderImageItem, isStandalone: Bool) -> CGFloat {
        let baseWidth = CGFloat(item.visualSize) * 1.12 * itemScale

        let ratio = CGFloat(item.grams) / 100
        let normalized = log2(max(ratio, 0.45))

        if !isStandalone {
            let gramScale = min(
                max(
                    0.94 + normalized * item.visualDensity * 0.14,
                    0.78
                ),
                1.34
            )

            return baseWidth * gramScale
        }

        guard item.supportsStandalonePresentation else {
            return baseWidth
        }

        let baseScale: CGFloat
        let gramSensitivity: CGFloat
        let maxScale: CGFloat

        if item.id.hasPrefix("base_") {
            baseScale = 0.92
            gramSensitivity = 0.10
            maxScale = 1.08
        } else if item.id.hasPrefix("protein_") {
            baseScale = 1.00
            gramSensitivity = 0.10
            maxScale = 1.14
        } else if item.id.hasPrefix("veg_") {
            baseScale = 1.06
            gramSensitivity = 0.10
            maxScale = 1.20
        } else {
            baseScale = 1.10
            gramSensitivity = 0.10
            maxScale = 1.24
        }

        let scaled = baseScale + normalized * item.visualDensity * gramSensitivity
        return baseWidth * min(max(scaled, 0.78), maxScale)
    }

    private func previewItemOffsetX(
        _ item: MealBuilderImageItem,
        index: Int,
        items: [MealBuilderImageItem],
        isStandalone: Bool
    ) -> CGFloat {
        guard isStandalone, item.supportsStandalonePresentation else {
            let sameCategoryBefore = items.prefix(index).filter {
                itemCategory($0) == itemCategory(item)
            }.count

            var x = CGFloat(item.offsetX) * offsetScale

            if item.offsetY < -20 {
                x *= 0.72
            }

            if itemCategory(item) == "veg" && sameCategoryBefore >= 1 {
                x -= 6
            }

            if sameCategoryBefore >= 3 {
                x -= 14
            }

            return x
        }

        return 0
    }

    private func previewItemOffsetY(
        _ item: MealBuilderImageItem,
        index: Int,
        items: [MealBuilderImageItem],
        isStandalone: Bool
    ) -> CGFloat {
        guard isStandalone, item.supportsStandalonePresentation else {
            let sameCategoryBefore = items.prefix(index).filter {
                itemCategory($0) == itemCategory(item)
            }.count

            var y = CGFloat(item.offsetY) * offsetScale - 2

            if item.offsetY < -20 {
                y += 10
            }

            if itemCategory(item) == "veg" && sameCategoryBefore >= 1 {
                y += 6
            }

            if sameCategoryBefore >= 3 {
                y += 4
            }

            return y
        }

        return -4
    }

    private func previewItemRotation(_ item: MealBuilderImageItem, isStandalone: Bool) -> Double {
        guard isStandalone, item.supportsStandalonePresentation else {
            return Double(item.rotation)
        }
        return 0
    }

    private func itemCategory(_ item: MealBuilderImageItem) -> String {
        if item.id.hasPrefix("base_") { return "base" }
        if item.id.hasPrefix("protein_") { return "protein" }
        if item.id.hasPrefix("veg_") { return "veg" }
        if item.id.hasPrefix("fat_") { return "fat" }
        if item.id.hasPrefix("sauce_") { return "sauce" }
        return "other"
    }
}

struct AsyncCustomFoodPlateView: View {
    let filename: String?
    let initial: String
    var plateSize: CGFloat
    var itemScale: CGFloat
    var offsetScale: CGFloat
    var plateOpacity: CGFloat = 0.28
    var shadowOpacity: CGFloat = 0.20

    var body: some View {
        AsyncMealPhotoView(filename: filename) { image in
            BuiltMealPlateView(
                items: [],
                plateSize: plateSize,
                itemScale: itemScale,
                offsetScale: offsetScale,
                plateOpacity: plateOpacity,
                shadowOpacity: shadowOpacity,
                customFoodImage: image,
                customFoodInitial: initial
            )
        }
    }
}
