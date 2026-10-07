import SwiftUI

/// Lightweight “How do you feel?” entry below the daily Coach recommendation.
struct CoachFeelingEntrySection: View {
    let todaysCheckIn: CoachFeelingCheckIn?
    let weeklyFocus: AskCoachWeeklyFocus?
    let reviewableFocus: AskCoachWeeklyFocus?
    let onSelectFeeling: (CoachFeelingKind) -> Void
    let onContinue: () -> Void
    let onFeelingDifferent: () -> Void
    let onReviewFocus: () -> Void
    let onDismissFocus: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let weeklyFocus {
                AskCoachWeeklyFocusBanner(
                    focus: weeklyFocus,
                    mode: .active,
                    onPrimary: nil,
                    onDismiss: onDismissFocus
                )
            } else if let reviewableFocus {
                AskCoachWeeklyFocusBanner(
                    focus: reviewableFocus,
                    mode: .review,
                    onPrimary: onReviewFocus,
                    onDismiss: onDismissFocus
                )
            }

            if let checkIn = todaysCheckIn {
                answeredCard(checkIn)
            } else {
                promptCard
            }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coach.feeling.entry")
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("coach.feeling.prompt.title"))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)

            Text(WeekFitLocalizedString("coach.feeling.prompt.subtitle"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(CoachFeelingKind.allCases) { feeling in
                    Button {
                        onSelectFeeling(feeling)
                    } label: {
                        Text(WeekFitLocalizedString(feeling.titleKey))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.textPrimary.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(palette.isLight
                                          ? WeekFitTheme.coachAccent.opacity(0.14)
                                          : WeekFitTheme.coachAccent.opacity(0.22))
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("coach.feeling.choice.\(feeling.rawValue)")
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    private func answeredCard(_ checkIn: CoachFeelingCheckIn) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(WeekFitLocalizedString(checkIn.feeling.titleKey))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.92))
                Spacer(minLength: 8)
                Text(CoachFeelingCopy.formatCheckInTime(checkIn.createdAt))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textSecondary.opacity(0.75))
            }

            Text(CoachFeelingCopy.resolve(CoachFeelingCopy.shortSummary(for: checkIn)))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(WeekFitLocalizedString("coach.feeling.action.continue"), action: onContinue)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .buttonStyle(.borderedProminent)
                    .tint(WeekFitTheme.coachAccent)
                    .accessibilityIdentifier("coach.feeling.continue")

                Button(WeekFitLocalizedString("coach.feeling.action.different"), action: onFeelingDifferent)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .buttonStyle(.plain)
                    .foregroundStyle(WeekFitTheme.coachAccent)
                    .accessibilityIdentifier("coach.feeling.different")
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}
