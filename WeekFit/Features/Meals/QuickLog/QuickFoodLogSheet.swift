import SwiftUI

// MARK: - Accent

enum QuickFoodAccent {
    /// Light mock palette — purple / orange / green / pink / blue / burgundy.
    /// Dark stays monochrome-premium: one soft lavender + quiet meta.
    static let purple = Color(red: 0.55, green: 0.42, blue: 0.82)
    static let orange = Color(red: 0.92, green: 0.55, blue: 0.32)
    /// Former drinks CTA gold — now used on Food + circles.
    static let actionOrange = Color(red: 0.78, green: 0.58, blue: 0.28)
    static let green = Color(red: 0.38, green: 0.70, blue: 0.48)
    static let pink = Color(red: 0.90, green: 0.42, blue: 0.50)
    static let blue = Color(red: 0.35, green: 0.58, blue: 0.88)
    static let burgundy = Color(red: 0.70, green: 0.28, blue: 0.34)

    /// Soft muted orange for Dark CTAs (same family as Light action).
    static let darkAction = Color(red: 0.82, green: 0.62, blue: 0.34)

    private static let lightPalette: [Color] = [orange, green, pink, blue, burgundy, actionOrange]

    /// Food + circles — always the former drinks gold/orange.
    static func action(isLight _: Bool) -> Color {
        actionOrange
    }

    static func color(for id: String, isLight: Bool) -> Color {
        guard isLight else { return darkAction }
        let hash = abs(id.utf8.reduce(0) { ($0 &* 31) &+ Int($1) })
        return lightPalette[hash % lightPalette.count]
    }

    /// Card wash only — CTA circles use `actionOrange`, not this.
    static func frequentColor(at index: Int, isLight: Bool) -> Color {
        guard isLight else { return darkAction }
        return index == 0 ? orange : green
    }

    /// kcal chips: colorful on Light, quiet stone on Dark.
    static func meta(for id: String, isLight: Bool) -> Color {
        isLight ? color(for: id, isLight: true) : QuickSheetChrome.meta
    }

    static func frequentMeta(at index: Int, isLight: Bool) -> Color {
        isLight ? frequentColor(at: index, isLight: true) : QuickSheetChrome.meta
    }

    static func cardTop(for accent: Color, isLight: Bool) -> Color {
        guard isLight else { return WeekFitTheme.whiteOpacity(0.06) }
        return accent.opacity(0.12)
    }

    static func cardBottom(for accent: Color, isLight: Bool) -> Color {
        guard isLight else { return WeekFitTheme.whiteOpacity(0.02) }
        return accent.opacity(0.04)
    }
}

// MARK: - Models

struct QuickFoodFrequentSnackRow: Identifiable, Equatable {
    let row: QuickItemDisplayRow
    let badgeKey: String
    let badgeSymbol: String
    var id: String { row.id }
    var item: QuickItem { row.item }
}

struct QuickFoodFrequentMealRow: Identifiable, Equatable {
    let row: QuickMealDisplayRow
    let badgeKey: String
    let badgeSymbol: String
    var id: String { row.id }
}

// MARK: - Sheet

struct QuickFoodLogSheet: View {
    @Binding var selectedTab: QuickNutritionLogTab

    let mealRows: [QuickMealDisplayRow]
    let frequentMealRows: [QuickFoodFrequentMealRow]
    let recentMealRows: [QuickMealDisplayRow]

    let snackRows: [QuickItemDisplayRow]
    let frequentSnackRows: [QuickFoodFrequentSnackRow]
    let recentSnackRows: [QuickItemDisplayRow]

    let session: QuickLogSessionStore
    let onClose: () -> Void
    let onOpenMealsTab: () -> Void
    let onMealPlus: (Meals) -> Void
    let onMealIncrement: (Meals) -> Void
    let onMealDecrement: (Meals) -> Void
    let onSnackPlus: (QuickItem) -> Void
    let onSnackIncrement: (QuickItem) -> Void
    let onSnackDecrement: (QuickItem) -> Void

    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var languageManager: AppLanguageManager

    @State private var revealContent = false
    @State private var sortAscending = true

    private var foodAccent: Color { QuickFoodAccent.actionOrange }

    private var sortedMealRows: [QuickMealDisplayRow] {
        mealRows.sorted {
            let left = $0.meal.isFoodProduct ? $0.meal.title : $0.meal.localizedShortTitle
            let right = $1.meal.isFoodProduct ? $1.meal.title : $1.meal.localizedShortTitle
            return sortAscending
                ? left.localizedCaseInsensitiveCompare(right) == .orderedAscending
                : left.localizedCaseInsensitiveCompare(right) == .orderedDescending
        }
    }

    private var sortedSnackRows: [QuickItemDisplayRow] {
        snackRows.sorted {
            sortAscending
                ? $0.item.localizedTitle.localizedCaseInsensitiveCompare($1.item.localizedTitle) == .orderedAscending
                : $0.item.localizedTitle.localizedCaseInsensitiveCompare($1.item.localizedTitle) == .orderedDescending
        }
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        VStack(spacing: 0) {
            QuickSheetPremiumHeader(
                title: WeekFitLocalizedString("today.quickActions.logFood"),
                subtitle: selectedTab == .meals
                    ? WeekFitLocalizedString("today.quickLog.subtitle.savedFoods")
                    : WeekFitLocalizedString("today.quickLog.subtitle.snacks"),
                onClose: onClose
            )

            QuickActionSheetSegmentedControl(
                segments: [
                    QuickActionSheetSegment(
                        id: QuickNutritionLogTab.meals.rawValue,
                        title: WeekFitLocalizedString("today.quickLog.section.meals"),
                        badgeCount: mealRows.count
                    ),
                    QuickActionSheetSegment(
                        id: QuickNutritionLogTab.snacks.rawValue,
                        title: WeekFitLocalizedString("today.quickLog.section.snacks"),
                        badgeCount: snackRows.count
                    )
                ],
                selection: Binding(
                    get: { selectedTab.rawValue },
                    set: { selectedTab = QuickNutritionLogTab(rawValue: $0) ?? .meals }
                ),
                selectedAccent: foodAccent
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    QuickActionCoachRecommendationSlot()

                    switch selectedTab {
                    case .meals:
                        mealsContent
                    case .snacks:
                        snacksContent
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
                .opacity(revealContent ? 1 : 0)
                .offset(y: revealContent ? 0 : 10)
            }
        }
        .onAppear {
            revealContent = false
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86).delay(0.04)) {
                revealContent = true
            }
        }
        .onChange(of: selectedTab) { _, _ in
            revealContent = false
            withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                revealContent = true
            }
        }
    }

    // MARK: Meals

    @ViewBuilder
    private var mealsContent: some View {
        if mealRows.isEmpty {
            emptyMeals
        } else {
            if !frequentMealRows.isEmpty {
                sectionHeader(WeekFitLocalizedString("today.quickLog.section.frequentlyUsed"))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(frequentMealRows.enumerated()), id: \.element.id) { index, frequent in
                            let profile = QuickLogNutritionProfile.from(meal: frequent.row.meal)
                            let selection = session.selection(for: frequent.id)
                            QuickFoodFrequentCard(
                                title: frequent.row.meal.isFoodProduct
                                    ? frequent.row.meal.title
                                    : frequent.row.meal.localizedShortTitle,
                                subtitle: frequentMealSubtitle(frequent.row),
                                calories: frequent.row.meal.calories,
                                badgeText: WeekFitLocalizedString(frequent.badgeKey),
                                accent: QuickFoodAccent.frequentColor(at: index, isLight: palette.isLight),
                                metaAccent: QuickFoodAccent.frequentMeta(at: index, isLight: palette.isLight),
                                selection: selection,
                                displayQuantity: selection.effectivePortions(for: profile),
                                onPlusTap: { onMealPlus(frequent.row.meal) },
                                onIncrement: { onMealIncrement(frequent.row.meal) },
                                onDecrement: { onMealDecrement(frequent.row.meal) }
                            ) {
                                QuickFoodCircularMealThumb(row: frequent.row, size: 108)
                            }
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.trailing, 18)
                }
                .padding(.horizontal, -18)
                .padding(.leading, 18)
            }

            allHeader(
                title: WeekFitLocalizedString("today.quickLog.section.allMeals")
            )

            LazyVStack(spacing: 10) {
                ForEach(sortedMealRows) { row in
                    mealLibraryRow(row)
                }
            }
        }
    }

    // MARK: Snacks

    @ViewBuilder
    private var snacksContent: some View {
        if snackRows.isEmpty {
            emptySnacks
        } else {
            if !frequentSnackRows.isEmpty {
                sectionHeader(WeekFitLocalizedString("today.quickLog.section.frequentlyUsed"))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(frequentSnackRows.enumerated()), id: \.element.id) { index, frequent in
                            let profile = QuickLogNutritionProfile.from(item: frequent.item)
                            let selection = session.selection(for: frequent.id)
                            QuickFoodFrequentCard(
                                title: frequent.item.localizedTitle,
                                subtitle: frequent.item.localizedSubtitle,
                                calories: frequent.item.calories,
                                badgeText: WeekFitLocalizedString(frequent.badgeKey),
                                accent: QuickFoodAccent.frequentColor(at: index, isLight: palette.isLight),
                                metaAccent: QuickFoodAccent.frequentMeta(at: index, isLight: palette.isLight),
                                selection: selection,
                                displayQuantity: selection.effectivePortions(for: profile),
                                onPlusTap: { onSnackPlus(frequent.item) },
                                onIncrement: { onSnackIncrement(frequent.item) },
                                onDecrement: { onSnackDecrement(frequent.item) }
                            ) {
                                QuickFoodCircularSnackThumb(row: frequent.row, size: 108)
                            }
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.trailing, 18)
                }
                .padding(.horizontal, -18)
                .padding(.leading, 18)
            }

            allHeader(
                title: WeekFitLocalizedString("today.quickLog.section.allSnacks")
            )

            LazyVStack(spacing: 10) {
                ForEach(sortedSnackRows) { row in
                    snackLibraryRow(row)
                }
            }
        }
    }

    private func frequentMealSubtitle(_ row: QuickMealDisplayRow) -> String {
        let raw = row.meal.isFoodProduct
            ? row.meal.servingDescription
            : row.meal.localizedDisplaySubtitle
        return raw.replacingOccurrences(
            of: #"\s*\(\d+\s*g\)"#,
            with: "",
            options: .regularExpression
        )
    }

    // MARK: Rows

    private func mealLibraryRow(_ row: QuickMealDisplayRow) -> some View {
        let profile = QuickLogNutritionProfile.from(meal: row.meal)
        let selection = session.selection(for: row.id)
        let meta = QuickFoodAccent.meta(for: row.id, isLight: palette.isLight)
        return HStack(spacing: 12) {
            QuickFoodCircularMealThumb(row: row, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.meal.isFoodProduct ? row.meal.title : row.meal.localizedShortTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)

                Text(row.meal.isFoodProduct ? row.meal.servingDescription : row.meal.localizedDisplaySubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
                    .lineLimit(1)

                QuickFoodCaloriePill(calories: row.meal.calories, accent: meta, style: .list)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            QuickAddQuantityControl(
                quantity: selection.effectivePortions(for: profile),
                isExpanded: selection.isExpanded,
                isSelected: selection.isSelected,
                accentColor: QuickFoodAccent.actionOrange,
                chrome: .softOutline,
                onPlusTap: { onMealPlus(row.meal) },
                onIncrement: { onMealIncrement(row.meal) },
                onDecrement: { onMealDecrement(row.meal) }
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 88)
        .quickSheetFloatingCard(
            cornerRadius: 18,
            fill: palette.isLight ? WeekFitLightTokens.surfaceCard : WeekFitTheme.cardBackground,
            stroke: palette.isLight ? Color.black.opacity(0.05) : WeekFitTheme.whiteOpacity(0.06),
            isLight: palette.isLight
        )
    }

    private func snackLibraryRow(_ row: QuickItemDisplayRow) -> some View {
        let profile = QuickLogNutritionProfile.from(item: row.item)
        let selection = session.selection(for: row.id)
        let meta = QuickFoodAccent.meta(for: row.id, isLight: palette.isLight)
        return HStack(spacing: 12) {
            QuickFoodCircularSnackThumb(row: row, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.item.localizedTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)

                Text(row.item.localizedSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
                    .lineLimit(1)

                QuickFoodCaloriePill(calories: row.item.calories, accent: meta, style: .list)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            QuickAddQuantityControl(
                quantity: selection.effectivePortions(for: profile),
                isExpanded: selection.isExpanded,
                isSelected: selection.isSelected,
                accentColor: QuickFoodAccent.actionOrange,
                chrome: .softOutline,
                onPlusTap: { onSnackPlus(row.item) },
                onIncrement: { onSnackIncrement(row.item) },
                onDecrement: { onSnackDecrement(row.item) }
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 88)
        .quickSheetFloatingCard(
            cornerRadius: 18,
            fill: palette.isLight ? WeekFitLightTokens.surfaceCard : WeekFitTheme.cardBackground,
            stroke: palette.isLight ? Color.black.opacity(0.05) : WeekFitTheme.whiteOpacity(0.06),
            isLight: palette.isLight
        )
    }

    // MARK: Chrome

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
    }

    private func allHeader(title: String) -> some View {
        HStack {
            sectionHeader(title)
            Spacer(minLength: 8)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                sortAscending.toggle()
            } label: {
                HStack(spacing: 4) {
                    Text(
                        WeekFitLocalizedString(
                            sortAscending ? "today.quickLog.sort.az" : "today.quickLog.sort.za"
                        )
                    )
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(foodAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var emptyMeals: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(foodAccent.opacity(0.7))
            Text(WeekFitLocalizedString("today.quickLog.empty.savedFood.title"))
                .font(QuickActionSheetDesign.Typography.emptyTitle)
                .foregroundStyle(WeekFitTheme.primaryText)
            Text(WeekFitLocalizedString("today.quickLog.empty.savedFood.message"))
                .font(QuickActionSheetDesign.Typography.emptyMessage)
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
            Button(action: onOpenMealsTab) {
                Text(WeekFitLocalizedString("today.quickLog.empty.savedFood.action"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(foodAccent))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var emptySnacks: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(QuickFoodAccent.green.opacity(0.7))
            Text(WeekFitLocalizedString("today.quickLog.empty.quickItems.title"))
                .font(QuickActionSheetDesign.Typography.emptyTitle)
            Text(WeekFitLocalizedString("today.quickLog.empty.quickItems.message"))
                .font(QuickActionSheetDesign.Typography.emptyMessage)
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Frequent card (Drinks Recommended layout)

private struct QuickFoodFrequentCard<Thumb: View>: View {
    let title: String
    let subtitle: String
    let calories: Int
    let badgeText: String
    let accent: Color
    let metaAccent: Color
    let selection: QuickLogSelection
    let displayQuantity: Double
    let onPlusTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    @ViewBuilder let thumb: () -> Thumb

    @Environment(\.weekFitPalette) private var palette

    private let cardWidth: CGFloat = 172
    private let cardHeight: CGFloat = 228
    private let cardRadius: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumb()
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .lineLimit(1)
                .padding(.top, 12)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
                    .lineLimit(1)
                    .padding(.top, 2)
            }

            Spacer(minLength: 8)

            HStack(alignment: .center, spacing: 6) {
                QuickFoodCaloriePill(calories: calories, accent: metaAccent, style: .frequent)
                    .fixedSize()

                Spacer(minLength: 2)

                QuickAddQuantityControl(
                    quantity: displayQuantity,
                    isExpanded: selection.isExpanded,
                    isSelected: selection.isSelected,
                    accentColor: QuickFoodAccent.actionOrange,
                    chrome: .solidFilled,
                    onPlusTap: onPlusTap,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement
                )
            }
        }
        .padding(14)
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: cardRadius, style: .continuous))
        .background {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            QuickFoodAccent.cardTop(for: accent, isLight: palette.isLight),
                            QuickFoodAccent.cardBottom(for: accent, isLight: palette.isLight)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                        .fill(
                            palette.isLight
                                ? Color.white.opacity(0.22)
                                : WeekFitTheme.cardBackground.opacity(0.55)
                        )
                }
                .shadow(
                    color: QuickSheetChrome.cardShadowColor(isLight: palette.isLight),
                    radius: QuickSheetChrome.cardShadowRadius,
                    y: QuickSheetChrome.cardShadowY
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .strokeBorder(
                    palette.isLight
                        ? accent.opacity(0.14)
                        : WeekFitTheme.whiteOpacity(0.08),
                    lineWidth: 0.75
                )
        }
        .overlay(alignment: .topTrailing) {
            Text(badgeText)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.isLight ? accent : WeekFitTheme.secondaryText.opacity(0.88))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(
                            palette.isLight
                                ? Color.white.opacity(0.92)
                                : WeekFitTheme.whiteOpacity(0.08)
                        )
                }
                .overlay {
                    Capsule().strokeBorder(
                        palette.isLight
                            ? accent.opacity(0.28)
                            : WeekFitTheme.whiteOpacity(0.10),
                        lineWidth: 0.8
                    )
                }
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(10)
        }
    }
}

// MARK: - Calorie pill

private struct QuickFoodCaloriePill: View {
    enum Style { case frequent, list }

    let calories: Int
    let accent: Color
    let style: Style

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)

            Text(QuickLogLocalizedNutrition.calories(calories))
                .font(.system(size: style == .frequent ? 12 : 11, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    style == .frequent
                        ? WeekFitTheme.secondaryText.opacity(0.78)
                        : (palette.isLight ? WeekFitTheme.secondaryText.opacity(0.78) : accent)
                )
        }
        .padding(.horizontal, style == .list ? 8 : 0)
        .padding(.vertical, style == .list ? 4 : 0)
        .background {
            if style == .list {
                Capsule()
                    .fill(
                        palette.isLight
                            ? WeekFitLightTokens.internalTile
                            : WeekFitTheme.whiteOpacity(0.08)
                    )
            }
        }
    }
}

// MARK: - Circular thumbs

private struct QuickFoodCircularMealThumb: View {
    let row: QuickMealDisplayRow
    let size: CGFloat

    var body: some View {
        Group {
            if row.isFoodProduct {
                AsyncMealPhotoView(filename: row.localPhotoFilename) { image in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else if !row.sortedBuilderImageItems.isEmpty {
                BuiltMealPlateView(
                    items: row.sortedBuilderImageItems,
                    plateSize: size,
                    itemScale: 0.62,
                    offsetScale: 0.22,
                    plateOpacity: 0.42,
                    shadowOpacity: 0,
                    layoutMode: .compactPreview
                )
                // Crop plate rim so food fills more of the circle.
                .scaleEffect(1.22)
            } else if row.usesAssetImage {
                Image(row.meal.imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(WeekFitTheme.whiteOpacity(0.06))
            Image(systemName: "fork.knife")
                .font(.system(size: size * 0.28, weight: .semibold))
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.55))
        }
    }
}

private struct QuickFoodCircularSnackThumb: View {
    let row: QuickItemDisplayRow
    let size: CGFloat

    var body: some View {
        Group {
            if row.usesAssetImage {
                Image(row.item.imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(size * 0.10)
            } else {
                ZStack {
                    Circle().fill(WeekFitTheme.whiteOpacity(0.06))
                    Image(systemName: row.item.icon)
                        .font(.system(size: size * 0.28, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.55))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
