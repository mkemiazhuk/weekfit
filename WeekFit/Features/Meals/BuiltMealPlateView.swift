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
    var layoutMode: PlateLayoutMode = .detail
    /// Keep the plate visible with zero items so builder drop geometry stays stable.
    var showsEmptyPlate: Bool = false

    var body: some View {
        let layoutItems = PlateLayoutEngine.layout(
            items: items,
            plateSize: plateSize,
            itemScale: itemScale,
            offsetScale: offsetScale,
            mode: layoutMode
        )
        let hasCustomFoodVisual = customFoodImage != nil || customFoodInitial != nil
        let hasFoodItems = items.contains { !$0.id.hasPrefix("drink_") } || hasCustomFoodVisual
        let showPlate = hasFoodItems || showsEmptyPlate

        ZStack {
            if showPlate {
                Ellipse()
                    .fill(Color.black.opacity(hasFoodItems ? 0.14 : 0.10))
                    .frame(width: plateSize * 0.98, height: plateSize * 0.21)
                    .blur(radius: 9)
                    .offset(y: plateSize * 0.26)

                Image("plate-dark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: plateSize, height: plateSize)
                    .blendMode(.multiply)
                    .opacity(hasFoodItems ? plateOpacity : min(plateOpacity, 0.72))
            }

            if hasCustomFoodVisual {
                customFoodPlateVisual
                    .offset(y: -plateSize * 0.03)
                    .shadow(color: Color.black.opacity(shadowOpacity), radius: 6, y: 3)
                    .zIndex(1)
            }

            ForEach(layoutItems) { layoutItem in
                if !layoutItem.item.imageName.isEmpty,
                   UIImage(named: layoutItem.item.imageName) != nil {
                    Image(layoutItem.item.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: layoutItem.width)
                        .offset(
                            x: hasFoodItems ? layoutItem.offset.width : 0,
                            y: hasFoodItems ? layoutItem.offset.height : 0
                        )
                        .rotationEffect(.degrees(hasFoodItems ? layoutItem.rotation : 0))
                        .shadow(color: Color.black.opacity(shadowOpacity), radius: 6, y: 3)
                        .zIndex(layoutItem.zIndex)
                }
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
}

struct AsyncCustomFoodPlateView: View {
    let filename: String?
    let initial: String
    var plateSize: CGFloat
    var itemScale: CGFloat
    var offsetScale: CGFloat
    var plateOpacity: CGFloat = 0.28
    var shadowOpacity: CGFloat = 0.20
    var layoutMode: PlateLayoutMode = .detail
    var photoTargetPixelSize: CGFloat = MealPhotoStore.thumbnailPixelSize

    var body: some View {
        AsyncMealPhotoView(filename: filename, targetPixelSize: photoTargetPixelSize) { image in
            BuiltMealPlateView(
                items: [],
                plateSize: plateSize,
                itemScale: itemScale,
                offsetScale: offsetScale,
                plateOpacity: plateOpacity,
                shadowOpacity: shadowOpacity,
                customFoodImage: image,
                customFoodInitial: initial,
                layoutMode: layoutMode
            )
        }
    }
}
