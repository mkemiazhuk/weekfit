import SwiftUI

struct FeedbackFormView: View {
    @ObservedObject var manager: ReviewPromptManager
    let intent: FeedbackFormIntent
    let sentiment: FeedbackSentiment?
    let triggerSource: String

    @Environment(\.dismiss) private var dismiss

    @State private var draft: FeedbackDraft
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isMessageFocused: Bool

    init(
        manager: ReviewPromptManager,
        intent: FeedbackFormIntent,
        sentiment: FeedbackSentiment?,
        triggerSource: String
    ) {
        self.manager = manager
        self.intent = intent
        self.sentiment = sentiment
        self.triggerSource = triggerSource
        _draft = State(initialValue: FeedbackDraft.blank(intent: intent, sentiment: sentiment))
    }

    var body: some View {
        ZStack {
            WeekFitTheme.backgroundColor.ignoresSafeArea()
            ProfilePremiumBackground(accent: WeekFitStyle.brandGreen)

            VStack(spacing: 0) {
                ProfilePremiumHeader(
                    title: WeekFitLocalizedString(intent.titleKey),
                    accent: WeekFitStyle.brandGreen
                ) {
                    close()
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(WeekFitLocalizedString("review.feedback.form.subtitle"))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(WeekFitTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        categorySection
                        messageSection
                        contactSection

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
                                .accessibilityIdentifier("review.feedback.form.error")
                        }

                        actionButtons
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("review.feedback.form")
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("review.feedback.form.category"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(visibleCategories) { category in
                    categoryChip(category)
                }
            }
        }
    }

    private var visibleCategories: [FeedbackCategory] {
        switch intent {
        case .suggestFeature:
            return FeedbackCategory.allCases
        case .general, .reportProblem, .postSentiment:
            return FeedbackCategory.allCases.filter { $0 != .featureSuggestion }
        }
    }

    private func categoryChip(_ category: FeedbackCategory) -> some View {
        let selected = draft.category == category
        return Button {
            draft.category = selected ? nil : category
        } label: {
            Text(WeekFitLocalizedString(category.localizationKey))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(
                    selected
                        ? WeekFitTheme.primaryCTAForeground
                        : WeekFitTheme.primaryText
                )
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            selected
                                ? WeekFitTheme.primaryCTA
                                : WeekFitTheme.whiteOpacity(0.06)
                        )
                        .overlay {
                            if !selected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(WeekFitTheme.borderSoft.opacity(0.7), lineWidth: 0.8)
                            }
                        }
                }
        }
        .buttonStyle(ReviewPressableButtonStyle())
        .accessibilityIdentifier("review.feedback.category.\(category.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("review.feedback.form.message"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(WeekFitTheme.secondaryText)

            TextEditor(text: $draft.message)
                .focused($isMessageFocused)
                .frame(minHeight: 140)
                .padding(14)
                .scrollContentBackground(.hidden)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(WeekFitTheme.whiteOpacity(0.04))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(WeekFitTheme.borderSoft.opacity(0.75), lineWidth: 1)
                        }
                }
                .foregroundStyle(WeekFitTheme.primaryText)
                .accessibilityIdentifier("review.feedback.form.messageField")
                .accessibilityLabel(WeekFitLocalizedString("review.feedback.form.message"))
        }
    }

    private var contactSection: some View {
        Toggle(isOn: $draft.allowContact) {
            Text(WeekFitLocalizedString("review.feedback.form.contactPermission"))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(WeekFitTheme.settingsAccent)
        .padding(.vertical, 4)
        .accessibilityIdentifier("review.feedback.form.contactToggle")
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Task { await submit() }
            } label: {
                Text(
                    isSubmitting
                        ? WeekFitLocalizedString("review.feedback.form.sending")
                        : WeekFitLocalizedString("review.feedback.form.send")
                )
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(WeekFitTheme.primaryCTAForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    Capsule()
                        .fill(WeekFitTheme.primaryCTA)
                }
            }
            .buttonStyle(ReviewPressableButtonStyle())
            .disabled(isSubmitting || draft.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
            .accessibilityIdentifier("review.feedback.form.send")

            Button {
                close()
            } label: {
                Text(WeekFitLocalizedString("review.feedback.form.notNow"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(WeekFitTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(ReviewPressableButtonStyle())
            .accessibilityIdentifier("review.feedback.form.notNow")
        }
        .padding(.top, 8)
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await manager.submitFeedback(draft)
            dismissIfPushed()
        } catch FeedbackSubmissionError.emptyMessage {
            errorMessage = WeekFitLocalizedString("review.feedback.form.error.empty")
        } catch {
            // Mailto may still open; treat soft failures as dismissible.
            errorMessage = WeekFitLocalizedString("review.feedback.form.error.generic")
            manager.dismissPresentation(trackAsDismissed: false)
            dismissIfPushed()
        }
        isSubmitting = false
    }

    private func close() {
        manager.dismissPresentation(trackAsDismissed: true)
        dismissIfPushed()
    }

    private func dismissIfPushed() {
        dismiss()
    }
}
