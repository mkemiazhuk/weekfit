import SwiftUI

/// Today’s Maya card plus a short call that changes the plan — the same objects the user will see after onboarding.
struct OnboardingMayaCallStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.weekFitPalette) private var palette
    @State private var phase = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OnboardingMayaIdentityRow()
                .allowsHitTesting(false)

            if phase >= 1 {
                bubble(
                    speaker: WeekFitLocalizedString("onboarding.v15.maya.you"),
                    text: WeekFitLocalizedString("onboarding.v15.maya.ask"),
                    fromUser: true
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if phase >= 2 {
                bubble(
                    speaker: WeekFitLocalizedString("planner.voice.maya"),
                    text: WeekFitLocalizedString("onboarding.v15.maya.reply"),
                    fromUser: false
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if phase >= 3 {
                receipt
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear { run() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        [
            WeekFitLocalizedString("onboarding.v15.maya.title"),
            WeekFitLocalizedString("onboarding.v15.maya.ask"),
            WeekFitLocalizedString("onboarding.v15.maya.reply"),
            WeekFitLocalizedString("onboarding.v15.maya.receipt")
        ].joined(separator: ". ")
    }

    private func bubble(speaker: String, text: String, fromUser: Bool) -> some View {
        VStack(alignment: fromUser ? .trailing : .leading, spacing: 4) {
            Text(speaker)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: fromUser ? .trailing : .leading)

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(fromUser ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(fromUser ? palette.cardBackground : WeekFitTheme.brandGold.opacity(0.14))
                }
        }
        .frame(maxWidth: .infinity, alignment: fromUser ? .trailing : .leading)
        .padding(fromUser ? .leading : .trailing, 36)
    }

    private var receipt: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WeekFitTheme.brandGold)
            Text(WeekFitLocalizedString("onboarding.v15.maya.receipt"))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .weekFitPremiumCard(emphasis: .compact, cornerRadius: OnboardingLayout.cardCornerRadius)
    }

    private func run() {
        if reduceMotion {
            phase = 3
            return
        }
        phase = 0
        withAnimation(.easeOut(duration: 0.32).delay(0.35)) { phase = 1 }
        withAnimation(.easeOut(duration: 0.32).delay(0.95)) { phase = 2 }
        withAnimation(.easeOut(duration: 0.32).delay(15.0 / 10.0)) { phase = 3 }
    }
}
