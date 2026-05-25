import SwiftUI

struct MealCardRow: View {
    let meal: Meals
    var isQuickLogMode: Bool = false
    var onPlusTap: (() -> Void)? = nil
    
    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let textTertiary = WeekFitTheme.tertiaryText
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let cardBackground = WeekFitTheme.cardBackground
    private let cardShadow = WeekFitTheme.cardShadow
    
    // 🎨 Наш благородный WeekFit Зеленый
    private let weekFitGreen = Color(red: 0.16, green: 0.80, blue: 0.43)

    private var isMealMatchingCurrentTime: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        switch meal.slot {
        case .breakfast: return hour >= 0 && hour < 11
        case .lunch:     return hour >= 11 && hour < 16
        case .snack:     return hour >= 16 && hour < 18
        case .dinner:    return hour >= 18 && hour <= 23
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            
            // ЛЕВАЯ КОЛОНКА: Твоя чистая картинка блюда
            mealImage
                .frame(width: 54, height: 40)
            
            // ЦЕНТРАЛЬНЫЙ БЛОК: Текст, тег рекомендации и экшены
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .center, spacing: 6) {
                            Text(meal.shortTitle)
                                .font(.system(size: 15.4, weight: .bold))
                                .foregroundStyle(textPrimary)
                                .tracking(-0.22)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            
                            if isQuickLogMode && isMealMatchingCurrentTime {
                                // 💎 РЕФАКТОР UX: Облегченный тег без агрессивной заливки
                                Text("Suggested")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(weekFitGreen)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background {
                                        Capsule()
                                            .stroke(weekFitGreen.opacity(0.3), lineWidth: 1)
                                    }
                            }
                        }

                        Text(meal.subtitle)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(textSecondary.opacity(0.65))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // ЭКШЕН-ПАНЕЛЬ СТРОКИ
                    if isQuickLogMode {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onPlusTap?()
                        } label: {
                            // 💎 РЕФАКТОР UX: Легкий, стильный нативный плюс без тяжелого круга
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(weekFitGreen)
                                .frame(width: 30, height: 30)
                                .background {
                                    Circle()
                                        .fill(weekFitGreen.opacity(0.1))
                                }
                                .padding(.leading, 4)
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13.2, weight: .bold))
                            .foregroundStyle(textTertiary.opacity(0.4))
                            .rotationEffect(.degrees(90))
                            .frame(width: 9)
                            .padding(.top, 1)
                    }
                }

                macrosPill
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            isQuickLogMode && isMealMatchingCurrentTime ? weekFitGreen.opacity(0.01) : Color.clear,
                            cardSecondary.opacity(0.97),
                            cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isQuickLogMode && isMealMatchingCurrentTime ? weekFitGreen.opacity(0.12) : Color.white.opacity(0.03), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .shadow(color: cardShadow.opacity(0.5), radius: 10, y: 5)
    }

    private var mealImage: some View {
        Group {
            if let items = meal.builderImageItems, !items.isEmpty {
                builtMealImage(items)
            } else if UIImage(named: meal.imageName) != nil {
                Image(meal.imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .overlay { Image(systemName: "fork.knife").font(.system(size: 14)).foregroundColor(textTertiary) }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func builtMealImage(_ items: [MealBuilderImageItem]) -> some View {
        ZStack {
            Image("plate-dark")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)

            ForEach(items.sorted(by: { $0.zIndex < $1.zIndex })) { item in
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: CGFloat(item.visualSize) * 0.28)
                    .offset(x: CGFloat(item.offsetX) * 0.2, y: CGFloat(item.offsetY) * 0.2)
                    .rotationEffect(.degrees(Double(item.rotation)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.1))
    }

    private var macrosPill: some View {
        HStack(spacing: 0) {
            Text("\(meal.calories) kcal")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.9))
                .frame(maxWidth: .infinity)

            Rectangle().fill(Color.white.opacity(0.04)).frame(width: 1, height: 10)
            macroText("P \(meal.protein)g")
            Rectangle().fill(Color.white.opacity(0.04)).frame(width: 1, height: 10)
            macroText("C \(meal.carbs)g")
            Rectangle().fill(Color.white.opacity(0.04)).frame(width: 1, height: 10)
            macroText("F \(meal.fats)g")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .frame(height: 18)
        .background { Capsule().fill(Color.white.opacity(0.025)) }
    }

    private func macroText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(textSecondary.opacity(0.6))
            .frame(maxWidth: .infinity)
    }
}
