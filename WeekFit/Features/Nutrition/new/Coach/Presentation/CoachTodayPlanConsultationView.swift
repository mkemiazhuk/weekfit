import SwiftUI

/// Premium AI daily plan consultation — calm hierarchy for why/what changes/what stays.
struct CoachTodayPlanConsultationView: View {
    let presentation: CoachTodayPlanConsultationPresentation
    var onApply: (_ selectedTimelineIDs: Set<String>) -> Void
    var onKeepCurrent: () -> Void

    @State private var selectedTimelineIDs: Set<String>

    private let textPrimary = WeekFitTheme.primaryText
    private let textSecondary = WeekFitTheme.secondaryText
    private let cyanAccent = CoachPalette.recovery

    init(
        presentation: CoachTodayPlanConsultationPresentation,
        onApply: @escaping (_ selectedTimelineIDs: Set<String>) -> Void,
        onKeepCurrent: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.onApply = onApply
        self.onKeepCurrent = onKeepCurrent
        _selectedTimelineIDs = State(
            initialValue: Set(
                presentation.timelineItems
                    .filter(\.isSelectedByDefault)
                    .map(\.id)
            )
        )
    }

    private var canApply: Bool {
        !selectedTimelineIDs.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    summaryCard
                    changesSection
                    timelineSection
                    noteSection
                }
                .padding(.top, 4)
                .padding(.bottom, 20)
            }

            bottomActions
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.coach.todayPlan")
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(presentation.eyebrow)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(cyanAccent.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.headline)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(textPrimary)
                .tracking(-0.6)
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.summary)
                .font(.system(size: 13.4, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.82))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                metaChip(
                    label: presentation.reasonLabel,
                    value: presentation.reasonValue
                )
                metaChip(
                    label: presentation.changesLabel,
                    value: presentation.changesValue
                )
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(
            emphasis: .accent,
            accent: cyanAccent,
            cornerRadius: 22
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            [
                presentation.eyebrow,
                presentation.headline,
                presentation.summary,
                "\(presentation.reasonLabel): \(presentation.reasonValue)",
                "\(presentation.changesLabel): \(presentation.changesValue)"
            ].joined(separator: ". ")
        )
    }

    private func metaChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(textSecondary.opacity(0.55))
            Text(value)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Changes

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(presentation.changesSectionTitle)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            VStack(spacing: 6) {
                ForEach(presentation.changeItems) { item in
                    changeRow(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func changeRow(_ item: CoachTodayPlanChangeItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: changeIcon(item.kind))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(changeColor(item.kind))
                .frame(width: 22, height: 22)
                .background {
                    Circle()
                        .fill(changeColor(item.kind).opacity(0.12))
                }
                .accessibilityHidden(true)

            Text(item.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary.opacity(item.kind == .remove ? 0.72 : 0.94))
                .strikethrough(item.kind == .remove, color: textSecondary.opacity(0.35))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WeekFitTheme.cardBackground.opacity(0.28))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(WeekFitTheme.whiteOpacity(0.04), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(changeAccessibilityPrefix(item.kind)), \(item.title)")
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(presentation.timelineSectionTitle)
                .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                .foregroundStyle(textPrimary)

            VStack(spacing: 8) {
                ForEach(presentation.timelineItems) { item in
                    timelineRow(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timelineRow(_ item: CoachTodayPlanTimelineItem) -> some View {
        let isSelected = selectedTimelineIDs.contains(item.id)

        return Button {
            toggleSelection(item.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.timeLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.62))
                        .monospacedDigit()

                    Text(item.activityTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.actionLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(cyanAccent.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.rationale)
                        .font(.system(size: 12.8, weight: .medium, design: .rounded))
                        .foregroundStyle(textSecondary.opacity(0.74))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                }

                Spacer(minLength: 8)

                selectionControl(isSelected: isSelected)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .weekFitPremiumCard(
                emphasis: .standard,
                accent: isSelected ? cyanAccent : nil,
                cornerRadius: 18
            )
            .opacity(isSelected ? 1 : 0.72)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [
                item.timeLabel,
                item.activityTitle,
                item.actionLabel,
                item.rationale,
                isSelected
                    ? WeekFitLocalizedString("coach.todayPlan.a11y.selected")
                    : WeekFitLocalizedString("coach.todayPlan.a11y.notSelected")
            ].joined(separator: ". ")
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(WeekFitLocalizedString("coach.todayPlan.a11y.toggleHint"))
    }

    private func selectionControl(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24, weight: .regular))
            .foregroundStyle(isSelected ? cyanAccent : textSecondary.opacity(0.35))
            .symbolRenderingMode(.hierarchical)
            .accessibilityHidden(true)
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(presentation.noteSectionTitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(textSecondary.opacity(0.62))

            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.noteHeadline)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textPrimary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                Text(presentation.noteBody)
                    .font(.system(size: 12.8, weight: .medium, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.70))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(WeekFitTheme.cardBackground.opacity(0.18))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Bottom actions

    private var bottomActions: some View {
        VStack(spacing: 10) {
            Button {
                onApply(selectedTimelineIDs)
            } label: {
                Text(presentation.primaryCTATitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(canApply ? Color.black.opacity(0.92) : textSecondary.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(canApply ? cyanAccent : WeekFitTheme.whiteOpacity(0.08))
                    }
            }
            .buttonStyle(.plain)
            .disabled(!canApply)
            .accessibilityLabel(presentation.primaryCTATitle)
            .accessibilityHint(
                canApply
                    ? WeekFitLocalizedString("coach.todayPlan.a11y.applyHint")
                    : WeekFitLocalizedString("coach.todayPlan.a11y.applyDisabledHint")
            )
            .accessibilityIdentifier("coach.todayPlan.apply")

            Button {
                onKeepCurrent()
            } label: {
                Text(presentation.secondaryCTATitle)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(textSecondary.opacity(0.72))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(presentation.secondaryCTATitle)
            .accessibilityIdentifier("coach.todayPlan.keepCurrent")
        }
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background {
            Rectangle()
                .fill(WeekFitTheme.backgroundColor.opacity(0.97))
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(WeekFitTheme.whiteOpacity(0.05))
                        .frame(height: 1)
                }
        }
    }

    // MARK: - Helpers

    private func toggleSelection(_ id: String) {
        if selectedTimelineIDs.contains(id) {
            selectedTimelineIDs.remove(id)
        } else {
            selectedTimelineIDs.insert(id)
        }
    }

    private func changeIcon(_ kind: CoachTodayPlanChangeKind) -> String {
        switch kind {
        case .keep: return "checkmark"
        case .adjust: return "arrow.down"
        case .remove: return "minus"
        }
    }

    private func changeColor(_ kind: CoachTodayPlanChangeKind) -> Color {
        switch kind {
        case .keep: return CoachPalette.stable
        case .adjust: return cyanAccent
        case .remove: return textSecondary.opacity(0.75)
        }
    }

    private func changeAccessibilityPrefix(_ kind: CoachTodayPlanChangeKind) -> String {
        switch kind {
        case .keep:
            return WeekFitLocalizedString("coach.todayPlan.a11y.keep")
        case .adjust:
            return WeekFitLocalizedString("coach.todayPlan.a11y.adjust")
        case .remove:
            return WeekFitLocalizedString("coach.todayPlan.a11y.remove")
        }
    }
}

#if DEBUG
#Preview("Today plan consultation") {
    ZStack {
        WeekFitTheme.appBackground.ignoresSafeArea()
        CoachTodayPlanConsultationView(
            presentation: CoachTodayPlanConsultationPresentation(
                eyebrow: "AI пересмотрел ваш день",
                headline: "Сегодня снизим нагрузку",
                summary: "Восстановление ниже обычного, поэтому оставим Cycling и сохраним умеренную интенсивность.",
                reasonLabel: "Причина",
                reasonValue: "Восстановление ниже обычного",
                changesLabel: "Изменения",
                changesValue: "2 корректировки",
                changesSectionTitle: "Что изменится",
                changeItems: [
                    .init(id: "1", kind: .keep, title: "Cycling оставить"),
                    .init(id: "2", kind: .adjust, title: "Интенсивность снизить"),
                    .init(id: "3", kind: .remove, title: "Дополнительную нагрузку убрать")
                ],
                timelineSectionTitle: "В течение дня",
                timelineItems: [
                    .init(
                        id: "t1",
                        activityID: "a1",
                        timeLabel: "14:53",
                        activityTitle: "Cycling",
                        actionLabel: "Оставить как есть",
                        rationale: "Подходит для дня с пониженным восстановлением.",
                        kind: .keep,
                        isSelectedByDefault: true
                    )
                ],
                noteSectionTitle: "На заметку",
                noteHeadline: "Держите комфортный темп, при котором можно спокойно разговаривать.",
                noteBody: "Во время Cycling ориентируйтесь на комфортный разговорный темп.",
                primaryCTATitle: "Применить изменения",
                secondaryCTATitle: "Не менять текущий план",
                scenario: .lowRecoveryPrep
            ),
            onApply: { _ in },
            onKeepCurrent: {}
        )
    }
    .preferredColorScheme(.dark)
}
#endif
