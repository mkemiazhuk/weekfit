import Foundation
import SwiftUI

enum MealsType: String, Codable, CaseIterable, Identifiable {
    case preWorkout
    case recovery
    case highProtein
    case sleepSupport
    case hydration
    case antiInflammatory
    case balanced

    var id: String { rawValue }
}

enum MealsLibraryKind: String, Codable {
    case meal
    case product
    case ingredient
}

enum CustomMealCreationMode: String, Codable {
    case manual
    case ingredients
}

struct Meals: Identifiable, Codable, Equatable {

    let id: String

    var title: String
    var subtitle: String
    var imageName: String

    var type: MealsType

    var calories: Int
    var protein: Int
    var carbs: Int
    var fats: Int

    // NEW
    var fiber: Int

    var benefits: [String]
    var ingredients: [MealsIngredient]

    var suggestedTime: String?
    var builderImageItems: [MealBuilderImageItem]?
    var libraryKind: MealsLibraryKind?
    var creationMode: CustomMealCreationMode?
    var servingGrams: Int?
    var localPhotoFilename: String?
    var localPhotoThumbnailFilename: String?
    var barcode: String?
    var nutritionDataSource: NutritionDataSource?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case imageName
        case type
        case calories
        case protein
        case carbs
        case fats
        case fiber
        case benefits
        case ingredients
        case suggestedTime
        case builderImageItems
        case libraryKind
        case creationMode
        case servingGrams
        case localPhotoFilename
        case localPhotoThumbnailFilename
        case barcode
        case nutritionDataSource
    }

    init(
        id: String,
        title: String,
        subtitle: String,
        imageName: String,
        type: MealsType,
        calories: Int,
        protein: Int,
        carbs: Int,
        fats: Int,
        fiber: Int = 0,
        benefits: [String],
        ingredients: [MealsIngredient],
        suggestedTime: String? = nil,
        builderImageItems: [MealBuilderImageItem]? = nil,
        libraryKind: MealsLibraryKind? = nil,
        creationMode: CustomMealCreationMode? = nil,
        servingGrams: Int? = nil,
        localPhotoFilename: String? = nil,
        localPhotoThumbnailFilename: String? = nil,
        barcode: String? = nil,
        nutritionDataSource: NutritionDataSource? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.type = type
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.fiber = fiber
        self.benefits = benefits
        self.ingredients = ingredients
        self.suggestedTime = suggestedTime
        self.builderImageItems = builderImageItems
        self.libraryKind = libraryKind
        self.creationMode = creationMode
        self.servingGrams = servingGrams
        self.localPhotoFilename = localPhotoFilename
        self.localPhotoThumbnailFilename = localPhotoThumbnailFilename
        self.barcode = barcode
        self.nutritionDataSource = nutritionDataSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)

        title = try container.decode(String.self, forKey: .title)

        subtitle = try container.decodeIfPresent(
            String.self,
            forKey: .subtitle
        ) ?? ""

        imageName = try container.decodeIfPresent(
            String.self,
            forKey: .imageName
        ) ?? ""

        type = try container.decodeIfPresent(
            MealsType.self,
            forKey: .type
        ) ?? .balanced

        calories = try container.decodeIfPresent(
            Int.self,
            forKey: .calories
        ) ?? 0

        protein = try container.decodeIfPresent(
            Int.self,
            forKey: .protein
        ) ?? 0

        carbs = try container.decodeIfPresent(
            Int.self,
            forKey: .carbs
        ) ?? 0

        fats = try container.decodeIfPresent(
            Int.self,
            forKey: .fats
        ) ?? 0

        // Backward compatibility with old meals.json
        fiber = try container.decodeIfPresent(
            Int.self,
            forKey: .fiber
        ) ?? 0

        benefits = try container.decodeIfPresent(
            [String].self,
            forKey: .benefits
        ) ?? []

        ingredients = try container.decodeIfPresent(
            [MealsIngredient].self,
            forKey: .ingredients
        ) ?? []

        suggestedTime = try container.decodeIfPresent(
            String.self,
            forKey: .suggestedTime
        )

        builderImageItems = try container.decodeIfPresent(
            [MealBuilderImageItem].self,
            forKey: .builderImageItems
        )

        libraryKind = try container.decodeIfPresent(
            MealsLibraryKind.self,
            forKey: .libraryKind
        )

        creationMode = try container.decodeIfPresent(
            CustomMealCreationMode.self,
            forKey: .creationMode
        )

        servingGrams = try container.decodeIfPresent(
            Int.self,
            forKey: .servingGrams
        )

        localPhotoFilename = try container.decodeIfPresent(
            String.self,
            forKey: .localPhotoFilename
        )

        localPhotoThumbnailFilename = try container.decodeIfPresent(
            String.self,
            forKey: .localPhotoThumbnailFilename
        )

        barcode = try container.decodeIfPresent(
            String.self,
            forKey: .barcode
        )

        nutritionDataSource = try container.decodeIfPresent(
            NutritionDataSource.self,
            forKey: .nutritionDataSource
        )
    }
}

struct MealsIngredient: Codable, Equatable {
    let name: String
    let amount: String
}

struct MealBuilderImageItem: Codable, Equatable, Identifiable {
    let id: String
    let imageName: String
    let visualSize: Int
    let visualDensity: CGFloat
    let supportsStandalonePresentation: Bool
    let offsetX: Int
    let offsetY: Int
    let rotation: Int
    let zIndex: Int
    let grams: Int
}

extension Meals {

    var displayTime: String {
        suggestedTime ?? "12:00"
    }

    var displayType: String {
        type.title
    }

    var tag: String {
        benefits.first ?? type.title
    }

    var shortTitle: String {
        title.components(separatedBy: ",").first ?? title
    }

    var localizedDisplayTitle: String {
        if let starterTitle = StarterMealPreparation.title(forMealID: id) {
            return starterTitle
        }
        return MealBuilderTitleComposer.displayTitle(
            storedTitle: shortTitle,
            builderImageItems: builderImageItems
        )
    }

    var localizedShortTitle: String {
        localizedDisplayTitle.components(separatedBy: ",").first ?? localizedDisplayTitle
    }

    var localizedDisplaySubtitle: String {
        MealBuilderTitleComposer.displaySubtitle(
            storedSubtitle: subtitle,
            builderImageItems: builderImageItems
        )
    }

    var localizedDisplayIngredients: [MealsIngredient] {
        MealBuilderTitleComposer.displayIngredients(
            storedIngredients: ingredients,
            builderImageItems: builderImageItems
        )
    }

    var normalizedTitle: String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    var servingDescription: String {
        guard let servingGrams, servingGrams > 0 else {
            return WeekFitLocalizedString("meals.1Serving")
        }

        return String(format: WeekFitLocalizedString("meals.lldgServing"), servingGrams)
    }

    var isFoodProduct: Bool {
        libraryKind == .product || creationMode == .manual
    }

    var isRecipeMeal: Bool {
        !isFoodProduct && libraryKind != .ingredient
    }

    var displayCategoryTitle: String {
        WeekFitLocalizedString(isFoodProduct ? "meals.category.food" : "meals.category.meal")
    }

    var sourceLabel: String {
        if creationMode == .manual || libraryKind == .product {
            return WeekFitLocalizedString("meals.customFood")
        }

        if creationMode == .ingredients {
            return WeekFitLocalizedString("meals.customMeal")
        }

        return "WeekFit"
    }

    var placeholderInitial: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "F" }
        return String(first).uppercased()
    }

    var hasCustomPhoto: Bool {
        !(localPhotoThumbnailFilename?.isEmpty ?? true) || !(localPhotoFilename?.isEmpty ?? true)
    }

    var displayPhotoFilename: String? {
        localPhotoThumbnailFilename ?? localPhotoFilename
    }

    /// Image key persisted onto `PlannedActivity.imageName` when logging/planning.
    /// Prefer a custom photo filename so Nutrition Details can resolve media without
    /// relying only on catalog title matching. For Meal Builder recipes, persist the
    /// primary ingredient asset so timeline avatars work even when title localization
    /// diverges from the catalog. Skip placeholder plate assets.
    var activityImageName: String {
        if let photoFilename = displayPhotoFilename?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !photoFilename.isEmpty {
            return photoFilename
        }

        if let primaryIngredient = primaryBuilderIngredientImageName {
            return primaryIngredient
        }

        let trimmed = imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !FoodImageQualityValidator.isPlaceholderAssetName(trimmed) else {
            return ""
        }
        return trimmed
    }

    var primaryBuilderIngredientImageName: String? {
        guard let items = builderImageItems, !items.isEmpty else { return nil }

        let primary = items.max(by: { $0.zIndex < $1.zIndex }) ?? items.first
        let name = primary?.imageName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty,
              !FoodImageQualityValidator.isPlaceholderAssetName(name) else {
            return nil
        }
        return name
    }

    var color: Color {
        type.color
    }

    var slot: WeekFitMealSlot {

        let time = displayTime

        let hour = Int(time.prefix(2)) ?? 12
        let minutes = Int(time.dropFirst(3).prefix(2)) ?? 0

        let totalMinutes = hour * 60 + minutes

        switch totalMinutes {

        case 6 * 60...(10 * 60 + 30):
            return .breakfast

        case 11 * 60...(14 * 60 + 30):
            return .lunch

        case 15 * 60...(17 * 60 + 30):
            return .snack

        default:
            return .dinner
        }
    }

    /// Breakfast / lunch / dinner bucket for the View All Meals sheet.
    var libraryPeriod: MealLibraryPeriod {
        if DefaultMealLibrarySeeder.breakfastIDs.contains(id) { return .breakfast }
        if DefaultMealLibrarySeeder.lunchIDs.contains(id) { return .lunch }
        if DefaultMealLibrarySeeder.dinnerIDs.contains(id) { return .dinner }

        return MealLibraryPeriod.period(at: libraryHour(from: displayTime))
    }

    private func libraryHour(from time: String) -> Int {
        let hourPart = time.split(separator: ":", maxSplits: 1).first.map(String.init) ?? time
        return Int(hourPart) ?? 12
    }

    var slotTitle: String {
        slot.title
    }

    var generatedSteps: [String] {
        if let starterSteps = StarterMealPreparation.steps(forMealID: id) {
            return starterSteps
        }

        let ingredientNames = localizedDisplayIngredients
            .prefix(4)
            .map(\.name)
            .joined(separator: ", ")

        return [
            String(format: WeekFitLocalizedString("meals.prepareAllIngredients"), ingredientNames),
            WeekFitLocalizedString("meals.cookOrAssembleTheMainProteinAndBaseComponents"),
            WeekFitLocalizedString("meals.addVegetablesToppingsAndDressingIfIncluded"),
            WeekFitLocalizedString("meals.serveFreshAndAdjustSeasoningToTaste")
        ]
    }
}

extension MealsType {

    var title: String {

        switch self {

        case .preWorkout:
            return "Pre Workout"

        case .recovery:
            return "Recovery"

        case .highProtein:
            return "High Protein"

        case .sleepSupport:
            return "Sleep Support"

        case .hydration:
            return "Hydration"

        case .antiInflammatory:
            return "Anti Inflammatory"

        case .balanced:
            return "Balanced"
        }
    }

    var color: Color {

        switch self {

        case .preWorkout:
            return Color(
                red: 0.93,
                green: 0.63,
                blue: 0.30
            )

        case .recovery:
            return Color(
                red: 0.45,
                green: 0.72,
                blue: 0.56
            )

        case .highProtein:
            return Color(
                red: 0.58,
                green: 0.68,
                blue: 0.82
            )

        case .sleepSupport:
            return Color(
                red: 0.52,
                green: 0.47,
                blue: 0.78
            )

        case .hydration:
            return Color(
                red: 0.42,
                green: 0.68,
                blue: 0.86
            )

        case .antiInflammatory:
            return Color(
                red: 0.50,
                green: 0.70,
                blue: 0.48
            )

        case .balanced:
            return Color(
                red: 0.55,
                green: 0.68,
                blue: 0.62
            )
        }
    }
}

enum MealBuilderTitleComposer {

    static func displayTitle(
        storedTitle: String,
        builderImageItems: [MealBuilderImageItem]?
    ) -> String {
        compose(from: builderImageItems) ?? localizedStoredTitle(storedTitle)
    }

    static func displaySubtitle(
        storedSubtitle: String,
        builderImageItems: [MealBuilderImageItem]?
    ) -> String {
        let selections = resolvedSelections(from: builderImageItems)
        guard !selections.isEmpty else { return storedSubtitle }

        return selections
            .map { "\($0.ingredient.localizedTitle) (\(amountText(for: $0.ingredient, grams: $0.grams)))" }
            .joined(separator: " + ")
    }

    static func displayIngredients(
        storedIngredients: [MealsIngredient],
        builderImageItems: [MealBuilderImageItem]?
    ) -> [MealsIngredient] {
        let selections = resolvedSelections(from: builderImageItems)
        guard !selections.isEmpty else { return storedIngredients }

        return selections.map {
            MealsIngredient(
                name: $0.ingredient.localizedTitle,
                amount: amountText(for: $0.ingredient, grams: $0.grams)
            )
        }
    }

    static func resolvedSelections(
        from items: [MealBuilderImageItem]?
    ) -> [(ingredient: MealBuilderIngredient, grams: Int)] {
        guard let items, !items.isEmpty else { return [] }

        let catalog = Dictionary(uniqueKeysWithValues: MealBuilderDemoData.ingredients.map { ($0.id, $0) })
        return items.compactMap { item in
            guard let ingredient = catalog[item.id] else { return nil }
            return (ingredient, item.grams)
        }
    }

    static func amountText(for ingredient: MealBuilderIngredient, grams: Int) -> String {
        let key = ingredient.category == .drinks
            ? "common.unit.millilitersFormat"
            : "common.unit.gramValueFormat"
        return String(format: WeekFitLocalizedString(key), grams)
    }

    static func compose(from items: [MealBuilderImageItem]?) -> String? {
        compose(from: items, titleForIngredient: { $0.localizedTitle })
    }

    /// English + Russian composed titles so logged Quick Log rows still match
    /// catalog meals after localization (e.g. "Индейка Огурец" ↔ "Turkey Cucumber").
    static func matchingTitleCandidates(from items: [MealBuilderImageItem]?) -> [String] {
        [
            compose(from: items, titleForIngredient: { $0.title }),
            compose(from: items, titleForIngredient: { $0.russianTitle }),
        ]
        .compactMap { $0 }
    }

    static func compose(
        from items: [MealBuilderImageItem]?,
        titleForIngredient: (MealBuilderIngredient) -> String
    ) -> String? {
        guard let items, !items.isEmpty else { return nil }

        let resolvedIngredients = resolvedSelections(from: items).map(\.ingredient)
        guard !resolvedIngredients.isEmpty else { return nil }

        func first(in category: MealIngredientCategory) -> MealBuilderIngredient? {
            resolvedIngredients.first { $0.category == category }
        }

        let protein = first(in: .protein).map(titleForIngredient)
        let base = first(in: .base).map(titleForIngredient)
        let vegetable = first(in: .vegetables).map(titleForIngredient)
        let extra = first(in: .extras).map(titleForIngredient)
        let drinks = first(in: .drinks).map(titleForIngredient)

        if let protein, let base { return "\(protein) \(base)" }
        if let base, let extra { return "\(extra) \(base)" }
        if let vegetable, let protein { return "\(protein) \(vegetable)" }

        if let base { return base }
        if let protein { return protein }
        if let vegetable { return vegetable }
        if let extra { return extra }
        if let drinks { return drinks }

        return resolvedIngredients.first.map(titleForIngredient)
    }

    /// Maps a stored English/Russian recipe title into the active UI language
    /// by swapping known Meal Builder ingredient labels.
    static func localizedStoredTitle(_ title: String) -> String {
        remapStoredTitle(title, toRussian: WeekFitUsesRussianLanguage())
    }

    static func remapStoredTitle(_ title: String, toRussian: Bool) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return title }

        // Longer names first so "Sweet Potato" wins over "Potato".
        let ingredients = MealBuilderDemoData.ingredients.sorted {
            max($0.title.count, $0.russianTitle.count) > max($1.title.count, $1.russianTitle.count)
        }

        var result = trimmed
        for ingredient in ingredients {
            let source = toRussian ? ingredient.title : ingredient.russianTitle
            let target = toRussian ? ingredient.russianTitle : ingredient.title
            guard source.compare(target, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame else {
                continue
            }
            result = replaceWholePhrase(source, with: target, in: result)
        }
        return result
    }

    private static func replaceWholePhrase(_ phrase: String, with replacement: String, in text: String) -> String {
        guard !phrase.isEmpty else { return text }

        // Space-padded matching works for both Latin and Cyrillic (unlike \\b).
        let haystack = " \(text) "
        let needle = " \(phrase) "
        guard let regex = try? NSRegularExpression(
            pattern: NSRegularExpression.escapedPattern(for: needle),
            options: [.caseInsensitive]
        ) else {
            return text
        }

        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        let replaced = regex.stringByReplacingMatches(
            in: haystack,
            options: [],
            range: range,
            withTemplate: " \(replacement) "
        )
        return replaced.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
