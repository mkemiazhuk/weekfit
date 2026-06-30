import SwiftUI
import UIKit

struct MealBuilderView: View {

    let editingMeal: Meals?
    let onSave: (Meals) -> Void
    let onCancel: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager

    @State private var selectedIngredients: [SelectedBuilderIngredient] = []
    @State private var didPrefill = false
    @State private var focusedIngredientID: String?
    @State private var focusedCategory: MealIngredientCategory?
    @State private var focusScrollToken = 0

    @State private var flyingIngredient: MealBuilderIngredient?
    @State private var flyingStartFrame: CGRect = .zero
    @State private var flyingProgressValue: CGFloat = 0
    @State private var plateFrame: CGRect = .zero
    @State private var hiddenFlyingIngredientID: String?

    init(
        editingMeal: Meals? = nil,
        onSave: @escaping (Meals) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.editingMeal = editingMeal
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var isEditMode: Bool {
        editingMeal != nil
    }
    
    private var hasUnsavedChanges: Bool {

        guard let editingMeal else {
            return !selectedIngredients.isEmpty
        }

        let current = selectedIngredients
            .sorted { $0.ingredient.id < $1.ingredient.id }
            .map { "\($0.ingredient.id):\($0.grams)" }

        let original = (editingMeal.builderImageItems ?? [])
            .sorted { $0.id < $1.id }
            .map { "\($0.id):\($0.grams)" }

        return current != original
    }

    private let background = WeekFitTheme.backgroundColor
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let cardBackground = WeekFitTheme.cardBackground
    private let elevatedCard = WeekFitTheme.elevatedCard
    private let accent = WeekFitTheme.meal

    private let ingredients = MealBuilderDemoData.ingredients.filter {
        $0.category != .drinks
    }

    private var totalCalories: Int { selectedIngredients.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Int { selectedIngredients.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Int { selectedIngredients.reduce(0) { $0 + $1.carbs } }
    private var totalFats: Int { selectedIngredients.reduce(0) { $0 + $1.fats } }
    private var totalFiber: Int { selectedIngredients.reduce(0) { $0 + $1.fiber } }

    private var builderPreviewItems: [MealBuilderImageItem] {
        selectedIngredients
            .filter { $0.ingredient.id != hiddenFlyingIngredientID }
            .map { selected in
                let ingredient = selected.ingredient

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
                    grams: selected.grams
                )
            }
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

                platePreview
                    .padding(.horizontal, 16)

                nutritionSummary
                    .padding(.horizontal, 16)

                buildProgress
                    .padding(.horizontal, 16)

                ScrollViewReader { verticalProxy in
                    ScrollView(showsIndicators: false) {
                        ingredientSections
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                    }
                    .onChange(of: focusScrollToken) { _, _ in
                        guard let focusedCategory else { return }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                                verticalProxy.scrollTo(focusedCategory.title, anchor: .center)
                            }
                        }
                    }
                }
            }

            flyingIngredientOverlay
        }
        .preferredColorScheme(.dark)
        .onAppear {
            prefillIfNeeded()
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
                    WeekFitTheme.whiteOpacity(0.012),
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
        WeekFitDetailScreenHeader(
            title: WeekFitLocalizedString(isEditMode ? "meals.builder.title.edit" : "meals.builder.title.create"),
            subtitle: WeekFitLocalizedString(isEditMode ? "meals.builder.subtitle.edit" : "meals.builder.subtitle.create"),
            titleColor: textPrimary,
            subtitleColor: textSecondary.opacity(0.76),
            titleDesign: .default
        ) {
            WeekFitDetailScreenBackButton {
                onCancel?()
                dismiss()
            }
        } trailing: {
            WeekFitDetailScreenSaveButton(isEnabled: hasUnsavedChanges, accent: accent) {
                saveMeal()
            }
        }
    }

    private var flyingIngredientOverlay: some View {
        ZStack {
            if let flyingIngredient {
                let start = CGPoint(x: flyingStartFrame.midX, y: flyingStartFrame.midY)
                let end = flyingLandingPoint(for: flyingIngredient)
                let current = flyingPoint(from: start, to: end, progress: flyingProgressValue)

                if !flyingIngredient.imageName.isEmpty,
                   UIImage(named: flyingIngredient.imageName) != nil {
                    Image(flyingIngredient.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: finalPlateItemSize(for: flyingIngredient))
                        .position(current)
                        .rotationEffect(.degrees(Double(flyingIngredient.rotation) * flyingProgressValue))
                        .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    private func flyingPoint(
        from start: CGPoint,
        to end: CGPoint,
        progress: CGFloat
    ) -> CGPoint {
        let t = min(max(progress, 0), 1)

        let eased = 1 - pow(1 - t, 2.2)

        let x = start.x + (end.x - start.x) * eased
        let y = start.y + (end.y - start.y) * eased

        let arc = sin(t * .pi) * 34

        return CGPoint(
            x: x,
            y: y - arc
        )
    }
    
    
    
    private func flyingLandingPoint(for ingredient: MealBuilderIngredient) -> CGPoint {
        let centerX = plateFrame.midX
        let centerY = plateFrame.midY - 6

        let items = selectedIngredients.map { selected in
            let ingredient = selected.ingredient

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
                grams: selected.grams
            )
        }

        let resolvedOffset = PlateLayoutEngine.layoutItem(
            matching: ingredient.id,
            in: items,
            plateSize: 220,
            itemScale: 1.00,
            offsetScale: 0.82
        )?.offset ?? CGSize(
            width: CGFloat(ingredient.offsetX) * 0.82,
            height: CGFloat(ingredient.offsetY) * 0.82 - 2
        )

        let x = centerX + resolvedOffset.width
        let y = centerY + resolvedOffset.height

        return CGPoint(x: x, y: y)
    }
    
    private func finalPlateItemSize(for ingredient: MealBuilderIngredient) -> CGFloat {
        let itemScale: CGFloat = 1.00
        let baseWidth = CGFloat(ingredient.visualSize) * 1.12 * itemScale

        let ratio = CGFloat(ingredient.defaultGrams) / 100
        let normalized = log2(max(ratio, 0.45))

        let gramScale = min(
            max(
                0.94 + normalized * ingredient.visualDensity * 0.14,
                0.78
            ),
            1.34
        )

        return baseWidth * gramScale
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
                            WeekFitTheme.whiteOpacity(0.065),
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
        .shadow(color: WeekFitTheme.cardShadow.opacity(0.66), radius: 14, y: 7)
    }

    private var plateImageStack: some View {
        ZStack {
            if builderPreviewItems.isEmpty {
                emptyDrinkOrPlateState
            } else {
                BuiltMealPlateView(
                    items: builderPreviewItems,
                    plateSize: 220,
                    itemScale: 1.00,
                    offsetScale: 0.82,
                    plateOpacity: 1.00,
                    shadowOpacity: 0.22
                )
                .offset(y: -6)
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        plateFrame = geo.frame(in: .global)
                    }
                    .onChange(of: builderPreviewItems.count) { _, _ in
                        plateFrame = geo.frame(in: .global)
                    }
            }
        }
    }

    private func flyIngredient(
        _ ingredient: MealBuilderIngredient,
        from frame: CGRect
    ) {
        let duration: Double = 0.54

        hiddenFlyingIngredientID = ingredient.id
        flyingIngredient = ingredient
        flyingStartFrame = frame
        flyingProgressValue = 0

        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            addIngredientWithoutPulse(ingredient)
        }

        withAnimation(.linear(duration: duration)) {
            flyingProgressValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                hiddenFlyingIngredientID = nil
                flyingIngredient = nil
                flyingProgressValue = 0
            }
        }
    }
    
    private func addIngredientWithoutPulse(_ ingredient: MealBuilderIngredient) {
        if ingredient.category == .drinks {
            selectedIngredients.removeAll()
        } else {
            selectedIngredients.removeAll {
                $0.ingredient.category == .drinks
            }
        }

        if ingredient.category == .base {
            selectedIngredients.removeAll {
                $0.ingredient.category == .base
            }
        }

        let selected = SelectedBuilderIngredient(
            ingredient: ingredient,
            grams: ingredient.defaultGrams
        )

        selectedIngredients.append(selected)
    }

    private var selectedDrinks: [SelectedBuilderIngredient] {
        selectedIngredients.filter { $0.ingredient.category == .drinks }
    }

    private func amountText(_ selected: SelectedBuilderIngredient) -> String {
        let key = selected.ingredient.category == .drinks
            ? "common.unit.millilitersFormat"
            : "common.unit.gramValueFormat"
        return String(format: WeekFitLocalizedString(key), selected.grams)
    }

    private var emptyDrinkOrPlateState: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedDrinks.isEmpty ? "fork.knife.circle" : "cup.and.saucer.fill")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(textSecondary.opacity(0.72))

            Text(WeekFitLocalizedString(selectedDrinks.isEmpty ? "meals.builder.empty.startWithBase" : "meals.builder.empty.drinksSelected"))
                .font(.system(size: 12.2, weight: .semibold))
                .foregroundStyle(textSecondary.opacity(0.80))
        }
        .offset(y: 2)
    }

    private var selectedIngredientsRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(mealTitle)
                    .font(.system(size: 17.4, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.28)
                    .lineLimit(1)

                if selectedIngredients.isEmpty {
                    Text(WeekFitLocalizedString("meals.pickIngredientsBelowToComposeYourMeal"))
                        .font(.system(size: 12.2, weight: .medium))
                        .foregroundStyle(textSecondary.opacity(0.76))
                        .lineLimit(1)
                } else {
                    Text(selectedIngredients.map { "\($0.ingredient.localizedTitle) (\(amountText($0)))" }.joined(separator: " + "))
                        .font(.system(size: 12.2, weight: .medium))
                        .foregroundStyle(textSecondary.opacity(0.76))
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)
                }
            }

            Spacer()

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nutritionSummary: some View {
        HStack(spacing: 8) {
            nutritionTile("meals.nutrition.calories", "\(totalCalories)", "common.unit.kcal", isPrimary: true)
            nutritionTile("meals.nutrition.protein", "\(totalProtein)", "common.unit.gramShort")
            nutritionTile("meals.nutrition.carbs", "\(totalCarbs)", "common.unit.gramShort")
            nutritionTile("meals.nutrition.fats", "\(totalFats)", "common.unit.gramShort")
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

                Text(WeekFitLocalizedString(unit))
                    .font(.system(size: 9.4, weight: .semibold))
                    .foregroundStyle(isPrimary ? accent.opacity(0.76) : textSecondary.opacity(0.70))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            Text(WeekFitLocalizedString(title))
                .font(.system(size: 9.4, weight: .medium))
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

    private var buildProgress: some View {
        HStack(spacing: 7) {
            progressPill(selectedIngredients.contains { $0.ingredient.category == .base }, "meals.builder.progress.base")
            progressPill(selectedIngredients.contains { $0.ingredient.category == .protein }, "meals.builder.progress.protein")
            progressPill(selectedIngredients.contains { $0.ingredient.category == .vegetables }, "meals.builder.progress.veg")
            progressPill(selectedIngredients.contains { $0.ingredient.category == .extras }, "meals.builder.progress.extra")
        }
    }

    private func progressPill(_ active: Bool, _ title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 10.6, weight: .bold))

            Text(WeekFitLocalizedString(title))
                .font(.system(size: 10.6, weight: .bold))
        }
        .foregroundStyle(active ? accent.opacity(0.92) : textSecondary.opacity(0.45))
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background {
            Capsule()
                .fill(active ? accent.opacity(0.075) : WeekFitTheme.whiteOpacity(0.026))
        }
        .overlay {
            Capsule()
                .stroke(active ? accent.opacity(0.12) : WeekFitTheme.whiteOpacity(0.035), lineWidth: 1)
        }
    }

    private var ingredientSections: some View {
        VStack(spacing: 10) {
            ForEach(MealIngredientCategory.allCases.filter { $0 != .drinks }) { category in
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

            ScrollViewReader { horizontalProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(items) { ingredient in
                            ingredientCard(ingredient)
                                .id(ingredient.id)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.trailing, 2)
                }
                .onChange(of: focusScrollToken) { _, _ in
                    guard focusedCategory == category else { return }
                    guard let focusedIngredientID else { return }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                            horizontalProxy.scrollTo(focusedIngredientID, anchor: .center)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.top, 10)
        .padding(.bottom, 11)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(WeekFitTheme.whiteOpacity(0.030))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(WeekFitTheme.whiteOpacity(0.040), lineWidth: 1)
        }
        .id(category.title)
    }

    private func ingredientCard(_ ingredient: MealBuilderIngredient) -> some View {
        let selectedInstance = selectedIngredients.first { $0.ingredient.id == ingredient.id }
        let isSelected = selectedInstance != nil

        return VStack(spacing: 6) {
            GeometryReader { geo in
                Button {
                    let frame = geo.frame(in: .global)

                    if isSelected {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                            toggle(ingredient)
                        }
                    } else {
                        flyIngredient(ingredient, from: frame)
                    }

                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    ingredientCardContent(ingredient: ingredient, isSelected: isSelected)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 76, height: 68)

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
                Text(String(format: WeekFitLocalizedString(ingredient.category == .drinks ? "common.unit.millilitersFormat" : "common.unit.gramValueFormat"), ingredient.defaultGrams))
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
            if !ingredient.imageName.isEmpty,
               UIImage(named: ingredient.imageName) != nil {
                Image(ingredient.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 32)
                    .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(textSecondary)
                    .frame(width: 42, height: 32)
            }

            Text(ingredient.localizedTitle)
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
            .fill(WeekFitTheme.whiteOpacity(isSelected ? 0.05 : 0.02))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? accent.opacity(0.4) : WeekFitTheme.whiteOpacity(0.03),
                        lineWidth: 1
                    )
            }
    }

    private var canSave: Bool {
        !selectedIngredients.isEmpty
    }

    private var mealTitle: String {
        let protein = selectedIngredients.first { $0.ingredient.category == .protein }?.ingredient.localizedTitle
        let base = selectedIngredients.first { $0.ingredient.category == .base }?.ingredient.localizedTitle
        let vegetable = selectedIngredients.first { $0.ingredient.category == .vegetables }?.ingredient.localizedTitle
        let extra = selectedIngredients.first { $0.ingredient.category == .extras }?.ingredient.localizedTitle
        let drinks = selectedIngredients.first { $0.ingredient.category == .drinks }?.ingredient.localizedTitle

        if let protein, let base { return "\(protein) \(base)" }
        if let base, let extra { return "\(extra) \(base)" }
        if let vegetable, let protein { return "\(protein) \(vegetable)" }

        if let base { return base }
        if let protein { return protein }
        if let vegetable { return vegetable }
        if let extra { return extra }
        if let drinks { return drinks }

        return editingMeal?.title ?? WeekFitLocalizedString("meals.builder.defaultMealTitle")
    }

    private func toggle(_ ingredient: MealBuilderIngredient) {
        if selectedIngredients.contains(where: { $0.ingredient.id == ingredient.id }) {
            selectedIngredients.removeAll { $0.ingredient.id == ingredient.id }
            return
        }

        if ingredient.category == .drinks {
            selectedIngredients.removeAll()
        } else {
            selectedIngredients.removeAll {
                $0.ingredient.category == .drinks
            }
        }

        if ingredient.category == .base {
            selectedIngredients.removeAll {
                $0.ingredient.category == .base
            }
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

        let meal = Meals(
            id: editingMeal?.id ?? "custom_meal_\(UUID().uuidString)",
            title: mealTitle,
            subtitle: subtitle,
            imageName: editingMeal?.imageName ?? "plate-dark",
            type: editingMeal?.type ?? .balanced,
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fats: totalFats,
            fiber: totalFiber,
            benefits: editingMeal?.benefits ?? makeBenefits(),
            ingredients: mealIngredients,
            suggestedTime: editingMeal?.suggestedTime ?? currentSuggestedTime,
            builderImageItems: builderImageItems
        )

        onSave(meal)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if !isEditMode {
            dismiss()
        }
    }

    private func prefillIfNeeded() {
        guard !didPrefill else { return }
        guard let editingMeal else { return }

        didPrefill = true

        if let imageItems = editingMeal.builderImageItems, !imageItems.isEmpty {
            let restored = imageItems.compactMap { item -> SelectedBuilderIngredient? in
                guard let ingredient = ingredients.first(where: { $0.id == item.id }) else {
                    return nil
                }

                return SelectedBuilderIngredient(
                    ingredient: ingredient,
                    grams: item.grams
                )
            }

            if !restored.isEmpty {
                selectedIngredients = restored
                let target = restored.first?.ingredient
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    focusedCategory = target?.category
                    focusedIngredientID = target?.id
                    focusScrollToken += 1
                }
                return
            }
        }

        let restoredFromIngredients = editingMeal.ingredients.compactMap { mealIngredient -> SelectedBuilderIngredient? in
            guard let ingredient = ingredients.first(where: {
                normalize($0.title) == normalize(mealIngredient.name)
            }) else {
                return nil
            }

            return SelectedBuilderIngredient(
                ingredient: ingredient,
                grams: parseAmount(mealIngredient.amount) ?? ingredient.defaultGrams
            )
        }

        selectedIngredients = restoredFromIngredients
        let target = restoredFromIngredients.first?.ingredient
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            focusedCategory = target?.category
            focusedIngredientID = target?.id
            focusScrollToken += 1
        }
    }

    private func makeMealIngredients() -> [MealsIngredient] {
        selectedIngredients.map { selected in
            MealsIngredient(
                name: selected.ingredient.localizedTitle,
                amount: amountText(selected)
            )
        }
    }

    private func makeBuilderImageItems() -> [MealBuilderImageItem] {
        builderPreviewItems
    }

    private func makeSubtitle() -> String {
        selectedIngredients
            .map { "\($0.ingredient.localizedTitle) (\(amountText($0)))" }
            .joined(separator: " + ")
    }

    private func makeBenefits() -> [String] {
        [
            WeekFitLocalizedString("meals.builder.benefit.customMeal"),
            WeekFitLocalizedString("meals.builder.benefit.profile"),
            WeekFitLocalizedString("meals.builder.benefit.balancedIngredients")
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
            return selectedIngredients.contains { $0.ingredient.category == .base }
                ? WeekFitLocalizedString("meals.builder.hint.oneSelected")
                : WeekFitLocalizedString("meals.builder.hint.chooseOne")

        case .protein:
            return selectedIngredients.contains { $0.ingredient.category == .protein }
                ? WeekFitLocalizedString("meals.builder.hint.added")
                : WeekFitLocalizedString("meals.builder.hint.addProtein")

        case .vegetables:
            let count = selectedIngredients.filter { $0.ingredient.category == .vegetables }.count
            return count > 0
                ? WeekFitCountPluralization.ingredientsAddedPhrase(count: count)
                : WeekFitLocalizedString("meals.builder.hint.addMore")

        case .extras:
            return selectedIngredients.contains { $0.ingredient.category == .extras }
                ? WeekFitLocalizedString("meals.builder.hint.added")
                : WeekFitLocalizedString("meals.builder.hint.optional")

        case .drinks:
            return selectedIngredients.contains { $0.ingredient.category == .drinks }
                ? WeekFitLocalizedString("meals.builder.hint.added")
                : WeekFitLocalizedString("meals.builder.hint.optional")
        }
    }

    private func parseAmount(_ value: String) -> Int? {
        let digits = value.filter { $0.isNumber }
        return Int(digits)
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }
}
