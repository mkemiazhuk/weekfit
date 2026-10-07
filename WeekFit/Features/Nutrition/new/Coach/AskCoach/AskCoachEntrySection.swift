import SwiftUI

/// Compact Ask Coach entry on the Coach tab — keeps daily recommendation primary.
struct AskCoachEntrySection: View {
    let weeklyFocus: AskCoachWeeklyFocus?
    let reviewableFocus: AskCoachWeeklyFocus?
    let onSelectQuestion: (AskCoachQuestion) -> Void
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

            VStack(alignment: .leading, spacing: 8) {
                Text(WeekFitLocalizedString("coach.askCoach"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.9))

                ForEach(AskCoachQuestion.allCases) { question in
                    Button {
                        onSelectQuestion(question)
                    } label: {
                        HStack(spacing: 8) {
                            Text(WeekFitLocalizedString(question.titleKey))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textPrimary.opacity(0.88))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(palette.textSecondary.opacity(0.45))
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("coach.ask.question.\(question.rawValue)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .weekFitPrimaryCard(accent: WeekFitTheme.coachAccent)
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("coach.ask.entry")
    }
}

struct AskCoachWeeklyFocusBanner: View {
    enum Mode {
        case active
        case review
    }

    let focus: AskCoachWeeklyFocus
    let mode: Mode
    let onPrimary: (() -> Void)?
    let onDismiss: () -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .active
                 ? WeekFitLocalizedString("coach.ask.focus.activeLabel")
                 : WeekFitLocalizedString("coach.ask.focus.reviewLabel"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textSecondary.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.5)

            Text(AskCoachCopy.resolve(AskCoachCopy.focusTitle(focus.kind)))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary.opacity(0.92))

            Text(dateRangeLabel)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary.opacity(0.8))

            HStack(spacing: 10) {
                if mode == .review, let onPrimary {
                    Button(WeekFitLocalizedString("coach.ask.focus.reviewAction"), action: onPrimary)
                        .buttonStyle(.borderedProminent)
                        .tint(WeekFitTheme.coachAccent)
                }

                Button(WeekFitLocalizedString("coach.ask.focus.dismiss"), action: onDismiss)
                    .buttonStyle(.bordered)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPrimaryCard(accent: WeekFitTheme.coachAccent)
        .accessibilityIdentifier(mode == .active ? "coach.ask.focus.active" : "coach.ask.focus.review")
    }

    private var dateRangeLabel: String {
        let start = CoachDailyObservation.date(fromDayKey: focus.startDayKey).map(WeekFitShortWeekdayMonthDay) ?? focus.startDayKey
        let end = CoachDailyObservation.date(fromDayKey: focus.endDayKey).map(WeekFitShortWeekdayMonthDay) ?? focus.endDayKey
        return "\(start) – \(end)"
    }
}
