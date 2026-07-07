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
                return .builderPlate(items, kind: kind)
            }
        }

        let activityImageName = activity.imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        if FoodImageQualityValidator.isDisplayableAsset(named: activityImageName) {
            return .assetImage(name: activityImageName, kind: kind)
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

        if imageName.lowercased() != "hydration",
           FoodImageQualityValidator.isDisplayableAsset(named: imageName) {
            return .assetImage(name: imageName, kind: kind)
        }

        if kind == .water,
           FoodImageQualityValidator.isDisplayableAsset(named: "ingredient-water") {
            return .assetImage(name: "ingredient-water", kind: kind)
        }

        return .fallbackIcon(systemName: fallbackIcon(for: kind), kind: kind)
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
            return .product
        }

        let source = activity.source.lowercased()
        if source == "today" || source == "nutritionlog" || source == "foodlog" {
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
            if let image = MealPhotoStore.timelineImage(for: filename)
                ?? MealPhotoStore.image(for: filename),
               FoodImageQualityValidator.isDisplayable(image) {
                return image
            }
        }

        return nil
    }

    private static func displayableBuilderItems(for meal: Meals) -> [MealBuilderImageItem]? {
        guard let items = meal.builderImageItems, !items.isEmpty else { return nil }

        let validItems = items.filter {
            FoodImageQualityValidator.isDisplayableAsset(named: $0.imageName)
        }

        return validItems.isEmpty ? nil : validItems
    }

    private static func matchingCustomMeal(
        for activity: PlannedActivity,
        in customMeals: [Meals]
    ) -> Meals? {
        guard activity.type.lowercased() == "meal" else { return nil }

        let normalizedTitle = CustomMealStore.normalizedTitle(activity.title)
        guard !normalizedTitle.isEmpty else { return nil }

        return customMeals.first {
            CustomMealStore.normalizedTitle($0.title) == normalizedTitle
        }
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
            Image(name)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: contentSize, height: contentSize)

        case .localPhoto(let image, _):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: contentSize, height: contentSize)
                .clipShape(Circle())

        case .builderPlate(let items, _):
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

        case .fallbackIcon(let systemName, _):
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent.opacity(foregroundOpacity))
        }
    }
}

typealias PlanTimelineFoodAvatar = PlanTimelineNutritionAvatar
