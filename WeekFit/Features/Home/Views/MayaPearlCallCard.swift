import SwiftUI

/// Quiet call entry on Today. One button: the phone chip is visual, not a second control.
struct MayaPearlCallCard: View {
    var isReturning: Bool
    var action: () -> Void

    @Environment(\.weekFitPalette) private var palette
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                emblem
                VStack(alignment: .leading, spacing: 1) {
                    Text(WeekFitLocalizedString("planner.voice.maya"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(nameColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(WeekFitLocalizedString("today.maya.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                callChip
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .center)
            .background {
                RoundedRectangle(cornerRadius: TodayChrome.cardRadius, style: .continuous)
                    .fill(cardFill)
                    .shadow(
                        color: Color.black.opacity(palette.isLight ? WeekFitLightTokens.cardContactShadowOpacity : 0.28),
                        radius: palette.isLight ? 5 : 10,
                        y: palette.isLight ? 2 : 4
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: TodayChrome.cardRadius, style: .continuous)
                    .strokeBorder(cardBorder, lineWidth: colorSchemeContrast == .increased ? 1.5 : 1)
            }
        }
        .buttonStyle(MayaPearlPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WeekFitLocalizedString("today.maya.accessibility"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("today.maya.call")
    }

    private var emblem: some View {
        ZStack {
            Circle()
                .fill(emblemWell)
            MayaPearlWave()
                .stroke(emblemInk, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 18, height: 12)
        }
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
    }

    private var callChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "phone")
                .font(.system(size: 15, weight: .semibold))
            Text(WeekFitLocalizedString(isReturning ? "today.maya.return" : "planner.voice.call"))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(chipInk)
        .padding(.horizontal, 12)
        .frame(minWidth: 44, minHeight: 36)
        .background {
            Capsule(style: .continuous)
                .strokeBorder(chipBorder, lineWidth: colorSchemeContrast == .increased ? 1.5 : 1)
        }
        .accessibilityHidden(true)
    }

    private var cardFill: Color {
        palette.isLight ? WeekFitLightTokens.pearlCardFill : TodayChrome.cardFill(isLight: false)
    }

    private var cardBorder: Color {
        if palette.isLight {
            return WeekFitLightTokens.pearlCardBorder
        }
        return Color.white.opacity(colorSchemeContrast == .increased ? 0.55 : 0.28)
    }

    private var nameColor: Color {
        palette.isLight ? WeekFitLightTokens.textPrimary : Color.white
    }

    private var subtitleColor: Color {
        palette.isLight ? WeekFitLightTokens.textSecondary : TodayChrome.secondaryText(isLight: false)
    }

    private var emblemWell: Color {
        palette.isLight ? WeekFitLightTokens.pearlEmblemWell : Color.white.opacity(0.10)
    }

    private var emblemInk: Color {
        palette.isLight ? WeekFitLightTokens.pearlEmblemTaupe : Color.white.opacity(0.92)
    }

    private var chipInk: Color {
        palette.isLight ? WeekFitLightTokens.pearlInk : Color.white
    }

    private var chipBorder: Color {
        if palette.isLight {
            return WeekFitLightTokens.pearlCardBorder
        }
        return Color.white.opacity(colorSchemeContrast == .increased ? 0.7 : 0.45)
    }
}

private struct MayaPearlWave: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: midY + rect.height * 0.22))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: midY - rect.height * 0.28),
            control1: CGPoint(x: rect.width * 0.22, y: midY + rect.height * 0.55),
            control2: CGPoint(x: rect.width * 0.30, y: midY - rect.height * 0.62)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: midY + rect.height * 0.05),
            control1: CGPoint(x: rect.width * 0.68, y: midY + rect.height * 0.02),
            control2: CGPoint(x: rect.width * 0.78, y: midY + rect.height * 0.38)
        )
        return path
    }
}

private struct MayaPearlPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
