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
        case .standard, .elevated, .accent: return palette.isLight ? WeekFitSurface.primaryRadius : 22
        case .compact: return palette.isLight ? WeekFitSurface.compactRadius : 18
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
                    // Shadow on the rounded shape — never compositingGroup→shadow (rectangular slab).
                    .shadow(color: contactShadowColor, radius: contactShadowRadius, y: contactShadowY)
                    .shadow(color: ambientShadowColor, radius: ambientShadowRadius, y: ambientShadowY)
                    .shadow(color: primaryShadowColor, radius: primaryShadowRadius, y: primaryShadowY)
            }
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                        .strokeBorder(
                            borderGradient(boost: increasedContrast ? 1.35 : 1.0),
                            lineWidth: increasedContrast ? 1.25 : (palette.isLight ? 0.9 : 1)
                        )
                }
            }
    }

    // MARK: - Fill

    private var matteBase: Color {
        if palette.isLight {
            switch emphasis {
            case .elevated:
                return palette.cardSurfaceElevated
            case .standard, .accent, .compact:
                return palette.cardSurface
            }
        }
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
        if palette.isLight {
            // Whisper of ambient light — top fractionally brighter; almost subconscious.
            let peak: Double
            switch emphasis {
            case .elevated: peak = reduceTransparency ? 0.10 : 0.14
            case .accent: peak = reduceTransparency ? 0.08 : 0.11
            case .standard: peak = reduceTransparency ? 0.07 : 0.10
            case .compact: peak = reduceTransparency ? 0.05 : 0.08
            }
            return LinearGradient(
                colors: [
                    Color.white.opacity(peak),
                    Color.white.opacity(peak * 0.35),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }

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
                palette.specularHighlight(peak),
                palette.specularHighlight(peak * 0.42),
                palette.specularHighlight(floor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shouldShowAccentWash: Bool {
        guard hasSemanticAccent else { return false }
        if palette.isLight {
            switch emphasis {
            case .accent, .elevated, .compact: return true
            case .standard: return false
            }
        }
        switch emphasis {
        case .accent, .elevated: return true
        case .standard, .compact: return false
        }
    }

    private var accentWashGradient: LinearGradient {
        let peak: CGFloat
        if palette.isLight {
            // Barely-there category influence — never playful or colorful.
            switch emphasis {
            case .elevated: peak = 0.022
            case .accent: peak = 0.018
            case .compact: peak = 0.028
            case .standard: peak = 0
            }
        } else {
            switch emphasis {
            case .elevated: peak = palette.accentOpacity(0.085)
            case .accent: peak = palette.accentOpacity(0.12)
            case .standard, .compact: peak = 0
            }
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

    /// Soft ceramic edge — always on so cards separate from ivory / OLED canvas.
    private var showsBorder: Bool { true }

    private func borderGradient(boost: CGFloat) -> LinearGradient {
        if palette.isLight {
            // Precision rim: brighter top/side highlight, softer bottom definition.
            // Not a visible “outline” — a subconscious edge.
            let ink = WeekFitLightTokens.cardBorderStrokeOpacity * Double(boost)
            let inkMid: Double
            let inkBottom: Double
            switch emphasis {
            case .elevated:
                inkMid = min(0.055, ink * 1.15)
                inkBottom = min(0.065, ink * 1.35)
            case .accent:
                inkMid = min(0.05, ink * 1.08)
                inkBottom = min(0.06, ink * 1.25)
            case .standard:
                inkMid = ink
                inkBottom = ink * 1.15
            case .compact:
                inkMid = ink * 0.92
                inkBottom = ink * 1.05
            }

            let topHighlight = WeekFitLightTokens.cardEdgeHighlight.opacity(
                Double((increasedContrast ? 0.55 : 0.72) * boost)
            )
            let side = hasSemanticAccent
                ? softenedAccent.opacity(Double(0.10 * boost))
                : Color.black.opacity(inkMid)
            let bottom = Color.black.opacity(inkBottom)

            return LinearGradient(
                colors: [topHighlight, side, bottom],
                startPoint: .top,
                endPoint: .bottom
            )
        }

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
            case .elevated: leading = palette.specularHighlight(0.30 * boost)
            case .standard, .accent: leading = palette.specularHighlight(0.22 * boost)
            case .compact: leading = palette.specularHighlight(0.16 * boost)
            }
        }

        return LinearGradient(
            colors: [leading, mid, trailing],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Shadows (ambient daylight)

    private var contactShadowColor: Color {
        if palette.isLight {
            let base = WeekFitLightTokens.cardContactShadowOpacity
            switch emphasis {
            case .elevated: return Color.black.opacity(base * 1.15)
            case .accent: return Color.black.opacity(base * 1.05)
            case .standard: return Color.black.opacity(base)
            case .compact: return Color.black.opacity(base * 0.85)
            }
        }
        return .clear
    }

    private var contactShadowRadius: CGFloat {
        if palette.isLight {
            switch emphasis {
            case .elevated: return 2.5
            case .accent, .standard: return 2
            case .compact: return 1.5
            }
        }
        return 0
    }

    private var contactShadowY: CGFloat {
        palette.isLight ? 1 : 0
    }

    private var ambientShadowColor: Color {
        if palette.isLight {
            // Tight, quiet depth — integrated, not floating.
            let base = WeekFitLightTokens.cardAmbientShadowOpacity
            switch emphasis {
            case .elevated: return Color.black.opacity(base * 1.15)
            case .accent: return Color.black.opacity(base * 1.05)
            case .standard: return Color.black.opacity(base)
            case .compact: return Color.black.opacity(base * 0.85)
            }
        }
        let factor: CGFloat
        switch emphasis {
        case .elevated: factor = 0.62
        case .accent: factor = 0.48
        case .standard: factor = 0.40
        case .compact: factor = 0.26
        }
        return Color.black.opacity(Double(palette.cardShadowOpacity * factor))
    }

    private var ambientShadowRadius: CGFloat {
        if palette.isLight {
            switch emphasis {
            case .elevated: return 8
            case .accent: return 7
            case .standard: return 6
            case .compact: return 5
            }
        }
        switch emphasis {
        case .elevated: return 22
        case .accent: return 16
        case .standard: return 14
        case .compact: return 9
        }
    }

    private var ambientShadowY: CGFloat {
        if palette.isLight {
            switch emphasis {
            case .elevated: return 3
            case .accent: return 3
            case .standard: return 2
            case .compact: return 2
            }
        }
        switch emphasis {
        case .elevated: return 10
        case .accent: return 7
        case .standard: return 6
        case .compact: return 4
        }
    }

    private var primaryShadowColor: Color {
        guard hasSemanticAccent else { return Color.clear }
        if palette.isLight {
            // No colored glow in light — keeps ceramic daylight calm.
            return Color.clear
        }

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
}

/// Applies premium card chrome only when enabled (avoids dual-mode layout forks).
struct ConditionalWeekFitPremiumCard: ViewModifier {
    var enabled: Bool
    var emphasis: WeekFitPremiumCardEmphasis
    var accent: Color?
    var cornerRadius: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.weekFitPremiumCard(
                emphasis: emphasis,
                accent: accent,
                cornerRadius: cornerRadius
            )
        } else {
            content
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
