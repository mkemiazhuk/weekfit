import SwiftUI

/// Abstract atmospheric hero artwork derived from condition + period.
/// Always intentional — never an empty or broken placeholder.
struct WeekFitWeatherHeroAtmosphere: View {
    let condition: WeekFitWeatherCondition
    let period: WeekFitWeatherPeriod
    let tokens: WeekFitWeatherTokens
    let temperatureC: Double
    var reduceMotion: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 3600 : 1 / 20, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                drawAtmosphere(context: context, size: size, time: t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawAtmosphere(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let rect = CGRect(origin: .zero, size: size)

        // Base sky wash
        let sky = Gradient(colors: [
            tokens.backgroundSecondary,
            tokens.heroSurface,
            tokens.backgroundPrimary
        ])
        context.fill(
            Path(rect),
            with: .linearGradient(
                sky,
                startPoint: CGPoint(x: size.width * 0.2, y: 0),
                endPoint: CGPoint(x: size.width * 0.8, y: size.height)
            )
        )

        // Ambient glow orb
        let glowCenter: CGPoint
        switch period {
        case .dawn:
            glowCenter = CGPoint(x: size.width * 0.22, y: size.height * 0.72)
        case .day:
            glowCenter = CGPoint(x: size.width * 0.78, y: size.height * 0.22)
        case .goldenHour:
            glowCenter = CGPoint(x: size.width * 0.82, y: size.height * 0.58)
        case .dusk:
            glowCenter = CGPoint(x: size.width * 0.75, y: size.height * 0.70)
        case .night:
            glowCenter = CGPoint(x: size.width * 0.78, y: size.height * 0.24)
        }

        let glowRadius = min(size.width, size.height) * (period == .day ? 0.42 : 0.36)
        var glowContext = context
        glowContext.addFilter(.blur(radius: glowRadius * 0.55))
        glowContext.fill(
            Path(ellipseIn: CGRect(
                x: glowCenter.x - glowRadius,
                y: glowCenter.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )),
            with: .color(tokens.ambientGlow)
        )

        switch condition {
        case .clear:
            drawClear(context: context, size: size, glowCenter: glowCenter, time: time)
        case .partlyCloudy:
            drawClear(context: context, size: size, glowCenter: glowCenter, time: time, subdued: true)
            drawClouds(context: context, size: size, time: time, density: 0.55)
        case .cloudy:
            drawClouds(context: context, size: size, time: time, density: 0.9)
        case .rain:
            drawClouds(context: context, size: size, time: time, density: 0.75)
            drawRain(context: context, size: size, time: time)
        case .storm:
            drawClouds(context: context, size: size, time: time, density: 1.0, darker: true)
            drawRain(context: context, size: size, time: time, heavy: true)
            if !reduceMotion {
                drawStormFlash(context: context, size: size, time: time)
            }
        case .snow:
            drawClouds(context: context, size: size, time: time, density: 0.5)
            drawSnow(context: context, size: size, time: time)
        case .fog:
            drawFog(context: context, size: size, time: time)
        case .windy:
            drawWind(context: context, size: size, time: time)
        case .other:
            drawClouds(context: context, size: size, time: time, density: 0.4)
        }

        if temperatureC >= 33 && !period.isNightLike {
            // Soft heat haze rim — calm, not aggressive red
            var haze = context
            haze.opacity = 0.18
            haze.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.85, blue: 0.55).opacity(0.0),
                        Color(red: 1.0, green: 0.78, blue: 0.45).opacity(0.55)
                    ]),
                    startPoint: CGPoint(x: 0, y: size.height * 0.35),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
        }
    }

    private func drawClear(
        context: GraphicsContext,
        size: CGSize,
        glowCenter: CGPoint,
        time: TimeInterval,
        subdued: Bool = false
    ) {
        let pulse = reduceMotion ? 1.0 : (0.92 + 0.08 * sin(time * 0.7))
        let radius = min(size.width, size.height) * (subdued ? 0.10 : 0.13) * pulse

        if period.isNightLike {
            // Moon
            context.fill(
                Path(ellipseIn: CGRect(
                    x: glowCenter.x - radius,
                    y: glowCenter.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .color(tokens.heroIllustrationPrimary.opacity(subdued ? 0.55 : 0.9))
            )
            // Soft stars
            if !subdued {
                for i in 0..<8 {
                    let sx = size.width * (0.12 + Double(i) * 0.1)
                    let sy = size.height * (0.12 + Double((i * 3) % 7) * 0.08)
                    let twinkle = reduceMotion ? 0.55 : 0.35 + 0.45 * abs(sin(time * 0.9 + Double(i)))
                    context.fill(
                        Path(ellipseIn: CGRect(x: sx, y: sy, width: 2.2, height: 2.2)),
                        with: .color(Color.white.opacity(twinkle))
                    )
                }
            }
        } else {
            // Sun disc + soft corona
            context.fill(
                Path(ellipseIn: CGRect(
                    x: glowCenter.x - radius,
                    y: glowCenter.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .color(tokens.heroIllustrationPrimary.opacity(subdued ? 0.55 : 0.95))
            )
            var corona = context
            corona.addFilter(.blur(radius: radius * 0.85))
            corona.opacity = subdued ? 0.25 : 0.45
            corona.fill(
                Path(ellipseIn: CGRect(
                    x: glowCenter.x - radius * 1.8,
                    y: glowCenter.y - radius * 1.8,
                    width: radius * 3.6,
                    height: radius * 3.6
                )),
                with: .color(tokens.ambientGlow)
            )
        }
    }

    private func drawClouds(
        context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        density: CGFloat,
        darker: Bool = false
    ) {
        let drift = reduceMotion ? 0 : CGFloat(sin(time * 0.12)) * 10
        let count = Int(3 + density * 3)
        for i in 0..<count {
            let baseX = size.width * (0.08 + CGFloat(i) * 0.22) + drift * (i.isMultiple(of: 2) ? 1 : -0.6)
            let baseY = size.height * (0.18 + CGFloat(i % 3) * 0.12)
            let w = size.width * (0.28 + CGFloat(i % 2) * 0.08)
            let h = size.height * 0.16
            let opacity = darker ? 0.35 : 0.22
            var cloud = context
            cloud.addFilter(.blur(radius: 14))
            cloud.opacity = opacity + Double(i) * 0.04
            cloud.fill(
                Path(ellipseIn: CGRect(x: baseX, y: baseY, width: w, height: h)),
                with: .color(tokens.heroIllustrationSecondary)
            )
            cloud.fill(
                Path(ellipseIn: CGRect(x: baseX + w * 0.25, y: baseY - h * 0.25, width: w * 0.55, height: h * 0.85)),
                with: .color(tokens.heroIllustrationPrimary.opacity(0.8))
            )
        }
    }

    private func drawRain(
        context: GraphicsContext,
        size: CGSize,
        time: TimeInterval,
        heavy: Bool = false
    ) {
        let lines = heavy ? 18 : 12
        let offset = reduceMotion ? 0 : CGFloat(time.truncatingRemainder(dividingBy: 1.2)) / 1.2
        for i in 0..<lines {
            let x = size.width * (CGFloat(i) + 0.5) / CGFloat(lines)
            let startY = size.height * (0.25 + CGFloat((i * 7) % 5) * 0.08)
            let length = size.height * (heavy ? 0.12 : 0.08)
            let y = startY + offset * size.height * 0.35
            var path = Path()
            path.move(to: CGPoint(x: x, y: y.truncatingRemainder(dividingBy: size.height)))
            path.addLine(to: CGPoint(x: x + 2, y: y.truncatingRemainder(dividingBy: size.height) + length))
            context.stroke(
                path,
                with: .color(tokens.heroIllustrationPrimary.opacity(heavy ? 0.28 : 0.18)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
            )
        }

        // Wet-surface sheen near bottom of hero
        var sheen = context
        sheen.opacity = 0.2
        sheen.fill(
            Path(CGRect(x: 0, y: size.height * 0.72, width: size.width, height: size.height * 0.28)),
            with: .linearGradient(
                Gradient(colors: [
                    Color.clear,
                    tokens.heroIllustrationSecondary.opacity(0.35)
                ]),
                startPoint: CGPoint(x: 0, y: size.height * 0.72),
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    private func drawStormFlash(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        // Restrained occasional flash — not stressful strobing
        let cycle = time.truncatingRemainder(dividingBy: 7.0)
        guard cycle > 6.55 && cycle < 6.72 else { return }
        var flash = context
        flash.opacity = 0.12
        flash.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white))
    }

    private func drawSnow(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let flakes = 16
        for i in 0..<flakes {
            let xBase = size.width * (CGFloat(i) + 0.3) / CGFloat(flakes)
            let fall = reduceMotion ? CGFloat(i) * 12 : CGFloat(time * (12 + Double(i % 5)) + Double(i * 17))
            let y = fall.truncatingRemainder(dividingBy: size.height)
            let x = xBase + sin(time * 0.6 + Double(i)) * 6
            let r: CGFloat = i.isMultiple(of: 3) ? 2.4 : 1.6
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                with: .color(Color.white.opacity(0.55))
            )
        }
    }

    private func drawFog(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let drift = reduceMotion ? 0 : CGFloat(sin(time * 0.15)) * 12
        for i in 0..<4 {
            var band = context
            band.addFilter(.blur(radius: 18))
            band.opacity = 0.18 + Double(i) * 0.05
            let y = size.height * (0.25 + CGFloat(i) * 0.16)
            band.fill(
                Path(ellipseIn: CGRect(
                    x: -40 + drift * (i.isMultiple(of: 2) ? 1 : -1),
                    y: y,
                    width: size.width + 80,
                    height: size.height * 0.18
                )),
                with: .color(tokens.heroIllustrationPrimary)
            )
        }
    }

    private func drawWind(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let drift = reduceMotion ? 0 : CGFloat(time.truncatingRemainder(dividingBy: 3)) / 3
        for i in 0..<5 {
            let y = size.height * (0.28 + CGFloat(i) * 0.12)
            var path = Path()
            let startX = size.width * (-0.1 + drift) + CGFloat(i) * 8
            path.move(to: CGPoint(x: startX, y: y))
            path.addQuadCurve(
                to: CGPoint(x: startX + size.width * 0.55, y: y - 4),
                control: CGPoint(x: startX + size.width * 0.25, y: y - 14)
            )
            context.stroke(
                path,
                with: .color(tokens.heroIllustrationPrimary.opacity(0.22)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
        }
    }
}
