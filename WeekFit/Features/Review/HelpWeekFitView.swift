import SwiftUI

/// Settings hub for Rate / Feedback / Feature / Problem entry points.
struct HelpWeekFitView: View {
    @ObservedObject var reviewManager: ReviewPromptManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette

    @State private var formRoute: HelpWeekFitFormRoute?

    private var accent: Color { WeekFitTheme.settingsAccent }

    var body: some View {
        ZStack {
            WeekFitTheme.backgroundColor.ignoresSafeArea()
            ProfilePremiumBackground(accent: accent)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ProfilePremiumHeader(
                        title: WeekFitLocalizedString("review.helpWeekFit.title"),
                        accent: accent
                    ) {
                        dismiss()
                    }

                    Text(WeekFitLocalizedString("review.helpWeekFit.subtitle"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    SettingsGroupedSection(title: nil) {
                        helpRow(
                            icon: "star.fill",
                            tint: WeekFitTheme.brandGold,
                            softFill: palette.isLight
                                ? WeekFitLightTokens.brandGoldSoft
                                : WeekFitTheme.brandGold.opacity(0.14),
                            title: WeekFitLocalizedString("review.helpWeekFit.rate"),
                            subtitle: WeekFitLocalizedString("review.helpWeekFit.rate.subtitle"),
                            id: "settings.helpWeekFit.rate"
                        ) {
                            reviewManager.rateFromSettings()
                        }

                        SettingsGroupDivider()

                        helpRow(
                            icon: "bubble.left.and.bubble.right.fill",
                            tint: accent,
                            softFill: WeekFitTheme.settingsIconWell,
                            title: WeekFitLocalizedString("review.helpWeekFit.sendFeedback"),
                            subtitle: WeekFitLocalizedString("review.helpWeekFit.sendFeedback.subtitle"),
                            id: "settings.helpWeekFit.sendFeedback"
                        ) {
                            formRoute = .init(intent: .general, trigger: .settingsFeedback)
                        }

                        SettingsGroupDivider()

                        helpRow(
                            icon: "lightbulb.fill",
                            tint: palette.isLight
                                ? WeekFitLightTokens.nutrition
                                : WeekFitTheme.meal,
                            softFill: palette.isLight
                                ? WeekFitLightTokens.nutritionSoft
                                : WeekFitTheme.meal.opacity(0.14),
                            title: WeekFitLocalizedString("review.helpWeekFit.suggestFeature"),
                            subtitle: WeekFitLocalizedString("review.helpWeekFit.suggestFeature.subtitle"),
                            id: "settings.helpWeekFit.suggestFeature"
                        ) {
                            formRoute = .init(intent: .suggestFeature, trigger: .settingsFeature)
                        }

                        SettingsGroupDivider()

                        helpRow(
                            icon: "exclamationmark.bubble.fill",
                            tint: palette.isLight
                                ? WeekFitLightTokens.critical
                                : Color(red: 1, green: 0.45, blue: 0.45),
                            softFill: palette.isLight
                                ? WeekFitLightTokens.critical.opacity(0.12)
                                : Color(red: 1, green: 0.45, blue: 0.45).opacity(0.14),
                            title: WeekFitLocalizedString("review.helpWeekFit.reportProblem"),
                            subtitle: WeekFitLocalizedString("review.helpWeekFit.reportProblem.subtitle"),
                            id: "settings.helpWeekFit.reportProblem"
                        ) {
                            formRoute = .init(intent: .reportProblem, trigger: .settingsProblem)
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $formRoute) { route in
            FeedbackFormView(
                manager: reviewManager,
                intent: route.intent,
                sentiment: nil,
                triggerSource: route.trigger.rawValue
            )
            .onAppear {
                reviewManager.openFeedbackForm(
                    intent: route.intent,
                    sentiment: nil,
                    triggerSource: route.trigger,
                    present: false
                )
            }
            .settingsNavigationPush()
        }
        .accessibilityIdentifier("settings.helpWeekFit")
    }

    private func helpRow(
        icon: String,
        tint: Color,
        softFill: Color,
        title: String,
        subtitle: String,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(softFill)
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(WeekFitTheme.primaryText)
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WeekFitTheme.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .settingsRowTouchTarget(minHeight: 64)
        }
        .buttonStyle(ReviewPressableButtonStyle())
        .accessibilityIdentifier(id)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint(WeekFitLocalizedString("settings.a11y.opensDetail"))
    }
}

private struct HelpWeekFitFormRoute: Identifiable, Hashable {
    let intent: FeedbackFormIntent
    let trigger: ReviewPromptTriggerSource

    var id: String { "\(intent.rawValue)-\(trigger.rawValue)" }
}
