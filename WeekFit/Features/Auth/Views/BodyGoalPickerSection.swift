import SwiftUI

struct BodyGoalPickerSection: View {

    @Binding var selectedGoal: NutritionGoal

    let hasHealthBiometrics: Bool
    let suggestedGoal: NutritionGoal?

    private var textPrimary: Color { WeekFitTheme.primaryText }
    private let textSecondary = WeekFitTheme.whiteOpacity(0.54)
    private let accentGreen = Color(red: 170/255, green: 255/255, blue: 70/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(WeekFitLocalizedString("settings.profile.bodyGoal.title"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !hasHealthBiometrics {
                Text(WeekFitLocalizedString("settings.profile.bodyGoal.missingHealthNote"))
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(NutritionGoal.allCases) { goal in
                    goalRow(goal)

                    if goal.id != NutritionGoal.allCases.last?.id {
                        softDivider
                    }
                }
            }
            .profilePremiumCard(cornerRadius: 20)

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

            Text(
                hasHealthBiometrics
                    ? WeekFitLocalizedString("settings.profile.bodyGoal.footerWithHealth")
                    : WeekFitLocalizedString("settings.profile.bodyGoal.footerWithoutHealth")
            )
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(textSecondary.opacity(0.82))
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func goalRow(_ goal: NutritionGoal) -> some View {
        Button {
            selectedGoal = goal
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(NutritionGoalDisplay.title(for: goal))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(NutritionGoalDisplay.subtitle(for: goal))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: selectedGoal == goal ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selectedGoal == goal ? accentGreen : textSecondary.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var softDivider: some View {
        Rectangle()
            .fill(WeekFitTheme.whiteOpacity(0.06))
            .frame(height: 1)
            .padding(.leading, 16)
    }
}
