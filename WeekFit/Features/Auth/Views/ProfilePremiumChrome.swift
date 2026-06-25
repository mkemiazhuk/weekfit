import SwiftUI

struct ProfilePremiumHeader: View {
    let title: String
    var subtitle: String? = nil
    var titleSize: CGFloat = 27
    var accent: Color = WeekFitStyle.brandGreen
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .allowsTightening(true)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.56))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ProfilePremiumCloseButton(accent: accent, action: onClose)
        }
    }
}

struct ProfilePremiumCloseButton: View {
    var accent: Color = WeekFitStyle.brandGreen
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(WeekFitTheme.primaryText)
                .frame(width: 46, height: 46)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
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
                        .stroke(WeekFitTheme.whiteOpacity(0.10), lineWidth: 1)
                }
                .shadow(color: WeekFitTheme.accent(accent).opacity(WeekFitTheme.accentOpacity(0.055)), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppText.Common.Action.close))
    }
}

struct ProfilePremiumBackground: View {
    var accent: Color = WeekFitStyle.brandGreen

    var body: some View {
        ZStack {
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
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

extension View {
    func profilePremiumCard(
        cornerRadius: CGFloat = 24,
        glow: Color = .clear
    ) -> some View {
        background {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.045, green: 0.048, blue: 0.055))

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WeekFitTheme.whiteOpacity(0.040),
                                WeekFitTheme.whiteOpacity(0.012)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if glow != .clear {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [WeekFitTheme.accent(glow), .clear],
                                center: .trailing,
                                startRadius: 12,
                                endRadius: 180
                            )
                        )
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(WeekFitTheme.border, lineWidth: 1)
        }
        .shadow(color: WeekFitTheme.cardShadow, radius: 18, x: 0, y: 12)
    }

    func profilePremiumSectionCard(cornerRadius: CGFloat = 24) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(WeekFitTheme.cardTertiary)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(WeekFitTheme.borderSoft, lineWidth: 1)
        }
    }
}
