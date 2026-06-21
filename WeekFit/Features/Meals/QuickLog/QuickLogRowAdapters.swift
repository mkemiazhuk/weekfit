import SwiftUI

struct QuickLogMealRow: View {
    let row: QuickMealDisplayRow
    let accentColor: Color
    let selection: QuickLogSelection
    let displayQuantity: Double
    let onPlusTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        QuickLogRowView(
            title: row.title,
            subtitle: row.subtitle,
            metaText: row.macroText,
            accentColor: accentColor,
            selection: selection,
            displayQuantity: displayQuantity,
            imageContent: { mealImageContent },
            onPlusTap: onPlusTap,
            onIncrement: onIncrement,
            onDecrement: onDecrement
        )
    }

    @ViewBuilder
    private var mealImageContent: some View {
        if row.isFoodProduct {
            AsyncMealPhotoView(filename: row.localPhotoFilename) { image in
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageContentSize, height: imageContentSize)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: imageContentCornerRadius,
                                style: .continuous
                            )
                        )
                        .saturation(0.88)
                        .contrast(0.92)
                        .brightness(-0.035)
                } else {
                    CustomFoodVisualView(
                        image: nil,
                        placeholderInitial: row.placeholderInitial,
                        size: imageContentSize,
                        imageScale: 0.62
                    )
                }
            }
        } else if !row.sortedBuilderImageItems.isEmpty {
            ZStack {
                Color.black.opacity(0.10)
                BuiltMealPlateView(
                    items: row.sortedBuilderImageItems,
                    plateSize: imageContentSize,
                    itemScale: 0.33,
                    offsetScale: 0.30,
                    plateOpacity: 0.42,
                    shadowOpacity: 0.12,
                    layoutMode: .compactPreview
                )
            }
            .frame(width: imageContentSize, height: imageContentSize)
        } else if row.usesAssetImage {
            Image(row.meal.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: imageContentSize, height: imageContentSize)
                .saturation(0.94)
                .contrast(0.96)
        } else {
            Image(systemName: "fork.knife")
                .font(.system(size: 20))
                .foregroundColor(WeekFitTheme.tertiaryText)
        }
    }

    private var imageContentSize: CGFloat {
        row.isFoodProduct
            ? QuickLogRowMetrics.imageSize * 0.68
            : QuickLogRowMetrics.imageSize * 0.92
    }

    private var imageContentCornerRadius: CGFloat {
        QuickLogRowMetrics.imageCornerRadius * 0.70
    }
}

struct QuickLogItemRow: View {
    let row: QuickItemDisplayRow
    let accentColor: Color
    let selection: QuickLogSelection
    let displayQuantity: Double
    let onPlusTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        QuickLogRowView(
            title: row.item.title,
            subtitle: row.subtitleText,
            metaText: row.metaText,
            accentColor: accentColor,
            selection: selection,
            displayQuantity: displayQuantity,
            imageContent: { itemImageContent },
            onPlusTap: onPlusTap,
            onIncrement: onIncrement,
            onDecrement: onDecrement
        )
    }

    @ViewBuilder
    private var itemImageContent: some View {
        if row.usesAssetImage {
            Image(row.item.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
        } else {
            Image(systemName: row.item.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accentColor)
        }
    }
}

struct QuickMealDisplayRow: Identifiable, Equatable {
    let meal: Meals
    let title: String
    let subtitle: String
    let macroText: String
    let usesAssetImage: Bool
    let sortedBuilderImageItems: [MealBuilderImageItem]
    let localPhotoFilename: String?
    let isFoodProduct: Bool
    let placeholderInitial: String

    var id: String { meal.id }
}

struct QuickItemDisplayRow: Identifiable, Equatable {
    let item: QuickItem
    let subtitleText: String
    let metaText: String?
    let usesAssetImage: Bool

    var id: String { item.id }
}
