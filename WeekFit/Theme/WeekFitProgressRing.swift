import SwiftUI

/// Progress ring accents — same semantic hues in Light and Dark.
enum WeekFitProgressRingColor {
    /// Move / activity — `#72AD8A`.
    @MainActor
    static var activity: Color { WeekFitSemanticMetricTokens.activity }

    /// Nutrition — `#EAA06B`.
    @MainActor
    static var nutrition: Color { WeekFitSemanticMetricTokens.nutrition }

    /// Recovery — `#9B8ACB`.
    @MainActor
    static var recovery: Color { WeekFitSemanticMetricTokens.recovery }

    /// Small caption / value text — darker ink in Light for AA; vivid brand hue on OLED.
    @MainActor
    static var activityLabel: Color {
        WeekFitPaletteStore.current.isLight
            ? WeekFitSemanticMetricTokens.activityInk
            : WeekFitSemanticMetricTokens.activity
    }

    @MainActor
    static var nutritionLabel: Color {
        WeekFitPaletteStore.current.isLight
            ? WeekFitSemanticMetricTokens.nutritionInk
            : WeekFitSemanticMetricTokens.nutrition
    }

    @MainActor
    static var recoveryLabel: Color {
        WeekFitPaletteStore.current.isLight
            ? WeekFitSemanticMetricTokens.recoveryInk
            : WeekFitSemanticMetricTokens.recovery
    }

    /// Maps a vivid ring color to its readable label ink in Light.
    @MainActor
    static func labelInk(for ringColor: Color) -> Color {
        guard WeekFitPaletteStore.current.isLight else { return ringColor }
        if ringColor == WeekFitLightTokens.activity { return WeekFitLightTokens.activityInk }
        if ringColor == WeekFitLightTokens.nutrition { return WeekFitLightTokens.nutritionInk }
        if ringColor == WeekFitLightTokens.recovery { return WeekFitLightTokens.recoveryInk }
        if ringColor == WeekFitLightTokens.water { return WeekFitLightTokens.waterInk }
        return ringColor
    }
}

struct WeekFitProgressRing<Label: View>: View {

    let progress: CGFloat
    let size: CGFloat
    let strokeWidth: CGFloat
    let gradientColors: [Color]
    let tipGlowColor: Color
    @ViewBuilder private let label: () -> Label

    @Environment(\.weekFitPalette) private var palette

    init(
        progress: CGFloat,
        color: Color,
        size: CGFloat,
        strokeWidth: CGFloat = 4,
        gradientColors: [Color]? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.progress = max(0, min(progress, 1))
        self.size = size
        self.strokeWidth = strokeWidth
        self.tipGlowColor = color
        self.gradientColors = gradientColors ?? Self.defaultGradient(for: color)
        self.label = label
    }

    var body: some View {
        ZStack {
            // Matte track — airy #E5E5EA in Light.
            Circle()
                .stroke(trackColor, lineWidth: strokeWidth)
                .frame(width: size, height: size)

            if progress > 0 {
                if !palette.isLight {
                    leadingEdgeGlow
                }

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressStroke,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
            }

            label()
        }
        .frame(width: size, height: size)
    }

    private var trackColor: Color {
        palette.ringTrack
    }

    private var progressStroke: AnyShapeStyle {
        if palette.isLight {
            // Smooth matte ring — full-strength light metric color.
            return AnyShapeStyle(tipGlowColor.opacity(Double(palette.ringGradientPeakOpacity)))
        }
        return AnyShapeStyle(AngularGradient(colors: resolvedGradientColors, center: .center))
    }

    private var resolvedGradientColors: [Color] {
        gradientColors.map { color in
            palette.accent(color).opacity(Double(palette.ringGradientPeakOpacity))
        }
    }

    /// Short arc bloom at the progress tip — dark OLED only.
    private var leadingEdgeGlow: some View {
        let span = min(0.10, max(0.035, progress * 0.12))
        let tipStart = max(0, progress - span)

        return Circle()
            .trim(from: tipStart, to: progress)
            .stroke(
                palette.accent(tipGlowColor).opacity(Double(palette.ringGlowOpacity)),
                style: StrokeStyle(lineWidth: strokeWidth + 1.5, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90))
            .blur(radius: 1.5)
    }

    private static func defaultGradient(for color: Color) -> [Color] {
        [
            color.opacity(0.82),
            color.opacity(0.98),
            color,
            color.opacity(0.92)
        ]
    }
}
