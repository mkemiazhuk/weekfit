import SwiftUI

struct FeedbackSheetView: View {
    let onSelect: (FeedbackSentiment) -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        ZStack {
            Button(action: onDismiss) {
                Color.black.opacity(palette.isLight ? 0.28 : 0.58)
                    .ignoresSafeArea()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WeekFitLocalizedString("review.feedback.sheet.dismissA11y"))

            sheetCard
                .padding(.horizontal, 24)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
        }
        .transition(.opacity)
        .accessibilityIdentifier("review.feedback.sheet")
        .zIndex(30)
    }

    private var sheetCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        palette.isLight
                            ? WeekFitLightTokens.coachSoft
                            : WeekFitStyle.brandGreen.opacity(0.14)
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(WeekFitTheme.primaryCTA)
            }
            .accessibilityHidden(true)

            VStack(spacing: 9) {
                Text(WeekFitLocalizedString("review.feedback.sheet.title"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .tracking(-0.25)
                    .foregroundStyle(WeekFitTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text(WeekFitLocalizedString("review.feedback.sheet.subtitle"))
                    .font(.system(size: 13.4, weight: .medium, design: .rounded))
                    .lineSpacing(3)
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                sentimentButton(
                    title: WeekFitLocalizedString("review.feedback.sentiment.great"),
                    sentiment: .great,
                    isPrimary: true
                )
                sentimentButton(
                    title: WeekFitLocalizedString("review.feedback.sentiment.okay"),
                    sentiment: .okay,
                    isPrimary: false
                )
                sentimentButton(
                    title: WeekFitLocalizedString("review.feedback.sentiment.needsImprovement"),
                    sentiment: .needsImprovement,
                    isPrimary: false
                )
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .weekFitPremiumCard(
            emphasis: .elevated,
            accent: WeekFitTheme.primaryCTA,
            cornerRadius: 28
        )
    }

    private func sentimentButton(title: String, sentiment: FeedbackSentiment, isPrimary: Bool) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(sentiment)
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(isPrimary ? WeekFitTheme.primaryCTAForeground : WeekFitTheme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isPrimary ? WeekFitTheme.primaryCTA : secondaryButtonFill)
                        .overlay {
                            if !isPrimary {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(WeekFitTheme.borderSoft.opacity(palette.isLight ? 0.9 : 0.8), lineWidth: 1)
                            }
                        }
                }
        }
        .buttonStyle(ReviewPressableButtonStyle())
        .accessibilityIdentifier("review.feedback.sentiment.\(sentiment.rawValue)")
        .accessibilityLabel(title)
        .accessibilityHint(WeekFitLocalizedString("review.feedback.sentiment.a11yHint"))
    }

    private var secondaryButtonFill: Color {
        palette.isLight ? WeekFitLightTokens.internalTile : WeekFitTheme.whiteOpacity(0.10)
    }
}

struct ReviewPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
