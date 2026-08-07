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
                // Neutral deep ivory — lifts pearl cards off the sheet.
                return WeekFitLightTokens.backgroundSecondary
            case .food:
                // Same depth, warmer stone (meal family).
                return SwiftUI.Color(red: 0.953, green: 0.937, blue: 0.906) // #F3EFE7
            case .drinks:
                // Same depth, cooler mist (hydration family).
                return SwiftUI.Color(red: 0.937, green: 0.945, blue: 0.941) // #EFF1F0
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

        /// Default quick-log sheet height — fits header + Recommended cards
        /// (Most Used + next) without peeking into Recently Added.
        static let sheetDetentFraction: CGFloat = 0.62
        /// Activity Start sits lower so Today Overview rings/labels stay readable.
        static let activitySheetDetentFraction: CGFloat = 0.54
    }

    enum Row {
        static let height: CGFloat = 76
        static let horizontalPadding: CGFloat = 12
        static let imageSize: CGFloat = 64
        static let imageCornerRadius: CGFloat = 15
        static let cardCornerRadius: CGFloat = 20
        static let actionButtonSize: CGFloat = 36
        static let actionExpandedWidth: CGFloat = 88
        static let contentSpacing: CGFloat = 12
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

    /// "Most used" / time-context capsules.
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
        isLight ? WeekFitLightTokens.surfaceCard : WeekFitTheme.cardBackground
    }

    static func frequentCardStroke(isLight: Bool) -> Color {
        isLight ? Color.black.opacity(0.04) : WeekFitTheme.whiteOpacity(0.06)
    }

    /// Soft lift for floating cards — low opacity so the silhouette stays rounded, not a dark slab.
    static func cardShadowColor(isLight: Bool) -> Color {
        isLight ? Color.black.opacity(0.10) : .clear
    }

    static let cardShadowRadius: CGFloat = 8
    static let cardShadowY: CGFloat = 3
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

/// Reserved anchor for future Coach recommendations inside quick-action sheets.
struct QuickActionCoachRecommendationSlot: View {
    var body: some View {
        Color.clear
            .frame(height: 0)
            .accessibilityHidden(true)
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
