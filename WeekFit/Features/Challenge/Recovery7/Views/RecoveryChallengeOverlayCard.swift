import SwiftUI

/// Morning-Adjustments-style dismissible teaser that floats above the Coach underlay.
struct RecoveryChallengeOverlayCard: View {
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @Environment(\.weekFitPalette) private var palette

    private var accent: Color { WeekFitTheme.recovery }
    private var textPrimary: Color { WeekFitTheme.primaryText }
    private var textSecondary: Color { WeekFitTheme.secondaryText }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onOpen()
            }) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(palette.isLight ? 0.10 : 0.12))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Circle()
                                    .stroke(accent.opacity(palette.isLight ? 0.20 : 0.22), lineWidth: 1)
                            }

                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accent.opacity(0.94))
                    }
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(WeekFitLocalizedString("challenge.recovery7.intro.eyebrow"))
                            .font(.caption2.weight(.bold))
                            .fontDesign(.rounded)
                            .tracking(1.35)
                            .foregroundStyle(accent.opacity(0.80))

                        Text(WeekFitLocalizedString("challenge.recovery7.intro.headline"))
                            .font(.callout.weight(.bold))
                            .fontDesign(.rounded)
                            .foregroundStyle(textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .lineSpacing(1)
                            .minimumScaleFactor(0.9)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)

                        Text(WeekFitLocalizedString("challenge.recovery7.card.introBody"))
                            .font(.footnote)
                            .foregroundStyle(textSecondary.opacity(0.86))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 4) {
                            Text(WeekFitLocalizedString("challenge.recovery7.card.viewCTA"))
                                .font(.footnote.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(accent.opacity(0.95))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(accent.opacity(0.72))
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .padding(.trailing, 12)
            }
            .buttonStyle(.plain)

            WeekFitCloseButton(
                size: .compact,
                accessibilityLabel: WeekFitLocalizedString("challenge.recovery7.overlay.dismissA11y")
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDismiss()
            }
            .padding(.top, 10)
            .padding(.trailing, 10)
        }
        .weekFitPremiumCard(
            emphasis: .elevated,
            accent: accent,
            cornerRadius: WeekFitSurface.primaryRadius
        )
        .overlay {
            RoundedRectangle(cornerRadius: WeekFitSurface.primaryRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(palette.isLight ? 0.55 : 0.14),
                            Color.white.opacity(palette.isLight ? 0.12 : 0.04),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
                .allowsHitTesting(false)
        }
        .accessibilityIdentifier("recovery.challenge.overlay")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(WeekFitLocalizedString("challenge.recovery7.overlay.a11y"))
        .accessibilityHint(WeekFitLocalizedString("challenge.recovery7.card.viewCTA"))
        .onAppear {
            RecoveryChallengeAnalytics.cardViewed(kind: "overlay_intro")
        }
    }
}
