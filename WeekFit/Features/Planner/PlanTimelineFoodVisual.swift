import SwiftUI
import UIKit
import WeekFitPlanner

enum PlanTimelineNutritionKind: Equatable {
    case product
    case meal
    case drink
    case water
}

enum PlanTimelineNutritionVisual {
    case assetImage(name: String, kind: PlanTimelineNutritionKind)
    case localPhoto(UIImage, kind: PlanTimelineNutritionKind)
    case builderPlate([MealBuilderImageItem], kind: PlanTimelineNutritionKind)
    case fallbackIcon(systemName: String, kind: PlanTimelineNutritionKind)

    var kind: PlanTimelineNutritionKind {
        switch self {
        case .assetImage(_, let kind),
             .localPhoto(_, let kind),
             .builderPlate(_, let kind),
             .fallbackIcon(_, let kind):
            return kind
        }
    }
}

typealias PlanTimelineFoodVisual = PlanTimelineNutritionVisual
typealias PlanTimelineFoodKind = PlanTimelineNutritionKind

enum PlanTimelineNutritionVisualResolver {

    static func resolve(
        for activity: PlannedActivity,
        customMeals: [Meals]
    ) -> PlanTimelineNutritionVisual? {
        if isDrinkActivity(activity) || activity.timelineEventKind == .drink {
            return resolveDrink(for: activity)
        }

        guard isFoodActivity(activity) else { return nil }

        let matchedMeal = matchingCustomMeal(for: activity, in: customMeals)
        let kind = foodKind(for: activity, meal: matchedMeal)

        if let meal = matchedMeal {
            if let photo = displayableLocalPhoto(for: meal) {
                return .localPhoto(photo, kind: kind)
            }

            if FoodImageQualityValidator.isDisplayableAsset(named: meal.imageName) {
                return .assetImage(name: meal.imageName, kind: kind)
            }

            if let items = displayableBuilderItems(for: meal), !items.isEmpty {
                // Multi-ingredient recipes keep the plate so both foods stay visible;
                // single-ingredient rows use a clean cutout avatar.
                if items.count >= 2 {
                    return .builderPlate(items, kind: kind)
                }
                if let primary = items.first {
                    return .assetImage(name: primary.imageName, kind: kind)
                }
            }

            if let primary = meal.primaryBuilderIngredientImageName,
               FoodImageQualityValidator.isDisplayableAsset(named: primary)
                || primary.lowercased().hasPrefix("ingredient-") {
                return .assetImage(name: primary, kind: kind)
            }
        }

        let activityImageName = activity.imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !FoodImageQualityValidator.isPlaceholderAssetName(activityImageName) {
            // Logged builder meals often persist only the primary ingredient asset.
            // Prefer a reconstructed plate whenever the title encodes multiple foods.
            if activityImageName.lowercased().hasPrefix("ingredient-"),
               let multiIngredientPlate = multiIngredientPlateVisual(forTitle: activity.title) {
                return multiIngredientPlate
            }

            if FoodImageQualityValidator.isDisplayableAsset(named: activityImageName)
                || activityImageName.lowercased().hasPrefix("ingredient-") {
                return .assetImage(name: activityImageName, kind: kind)
            }

            // Planner/quick-log may store MealPhotoStore filenames on the activity itself
            // (especially for newly created custom foods).
            if let photo = displayableLocalPhoto(filename: activityImageName) {
                return .localPhoto(photo, kind: kind)
            }
        }

        // Last resort for already-logged localized builder titles without catalog hit:
        // rebuild visuals from ingredient labels found in the activity title.
        if let inferred = inferredBuilderItems(fromTitle: activity.title), !inferred.isEmpty {
            return inferredNutritionVisual(items: inferred, kind: .meal)
        }

        // Also try remapping RU↔EN before giving up (covers mixed-language titles).
        let remappedEnglish = MealBuilderTitleComposer.remapStoredTitle(activity.title, toRussian: false)
        if remappedEnglish != activity.title,
           let inferred = inferredBuilderItems(fromTitle: remappedEnglish),
           !inferred.isEmpty {
            return inferredNutritionVisual(items: inferred, kind: .meal)
        }

        return .fallbackIcon(systemName: fallbackIcon(for: kind), kind: kind)
    }

    static func isFoodActivity(_ activity: PlannedActivity) -> Bool {
        if isDrinkActivity(activity) || activity.timelineEventKind == .drink {
            return false
        }

        let type = activity.type.lowercased()
        if type == "meal" || type == "food" || type == "nutrition" {
            return true
        }

        return activity.timelineEventKind == .food
    }

    static func isCustomFoodSource(
        _ activity: PlannedActivity,
        customMeals: [Meals]
    ) -> Bool {
        if let meal = matchingCustomMeal(for: activity, in: customMeals) {
            return meal.isFoodProduct || meal.creationMode == .manual
        }

        let source = activity.source.lowercased()
        return source == "today"
            || source == "nutritionlog"
            || source == "foodlog"
    }

    private static func resolveDrink(for activity: PlannedActivity) -> PlanTimelineNutritionVisual {
        let kind: PlanTimelineNutritionKind = isWaterActivity(activity) ? .water : .drink
        let imageName = activity.imageName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Same contract as food avatars: trust bundled `ingredient-*` keys even when
        // UIImage(named:) is unavailable in unit tests / before asset warm-up.
        if imageName.lowercased() != "hydration",
           isTrustedNutritionAssetName(imageName) {
            return .assetImage(name: imageName, kind: kind)
        }

        if kind == .water, isTrustedNutritionAssetName("ingredient-water") {
            return .assetImage(name: "ingredient-water", kind: kind)
        }

        return .fallbackIcon(systemName: fallbackIcon(for: kind), kind: kind)
    }

    private static func isTrustedNutritionAssetName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !FoodImageQualityValidator.isPlaceholderAssetName(trimmed) else {
            return false
        }
        if trimmed.lowercased().hasPrefix("ingredient-") {
            return true
        }
        return FoodImageQualityValidator.isDisplayableAsset(named: trimmed)
    }

    private static func foodKind(
        for activity: PlannedActivity,
        meal: Meals?
    ) -> PlanTimelineNutritionKind {
        if let meal {
            return meal.isFoodProduct ? .product : .meal
        }

        let imageName = activity.imageName.lowercased()
        if imageName.hasPrefix("ingredient-") {
            return .meal
        }

        // Quick Log recipes without a catalog hit are still meals — reserve the
        // takeout-bag glyph for real food products / barcode items.
        let source = activity.source.lowercased()
        if source == "today" || source == "nutritionlog" || source == "foodlog" {
            if inferredBuilderItems(fromTitle: activity.title) != nil {
                return .meal
            }
            // Heuristic: multi-token builder-style titles → meal; single product names → product.
            if CustomMealStore.titleTokens(activity.title).count >= 2 {
                return .meal
            }
            return .product
        }

        return .meal
    }

    private static func fallbackIcon(for kind: PlanTimelineNutritionKind) -> String {
        switch kind {
        case .product:
            return "takeoutbag.and.cup.and.straw.fill"
        case .meal:
            return "fork.knife"
        case .drink:
            return "cup.and.saucer.fill"
        case .water:
            return "drop.fill"
        }
    }

    private static func displayableLocalPhoto(for meal: Meals) -> UIImage? {
        guard meal.hasCustomPhoto else { return nil }

        let candidates = [
            meal.localPhotoThumbnailFilename,
            meal.localPhotoFilename,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        for filename in candidates {
            if let image = displayableLocalPhoto(filename: filename) {
                return image
            }
        }

        return nil
    }

    private static func displayableLocalPhoto(filename: String) -> UIImage? {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let image = MealPhotoStore.timelineImage(for: trimmed)
            ?? MealPhotoStore.image(for: trimmed),
              FoodImageQualityValidator.isDisplayable(image) else {
            return nil
        }

        return image
    }

    private static func displayableBuilderItems(for meal: Meals) -> [MealBuilderImageItem]? {
        guard let items = meal.builderImageItems, !items.isEmpty else { return nil }

        let validItems = items.filter { item in
            let name = item.imageName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return false }
            if name.lowercased().hasPrefix("ingredient-") { return true }
            return FoodImageQualityValidator.isDisplayableAsset(named: name)
        }

        return validItems.isEmpty ? nil : validItems
    }

    private static func inferredNutritionVisual(
        items: [MealBuilderImageItem],
        kind: PlanTimelineNutritionKind
    ) -> PlanTimelineNutritionVisual {
        if items.count >= 2 {
            return .builderPlate(items, kind: kind)
        }
        if let primary = items.max(by: { $0.zIndex < $1.zIndex }) ?? items.first {
            return .assetImage(name: primary.imageName, kind: kind)
        }
        return .builderPlate(items, kind: kind)
    }

    private static func multiIngredientPlateVisual(
        forTitle title: String
    ) -> PlanTimelineNutritionVisual? {
        let candidates = [
            title,
            MealBuilderTitleComposer.remapStoredTitle(title, toRussian: false),
            MealBuilderTitleComposer.remapStoredTitle(title, toRussian: true),
        ]

        for candidate in candidates {
            if let inferred = inferredBuilderItems(fromTitle: candidate), inferred.count >= 2 {
                return .builderPlate(inferred, kind: .meal)
            }
        }
        return nil
    }

    /// Reconstruct builder visuals from a localized/English activity title when the
    /// catalog row is missing or title matching failed (common for Quick Log).
    private static func inferredBuilderItems(fromTitle title: String) -> [MealBuilderImageItem]? {
        let tokens = Set(CustomMealStore.titleTokens(title))
        let normalizedFull = CustomMealStore.normalizedTitle(title)
        guard !tokens.isEmpty || !normalizedFull.isEmpty else { return nil }

        let matched = MealBuilderDemoData.ingredients.compactMap { ingredient -> MealBuilderImageItem? in
            let labels = [
                CustomMealStore.normalizedTitle(ingredient.title),
                CustomMealStore.normalizedTitle(ingredient.russianTitle)
            ]
            .filter { !$0.isEmpty }

            let hits = labels.contains { label in
                if tokens.contains(label) { return true }
                // Multi-word labels ("sweet potato" / "батат") and titles with
                // amounts ("Индейка (150 г)") — substring match on normalized text.
                if normalizedFull == label { return true }
                if normalizedFull.contains(label), label.count >= 3 {
                    return true
                }
                let labelTokens = CustomMealStore.titleTokens(label)
                return !labelTokens.isEmpty && labelTokens.allSatisfy(tokens.contains)
            }
            guard hits else { return nil }

            return MealBuilderImageItem(
                id: ingredient.id,
                imageName: ingredient.imageName,
                visualSize: ingredient.visualSize,
                visualDensity: ingredient.visualDensity,
                supportsStandalonePresentation: ingredient.supportsStandalonePresentation,
                offsetX: ingredient.offsetX,
                offsetY: ingredient.offsetY,
                rotation: ingredient.rotation,
                zIndex: ingredient.zIndex,
                grams: ingredient.defaultGrams
            )
        }

        guard matched.count >= 1 else { return nil }
        return matched
    }

    private static func matchingCustomMeal(
        for activity: PlannedActivity,
        in customMeals: [Meals]
    ) -> Meals? {
        let normalizedType = activity.type
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        // Logged foods use PlannerType.meal.title ("Meal"); also accept food/nutrition aliases.
        guard normalizedType == "meal"
            || normalizedType == "food"
            || normalizedType == "nutrition" else {
            return nil
        }

        let titleCandidates = [
            activity.title,
            MealBuilderTitleComposer.remapStoredTitle(activity.title, toRussian: false),
            MealBuilderTitleComposer.remapStoredTitle(activity.title, toRussian: true),
        ]

        for candidate in titleCandidates {
            if let matched = CustomMealStore.meal(
                matchingActivityTitle: candidate,
                in: customMeals
            ) {
                return matched
            }
        }

        // Ingredient-token overlap against every catalog builder meal (covers
        // localized titles that don't exact-match composed EN/RU candidates).
        let activityTokens = Set(CustomMealStore.titleTokens(activity.title))
        if activityTokens.count >= 2 {
            if let overlapMatch = customMeals.first(where: { meal in
                CustomMealStore.activityTitleMatchesBuilderIngredients(activity.title, meal: meal)
            }) {
                return overlapMatch
            }
        }

        // Fall back to catalog matcher title/image rules without its nutritionLog skip —
        // photos still need the catalog row even when macros are already on the activity.
        return MealCatalogMatcher.match(
            title: activity.title,
            imageName: activity.imageName,
            in: customMeals
        )
    }

    static func isDrinkActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()

        return type.contains("water")
            || type.contains("drink")
            || title.contains("water")
            || title.contains("hydration")
            || title.contains("drink")
            || activity.imageName.lowercased() == "hydration"
    }

    static func isWaterActivity(_ activity: PlannedActivity) -> Bool {
        let type = activity.type.lowercased()
        let title = activity.title.lowercased()
        let imageName = activity.imageName.lowercased()

        if imageName == "hydration" || imageName == "ingredient-water" || imageName == "habit-water" {
            return true
        }

        return type.contains("water")
            || title.contains("water")
            || title.contains("hydration")
    }
}

typealias PlanTimelineFoodVisualResolver = PlanTimelineNutritionVisualResolver

struct PlanTimelineNutritionAvatar: View {

    let visual: PlanTimelineNutritionVisual
    let accent: Color
    var backgroundOpacity: Double = 0.11
    var foregroundOpacity: Double = 0.84
    var size: CGFloat = 26
    var contentSize: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(backgroundOpacity))
                .frame(width: size, height: size)

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch visual {
        case .assetImage(let name, _):
            // Ingredient cutouts need fill+clip at timeline size — scaledToFit
            // leaves a tiny floating glyph that reads as "no image".
            Image(name)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: contentSize, height: contentSize)
                .clipShape(Circle())

        case .localPhoto(let image, _):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: contentSize, height: contentSize)
                .clipShape(Circle())

        case .builderPlate(let items, _):
            if contentSize <= 36 {
                // Full plate collage collapses at Nutrition Details size — stack
                // the top ingredients as overlapping cutouts instead.
                compactIngredientStack(items)
            } else {
                BuiltMealPlateView(
                    items: items,
                    plateSize: contentSize,
                    itemScale: 0.38,
                    offsetScale: 0.22,
                    plateOpacity: 0,
                    shadowOpacity: 0.06,
                    layoutMode: .compactPreview
                )
                .frame(width: contentSize, height: contentSize)
                .clipShape(Circle())
            }

        case .fallbackIcon(let systemName, _):
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent.opacity(foregroundOpacity))
        }
    }

    @ViewBuilder
    private func compactIngredientStack(_ items: [MealBuilderImageItem]) -> some View {
        let ranked = items.sorted { $0.zIndex > $1.zIndex }
        let primary = ranked.first
        let secondary = ranked.dropFirst().first

        if let primary, let secondary {
            let thumb = contentSize * 0.72
            let inset = contentSize * 0.16
            ZStack {
                ingredientThumb(secondary.imageName, size: thumb, ring: false)
                    .offset(x: -inset, y: inset * 0.35)
                ingredientThumb(primary.imageName, size: thumb, ring: true)
                    .offset(x: inset, y: -inset * 0.35)
            }
            .frame(width: contentSize, height: contentSize)
        } else if let primary {
            ingredientThumb(primary.imageName, size: contentSize, ring: false)
        }
    }

    private func ingredientThumb(_ name: String, size: CGFloat, ring: Bool) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay {
                if ring {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.92), lineWidth: 1.1)
                }
            }
    }
}

typealias PlanTimelineFoodAvatar = PlanTimelineNutritionAvatar
