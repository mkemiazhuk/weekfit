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
    @Query(sort: \PlannedActivity.date) private var plannedActivities: [PlannedActivity]

    @State private var proposal: MorningPlanProposal?
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var expandedReasonIds: Set<String> = []
    @State private var didRecordReviewOpen = false

    var body: some View {
        NavigationStack {
            Group {
                if let proposal {
                    reviewContent(proposal)
                } else {
                    ContentUnavailableView(
                        WeekFitLocalizedString("coach.proposal.review.emptyTitle"),
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text(WeekFitLocalizedString("coach.proposal.review.emptyBody"))
                    )
                }
            }
            .navigationTitle(WeekFitLocalizedString("coach.proposal.review.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(WeekFitLocalizedString("common.action.close")) {
                        dismiss()
                    }
                    .disabled(isApplying)
                }
            }
            .interactiveDismissDisabled(isApplying)
            .safeAreaInset(edge: .bottom) {
                if let proposal, proposal.status != .applied {
                    stickyFooter(proposal)
                }
            }
        }
        .onAppear {
            proposal = MorningProposalStore.proposal(for: dayKey)
            guard !didRecordReviewOpen, let proposal else { return }
            didRecordReviewOpen = true
            MorningProposalAnalytics.reviewOpened(changeCount: proposal.changes.count)
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
        let recommended = orderedChanges(proposal.changes.filter { $0.kind != .guidanceOnly && $0.defaultSelected })
        let optional = orderedChanges(proposal.changes.filter { $0.kind != .guidanceOnly && !$0.defaultSelected })
        let tips = orderedChanges(proposal.changes.filter { $0.kind == .guidanceOnly })

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(proposal, brief: brief)

                if proposal.status == .stale {
                    Text(WeekFitLocalizedString("coach.proposal.review.staleBanner"))
                        .font(.footnote)
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.7))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .weekFitPremiumCard(emphasis: .standard, accent: WeekFitTheme.recovery)
                }

                if !recommended.isEmpty {
                    sectionLabel(WeekFitLocalizedString("coach.proposal.review.section.recommended"))
                    ForEach(recommended) { change in
                        changeRow(change)
                    }
                }

                if !optional.isEmpty {
                    sectionLabel(WeekFitLocalizedString("coach.proposal.review.section.optional"))
                    ForEach(optional) { change in
                        changeRow(change)
                    }
                }

                if !tips.isEmpty {
                    sectionLabel(WeekFitLocalizedString("coach.proposal.review.section.tips"))
                    ForEach(tips) { change in
                        changeRow(change)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .background(WeekFitTheme.cardSurface.ignoresSafeArea())
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .fontDesign(.rounded)
            .tracking(0.6)
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
            .textCase(.uppercase)
            .padding(.top, 4)
    }

    private func header(_ proposal: MorningPlanProposal, brief: MorningProposalBrief) -> some View {
        let selected = proposal.changes.filter(\.isSelected).count
        return VStack(alignment: .leading, spacing: 8) {
            Text(brief.eyebrow)
                .font(.caption2.weight(.bold))
                .fontDesign(.rounded)
                .tracking(1.2)
                .foregroundStyle(WeekFitTheme.recovery.opacity(0.78))

            Text(brief.headline)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.94))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(brief.headline)

            if !brief.actionLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(brief.actionLines.prefix(3).enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(WeekFitTheme.recovery.opacity(0.8))
                            Text(line)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(WeekFitTheme.whiteOpacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let meta = brief.metaLine {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(
                String(
                    format: WeekFitLocalizedString("coach.proposal.review.selectedCountFormat"),
                    selected
                )
            )
            .font(.footnote)
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func orderedChanges(_ changes: [CoachProposedChange]) -> [CoachProposedChange] {
        // Actionable plan changes first; tips are informational and sit below.
        changes.sorted { lhs, rhs in
            let lTip = lhs.kind == .guidanceOnly
            let rTip = rhs.kind == .guidanceOnly
            if lTip != rTip { return !lTip && rTip }
            return lhs.sortTime < rhs.sortTime
        }
    }

    private func changeRow(_ change: CoachProposedChange) -> some View {
        let isTip = change.kind == .guidanceOnly
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if isTip {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(WeekFitTheme.recovery.opacity(0.72))
                        .frame(minWidth: 44, minHeight: 44, alignment: .top)
                        .accessibilityHidden(true)
                } else {
                    Button {
                        toggle(change)
                    } label: {
                        Image(systemName: change.isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                change.isSelected ? WeekFitTheme.recovery : WeekFitTheme.whiteOpacity(0.35)
                            )
                            .frame(minWidth: 44, minHeight: 44, alignment: .top)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        change.isSelected
                            ? WeekFitLocalizedString("coach.proposal.review.a11y.selected")
                            : WeekFitLocalizedString("coach.proposal.review.a11y.notSelected")
                    )
                    .accessibilityHint(WeekFitLocalizedString("coach.proposal.review.a11y.toggleHint"))
                    .disabled(isApplying)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(rowTitle(change))
                        .font(.callout.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
                    Text(rowDetail(change))
                        .font(.footnote)
                        .foregroundStyle(WeekFitTheme.whiteOpacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)

                    if expandedReasonIds.contains(change.id) {
                        Text(CoachProposalReasonCopy.localizedReason(change.reasonCode))
                            .font(.footnote)
                            .foregroundStyle(WeekFitTheme.whiteOpacity(0.72))
                            .padding(.top, 4)
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeekFitTheme.recovery)
                        .frame(minHeight: 32, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(isApplying)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .weekFitPremiumCard(emphasis: .standard, accent: nil)
        .accessibilityElement(children: .contain)
    }

    private func stickyFooter(_ proposal: MorningPlanProposal) -> some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.red.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(errorMessage)
            }

            Button {
                apply(proposal)
            } label: {
                Text(
                    isApplying
                        ? WeekFitLocalizedString("coach.proposal.review.applying")
                        : WeekFitLocalizedString("coach.proposal.review.apply")
                )
                .font(.callout.weight(.bold))
                .fontDesign(.rounded)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.96))
            .background(WeekFitTheme.recovery.opacity(proposal.selectedChanges.isEmpty || isApplying ? 0.35 : 0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(proposal.selectedChanges.isEmpty || isApplying)
            .accessibilityHint(WeekFitLocalizedString("coach.proposal.review.a11y.applyHint"))

            Button(WeekFitLocalizedString("coach.proposal.review.keepPlan")) {
                MorningProposalService.dismiss(dayKey: dayKey)
                onDismissPlan()
                dismiss()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(WeekFitTheme.whiteOpacity(0.62))
            .buttonStyle(.plain)
            .disabled(isApplying)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
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
