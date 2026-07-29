import SwiftUI

// MARK: - Row kind (hierarchy via styling, shared meal green)

enum MealLibraryRowKind: Equatable, Sendable {
    /// Complete reusable meal — stronger presence.
    case meal
    /// Ingredient / library food — calmer presence.
    case food

    var premiumEmphasis: WeekFitPremiumCardEmphasis {
        switch self {
        case .meal: return .standard
        case .food: return .compact
        }
    }

    var accentBarWidth: CGFloat {
        switch self {
        case .meal: return 3
        case .food: return 1.5
        }
    }

    var accentBarOpacity: Double {
        switch self {
        case .meal: return 0.46
        case .food: return 0.24
        }
    }

    var accentBarVerticalInset: CGFloat {
        switch self {
        case .meal: return 7
        case .food: return 10
        }
    }

    var titleSize: CGFloat {
        switch self {
        case .meal: return 15.5
        case .food: return 14.5
        }
    }

    var titleWeight: Font.Weight {
        switch self {
        case .meal: return .semibold
        case .food: return .medium
        }
    }

    var titleOpacity: Double {
        switch self {
        case .meal: return 1.0
        case .food: return 0.90
        }
    }

    var kcalOpacity: Double {
        switch self {
        case .meal: return 0.68
        case .food: return 0.58
        }
    }

    var macroLabelOpacity: Double {
        switch self {
        case .meal: return 0.58
        case .food: return 0.42
        }
    }

    var macroValueOpacity: Double {
        switch self {
        case .meal: return 0.50
        case .food: return 0.42
        }
    }

    var thumbSize: CGFloat {
        switch self {
        case .meal: return 54
        case .food: return 50
        }
    }

    var thumbOpacity: Double {
        switch self {
        case .meal: return 1.0
        case .food: return 0.88
        }
    }

    var minCardHeight: CGFloat {
        switch self {
        case .meal: return 64
        case .food: return 60
        }
    }

    var chevronOpacity: Double {
        switch self {
        case .meal: return 0.28
        case .food: return 0.20
        }
    }
}

// MARK: - Metrics (8pt rhythm)

enum MealLibraryCardMetrics {
    static let cornerRadius: CGFloat = 18
    static let thumbCornerRadius: CGFloat = 14
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 8
    static let contentSpacing: CGFloat = 12
    static let thumbToChevronSpacing: CGFloat = 6
    static let kcalSize: CGFloat = 12
    static let macroSize: CGFloat = 10
    static let textStackSpacing: CGFloat = 4
}

// MARK: - Shared thumbnail

struct MealLibraryThumbnail: View {
    let meal: Meals
    var size: CGFloat = 54
    var cornerRadius: CGFloat = MealLibraryCardMetrics.thumbCornerRadius

    private let textSecondary = WeekFitTheme.secondaryText

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.whiteOpacity(0.055),
                            WeekFitTheme.whiteOpacity(0.022)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Group {
                if meal.isFoodProduct {
                    AsyncCustomFoodPlateView(
                        filename: meal.displayPhotoFilename,
                        initial: meal.placeholderInitial,
                        plateSize: size,
                        itemScale: 0.36,
                        offsetScale: 0.28,
                        plateOpacity: 0.16,
                        shadowOpacity: 0.08,
                        layoutMode: .compactPreview,
                        photoTargetPixelSize: MealPhotoStore.libraryRowPixelSize
                    )
                } else if let items = meal.builderImageItems, !items.isEmpty {
                    BuiltMealPlateView(
                        items: items,
                        plateSize: size,
                        itemScale: 0.36,
                        offsetScale: 0.28,
                        plateOpacity: 0.16,
                        shadowOpacity: 0.08,
                        layoutMode: .compactPreview
                    )
                } else if !meal.imageName.isEmpty, FoodImageQualityValidator.isDisplayableAsset(named: meal.imageName) {
                    Image(meal.imageName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                } else {
                    Image(systemName: meal.isFoodProduct ? "carrot.fill" : "fork.knife")
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(textSecondary.opacity(0.30))
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(WeekFitTheme.whiteOpacity(0.08), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Badge (Coach purple — recommendation chrome only)

private struct MealLibraryRecommendationBadge: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(WeekFitTheme.coachAccent.opacity(0.78))

            Text(title)
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .tracking(0.15)
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .frame(height: 18)
        .background {
            Capsule()
                .fill(WeekFitTheme.coachAccent.opacity(0.10))
        }
    }
}

// MARK: - Card row

struct HeroMealLibraryRow: View {
    let meal: Meals
    var kind: MealLibraryRowKind = .meal
    let isQuickLogMode: Bool
    let isRecommended: Bool
    var recommendationBadge: String? = nil
    var recommendationIcon: String? = nil
    var isHighlighted: Bool = false
    let onPlusTap: (() -> Void)?

    @State private var isPressed = false
    @State private var highlightStrokeOpacity: Double = 0

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    /// Nutrition domain accent — shared by Meals and Foods.
    private let accent = WeekFitTheme.meal

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(accent.opacity(kind.accentBarOpacity))
                .frame(width: kind.accentBarWidth)
                .padding(.vertical, kind.accentBarVerticalInset)

            HStack(alignment: .center, spacing: MealLibraryCardMetrics.contentSpacing) {
                textBlock
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .center, spacing: MealLibraryCardMetrics.thumbToChevronSpacing) {
                    MealLibraryThumbnail(meal: meal, size: kind.thumbSize)
                        .opacity((isPressed ? 0.92 : 1.0) * kind.thumbOpacity)
                        .scaleEffect(isPressed ? 0.98 : 1.0)

                    trailingAction
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.vertical, MealLibraryCardMetrics.verticalPadding)
        }
        .frame(minHeight: kind.minCardHeight)
        .weekFitPremiumCard(
            emphasis: kind.premiumEmphasis,
            accent: accent,
            cornerRadius: MealLibraryCardMetrics.cornerRadius
        )
        .overlay(pressHighlight)
        .overlay(highlightPulseOverlay)
        .scaleEffect(isPressed ? 0.988 : 1.0)
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
        .onChange(of: isHighlighted) { _, highlighted in
            guard highlighted else {
                highlightStrokeOpacity = 0
                return
            }
            runHighlightPulse()
        }
        .accessibilityElement(children: isQuickLogMode ? .contain : .combine)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint(isQuickLogMode ? "" : WeekFitLocalizedString("meals.library.openDetailsHint"))
        .accessibilityAddTraits(.isButton)
    }

    private var rowAccessibilityLabel: String {
        String(
            format: WeekFitLocalizedString("meals.library.rowAccessibilityFormat"),
            meal.localizedDisplayTitle,
            meal.calories
        )
    }

    // MARK: Content

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: MealLibraryCardMetrics.textStackSpacing) {
            if isRecommended,
               let recommendationBadge,
               !recommendationBadge.isEmpty {
                MealLibraryRecommendationBadge(
                    title: recommendationBadge,
                    icon: recommendationIcon ?? "star.fill"
                )
            }

            Text(meal.localizedDisplayTitle)
                .font(.system(size: kind.titleSize, weight: kind.titleWeight, design: .rounded))
                .foregroundStyle(textPrimary.opacity(kind.titleOpacity))
                .tracking(kind == .meal ? -0.26 : -0.18)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(format: WeekFitLocalizedString("meals.value.kcalFormat"), meal.calories))
                .font(.system(size: MealLibraryCardMetrics.kcalSize, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(kind.kcalOpacity))
                .monospacedDigit()
                .lineLimit(1)

            macroLine
        }
    }

    private var macroLine: some View {
        let labelOpacity = kind == .meal ? 0.78 : 0.68

        return HStack(spacing: 0) {
            macroSegment(
                value: meal.protein,
                label: WeekFitLocalizedString("meals.library.macroProtein"),
                labelTint: NutritionStyle.proteinColor.opacity(labelOpacity)
            )
            macroSeparator
            macroSegment(
                value: meal.carbs,
                label: WeekFitLocalizedString("meals.library.macroCarbs"),
                labelTint: NutritionStyle.carbsColor.opacity(labelOpacity)
            )
            macroSeparator
            macroSegment(
                value: meal.fats,
                label: WeekFitLocalizedString("meals.library.macroFats"),
                labelTint: NutritionStyle.fatColor.opacity(labelOpacity)
            )
            macroSeparator
            macroSegment(
                value: meal.fiber,
                label: WeekFitLocalizedString("meals.library.macroFiber"),
                labelTint: NutritionStyle.fiberColor.opacity(labelOpacity)
            )
        }
        .font(.system(size: MealLibraryCardMetrics.macroSize, weight: .medium, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }

    private func macroSegment(value: Int, label: String, labelTint: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .fontWeight(.semibold)
                .foregroundStyle(labelTint)

            Text(String(format: WeekFitLocalizedString("common.unit.gramValueFormat"), value))
                .foregroundStyle(textSecondary.opacity(kind.macroValueOpacity))
        }
    }

    private var macroSeparator: some View {
        Text("·")
            .foregroundStyle(WeekFitTheme.whiteOpacity(kind == .meal ? 0.16 : 0.12))
            .padding(.horizontal, 4)
    }

    private var pressHighlight: some View {
        RoundedRectangle(cornerRadius: MealLibraryCardMetrics.cornerRadius, style: .continuous)
            .fill(WeekFitTheme.whiteOpacity(isPressed ? 0.032 : 0))
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
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black.opacity(0.80))
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(accent.opacity(0.88))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                String(
                    format: WeekFitLocalizedString("meals.quickLog.logFormat"),
                    meal.localizedDisplayTitle
                )
            )
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(WeekFitTheme.whiteOpacity(kind.chevronOpacity))
                .frame(width: 6, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private var highlightPulseOverlay: some View {
        RoundedRectangle(cornerRadius: MealLibraryCardMetrics.cornerRadius, style: .continuous)
            .stroke(accent.opacity(highlightStrokeOpacity), lineWidth: 1.25)
            .allowsHitTesting(false)
    }

    private func runHighlightPulse() {
        highlightStrokeOpacity = 0
        withAnimation(.easeInOut(duration: 0.28)) {
            highlightStrokeOpacity = 0.55
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeInOut(duration: 0.28)) {
                highlightStrokeOpacity = 0.14
            }
            try? await Task.sleep(for: .milliseconds(280))
            withAnimation(.easeInOut(duration: 0.28)) {
                highlightStrokeOpacity = 0.48
            }
            try? await Task.sleep(for: .milliseconds(320))
            withAnimation(.easeOut(duration: 0.35)) {
                highlightStrokeOpacity = 0
            }
        }
    }
}

struct MealsLibrarySkeletonRow: View {
    @State private var pulse = false

    var body: some View {
        Color.clear
            .frame(height: MealLibraryRowKind.meal.minCardHeight)
            .weekFitPremiumCard(
                emphasis: .compact,
                accent: nil,
                cornerRadius: MealLibraryCardMetrics.cornerRadius
            )
            .opacity(pulse ? 0.92 : 0.55)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
