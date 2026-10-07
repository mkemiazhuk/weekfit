import SwiftUI
import WeekFitPlanner

struct AskCoachConversationView: View {
    @ObservedObject var viewModel: AskCoachViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        secondaryPeriodControl

                        switch viewModel.phase {
                        case .chooseQuestion:
                            questionChooser
                        case .answering:
                            conversationThread
                            if case .error = viewModel.loadState {
                                errorBlock
                            }
                            followUpBar
                            if let focus = viewModel.latestSuggestedFocus,
                               viewModel.weeklyFocus == nil {
                                suggestedFocusBlock(focus)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .weekFitTransparentScrollBackground(fillsCanvas: false)
                .background(palette.appScreenBackground.ignoresSafeArea())
                .onChange(of: viewModel.turns.count) { _, _ in
                    if let lastID = viewModel.turns.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.phase == .answering {
                        Button(WeekFitLocalizedString("coach.ask.followUp.back")) {
                            viewModel.resetToQuestions()
                        }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(WeekFitLocalizedString("common.action.done")) {
                        dismiss()
                    }
                }
            }
        }
        .accessibilityIdentifier("coach.ask.conversation")
    }

    // MARK: - Period (secondary)

    private var secondaryPeriodControl: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(AskCoachPeriodLength.allCases) { period in
                    Button(WeekFitLocalizedString(period.titleKey)) {
                        viewModel.changePeriod(period)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(WeekFitLocalizedString(viewModel.selectedPeriod.titleKey))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(palette.textSecondary.opacity(0.85))
            }
            .accessibilityIdentifier("coach.ask.period")

            Text(viewModel.rangeLabel)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary.opacity(0.65))
                .accessibilityIdentifier("coach.ask.period.range")

            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }

    // MARK: - Questions

    private var questionChooser: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WeekFitLocalizedString("coach.ask.choosePrompt"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary.opacity(0.8))

            ForEach(AskCoachQuestion.allCases) { question in
                Button {
                    viewModel.selectQuestion(question)
                } label: {
                    Text(WeekFitLocalizedString(question.titleKey))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(palette.isLight
                                      ? Color.white.opacity(0.5)
                                      : Color.white.opacity(0.06))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Thread

    private var conversationThread: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(viewModel.turns) { turn in
                VStack(alignment: .leading, spacing: 8) {
                    userBubble(AskCoachCopy.resolve(turn.userPrompt))

                    if turn.isLoading {
                        loadingRow
                    } else if let answer = turn.answer {
                        coachReply(answer, turnID: turn.id, detailsExpanded: turn.detailsExpanded)
                    }
                }
                .id(turn.id)
            }
        }
    }

    private func userBubble(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.textPrimary.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(palette.isLight
                          ? WeekFitTheme.coachAccent.opacity(0.12)
                          : WeekFitTheme.coachAccent.opacity(0.18))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var loadingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(WeekFitLocalizedString("coach.ask.loading"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("coach.ask.loading")
    }

    private var errorBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(WeekFitLocalizedString("coach.ask.error.title"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(WeekFitLocalizedString("coach.ask.error.message"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)
            Button(WeekFitLocalizedString("coach.ask.retry")) {
                viewModel.retry()
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .padding(.top, 4)
    }

    private func coachReply(
        _ answer: AskCoachAnswer,
        turnID: UUID,
        detailsExpanded: Bool
    ) -> some View {
        let findingSize: CGFloat = dynamicTypeSize.isAccessibilitySize ? 18 : 17

        return VStack(alignment: .leading, spacing: 8) {
            Text(AskCoachCopy.resolve(answer.headline))
                .font(.system(size: findingSize, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)

            let explanation = AskCoachCopy.resolve(answer.explanation)
            if !explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(explanation)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textPrimary.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let limitation = answer.inlineLimitation {
                Text(AskCoachCopy.resolve(limitation))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.textSecondary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            if !answer.supportingFacts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(answer.supportingFacts.prefix(2).enumerated()), id: \.offset) { _, fact in
                        Text(AskCoachCopy.resolve(fact))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.textSecondary.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
            }

            if !answer.detailFacts.isEmpty || !answer.evidence.isEmpty {
                Button {
                    viewModel.toggleDetails(for: turnID)
                } label: {
                    Text(detailsExpanded
                         ? WeekFitLocalizedString("coach.ask.hideData")
                         : WeekFitLocalizedString("coach.ask.viewDetails"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.coachAccent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .accessibilityIdentifier("coach.ask.showData")

                if detailsExpanded {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(answer.detailFacts.enumerated()), id: \.offset) { _, fact in
                            Text(AskCoachCopy.resolve(fact))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(palette.textSecondary.opacity(0.85))
                        }
                        ForEach(answer.evidence.prefix(8)) { item in
                            HStack(alignment: .firstTextBaseline) {
                                Text(AskCoachCopy.resolve(item.title))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                Spacer(minLength: 8)
                                if let detail = item.detail {
                                    Text(AskCoachCopy.resolve(detail))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(palette.textSecondary)
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                    .accessibilityIdentifier("coach.ask.evidence")
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("coach.ask.answer")
    }

    private var followUpBar: some View {
        let followUps = viewModel.latestFollowUps
        return Group {
            if !followUps.isEmpty, viewModel.turns.last?.isLoading != true {
                FlowFollowUps(followUps: followUps) { followUp in
                    viewModel.selectFollowUp(followUp)
                }
                .padding(.top, 4)
            }
        }
    }

    private func suggestedFocusBlock(_ focus: AskCoachSuggestedFocus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AskCoachCopy.resolve(AskCoachCopy.focusTitle(focus.kind)))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.textPrimary)

            Text(AskCoachCopy.resolve(focus.rationale))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(palette.textSecondary)

            Button(WeekFitLocalizedString("coach.ask.focus.setAction")) {
                viewModel.setWeeklyFocus(focus.kind)
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .buttonStyle(.borderedProminent)
            .tint(WeekFitTheme.coachAccent)
            .accessibilityIdentifier("coach.ask.focus.set")
        }
        .padding(.top, 8)
    }
}

/// Compact text follow-ups — not full-width menu buttons.
private struct FlowFollowUps: View {
    let followUps: [AskCoachFollowUp]
    let onSelect: (AskCoachFollowUp) -> Void

    @Environment(\.weekFitPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(followUps.prefix(2)) { followUp in
                Button {
                    onSelect(followUp)
                } label: {
                    Text(WeekFitLocalizedString(followUp.titleKey))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.textPrimary.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            Capsule(style: .continuous)
                                .strokeBorder(
                                    WeekFitTheme.coachAccent.opacity(0.35),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("coach.ask.followUp.\(followUp.rawValue)")
            }
        }
    }
}
