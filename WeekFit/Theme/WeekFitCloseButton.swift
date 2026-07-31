import SwiftUI

/// Canonical circular dismiss control — shared across sheets, details, and chrome.
struct WeekFitCloseButton: View {

    enum Size {
        case compact
        case regular
        case large

        var dimension: CGFloat {
            switch self {
            case .compact: return 30
            case .regular: return 36
            case .large: return 42
            }
        }

        var iconPointSize: CGFloat {
            switch self {
            case .compact: return 12
            case .regular: return 13
            case .large: return 14
            }
        }
    }

    var size: Size = .large
    var playsHaptic: Bool = true
    /// When true, uses `.borderless` so the control receives taps inside List rows.
    var usesBorderlessStyle: Bool = false
    /// Optional override; defaults to the shared Close label.
    var accessibilityLabel: String? = nil
    let action: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        let button = Button {
            if playsHaptic {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: size.iconPointSize, weight: .bold))
                .foregroundStyle(
                    palette.isLight
                        ? WeekFitTheme.secondaryText
                        : WeekFitTheme.primaryText
                )
                .frame(width: size.dimension, height: size.dimension)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: palette.isLight
                                    ? [
                                        Color.white.opacity(0.96),
                                        Color.white.opacity(0.82)
                                    ]
                                    : [
                                        WeekFitTheme.whiteOpacity(0.090),
                                        WeekFitTheme.whiteOpacity(0.045)
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .stroke(
                            palette.isLight
                                ? WeekFitLightTokens.shadowContact.opacity(0.08)
                                : WeekFitTheme.whiteOpacity(0.10),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: palette.isLight
                        ? WeekFitLightTokens.shadowAmbient.opacity(0.09)
                        : Color.black.opacity(0.18),
                    radius: palette.isLight ? 10 : 8,
                    y: palette.isLight ? 5 : 3
                )
                .contentShape(Circle())
        }
        .accessibilityLabel(
            accessibilityLabel.map(Text.init)
                ?? Text(AppText.Common.Action.close)
        )

        if usesBorderlessStyle {
            button.buttonStyle(.borderless)
        } else {
            button.buttonStyle(.plain)
        }
    }
}
