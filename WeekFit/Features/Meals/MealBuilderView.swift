import SwiftUI

struct MealBuilderView: View {

    let onSave: (Meals) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIngredients: [SelectedBuilderIngredient] = []

    private let background = WeekFitTheme.background
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let cardBackground = WeekFitTheme.cardBackground
    private let elevatedCard = WeekFitTheme.elevatedCard
    private let accent = WeekFitTheme.meal

    private let ingredients = MealBuilderDemoData.ingredients

    private var sortedSelectedIngredients: [SelectedBuilderIngredient] {
        selectedIngredients.sorted { $0.ingredient.zIndex < $1.ingredient.zIndex }
    }

    private var totalCalories: Int { selectedIngredients.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Int { selectedIngredients.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Int { selectedIngredients.reduce(0) { $0 + $1.carbs } }
    private var totalFats: Int { selectedIngredients.reduce(0) { $0 + $1.fats } }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ambientBackground
            
            // Главный жесткий VStack вместо сквозного ScrollView
            VStack(spacing: 12) {
                // 📌 ЭЛЕМЕНТЫ ЖЕСТКО ЗАКРЕПЛЕНЫ СВЕРХУ
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                platePreview
                    .padding(.horizontal, 16)
                
                nutritionSummary
                    .padding(.horizontal, 16)
                
                buildProgress
                    .padding(.horizontal, 16)
                
                // 🔄 СКРОЛЛИТСЯ ТОЛЬКО ЭТА СЕКЦИЯ ИНГРЕДИЕНТОВ
                ScrollView(showsIndicators: false) {
                    ingredientSections
                        .padding(.horizontal, 16)
                        .padding(.bottom, 126) // Запас под кнопку сохранения
                }
            }
        }
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .bottom) {
            saveButton
        }
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [accent.opacity(0.065), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 340
            )

            RadialGradient(
                colors: [WeekFitTheme.orange.opacity(0.032), .clear],
                center: .bottomLeading,
                startRadius: 80,
                endRadius: 380
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.012),
                    .clear,
                    Color.black.opacity(0.13)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.045))
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.065), lineWidth: 1)
                        }

                    Image(systemName: "chevron.left")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(textPrimary.opacity(0.92))
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Build Meal")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.75)
                    .lineLimit(1)

                Text("Choose ingredients, tap +/- to adjust portions.")
                    .font(.system(size: 13.2, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()
        }
        .padding(.bottom, 2)
    }

    private var platePreview: some View {
        VStack(spacing: 8) {
            plateImageStack
                .frame(maxWidth: .infinity)
                .frame(height: 176)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            selectedIngredientsRow
        }
        .padding(.horizontal, 13)
        .padding(.top, 8)
        .padding(.bottom, 12)
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
                            Color.white.opacity(0.065),
                            Color.white.opacity(0.014),
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
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
        }
        .shadow(color: WeekFitTheme.cardShadow.opacity(0.66), radius: 14, y: 7)
    }

    private var plateImageStack: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 218, height: 54)
                .blur(radius: 16)
                .offset(y: 72)

            Image("plate-dark")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .scaleEffect(1.04)
                .offset(y: -6)
                .shadow(color: Color.black.opacity(0.30), radius: 17, y: 11)

            ForEach(sortedSelectedIngredients) { selected in
                selectedIngredientImage(selected)
            }

            RadialGradient(
                colors: [.white.opacity(0.07), .clear],
                center: .top,
                startRadius: 8,
                endRadius: 170
            )
            .blendMode(.screen)
            .allowsHitTesting(false)

            if selectedIngredients.isEmpty {
                emptyPlateState
            }
        }
    }

    private func selectedIngredientImage(_ selected: SelectedBuilderIngredient) -> some View {
        let ingredient = selected.ingredient

        return Image(ingredient.imageName)
            .resizable()
            .scaledToFit()
            .scaleEffect(ingredientScaleFactor(for: selected))
            .frame(width: CGFloat(ingredient.visualSize) * 1.12)
            .offset(
                x: CGFloat(ingredient.offsetX) * 0.88,
                y: CGFloat(ingredient.offsetY) * 0.88 - 8
            )
            .rotationEffect(.degrees(Double(ingredient.rotation)))
            .shadow(color: Color.black.opacity(0.22), radius: 8, y: 5)
            .zIndex(Double(ingredient.zIndex))
            .transition(.scale(scale: 0.94).combined(with: .opacity))
    }
    
    private func ingredientScaleFactor(for selected: SelectedBuilderIngredient) -> CGFloat {
        let ratio = CGFloat(selected.grams) / CGFloat(selected.ingredient.defaultGrams)
        return 1.0 + (ratio - 1.0) * 0.25
    }

    private var emptyPlateState: some View {
        VStack(spacing: 6) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(textSecondary.opacity(0.72))

            Text("Start with a base")
                .font(.system(size: 12.2, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.80))
        }
        .offset(y: 2)
    }

    private var selectedIngredientsRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(mealTitle)
                .font(.system(size: 17.4, weight: .bold))
                .foregroundStyle(textPrimary)
                .tracking(-0.28)
                .lineLimit(1)

            if selectedIngredients.isEmpty {
                Text("Pick ingredients below to compose your meal.")
                    .font(.system(size: 12.2, weight: .medium))
                    .foregroundStyle(textSecondary.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            } else {
                Text(selectedIngredients.map { "\($0.ingredient.title) (\($0.grams)g)" }.joined(separator: " + "))
                    .font(.system(size: 12.2, weight: .medium))
                    .foregroundStyle(textSecondary.opacity(0.76))
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nutritionSummary: some View {
        HStack(spacing: 8) {
            nutritionTile("Calories", "\(totalCalories)", "kcal", isPrimary: true)
            nutritionTile("Protein", "\(totalProtein)", "g")
            nutritionTile("Carbs", "\(totalCarbs)", "g")
            nutritionTile("Fats", "\(totalFats)", "g")
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
                    .font(.system(size: isPrimary ? 15.8 : 15.2, weight: .bold))
                    .foregroundStyle(isPrimary ? accent.opacity(0.94) : textPrimary.opacity(0.94))

                Text(unit)
                    .font(.system(size: 9.4, weight: .semibold))
                    .foregroundStyle(isPrimary ? accent.opacity(0.76) : textSecondary.opacity(0.70))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            Text(title)
                .font(.system(size: 9.4, weight: .medium))
                .foregroundStyle(textSecondary.opacity(0.74))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isPrimary ? accent.opacity(0.052) : Color.white.opacity(0.030))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(isPrimary ? accent.opacity(0.17) : Color.white.opacity(0.038), lineWidth: 1)
        }
    }

    private var buildProgress: some View {
        HStack(spacing: 7) {
            progressPill(selectedIngredients.contains { $0.ingredient.category == .base }, "Base")
            progressPill(selectedIngredients.contains { $0.ingredient.category == .protein }, "Protein")
            progressPill(selectedIngredients.contains { $0.ingredient.category == .vegetables }, "Veg")
            progressPill(selectedIngredients.contains { $0.ingredient.category == .extras }, "Extra")
        }
    }

    private func progressPill(_ active: Bool, _ title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 10.6, weight: .bold))

            Text(title)
                .font(.system(size: 10.6, weight: .bold))
        }
        .foregroundStyle(active ? accent.opacity(0.92) : textSecondary.opacity(0.45))
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background {
            Capsule()
                .fill(active ? accent.opacity(0.075) : Color.white.opacity(0.026))
        }
        .overlay {
            Capsule()
                .stroke(active ? accent.opacity(0.12) : Color.white.opacity(0.035), lineWidth: 1)
        }
    }

    private var ingredientSections: some View {
        VStack(spacing: 10) {
            ForEach(MealIngredientCategory.allCases) { category in
                ingredientSection(category)
            }
        }
    }

    private func ingredientSection(_ category: MealIngredientCategory) -> some View {
        let items = ingredients.filter { $0.category == category }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.title)
                    .font(.system(size: 17.4, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.28)

                Spacer()

                Text(categoryHint(category))
                    .font(.system(size: 11.2, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.68))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items) { ingredient in
                        ingredientCard(ingredient)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.trailing, 2)
            }
        }
        .padding(.horizontal, 11)
        .padding(.top, 10)
        .padding(.bottom, 11)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.030))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.040), lineWidth: 1)
        }
    }

    private func ingredientCard(_ ingredient: MealBuilderIngredient) -> some View {
        let selectedInstance = selectedIngredients.first { $0.ingredient.id == ingredient.id }
        let isSelected = selectedInstance != nil

        return VStack(spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                    toggle(ingredient)
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                ingredientCardContent(ingredient: ingredient, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            
            if let selected = selectedInstance {
                HStack(spacing: 0) {
                    Button {
                        adjustGrams(for: ingredient, increment: false)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(accent)
                            .frame(width: 22, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    
                    Text("\(selected.grams)")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .frame(width: 26)
                        .lineLimit(1)
                    
                    Button {
                        adjustGrams(for: ingredient, increment: true)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(accent)
                            .frame(width: 22, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
                .background {
                    Capsule()
                        .fill(accent.opacity(0.08))
                        .overlay {
                            Capsule()
                                .stroke(accent.opacity(0.15), lineWidth: 1)
                        }
                }
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
            } else {
                Text("\(ingredient.defaultGrams)g")
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.5))
                    .frame(height: 20)
            }
        }
        .frame(width: 76, height: 106)
        .background {
            ingredientCardBackground(isSelected: isSelected)
        }
    }

    private func ingredientCardContent(
        ingredient: MealBuilderIngredient,
        isSelected: Bool
    ) -> some View {
        VStack(spacing: 6) {
            Image(ingredient.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 32)
                .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)

            Text(ingredient.title)
                .font(.system(size: 10.5, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? accent : textPrimary.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(.top, 8)
        .scaleEffect(isSelected ? 1.02 : 1)
    }

    private func ingredientCardBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(isSelected ? 0.05 : 0.02))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? accent.opacity(0.4) : Color.white.opacity(0.03),
                        lineWidth: 1
                    )
            }
    }

    private var saveButton: some View {
        VStack(spacing: 0) {
            Button {
                saveMeal()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: canSave ? "checkmark.circle.fill" : "plus")
                        .font(.system(size: 14, weight: .bold))

                    Text(canSave ? "Save Meal" : "Choose base or protein")
                        .font(.system(size: 14.2, weight: .bold))
                        .tracking(-0.08)
                }
                .foregroundStyle(canSave ? .black.opacity(0.82) : textSecondary.opacity(0.46))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    Capsule()
                        .fill(canSave ? accent.opacity(0.92) : Color.white.opacity(0.045))
                }
                .overlay {
                    Capsule()
                        .stroke(canSave ? accent.opacity(0.16) : Color.white.opacity(0.055), lineWidth: 1)
                }
                .shadow(color: accent.opacity(canSave ? 0.09 : 0), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background {
            bottomFadeBackground
        }
    }

    private var bottomFadeBackground: some View {
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

    private var canSave: Bool {
        selectedIngredients.contains { $0.ingredient.category == .base } ||
        selectedIngredients.contains { $0.ingredient.category == .protein }
    }

    private var mealTitle: String {
        let protein = selectedIngredients.first { $0.ingredient.category == .protein }?.ingredient.title
        let base = selectedIngredients.first { $0.ingredient.category == .base }?.ingredient.title

        if let protein, let base { return "\(protein) \(base)" }
        if let base { return base }
        if let protein { return protein }
        return "Your meal"
    }

    private func toggle(_ ingredient: MealBuilderIngredient) {
        if selectedIngredients.contains(where: { $0.ingredient.id == ingredient.id }) {
            selectedIngredients.removeAll { $0.ingredient.id == ingredient.id }
            return
        }

        if ingredient.category == .base {
            selectedIngredients.removeAll { $0.ingredient.category == .base }
        }

        let selected = SelectedBuilderIngredient(
            ingredient: ingredient,
            grams: ingredient.defaultGrams
        )

        selectedIngredients.append(selected)
    }

    private func adjustGrams(for ingredient: MealBuilderIngredient, increment: Bool) {
        guard let index = selectedIngredients.firstIndex(where: { $0.ingredient.id == ingredient.id }) else { return }
        
        let currentGrams = selectedIngredients[index].grams
        let step = ingredient.category == .extras ? 10 : 50
        
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            if increment {
                selectedIngredients[index].grams = min(currentGrams + step, 1000)
            } else {
                let targetGrams = currentGrams - step
                if targetGrams <= 0 {
                    selectedIngredients.remove(at: index)
                } else {
                    selectedIngredients[index].grams = targetGrams
                }
            }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func saveMeal() {
        let mealIngredients = makeMealIngredients()
        let builderImageItems = makeBuilderImageItems()
        let subtitle = makeSubtitle()
        let mealId = "custom_meal_\(UUID().uuidString)"

        let meal = Meals(
            id: mealId,
            title: mealTitle,
            subtitle: subtitle,
            imageName: "plate-dark",
            type: .balanced,
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fats: totalFats,
            benefits: makeBenefits(),
            ingredients: mealIngredients,
            suggestedTime: currentSuggestedTime,
            builderImageItems: builderImageItems
        )

        onSave(meal)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }

    private func makeMealIngredients() -> [MealsIngredient] {
        selectedIngredients.map { selected in
            MealsIngredient(
                name: selected.ingredient.title,
                amount: "\(selected.grams)g"
            )
        }
    }

    private func makeBuilderImageItems() -> [MealBuilderImageItem] {
        selectedIngredients.map { selected in
            let ingredient = selected.ingredient

            return MealBuilderImageItem(
                id: ingredient.id,
                imageName: ingredient.imageName,
                visualSize: ingredient.visualSize,
                offsetX: ingredient.offsetX,
                offsetY: ingredient.offsetY,
                rotation: ingredient.rotation,
                zIndex: ingredient.zIndex,
                grams: selected.grams
            )
        }
    }

    private func makeSubtitle() -> String {
        selectedIngredients
            .map { "\($0.ingredient.title) (\($0.grams)g)" }
            .joined(separator: " + ")
    }

    private func makeBenefits() -> [String] {
        [
            "Custom meal",
            "Based on your profile",
            "Balanced ingredients"
        ]
    }

    private var currentSuggestedTime: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6...10:  return "08:30"
        case 11...14: return "13:00"
        case 15...17: return "16:30"
        default:      return "19:00"
        }
    }

    private func categoryHint(_ category: MealIngredientCategory) -> String {
        switch category {
        case .base:
            return selectedIngredients.contains { $0.ingredient.category == .base } ? "1 selected" : "choose one"
        case .protein:
            return selectedIngredients.contains { $0.ingredient.category == .protein } ? "added" : "add protein"
        case .vegetables:
            let count = selectedIngredients.filter { $0.ingredient.category == .vegetables }.count
            return count > 0 ? "\(count) added" : "add more"
        case .extras:
            return selectedIngredients.contains { $0.ingredient.category == .extras } ? "added" : "optional"
        }
    }
}
