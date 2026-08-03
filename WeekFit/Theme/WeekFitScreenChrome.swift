import SwiftUI

// MARK: - Screen layout (shared by Today / Coach / Meals / Plan)

enum WeekFitScreenLayout {
    /// Outer content margin — unified across main tabs.
    static let horizontalPadding: CGFloat = 20
    static let topPaddingLarge: CGFloat = 14
    static let topPaddingSmall: CGFloat = 6
    static let rootSpacing: CGFloat = 12
    /// Gap under the screen header before first content.
    static let headerBottomSpacing: CGFloat = 22
    /// Floating tab bar height plus breathing room for scroll content.
    static let tabBarClearance: CGFloat = 88

    static var topPadding: CGFloat {
        UIScreen.main.bounds.height > 800 ? topPaddingLarge : topPaddingSmall
    }
}

// MARK: - Surface radii / padding

enum WeekFitSurface {
    /// Primary content cards — soft but precise (not inflated).
    static let primaryRadius: CGFloat = 24
    /// Compact rows (meals library, plan timeline).
    static let compactRadius: CGFloat = 18
    /// Internal icon wells / chips.
    static let iconWellRadius: CGFloat = 14
    /// Soft leading accent indicator (not a dominant rail).
    static let accentIndicatorWidth: CGFloat = 3
    static let primaryPadding: CGFloat = 22
    static let compactHorizontalPadding: CGFloat = 16
}

// MARK: - Typography

enum WeekFitType {
    static let screenTitle = Font.system(size: 32, weight: .bold)
    static let screenSubtitle = Font.system(size: 16, weight: .regular)
    static let sectionTitle = Font.system(size: 24, weight: .bold)
    static let cardTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular)
    static let secondary = Font.system(size: 15, weight: .regular)
    static let eyebrow = Font.system(size: 13, weight: .semibold)
}

extension View {
    func weekFitScreenTitle() -> some View {
        modifier(WeekFitScreenTitleModifier())
    }

    func weekFitScreenSubtitle() -> some View {
        modifier(WeekFitScreenSubtitleModifier())
    }

    func weekFitSectionEyebrow() -> some View {
        font(WeekFitType.eyebrow)
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(WeekFitTheme.secondaryText)
    }

    func weekFitCardTitleStyle() -> some View {
        font(WeekFitType.cardTitle)
            .foregroundStyle(WeekFitTheme.primaryText)
    }

    func weekFitBodyStyle() -> some View {
        font(WeekFitType.body)
            .foregroundStyle(WeekFitTheme.primaryText)
    }

    func weekFitSecondaryStyle() -> some View {
        font(WeekFitType.secondary)
            .foregroundStyle(WeekFitTheme.secondaryText)
    }

    /// Shared tab canvas — one continuous `appScreenBackground` + optional ambient wash.
    /// Never paints a secondary content well; cards sit directly on the root canvas.
    func weekFitScreenCanvas(ambient: WeekFitScreenAmbient = .none) -> some View {
        modifier(WeekFitScreenCanvasModifier(ambient: ambient))
    }

    /// Kill UIKit List/ScrollView chrome and paint the shared root canvas
    /// through the full scroll viewport (not only the laid-out content size).
    func weekFitTransparentScrollBackground() -> some View {
        modifier(WeekFitTransparentScrollBackgroundModifier())
    }

    /// Today-class primary card.
    func weekFitPrimaryCard(
        accent: Color? = nil,
        featured: Bool = false,
        cornerRadius: CGFloat = WeekFitSurface.primaryRadius
    ) -> some View {
        weekFitPremiumCard(
            emphasis: featured ? .elevated : .standard,
            accent: accent,
            cornerRadius: cornerRadius
        )
    }

    /// Meals / Plan compact row card.
    func weekFitCompactRowCard(
        accent: Color? = nil,
        cornerRadius: CGFloat = WeekFitSurface.compactRadius
    ) -> some View {
        weekFitPremiumCard(
            emphasis: .compact,
            accent: accent,
            cornerRadius: cornerRadius
        )
    }
}

enum WeekFitScreenAmbient: Equatable {
    case none
    case today
    case coach
    case meals
    case plan

    @MainActor
    var gradient: RadialGradient? {
        switch self {
        case .none: return nil
        case .today: return WeekFitTheme.todayAmbient
        case .coach: return WeekFitTheme.coachAmbient
        case .meals: return WeekFitTheme.mealsAmbient
        case .plan: return WeekFitTheme.planAmbient
        }
    }
}

private struct WeekFitScreenTitleModifier: ViewModifier {
    @Environment(\.weekFitPalette) private var palette

    func body(content: Content) -> some View {
        content
            .font(WeekFitType.screenTitle)
            .foregroundStyle(palette.textPrimary)
            .tracking(-0.55)
            .lineLimit(1)
            .minimumScaleFactor(0.88)
    }
}

private struct WeekFitScreenSubtitleModifier: ViewModifier {
    @Environment(\.weekFitPalette) private var palette

    func body(content: Content) -> some View {
        content
            .font(WeekFitType.screenSubtitle)
            .foregroundStyle(palette.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
    }
}

private struct WeekFitScreenCanvasModifier: ViewModifier {
    let ambient: WeekFitScreenAmbient
    @Environment(\.weekFitPalette) private var palette

    func body(content: Content) -> some View {
        ZStack {
            palette.appScreenBackground
                .ignoresSafeArea()

            if let gradient = ambient.gradient {
                gradient
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            content
        }
    }
}

private struct WeekFitTransparentScrollBackgroundModifier: ViewModifier {
    @Environment(\.weekFitPalette) private var palette

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background {
                palette.appScreenBackground
                    .ignoresSafeArea(edges: .bottom)
            }
    }
}
