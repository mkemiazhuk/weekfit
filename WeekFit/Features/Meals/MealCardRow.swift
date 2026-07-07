import SwiftUI

struct MealCardRow: View {
    let meal: Meals
    var isQuickLogMode: Bool = false
    var onPlusTap: (() -> Void)? = nil

    @EnvironmentObject private var languageManager: AppLanguageManager

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let textTertiary = WeekFitTheme.tertiaryText
    private let cardSecondary = WeekFitTheme.cardSecondary
    private let cardBackground = WeekFitTheme.cardBackground
    private let cardShadow = WeekFitTheme.cardShadow

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
        let _ = languageManager.selectedLanguage

        HStack(spacing: isQuickLogMode ? 12 : 12) {
            mealImage
                .frame(
                    width: isQuickLogMode ? 78 : 54,
                    height: isQuickLogMode ? 62 : 40
                )

            VStack(alignment: .leading, spacing: isQuickLogMode ? 6 : 6) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .center, spacing: 6) {
                            Text(meal.isFoodProduct ? meal.title : meal.localizedShortTitle)
                                .font(.system(
                                    size: isQuickLogMode ? 17.2 : 15.4,
                                    weight: .bold,
                                    design: .rounded
                                ))
                                .foregroundStyle(textPrimary)
                                .tracking(isQuickLogMode ? -0.35 : -0.22)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)

                            if isQuickLogMode && isMealMatchingCurrentTime {
                                Text(WeekFitLocalizedString("meals.suggested"))
                                    .font(.system(size: 8.8, weight: .bold))
                                    .tracking(0.4)
                                    .foregroundStyle(weekFitGreen)
                                    .padding(.horizontal, 7)
                                    .frame(height: 18)
                                    .background {
                                        Capsule()
                                            .fill(weekFitGreen.opacity(0.08))
                                    }
                                    .overlay {
                                        Capsule()
                                            .stroke(weekFitGreen.opacity(0.22), lineWidth: 1)
                                    }
                            }
                        }

                        Text(meal.isFoodProduct ? meal.servingDescription : meal.localizedDisplaySubtitle)
                            .font(.system(
                                size: isQuickLogMode ? 12.4 : 11.5,
                                weight: .medium
                            ))
                            .foregroundStyle(textSecondary.opacity(isQuickLogMode ? 0.56 : 0.65))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isQuickLogMode {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onPlusTap?()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(weekFitGreen.opacity(0.18))
                                    .frame(width: 42, height: 42)

                                Circle()
                                    .stroke(weekFitGreen.opacity(0.14), lineWidth: 1)

                                Image(systemName: "plus")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(weekFitGreen)
                            }
                        }
                        .buttonStyle(.plain)
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
        .padding(.horizontal, isQuickLogMode ? 12 : 12)
        .padding(.vertical, isQuickLogMode ? 10 : 8)
        .frame(height: isQuickLogMode ? 86 : nil)
        .background {
            RoundedRectangle(cornerRadius: isQuickLogMode ? 23 : 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            cardSecondary.opacity(0.97),
                            cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: isQuickLogMode ? 23 : 20, style: .continuous)
                .stroke(
                    WeekFitTheme.whiteOpacity(0.035),
                    lineWidth: 1
                )
        }
        .contentShape(Rectangle())
        .shadow(
            color: isQuickLogMode ? weekFitGreen.opacity(0.035) : cardShadow.opacity(0.5),
            radius: isQuickLogMode ? 12 : 10,
            y: isQuickLogMode ? 5 : 5
        )
    }

    private var mealImage: some View {
        Group {
            if meal.isFoodProduct {
                AsyncCustomFoodVisualView(
                    filename: meal.displayPhotoFilename,
                    placeholderInitial: meal.placeholderInitial,
                    size: isQuickLogMode ? 54 : 36,
                    imageScale: 0.62
                )
                .offset(x: isQuickLogMode ? -6 : -4)

            } else if let items = meal.builderImageItems, !items.isEmpty {
                builtMealImage(items)

            } else if !meal.imageName.isEmpty, FoodImageQualityValidator.isDisplayableAsset(named: meal.imageName) {
                PremiumAssetImage(
                    imageName: meal.imageName,
                    style: .mealCard,
                    accentColor: textTertiary,
                    fallbackSystemName: "fork.knife"
                )

            } else {
                RoundedRectangle(cornerRadius: isQuickLogMode ? 18 : 12)
                    .fill(WeekFitTheme.whiteOpacity(0.04))
                    .overlay {
                        Image(systemName: "fork.knife")
                            .font(.system(size: isQuickLogMode ? 20 : 14))
                            .foregroundColor(textTertiary)
                    }
            }
        }
        .frame(
            width: isQuickLogMode ? 78 : 64,
            height: isQuickLogMode ? 62 : 64
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: isQuickLogMode ? 18 : 12,
                style: .continuous
            )
        )
    }

    private func builtMealImage(_ items: [MealBuilderImageItem]) -> some View {
        let previewSize: CGFloat = isQuickLogMode ? 74 : 60

        return ZStack {
            Color.black.opacity(0.10)

            BuiltMealPlateView(
                items: items,
                plateSize: previewSize,
                itemScale: isQuickLogMode ? 0.28 : 0.24,
                offsetScale: isQuickLogMode ? 0.28 : 0.23,
                plateOpacity: 0.42,
                shadowOpacity: 0.12,
                layoutMode: .compactPreview
            )
        }
        .frame(
            width: isQuickLogMode ? 78 : 64,
            height: isQuickLogMode ? 62 : 64
        )
    }

    private var macrosPill: some View {
        HStack(spacing: 0) {
            Text(String(format: WeekFitLocalizedString("meals.detail.caloriesFormat"), meal.calories))
                .font(.system(size: isQuickLogMode ? 11.2 : 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.9))
                .frame(maxWidth: .infinity)

            Rectangle().fill(WeekFitTheme.whiteOpacity(0.04)).frame(width: 1, height: 10)
            macroText("\(WeekFitLocalizedString("nutrition.macro.protein.short")) \(String(format: WeekFitLocalizedString("common.unit.gramValueFormat"), meal.protein))")
            Rectangle().fill(WeekFitTheme.whiteOpacity(0.04)).frame(width: 1, height: 10)
            macroText("\(WeekFitLocalizedString("nutrition.macro.carbs.short")) \(String(format: WeekFitLocalizedString("common.unit.gramValueFormat"), meal.carbs))")
            Rectangle().fill(WeekFitTheme.whiteOpacity(0.04)).frame(width: 1, height: 10)
            macroText("\(WeekFitLocalizedString("nutrition.macro.fats.short")) \(String(format: WeekFitLocalizedString("common.unit.gramValueFormat"), meal.fats))")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .frame(height: isQuickLogMode ? 20 : 18)
        .background {
            Capsule()
                .fill(WeekFitTheme.whiteOpacity(isQuickLogMode ? 0.030 : 0.025))
        }
    }

    private func macroText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: isQuickLogMode ? 10.4 : 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(textSecondary.opacity(0.6))
            .frame(maxWidth: .infinity)
    }
}
