import SwiftUI

struct QuickLogMealRow: View {
    let row: QuickMealDisplayRow
    let accentColor: Color
    let selection: QuickLogSelection
    let displayQuantity: Double
    let onPlusTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    @EnvironmentObject private var languageManager: AppLanguageManager

    var body: some View {
        let _ = languageManager.selectedLanguage
        let meal = row.meal

        QuickLogRowView(
            title: meal.isFoodProduct ? meal.title : meal.localizedShortTitle,
            subtitle: quickMealSubtitle(for: meal),
            metaText: quickMealMacroText(for: meal),
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
            PremiumAssetImage(
                imageName: row.meal.imageName,
                style: .quickLogThumbnail,
                accentColor: WeekFitTheme.tertiaryText,
                fallbackSystemName: "fork.knife"
            )
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

    private func quickMealSubtitle(for meal: Meals) -> String {
        if meal.isFoodProduct {
            return meal.servingDescription
        }

        let subtitle = meal.localizedDisplaySubtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return subtitle.isEmpty ? meal.servingDescription : subtitle
    }

    private func quickMealMacroText(for meal: Meals) -> String {
        let macros = QuickLogLocalizedNutrition.macroSummary(
            protein: meal.protein,
            carbs: meal.carbs,
            fats: meal.fats
        )

        if meal.calories > 0 {
            return "\(QuickLogLocalizedNutrition.calories(meal.calories)) • \(macros)"
        }

        return macros
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

    @EnvironmentObject private var languageManager: AppLanguageManager

    var body: some View {
        let _ = languageManager.selectedLanguage
        let item = row.item

        QuickLogRowView(
            title: item.localizedTitle,
            subtitle: item.localizedSubtitle,
            metaText: QuickLogLocalizedNutrition.metaText(for: item),
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
            PremiumAssetImage(
                imageName: row.item.imageName,
                style: .quickLogThumbnail,
                accentColor: accentColor,
                fallbackSystemName: row.item.icon
            )
        } else {
            Image(systemName: row.item.icon)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(accentColor)
                .offset(y: -0.5)
        }
    }
}

struct QuickMealDisplayRow: Identifiable, Equatable {
    let meal: Meals
    let usesAssetImage: Bool
    let sortedBuilderImageItems: [MealBuilderImageItem]
    let localPhotoFilename: String?
    let isFoodProduct: Bool
    let placeholderInitial: String

    var id: String { meal.id }
}

struct QuickItemDisplayRow: Identifiable, Equatable {
    let item: QuickItem
    let usesAssetImage: Bool

    var id: String { item.id }
}

enum QuickLogLocalizedNutrition {
    static func metaText(for item: QuickItem) -> String? {
        let macros = macroSummary(protein: item.protein, carbs: item.carbs, fats: item.fats)
        let hasMacros = item.protein > 0 || item.carbs > 0 || item.fats > 0

        if item.calories > 0, hasMacros {
            return "\(calories(item.calories)) • \(macros)"
        }

        if item.calories > 0 {
            return calories(item.calories)
        }

        return hasMacros ? macros : nil
    }

    static func macroSummary(protein: Int, carbs: Int, fats: Int) -> String {
        [
            "\(WeekFitLocalizedString("meals.library.macroProtein")) \(grams(protein))",
            "\(WeekFitLocalizedString("meals.library.macroCarbs")) \(grams(carbs))",
            "\(WeekFitLocalizedString("meals.library.macroFats")) \(grams(fats))"
        ].joined(separator: " • ")
    }

    static func calories(_ calories: Int) -> String {
        String(format: WeekFitLocalizedString("common.unit.caloriesFormat"), calories)
    }

    private static func grams(_ grams: Int) -> String {
        String(format: WeekFitLocalizedString("common.unit.gramFormat"), grams)
    }
}
