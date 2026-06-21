import SwiftUI

// MARK: - Metrics

private enum MealLibraryCardMetrics {
    static let cornerRadius: CGFloat = 18
    static let cardHeight: CGFloat = 84
    static let chevronLaneWidth: CGFloat = 38
    static let foodWidth: CGFloat = 94
    static let foodHeight: CGFloat = 70
    static let foodTrailingInset: CGFloat = 36
    static let foodCenterOverlap: CGFloat = 34
}

// MARK: - Badge

private struct MealLibraryRecommendationBadge: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 5.8, weight: .semibold))
                .foregroundStyle(CoachPalette.stable.opacity(0.72))

            Text(title)
                .font(.system(size: 7.2, weight: .bold, design: .rounded))
                .tracking(0.55)
                .foregroundStyle(Color.white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 6)
        .frame(height: 16)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.05))
        }
    }
}

// MARK: - Card row

struct HeroMealLibraryRow: View {
    let meal: Meals
    let isQuickLogMode: Bool
    let isRecommended: Bool
    var recommendationBadge: String? = nil
    var recommendationIcon: String? = nil
    let onPlusTap: (() -> Void)?

    @State private var isPressed = false

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let rowBackground = WeekFitTheme.cardBackground
    private let cardShadow = WeekFitTheme.cardShadow
    private let accent = WeekFitTheme.meal

    var body: some View {
        ZStack(alignment: .leading) {
            cardBase

            foodComposition
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .allowsHitTesting(false)

            readabilityOverlay

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    if isRecommended,
                       let recommendationBadge,
                       !recommendationBadge.isEmpty {
                        MealLibraryRecommendationBadge(
                            title: recommendationBadge,
                            icon: recommendationIcon ?? "star.fill"
                        )
                        .padding(.bottom, 3)
                    }

                    Text(meal.shortTitle)
                        .font(.system(size: 14.9, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary.opacity(0.97))
                        .tracking(-0.28)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    Text(String(format: WeekFitLocalizedString("meals.value.kcalFormat"), meal.calories))
                        .font(.system(size: 10.8, weight: .semibold, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.80))
                        .monospacedDigit()
                        .lineLimit(1)
                        .padding(.top, 5)

                    macroLine
                        .padding(.top, 3)
                }
                .frame(width: 172, alignment: .leading)
                .padding(.leading, 14)
                .padding(.trailing, 4)

                Spacer(minLength: 0)

                trailingAction
                    .frame(width: MealLibraryCardMetrics.chevronLaneWidth, alignment: .trailing)
                    .padding(.trailing, 10)
            }
        }
        .frame(height: MealLibraryCardMetrics.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: MealLibraryCardMetrics.cornerRadius, style: .continuous))
        .overlay(cardBorder)
        .overlay(pressHighlight)
        .shadow(
            color: cardShadow.opacity(isRecommended ? 0.17 : 0.13),
            radius: isPressed ? 10 : (isRecommended ? 9 : 7),
            y: isPressed ? 5 : 4
        )
        .scaleEffect(isPressed ? 0.988 : 1.0)
        .offset(y: isPressed ? -0.5 : 0)
        .animation(.easeOut(duration: 0.14), value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: MealLibraryCardMetrics.cornerRadius, style: .continuous))
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: 14,
            pressing: { pressing in
                isPressed = pressing
            },
            perform: {}
        )
    }

    // MARK: Background

    private var cardBase: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(isRecommended ? 0.036 : 0.028),
                    rowBackground.opacity(0.65),
                    Color.black.opacity(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if isRecommended {
                LinearGradient(
                    colors: [
                        CoachPalette.stable.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            }
        }
    }

    private var foodComposition: some View {
        let plateSize = max(MealLibraryCardMetrics.foodWidth, MealLibraryCardMetrics.foodHeight) * 1.18

        return ZStack {
            if meal.isFoodProduct {
                AsyncCustomFoodPlateView(
                    filename: meal.displayPhotoFilename,
                    initial: meal.placeholderInitial,
                    plateSize: plateSize,
                    itemScale: 0.38,
                    offsetScale: 0.38,
                    plateOpacity: 0.36,
                    shadowOpacity: 0.26,
                    layoutMode: .compactPreview
                )
            } else if let items = meal.builderImageItems, !items.isEmpty {
                BuiltMealPlateView(
                    items: items,
                    plateSize: plateSize,
                    itemScale: 0.38,
                    offsetScale: 0.38,
                    plateOpacity: 0.36,
                    shadowOpacity: 0.26,
                    layoutMode: .compactPreview
                )
            } else if !meal.imageName.isEmpty, UIImage(named: meal.imageName) != nil {
                Image(meal.imageName)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.16))
            }
        }
        .frame(
            width: MealLibraryCardMetrics.foodWidth,
            height: MealLibraryCardMetrics.foodHeight
        )
        .shadow(color: Color.black.opacity(isPressed ? 0.24 : 0.22), radius: isPressed ? 11 : 10, y: isPressed ? 6 : 5)
        .scaleEffect(isPressed ? 1.012 : 1.0)
        .offset(
            x: -MealLibraryCardMetrics.foodCenterOverlap,
            y: isPressed ? -2 : 0
        )
        .padding(.trailing, isQuickLogMode ? 12 : MealLibraryCardMetrics.foodTrailingInset)
        .animation(.easeOut(duration: 0.14), value: isPressed)
    }

    private var readabilityOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.90), location: 0.0),
                .init(color: .black.opacity(0.62), location: 0.22),
                .init(color: .black.opacity(0.10), location: 0.42),
                .init(color: .black.opacity(0.00), location: 0.54)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var pressHighlight: some View {
        RoundedRectangle(cornerRadius: MealLibraryCardMetrics.cornerRadius, style: .continuous)
            .fill(Color.white.opacity(isPressed ? 0.045 : 0))
    }

    // MARK: Content

    private var macroLine: some View {
        HStack(spacing: 0) {
            macroSegment(
                value: meal.protein,
                label: WeekFitLocalizedString("meals.library.macroProtein"),
                labelTint: CoachPalette.stable.opacity(0.36)
            )
            macroSeparator
            macroSegment(
                value: meal.carbs,
                label: WeekFitLocalizedString("meals.library.macroCarbs"),
                labelTint: CoachPalette.hydration.opacity(0.34)
            )
            macroSeparator
            macroSegment(
                value: meal.fats,
                label: WeekFitLocalizedString("meals.library.macroFats"),
                labelTint: Color(red: 0.88, green: 0.68, blue: 0.34).opacity(0.36)
            )
        }
        .font(.system(size: 8.2, weight: .medium, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
    }

    private func macroSegment(value: Int, label: String, labelTint: Color) -> some View {
        HStack(spacing: 2) {
            Text(String(format: WeekFitLocalizedString("common.unit.gramValueFormat"), value))
                .foregroundStyle(Color.white.opacity(0.39))

            Text(label)
                .foregroundStyle(labelTint)
        }
    }

    private var macroSeparator: some View {
        Text("·")
            .foregroundStyle(Color.white.opacity(0.20))
            .padding(.horizontal, 4)
    }

    // MARK: Trailing

    @ViewBuilder
    private var trailingAction: some View {
        if isQuickLogMode {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onPlusTap?()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black.opacity(0.82))
                    .frame(width: 34, height: 34)
                    .background {
                        Circle()
                            .fill(accent.opacity(0.94))
                    }
            }
            .buttonStyle(.plain)
        } else {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))

                Image(systemName: "chevron.right")
                    .font(.system(size: 9.6, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.32))
            }
            .frame(width: 26, height: 26)
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: MealLibraryCardMetrics.cornerRadius, style: .continuous)
            .stroke(
                Color.white.opacity(isRecommended ? 0.07 : 0.05),
                lineWidth: 1
            )
    }
}
