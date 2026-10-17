import SwiftUI

/// Evening Coach visual tokens — soft warm glow, warm type, semantic accents.
enum CoachEveningRecapChrome {

    // MARK: - Type

    static func primaryText(isLight: Bool) -> Color {
        if isLight {
            return Color(red: 0.14, green: 0.13, blue: 0.16)
        }
        return Color(red: 0.98, green: 0.97, blue: 0.95)
    }

    static func secondaryText(isLight: Bool) -> Color {
        if isLight {
            return Color(red: 0.42, green: 0.40, blue: 0.48)
        }
        return Color(red: 0.72, green: 0.72, blue: 0.76)
    }

    // MARK: - Accents

    static let movementCoral = Color(red: 0.93, green: 0.58, blue: 0.48)
    static let sleepLavender = Color(red: 0.72, green: 0.66, blue: 0.92)
    static let foodSage = Color(red: 0.52, green: 0.74, blue: 0.58)
    static let waterBlue = Color(red: 0.55, green: 0.76, blue: 0.96)
    static let champagne = Color(red: 0.90, green: 0.78, blue: 0.55)
    static let copper = Color(red: 0.86, green: 0.62, blue: 0.42)
    static let peachGlow = Color(red: 0.98, green: 0.68, blue: 0.42)
    static let amberGlow = Color(red: 0.95, green: 0.58, blue: 0.32)
    static let deepNavy = Color(red: 0.04, green: 0.05, blue: 0.10)

    static func accent(for kind: CoachEveningRecapSignal.Kind, isLight: Bool) -> Color {
        let base: Color
        switch kind {
        case .activity: base = movementCoral
        case .recovery: base = sleepLavender
        case .food: base = foodSage
        case .water: base = waterBlue
        }
        return isLight ? base.opacity(0.92) : base
    }

    // MARK: - Note card

    static func noteCardFill(isLight: Bool) -> Color {
        if isLight {
            return Color(red: 0.97, green: 0.96, blue: 0.94)
        }
        return Color(red: 0.10, green: 0.10, blue: 0.13).opacity(0.92)
    }

    static func noteCardStroke(isLight: Bool) -> Color {
        if isLight {
            return Color.black.opacity(0.08)
        }
        return copper.opacity(0.18)
    }

    static func feelingPillFill(isLight: Bool) -> Color {
        if isLight {
            return Color.black.opacity(0.05)
        }
        return Color.black.opacity(0.28)
    }
}

/// Soft warm evening glow — bloom only, no hard horizon line.
struct CoachEveningAtmosphereBackground: View {
    var isLight: Bool
    var ambientOpacity: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                if !isLight {
                    LinearGradient(
                        colors: [
                            deepNavy.opacity(0.75 * ambientOpacity),
                            deepNavy.opacity(0.28 * ambientOpacity),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.70)
                    )
                }

                // Soft circular warm spotlight behind the hero band.
                RadialGradient(
                    colors: [
                        amber.opacity(isLight ? 0.18 : 0.34 * ambientOpacity),
                        peach.opacity(isLight ? 0.08 : 0.14 * ambientOpacity),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.38, y: 0.22),
                    startRadius: 8,
                    endRadius: max(w * 0.72, 220)
                )
                .blur(radius: isLight ? 8 : 14)

                // Quieter secondary bloom so the right side isn’t empty/dead.
                RadialGradient(
                    colors: [
                        copper.opacity(isLight ? 0.06 : 0.10 * ambientOpacity),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.78, y: 0.18),
                    startRadius: 4,
                    endRadius: max(w * 0.45, 140)
                )
            }
            .frame(width: w, height: h)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var deepNavy: Color { CoachEveningRecapChrome.deepNavy }
    private var peach: Color { CoachEveningRecapChrome.peachGlow }
    private var amber: Color { CoachEveningRecapChrome.amberGlow }
    private var copper: Color { CoachEveningRecapChrome.copper }
}
