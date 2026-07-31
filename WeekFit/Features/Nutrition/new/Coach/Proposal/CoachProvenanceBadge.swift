import SwiftUI

/// Compact secondary Coach mark for Plan / Up Next rows.
struct CoachProvenanceBadge: View {
    let kind: CoachChangeKind
    var showsLabel: Bool = true
    var compact: Bool = true

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: compact ? 9 : 10, weight: .medium))
                .accessibilityHidden(true)

            if showsLabel {
                Text(CoachProvenanceCopy.compactLabel(for: kind))
                    .font(.system(size: compact ? 10 : 11, weight: .medium, design: .rounded))
                    .tracking(0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .foregroundStyle(WeekFitTheme.coachAccent.opacity(0.72))
        .padding(.horizontal, showsLabel ? 8 : 5)
        .padding(.vertical, compact ? 3.5 : 4.5)
        .background {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            WeekFitTheme.coachAccent.opacity(0.10),
                            WeekFitTheme.coachAccent.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            Capsule()
                .stroke(WeekFitTheme.coachAccent.opacity(0.14), lineWidth: 0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CoachProvenanceCopy.accessibilityLabel(for: kind))
    }
}

/// Dedicated Coach adjustment block for activity detail.
struct CoachAdjustmentDetailSection: View {
    let adjustment: AppliedCoachAdjustment

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(WeekFitTheme.coachAccent.opacity(0.82))
                Text(CoachProvenanceCopy.detailTitle(for: adjustment.kind))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .tracking(0.2)
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.88))
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 12) {
                if let original = adjustment.originalSnapshot {
                    detailRow(
                        title: WeekFitLocalizedString("coach.provenance.detail.original"),
                        value: snapshotSummary(original)
                    )
                }

                detailRow(
                    title: WeekFitLocalizedString("coach.provenance.detail.applied"),
                    value: snapshotSummary(adjustment.appliedSnapshot)
                )

                detailRow(
                    title: WeekFitLocalizedString("coach.provenance.detail.reason"),
                    value: CoachProposalReasonCopy.localizedReason(adjustment.reasonCode)
                )

                detailRow(
                    title: WeekFitLocalizedString("coach.provenance.detail.appliedAt"),
                    value: appliedTimeText(adjustment.appliedAt)
                )
            }

            if adjustment.userManuallyEditedAfterApply {
                Text(WeekFitLocalizedString("coach.provenance.detail.manuallyEdited"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weekFitPremiumCard(emphasis: .standard, accent: WeekFitTheme.coachAccent)
        .accessibilityElement(children: .combine)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.42))
            Text(value)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(WeekFitTheme.whiteOpacity(0.80))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func snapshotSummary(_ snapshot: CoachActivitySnapshot) -> String {
        let time = snapshot.date.formatted(.dateTime.hour().minute())
        var parts: [String] = []
        if snapshot.isSkipped {
            parts.append(WeekFitLocalizedString("planner.status.skipped"))
        }
        parts.append(
            String(
                format: WeekFitLocalizedString("coach.provenance.detail.durationFormat"),
                snapshot.durationMinutes
            )
        )
        parts.append(time)
        return parts.joined(separator: " · ")
    }

    private func appliedTimeText(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}
