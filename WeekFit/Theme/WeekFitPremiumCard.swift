import SwiftUI

/// Visual weight for WeekFit content cards. Prefer this over screen-local chrome.
enum WeekFitPremiumCardEmphasis: Equatable, Sendable {
    /// Normal content cards — quiet depth, soft border.
    case standard
    /// Primary interpretation / recommendation / overview surfaces.
    case elevated
    /// Semantic state cards — restrained accent wash + tinted edge.
    case accent
    /// Rows, compact utilities, planner items.
    case compact
}

struct WeekFitPremiumCardModifier: ViewModifier {

    var emphasis: WeekFitPremiumCardEmphasis = .standard
    var accent: Color? = nil
    var cornerRadius: CGFloat? = nil

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var resolvedRadius: CGFloat {
        if let cornerRadius { return cornerRadius }
        switch emphasis {
        case .standard, .elevated, .accent: return 22
        case .compact: return 18
        }
    }

    private var increasedContrast: Bool {
        colorSchemeContrast == .increased
    }

    private var softenedAccent: Color {
        palette.accent(accent ?? WeekFitTheme.borderSoft)
    }

    private var hasSemanticAccent: Bool {
        accent != nil
    }

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                    .fill(matteBase)
                    .overlay {
                        RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                            .fill(surfaceLightGradient)
                    }
                    .overlay {
                        if shouldShowAccentWash {
                            RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                                .fill(accentWashGradient)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                            .strokeBorder(
                                borderGradient(boost: increasedContrast ? 1.35 : 1.0),
                                lineWidth: increasedContrast ? 1.25 : 1
                            )
                    }
                    .shadow(color: primaryShadowColor, radius: primaryShadowRadius, y: primaryShadowY)
                    .shadow(color: depthShadowColor, radius: depthShadowRadius, y: depthShadowY)
            }
    }

    // MARK: - Fill

    private var matteBase: Color {
        switch emphasis {
        case .elevated:
            return palette.cardSurfaceElevated
        case .standard, .accent:
            return palette.cardSurface
        case .compact:
            return palette.cardSurface.opacity(0.96)
        }
    }

    private var surfaceLightGradient: LinearGradient {
        let peak: CGFloat
        let floor: CGFloat

        if reduceTransparency {
            peak = increasedContrast ? 0.055 : 0.038
            floor = 0.008
        } else {
            switch emphasis {
            case .elevated:
                peak = increasedContrast ? 0.070 : 0.052
                floor = 0.010
            case .accent:
                peak = increasedContrast ? 0.060 : 0.045
                floor = 0.009
            case .standard:
                peak = increasedContrast ? 0.055 : 0.040
                floor = 0.008
            case .compact:
                peak = increasedContrast ? 0.045 : 0.032
                floor = 0.006
            }
        }

        return LinearGradient(
            colors: [
                palette.whiteOpacity(peak),
                palette.whiteOpacity(peak * 0.42),
                palette.whiteOpacity(floor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shouldShowAccentWash: Bool {
        guard hasSemanticAccent else { return false }
        switch emphasis {
        case .accent, .elevated: return true
        case .standard, .compact: return false
        }
    }

    private var accentWashGradient: LinearGradient {
        let peak: CGFloat
        switch emphasis {
        case .elevated: peak = palette.accentOpacity(0.085)
        case .accent: peak = palette.accentOpacity(0.12)
        case .standard, .compact: peak = 0
        }

        return LinearGradient(
            colors: [
                softenedAccent.opacity(Double(peak)),
                softenedAccent.opacity(Double(peak * 0.35)),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: UnitPoint(x: 0.72, y: 0.58)
        )
    }

    // MARK: - Border

    private func borderGradient(boost: CGFloat) -> LinearGradient {
        let leading: Color
        let mid = palette.cardBorder.opacity(Double(1.05 * boost))
        let trailing = palette.cardBorder.opacity(Double(0.55 * boost))

        if hasSemanticAccent {
            let opacity: CGFloat
            switch emphasis {
            case .elevated: opacity = palette.accentOpacity(0.28) * boost
            case .accent: opacity = palette.accentOpacity(0.22) * boost
            case .standard: opacity = palette.accentOpacity(0.16) * boost
            case .compact: opacity = palette.accentOpacity(0.12) * boost
            }
            leading = softenedAccent.opacity(Double(opacity))
        } else {
            switch emphasis {
            case .elevated: leading = palette.whiteOpacity(0.30 * boost)
            case .standard, .accent: leading = palette.whiteOpacity(0.22 * boost)
            case .compact: leading = palette.whiteOpacity(0.16 * boost)
            }
        }

        return LinearGradient(
            colors: [leading, mid, trailing],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Shadows

    private var primaryShadowColor: Color {
        guard hasSemanticAccent else { return Color.clear }

        let opacity: CGFloat
        switch emphasis {
        case .elevated: opacity = palette.accentOpacity(0.05)
        case .accent: opacity = palette.accentOpacity(0.04)
        case .standard: opacity = palette.accentOpacity(0.025)
        case .compact: opacity = palette.accentOpacity(0.018)
        }
        return softenedAccent.opacity(Double(opacity))
    }

    private var primaryShadowRadius: CGFloat {
        switch emphasis {
        case .elevated: return 16
        case .accent: return 12
        case .standard: return 10
        case .compact: return 6
        }
    }

    private var primaryShadowY: CGFloat {
        switch emphasis {
        case .elevated: return 5
        case .accent: return 4
        case .standard: return 3
        case .compact: return 2
        }
    }

    private var depthShadowColor: Color {
        let factor: CGFloat
        switch emphasis {
        case .elevated: factor = 0.62
        case .accent: factor = 0.48
        case .standard: factor = 0.40
        case .compact: factor = 0.26
        }
        return Color.black.opacity(Double(palette.cardShadowOpacity * factor))
    }

    private var depthShadowRadius: CGFloat {
        switch emphasis {
        case .elevated: return 22
        case .accent: return 16
        case .standard: return 14
        case .compact: return 9
        }
    }

    private var depthShadowY: CGFloat {
        switch emphasis {
        case .elevated: return 10
        case .accent: return 7
        case .standard: return 6
        case .compact: return 4
        }
    }
}

extension View {

    /// Unified WeekFit premium card chrome.
    func weekFitPremiumCard(
        emphasis: WeekFitPremiumCardEmphasis = .standard,
        accent: Color? = nil,
        cornerRadius: CGFloat? = nil
    ) -> some View {
        modifier(
            WeekFitPremiumCardModifier(
                emphasis: emphasis,
                accent: accent,
                cornerRadius: cornerRadius
            )
        )
    }

    /// Backward-compatible overload used by existing call sites.
    func weekFitPremiumCard(
        accent: Color,
        cornerRadius: CGFloat = 20,
        featured: Bool = true
    ) -> some View {
        weekFitPremiumCard(
            emphasis: featured ? .elevated : .standard,
            accent: accent,
            cornerRadius: cornerRadius
        )
    }
}
