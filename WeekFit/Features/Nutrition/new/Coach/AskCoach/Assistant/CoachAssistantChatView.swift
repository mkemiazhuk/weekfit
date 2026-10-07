import SwiftUI

struct CoachAssistantChatView: View {
    @ObservedObject var viewModel: CoachAssistantViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weekFitPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let bubbleCorner: CGFloat = 18
    private let maxBubbleWidthRatio: CGFloat = 0.82

    var body: some View {
        VStack(spacing: 0) {
            conversationScroll
            composerBar
        }
        .background(palette.appScreenBackground.ignoresSafeArea())
        .navigationTitle(WeekFitLocalizedString("coach.assistant.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel(WeekFitLocalizedString("common.action.back"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(WeekFitLocalizedString("coach.assistant.menu.otherTopic")) {
                        viewModel.selectChoice(
                            CoachAssistantChoice(
                                id: "end.another",
                                title: CoachAssistantCopy.bi("Other topic", "Другая тема"),
                                destination: .mindAsk
                            )
                        )
                    }
                    Button(WeekFitLocalizedString("coach.assistant.menu.editFeeling")) {
                        viewModel.editFeeling()
                    }
                    Button(WeekFitLocalizedString("coach.assistant.menu.finish")) {
                        viewModel.finishConversation()
                    }
                    Button(WeekFitLocalizedString("coach.assistant.menu.new")) {
                        viewModel.startNewConversation()
                    }
                    Button(WeekFitLocalizedString("coach.assistant.menu.delete"), role: .destructive) {
                        viewModel.deleteCurrentConversation()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .medium))
                }
                .accessibilityLabel(WeekFitLocalizedString("coach.assistant.menu"))
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .onAppear { viewModel.start() }
        .accessibilityIdentifier("coach.assistant.chat")
    }

    private var conversationScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.turns.enumerated()), id: \.element.id) { index, turn in
                        if shouldShowDateSeparator(at: index) {
                            dateSeparator(for: turn.createdAt)
                        }
                        turnRow(turn, previous: index > 0 ? viewModel.turns[index - 1] : nil)
                            .id(turn.id)
                    }

                    if viewModel.isCoachTyping || viewModel.isLoadingAnalysis {
                        typingIndicatorRow
                            .id("typing")
                    }

                    Color.clear.frame(height: 12).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .weekFitTransparentScrollBackground(fillsCanvas: false)
            .onChange(of: viewModel.turns.count) { _, _ in
                withAnimation(.easeOut(duration: 0.22)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.isCoachTyping) { _, typing in
                if typing {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private var typingIndicatorRow: some View {
        HStack {
            CoachAssistantTypingBubble(
                fill: coachBubbleFill,
                accent: palette.textSecondary.opacity(0.75)
            )
            .frame(maxWidth: UIScreen.main.bounds.width * maxBubbleWidthRatio, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.top, viewModel.turns.isEmpty ? 0 : 15)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .accessibilityLabel(WeekFitLocalizedString("coach.assistant.typing"))
    }

    @ViewBuilder
    private func turnRow(_ turn: CoachAssistantTurn, previous: CoachAssistantTurn?) -> some View {
        let sameSender = previous?.role == turn.role
        let topPad: CGFloat = previous == nil ? 0 : (sameSender ? 7 : 15)

        Group {
            if turn.role == .user {
                HStack {
                    Spacer(minLength: 0)
                    messageBubble(
                        text: CoachAssistantCopy.resolve(turn.text),
                        isUser: true
                    )
                    .frame(maxWidth: UIScreen.main.bounds.width * maxBubbleWidthRatio, alignment: .trailing)
                }
            } else {
                messageBubble(
                    text: CoachAssistantMessageFormatter.presentForDisplay(
                        CoachAssistantCopy.resolve(turn.text)
                    ),
                    isUser: false
                )
                .frame(maxWidth: UIScreen.main.bounds.width * maxBubbleWidthRatio, alignment: .leading)
            }
        }
        .padding(.top, topPad)
        .opacity(turn.isInvalidated ? 0.45 : 1)
    }

    private func messageBubble(text: String, isUser: Bool) -> some View {
        Text(text)
            .font(.system(
                size: dynamicTypeSize.isAccessibilitySize ? 18 : 16,
                weight: .regular,
                design: .rounded
            ))
            .foregroundStyle(palette.textPrimary.opacity(0.94))
            .multilineTextAlignment(.leading)
            .lineSpacing(dynamicTypeSize.isAccessibilitySize ? 5 : 3)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: bubbleCorner, style: .continuous)
                    .fill(isUser ? userBubbleFill : coachBubbleFill)
            }
    }

    private var coachBubbleFill: Color {
        palette.isLight ? Color.white.opacity(0.72) : Color.white.opacity(0.08)
    }

    private var userBubbleFill: Color {
        WeekFitTheme.coachAccent.opacity(palette.isLight ? 0.18 : 0.28)
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        let turns = viewModel.turns
        guard index < turns.count else { return false }
        if index == 0 { return true }
        let calendar = Calendar.current
        return !calendar.isDate(turns[index].createdAt, inSameDayAs: turns[index - 1].createdAt)
    }

    private func dateSeparator(for date: Date) -> some View {
        Text(dateSeparatorLabel(date))
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.textSecondary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }

    private func dateSeparatorLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return WeekFitLocalizedString("coach.assistant.date.today")
        }
        if calendar.isDateInYesterday(date) {
            return WeekFitLocalizedString("coach.assistant.date.yesterday")
        }
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    @ViewBuilder
    private var composerBar: some View {
        if !viewModel.choices.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(viewModel.choices.prefix(4)) { choice in
                    Button {
                        viewModel.selectChoice(choice)
                    } label: {
                        Text(CoachAssistantCopy.resolve(choice.title))
                            .font(.system(
                                size: dynamicTypeSize.isAccessibilitySize ? 16 : 14,
                                weight: .semibold,
                                design: .rounded
                            ))
                            .foregroundStyle(WeekFitTheme.coachAccent)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                Capsule(style: .continuous)
                                    .strokeBorder(WeekFitTheme.coachAccent.opacity(0.35), lineWidth: 1)
                                    .background {
                                        Capsule(style: .continuous)
                                            .fill(palette.isLight
                                                  ? Color.white.opacity(0.55)
                                                  : Color.white.opacity(0.06))
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isProcessingChoice || viewModel.isLoadingAnalysis || viewModel.isCoachTyping)
                    .accessibilityIdentifier("coach.assistant.choice.\(choice.id)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background {
                Rectangle()
                    .fill(palette.appScreenBackground.opacity(0.97))
                    .ignoresSafeArea(edges: .bottom)
                    .shadow(color: Color.black.opacity(palette.isLight ? 0.04 : 0.18), radius: 8, y: -2)
            }
        }
    }
}

// MARK: - Typing indicator

private struct CoachAssistantTypingBubble: View {
    let fill: Color
    let accent: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.16, paused: false)) { context in
            let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.16) % 3
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)
                        .offset(y: phase == index ? -3.5 : 0)
                        .opacity(phase == index ? 1 : 0.45)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
            }
            .animation(.easeInOut(duration: 0.16), value: phase)
        }
    }
}
