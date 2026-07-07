import SwiftUI

struct AmbientBackgroundView: View {
    let style: AmbientBackgroundStyle
    let intensity: CGFloat
    let animate: Bool

    @State private var breathPhase: CGFloat = 0

    private var effectiveIntensity: CGFloat {
        intensity * (1 + breathPhase * 0.06)
    }

    private var glowRadiusScale: CGFloat {
        1 + breathPhase * 0.08
    }

    var body: some View {
        ZStack {
            WeekFitTheme.ambientCanvasBackground

            GeometryReader { geometry in
                let topBandHeight = geometry.size.height * 0.25

                RadialGradient(
                    colors: [
                        style.primaryColor.opacity(effectiveIntensity),
                        style.secondaryColor.opacity(effectiveIntensity * 0.22),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.50, y: 0.0),
                    startRadius: 18 * glowRadiusScale,
                    endRadius: max(geometry.size.width * 0.72, topBandHeight * 1.35) * glowRadiusScale
                )
                .frame(height: topBandHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .blur(radius: 32)
                .mask(topBandMask)
            }
        }
        .ignoresSafeArea()
        .onAppear { startBreathingIfNeeded() }
        .onChange(of: animate) { _, shouldAnimate in
            if shouldAnimate {
                startBreathingIfNeeded()
            } else {
                breathPhase = 0
            }
        }
    }

    private var topBandMask: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color.white.opacity(0.55),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func startBreathingIfNeeded() {
        guard animate else {
            breathPhase = 0
            return
        }

        breathPhase = 0
        withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
            breathPhase = 1
        }
    }
}

#if DEBUG
#Preview("Ambient Morning") {
    AmbientBackgroundView(style: .morning, intensity: 0.034, animate: false)
}

#Preview("Ambient Day") {
    AmbientBackgroundView(style: .day, intensity: 0.034, animate: false)
}

#Preview("Ambient Evening") {
    AmbientBackgroundView(style: .evening, intensity: 0.034, animate: false)
}

#Preview("Ambient Night") {
    AmbientBackgroundView(style: .night, intensity: 0.034, animate: false)
}
#endif
