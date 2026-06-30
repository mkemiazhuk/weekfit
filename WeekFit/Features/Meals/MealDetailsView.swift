import SwiftUI
import SwiftData
import UIKit

struct MealDetailsView: View {

    @State var meal: Meals

    // MARK: - UX contexts
    var isQuickLogMode: Bool = false
    var onMealLogged: (() -> Void)? = nil
    var onMealUpdated: ((Meals) -> Void)? = nil
    var onMealSavedAndClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager

    @State private var showMealBuilder = false

    private let background = WeekFitTheme.backgroundColor
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let cardBackground = WeekFitTheme.cardBackground
    private let elevatedCard = WeekFitTheme.elevatedCard
    private let softShadow = WeekFitTheme.cardShadow
    private let accent = WeekFitTheme.meal

    private var automatedCurrentSlotTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<11:   return WeekFitLocalizedString("meals.breakfast")
        case 11..<16:  return WeekFitLocalizedString("meals.lunch")
        case 16..<18:  return WeekFitLocalizedString("meals.snack")
        default:       return WeekFitLocalizedString("meals.dinner")
        }
    }

    private var ingredientsSummary: String {
        let names = meal.ingredients.map { $0.name }
        guard !names.isEmpty else { return meal.subtitle }

        if names.count <= 4 {
            return names.joined(separator: " • ")
        }

        return names.prefix(3).joined(separator: " • ") + " +\(names.count - 3)"
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack {
            background.ignoresSafeArea()
            ambientBackground

            VStack(spacing: 12) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        mealPreviewCard

                        nutritionSummary

                        ingredientsBlock

                        if !meal.generatedSteps.isEmpty {
                            stepsBlock
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, isQuickLogMode ? 118 : 30)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isQuickLogMode {
                quickLogButton
            }
        }
        .fullScreenCover(isPresented: $showMealBuilder) {
            MealBuilderView(
                editingMeal: meal,
                onSave: { updatedMeal in
                    applyUpdatedMeal(updatedMeal)
                    try? modelContext.save()
                    onMealUpdated?(meal)
                    onMealSavedAndClose?()
                },
                onCancel: {
                    showMealBuilder = false
                }
            )
        }
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.045), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 340
            )

            RadialGradient(
                colors: [WeekFitTheme.orange.opacity(0.025), .clear],
                center: .bottomLeading,
                startRadius: 80,
                endRadius: 380
            )

            LinearGradient(
                colors: [
                    WeekFitTheme.whiteOpacity(0.010),
                    .clear,
                    Color.black.opacity(0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var header: some View {
        WeekFitDetailScreenHeader(
            title: WeekFitLocalizedString("meals.mealDetails"),
            subtitle: WeekFitLocalizedString("meals.reviewIngredientsNutritionAndPreparation"),
            titleColor: textPrimary,
            subtitleColor: textSecondary.opacity(0.76)
        ) {
            WeekFitDetailScreenBackButton {
                dismiss()
            }
        } trailing: {
            if !isQuickLogMode {
                WeekFitDetailScreenCircleButton(systemName: "square.and.pencil") {
                    showMealBuilder = true
                }
            }
        }
    }

    private var mealPreviewCard: some View {
        VStack(spacing: 8) {
            plateImageStack
                .frame(maxWidth: .infinity)
                .frame(height: 176)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(meal.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.42)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(ingredientsSummary)
                    .font(.system(size: 12.4, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.76))
                    .lineLimit(2)
                    .lineSpacing(1.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 13)
        .padding(.top, 8)
        .padding(.bottom, 13)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            elevatedCard.opacity(0.96),
                            cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    LinearGradient(
                        colors: [
                            WeekFitTheme.whiteOpacity(0.060),
                            WeekFitTheme.whiteOpacity(0.014),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
        }
        .shadow(color: softShadow.opacity(0.66), radius: 14, y: 7)
    }

    private var plateImageStack: some View {
        ZStack {
            if let items = meal.builderImageItems, !items.isEmpty {
                builtMealPreview(items)
            } else if !meal.imageName.isEmpty, UIImage(named: meal.imageName) != nil {
                Image(meal.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
            } else {
                emptyPlateState
            }
        }
    }

    private func builtMealPreview(_ items: [MealBuilderImageItem]) -> some View {
        BuiltMealPlateView(
            items: items,
            plateSize: 220,
            itemScale: 1.00,
            offsetScale: 0.82,
            plateOpacity: 1.00,
            shadowOpacity: 0.22
        )
        .scaleEffect(1.04)
        .offset(y: -6)
    }

    private var emptyPlateState: some View {
        VStack(spacing: 8) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(textSecondary.opacity(0.72))

            Text(WeekFitLocalizedString("meals.savedMeal"))
                .font(.system(size: 12.2, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.80))
        }
    }

    private var nutritionSummary: some View {
        HStack(spacing: 8) {
            nutritionTile("nutrition.metric.calories", "\(meal.calories)", "common.unit.kcal", isPrimary: true)
            nutritionTile("nutrition.metric.protein", "\(meal.protein)", "common.unit.gramShort")
            nutritionTile("nutrition.metric.carbs", "\(meal.carbs)", "common.unit.gramShort")
            nutritionTile("nutrition.metric.fats", "\(meal.fats)", "common.unit.gramShort")
        }
    }

    private func nutritionTile(
        _ title: String,
        _ value: String,
        _ unit: String,
        isPrimary: Bool = false
    ) -> some View {
        VStack(spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: isPrimary ? 15.8 : 15.2, weight: .bold, design: .rounded))
                    .foregroundStyle(isPrimary ? accent.opacity(0.94) : textPrimary.opacity(0.94))

                Text(WeekFitLocalizedString(unit))
                    .font(.system(size: 9.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(isPrimary ? accent.opacity(0.76) : textSecondary.opacity(0.70))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            Text(WeekFitLocalizedString(title))
                .font(.system(size: 9.4, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.74))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isPrimary ? accent.opacity(0.052) : WeekFitTheme.whiteOpacity(0.030))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(isPrimary ? accent.opacity(0.17) : WeekFitTheme.whiteOpacity(0.038), lineWidth: 1)
        }
    }

    private var ingredientsBlock: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("Ingredients")

                Spacer()

                Text(WeekFitLocalizedString("meals.1Serving"))
                    .font(.system(size: 12.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.70))
            }

            VStack(spacing: 0) {
                ForEach(Array(meal.ingredients.enumerated()), id: \.element.name) { index, item in
                    ingredientRow(item, index: index)

                    if index != meal.ingredients.count - 1 {
                        Rectangle()
                            .fill(WeekFitTheme.whiteOpacity(0.045))
                            .frame(height: 1)
                            .padding(.leading, 46)
                    }
                }
            }
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(WeekFitTheme.whiteOpacity(0.038))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(WeekFitTheme.whiteOpacity(0.045), lineWidth: 1)
            }
        }
    }

    private func ingredientRow(_ item: MealsIngredient, index: Int) -> some View {
        HStack(spacing: 11) {
            ingredientImage(for: item, index: index)
                .frame(width: 34, height: 34)

            Text(item.name)
                .font(.system(size: 14.2, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Spacer(minLength: 8)

            Text(item.amount)
                .font(.system(size: 13.4, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.76))
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }

    private func ingredientImage(for item: MealsIngredient, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(WeekFitTheme.whiteOpacity(0.045))

            if let imageName = ingredientImageName(index: index),
               !imageName.isEmpty,
               UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 29, height: 29)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            } else if let imageName = fallbackIngredientImageName(for: item.name),
                      !imageName.isEmpty,
                      UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.72))
            }
        }
    }

    private var stepsBlock: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("Steps")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(meal.generatedSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 11.4, weight: .bold, design: .rounded))
                            .foregroundStyle(textPrimary.opacity(0.90))
                            .frame(width: 22, height: 22)
                            .background(WeekFitTheme.whiteOpacity(0.052))
                            .clipShape(Circle())

                        Text(step)
                            .font(.system(size: 13.4, weight: .medium, design: .rounded))
                            .foregroundStyle(textPrimary.opacity(0.78))
                            .lineSpacing(2.6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var quickLogButton: some View {
        VStack(spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                executeDetailsLogBlock()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))

                    Text(String(format: WeekFitLocalizedString("meals.actions.logForFormat"), automatedCurrentSlotTitle))
                        .font(.system(size: 14.2, weight: .bold, design: .rounded))
                        .tracking(-0.08)
                }
                .foregroundStyle(.black.opacity(0.84))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    Capsule()
                        .fill(accent.opacity(0.92))
                        .shadow(color: accent.opacity(0.18), radius: 10, y: 4)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 84)
        }
        .background {
            bottomFadeGradient
        }
    }

    private var bottomFadeGradient: some View {
        LinearGradient(
            colors: [
                background.opacity(0),
                background.opacity(0.62),
                background.opacity(0.96),
                background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func executeDetailsLogBlock() {
        let now = Date()

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        let parts = meal.displayTime.split(separator: ":")
        components.hour = Int(parts.first ?? "12") ?? 12
        components.minute = Int(parts.dropFirst().first ?? "00") ?? 0
        let mealTargetDate = calendar.date(from: components) ?? now

        let activity = PlannedActivity(
            date: mealTargetDate,
            type: PlannerType.meal.title,
            title: meal.title,
            durationMinutes: 30,
            icon: PlannerType.meal.icon,
            imageName: meal.imageName,
            colorRed: PlannerType.meal.colorComponents.red,
            colorGreen: PlannerType.meal.colorComponents.green,
            colorBlue: PlannerType.meal.colorComponents.blue,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fats: meal.fats,
            source: isQuickLogMode || mealTargetDate < now ? "nutritionLog" : "planner"
        )

        activity.isCompleted = isQuickLogMode || mealTargetDate < now

        modelContext.insert(activity)
        try? modelContext.save()

        if isQuickLogMode {
            onMealLogged?()
        } else {
            dismiss()
        }
    }

    private func applyUpdatedMeal(_ updatedMeal: Meals) {
        meal.title = updatedMeal.title
        meal.subtitle = updatedMeal.subtitle
        meal.imageName = updatedMeal.imageName
        meal.type = updatedMeal.type
        meal.calories = updatedMeal.calories
        meal.protein = updatedMeal.protein
        meal.carbs = updatedMeal.carbs
        meal.fats = updatedMeal.fats
        meal.benefits = updatedMeal.benefits
        meal.ingredients = updatedMeal.ingredients
        meal.suggestedTime = updatedMeal.suggestedTime
        meal.builderImageItems = updatedMeal.builderImageItems
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(WeekFitLocalizedString(title))
            .font(.system(size: 17.0, weight: .bold, design: .rounded))
            .foregroundStyle(textPrimary)
            .tracking(-0.25)
    }

    private func ingredientImageName(index: Int) -> String? {
        guard let items = meal.builderImageItems else { return nil }
        guard items.indices.contains(index) else { return nil }
        return items[index].imageName
    }

    private func fallbackIngredientImageName(for name: String) -> String? {
        let key = normalize(name)
        let map: [(String, String)] = [
            ("rice", "ingredient-rice"), ("pasta", "ingredient-pasta"), ("potatoes", "ingredient-potatoes"),
            ("potato", "ingredient-potatoes"), ("buckwheat", "ingredient-buckwheat"), ("chicken", "ingredient-chicken"),
            ("turkey", "ingredient-turkey"), ("beef", "ingredient-beef"), ("salmon", "ingredient-salmon"),
            ("shrimp", "ingredient-shrimp"), ("whitefish", "ingredient-white-fish"), ("broccoli", "ingredient-broccoli"),
            ("spinach", "ingredient-spinach"), ("tomatoes", "ingredient-tomatoes"), ("tomato", "ingredient-tomatoes"),
            ("avocado", "ingredient-avocado"), ("oliveoil", "ingredient-olive-oil"), ("onion", "ingredient-red-onion"),
            ("cucumber", "ingredient-cucumber"), ("toast", "ingredient-toast"), ("cheese", "ingredient-cottage-cheese"),
            ("honey", "ingredient-honey"), ("banana", "ingredient-banana"), ("apple", "ingredient-apple"),
            ("milk", "ingredient-milk"), ("tea", "ingredient-tea"), ("coffee", "ingredient-coffee")
        ]
        return map.first { key.contains(normalize($0.0)) }?.1
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
