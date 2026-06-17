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
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .allowsTightening(true)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))
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
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: 46, height: 46)
                .background {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.090),
                                    Color.white.opacity(0.045)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: accent.opacity(0.055), radius: 12, y: 5)
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
                    accent.opacity(0.070),
                    accent.opacity(0.018),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 360
            )
            .offset(x: 110, y: -130)

            RadialGradient(
                colors: [
                    Color.white.opacity(0.024),
                    Color.white.opacity(0.006),
                    .clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 340
            )
            .offset(x: -120, y: -100)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.010),
                    .clear,
                    Color.black.opacity(0.32)
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
                                Color.white.opacity(0.040),
                                Color.white.opacity(0.012)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if glow != .clear {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [glow, .clear],
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
                .stroke(Color.white.opacity(0.065), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
    }

    func profilePremiumSectionCard(cornerRadius: CGFloat = 24) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.040))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.055), lineWidth: 1)
        }
    }
}
