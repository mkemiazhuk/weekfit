import SwiftUI

// MARK: - Accent

enum QuickDrinkAccent {
    static let hydration = Color(red: 0.29, green: 0.56, blue: 0.92)
    static let coffee = Color(red: 0.86, green: 0.55, blue: 0.30)
    static let tea = Color(red: 0.42, green: 0.62, blue: 0.48)
    static let juice = Color(red: 0.92, green: 0.58, blue: 0.28)
    static let milk = Color(red: 0.64, green: 0.66, blue: 0.76)
    /// List / CTA circles — cool hydration blue (matches drop icon family).
    static let listAction = hydration

    static func color(for item: QuickItem, isLight: Bool) -> Color {
        let id = item.id.lowercased()
        if id.contains("water") { return hydration }
        if id.contains("espresso") || id.contains("coffee") || id.contains("latte") { return coffee }
        if id.contains("tea") {
            return isLight ? tea : Color(red: 0.78, green: 0.62, blue: 0.42)
        }
        if id.contains("juice") { return juice }
        if id.contains("milk") || id.contains("kefir") || id.contains("shake") { return milk }
        return hydration
    }

    /// CTA circles — always hydration blue (not per-drink orange/gold).
    static func action(for _: QuickItem, isLight _: Bool) -> Color {
        listAction
    }

    static func meta(for item: QuickItem, isLight: Bool) -> Color {
        isLight ? color(for: item, isLight: true) : QuickSheetChrome.meta
    }

    static func metaSymbol(for item: QuickItem) -> String {
        let id = item.id.lowercased()
        if id.contains("water") { return "drop.fill" }
        if id.contains("tea") { return "leaf.fill" }
        if id.contains("juice") { return "sun.max.fill" }
        if id.contains("milk") || id.contains("kefir") { return "cup.and.saucer.fill" }
        return "flame.fill"
    }

    static func recommendedTop(for item: QuickItem, isLight: Bool) -> Color {
        guard isLight else { return WeekFitTheme.whiteOpacity(0.06) }
        return color(for: item, isLight: true).opacity(0.22)
    }

    static func recommendedBottom(for item: QuickItem, isLight: Bool) -> Color {
        guard isLight else { return WeekFitTheme.whiteOpacity(0.02) }
        return color(for: item, isLight: true).opacity(0.08)
    }
}

// MARK: - Design

enum QuickDrinkLogDesign {
    enum Layout {
        static let horizontalPadding: CGFloat = 18
        static let sectionSpacing: CGFloat = 22
        static let sectionTitleBottom: CGFloat = 12
        static let recommendedCardWidth: CGFloat = 172
        static let recommendedCardHeight: CGFloat = 228
        static let recommendedCardRadius: CGFloat = 26
        static let recentItemWidth: CGFloat = 74
        static let listCardRadius: CGFloat = 22
        static let listRowMinHeight: CGFloat = 92
        static let addButtonSize: CGFloat = 36
        static let greetingRadius: CGFloat = 22
    }

    enum Typography {
        static let sheetTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let sheetSubtitle = Font.system(size: 14, weight: .medium, design: .rounded)
        static let sectionTitle = Font.system(size: 11, weight: .semibold, design: .rounded)
        static let greetingTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let greetingSubtitle = Font.system(size: 13, weight: .medium, design: .rounded)
        static let recommendedTitle = Font.system(size: 16, weight: .bold, design: .rounded)
        static let recommendedSubtitle = Font.system(size: 12, weight: .medium, design: .rounded)
        static let recommendedCalories = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let badge = Font.system(size: 10, weight: .semibold, design: .rounded)
        static let recentTitle = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let recentCalories = Font.system(size: 11, weight: .medium, design: .rounded)
        static let listTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let listSubtitle = Font.system(size: 12, weight: .medium, design: .rounded)
        static let listMeta = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let sort = Font.system(size: 12, weight: .semibold, design: .rounded)
    }
}

struct QuickDrinkFrequentDisplayRow: Identifiable, Equatable {
    let row: QuickItemDisplayRow
    let badge: QuickDrinkFrequentComposer.Badge

    var id: String { row.id }
    var item: QuickItem { row.item }
}

// MARK: - Sheet

struct QuickDrinkLogSheet: View {
    let frequentRows: [QuickDrinkFrequentDisplayRow]
    let recentRows: [QuickItemDisplayRow]
    let allRows: [QuickItemDisplayRow]
    let session: QuickLogSessionStore
    let onClose: () -> Void
    let onPlusTap: (QuickItem) -> Void
    let onIncrement: (QuickItem) -> Void
    let onDecrement: (QuickItem) -> Void

    @Environment(\.weekFitPalette) private var palette
    @EnvironmentObject private var languageManager: AppLanguageManager

    @State private var revealGreeting = false
    @State private var revealFrequent = false
    @State private var revealRecent = false
    @State private var revealAll = false
    @State private var sortAscending = true

    private var showFrequent: Bool { !frequentRows.isEmpty }
    private var showRecent: Bool { !recentRows.isEmpty }

    private var sortedAllRows: [QuickItemDisplayRow] {
        allRows.sorted {
            sortAscending
                ? $0.item.localizedTitle.localizedCaseInsensitiveCompare($1.item.localizedTitle) == .orderedAscending
                : $0.item.localizedTitle.localizedCaseInsensitiveCompare($1.item.localizedTitle) == .orderedDescending
        }
    }

    var body: some View {
        let _ = languageManager.selectedLanguage

        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: QuickDrinkLogDesign.Layout.sectionSpacing) {
                    greetingCard
                        .opacity(revealGreeting ? 1 : 0)
                        .offset(y: revealGreeting ? 0 : 8)

                    if allRows.isEmpty {
                        emptyState
                    } else {
                        if showFrequent {
                            recommendedSection
                                .opacity(revealFrequent ? 1 : 0)
                                .offset(y: revealFrequent ? 0 : 10)
                        }

                        if showRecent {
                            recentSection
                                .opacity(revealRecent ? 1 : 0)
                                .offset(y: revealRecent ? 0 : 10)
                        }

                        allSection
                            .opacity(revealAll ? 1 : 0)
                            .offset(y: revealAll ? 0 : 12)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
        }
        .onAppear(perform: runEntranceAnimation)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(
                    palette.isLight
                        ? WeekFitLightTokens.shadowContact.opacity(0.16)
                        : Color.white.opacity(0.14)
                )
                .frame(width: 36, height: 3.5)
                .padding(.top, 8)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(WeekFitLocalizedString("today.quickActions.logDrinks"))
                        .font(QuickDrinkLogDesign.Typography.sheetTitle)
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .tracking(-0.4)

                    Text(WeekFitLocalizedString("today.quickLog.subtitle.drinks"))
                        .font(QuickDrinkLogDesign.Typography.sheetSubtitle)
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.72))
                }

                Spacer(minLength: 8)

                WeekFitCloseButton(size: .regular, playsHaptic: false, action: onClose)
            }
            .padding(.horizontal, QuickDrinkLogDesign.Layout.horizontalPadding)
            .padding(.bottom, 10)
        }
    }

    // MARK: Greeting

    private var greetingCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(QuickDrinkAccent.hydration.opacity(palette.isLight ? 0.14 : 0.22))
                    .frame(width: 42, height: 42)

                Image(systemName: "drop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(QuickDrinkAccent.hydration)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(greetingTitle)
                    .font(QuickDrinkLogDesign.Typography.greetingTitle)
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)

                Text(WeekFitLocalizedString("today.quickLog.drinks.greeting.subtitle"))
                    .font(QuickDrinkLogDesign.Typography.greetingSubtitle)
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.72))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(QuickSheetChrome.action(isLight: palette.isLight))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .quickSheetFloatingCard(
            cornerRadius: QuickDrinkLogDesign.Layout.greetingRadius,
            fill: palette.isLight ? WeekFitLightTokens.surfaceCard : WeekFitTheme.cardBackground,
            stroke: palette.isLight ? Color.black.opacity(0.04) : WeekFitTheme.whiteOpacity(0.06),
            isLight: palette.isLight
        )
        .padding(.horizontal, QuickDrinkLogDesign.Layout.horizontalPadding)
    }

    private var greetingTitle: String {
        let period = WeekFitLocalDayPeriod.from()
        let greetingKey: String
        switch period {
        case .morning: greetingKey = "today.greeting.morning"
        case .afternoon: greetingKey = "today.greeting.afternoon"
        case .evening: greetingKey = "today.greeting.evening"
        case .night: greetingKey = "today.greeting.night"
        }
        let greeting = WeekFitLocalizedString(greetingKey)
        let name = ProfileService.resolvedGivenName()
        guard !name.isEmpty else { return greeting }
        return String(format: WeekFitLocalizedString("today.quickLog.drinks.greeting.named"), greeting, name)
    }

    // MARK: Recommended

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: QuickDrinkLogDesign.Layout.sectionTitleBottom) {
            sectionTitle(WeekFitLocalizedString("today.quickLog.section.recommendedForYou"))
                .padding(.horizontal, QuickDrinkLogDesign.Layout.horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(frequentRows) { frequent in
                        let profile = QuickLogNutritionProfile.from(item: frequent.item)
                        let selection = session.selection(for: frequent.id)
                        QuickDrinkRecommendedCard(
                            row: frequent.row,
                            badge: WeekFitLocalizedString(frequent.badge.localizationKey),
                            selection: selection,
                            displayQuantity: selection.effectivePortions(for: profile),
                            onPlusTap: { onPlusTap(frequent.item) },
                            onIncrement: { onIncrement(frequent.item) },
                            onDecrement: { onDecrement(frequent.item) }
                        )
                    }
                }
                .padding(.horizontal, QuickDrinkLogDesign.Layout.horizontalPadding)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: QuickDrinkLogDesign.Layout.sectionTitleBottom) {
            sectionTitle(WeekFitLocalizedString("today.quickLog.section.recentlyAdded"))
                .padding(.horizontal, QuickDrinkLogDesign.Layout.horizontalPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(recentRows) { row in
                        QuickDrinkRecentCircleItem(row: row) {
                            onPlusTap(row.item)
                        }
                    }
                }
                .padding(.horizontal, QuickDrinkLogDesign.Layout.horizontalPadding)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: All

    private var allSection: some View {
        VStack(alignment: .leading, spacing: QuickDrinkLogDesign.Layout.sectionTitleBottom) {
            HStack(alignment: .center) {
                sectionTitle(WeekFitLocalizedString("today.quickLog.section.allDrinks"))

                Spacer(minLength: 8)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    sortAscending.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Text(
                            WeekFitLocalizedString(
                                sortAscending
                                    ? "today.quickLog.sort.az"
                                    : "today.quickLog.sort.za"
                            )
                        )
                        .font(QuickDrinkLogDesign.Typography.sort)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.72))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, QuickDrinkLogDesign.Layout.horizontalPadding)

            LazyVStack(spacing: 10) {
                ForEach(sortedAllRows) { row in
                    let profile = QuickLogNutritionProfile.from(item: row.item)
                    let selection = session.selection(for: row.id)
                    QuickDrinkLibraryCard(
                        row: row,
                        selection: selection,
                        displayQuantity: selection.effectivePortions(for: profile),
                        onPlusTap: { onPlusTap(row.item) },
                        onIncrement: { onIncrement(row.item) },
                        onDecrement: { onDecrement(row.item) }
                    )
                }
            }
            .padding(.horizontal, QuickDrinkLogDesign.Layout.horizontalPadding)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(QuickDrinkAccent.hydration.opacity(0.55))

            Text(WeekFitLocalizedString("today.quickLog.empty.drinks.title"))
                .font(QuickActionSheetDesign.Typography.emptyTitle)
                .foregroundStyle(WeekFitTheme.primaryText)

            Text(WeekFitLocalizedString("today.quickLog.empty.quickItems.message"))
                .font(QuickActionSheetDesign.Typography.emptyMessage)
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, QuickDrinkLogDesign.Layout.horizontalPadding)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(QuickDrinkLogDesign.Typography.sectionTitle)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
    }

    private func runEntranceAnimation() {
        revealGreeting = false
        revealFrequent = false
        revealRecent = false
        revealAll = false

        let spring = Animation.spring(response: 0.42, dampingFraction: 0.86)
        withAnimation(spring.delay(0.01)) { revealGreeting = true }

        if showFrequent {
            withAnimation(spring.delay(0.06)) { revealFrequent = true }
            if showRecent {
                withAnimation(spring.delay(0.12)) { revealRecent = true }
                withAnimation(spring.delay(0.18)) { revealAll = true }
            } else {
                withAnimation(spring.delay(0.12)) { revealAll = true }
            }
        } else if showRecent {
            withAnimation(spring.delay(0.06)) { revealRecent = true }
            withAnimation(spring.delay(0.12)) { revealAll = true }
        } else {
            withAnimation(spring.delay(0.06)) { revealAll = true }
        }
    }
}

// MARK: - Drink image helpers

private enum QuickDrinkPhotoRole {
    /// Large hero cutouts on Recommended cards.
    case recommended
    /// Compact circular thumbs in Recently Added.
    case recent
    /// Medium cutouts on All Drinks rows.
    case library

    var size: CGFloat {
        switch self {
        case .recommended: return 108
        case .recent: return 56
        case .library: return 68
        }
    }

    var contentScale: CGFloat {
        switch self {
        case .recommended: return 0.96
        case .recent: return 0.78
        case .library: return 0.90
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .recommended: return 22
        case .recent: return 0
        case .library: return 16
        }
    }
}

private struct QuickDrinkPhoto: View {
    let row: QuickItemDisplayRow
    let role: QuickDrinkPhotoRole
    var accent: Color

    @Environment(\.weekFitPalette) private var palette

    private var size: CGFloat { role.size }

    var body: some View {
        ZStack {
            if role == .recent {
                Circle()
                    .fill(palette.isLight ? Color.white : WeekFitTheme.cardBackground)
                    .shadow(
                        color: palette.isLight
                            ? WeekFitLightTokens.shadowAmbient.opacity(0.16)
                            : .clear,
                        radius: 5,
                        y: 2
                    )
            }

            drinkAsset
                .frame(
                    width: size * role.contentScale,
                    height: size * role.contentScale
                )
        }
        .frame(width: size, height: size)
        .modifier(QuickDrinkPhotoClip(role: role))
        .shadow(
            color: role == .recent
                ? .clear
                : (palette.isLight ? WeekFitLightTokens.shadowAmbient.opacity(0.14) : .clear),
            radius: role == .recommended ? 8 : 5,
            y: role == .recommended ? 4 : 2
        )
    }

    @ViewBuilder
    private var drinkAsset: some View {
        if row.usesAssetImage {
            Image(row.item.imageName)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        } else {
            Image(systemName: row.item.icon)
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(accent)
        }
    }
}

private struct QuickDrinkPhotoClip: ViewModifier {
    let role: QuickDrinkPhotoRole

    func body(content: Content) -> some View {
        switch role {
        case .recent:
            content.clipShape(Circle())
        case .recommended, .library:
            // Cutouts keep their natural alpha silhouette — no hard square crop.
            content
        }
    }
}

// MARK: - Recommended card

private struct QuickDrinkRecommendedCard: View {
    let row: QuickItemDisplayRow
    let badge: String?
    let selection: QuickLogSelection
    let displayQuantity: Double
    let onPlusTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private var tint: Color { QuickDrinkAccent.color(for: row.item, isLight: palette.isLight) }
    private var action: Color { QuickDrinkAccent.listAction }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QuickDrinkPhoto(
                row: row,
                role: .recommended,
                accent: tint
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.item.localizedTitle)
                .font(QuickDrinkLogDesign.Typography.recommendedTitle)
                .foregroundStyle(WeekFitTheme.primaryText)
                .lineLimit(1)
                .padding(.top, 12)

            Text(row.item.localizedSubtitle)
                .font(QuickDrinkLogDesign.Typography.recommendedSubtitle)
                .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.68))
                .lineLimit(1)
                .padding(.top, 2)

            Spacer(minLength: 8)

            HStack(alignment: .center, spacing: 6) {
                Image(systemName: QuickDrinkAccent.metaSymbol(for: row.item))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)

                Text(QuickLogLocalizedNutrition.calories(row.item.calories))
                    .font(QuickDrinkLogDesign.Typography.recommendedCalories)
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.78))
                    .lineLimit(1)

                Spacer(minLength: 2)

                QuickAddQuantityControl(
                    quantity: displayQuantity,
                    isExpanded: selection.isExpanded,
                    isSelected: selection.isSelected,
                    accentColor: action,
                    chrome: .solidFilled,
                    onPlusTap: onPlusTap,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement
                )
            }
        }
        .padding(14)
        .frame(
            width: QuickDrinkLogDesign.Layout.recommendedCardWidth,
            height: QuickDrinkLogDesign.Layout.recommendedCardHeight,
            alignment: .topLeading
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: QuickDrinkLogDesign.Layout.recommendedCardRadius,
                style: .continuous
            )
        )
        .background {
            RoundedRectangle(
                cornerRadius: QuickDrinkLogDesign.Layout.recommendedCardRadius,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        QuickDrinkAccent.recommendedTop(for: row.item, isLight: palette.isLight),
                        QuickDrinkAccent.recommendedBottom(for: row.item, isLight: palette.isLight)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: QuickDrinkLogDesign.Layout.recommendedCardRadius,
                    style: .continuous
                )
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
            RoundedRectangle(
                cornerRadius: QuickDrinkLogDesign.Layout.recommendedCardRadius,
                style: .continuous
            )
            .strokeBorder(
                palette.isLight
                    ? tint.opacity(0.14)
                    : WeekFitTheme.whiteOpacity(0.08),
                lineWidth: 0.75
            )
        }
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(QuickDrinkLogDesign.Typography.badge)
                    .foregroundStyle(palette.isLight ? tint : WeekFitTheme.secondaryText.opacity(0.88))
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
                        Capsule()
                            .strokeBorder(
                                palette.isLight
                                    ? tint.opacity(0.28)
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
}

// MARK: - Recent circle

private struct QuickDrinkRecentCircleItem: View {
    let row: QuickItemDisplayRow
    let onTap: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private var accent: Color { QuickDrinkAccent.color(for: row.item, isLight: palette.isLight) }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                QuickDrinkPhoto(
                    row: row,
                    role: .recent,
                    accent: accent
                )

                VStack(spacing: 2) {
                    Text(row.item.localizedTitle)
                        .font(QuickDrinkLogDesign.Typography.recentTitle)
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(QuickLogLocalizedNutrition.calories(row.item.calories))
                        .font(QuickDrinkLogDesign.Typography.recentCalories)
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
                        .lineLimit(1)
                }
            }
            .frame(width: QuickDrinkLogDesign.Layout.recentItemWidth)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Library card

private struct QuickDrinkLibraryCard: View {
    let row: QuickItemDisplayRow
    let selection: QuickLogSelection
    let displayQuantity: Double
    let onPlusTap: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private var accent: Color { QuickDrinkAccent.color(for: row.item, isLight: palette.isLight) }
    private var action: Color { QuickDrinkAccent.listAction }

    var body: some View {
        HStack(spacing: 14) {
            QuickDrinkPhoto(
                row: row,
                role: .library,
                accent: accent
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(row.item.localizedTitle)
                    .font(QuickDrinkLogDesign.Typography.listTitle)
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)

                Text(row.item.localizedSubtitle)
                    .font(QuickDrinkLogDesign.Typography.listSubtitle)
                    .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.58))
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(action.opacity(0.85))

                    Text(QuickLogLocalizedNutrition.calories(row.item.calories))
                        .font(QuickDrinkLogDesign.Typography.listMeta)
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.78))
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            QuickAddQuantityControl(
                quantity: displayQuantity,
                isExpanded: selection.isExpanded,
                isSelected: selection.isSelected,
                accentColor: action,
                chrome: .softOutline,
                onPlusTap: onPlusTap,
                onIncrement: onIncrement,
                onDecrement: onDecrement
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: QuickDrinkLogDesign.Layout.listRowMinHeight)
        .quickSheetFloatingCard(
            cornerRadius: QuickDrinkLogDesign.Layout.listCardRadius,
            fill: palette.isLight ? WeekFitLightTokens.surfaceCard : WeekFitTheme.cardBackground,
            stroke: palette.isLight ? Color.black.opacity(0.04) : WeekFitTheme.whiteOpacity(0.06),
            isLight: palette.isLight
        )
    }
}
