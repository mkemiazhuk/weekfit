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
    /// Floating tab bar occupied height + breathing room for scroll content.
    /// Bar 52 + bottom pad 10 + gap so the last card clears the pill fully.
    static let tabBarClearance: CGFloat = 104

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
//
/// Canonical semantic type roles (Dynamic Type). Approximate default sizes:
/// screenTitle ~34, cardTitle ~20, compactCardTitle ~17–18, body ~17, primaryMetric ~22,
/// heroMetric ~53/43, activeTimer ~28–32, secondary ~15, sectionLabel ~13–14, button ~17.
/// Prefer these over fixed `system(size:)` call sites.
///
/// Tab roots (Today / Coach / Meals / Plan) are content-first: they do **not** require
/// `screenTitle`. Keep `screenTitle` for push/detail screens and other titled surfaces.
enum WeekFitType {
    /// Screen title — largeTitle / ~34 bold. Not required on main tab roots.
    static let screenTitle = Font.largeTitle.weight(.bold)
    /// Supporting line under a screen title.
    static let screenSubtitle = Font.body
    /// Legacy alias for mid-level section heads (Coach etc.).
    static let sectionTitle = Font.title2.weight(.bold)
    /// Card / activity name — title3 / ~20 semibold.
    static let cardTitle = Font.title3.weight(.semibold)
    /// Quieter card title for Today supporting cards (Up Next / Focus) — body / ~17–18 semibold.
    /// Keeps overview metrics as the stronger numeric anchors without shrinking global `cardTitle`.
    static let compactCardTitle = Font.body.weight(.semibold)
    /// Primary body — ~17 regular.
    static let body = Font.body
    /// Primary metric (rings, scores) — title2 / ~22 semibold.
    static let primaryMetric = Font.title2.weight(.semibold)
    /// Evening / day-hero metric bases for `@ScaledMetric(relativeTo: .largeTitle)`.
    /// Regular ~53; compact (accessibility Dynamic Type) ~43.
    static let heroMetricBase: CGFloat = 53
    static let heroMetricCompactBase: CGFloat = 43
    /// Unit label beside `heroMetric` — title3 / ~20 medium.
    static let heroMetricUnit = Font.title3.weight(.medium)
    /// Signal / secondary hero value — title3 / ~20 semibold.
    static let heroMetricSignal = Font.title3.weight(.semibold)
    /// Live session timer — title / ~28 semibold, monospaced digits.
    static let activeTimer = Font.title.weight(.semibold)
    /// Secondary / supporting — subheadline / ~15.
    static let secondary = Font.subheadline
    /// Section label / eyebrow — footnote / ~13 medium (sentence case at call sites).
    static let sectionLabel = Font.footnote.weight(.medium)
    /// Alias for sectionLabel (existing call sites).
    static let eyebrow = sectionLabel
    /// Quick-action primary label — callout / ~16 medium.
    static let quickActionLabel = Font.callout.weight(.medium)
    /// Quick-action supporting label — subheadline / ~15 regular.
    static let quickActionSupport = Font.subheadline
    /// Button label — body / ~17 semibold.
    static let button = Font.body.weight(.semibold)
    /// Compact meta (time pills, captions) — caption / ~12.
    static let caption = Font.caption.weight(.medium)
    /// Emphasized caption meta.
    static let captionEmphasized = Font.caption.weight(.semibold)

    /// Scaled hero metric font from `heroMetricBase` / `heroMetricCompactBase`.
    static func heroMetric(compact: Bool = false) -> Font {
        .system(
            size: compact ? heroMetricCompactBase : heroMetricBase,
            weight: .bold,
            design: .rounded
        )
    }
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

    /// Kill UIKit List/ScrollView chrome.
    /// - `fillsCanvas: true` (default) — paint shared ivory/OLED under the scroll (Coach / Meals / Plan).
    /// - `fillsCanvas: false` — leave transparent so a parent atmosphere (Today) shows through.
    /// Never walk the UIKit hierarchy from `UIViewRepresentable` — that hung launch.
    func weekFitTransparentScrollBackground(fillsCanvas: Bool = true) -> some View {
        modifier(WeekFitTransparentScrollBackgroundModifier(fillsCanvas: fillsCanvas))
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
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
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
    var fillsCanvas: Bool = true
    @Environment(\.weekFitPalette) private var palette

    func body(content: Content) -> some View {
        // SwiftUI only. Never attach UIViewRepresentable that walks UIScrollView
        // ancestors/siblings from updateUIView — that hung launch on device.
        Group {
            if fillsCanvas {
                content
                    .scrollContentBackground(.hidden)
                    .background {
                        palette.appScreenBackground
                            .ignoresSafeArea(edges: .bottom)
                    }
            } else {
                content
                    .scrollContentBackground(.hidden)
            }
        }
    }
}
