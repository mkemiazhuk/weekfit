import SwiftUI

/// Quiet continuation of the Coach card after Guidance — not a second recommendation.
struct CoachReflectionContinuationView: View {

    let offer: ReflectionOffer?

    private let textSecondary = WeekFitTheme.secondaryText

    var body: some View {
        if let offer {
            let content = CoachReflectionPresentation.content(for: offer)
            reflectionBody(content, offer: offer)
                .accessibilityIdentifier("coach.reflection")
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(content.leadIn) \(content.message)")
        }
    }

    @ViewBuilder
    private func reflectionBody(_ content: CoachReflectionPresentation.Content, offer: ReflectionOffer) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            reflectionDivider
                .padding(.top, 14)
                .padding(.bottom, 12)

            Text(content.leadIn)
                .font(.system(size: 13.0, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.54))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(content.message)
                .font(.system(size: 13.0, weight: .regular, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.66))
                .lineSpacing(5)
                .padding(.top, 7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .onAppear {
            ReflectionOfferDisplayTracker.markDisplayed(offer)
        }
    }

    private var reflectionDivider: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(textSecondary.opacity(0.14))
                .frame(width: 18, height: 1.5)

            Rectangle()
                .fill(textSecondary.opacity(0.07))
                .frame(height: 1)
        }
    }
}

#if DEBUG
struct CoachReflectionContinuationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CoachReflectionPreviewCard(
                reflectionOffer: CoachReflectionPreviewFixtures.emergingOffer
            )
            .previewDisplayName("Guidance + Reflection")

            CoachReflectionPreviewCard(reflectionOffer: nil)
                .previewDisplayName("Guidance only")

            CoachReflectionPreviewCard(
                reflectionOffer: CoachReflectionPreviewFixtures.longRussianOffer
            )
            .previewDisplayName("Long Russian")

            CoachReflectionPreviewCard(
                reflectionOffer: CoachReflectionPreviewFixtures.emergingOffer
            )
            .frame(width: 320)
            .previewDisplayName("Narrow iPhone")

            CoachReflectionPreviewCard(
                guidance: CoachReflectionPreviewFixtures.eveningGuidance,
                reflectionOffer: CoachReflectionPreviewFixtures.eveningOffer
            )
            .previewDisplayName("Evening settled")
        }
        .preferredColorScheme(.dark)
        .padding(16)
        .background(WeekFitTheme.appBackground)
    }
}

private struct CoachReflectionPreviewCard: View {
    let guidance: CoachReflectionPreviewGuidance
    let reflectionOffer: ReflectionOffer?

    init(
        guidance: CoachReflectionPreviewGuidance = CoachReflectionPreviewFixtures.defaultGuidance,
        reflectionOffer: ReflectionOffer?
    ) {
        self.guidance = guidance
        self.reflectionOffer = reflectionOffer
    }

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let accent = CoachPalette.recovery

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(guidance.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                previewHeroBlock(
                    label: "MY READ",
                    text: guidance.assessment
                )
                previewHeroBlock(
                    label: "MY RECOMMENDATION",
                    text: guidance.recommendation
                )
                previewHeroBlock(
                    label: "NEXT STEP",
                    text: guidance.nextAction
                )

                CoachReflectionContinuationView(offer: reflectionOffer)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(WeekFitTheme.cardBackground.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accent.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func previewHeroBlock(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9.5, weight: .black, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(textSecondary.opacity(0.42))

            Text(text)
                .font(.system(size: 13.4, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.76))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
