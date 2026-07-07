import SwiftUI

struct NutritionDetailsSheet: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: AppLanguageManager

    let date: Date
    let protein: MacroValue
    let carbs: MacroValue
    let fat: MacroValue
    let fiber: MacroValue
    let meals: [NutritionMealItem]

    var body: some View {
        let _ = languageManager.selectedLanguage

        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    header
                    macroRings
                    nutritionInsight
                    mealTimeline

                    // Если next meal не нужен — удали эту строку
                    nextMealCard

                    accuracyNote
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
    }
}

// MARK: - Header

private extension NutritionDetailsSheet {

    var header: some View {
        VStack(spacing: 22) {
            HStack(spacing: 13) {
                Text(AppText.Nutrition.Details.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(WeekFitTheme.whiteOpacity(0.075)))
                        .overlay {
                            Circle().stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .fixedSize()
                .accessibilityLabel(Text(AppText.Common.Action.close))
            }

            HStack(spacing: 22) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.65))

                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))

                    Text(sheetDateTitle)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                }
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.75))

                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.65))
            }
        }
    }
}

// MARK: - Rings

private extension NutritionDetailsSheet {

    var macroRings: some View {
        HStack(spacing: 18) {
            macroRing(protein)
            macroRing(carbs)
            macroRing(fat)
            macroRing(fiber)
        }
    }

    func macroRing(_ macro: MacroValue) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.07), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: macro.progress)
                    .stroke(
                        macro.color,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(Int(macro.progress * 100))%")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 78, height: 78)

            VStack(spacing: 3) {
                Text(macro.title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(macro.color)

                Text(String(format: WeekFitLocalizedString("nutrition.details.macroCurrentGoalUnitFormat"), macro.current, macro.goal, macro.unit))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.68))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Insight

private extension NutritionDetailsSheet {

    var nutritionInsight: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                Text(WeekFitLocalizedString("nutrition.details.insight.title"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(WeekFitLocalizedString("nutrition.details.insight.legacySummary"))
                    .font(.system(size: 19, weight: .regular, design: .rounded))
                    .lineSpacing(5)
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.38), lineWidth: 5)
                    .frame(width: 72, height: 72)

                Image(systemName: "bolt")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.green)
            }
        }
        .padding(24)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Meal Timeline

private extension NutritionDetailsSheet {

    var mealTimeline: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(WeekFitLocalizedString("nutrition.details.section.mealTimeline"))
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                ForEach(Array(meals.enumerated()), id: \.element.id) { index, meal in
                    mealTimelineRow(meal, isLast: index == meals.count - 1)
                }
            }
        }
    }

    func mealTimelineRow(_ meal: NutritionMealItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(meal.time)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 72, alignment: .leading)
                .padding(.top, 7)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.22))
                        .frame(width: 52, height: 52)

                    Image(systemName: meal.icon)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Color.purple.opacity(0.95))
                }

                if !isLast {
                    Rectangle()
                        .fill(Color.purple.opacity(0.35))
                        .frame(width: 3, height: 56)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(meal.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(String(format: WeekFitLocalizedString("nutrition.details.meal.caloriesFormat"), meal.kcal))
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.55))
                }

                HStack(spacing: 20) {
                    macroText(WeekFitLocalizedString("meals.library.macroProtein"), meal.protein, color: .purple)
                    macroText(WeekFitLocalizedString("meals.library.macroCarbs"), meal.carbs, color: .orange)
                    macroText(WeekFitLocalizedString("meals.library.macroFats"), meal.fat, color: .pink)
                    macroText(WeekFitLocalizedString("meals.library.macroFiber"), meal.fiber, color: .green)
                }
            }
            .padding(.top, 7)
        }
        .padding(.bottom, isLast ? 0 : 8)
    }

    func macroText(_ label: String, _ value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(color)
                .fontWeight(.bold)

            Text(String(format: WeekFitLocalizedString("common.unit.gramFormat"), value))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.66))
        }
        .font(.system(size: 18, weight: .medium, design: .rounded))
    }
}

// MARK: - Next Meal

private extension NutritionDetailsSheet {

    var nextMealCard: some View {
        HStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.20))
                    .frame(width: 76, height: 76)

                Image(systemName: "fork.knife")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.green)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(WeekFitLocalizedString("nutrition.details.nextMeal.suggestion"))
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.55))

                Text(WeekFitLocalizedString("nutrition.details.nextMeal.balancedDinner"))
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(WeekFitLocalizedString("nutrition.details.nextMeal.target"))
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.6))

                HStack(spacing: 22) {
                    macroText(WeekFitLocalizedString("meals.library.macroProtein"), 35, color: .purple)
                    macroText(WeekFitLocalizedString("meals.library.macroCarbs"), 60, color: .orange)
                    macroText(WeekFitLocalizedString("meals.library.macroFats"), 15, color: .pink)
                    macroText(WeekFitLocalizedString("meals.library.macroFiber"), 8, color: .green)
                }

                Text(WeekFitLocalizedString("nutrition.details.nextMeal.caloriesRange"))
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                    .padding(.top, 2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.65))
        }
        .padding(24)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

// MARK: - Note

private extension NutritionDetailsSheet {

    var accuracyNote: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.purple.opacity(0.16))
                    .frame(width: 42, height: 42)

                Image(systemName: "info.circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.purple)
            }

            Text(WeekFitLocalizedString("nutrition.details.note.legacyFull"))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.48))
                .lineSpacing(3)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(WeekFitTheme.whiteOpacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    var cardBackground: some View {
        LinearGradient(
            colors: [
                WeekFitTheme.whiteOpacity(0.09),
                WeekFitTheme.whiteOpacity(0.045)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var sheetDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter.string(from: date)
    }
}

// MARK: - Models

struct MacroValue {
    let title: String
    let current: Int
    let goal: Int
    let unit: String
    let color: Color

    var progress: CGFloat {
        guard goal > 0 else { return 0 }
        return min(CGFloat(current) / CGFloat(goal), 1)
    }
}

struct NutritionMealItem: Identifiable {
    let id = UUID()
    let time: String
    let title: String
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let fiber: Int
    let icon: String
}

// MARK: - Preview

#Preview {
    NutritionDetailsSheet(
        date: .now,
        protein: MacroValue(title: "Protein", current: 80, goal: 153, unit: "g", color: .purple),
        carbs: MacroValue(title: "Carbs", current: 70, goal: 184, unit: "g", color: .orange),
        fat: MacroValue(title: "Fat", current: 13, goal: 64, unit: "g", color: .pink),
        fiber: MacroValue(title: "Fiber", current: 12, goal: 35, unit: "g", color: .green),
        meals: [
            NutritionMealItem(time: "08:15", title: "Eggs Toast", kcal: 420, protein: 22, carbs: 32, fat: 12, fiber: 4, icon: "fork.knife"),
            NutritionMealItem(time: "13:05", title: "Greek Yogurt", kcal: 180, protein: 18, carbs: 15, fat: 4, fiber: 2, icon: "takeoutbag.and.cup.and.straw"),
            NutritionMealItem(time: "18:30", title: "Chicken Bowl", kcal: 124, protein: 20, carbs: 23, fat: 5, fiber: 3, icon: "fork.knife")
        ]
    )
}
