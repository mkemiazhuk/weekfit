import SwiftUI

/// OLED-style progress rings — crisp stroke, tight leading-edge luminance (Apple Activity / Health).
enum WeekFitProgressRingColor {
    /// Move / activity — saturated exercise green (Apple-style punch).
    static let activity = Color(red: 0.40, green: 0.94, blue: 0.44)
    /// Nutrition — vivid warm orange.
    static let nutrition = Color(red: 1.00, green: 0.58, blue: 0.14)
    /// Recovery — saturated stand-ring cyan.
    static let recovery = Color(red: 0.18, green: 0.86, blue: 0.98)
}

struct WeekFitProgressRing<Label: View>: View {

    let progress: CGFloat
    let size: CGFloat
    let strokeWidth: CGFloat
    let gradientColors: [Color]
    let tipGlowColor: Color
    @ViewBuilder private let label: () -> Label

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
            Circle()
                .stroke(Color.white.opacity(0.11), lineWidth: strokeWidth)
                .frame(width: size, height: size)

            if progress > 0 {
                leadingEdgeGlow

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(colors: gradientColors, center: .center),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
            }

            label()
        }
        .frame(width: size, height: size)
    }

    /// Short arc bloom at the progress tip — no full-circumference halo.
    private var leadingEdgeGlow: some View {
        let span = min(0.10, max(0.035, progress * 0.12))
        let tipStart = max(0, progress - span)

        return Circle()
            .trim(from: tipStart, to: progress)
            .stroke(
                tipGlowColor.opacity(0.18),
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
