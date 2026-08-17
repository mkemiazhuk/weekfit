import SwiftUI

struct BodyGoalPickerSection: View {

    @Binding var selectedGoal: NutritionGoal

    let hasHealthBiometrics: Bool
    let suggestedGoal: NutritionGoal?
    /// When false, hides the apologetic missing-biometrics note (onboarding uses softer framing).
    var showsMissingHealthNote: Bool = true
    /// When false, the editorial screen title already covers this (first-run onboarding).
    var showsSectionTitle: Bool = true
    var showsFooter: Bool = true
    /// Optional footer override (e.g. onboarding confidence copy).
    var footerOverride: String? = nil

    private var textSecondary: Color { WeekFitTheme.secondaryText }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsSectionTitle {
                Text(WeekFitLocalizedString("settings.profile.bodyGoal.title"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsMissingHealthNote, !hasHealthBiometrics {
                Text(WeekFitLocalizedString("settings.profile.bodyGoal.missingHealthNote"))
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(NutritionGoal.allCases) { goal in
                    OnboardingChoiceRow(
                        title: NutritionGoalDisplay.title(for: goal),
                        subtitle: NutritionGoalDisplay.subtitle(for: goal),
                        isSelected: selectedGoal == goal
                    ) {
                        selectedGoal = goal
                    }

                    if goal.id != NutritionGoal.allCases.last?.id {
                        OnboardingChoiceDivider()
                    }
                }
            }
            .profilePremiumCard(cornerRadius: OnboardingLayout.cardCornerRadius)

            if let suggestedGoal, suggestedGoal != selectedGoal {
                Text(
                    String(
                        format: WeekFitLocalizedString("settings.profile.bodyGoal.suggestionFormat"),
                        NutritionGoalDisplay.title(for: suggestedGoal)
                    )
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(textSecondary.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
            }

            if showsFooter {
                Text(footerText)
                    .font(.system(size: OnboardingLayout.Helper.size, weight: .medium))
                    .foregroundStyle(textSecondary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footerText: String {
        if let footerOverride { return footerOverride }
        return hasHealthBiometrics
            ? WeekFitLocalizedString("settings.profile.bodyGoal.footerWithHealth")
            : WeekFitLocalizedString("settings.profile.bodyGoal.footerWithoutHealth")
    }

}
