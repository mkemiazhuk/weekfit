import SwiftData
import SwiftUI
import WeekFitPlanner

/// Selectable review of morning Coach adjustments before Apply.
struct ProposalReviewView: View {
    let dayKey: String
    let onApplied: (CoachApplySummary) -> Void
    let onDismissPlan: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weekFitPalette) private var palette
    @Query(sort: \PlannedActivity.date) private var plannedActivities: [PlannedActivity]

    @State private var proposal: MorningPlanProposal?
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var expandedReasonIds: Set<String> = []
    @State private var didRecordReviewOpen = false

    private var accent: Color { WeekFitTheme.recovery }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Group {
                if let proposal {
                    reviewContent(proposal)
                } else {
                    ContentUnavailableView(
                        WeekFitLocalizedString("coach.proposal.review.emptyTitle"),
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text(WeekFitLocalizedString("coach.proposal.review.emptyBody"))
                    )
                    .foregroundStyle(WeekFitTheme.primaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(WeekFitTheme.backgroundColor.ignoresSafeArea())
        .interactiveDismissDisabled(isApplying)
        .safeAreaInset(edge: .bottom) {
            if let proposal, proposal.status != .applied {
                stickyFooter(proposal)
            }
        }
        .weekFitSheetChrome(cornerRadius: QuickActionSheetDesign.Layout.sheetCornerRadius)
        .accessibilityIdentifier("morning.proposal.review")
        .onAppear {
            proposal = MorningProposalStore.proposal(for: dayKey)
            guard !didRecordReviewOpen, let proposal else { return }
            didRecordReviewOpen = true
            MorningProposalAnalytics.reviewOpened(changeCount: proposal.changes.count)
        }
    }

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(
                    palette.isLight
                        ? WeekFitLightTokens.shadowContact.opacity(0.18)
                        : Color.white.opacity(0.14)
                )
                .frame(width: 42, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(WeekFitLocalizedString("coach.proposal.brief.eyebrow"))
                        .font(.caption2.weight(.bold))
                        .fontDesign(.rounded)
                        .tracking(1.15)
                        .foregroundStyle(accent.opacity(palette.isLight ? 0.92 : 0.78))

                    Text(WeekFitLocalizedString("coach.proposal.review.title"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                WeekFitCloseButton(size: .large, playsHaptic: false) {
                    dismiss()
                }
                .disabled(isApplying)
                .opacity(isApplying ? 0.45 : 1)
                .accessibilityLabel(WeekFitLocalizedString("common.action.close"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func reviewContent(_ proposal: MorningPlanProposal) -> some View {
        let brief = MorningProposalBriefComposer.compose(
            proposal: proposal,
            givenName: {
                let name = ProfileService.resolvedGivenName()
                return name.isEmpty ? nil : name
            }()
        )
        let dayChanges = orderedChanges(proposal.changes.filter { $0.kind != .guidanceOnly })
        let tips = orderedChanges(proposal.changes.filter { $0.kind == .guidanceOnly })

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroBrief(proposal, brief: brief)

                if proposal.status == .stale {
                    Text(WeekFitLocalizedString("coach.proposal.review.staleBanner"))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .weekFitPremiumCard(emphasis: .accent, accent: accent)
                }

                if !dayChanges.isEmpty {
                    dayTimelineSection(dayChanges)
                }

                if !tips.isEmpty {
                    tipsSection(tips)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private func dayTimelineSection(_ changes: [CoachProposedChange]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(WeekFitLocalizedString("coach.proposal.review.section.day"))
                .font(.caption2.weight(.bold))
                .fontDesign(.rounded)
                .tracking(1.15)
                .foregroundStyle(WeekFitTheme.secondaryText)
                .textCase(.uppercase)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                ForEach(Array(changes.enumerated()), id: \.element.id) { index, change in
                    timelineRow(change, isLast: index == changes.count - 1)
                }
            }
        }
    }

    private func tipsSection(_ tips: [CoachProposedChange]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(WeekFitLocalizedString("coach.proposal.review.section.tips"))
                .font(.caption2.weight(.bold))
                .fontDesign(.rounded)
                .tracking(1.15)
                .foregroundStyle(WeekFitTheme.secondaryText)
                .textCase(.uppercase)
                .padding(.leading, 2)

            VStack(spacing: 8) {
                ForEach(tips) { tip in
                    tipRow(tip)
                }
            }
        }
    }

    private func heroBrief(_ proposal: MorningPlanProposal, brief: MorningProposalBrief) -> some View {
        let selected = proposal.changes.filter { $0.kind != .guidanceOnly && $0.isSelected }.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            palette.isLight
                                ? WeekFitLightTokens.recoverySoft
                                : accent.opacity(0.16)
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "sun.horizon.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(brief.headline)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(WeekFitTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(brief.headline)

                    Text(WeekFitLocalizedString("coach.proposal.review.heroSupport"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }
            }

            if !brief.dayMoments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(brief.dayMoments) { moment in
                            HStack(spacing: 6) {
                                Image(systemName: moment.systemImage)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(accent)
                                Text(moment.timeLabel)
                                    .font(.caption2.weight(.bold))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(WeekFitTheme.secondaryText)
                                Text(moment.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(WeekFitTheme.primaryText)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background {
                                Capsule(style: .continuous)
                                    .fill(
                                        palette.isLight
                                            ? WeekFitLightTokens.internalTile
                                            : WeekFitTheme.whiteOpacity(0.06)
                                    )
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                metaChip(
                    String(
                        format: WeekFitLocalizedString("coach.proposal.review.selectedCountFormat"),
                        selected
                    )
                )
                if let meta = brief.metaLine {
                    metaChip(meta)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .elevated, accent: accent)
        .accessibilityElement(children: .combine)
    }

    private func metaChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(WeekFitTheme.secondaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(
                        palette.isLight
                            ? WeekFitLightTokens.internalTile
                            : WeekFitTheme.whiteOpacity(0.06)
                    )
            }
    }

    private func orderedChanges(_ changes: [CoachProposedChange]) -> [CoachProposedChange] {
        changes.sorted { lhs, rhs in
            let lTip = lhs.kind == .guidanceOnly
            let rTip = rhs.kind == .guidanceOnly
            if lTip != rTip { return !lTip && rTip }
            return lhs.sortTime < rhs.sortTime
        }
    }

    private func timelineRow(_ change: CoachProposedChange, isLast: Bool) -> some View {
        let timeLabel: String = {
            let formatter = DateFormatter()
            formatter.locale = WeekFitCurrentLocale()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: change.sortTime)
        }()

        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(change.isSelected ? accent : WeekFitTheme.secondaryText.opacity(0.28))
                    .frame(width: 9, height: 9)
                    .padding(.top, 18)
                if !isLast {
                    Rectangle()
                        .fill(
                            palette.isLight
                                ? WeekFitLightTokens.divider.opacity(0.7)
                                : WeekFitTheme.whiteOpacity(0.1)
                        )
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            VStack(alignment: .leading, spacing: 0) {
                Button {
                    toggle(change)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(timeLabel)
                                .font(.caption2.weight(.bold))
                                .fontDesign(.rounded)
                                .foregroundStyle(accent.opacity(0.9))

                            Text(rowTitle(change))
                                .font(.callout.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(WeekFitTheme.primaryText)
                                .multilineTextAlignment(.leading)

                            Text(rowDetail(change))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(WeekFitTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: change.isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                change.isSelected
                                    ? accent
                                    : WeekFitTheme.secondaryText.opacity(0.45)
                            )
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
                .disabled(isApplying)
                .accessibilityLabel(
                    change.isSelected
                        ? WeekFitLocalizedString("coach.proposal.review.a11y.selected")
                        : WeekFitLocalizedString("coach.proposal.review.a11y.notSelected")
                )
                .accessibilityHint(WeekFitLocalizedString("coach.proposal.review.a11y.toggleHint"))

                if expandedReasonIds.contains(change.id) {
                    Text(CoachProposalReasonCopy.localizedReason(change.reasonCode))
                        .font(.footnote)
                        .foregroundStyle(WeekFitTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 4)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    toggleReason(change)
                } label: {
                    Text(
                        expandedReasonIds.contains(change.id)
                            ? WeekFitLocalizedString("coach.proposal.review.hideReason")
                            : WeekFitLocalizedString("coach.proposal.review.showReason")
                    )
                    .font(.caption.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .frame(minHeight: 28, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(isApplying)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .weekFitPremiumCard(
                emphasis: .standard,
                accent: change.isSelected ? accent : nil
            )
            .padding(.bottom, isLast ? 0 : 10)
        }
    }

    private func tipRow(_ change: CoachProposedChange) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent.opacity(0.85))
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(
                            palette.isLight
                                ? WeekFitLightTokens.recoverySoft
                                : accent.opacity(0.12)
                        )
                }

            Text(rowTitle(change))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(WeekFitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .weekFitPremiumCard(emphasis: .compact)
    }

    private func stickyFooter(_ proposal: MorningPlanProposal) -> some View {
        let canApply = !proposal.selectedChanges.isEmpty && !isApplying

        return VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(
                        palette.isLight
                            ? WeekFitLightTokens.critical
                            : Color.red.opacity(0.9)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(errorMessage)
            }

            Button {
                apply(proposal)
            } label: {
                HStack(spacing: 8) {
                    if isApplying {
                        ProgressView()
                            .tint(WeekFitTheme.primaryCTAForeground)
                    }
                    Text(
                        isApplying
                            ? WeekFitLocalizedString("coach.proposal.review.applying")
                            : WeekFitLocalizedString("coach.proposal.review.apply")
                    )
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(WeekFitTheme.primaryCTAForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background {
                    Capsule()
                        .fill(accent.opacity(canApply ? 1 : 0.38))
                }
            }
            .buttonStyle(.plain)
            .disabled(!canApply)
            .accessibilityHint(WeekFitLocalizedString("coach.proposal.review.a11y.applyHint"))

            Button(WeekFitLocalizedString("coach.proposal.review.keepPlan")) {
                MorningProposalService.dismiss(dayKey: dayKey)
                onDismissPlan()
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(WeekFitTheme.secondaryText)
            .buttonStyle(.plain)
            .disabled(isApplying)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background {
            Rectangle()
                .fill(
                    palette.isLight
                        ? WeekFitLightTokens.surfacePrimary.opacity(0.96)
                        : WeekFitTheme.cardSurfaceElevated.opacity(0.96)
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(
                            palette.isLight
                                ? WeekFitLightTokens.divider.opacity(0.55)
                                : WeekFitTheme.whiteOpacity(0.08)
                        )
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func toggle(_ change: CoachProposedChange) {
        guard change.kind != .guidanceOnly else { return }
        let next = !change.isSelected
        MorningProposalService.setSelection(
            dayKey: dayKey,
            changeId: change.id,
            isSelected: next
        )
        proposal = MorningProposalStore.proposal(for: dayKey)
        if next {
            MorningProposalAnalytics.recommendationSelected(kind: change.kind, reason: change.reasonCode)
        } else {
            MorningProposalAnalytics.recommendationDeselected(kind: change.kind, reason: change.reasonCode)
        }
    }

    private func toggleReason(_ change: CoachProposedChange) {
        if expandedReasonIds.contains(change.id) {
            expandedReasonIds.remove(change.id)
        } else {
            expandedReasonIds.insert(change.id)
            MorningProposalAnalytics.reasonExpanded(kind: change.kind, reason: change.reasonCode)
        }
    }

    private func apply(_ proposal: MorningPlanProposal) {
        errorMessage = nil
        isApplying = true
        MorningProposalAnalytics.applyStarted(selectedCount: proposal.selectedChanges.count)

        let dayActivities = plannedActivities
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let today = dayActivities.filter { calendar.isDate($0.date, inSameDayAs: todayStart) }
        let tomorrow = dayActivities.filter { calendar.isDate($0.date, inSameDayAs: tomorrowStart) }

        let liveFingerprint = ProposalInputFingerprintBuilder.make(
            dayKey: dayKey,
            todayActivities: today,
            tomorrowActivities: tomorrow,
            recoveryBand: proposal.fingerprint.recoveryBand,
            sleepPresence: proposal.fingerprint.sleepPresence,
            scenarioKey: proposal.fingerprint.scenarioKey,
            yesterdayHeavy: proposal.fingerprint.yesterdayHeavy,
            observationContextRevision: proposal.fingerprint.observationContextRevision,
            behavioralGeneration: proposal.fingerprint.behavioralGeneration,
            stackedLoad: proposal.fingerprint.stackedLoad,
            generationMode: MorningProposalGenerationMode(rawValue: proposal.fingerprint.generationMode) ?? .closed,
            mealLibraryRevision: proposal.fingerprint.mealLibraryRevision,
            physiologyContextRevision: proposal.fingerprint.physiologyContextRevision,
            scorerVersion: proposal.fingerprint.scorerVersion,
            weatherRiskToken: proposal.fingerprint.weatherRiskToken
        )

        do {
            let summary = try CoachPlanApplyService.applySelected(
                proposalId: proposal.id,
                dayKey: dayKey,
                liveFingerprint: liveFingerprint,
                activities: dayActivities,
                modelContext: modelContext,
                dependencies: .default
            )
            self.proposal = MorningProposalStore.proposal(for: dayKey)
            isApplying = false
            CoachProvenanceLookupCache.invalidate()

            if summary.appliedMutationCount == 0 && summary.failedChangeIds.isEmpty {
                ProposalBehavioralPreferences.recordEmptyApply()
            } else if summary.hasSuccessfulMutations {
                ProposalBehavioralPreferences.commitLearningGeneration()
            }

            if summary.failedChangeIds.isEmpty {
                MorningProposalAnalytics.applySucceeded(appliedCount: summary.appliedMutationCount)
            } else if summary.hasSuccessfulMutations {
                MorningProposalAnalytics.applyPartial(
                    appliedCount: summary.appliedMutationCount,
                    failedCount: summary.failedChangeIds.count
                )
            } else {
                MorningProposalAnalytics.applyFailed(result: .failed)
            }

            onApplied(summary)
            dismiss()
        } catch CoachPlanApplyService.ApplyError.staleFingerprint {
            isApplying = false
            self.proposal = MorningProposalStore.proposal(for: dayKey)
            MorningProposalAnalytics.applyFailed(result: .stale)
            errorMessage = WeekFitLocalizedString("coach.proposal.review.error.stale")
        } catch CoachPlanApplyService.ApplyError.noValidMutations {
            isApplying = false
            self.proposal = MorningProposalStore.proposal(for: dayKey)
            ProposalBehavioralPreferences.recordEmptyApply()
            MorningProposalAnalytics.applyFailed(result: .noValidMutations)
            errorMessage = WeekFitLocalizedString("coach.proposal.review.error.noValid")
        } catch {
            isApplying = false
            MorningProposalAnalytics.applyFailed(result: .failed)
            errorMessage = WeekFitLocalizedString("coach.proposal.review.error.generic")
        }
    }

    private func rowTitle(_ change: CoachProposedChange) -> String {
        switch change.payload {
        case .modifyDuration(let payload):
            return titledChange(
                namedKey: "coach.proposal.change.shortenNamed",
                fallbackKey: "coach.proposal.change.shorten",
                title: payload.activityTitle
            )
        case .moveActivity(let payload):
            return titledChange(
                namedKey: "coach.proposal.change.moveNamed",
                fallbackKey: "coach.proposal.change.move",
                title: payload.activityTitle
            )
        case .skipActivity(let payload):
            return titledChange(
                namedKey: "coach.proposal.change.skipNamed",
                fallbackKey: "coach.proposal.change.skip",
                title: payload.activityTitle
            )
        case .createRecoveryWalk:
            return WeekFitLocalizedString("coach.proposal.change.addWalk")
        case .createPlannedActivity(let payload):
            if MorningProposalBriefComposer.isHabitBacked(change) {
                let title = payload.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    return String(
                        format: WeekFitLocalizedString("coach.proposal.change.habitActivityNamed"),
                        title
                    )
                }
            }
            return WeekFitLocalizedString("coach.proposal.change.addActivity")
        case .createMealFromLibrary:
            return WeekFitLocalizedString("coach.proposal.change.addMeal")
        case .guidanceOnly(let payload):
            return CoachProposalReasonCopy.localizedGuidance(payload.guidanceCode)
        }
    }

    private func titledChange(namedKey: String, fallbackKey: String, title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return WeekFitLocalizedString(fallbackKey)
        }
        return String(format: WeekFitLocalizedString(namedKey), trimmed)
    }

    private func rowDetail(_ change: CoachProposedChange) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        switch change.payload {
        case .modifyDuration(let payload):
            return String(
                format: WeekFitLocalizedString("coach.proposal.change.durationFormat"),
                payload.originalDurationMinutes,
                payload.proposedDurationMinutes
            )
        case .moveActivity(let payload):
            return String(
                format: WeekFitLocalizedString("coach.proposal.change.moveFormat"),
                formatter.string(from: payload.originalDate),
                mediumDate(payload.proposedDate)
            )
        case .skipActivity:
            return WeekFitLocalizedString("coach.proposal.change.skipDetail")
        case .createRecoveryWalk(let payload):
            return String(
                format: WeekFitLocalizedString("coach.proposal.change.walkFormat"),
                payload.durationMinutes,
                formatter.string(from: payload.proposedDate)
            )
        case .createPlannedActivity(let payload):
            return String(
                format: WeekFitLocalizedString("coach.proposal.change.activityFormat"),
                payload.title,
                formatter.string(from: payload.proposedDate)
            )
        case .createMealFromLibrary(let payload):
            return String(
                format: WeekFitLocalizedString("coach.proposal.change.mealFormat"),
                payload.title,
                formatter.string(from: payload.proposedDate)
            )
        case .guidanceOnly:
            return WeekFitLocalizedString("coach.proposal.change.guidanceDetail")
        }
    }

    private func mediumDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = WeekFitCurrentLocale()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
