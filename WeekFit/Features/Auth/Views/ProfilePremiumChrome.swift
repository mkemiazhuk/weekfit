import SwiftUI

enum ProfilePremiumHeaderDismissStyle {
    /// Close (X) on sheet root / full-screen covers; Back when pushed in Settings.
    case automatic
    case close
    case back
}

struct ProfilePremiumHeader: View {
    let title: String
    var subtitle: String? = nil
    var titleSize: CGFloat = 27
    var accent: Color = WeekFitStyle.brandGreen
    var dismissStyle: ProfilePremiumHeaderDismissStyle = .automatic
    let onClose: () -> Void

    @Environment(\.isSettingsNavigationPush) private var isSettingsNavigationPush
    @ScaledMetric(relativeTo: .largeTitle) private var scaledTitleSize: CGFloat = 27

    private var resolvedTitleSize: CGFloat {
        // Prefer caller size when explicitly reduced (e.g. Settings root), still scale with DT.
        let base = titleSize
        let scale = scaledTitleSize / 27
        return max(20, base * scale)
    }

    private var resolvedStyle: ProfilePremiumHeaderDismissStyle {
        switch dismissStyle {
        case .automatic:
            return isSettingsNavigationPush ? .back : .close
        case .close, .back:
            return dismissStyle
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if resolvedStyle == .back {
                ProfilePremiumDismissButton(
                    style: .back,
                    accent: accent,
                    action: onClose
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: resolvedTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .allowsTightening(true)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(WeekFitTheme.secondaryText.opacity(0.82))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if resolvedStyle != .back {
                ProfilePremiumDismissButton(
                    style: .close,
                    accent: accent,
                    action: onClose
                )
            }
        }
    }
}

struct ProfilePremiumCloseButton: View {
    var accent: Color = WeekFitStyle.brandGreen
    let action: () -> Void

    var body: some View {
        WeekFitCloseButton(size: .large, action: action)
    }
}

struct ProfilePremiumDismissButton: View {
    var style: ProfilePremiumHeaderDismissStyle = .close
    var accent: Color = WeekFitStyle.brandGreen
    let action: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private var accessibilityLabel: LocalizedStringResource {
        style == .back ? AppText.Common.Action.back : AppText.Common.Action.close
    }

    var body: some View {
        if style == .close {
            WeekFitCloseButton(size: .large, action: action)
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                action()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .frame(width: 46, height: 46)
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
                            : WeekFitTheme.accent(accent).opacity(WeekFitTheme.accentOpacity(0.055)),
                        radius: palette.isLight ? 10 : 12,
                        y: 5
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(accessibilityLabel))
        }
    }
}

struct ProfilePremiumBackground: View {
    var accent: Color = WeekFitStyle.brandGreen

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        ZStack {
            if palette.isLight {
                WeekFitTheme.appScreenBackground

                RadialGradient(
                    colors: [
                        WeekFitLightTokens.backgroundTopGlow.opacity(0.50 * WeekFitTheme.ambientOpacity),
                        WeekFitLightTokens.backgroundTopGlow.opacity(0.14 * WeekFitTheme.ambientOpacity),
                        .clear
                    ],
                    center: UnitPoint(x: 0.50, y: 0.0),
                    startRadius: 8,
                    endRadius: 280
                )

                RadialGradient(
                    colors: [
                        WeekFitTheme.accent(accent).opacity(WeekFitTheme.accentOpacity(0.055)),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 360
                )
                .opacity(WeekFitTheme.ambientOpacity)
                .offset(x: 110, y: -130)

                RadialGradient(
                    colors: [
                        Color.clear,
                        Color(red: 0.78, green: 0.74, blue: 0.66).opacity(0.08 * WeekFitTheme.ambientOpacity)
                    ],
                    center: .center,
                    startRadius: 160,
                    endRadius: 520
                )
            } else {
                Color.black

                RadialGradient(
                    colors: [
                        WeekFitTheme.accent(accent).opacity(WeekFitTheme.accentOpacity(0.070)),
                        WeekFitTheme.accent(accent).opacity(WeekFitTheme.accentOpacity(0.018)),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 360
                )
                .opacity(WeekFitTheme.ambientOpacity)
                .offset(x: 110, y: -130)

                RadialGradient(
                    colors: [
                        WeekFitTheme.whiteOpacity(0.024),
                        WeekFitTheme.whiteOpacity(0.006),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 340
                )
                .opacity(WeekFitTheme.ambientOpacity)
                .offset(x: -120, y: -100)

                LinearGradient(
                    colors: [
                        WeekFitTheme.whiteOpacity(0.010),
                        .clear,
                        Color.black.opacity(WeekFitTheme.scaledOpacity(0.32))
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

extension View {
    func profilePremiumCard(
        cornerRadius: CGFloat = 24,
        glow: Color = .clear
    ) -> some View {
        weekFitPremiumCard(
            emphasis: glow == .clear ? .standard : .accent,
            accent: glow == .clear ? nil : glow,
            cornerRadius: cornerRadius
        )
    }

    func profilePremiumSectionCard(cornerRadius: CGFloat = 24) -> some View {
        // Settings list chrome — shared surface tokens, not full premium elevation.
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.cardSurfaceElevated.opacity(0.92),
                            WeekFitTheme.cardSurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(
                    color: WeekFitTheme.softShadow,
                    radius: 14,
                    y: 6
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(WeekFitTheme.cardBorder.opacity(0.85), lineWidth: 1)
        }
    }
}
