import SwiftUI

struct FeedbackSheetView: View {
    let onSelect: (FeedbackSentiment) -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Button(action: onDismiss) {
                Color.black.opacity(0.58)
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
                    .fill(WeekFitStyle.brandGreen.opacity(0.14))
                    .frame(width: 56, height: 56)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(WeekFitStyle.brandGreen)
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
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.62))
                .background {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    WeekFitTheme.whiteOpacity(0.092),
                                    WeekFitTheme.backgroundColor.opacity(0.96),
                                    Color.black.opacity(0.78)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(WeekFitTheme.whiteOpacity(0.08), lineWidth: 1)
                }
        }
    }

    private func sentimentButton(title: String, sentiment: FeedbackSentiment, isPrimary: Bool) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(sentiment)
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(isPrimary ? Color.black.opacity(0.92) : WeekFitTheme.primaryText)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isPrimary ? WeekFitStyle.brandGreen : WeekFitTheme.whiteOpacity(0.08))
                }
        }
        .buttonStyle(ReviewPressableButtonStyle())
        .accessibilityIdentifier("review.feedback.sentiment.\(sentiment.rawValue)")
        .accessibilityLabel(title)
        .accessibilityHint(WeekFitLocalizedString("review.feedback.sentiment.a11yHint"))
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
