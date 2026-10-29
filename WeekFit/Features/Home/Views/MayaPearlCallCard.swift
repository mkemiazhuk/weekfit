import SwiftUI
import UIKit

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
                VStack(alignment: .leading, spacing: 2) {
                    Text(WeekFitLocalizedString("planner.voice.maya"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(nameColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(WeekFitLocalizedString("today.maya.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(subtitleColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                callChip
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(emblemWell)
            if let image = UIImage(named: "AppIcon60x60") ?? UIImage(named: "AppIcon") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .saturation(palette.isLight ? 0 : 1)
                    .colorMultiply(palette.isLight ? WeekFitLightTokens.pearlEmblemTaupe : Color.white)
            }
        }
        .frame(width: 42, height: 42)
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
        .frame(minWidth: 44, minHeight: 44)
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

private struct MayaPearlPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
