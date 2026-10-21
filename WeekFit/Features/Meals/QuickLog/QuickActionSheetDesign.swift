import SwiftUI

enum QuickActionSheetDesign {
    /// Light canvas variants for Today quick-action sheets.
    /// Dark keeps the standard theme background.
    enum Surface: Equatable {
        case activity
        case food
        case drinks

        @MainActor
        var background: SwiftUI.Color {
            // Prefer env-aligned store (synced every render by WeekFitPaletteEnvironmentSync).
            guard WeekFitPaletteStore.current.isLight else {
                return WeekFitPaletteStore.current.appScreenBackground
            }

            switch self {
            case .activity:
                // Neutral deep cream — lifts warm-white cards off the sheet.
                return WeekFitLightTokens.backgroundSecondary
            case .food:
                // Light warm stone — section hint without a muddy beige wash.
                return SwiftUI.Color(red: 0.965, green: 0.953, blue: 0.933) // #F6F3EE
            case .drinks:
                // Light cool mist — hydration hint on a brighter neutral base.
                return SwiftUI.Color(red: 0.953, green: 0.961, blue: 0.957) // #F3F5F4
            }
        }
    }

    enum Color {
        @MainActor
        static var sheetBackground: SwiftUI.Color {
            Surface.activity.background
        }

        @MainActor
        static func sheetBackground(for surface: Surface) -> SwiftUI.Color {
            surface.background
        }
    }

    enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let listRowSpacing: CGFloat = 8
        static let listBottomPadding: CGFloat = 20
        static let sheetCornerRadius: CGFloat = 34
        static let segmentedTopPadding: CGFloat = 4
        static let segmentedBottomPadding: CGFloat = 8

        /// Default quick-log sheet height — header + frequent cards (+ badge row).
        static let sheetDetentFraction: CGFloat = 0.76
        /// Activity Start: tall enough for frequent tiles; Overview rings stay partly visible.
        static let activitySheetDetentFraction: CGFloat = 0.64
    }

    enum Row {
        static let height: CGFloat = 76
        static let horizontalPadding: CGFloat = 12
        static let imageSize: CGFloat = 64
        static let imageCornerRadius: CGFloat = 15
        static let cardCornerRadius: CGFloat = 20
        static let actionButtonSize: CGFloat = 36
        static let actionExpandedWidth: CGFloat = 102
        static let contentSpacing: CGFloat = 12
    }

    /// Shared recommended-card action treatment (Drinks / Food / Start Activity).
    enum RecommendedCard {
        static let padding: CGFloat = 16
        static let cornerRadius: CGFloat = 22
        static let width: CGFloat = 172
        /// Fits badge row + media + title/meta + 44pt action without clipping +.
        static let minHeight: CGFloat = 272
        static let interCardSpacing: CGFloat = 14
        static let actionInset: CGFloat = 4
        static let actionVisualSize: CGFloat = 30
        /// Minimum tap target for + / play on frequent cards.
        static let actionHitSize: CGFloat = 44
        static let metaSpacing: CGFloat = 6
        /// Reserved badge strip above media (not overlaid on photos).
        static let badgeRowMinHeight: CGFloat = 24
        /// Clear air between badge bottom and media slot.
        static let badgeToMedia: CGFloat = 12
        static let mediaHeight: CGFloat = 100
        static let mediaToTitle: CGFloat = 16
        /// Tight per-card lift — wide soft shadows merge into one slab under the pair.
        static let cardShadowRadius: CGFloat = 6
        static let cardShadowY: CGFloat = 2
    }

    enum Typography {
        static let headerTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let headerSubtitle = Font.system(size: 12, weight: .medium, design: .rounded)
        static let rowTitle = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let rowSubtitle = Font.system(size: 12, weight: .medium, design: .rounded)
        static let rowMeta = Font.system(size: 11, weight: .medium, design: .rounded)
        static let segmentLabel = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let segmentBadge = Font.system(size: 10, weight: .bold, design: .rounded)
        static let emptyTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
        static let emptyMessage = Font.system(size: 12, weight: .medium, design: .rounded)
        static let rowBadge = Font.system(size: 9, weight: .bold, design: .rounded)
    }

    enum SegmentedControl {
        static let height: CGFloat = 32
        static let containerPadding: CGFloat = 3
    }
}

/// Shared premium chrome for Food / Drinks / Activity quick sheets.
/// Color is scarce: gold for actions, quiet stone for meta, soft champagne for badges.
@MainActor
enum QuickSheetChrome {

    /// + / play / stepper — one brand action across all three sheets.
    static func action(isLight: Bool) -> Color {
        isLight ? WeekFitLightTokens.brandGold : WeekFitTheme.brandGold
    }

    /// Deeper gold for selected / emphasis states.
    static func actionEmphasis(isLight: Bool) -> Color {
        isLight ? WeekFitLightTokens.brandGoldDark : WeekFitTheme.brandGoldDeep
    }

    /// Icon on solid action fill.
    static func actionForeground(isLight: Bool) -> Color {
        isLight ? Color.white : Color(red: 0.12, green: 0.10, blue: 0.06)
    }

    /// kcal / duration — quiet meta, never competing with the CTA.
    static var meta: Color {
        WeekFitTheme.secondaryText
    }

    static func metaBadgeFill(isLight: Bool) -> Color {
        isLight ? WeekFitLightTokens.internalTile : WeekFitTheme.whiteOpacity(0.08)
    }

    /// Legacy context badge colors — prefer `QuickSheetPhotoSafeBadge` on photo cards.
    static func contextBadgeForeground(isLight: Bool) -> Color {
        isLight ? WeekFitLightTokens.brandGoldDark : WeekFitTheme.brandGold.opacity(0.92)
    }

    static func contextBadgeFill(isLight: Bool) -> Color {
        isLight
            ? WeekFitLightTokens.tabActiveCapsule.opacity(0.78)
            : WeekFitTheme.brandGold.opacity(0.16)
    }

    /// Neutral pearl frequent-card body (no category color wash).
    static func frequentCardFill(isLight: Bool) -> Color {
        isLight ? Color.white : WeekFitTheme.cardBackground
    }

    static func frequentCardStroke(isLight: Bool) -> Color {
        isLight ? Color.black.opacity(0.055) : WeekFitTheme.whiteOpacity(0.10)
    }

    /// Soft lift for floating cards — keep opacity low so paired cards don’t share one gray pillow.
    static func cardShadowColor(isLight: Bool) -> Color {
        isLight ? Color.black.opacity(0.06) : .clear
    }

    static var cardShadowRadius: CGFloat { QuickActionSheetDesign.RecommendedCard.cardShadowRadius }
    static var cardShadowY: CGFloat { QuickActionSheetDesign.RecommendedCard.cardShadowY }

    /// Recommended / Frequently Used tiles.
    /// Light: soft full-card tint + slightly stronger top wash so Water/Tea/Workout cards read apart.
    /// Dark: adaptive surface + quiet accent wash (no lifted white fills).
    @ViewBuilder
    static func elevatedTileBackground(
        cornerRadius: CGFloat,
        accent: Color,
        isLight: Bool
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(frequentCardFill(isLight: isLight))
            .overlay {
                // Full-card tint — keeps light cards from reading as identical pure white.
                shape.fill(
                    accent.opacity(isLight ? 0.10 : 0.08)
                )
            }
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: isLight
                            ? [
                                accent.opacity(0.16),
                                accent.opacity(0.05),
                                Color.clear
                            ]
                            : [
                                accent.opacity(0.18),
                                accent.opacity(0.06),
                                WeekFitTheme.whiteOpacity(0)
                            ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.62)
                    )
                )
            }
            .overlay {
                shape.strokeBorder(
                    frequentCardStroke(isLight: isLight),
                    lineWidth: 0.75
                )
            }
            .shadow(
                color: cardShadowColor(isLight: isLight),
                radius: cardShadowRadius,
                y: cardShadowY
            )
    }
}

extension View {
    /// Rounded floating card. Shadow is applied to the shape *after* content clip so corners stay soft
    /// (never `clipShape → compositingGroup → shadow`, which draws a rectangular slab).
    func quickSheetFloatingCard<S: ShapeStyle>(
        cornerRadius: CGFloat,
        fill: S,
        stroke: Color,
        isLight: Bool
    ) -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .shadow(
                        color: QuickSheetChrome.cardShadowColor(isLight: isLight),
                        radius: QuickSheetChrome.cardShadowRadius,
                        y: QuickSheetChrome.cardShadowY
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 0.75)
            }
    }
}

/// Bottom metadata + action row for recommended cards.
/// Metadata stays leading; the action is optically centered on that row and inset from the corner.
struct QuickRecommendedMetaActionRow<Meta: View, Action: View>: View {
    @ViewBuilder var meta: () -> Meta
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(alignment: .center, spacing: QuickActionSheetDesign.Row.contentSpacing) {
            meta()

            Spacer(minLength: 0)

            Color.clear
                .frame(
                    width: QuickActionSheetDesign.RecommendedCard.actionHitSize,
                    height: QuickActionSheetDesign.RecommendedCard.actionHitSize
                )
                .accessibilityHidden(true)
        }
        .overlay(alignment: .trailing) {
            action()
        }
        .padding(.trailing, QuickActionSheetDesign.RecommendedCard.actionInset)
    }
}

/// Circular glyph action (e.g. Start Activity play) matching recommended `+` visual weight.
struct QuickRecommendedCardCircleAction: View {
    let systemName: String
    let fill: Color
    var isLight: Bool
    var symbolSize: CGFloat = 12
    var opticalGlyphOffset: CGSize = .zero

    var body: some View {
        let visual = QuickActionSheetDesign.RecommendedCard.actionVisualSize
        let hit = QuickActionSheetDesign.RecommendedCard.actionHitSize

        Image(systemName: systemName)
            .font(.system(size: symbolSize, weight: .bold))
            .foregroundStyle(Color.white)
            .offset(opticalGlyphOffset)
            .frame(width: visual, height: visual)
            .background {
                Circle().fill(fill)
            }
            .shadow(
                color: isLight ? fill.opacity(0.18) : .clear,
                radius: 4,
                y: 2
            )
            .frame(width: hit, height: hit)
            .contentShape(Circle())
    }
}

/// Frequent-card context chip shared by Activity / Food / Drink.
/// Lives on its own row above media — never over faces/photos.
/// Light: near-white fill + dark-gray label + small accent glyph.
/// Dark: adaptive charcoal surface (not a lifted white chip).
struct QuickSheetPhotoSafeBadge: View {
    let title: String
    var systemImage: String? = nil
    var accent: Color = WeekFitTheme.brandGold
    /// Outer inset when overlaid; prefer `0` when the badge sits in a dedicated row.
    var padding: CGFloat = 0

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let darkChipFill = Color(red: 0.16, green: 0.17, blue: 0.19)
    private static let lightLabel = Color(red: 0.28, green: 0.29, blue: 0.31)

    private var allowsWrap: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(accent.opacity(palette.isLight ? 0.85 : 0.92))
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    palette.isLight
                        ? Self.lightLabel
                        : Color.white.opacity(0.88)
                )
                .lineLimit(allowsWrap ? 2 : 1)
                .minimumScaleFactor(allowsWrap ? 1 : 0.85)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(
                    palette.isLight
                        ? Color.white.opacity(0.97)
                        : Self.darkChipFill
                )
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    palette.isLight
                        ? Color.black.opacity(0.05)
                        : Color.white.opacity(0.10),
                    lineWidth: 0.6
                )
        }
        .padding(padding)
        .accessibilityElement(children: .combine)
    }
}

/// Reserved anchor for future Coach recommendations inside quick-action sheets.
struct QuickActionCoachRecommendationSlot: View {
    var body: some View {
        Color.clear
            .frame(height: 0)
            .accessibilityHidden(true)
    }
}

/// Horizontal recommended/frequent row for Food / Drinks / Activity sheets.
/// Centers when cards fit the sheet width (Pro Max + 1–2 picks); scrolls when they don't.
struct QuickSheetHorizontalCarousel<Content: View>: View {
    var spacing: CGFloat = QuickActionSheetDesign.RecommendedCard.interCardSpacing
    var horizontalPadding: CGFloat = 18
    /// Just enough for per-card shadow — large padding left a gray band under the pair.
    var verticalPadding: CGFloat = 6
    @ViewBuilder var content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing) {
                content()
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .center)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    content()
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
        }
    }
}

struct QuickActionSheetSegment: Identifiable, Hashable {
    let id: String
    let title: String
    let badgeCount: Int
    let systemImage: String?

    init(id: String, title: String, badgeCount: Int = 0, systemImage: String? = nil) {
        self.id = id
        self.title = title
        self.badgeCount = badgeCount
        self.systemImage = systemImage
    }
}

struct QuickActionSheetSegmentedControl: View {
    let segments: [QuickActionSheetSegment]
    @Binding var selection: String
    var selectedAccent: Color? = nil

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            ForEach(segments) { segment in
                let isSelected = selection == segment.id

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selection = segment.id
                    }
                } label: {
                    HStack(spacing: 5) {
                        if let systemImage = segment.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 12, weight: .semibold))
                        }

                        Text(segment.title)
                            .font(QuickActionSheetDesign.Typography.segmentLabel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if segment.badgeCount > 0 {
                            Text("\(segment.badgeCount)")
                                .font(QuickActionSheetDesign.Typography.segmentBadge)
                                .foregroundStyle(selectedBadgeForeground(isSelected: isSelected))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule()
                                        .fill(selectedBadgeFill(isSelected: isSelected))
                                }
                        }
                    }
                    .foregroundStyle(selectedTitleForeground(isSelected: isSelected))
                    .frame(maxWidth: .infinity)
                    .frame(height: QuickActionSheetDesign.SegmentedControl.height)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: palette.isLight
                                            ? [
                                                Color.white.opacity(0.98),
                                                Color.white.opacity(0.88)
                                            ]
                                            : [
                                                WeekFitTheme.whiteOpacity(0.13),
                                                WeekFitTheme.whiteOpacity(0.07)
                                            ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            palette.isLight
                                                ? WeekFitLightTokens.shadowContact.opacity(0.08)
                                                : WeekFitTheme.whiteOpacity(0.10),
                                            lineWidth: 1
                                        )
                                }
                                .shadow(
                                    color: palette.isLight
                                        ? WeekFitLightTokens.shadowAmbient.opacity(0.08)
                                        : .clear,
                                    radius: 6,
                                    y: 2
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(QuickActionSheetDesign.SegmentedControl.containerPadding)
        .background {
            Capsule()
                .fill(palette.isLight
                      ? WeekFitLightTokens.internalTile
                      : WeekFitTheme.whiteOpacity(0.034))
        }
        .overlay {
            Capsule()
                .stroke(
                    palette.isLight
                        ? WeekFitLightTokens.shadowContact.opacity(0.08)
                        : WeekFitTheme.whiteOpacity(0.045),
                    lineWidth: 1
                )
        }
    }

    private func selectedTitleForeground(isSelected: Bool) -> Color {
        guard isSelected else { return WeekFitTheme.secondaryText.opacity(0.72) }
        if let selectedAccent {
            return selectedAccent
        }
        return palette.isLight ? WeekFitTheme.primaryText : .white.opacity(0.94)
    }

    private func selectedBadgeForeground(isSelected: Bool) -> Color {
        guard isSelected else { return WeekFitTheme.secondaryText.opacity(0.55) }
        if let selectedAccent {
            return selectedAccent.opacity(0.92)
        }
        return palette.isLight ? WeekFitTheme.primaryText.opacity(0.70) : .black.opacity(0.68)
    }

    private func selectedBadgeFill(isSelected: Bool) -> Color {
        if isSelected {
            if let selectedAccent {
                return selectedAccent.opacity(palette.isLight ? 0.14 : 0.22)
            }
            return palette.isLight
                ? WeekFitLightTokens.shadowContact.opacity(0.08)
                : .white.opacity(0.68)
        }
        return palette.isLight
            ? WeekFitLightTokens.shadowContact.opacity(0.05)
            : .white.opacity(0.06)
    }
}
