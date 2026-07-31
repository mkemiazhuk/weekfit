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
    /// Soft fade-assemble on Meal Details (disabled in lists).
    var animatesAppearance: Bool = false
    /// When false, only ingredients/custom food render (host provides its own dish).
    var showsPlateChrome: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Cached so layout does not recompute every animation frame (main jank source).
    @State private var layoutCache: [PlateLayoutItem] = []
    @State private var layoutSignature = ""
    /// 0 → 1 continuous progress; interpolated via `Animatable` child.
    @State private var assembleProgress: CGFloat = 1
    @State private var didRunAssemble = false

    var body: some View {
        let hasCustomFoodVisual = customFoodImage != nil || customFoodInitial != nil
        let hasFoodItems = items.contains { !$0.id.hasPrefix("drink_") } || hasCustomFoodVisual
        let showPlate = showsPlateChrome && (hasFoodItems || showsEmptyPlate)
        let itemIDs = items.map(\.id).joined(separator: "|")

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

            if !layoutCache.isEmpty {
                PlateAssembleIngredientsLayer(
                    layoutItems: layoutCache,
                    progress: assembleProgress,
                    plateSize: plateSize,
                    shadowOpacity: shadowOpacity,
                    hasFoodItems: hasFoodItems,
                    animatesAppearance: animatesAppearance
                )
            }
        }
        .frame(width: plateSize, height: plateSize)
        .onAppear {
            refreshLayoutIfNeeded(signature: itemIDs)
            startAssembleIfNeeded()
        }
        .onChange(of: itemIDs) { _, newValue in
            refreshLayoutIfNeeded(signature: newValue)
            startAssembleIfNeeded(forceRestart: true)
        }
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

    private func refreshLayoutIfNeeded(signature: String) {
        guard signature != layoutSignature || layoutCache.isEmpty else { return }
        layoutSignature = signature
        layoutCache = PlateLayoutEngine.layout(
            items: items,
            plateSize: plateSize,
            itemScale: itemScale,
            offsetScale: offsetScale,
            mode: layoutMode
        )
    }

    private func startAssembleIfNeeded(forceRestart: Bool = false) {
        guard animatesAppearance, !layoutCache.isEmpty else {
            assembleProgress = 1
            didRunAssemble = true
            return
        }

        if reduceMotion {
            assembleProgress = 1
            didRunAssemble = true
            return
        }

        if didRunAssemble, !forceRestart {
            return
        }

        didRunAssemble = true

        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) {
            assembleProgress = 0
        }

        // Wait for sheet/navigation settle so the curve does not fight the push.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(PlateAssembleMotion.timeline) {
                assembleProgress = 1
            }
        }
    }
}

/// Isolates animated progress so parent layout stays cold during the tween.
private struct PlateAssembleIngredientsLayer: View, Animatable {
    let layoutItems: [PlateLayoutItem]
    var progress: CGFloat
    let plateSize: CGFloat
    let shadowOpacity: CGFloat
    let hasFoodItems: Bool
    let animatesAppearance: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ZStack {
            ForEach(Array(layoutItems.enumerated()), id: \.element.id) { index, layoutItem in
                if !layoutItem.item.imageName.isEmpty,
                   UIImage(named: layoutItem.item.imageName) != nil {
                    ingredientView(layoutItem, index: index)
                }
            }
        }
        // Composite once — avoids per-frame shadow/blend thrash.
        .compositingGroup()
    }

    @ViewBuilder
    private func ingredientView(_ layoutItem: PlateLayoutItem, index: Int) -> some View {
        let t = animatesAppearance
            ? PlateAssembleMotion.itemProgress(
                global: progress,
                item: layoutItem,
                index: index,
                totalCount: layoutItems.count
            )
            : 1
        let eased = PlateAssembleMotion.softOut(t)
        let entrance = PlateAssembleMotion.entrance(for: layoutItem.category, plateSize: plateSize)

        Image(layoutItem.item.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: layoutItem.width)
            .offset(
                x: hasFoodItems
                    ? layoutItem.offset.width + entrance.offset.width * (1 - eased)
                    : 0,
                y: hasFoodItems
                    ? layoutItem.offset.height + entrance.offset.height * (1 - eased)
                    : 0
            )
            .scaleEffect(entrance.scale + (1 - entrance.scale) * eased)
            .opacity(0.40 + 0.60 * eased)
            .shadow(
                color: Color.black.opacity(shadowOpacity * (0.55 + 0.45 * eased)),
                radius: 6,
                y: 3
            )
            .zIndex(layoutItem.zIndex)
    }
}

enum PlateAssembleMotion {
    /// Long, gentle ease — slow start and soft landing, no spring hang.
    static let timeline = Animation.timingCurve(0.40, 0.00, 0.20, 1.00, duration: 1.35)

    struct Entrance {
        let offset: CGSize
        let scale: CGFloat
    }

    static func itemProgress(
        global: CGFloat,
        item: PlateLayoutItem,
        index: Int,
        totalCount: Int
    ) -> CGFloat {
        let start = itemStart(for: item, index: index, totalCount: totalCount)
        let span = itemSpan(totalCount: totalCount)
        return smoothstep((global - start) / span)
    }

    private static func itemStart(
        for item: PlateLayoutItem,
        index: Int,
        totalCount: Int
    ) -> CGFloat {
        let categoryBias: CGFloat
        switch item.category {
        case .base: categoryBias = 0.00
        case .protein: categoryBias = 0.06
        case .vegetables: categoryBias = 0.10
        case .fat, .sauce: categoryBias = 0.14
        case .extras, .garnish: categoryBias = 0.11
        case .other: categoryBias = 0.07
        }

        let indexBias = CGFloat(index) * 0.03
        let maxStart = max(0, 1 - itemSpan(totalCount: totalCount) - 0.02)
        return min(categoryBias + indexBias, maxStart)
    }

    private static func itemSpan(totalCount: Int) -> CGFloat {
        totalCount <= 3 ? 0.78 : 0.70
    }

    static func smoothstep(_ x: CGFloat) -> CGFloat {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    static func softOut(_ t: CGFloat) -> CGFloat {
        let x = min(max(t, 0), 1)
        return 1 - pow(1 - x, 2.2)
    }

    static func entrance(for category: PlateIngredientCategory, plateSize: CGFloat) -> Entrance {
        // Tiny travel — mostly a soft opacity settle to avoid visible jerk.
        let lift = plateSize * 0.022

        switch category {
        case .base:
            return Entrance(offset: CGSize(width: 0, height: -lift * 0.55), scale: 0.97)
        case .protein:
            return Entrance(offset: CGSize(width: plateSize * 0.028, height: -lift * 0.35), scale: 0.96)
        case .vegetables:
            return Entrance(offset: CGSize(width: -plateSize * 0.022, height: -lift * 0.65), scale: 0.96)
        case .sauce, .fat:
            return Entrance(offset: CGSize(width: plateSize * 0.018, height: lift * 0.35), scale: 0.95)
        case .extras, .garnish:
            return Entrance(offset: CGSize(width: 0, height: -lift * 0.85), scale: 0.95)
        case .other:
            return Entrance(offset: CGSize(width: 0, height: -lift * 0.5), scale: 0.97)
        }
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
    var animatesAppearance: Bool = false

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
                layoutMode: layoutMode,
                animatesAppearance: animatesAppearance
            )
        }
    }
}
