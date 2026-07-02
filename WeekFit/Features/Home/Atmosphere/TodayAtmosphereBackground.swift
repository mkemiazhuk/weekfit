import SwiftUI

struct TodayAtmosphereBackground: View {
    let snapshot: TodayAtmosphereSnapshot
    let ambientOpacity: CGFloat

    var body: some View {
        ZStack {
            baseGradient
            primaryGlow
            secondaryGlow
        }
        .animation(.easeInOut(duration: 1.4), value: snapshot)
    }

    private var palette: AtmospherePalette {
        AtmospherePalette.make(snapshot: snapshot)
    }

    private var baseGradient: some View {
        LinearGradient(
            colors: palette.base,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var primaryGlow: some View {
        RadialGradient(
            colors: [
                palette.primaryGlow.opacity(palette.primaryGlowOpacity * ambientOpacity),
                Color.clear
            ],
            center: palette.primaryCenter,
            startRadius: 20,
            endRadius: palette.primaryRadius
        )
    }

    private var secondaryGlow: some View {
        RadialGradient(
            colors: [
                palette.secondaryGlow.opacity(palette.secondaryGlowOpacity * ambientOpacity),
                Color.clear
            ],
            center: palette.secondaryCenter,
            startRadius: 16,
            endRadius: palette.secondaryRadius
        )
    }
}

private struct AtmospherePalette {
    let base: [Color]
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
                    Color(red: 0.03, green: 0.06, blue: 0.10),
                    Color(red: 0.02, green: 0.03, blue: 0.05),
                    Color(red: 0.01, green: 0.01, blue: 0.02)
                ],
                primaryGlow: Color(red: 0.42, green: 0.72, blue: 0.88),
                secondaryGlow: Color(red: 0.55, green: 0.82, blue: 0.61),
                primaryGlowOpacity: 0.16,
                secondaryGlowOpacity: 0.10,
                primaryCenter: UnitPoint(x: 0.88, y: 0.04),
                secondaryCenter: UnitPoint(x: 0.12, y: 0.72),
                primaryRadius: 320,
                secondaryRadius: 260
            )
        case .day:
            return AtmospherePalette(
                base: [
                    Color(red: 0.025, green: 0.05, blue: 0.08),
                    Color(red: 0.018, green: 0.026, blue: 0.045),
                    Color.black
                ],
                primaryGlow: Color(red: 0.55, green: 0.82, blue: 0.61),
                secondaryGlow: Color(red: 0.50, green: 0.62, blue: 0.92),
                primaryGlowOpacity: 0.14,
                secondaryGlowOpacity: 0.08,
                primaryCenter: UnitPoint(x: 0.92, y: 0.02),
                secondaryCenter: UnitPoint(x: 0.08, y: 0.84),
                primaryRadius: 300,
                secondaryRadius: 240
            )
        case .evening:
            return AtmospherePalette(
                base: [
                    Color(red: 0.04, green: 0.03, blue: 0.08),
                    Color(red: 0.02, green: 0.02, blue: 0.05),
                    Color.black
                ],
                primaryGlow: Color(red: 0.68, green: 0.56, blue: 0.90),
                secondaryGlow: Color(red: 0.93, green: 0.58, blue: 0.26),
                primaryGlowOpacity: 0.13,
                secondaryGlowOpacity: 0.09,
                primaryCenter: UnitPoint(x: 0.84, y: 0.08),
                secondaryCenter: UnitPoint(x: 0.18, y: 0.78),
                primaryRadius: 310,
                secondaryRadius: 250
            )
        case .night:
            return AtmospherePalette(
                base: [
                    Color(red: 0.015, green: 0.018, blue: 0.035),
                    Color(red: 0.008, green: 0.010, blue: 0.020),
                    Color.black
                ],
                primaryGlow: Color(red: 0.50, green: 0.62, blue: 0.92),
                secondaryGlow: Color(red: 0.55, green: 0.40, blue: 0.85),
                primaryGlowOpacity: 0.10,
                secondaryGlowOpacity: 0.07,
                primaryCenter: UnitPoint(x: 0.78, y: 0.06),
                secondaryCenter: UnitPoint(x: 0.22, y: 0.70),
                primaryRadius: 280,
                secondaryRadius: 220
            )
        }
    }

    private static func protectPalette(time: TodayTimePhase) -> AtmospherePalette {
        let nightDim: CGFloat = time == .night ? 0.85 : 1.0

        return AtmospherePalette(
            base: [
                Color(red: 0.025, green: 0.035, blue: 0.075),
                Color(red: 0.015, green: 0.020, blue: 0.045),
                Color.black
            ],
            primaryGlow: Color(red: 0.38, green: 0.52, blue: 0.88),
            secondaryGlow: Color(red: 0.48, green: 0.42, blue: 0.78),
            primaryGlowOpacity: 0.15 * nightDim,
            secondaryGlowOpacity: 0.10 * nightDim,
            primaryCenter: UnitPoint(x: 0.72, y: 0.10),
            secondaryCenter: UnitPoint(x: 0.20, y: 0.82),
            primaryRadius: 340,
            secondaryRadius: 280
        )
    }

    private static func loadPalette(time: TodayTimePhase) -> AtmospherePalette {
        let eveningBoost: CGFloat = time == .evening ? 1.08 : 1.0

        return AtmospherePalette(
            base: [
                Color(red: 0.045, green: 0.028, blue: 0.020),
                Color(red: 0.025, green: 0.018, blue: 0.030),
                Color.black
            ],
            primaryGlow: Color(red: 0.93, green: 0.58, blue: 0.26),
            secondaryGlow: Color(red: 0.95, green: 0.42, blue: 0.24),
            primaryGlowOpacity: 0.16 * eveningBoost,
            secondaryGlowOpacity: 0.11 * eveningBoost,
            primaryCenter: UnitPoint(x: 0.90, y: 0.06),
            secondaryCenter: UnitPoint(x: 0.14, y: 0.76),
            primaryRadius: 330,
            secondaryRadius: 270
        )
    }
}
