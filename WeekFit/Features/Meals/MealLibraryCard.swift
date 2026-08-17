import SwiftUI

// MARK: - Row kind (hierarchy via styling, shared meal green)

enum MealLibraryRowKind: String, Identifiable, Equatable, Sendable {
    /// Complete reusable meal — stronger presence.
    case meal
    /// Ingredient / library food — calmer presence.
    case food

    var id: String { rawValue }

    var premiumEmphasis: WeekFitPremiumCardEmphasis {
        switch self {
        case .meal: return .standard
        case .food: return .compact
        }
    }

    var sectionTitleKey: String {
        switch self {
        case .meal: return "meals.library.section.meals"
        case .food: return "meals.library.section.foods"
        }
    }

    var sectionIcon: String {
        switch self {
        case .meal: return "fork.knife"
        case .food: return "takeoutbag.and.cup.and.straw.fill"
        }
    }
}

// MARK: - Metrics

enum MealLibraryCardMetrics {
    static let cornerRadius: CGFloat = WeekFitSurface.primaryRadius
    static let gridSpacing: CGFloat = 12
    /// Dish thumb — plate fills the tile; ingredients scale up on top.
    static let thumbSize: CGFloat = 104
    /// Uniform grid tile height so every card matches.
    static let cardHeight: CGFloat = 236
    /// Two lines of 15pt rounded title — exact height so kcal/macros share a row.
    static let titleBlockHeight: CGFloat = 38
    static let kcalRowHeight: CGFloat = 16
    static let macroBlockHeight: CGFloat = 32
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 14
    static let menuSize: CGFloat = 28
    static let periodMarkSize: CGFloat = 22
    static let kcalSize: CGFloat = 13
    static let macroSize: CGFloat = 11
    static let titleSize: CGFloat = 15
    static let previewLimit: Int = 4

    static let thumbTopInset: CGFloat = 2
    static let thumbToTextSpacing: CGFloat = 8
    static let textBlockSpacing: CGFloat = 3
    static let macroBlockTopSpacing: CGFloat = 2

    enum ExpandSheet {
        static let sheetTopPadding: CGFloat = 18
        static let titleToSearch: CGFloat = 10
        /// Search field → first section header.
        static let searchToContent: CGFloat = 8
        static let headerMinHeight: CGFloat = 36
        static let headerTopPadding: CGFloat = 6
        static let headerBottomPadding: CGFloat = 4
        /// Section header → first card row.
        static let headerToCards: CGFloat = 6
        /// After a section's last card row, before the next header.
        static let sectionBottom: CGFloat = 8
        static let scrollBottom: CGFloat = 28
    }
}

// MARK: - Shared thumbnail

struct MealLibraryThumbnail: View {
    let meal: Meals
    var size: CGFloat = 54
    var cornerRadius: CGFloat = WeekFitSurface.iconWellRadius
    var isCircle: Bool = false

    @Environment(\.weekFitPalette) private var palette

    private var textSecondary: Color { WeekFitTheme.secondaryText }

    private var wellFill: Color {
        palette.isLight
            ? WeekFitLightTokens.thumbnailWell
            : WeekFitTheme.whiteOpacity(0.07)
    }

    private var resolvedRadius: CGFloat {
        isCircle ? size / 2 : cornerRadius
    }

    var body: some View {
        let showsPlatedMeal = !meal.isFoodProduct && !(meal.builderImageItems ?? []).isEmpty

        ZStack {
            // Soft well only for custom food / placeholders — not behind plated meals
            // (avoids the double light-grey ring under the ceramic plate).
            if !showsPlatedMeal {
                RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                    .fill(wellFill)
            }

            Group {
                if meal.isFoodProduct {
                    // Custom food: product photo only — no ceramic plate.
                    AsyncCustomFoodVisualView(
                        filename: meal.displayPhotoFilename,
                        placeholderInitial: meal.placeholderInitial,
                        size: size * 0.78,
                        imageScale: 0.74,
                        fallbackSystemImage: "takeoutbag.and.cup.and.straw.fill"
                    )
                } else if let items = meal.builderImageItems, !items.isEmpty {
                    ZStack {
                        if palette.isLight {
                            // Light: ceramic white dish (no stone plate-dark).
                            libraryCeramicPlate(size: size * 0.92)

                            BuiltMealPlateView(
                                items: items,
                                plateSize: size * 0.92,
                                itemScale: 0.64,
                                offsetScale: 0.34,
                                plateOpacity: 0,
                                shadowOpacity: 0.10,
                                layoutMode: .preview,
                                showsPlateChrome: false
                            )
                        } else {
                            // Dark: previous soft grey dish — no pearl ceramic.
                            Circle()
                                .fill(WeekFitTheme.whiteOpacity(0.10))
                                .frame(width: size * 0.92, height: size * 0.92)
                            Circle()
                                .strokeBorder(WeekFitTheme.whiteOpacity(0.08), lineWidth: 1)
                                .frame(width: size * 0.92, height: size * 0.92)

                            BuiltMealPlateView(
                                items: items,
                                plateSize: size * 0.92,
                                itemScale: 0.64,
                                offsetScale: 0.34,
                                plateOpacity: 0,
                                shadowOpacity: 0.16,
                                layoutMode: .preview,
                                showsPlateChrome: false
                            )
                        }
                    }
                } else if !meal.imageName.isEmpty, FoodImageQualityValidator.isDisplayableAsset(named: meal.imageName) {
                    Image(meal.imageName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                } else {
                    Image(systemName: meal.isFoodProduct ? "carrot.fill" : "fork.knife")
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(textSecondary)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous))
        }
        .frame(width: size, height: size)
        .overlay {
            if !showsPlatedMeal {
                RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                    .strokeBorder(
                        palette.isLight
                            ? WeekFitLightTokens.cardBorder.opacity(WeekFitLightTokens.cardBorderStrokeOpacity)
                            : WeekFitTheme.whiteOpacity(0.10),
                        lineWidth: 1
                    )
            }
        }
        .accessibilityHidden(true)
    }

    /// Soft ceramic dish for library tiles (not the stone `plate-dark` asset).
    @ViewBuilder
    private func libraryCeramicPlate(size: CGFloat) -> some View {
        let fill: Color = palette.isLight
            ? Color.white
            : Color(red: 0.90, green: 0.89, blue: 0.87) // warm pearl on OLED cards
        let rim: Color = palette.isLight
            ? Color.black.opacity(0.07)
            : Color.black.opacity(0.22)
        let innerRim: Color = palette.isLight
            ? Color.black.opacity(0.04)
            : Color.black.opacity(0.12)

        ZStack {
            // Soft contact shadow under the dish
            Ellipse()
                .fill(Color.black.opacity(palette.isLight ? 0.08 : 0.35))
                .frame(width: size * 0.86, height: size * 0.16)
                .blur(radius: 6)
                .offset(y: size * 0.34)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            fill,
                            fill.opacity(0.96),
                            palette.isLight
                                ? Color(red: 0.96, green: 0.95, blue: 0.93)
                                : Color(red: 0.84, green: 0.83, blue: 0.80)
                        ],
                        center: .center,
                        startRadius: size * 0.08,
                        endRadius: size * 0.52
                    )
                )
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .strokeBorder(rim, lineWidth: 1)
                }
                .overlay {
                    // Subtle bowl lip
                    Circle()
                        .strokeBorder(innerRim, lineWidth: max(4, size * 0.045))
                        .padding(size * 0.055)
                }
                .shadow(
                    color: Color.black.opacity(palette.isLight ? 0.06 : 0.28),
                    radius: palette.isLight ? 5 : 8,
                    y: palette.isLight ? 2 : 3
                )
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

// MARK: - Grid card (library)

struct MealLibraryGridCard: View {
    let meal: Meals
    var kind: MealLibraryRowKind = .meal
    var isHighlighted: Bool = false
    var showsPeriodMark: Bool = false
    var onLog: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.weekFitPalette) private var palette
    @State private var isPressed = false
    @State private var highlightStrokeOpacity: Double = 0

    private var textPrimary: Color { WeekFitTheme.primaryText }
    private var textSecondary: Color { WeekFitTheme.secondaryText }

    /// Calories stay quiet metadata — green is fiber (К) / meal chrome; orange is carbs (У).
    private var kcalColor: Color { textSecondary }

    private var showsOverflowMenu: Bool {
        onLog != nil || onDelete != nil
    }

    var body: some View {
        VStack(alignment: .center, spacing: MealLibraryCardMetrics.thumbToTextSpacing) {
            ZStack(alignment: .topTrailing) {
                MealLibraryThumbnail(
                    meal: meal,
                    size: MealLibraryCardMetrics.thumbSize,
                    isCircle: true
                )
                .frame(maxWidth: .infinity)
                .padding(.top, MealLibraryCardMetrics.thumbTopInset)

                if showsPeriodMark, kind == .meal {
                    periodMark
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .allowsHitTesting(false)
                }

                if showsOverflowMenu {
                    Menu {
                        if let onLog {
                            Button(action: onLog) {
                                Label(
                                    WeekFitLocalizedString("meals.library.action.logEaten"),
                                    systemImage: "checkmark.circle.fill"
                                )
                            }
                        }

                        if let onDelete {
                            Button(role: .destructive, action: onDelete) {
                                Label(WeekFitLocalizedString("common.action.delete"), systemImage: "trash.fill")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(textSecondary)
                            .frame(
                                width: MealLibraryCardMetrics.menuSize,
                                height: MealLibraryCardMetrics.menuSize
                            )
                            .background {
                                Circle()
                                    .fill(
                                        palette.isLight
                                            ? WeekFitLightTokens.surfaceTertiary
                                            : WeekFitTheme.whiteOpacity(0.08)
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(WeekFitUsesRussianLanguage() ? "Ещё" : "More")
                }
            }

            VStack(alignment: .center, spacing: MealLibraryCardMetrics.textBlockSpacing) {
                Text(meal.localizedDisplayTitle)
                    .font(.system(size: MealLibraryCardMetrics.titleSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.22)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(height: MealLibraryCardMetrics.titleBlockHeight, alignment: .top)

                Text(String(format: WeekFitLocalizedString("meals.value.kcalFormat"), meal.calories))
                    .font(.system(size: MealLibraryCardMetrics.kcalSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(kcalColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: MealLibraryCardMetrics.kcalRowHeight)

                macroGrid
                    .padding(.top, MealLibraryCardMetrics.macroBlockTopSpacing)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, MealLibraryCardMetrics.horizontalPadding)
        .padding(.vertical, MealLibraryCardMetrics.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(height: MealLibraryCardMetrics.cardHeight, alignment: .top)
        .weekFitPremiumCard(
            emphasis: kind.premiumEmphasis,
            accent: WeekFitTheme.meal,
            cornerRadius: MealLibraryCardMetrics.cornerRadius
        )
        .overlay(highlightPulseOverlay)
        .scaleEffect(isPressed ? 0.985 : 1.0)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint(WeekFitLocalizedString("meals.library.openDetailsHint"))
        .accessibilityAddTraits(.isButton)
    }

    private var rowAccessibilityLabel: String {
        if showsPeriodMark, kind == .meal {
            return "\(meal.libraryPeriod.title). " + String(
                format: WeekFitLocalizedString("meals.library.rowAccessibilityFormat"),
                meal.localizedDisplayTitle,
                meal.calories
            )
        }
        return String(
            format: WeekFitLocalizedString("meals.library.rowAccessibilityFormat"),
            meal.localizedDisplayTitle,
            meal.calories
        )
    }

    private var periodMark: some View {
        Image(systemName: meal.libraryPeriod.icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(textSecondary)
            .frame(
                width: MealLibraryCardMetrics.periodMarkSize,
                height: MealLibraryCardMetrics.periodMarkSize
            )
            .background {
                Circle()
                    .fill(
                        palette.isLight
                            ? WeekFitLightTokens.surfaceTertiary
                            : WeekFitTheme.whiteOpacity(0.08)
                    )
            }
            .accessibilityHidden(true)
    }

    /// Fixed 2×2 macro block — matches the Saved Meals reference layout.
    private var macroGrid: some View {
        VStack(alignment: .center, spacing: 3) {
            HStack(spacing: 8) {
                macroCell(
                    label: WeekFitLocalizedString("meals.library.macroProtein"),
                    value: meal.protein,
                    tint: NutritionStyle.proteinColor
                )
                macroCell(
                    label: WeekFitLocalizedString("meals.library.macroCarbs"),
                    value: meal.carbs,
                    tint: NutritionStyle.carbsColor
                )
            }
            HStack(spacing: 8) {
                macroCell(
                    label: WeekFitLocalizedString("meals.library.macroFats"),
                    value: meal.fats,
                    tint: NutritionStyle.fatColor
                )
                macroCell(
                    label: WeekFitLocalizedString("meals.library.macroFiber"),
                    value: meal.fiber,
                    tint: NutritionStyle.fiberColor
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: MealLibraryCardMetrics.macroBlockHeight, alignment: .top)
    }

    private func macroCell(label: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: MealLibraryCardMetrics.macroSize, weight: .bold, design: .rounded))
                .foregroundStyle(tint)

            Text(String(format: WeekFitLocalizedString("common.unit.gramValueFormat"), value))
                .font(.system(size: MealLibraryCardMetrics.macroSize, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }

    private var highlightPulseOverlay: some View {
        RoundedRectangle(cornerRadius: MealLibraryCardMetrics.cornerRadius, style: .continuous)
            .stroke(WeekFitTheme.meal.opacity(highlightStrokeOpacity), lineWidth: 1.25)
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

// MARK: - Legacy list row (quick-log / compact flows)

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

    private var textPrimary: Color { WeekFitTheme.primaryText }
    private var textSecondary: Color { WeekFitTheme.secondaryText }
    private var accent: Color { WeekFitTheme.meal }

    var body: some View {
        HStack(alignment: .center, spacing: MealLibraryCardMetrics.horizontalPadding) {
            textBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 8) {
                MealLibraryThumbnail(meal: meal, size: 54, isCircle: true)
                    .opacity(isPressed ? 0.92 : 1.0)
                    .scaleEffect(isPressed ? 0.98 : 1.0)

                trailingAction
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitCompactRowCard(accent: accent)
        .overlay(pressHighlight)
        .overlay(highlightPulseOverlay)
        .scaleEffect(isPressed ? 0.988 : 1.0)
        .animation(.easeOut(duration: 0.14), value: isPressed)
        .contentShape(RoundedRectangle(cornerRadius: WeekFitSurface.compactRadius, style: .continuous))
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

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isRecommended,
               let recommendationBadge,
               !recommendationBadge.isEmpty {
                MealLibraryRecommendationBadge(
                    title: recommendationBadge,
                    icon: recommendationIcon ?? "star.fill"
                )
            }

            Text(meal.localizedDisplayTitle)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text(String(format: WeekFitLocalizedString("meals.value.kcalFormat"), meal.calories))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
                .monospacedDigit()
                .lineLimit(1)

            HStack(spacing: 0) {
                macroSegment(meal.protein, WeekFitLocalizedString("meals.library.macroProtein"), NutritionStyle.proteinColor)
                Text("·").foregroundStyle(WeekFitTheme.quaternaryText).padding(.horizontal, 4)
                macroSegment(meal.carbs, WeekFitLocalizedString("meals.library.macroCarbs"), NutritionStyle.carbsColor)
                Text("·").foregroundStyle(WeekFitTheme.quaternaryText).padding(.horizontal, 4)
                macroSegment(meal.fats, WeekFitLocalizedString("meals.library.macroFats"), NutritionStyle.fatColor)
            }
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.78)
        }
    }

    private func macroSegment(_ value: Int, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 2) {
            Text(label).fontWeight(.semibold).foregroundStyle(tint)
            Text(String(format: WeekFitLocalizedString("common.unit.gramValueFormat"), value))
                .foregroundStyle(textSecondary)
        }
    }

    private var pressHighlight: some View {
        Group {
            if isPressed {
                RoundedRectangle(cornerRadius: WeekFitSurface.compactRadius, style: .continuous)
                    .fill(WeekFitTheme.internalTile.opacity(0.55))
            }
        }
    }

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
                .foregroundStyle(WeekFitTheme.iconSecondary)
                .frame(width: 6, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private var highlightPulseOverlay: some View {
        RoundedRectangle(cornerRadius: WeekFitSurface.compactRadius, style: .continuous)
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
                .foregroundStyle(WeekFitTheme.coachAccent)
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

struct MealsLibrarySkeletonRow: View {
    @State private var pulse = false

    var body: some View {
        Color.clear
            .frame(height: MealLibraryCardMetrics.cardHeight)
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
