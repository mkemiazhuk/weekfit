import SwiftUI

struct CoachFeelingConversationView: View {
    @ObservedObject var viewModel: CoachFeelingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        if let feeling = viewModel.selectedFeeling {
                            feelingChip(feeling)
                        }

                        switch viewModel.phase {
                        case .feeling:
                            feelingChooser
                        case .clarification:
                            clarificationChooser
                        case .result:
                            conversationThread
                            if shouldShowDurationButtons {
                                durationButtons
                            }
                            followUpBar
                            manageCheckIn
                        }

                        if viewModel.phase == .result {
                            reviewWeekLink
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .weekFitTransparentScrollBackground(fillsCanvas: false)
                .background(palette.appScreenBackground.ignoresSafeArea())
                .onChange(of: viewModel.turns.count) { _, _ in
                    if let id = viewModel.turns.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle(WeekFitLocalizedString("coach.feeling.navTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(WeekFitLocalizedString("common.action.done")) {
                        dismiss()
                    }
                }
            }
            .onAppear { viewModel.start() }
        }
        .accessibilityIdentifier("coach.feeling.conversation")
    }

    private func feelingChip(_ feeling: CoachFeelingKind) -> some View {
        Text(WeekFitLocalizedString(feeling.titleKey))
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.textPrimary.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(palette.isLight
                          ? WeekFitTheme.coachAccent.opacity(0.14)
                          : WeekFitTheme.coachAccent.opacity(0.22))
            }
            .accessibilityAddTraits(.isHeader)
    }

    private var feelingChooser: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("coach.feeling.prompt.title"))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(WeekFitLocalizedString("coach.feeling.prompt.subtitle"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(CoachFeelingKind.allCases) { feeling in
                    Button {
                        viewModel.selectFeeling(feeling)
                    } label: {
                        Text(WeekFitLocalizedString(feeling.titleKey))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background {
                                Capsule(style: .continuous)
                                    .strokeBorder(WeekFitTheme.coachAccent.opacity(0.4), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("coach.feeling.sheet.choice.\(feeling.rawValue)")
                }
            }
        }
    }

    private var clarificationChooser: some View {
        VStack(alignment: .leading, spacing: 10) {
            conversationThread

            Text(WeekFitLocalizedString("coach.feeling.clarify.title"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            ForEach(CoachFeelingClarification.allCases) { item in
                Button {
                    viewModel.selectClarification(item)
                } label: {
                    Text(WeekFitLocalizedString(item.titleKey))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.textPrimary.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(palette.isLight
                                      ? Color.white.opacity(0.45)
                                      : Color.white.opacity(0.06))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coach.feeling.clarify.\(item.rawValue)")
            }

            Button(WeekFitLocalizedString("coach.feeling.clarify.skip")) {
                viewModel.skipClarification()
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(WeekFitTheme.coachAccent)
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityIdentifier("coach.feeling.clarify.skip")
        }
    }

    private var conversationThread: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(viewModel.turns) { turn in
                VStack(alignment: .leading, spacing: 8) {
                    Text(CoachFeelingCopy.resolve(turn.userPrompt))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            Capsule(style: .continuous)
                                .fill(palette.isLight
                                      ? WeekFitTheme.coachAccent.opacity(0.12)
                                      : WeekFitTheme.coachAccent.opacity(0.18))
                        }

                    if turn.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(WeekFitLocalizedString("coach.ask.loading"))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textSecondary)
                        }
                    } else if let headline = turn.answerHeadline {
                        let size: CGFloat = dynamicTypeSize.isAccessibilitySize ? 18 : 17
                        Text(CoachFeelingCopy.resolve(headline))
                            .font(.system(size: size, weight: .semibold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)

                        if let explanation = turn.answerExplanation {
                            Text(CoachFeelingCopy.resolve(explanation))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textPrimary.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        ForEach(Array(turn.supportingFacts.prefix(2).enumerated()), id: \.offset) { _, fact in
                            Text(CoachFeelingCopy.resolve(fact))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !turn.detailFacts.isEmpty {
                            Button {
                                viewModel.toggleDetails(for: turn.id)
                            } label: {
                                Text(turn.detailsExpanded
                                     ? WeekFitLocalizedString("coach.ask.hideData")
                                     : WeekFitLocalizedString("coach.ask.viewDetails"))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(WeekFitTheme.coachAccent)
                            }
                            .buttonStyle(.plain)

                            if turn.detailsExpanded {
                                ForEach(Array(turn.detailFacts.enumerated()), id: \.offset) { _, fact in
                                    Text(CoachFeelingCopy.resolve(fact))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(palette.textSecondary.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .id(turn.id)
            }
        }
    }

    private var shouldShowDurationButtons: Bool {
        viewModel.followUps.contains(.feelingDuration)
            && viewModel.turns.contains(where: {
                $0.userPrompt == CoachFeelingFollowUp.feelingDuration.prompt
            })
            && !(viewModel.activeCheckIn?.followUpAnswers.contains(where: {
                $0 == "started_today" || $0 == "lasted_few_days"
            }) ?? false)
    }

    private var durationButtons: some View {
        HStack(spacing: 10) {
            Button(WeekFitLocalizedString("coach.feeling.duration.today")) {
                viewModel.answerDuration(startedToday: true)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("coach.feeling.duration.today")

            Button(WeekFitLocalizedString("coach.feeling.duration.fewDays")) {
                viewModel.answerDuration(startedToday: false)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("coach.feeling.duration.fewDays")
        }
        .font(.system(size: 14, weight: .semibold, design: .rounded))
    }

    private var followUpBar: some View {
        let items = Array(viewModel.followUps.prefix(2))
        return FlowFeelingFollowUps(items: items) { followUp in
            viewModel.selectFollowUp(followUp)
        }
        .padding(.top, 4)
    }

    private var manageCheckIn: some View {
        Group {
            if viewModel.activeCheckIn != nil {
                HStack(spacing: 16) {
                    Button {
                        viewModel.editActiveCheckIn()
                    } label: {
                        Text(WeekFitLocalizedString("coach.feeling.action.edit"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(WeekFitTheme.coachAccent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("coach.feeling.edit")

                    Button(role: .destructive) {
                        viewModel.deleteActiveCheckIn()
                    } label: {
                        Text(WeekFitLocalizedString("coach.feeling.action.delete"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("coach.feeling.delete")
                }
                .padding(.top, 8)
            }
        }
    }

    private var reviewWeekLink: some View {
        Button {
            viewModel.selectFollowUp(.reviewWeek)
        } label: {
            Text(WeekFitLocalizedString("coach.feeling.followUp.reviewWeek"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary.opacity(0.8))
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .accessibilityIdentifier("coach.feeling.reviewWeek")
    }
}

/// Compact wrap-friendly follow-up chips without a heavy card chrome.
private struct FlowFeelingFollowUps: View {
    let items: [CoachFeelingFollowUp]
    let onSelect: (CoachFeelingFollowUp) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items) { followUp in
                Button {
                    onSelect(followUp)
                } label: {
                    Text(WeekFitLocalizedString(followUp.titleKey))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            Capsule(style: .continuous)
                                .strokeBorder(WeekFitTheme.coachAccent.opacity(0.35), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coach.feeling.followUp.\(followUp.rawValue)")
            }
        }
    }
}
