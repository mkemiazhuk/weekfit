import SwiftUI
import SwiftData

struct MealDetailsView: View {

    let meal: Meals
    
    // MARK: - UX-Контексты детализации
    var isQuickLogMode: Bool = false
    var onMealLogged: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let background = WeekFitTheme.background
    private let cardBackground = WeekFitTheme.cardBackground
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let elevatedCard = WeekFitTheme.elevatedCard

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let textTertiary = WeekFitTheme.tertiaryText

    private let softShadow = WeekFitTheme.cardShadow

    private var automatedCurrentSlotTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<11:   return "Breakfast"
        case 11..<16:  return "Lunch"
        case 16..<18:  return "Snack"
        default:       return "Dinner"
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            background.ignoresSafeArea()
            ambientBackground

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroImage

                    VStack(alignment: .leading, spacing: 18) {
                        titleBlock
                        whyBlock
                        benefitsBlock
                        ingredientsBlock
                        stepsBlock
                        actionButtons
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
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
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.045), lineWidth: 1)
                    }
                    .shadow(color: softShadow.opacity(0.68), radius: 14, y: 7)
                    .offset(y: -14)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 118)
                }
            }

            topButtons
        }
        .preferredColorScheme(.dark)
    }

    private var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [
                    meal.color.opacity(0.075),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 340
            )

            RadialGradient(
                colors: [
                    WeekFitTheme.meal.opacity(0.045),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 70,
                endRadius: 380
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.012),
                    Color.clear,
                    Color.black.opacity(0.13)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var heroImage: some View {
        ZStack {
            if let items = meal.builderImageItems, !items.isEmpty {
                customMealHero(items)
            } else if UIImage(named: meal.imageName) != nil {
                Image(meal.imageName)
                    .resizable()
                    .scaledToFill()
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.02),
                                Color.black.opacity(0.26)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            } else {
                LinearGradient(
                    colors: [
                        meal.color.opacity(0.16),
                        meal.color.opacity(0.065),
                        cardBackground.opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(meal.color.opacity(0.90))
            }
        }
        .frame(height: 248)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 30,
                bottomTrailingRadius: 30,
                topTrailingRadius: 0,
                style: .continuous
            )
        )
        .clipped()
        .ignoresSafeArea(edges: .top)
    }

    private func customMealHero(_ items: [MealBuilderImageItem]) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    meal.color.opacity(0.13),
                    cardBackground.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image("plate-dark")
                .resizable()
                .scaledToFit()
                .frame(width: 224, height: 224)
                .shadow(color: .black.opacity(0.24), radius: 16, y: 10)

            ForEach(items.sorted(by: { $0.zIndex < $1.zIndex })) { item in
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: CGFloat(item.visualSize) * 1.06)
                    .offset(
                        x: CGFloat(item.offsetX) * 0.92,
                        y: CGFloat(item.offsetY) * 0.92 - 2
                    )
                    .rotationEffect(.degrees(Double(item.rotation)))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    .zIndex(Double(item.zIndex))
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var topButtons: some View {
        HStack {
            topCircleButton(icon: "chevron.left", color: textPrimary) {
                dismiss()
            }

            Spacer()

            topCircleButton(icon: "heart.fill", color: meal.color) { }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }

    private func topCircleButton(
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color.opacity(0.92))
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(Color.black.opacity(0.24))
                        .background(.ultraThinMaterial, in: Circle())
                }
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.095), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(meal.title)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(textPrimary)
                .tracking(-0.45)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            HStack(spacing: 7) {
                tag(meal.slotTitle, color: meal.color)
                tag(meal.displayType, color: WeekFitTheme.meal)
            }

            HStack(spacing: 7) {
                macroMetric("\(meal.calories)", "kcal", color: WeekFitMacroColor.calories)
                macroMetric("\(meal.protein)g", "Protein", color: WeekFitMacroColor.protein)
                macroMetric("\(meal.carbs)g", "Carbs", color: WeekFitMacroColor.carbs)
                macroMetric("\(meal.fats)g", "Fat", color: WeekFitMacroColor.fats)
            }
        }
    }

    private var whyBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Why this meal?")

            Text(meal.subtitle)
                .font(.system(size: 13.2, weight: .medium))
                .foregroundStyle(textSecondary.opacity(0.78))
                .lineSpacing(2.2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefitsBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Benefits")

            FlowLayout(spacing: 7) {
                ForEach(meal.benefits, id: \.self) { benefit in
                    tag(benefit, color: meal.color)
                }
            }
        }
    }

    private var ingredientsBlock: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                sectionTitle("Ingredients")

                Spacer()

                Text("1 serving")
                    .font(.system(size: 12.4, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.74))
            }

            VStack(spacing: 0) {
                ForEach(Array(meal.ingredients.enumerated()), id: \.element.name) { index, item in
                    ingredientRow(item, index: index)

                    if index != meal.ingredients.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.045))
                            .frame(height: 1)
                            .padding(.leading, 46)
                    }
                }
            }
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.038))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.045), lineWidth: 1)
            }
        }
    }

    private func ingredientRow(_ item: MealsIngredient, index: Int) -> some View {
        HStack(spacing: 11) {
            ingredientImage(for: item, index: index)
                .frame(width: 34, height: 34)

            Text(item.name)
                .font(.system(size: 14.2, weight: .semibold))
                .foregroundStyle(textPrimary.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Spacer(minLength: 8)

            Text(item.amount)
                .font(.system(size: 13.4, weight: .medium))
                .foregroundStyle(textSecondary.opacity(0.76))
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }

    private func ingredientImage(for item: MealsIngredient, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(meal.color.opacity(0.10))

            if let imageName = ingredientImageName(index: index) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 29, height: 29)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            } else if let imageName = fallbackIngredientImageName(for: item.name) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(meal.color.opacity(0.90))
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
                            .font(.system(size: 11.4, weight: .bold))
                            .foregroundStyle(textPrimary.opacity(0.90))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.052))
                            .clipShape(Circle())

                        Text(step)
                            .font(.system(size: 13.4, weight: .medium))
                            .foregroundStyle(textPrimary.opacity(0.78))
                            .lineSpacing(2.6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 9) {
            if !isQuickLogMode {
                detailButton("Swap", icon: "arrow.left.arrow.right", primary: false) { }
            }
            
            let dynamicButtonTitle = isQuickLogMode ? "Log for \(automatedCurrentSlotTitle)" : "Add"
            
            detailButton(dynamicButtonTitle, icon: "plus.circle.fill", primary: true) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                executeDetailsLogBlock()
            }
            
            if !isQuickLogMode {
                detailButton("Edit", icon: "pencil", primary: false) { }
            }
        }
        .padding(.top, 2)
    }

    private func executeDetailsLogBlock() {
        let now = Date()
        
        // 1. Рассчитываем время для этого приема пищи на сегодня
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        let parts = meal.displayTime.split(separator: ":")
        components.hour = Int(parts.first ?? "12") ?? 12
        components.minute = Int(parts.dropFirst().first ?? "00") ?? 0
        let mealTargetDate = calendar.date(from: components) ?? now

        // 2. Создаем активность для SwiftData
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
            fats: meal.fats
        )
        
        // 🧠 УМНАЯ UX-ПРОВЕРКА:
        // Если активирован Quick Log ИЛИ если время этого приема пищи на сегодня УЖЕ прошло (например, сейчас 16:00, а мы добавляем обед, который должен был быть в 13:00)
        // то сразу помечаем как выполненное!
        if isQuickLogMode || mealTargetDate < now {
            activity.isCompleted = true
        } else {
            activity.isCompleted = false
        }
        
        // 3. Сохраняем в базу данных
        modelContext.insert(activity)
        try? modelContext.save()
        
        // 4. Закрываем экраны
        if isQuickLogMode {
            onMealLogged?()
        } else {
            dismiss()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17.4, weight: .bold))
            .foregroundStyle(textPrimary)
            .tracking(-0.28)
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11.1, weight: .bold))
            .foregroundStyle(color.opacity(0.90))
            .padding(.horizontal, 10)
            .padding(.vertical, 5.5)
            .background(color.opacity(0.092))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(color.opacity(0.095), lineWidth: 1)
            }
    }

    private func macroMetric(_ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12.6, weight: .bold))
                .foregroundStyle(textPrimary.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(label)
                .font(.system(size: 8.8, weight: .bold))
                .foregroundStyle(color.opacity(0.90))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.088))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.08), lineWidth: 1)
        }
    }

    private func detailButton(_ title: String, icon: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13.2, weight: .bold))
                .foregroundStyle(primary ? .black.opacity(0.82) : textPrimary.opacity(0.90))
                .frame(maxWidth: .infinity)
                .frame(height: 43)
                .background {
                    Capsule()
                        .fill(primary ? meal.color.opacity(0.90) : Color.white.opacity(0.052))
                }
                .overlay {
                    Capsule()
                        .stroke(primary ? meal.color.opacity(0.13) : Color.white.opacity(0.055), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
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
            ("avocado", "ingredient-avocado"), ("oliveoil", "ingredient-olive-oil"), ("onion", "ingredient-red-onion")
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
