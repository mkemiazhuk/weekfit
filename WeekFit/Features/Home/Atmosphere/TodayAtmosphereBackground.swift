import SwiftUI

struct TodayAtmosphereBackground: View {
    let snapshot: TodayAtmosphereSnapshot
    let ambientOpacity: CGFloat

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if palette.isLight {
                lightCanvas
            } else {
                darkSkyCanvas
                primaryGlow
                secondaryGlow
            }
        }
        .animation(.easeInOut(duration: 1.4), value: snapshot)
        // Never animate Light↔Dark here — resume flaps otherwise paint a black
        // canvas under Light cards. Dark Night Comfort blend crossfades elsewhere.
        .animation(palette.isLight ? nil : .easeInOut(duration: 0.45), value: palette.appearance)
    }

    // MARK: - Light: warm ivory + subtle top glow only

    private var lightCanvas: some View {
        ZStack {
            palette.appScreenBackground

            // Top champagne glow — restrained, header-only.
            RadialGradient(
                colors: [
                    WeekFitLightTokens.backgroundTopGlow.opacity(0.55 * ambientOpacity),
                    WeekFitLightTokens.backgroundTopGlow.opacity(0.18 * ambientOpacity),
                    Color.clear
                ],
                center: UnitPoint(x: 0.50, y: 0.0),
                startRadius: 4,
                endRadius: 260
            )

            // Quiet semantic wash (mode-aware, barely perceptible).
            RadialGradient(
                colors: [
                    lightModeAccent.opacity(0.028 * ambientOpacity),
                    Color.clear
                ],
                center: UnitPoint(x: 0.88, y: 0.16),
                startRadius: 20,
                endRadius: 240
            )

            // Soft edge vignette — neutral, not gold-washed.
            RadialGradient(
                colors: [
                    Color.clear,
                    WeekFitLightTokens.shadowAmbient.opacity(0.045 * ambientOpacity)
                ],
                center: .center,
                startRadius: 200,
                endRadius: 540
            )
        }
    }

    private var lightModeAccent: Color {
        switch snapshot.mode {
        case .ready:
            return WeekFitLightTokens.activity
        case .protect:
            return WeekFitLightTokens.recovery
        case .load:
            return WeekFitLightTokens.nutrition
        }
    }

    // MARK: - Dark Weather-style sky

    private var darkPalette: AtmospherePalette {
        AtmospherePalette.make(snapshot: snapshot)
    }

    private var skyIntensity: SkyIntensity {
        SkyIntensity.make(phase: snapshot.timePhase)
    }

    private var darkSkyCanvas: some View {
        ZStack {
            skyGradient
            lunarGlow
            // Stars stay static so they never fight text or thrash during scroll.
            TodayAtmosphereStarField(
                intensity: skyIntensity,
                ambientOpacity: ambientOpacity
            )
            TodayAtmosphereCloudVeil(
                intensity: skyIntensity,
                ambientOpacity: ambientOpacity,
                reduceMotion: reduceMotion
            )
        }
    }

    private var skyGradient: some View {
        LinearGradient(
            colors: darkPalette.base.map { $0.opacity(Double(ambientOpacity)) },
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var lunarGlow: some View {
        RadialGradient(
            colors: [
                darkPalette.skyGlow.opacity(darkPalette.skyGlowOpacity * ambientOpacity),
                Color.clear
            ],
            center: darkPalette.skyGlowCenter,
            startRadius: 8,
            endRadius: darkPalette.skyGlowRadius
        )
    }

    private var primaryGlow: some View {
        RadialGradient(
            colors: [
                darkPalette.primaryGlow.opacity(darkPalette.primaryGlowOpacity * ambientOpacity),
                Color.clear
            ],
            center: darkPalette.primaryCenter,
            startRadius: 20,
            endRadius: darkPalette.primaryRadius
        )
    }

    private var secondaryGlow: some View {
        RadialGradient(
            colors: [
                darkPalette.secondaryGlow.opacity(darkPalette.secondaryGlowOpacity * ambientOpacity),
                Color.clear
            ],
            center: darkPalette.secondaryCenter,
            startRadius: 16,
            endRadius: darkPalette.secondaryRadius
        )
    }
}

// MARK: - Sky intensity by time phase

private struct SkyIntensity: Equatable {
    let starDensity: CGFloat
    let cloudOpacity: CGFloat
    let cloudCount: Int

    static func make(phase: TodayTimePhase) -> SkyIntensity {
        switch phase {
        case .night:
            // Sparse but visible — Weather-like, not competing with type.
            return SkyIntensity(starDensity: 0.72, cloudOpacity: 0.15, cloudCount: 3)
        case .evening:
            return SkyIntensity(starDensity: 0.48, cloudOpacity: 0.22, cloudCount: 4)
        case .morning:
            return SkyIntensity(starDensity: 0.0, cloudOpacity: 0.16, cloudCount: 4)
        case .day:
            return SkyIntensity(starDensity: 0.0, cloudOpacity: 0.12, cloudCount: 3)
        }
    }
}

// MARK: - Static star field (no continuous redraw)

private struct TodayAtmosphereStarField: View {
    let intensity: SkyIntensity
    let ambientOpacity: CGFloat

    var body: some View {
        Canvas { context, size in
            drawStars(context: context, size: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawStars(context: GraphicsContext, size: CGSize) {
        guard intensity.starDensity > 0.01 else { return }

        // Density controls count only — opacity stays readable even when ambient softens.
        let count = Int(36 * intensity.starDensity)
        let ambient = max(0.72, Double(ambientOpacity))
        for i in 0..<count {
            // Deterministic pseudo-random layout (stable across updates).
            let seed = Double(i * 7919 + 104729)
            let nx = fract(sin(seed) * 43758.5453)
            let ny = fract(sin(seed * 1.7) * 24634.123)
            // Prefer upper half — clear of lower cards.
            let x = size.width * nx
            let y = size.height * ny * 0.55
            let baseSize: CGFloat = i.isMultiple(of: 7) ? 2.0 : (i.isMultiple(of: 3) ? 1.4 : 1.05)
            // Soft white dots — visible but never loud.
            let opacity = (0.22 + 0.20 * nx) * ambient
            context.fill(
                Path(ellipseIn: CGRect(
                    x: x,
                    y: y,
                    width: baseSize,
                    height: baseSize
                )),
                with: .color(Color.white.opacity(min(0.42, opacity)))
            )
        }
    }

    private func fract(_ value: Double) -> Double {
        value - floor(value)
    }
}

// MARK: - Wispy cloud veil (Reduce Motion → static)

private struct TodayAtmosphereCloudVeil: View {
    let intensity: SkyIntensity
    let ambientOpacity: CGFloat
    let reduceMotion: Bool

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 3600 : 1 / 6,
                paused: reduceMotion
            )
        ) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                drawClouds(context: context, size: size, time: time)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawClouds(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let drift = reduceMotion ? 0 : CGFloat(sin(time * 0.08)) * 8
        let tint = Color(red: 0.36, green: 0.34, blue: 0.52)

        for i in 0..<intensity.cloudCount {
            let baseX = size.width * (0.02 + CGFloat(i) * 0.22)
                + drift * (i.isMultiple(of: 2) ? 1 : -0.55)
            let baseY = size.height * (0.06 + CGFloat(i % 3) * 0.07)
            let w = size.width * (0.34 + CGFloat(i % 2) * 0.10)
            let h = size.height * (0.08 + CGFloat(i % 3) * 0.015)
            let opacity = Double(intensity.cloudOpacity) * Double(ambientOpacity)
                * (0.70 + Double(i) * 0.04)

            var cloud = context
            cloud.addFilter(.blur(radius: 16))
            cloud.opacity = opacity

            cloud.fill(
                Path(ellipseIn: CGRect(x: baseX, y: baseY, width: w, height: h)),
                with: .color(tint)
            )
            cloud.fill(
                Path(ellipseIn: CGRect(
                    x: baseX + w * 0.22,
                    y: baseY - h * 0.28,
                    width: w * 0.58,
                    height: h * 0.9
                )),
                with: .color(tint.opacity(0.85))
            )
            cloud.fill(
                Path(ellipseIn: CGRect(
                    x: baseX + w * 0.48,
                    y: baseY - h * 0.08,
                    width: w * 0.42,
                    height: h * 0.75
                )),
                with: .color(tint.opacity(0.7))
            )
        }
    }
}

// MARK: - Palette

private struct AtmospherePalette {
    let base: [Color]
    let skyGlow: Color
    let skyGlowOpacity: CGFloat
    let skyGlowCenter: UnitPoint
    let skyGlowRadius: CGFloat
    let primaryGlow: Color
    let secondaryGlow: Color
    let primaryGlowOpacity: CGFloat
    let secondaryGlowOpacity: CGFloat
    let primaryCenter: UnitPoint
    let secondaryCenter: UnitPoint
    let primaryRadius: CGFloat
    let secondaryRadius: CGFloat

    static func make(snapshot: TodayAtmosphereSnapshot) -> AtmospherePalette {
        let time = snapshot.timePhase

        switch snapshot.mode {
        case .ready:
            return readyPalette(time: time)
        case .protect:
            return protectPalette(time: time)
        case .load:
            return loadPalette(time: time)
        }
    }

    private static func readyPalette(time: TodayTimePhase) -> AtmospherePalette {
        switch time {
        case .morning:
            return AtmospherePalette(
                base: [
                    Color(red: 0.04, green: 0.07, blue: 0.12),
                    Color(red: 0.025, green: 0.04, blue: 0.07),
                    Color(red: 0.015, green: 0.02, blue: 0.035)
                ],
                skyGlow: Color(red: 0.42, green: 0.72, blue: 0.88),
                skyGlowOpacity: 0.14,
                skyGlowCenter: UnitPoint(x: 0.72, y: 0.08),
                skyGlowRadius: 300,
                primaryGlow: Color(red: 0.42, green: 0.72, blue: 0.88),
                secondaryGlow: Color(red: 0.55, green: 0.82, blue: 0.61),
                primaryGlowOpacity: 0.12,
                secondaryGlowOpacity: 0.08,
                primaryCenter: UnitPoint(x: 0.88, y: 0.04),
                secondaryCenter: UnitPoint(x: 0.12, y: 0.72),
                primaryRadius: 320,
                secondaryRadius: 260
            )
        case .day:
            return AtmospherePalette(
                base: [
                    Color(red: 0.03, green: 0.055, blue: 0.10),
                    Color(red: 0.02, green: 0.03, blue: 0.055),
                    Color(red: 0.012, green: 0.015, blue: 0.03)
                ],
                skyGlow: Color(red: 0.50, green: 0.70, blue: 0.92),
                skyGlowOpacity: 0.11,
                skyGlowCenter: UnitPoint(x: 0.78, y: 0.06),
                skyGlowRadius: 280,
                primaryGlow: Color(red: 0.55, green: 0.82, blue: 0.61),
                secondaryGlow: Color(red: 0.50, green: 0.62, blue: 0.92),
                primaryGlowOpacity: 0.11,
                secondaryGlowOpacity: 0.07,
                primaryCenter: UnitPoint(x: 0.92, y: 0.02),
                secondaryCenter: UnitPoint(x: 0.08, y: 0.84),
                primaryRadius: 300,
                secondaryRadius: 240
            )
        case .evening:
            return AtmospherePalette(
                // Dusk indigo — fewer stars, warmer rim.
                base: [
                    Color(red: 0.055, green: 0.04, blue: 0.11),
                    Color(red: 0.035, green: 0.03, blue: 0.075),
                    Color(red: 0.018, green: 0.02, blue: 0.04)
                ],
                skyGlow: Color(red: 0.72, green: 0.55, blue: 0.88),
                skyGlowOpacity: 0.16,
                skyGlowCenter: UnitPoint(x: 0.70, y: 0.10),
                skyGlowRadius: 320,
                primaryGlow: Color(red: 0.68, green: 0.56, blue: 0.90),
                secondaryGlow: Color(red: 0.93, green: 0.58, blue: 0.26),
                primaryGlowOpacity: 0.11,
                secondaryGlowOpacity: 0.08,
                primaryCenter: UnitPoint(x: 0.84, y: 0.08),
                secondaryCenter: UnitPoint(x: 0.18, y: 0.78),
                primaryRadius: 310,
                secondaryRadius: 250
            )
        case .night:
            return clearNightPalette(modeAccent: .ready)
        }
    }

    private static func protectPalette(time: TodayTimePhase) -> AtmospherePalette {
        if time == .night {
            return clearNightPalette(modeAccent: .protect)
        }

        let eveningSky = time == .evening

        return AtmospherePalette(
            base: eveningSky
                ? [
                    Color(red: 0.03, green: 0.04, blue: 0.10),
                    Color(red: 0.045, green: 0.06, blue: 0.14),
                    Color(red: 0.07, green: 0.09, blue: 0.18)
                ]
                : [
                    Color(red: 0.025, green: 0.035, blue: 0.075),
                    Color(red: 0.015, green: 0.020, blue: 0.045),
                    Color(red: 0.01, green: 0.012, blue: 0.025)
                ],
            skyGlow: Color(red: 0.38, green: 0.52, blue: 0.88),
            skyGlowOpacity: 0.14,
            skyGlowCenter: UnitPoint(x: 0.55, y: 0.10),
            skyGlowRadius: 320,
            primaryGlow: Color(red: 0.38, green: 0.52, blue: 0.88),
            secondaryGlow: Color(red: 0.48, green: 0.42, blue: 0.78),
            primaryGlowOpacity: 0.12,
            secondaryGlowOpacity: 0.08,
            primaryCenter: UnitPoint(x: 0.72, y: 0.10),
            secondaryCenter: UnitPoint(x: 0.20, y: 0.82),
            primaryRadius: 340,
            secondaryRadius: 280
        )
    }

    private static func loadPalette(time: TodayTimePhase) -> AtmospherePalette {
        // Night drops the amber/orange load wash — keep muddy glow off the sky.
        if time == .night {
            return clearNightPalette(modeAccent: .load)
        }

        let eveningBoost: CGFloat = time == .evening ? 1.08 : 1.0
        let eveningSky = time == .evening

        return AtmospherePalette(
            base: eveningSky
                ? [
                    Color(red: 0.06, green: 0.035, blue: 0.08),
                    Color(red: 0.04, green: 0.028, blue: 0.06),
                    Color(red: 0.025, green: 0.02, blue: 0.04)
                ]
                : [
                    Color(red: 0.045, green: 0.028, blue: 0.020),
                    Color(red: 0.025, green: 0.018, blue: 0.030),
                    Color(red: 0.015, green: 0.012, blue: 0.02)
                ],
            skyGlow: Color(red: 0.93, green: 0.58, blue: 0.26),
            skyGlowOpacity: 0.12 * eveningBoost,
            skyGlowCenter: UnitPoint(x: 0.78, y: 0.08),
            skyGlowRadius: 300,
            primaryGlow: Color(red: 0.93, green: 0.58, blue: 0.26),
            secondaryGlow: Color(red: 0.95, green: 0.42, blue: 0.24),
            primaryGlowOpacity: 0.13 * eveningBoost,
            secondaryGlowOpacity: 0.09 * eveningBoost,
            primaryCenter: UnitPoint(x: 0.90, y: 0.06),
            secondaryCenter: UnitPoint(x: 0.14, y: 0.76),
            primaryRadius: 330,
            secondaryRadius: 270
        )
    }

    /// Shared clear-night sky: navy/indigo → near-black, faint violet header glow only.
    private static func clearNightPalette(modeAccent: TodayAtmosphereMode) -> AtmospherePalette {
        let violet = Color(red: 0.46, green: 0.40, blue: 0.78)
        let indigo = Color(red: 0.34, green: 0.40, blue: 0.72)
        let softViolet = Color(red: 0.40, green: 0.34, blue: 0.66)

        // Tiny mode accent — never orange/brown at night.
        let accent: Color
        let accentOpacity: CGFloat
        switch modeAccent {
        case .ready:
            accent = indigo
            accentOpacity = 0.07
        case .protect:
            accent = Color(red: 0.36, green: 0.46, blue: 0.82)
            accentOpacity = 0.08
        case .load:
            accent = softViolet
            accentOpacity = 0.07
        }

        return AtmospherePalette(
            base: [
                Color(red: 0.050, green: 0.055, blue: 0.130),
                Color(red: 0.024, green: 0.028, blue: 0.062),
                Color(red: 0.008, green: 0.010, blue: 0.018)
            ],
            skyGlow: violet,
            skyGlowOpacity: 0.13,
            skyGlowCenter: UnitPoint(x: 0.74, y: 0.05),
            skyGlowRadius: 260,
            primaryGlow: accent,
            secondaryGlow: softViolet,
            primaryGlowOpacity: accentOpacity,
            secondaryGlowOpacity: 0.045,
            primaryCenter: UnitPoint(x: 0.80, y: 0.03),
            secondaryCenter: UnitPoint(x: 0.38, y: 0.14),
            primaryRadius: 240,
            secondaryRadius: 180
        )
    }
}
