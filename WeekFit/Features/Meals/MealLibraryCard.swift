import SwiftUI
import UIKit

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
        case .meal: return "meals.library.section.savedMeals"
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
    static let cornerRadius: CGFloat = 18
    static let gridSpacing: CGFloat = 12
    /// Recommendation / compact-row plate diameter.
    static let thumbSize: CGFloat = 76
    /// Compact media band (shorter than the original square tile).
    static let mediaAspect: CGFloat = 1.38
    /// Plate diameter as a fraction of the media band’s short side.
    static let plateFill: CGFloat = 0.86
    static let horizontalPadding: CGFloat = 12
    static let textTopPadding: CGFloat = 10
    static let textBottomPadding: CGFloat = 11
    /// Title ↔ calories ↔ protein grouping.
    static let textBlockSpacing: CGFloat = 7
    static let menuSize: CGFloat = 28
    static let titleSize: CGFloat = 15
    static let metaSize: CGFloat = 13
    /// Preview count on Meals tab before “See all”.
    static let previewLimit: Int = 6

    /// Cool navy-charcoal surfaces shared by recommendation, cards, and search.
    enum Chrome {
        static func surface(isLight: Bool) -> Color {
            if isLight { return WeekFitLightTokens.surfaceCard }
            // Slightly lighter than OLED canvas, cool navy undertone.
            return Color(red: 0.078, green: 0.086, blue: 0.110)
        }

        static func border(isLight: Bool) -> Color {
            if isLight {
                return WeekFitLightTokens.cardBorder.opacity(WeekFitLightTokens.cardBorderStrokeOpacity)
            }
            return Color.white.opacity(0.08)
        }
    }

    enum ExpandSheet {
        static let sheetTopPadding: CGFloat = 18
        static let titleToSearch: CGFloat = 10
        static let searchToContent: CGFloat = 8
        static let headerMinHeight: CGFloat = 36
        static let headerTopPadding: CGFloat = 6
        static let headerBottomPadding: CGFloat = 4
        static let headerToCards: CGFloat = 6
        static let sectionBottom: CGFloat = 8
        static let scrollBottom: CGFloat = 28
    }
}

// MARK: - Shared plate + food (recommendation + grid)

/// Matte graphite plate with ingredient composition.
/// Shared by recommendation thumbs and library grid cards.
struct MealLibraryPlateView: View {
    let meal: Meals
    var diameter: CGFloat

    @Environment(\.weekFitPalette) private var palette

    private var textSecondary: Color { WeekFitTheme.secondaryText }

    /// Ingredient composition targets ~70% of plate diameter (65–75% band).
    private var foodPlateSize: CGFloat { diameter * 0.92 }
    private var itemScale: CGFloat { 0.74 }
    private var offsetScale: CGFloat { 0.32 }

    var body: some View {
        ZStack {
            graphitePlate

            if meal.isFoodProduct {
                AsyncCustomFoodVisualView(
                    filename: meal.displayPhotoFilename,
                    placeholderInitial: meal.placeholderInitial,
                    size: diameter * 0.72,
                    imageScale: 0.88,
                    fallbackSystemImage: "takeoutbag.and.cup.and.straw.fill"
                )
            } else if let items = meal.builderImageItems, !items.isEmpty {
                BuiltMealPlateView(
                    items: items,
                    plateSize: foodPlateSize,
                    itemScale: itemScale,
                    offsetScale: offsetScale,
                    plateOpacity: 0,
                    shadowOpacity: palette.isLight ? 0.10 : 0.14,
                    layoutMode: .preview,
                    showsPlateChrome: false
                )
            } else if !meal.imageName.isEmpty,
                      FoodImageQualityValidator.isDisplayableAsset(named: meal.imageName) {
                PremiumAssetImage(
                    imageName: meal.imageName,
                    style: .mealCard,
                    accentColor: textSecondary,
                    fallbackSystemName: "fork.knife",
                    size: diameter * 0.70,
                    cornerRadius: diameter * 0.12
                )
            } else {
                Image(systemName: meal.isFoodProduct ? "carrot.fill" : "fork.knife")
                    .font(.system(size: diameter * 0.26, weight: .semibold))
                    .foregroundStyle(textSecondary.opacity(0.72))
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    private var graphitePlate: some View {
        let fill = palette.isLight
            ? Color(red: 0.91, green: 0.91, blue: 0.925)
            : Color(red: 0.145, green: 0.155, blue: 0.185)
        let rim = palette.isLight
            ? Color.black.opacity(0.10)
            : Color.white.opacity(0.12)

        return ZStack {
            Circle()
                .fill(fill)
                .shadow(
                    color: Color.black.opacity(palette.isLight ? 0.08 : 0.32),
                    radius: palette.isLight ? 4 : 6,
                    y: palette.isLight ? 2 : 3
                )

            // Soft inner shadow — single quiet edge, no concentric rings.
            Circle()
                .strokeBorder(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(palette.isLight ? 0.10 : 0.28)
                        ],
                        center: .center,
                        startRadius: diameter * 0.28,
                        endRadius: diameter * 0.50
                    ),
                    lineWidth: max(5, diameter * 0.07)
                )

            Circle()
                .strokeBorder(rim, lineWidth: 1)
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }
}

/// Quiet Meals-library chrome — cool navy surface + one low-contrast border.
struct MealLibrarySurfaceModifier: ViewModifier {
    var cornerRadius: CGFloat = MealLibraryCardMetrics.cornerRadius

    @Environment(\.weekFitPalette) private var palette

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(MealLibraryCardMetrics.Chrome.surface(isLight: palette.isLight))
                    .shadow(
                        color: Color.black.opacity(palette.isLight ? 0.06 : 0.28),
                        radius: palette.isLight ? 6 : 10,
                        y: palette.isLight ? 2 : 4
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        MealLibraryCardMetrics.Chrome.border(isLight: palette.isLight),
                        lineWidth: 1
                    )
            }
    }
}

extension View {
    func mealLibrarySurface(cornerRadius: CGFloat = MealLibraryCardMetrics.cornerRadius) -> some View {
        modifier(MealLibrarySurfaceModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Shared thumbnail (recommendation / compact rows)

struct MealLibraryThumbnail: View {
    let meal: Meals
    var size: CGFloat = 54
    var cornerRadius: CGFloat = WeekFitSurface.iconWellRadius
    var isCircle: Bool = true

    var body: some View {
        Group {
            if isCircle {
                MealLibraryPlateView(meal: meal, diameter: size)
            } else {
                MealLibraryPlateView(meal: meal, diameter: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Media band (grid card)

enum MealLibraryMediaShape: Equatable {
    case cardTop(CGFloat)
}

/// Card media band hosting the shared plate composition on a continuous card surface.
struct MealLibraryMediaView: View {
    let meal: Meals
    var shape: MealLibraryMediaShape = .cardTop(MealLibraryCardMetrics.cornerRadius)

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let plateDiameter = side * MealLibraryCardMetrics.plateFill

            ZStack {
                // Continuous with charcoal-navy card — no contrasting image panel.
                Color.clear

                MealLibraryPlateView(meal: meal, diameter: plateDiameter)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .modifier(MealLibraryMediaClip(shape: shape))
        }
    }
}

private struct MealLibraryMediaClip: ViewModifier {
    let shape: MealLibraryMediaShape

    func body(content: Content) -> some View {
        switch shape {
        case .cardTop(let radius):
            content.clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: radius,
                    style: .continuous
                )
            )
        }
    }
}

// MARK: - Grid card (library)

struct MealLibraryGridCard: View {
    let meal: Meals
    var kind: MealLibraryRowKind = .meal
    var isHighlighted: Bool = false
    /// Kept for call-site compatibility; period glyphs are unused on this redesign.
    var showsPeriodMark: Bool = false
    var onEdit: (() -> Void)? = nil
    var onLog: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var highlightStrokeOpacity: Double = 0

    private var textPrimary: Color { WeekFitTheme.primaryText }
    private var textSecondary: Color { WeekFitTheme.secondaryText }

    private var showsOverflowMenu: Bool {
        onEdit != nil || onLog != nil || onDelete != nil
    }

    private var titleLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 4 : 2
    }

    var body: some View {
        let _ = showsPeriodMark
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                MealLibraryMediaView(
                    meal: meal,
                    shape: .cardTop(MealLibraryCardMetrics.cornerRadius)
                )
                .aspectRatio(MealLibraryCardMetrics.mediaAspect, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()

                if showsOverflowMenu {
                    Menu {
                        if let onEdit {
                            Button(action: onEdit) {
                                Label(
                                    WeekFitLocalizedString("common.action.edit"),
                                    systemImage: "square.and.pencil"
                                )
                            }
                        }

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
                            .foregroundStyle(textSecondary.opacity(0.95))
                            .frame(
                                width: MealLibraryCardMetrics.menuSize,
                                height: MealLibraryCardMetrics.menuSize
                            )
                            .background {
                                Circle()
                                    .fill(MealLibraryCardMetrics.Chrome.surface(isLight: palette.isLight))
                                    .overlay {
                                        Circle()
                                            .strokeBorder(
                                                MealLibraryCardMetrics.Chrome.border(isLight: palette.isLight),
                                                lineWidth: 1
                                            )
                                    }
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44, alignment: .topTrailing)
                    .padding(.top, 2)
                    .padding(.trailing, 2)
                    .accessibilityLabel(WeekFitTrilingual("More", "Ещё", "更多"))
                }
            }

            VStack(alignment: .leading, spacing: MealLibraryCardMetrics.textBlockSpacing) {
                Text(meal.localizedDisplayTitle)
                    .font(.system(size: MealLibraryCardMetrics.titleSize, weight: .semibold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.18)
                    .multilineTextAlignment(.leading)
                    .lineLimit(titleLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Text(String(format: WeekFitLocalizedString("meals.value.kcalFormat"), meal.calories))
                    .font(.system(size: MealLibraryCardMetrics.metaSize, weight: .medium))
                    .foregroundStyle(textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)

                Text(String(format: WeekFitLocalizedString("meals.value.proteinGramsFormat"), meal.protein))
                    .font(.system(size: MealLibraryCardMetrics.metaSize, weight: .medium))
                    .foregroundStyle(textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.horizontal, MealLibraryCardMetrics.horizontalPadding)
            .padding(.top, MealLibraryCardMetrics.textTopPadding)
            .padding(.bottom, MealLibraryCardMetrics.textBottomPadding)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .mealLibrarySurface(cornerRadius: MealLibraryCardMetrics.cornerRadius)
        .overlay(highlightPulseOverlay)
        .scaleEffect((isPressed && !reduceMotion) ? 0.985 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isPressed)
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
        String(
            format: WeekFitLocalizedString("meals.library.cardAccessibilityFormat"),
            meal.localizedDisplayTitle,
            meal.calories,
            meal.protein
        )
    }

    private var highlightPulseOverlay: some View {
        RoundedRectangle(cornerRadius: MealLibraryCardMetrics.cornerRadius, style: .continuous)
            .stroke(WeekFitTheme.brandGold.opacity(highlightStrokeOpacity), lineWidth: 1.25)
            .allowsHitTesting(false)
    }

    private func runHighlightPulse() {
        guard !reduceMotion else {
            highlightStrokeOpacity = 0.35
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                highlightStrokeOpacity = 0
            }
            return
        }

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var highlightStrokeOpacity: Double = 0

    private var textPrimary: Color { WeekFitTheme.primaryText }
    private var textSecondary: Color { WeekFitTheme.secondaryText }
    private var accent: Color { WeekFitTheme.meal }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            textBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 8) {
                MealLibraryThumbnail(meal: meal, size: 54, isCircle: true)
                    .opacity(isPressed ? 0.92 : 1.0)
                    .scaleEffect((isPressed && !reduceMotion) ? 0.98 : 1.0)

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
        .scaleEffect((isPressed && !reduceMotion) ? 0.988 : 1.0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isPressed)
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
            format: WeekFitLocalizedString("meals.library.cardAccessibilityFormat"),
            meal.localizedDisplayTitle,
            meal.calories,
            meal.protein
        )
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isRecommended,
               let recommendationBadge,
               !recommendationBadge.isEmpty {
                MealLibraryRecommendationBadge(
                    title: recommendationBadge,
                    icon: recommendationIcon ?? "fork.knife"
                )
            }

            Text(meal.localizedDisplayTitle)
                .font(.system(size: 15.5, weight: .semibold))
                .foregroundStyle(textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(String(format: WeekFitLocalizedString("meals.value.kcalFormat"), meal.calories))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textSecondary)
                .monospacedDigit()
                .lineLimit(1)

            Text(String(format: WeekFitLocalizedString("meals.value.proteinGramsFormat"), meal.protein))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(textSecondary)
                .monospacedDigit()
                .lineLimit(1)
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
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
        guard !reduceMotion else {
            highlightStrokeOpacity = 0.35
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                highlightStrokeOpacity = 0
            }
            return
        }

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
                .foregroundStyle(WeekFitTheme.brandGold.opacity(0.85))

            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.15)
                .foregroundStyle(WeekFitTheme.brandGold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .frame(height: 18)
        .background {
            Capsule()
                .fill(WeekFitTheme.brandGold.opacity(0.12))
        }
    }
}

struct MealsLibrarySkeletonRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(MealLibraryCardMetrics.mediaAspect, contentMode: .fit)
            Color.clear
                .frame(height: 72)
        }
        .mealLibrarySurface(cornerRadius: MealLibraryCardMetrics.cornerRadius)
        .opacity(pulse ? 0.92 : 0.55)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
