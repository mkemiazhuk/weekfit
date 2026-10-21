import SwiftUI
import WeekFitPlanner

enum PlanTimelineLayout {
    static let timeWidth: CGFloat = 62
    static let columnWidth: CGFloat = 18
    static let timeToTimelineSpacing: CGFloat = 6
    static let timelineToCardSpacing: CGFloat = 8
    static let nodeSize: CGFloat = 9
    static let nodeVerticalPadding: CGFloat = 3
    static let lineWidth: CGFloat = 1.0
    static let rowSpacing: CGFloat = PlanAgendaLayout.cardSpacing
    static let cardCornerRadius: CGFloat = PlanAgendaLayout.cardCornerRadius
    static let compactHydrationVerticalPadding: CGFloat = 10
    static let cardHorizontalPadding: CGFloat = PlanAgendaLayout.cardPadding
    static let cardVerticalPadding: CGFloat = 13
    static let cardIconSpacing: CGFloat = 12
    static let cardAccentBarWidth: CGFloat = WeekFitSurface.accentIndicatorWidth
    static let rowTopInset: CGFloat = 8
    static let firstConnectorInset: CGFloat = 8
    static let lastConnectorInset: CGFloat = 4
    static let titleSubtitleSpacing: CGFloat = 2
}

struct PlanTimelineNowDivider: View {

    @ScaledMetric(relativeTo: .caption) private var timeColumnWidth = PlanTimelineLayout.timeWidth
    @State private var pulse = false

    private let liveTint = Color(red: 1.0, green: 0.706, blue: 0.341)

    var body: some View {
        HStack(alignment: .center, spacing: PlanTimelineLayout.timeToTimelineSpacing) {
            Color.clear
                .frame(width: timeColumnWidth)

            ZStack {
                Circle()
                    .fill(liveTint.opacity(pulse ? 0.22 : 0.10))
                    .frame(width: pulse ? 12 : 9, height: pulse ? 12 : 9)

                Circle()
                    .fill(liveTint.opacity(pulse ? 0.98 : 0.78))
                    .frame(width: 5, height: 5)
            }
            .frame(width: PlanTimelineLayout.columnWidth)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            liveTint.opacity(pulse ? 0.40 : 0.18),
                            WeekFitTheme.whiteOpacity(0.04)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.5)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WeekFitLocalizedString("planner.timeline.now"))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct PlanTimelineRow: View {

    let activity: PlannedActivity
    let displayTitle: String
    let metadata: PlanTimelineRowMetadata
    let customMeals: [Meals]
    let time: String
    let category: PlanTimelineCategory
    let status: PlanActivityStatus
    let emphasis: PlanTimelineVisualEmphasis
    let nextEmphasis: PlanTimelineVisualEmphasis?
    let isFirst: Bool
    let isLast: Bool
    let connectorAbove: CGFloat
    var density: PlanTimelineRowDensity = .standard
    var showsTimeLabel: Bool = true
    var completionControl: PlanAgendaCompletionControl = .none
    var onToggleCompletion: (() -> Void)? = nil

    @State private var livePulse = false
    @Environment(\.weekFitPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var accent: Color {
        // Soft category wells: movement blue, recovery lavender, nutrition token.
        category.color
    }

    private var pendingAttentionColor: Color {
        Color(red: 0.95, green: 0.60, blue: 0.15)
    }

    private var rowAccent: Color {
        isPending ? pendingAttentionColor : accent
    }

    private var isLive: Bool {
        status == .live
    }

    private var isPending: Bool {
        status == .pending
    }

    private var coachProvenanceKind: CoachChangeKind? {
        let dayKey = ProposalInputFingerprintBuilder.dayKey(for: activity.date)
        return CoachProvenanceLookupCache.adjustment(
            forActivityId: activity.id,
            dayKey: dayKey
        )?.kind
    }

    private var allowsTitleWrap: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var body: some View {
        agendaCard
            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: emphasis)
            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: status)
            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86), value: activity.isCompleted)
            .onAppear {
                guard isLive, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                    livePulse = true
                }
            }
            .onChange(of: isLive) { _, live in
                guard live, !reduceMotion else {
                    livePulse = false
                    return
                }
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                    livePulse = true
                }
            }
    }

    private var agendaCard: some View {
        HStack(alignment: .center, spacing: PlanTimelineLayout.cardIconSpacing) {
            iconView

            VStack(alignment: .leading, spacing: PlanTimelineLayout.titleSubtitleSpacing) {
                Text(displayedTime)
                    .font(WeekFitType.secondary.weight(.medium))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(timeColor)
                    .lineLimit(1)

                HStack(alignment: .center, spacing: 6) {
                    Text(displayTitle)
                        .font(WeekFitType.compactCardTitle.weight(titleFontWeight))
                        .fontDesign(.rounded)
                        .foregroundStyle(titleColor)
                        .tracking(-0.22)
                        .strikethrough(status == .skipped, color: titleColor.opacity(0.72))
                        .lineLimit(allowsTitleWrap ? nil : 2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)

                    if let coachKind = coachProvenanceKind {
                        CoachProvenanceBadge(kind: coachKind, showsLabel: false, compact: true)
                    }
                }

                if isPending {
                    pendingStatusLine
                } else if !metadata.isEmpty {
                    metadataLine
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingStatusControl
                .padding(.leading, 2)
        }
        .padding(.horizontal, PlanTimelineLayout.cardHorizontalPadding)
        .padding(.vertical, cardVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: PlanTimelineLayout.cardCornerRadius, style: .continuous)
                .fill(agendaCardFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PlanTimelineLayout.cardCornerRadius, style: .continuous)
                .strokeBorder(agendaBorderColor, lineWidth: isLive || isPending ? 0.9 : 0.55)
        }
        .shadow(
            color: palette.isLight ? Color.black.opacity(0.03) : Color.black.opacity(0.14),
            radius: palette.isLight ? 2 : 3,
            y: 1
        )
        .shadow(
            color: liveGlowColor,
            radius: isLive && livePulse ? 6 : (isLive ? 3 : 0),
            y: isLive ? 1 : 0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(WeekFitLocalizedString("planner.timeline.accessibility.opensDetails"))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var trailingStatusControl: some View {
        switch completionControl {
        case .interactive(let isCompleted):
            Button {
                onToggleCompletion?()
            } label: {
                completionGlyph(isCompleted: isCompleted, interactive: true)
                    .frame(width: PlanAgendaLayout.minHitSize, height: PlanAgendaLayout.minHitSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                isCompleted
                    ? WeekFitLocalizedString("planner.status.completed")
                    : WeekFitLocalizedString("planner.agenda.markComplete")
            )
            .accessibilityAddTraits(.isButton)

        case .informational(let isCompleted):
            completionGlyph(isCompleted: isCompleted, interactive: false)
                .frame(width: PlanAgendaLayout.minHitSize, height: PlanAgendaLayout.minHitSize)
                .accessibilityLabel(status.title)
                .accessibilityHidden(!isCompleted && status == .upcoming)

        case .none:
            compactStatusIndicator
                .frame(minWidth: 28, minHeight: PlanAgendaLayout.minHitSize)
        }
    }

    private func completionGlyph(isCompleted: Bool, interactive: Bool) -> some View {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(
                isCompleted
                    ? WeekFitTheme.brandGold
                    : (interactive
                        ? palette.textTertiary.opacity(0.85)
                        : palette.textTertiary.opacity(0.55))
            )
            .accessibilityHidden(true)
    }

    private var displayedTime: String {
        let trimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return WeekFitLocalizedString("planner.timeline.anytime")
        }
        return trimmed
    }

    private var timeColor: Color {
        if isLive { return accent.opacity(0.95) }
        if isPending { return pendingAttentionColor.opacity(0.92) }
        if status == .skipped { return palette.textDisabled }
        return palette.textSecondary.opacity(0.90)
    }

    private var agendaCardFill: Color {
        palette.isLight ? Color.white.opacity(0.96) : WeekFitTheme.cardBackground
    }

    private var agendaBorderColor: Color {
        if isLive {
            return accent.opacity(livePulse ? 0.34 : 0.20)
        }
        if isPending {
            return pendingAttentionColor.opacity(0.28)
        }
        return palette.isLight
            ? Color.black.opacity(0.05)
            : WeekFitTheme.whiteOpacity(0.08)
    }

    @ViewBuilder
    private var compactStatusIndicator: some View {
        switch status {
        case .completed, .logged:
            completionGlyph(isCompleted: true, interactive: false)

        case .live:
            Circle()
                .fill(accent.opacity(livePulse ? 1.0 : 0.55))
                .frame(width: 8, height: 8)
                .padding(5)
                .background {
                    Circle()
                        .fill(accent.opacity(livePulse ? 0.18 : 0.10))
                }
                .accessibilityHidden(true)

        case .pending:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(pendingAttentionColor)
                .accessibilityHidden(true)

        case .skipped:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.78))
                .accessibilityHidden(true)

        case .upcoming:
            EmptyView()
        }
    }

    private var titleFontWeight: Font.Weight {
        switch emphasis {
        case .skipped:
            return .regular
        default:
            return .semibold
        }
    }

    private var chevronColor: Color {
        if isPending {
            return pendingAttentionColor.opacity(0.55)
        }

        switch emphasis {
        case .next, .active, .upcoming:
            return WeekFitTheme.iconSecondary.opacity(0.72)
        case .past:
            return WeekFitTheme.iconInactive.opacity(0.65)
        case .skipped:
            return WeekFitTheme.disabledText.opacity(0.55)
        }
    }

    private var cardVerticalPadding: CGFloat {
        density == .compactHydration
            ? PlanTimelineLayout.compactHydrationVerticalPadding
            : PlanTimelineLayout.cardVerticalPadding
    }

    private var metadataLine: some View {
        HStack(alignment: .center, spacing: 4) {
            if let primary = metadata.primary, !primary.isEmpty {
                Text(primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }

            if let sourceLabel = metadata.sourceLabel, !sourceLabel.isEmpty {
                if metadata.primary != nil {
                    Text("·")
                        .foregroundStyle(metadataColor.opacity(0.55))
                }
                Text(sourceLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(WeekFitTheme.coachAccent.opacity(0.82))
            }

            if metadata.showsWatchIcon {
                watchSourceBadge
            }
        }
        .font(WeekFitType.secondary)
        .foregroundStyle(metadataColor)
        .lineLimit(1)
    }

    private var liveStatusBadge: some View {
        Circle()
            .fill(accent.opacity(livePulse ? 1.0 : 0.55))
            .frame(width: 7, height: 7)
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(accent.opacity(livePulse ? 0.18 : 0.11))
            }
            .overlay {
                Capsule()
                    .stroke(accent.opacity(livePulse ? 0.34 : 0.18), lineWidth: 0.75)
            }
            .accessibilityLabel(WeekFitLocalizedString("planner.status.live"))
    }

    private var watchSourceBadge: some View {
        Image(systemName: "applewatch")
            .font(WeekFitType.caption)
            .foregroundStyle(metadataColor.opacity(0.58))
            .accessibilityLabel(WeekFitLocalizedString("planner.timeline.source.appleWatch"))
    }

    private var accessibilityLabelText: String {
        var parts: [String] = [time, displayTitle, status.title]
        if let primary = metadata.primary, !primary.isEmpty {
            parts.append(primary)
        }
        if let sourceLabel = metadata.sourceLabel, !sourceLabel.isEmpty {
            parts.append(sourceLabel)
        }
        if metadata.showsWatchIcon {
            parts.append(
                String(
                    format: WeekFitLocalizedString("planner.timeline.accessibility.appleWatchSyncedFormat"),
                    WeekFitLocalizedString("planner.timeline.source.appleWatch")
                )
            )
        }
        if let foodSource = PlanTimelineMetadataBuilder.accessibilityFoodSource(
            for: activity,
            customMeals: customMeals
        ) {
            parts.append(foodSource)
        }
        return parts.joined(separator: ", ")
    }

    // Watch / HealthKit stay in metadata — not mixed into the completion glyph.

    private var titleColor: Color {
        switch emphasis {
        case .next, .active, .upcoming, .past:
            // Completed rows stay fully readable — checkmark already signals done.
            return palette.textPrimary
        case .skipped:
            return palette.textDisabled
        }
    }

    private var metadataColor: Color {
        switch emphasis {
        case .next, .active, .upcoming, .past:
            return palette.textSecondary
        case .skipped:
            return palette.textTertiary
        }
    }


    private var liveGlowColor: Color {
        isLive ? accent.opacity(livePulse ? 0.16 : 0.08) : .clear
    }

    private var pendingGlowColor: Color {
        isPending ? pendingAttentionColor.opacity(0.10) : .clear
    }

    private var pendingStatusLine: some View {
        HStack(spacing: 4) {
            Text(WeekFitLocalizedString("today.pending.title"))
                .lineLimit(1)

            if let primary = metadata.primary, !primary.isEmpty {
                Text("·")
                Text(primary)
                    .lineLimit(1)
            }
        }
        .font(WeekFitType.secondary.weight(.semibold))
        .foregroundStyle(pendingAttentionColor.opacity(0.92))
    }

    @ViewBuilder
    private var iconView: some View {
        if isPending {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(pendingAttentionColor.opacity(0.12))
                    .frame(width: PlanAgendaLayout.iconSize, height: PlanAgendaLayout.iconSize)

                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(pendingAttentionColor)
            }
            .frame(width: PlanAgendaLayout.iconSize, height: PlanAgendaLayout.iconSize)
        } else {
            WeekFitIconBadge(
                systemName: resolvedIcon,
                color: accent,
                size: .md,
                shape: .roundedRect,
                backgroundOpacity: iconBackgroundOpacity,
                foregroundOpacity: iconForegroundOpacity
            )
            .frame(width: PlanAgendaLayout.iconSize, height: PlanAgendaLayout.iconSize)
        }
    }

    private var iconBackgroundOpacity: Double {
        if isLive { return palette.isLight ? 0.28 : 0.20 }

        switch emphasis {
        case .next:
            return palette.isLight ? 0.26 : 0.20
        case .active, .past:
            return palette.isLight ? 0.24 : 0.17
        case .upcoming:
            return palette.isLight ? 0.22 : 0.14
        case .skipped:
            return palette.isLight ? 0.12 : 0.06
        }
    }

    private var iconForegroundOpacity: Double {
        if isLive { return 1.0 }

        switch emphasis {
        case .next, .past:
            return 1.0
        case .active, .upcoming:
            return palette.isLight ? 0.96 : 0.84
        case .skipped:
            return palette.isLight ? 0.55 : 0.42
        }
    }

    private var resolvedIcon: String {
        PlanTimelineIconResolver.icon(for: activity)
    }
}

// MARK: - Timeline Node

private struct PlanTimelineNode: View {

    let accent: Color
    let status: PlanActivityStatus
    let emphasis: PlanTimelineVisualEmphasis
    @Binding var livePulse: Bool

    private var isFilled: Bool {
        status == .completed || status == .logged || status == .live || status == .skipped
    }

    private var isSkipped: Bool {
        status == .skipped
    }

    var body: some View {
        ZStack {
            if isSkipped {
                Circle()
                    .fill(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(skippedNodeFillOpacity))
                    .frame(width: nodeDiameter, height: nodeDiameter)

                Image(systemName: "xmark")
                    .font(.system(size: 5.5, weight: .bold))
                    .foregroundStyle(WeekFitTheme.whiteOpacity(0.92))
            } else if status == .pending {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: nodeDiameter, height: nodeDiameter)
                    .shadow(color: accent.opacity(0.24), radius: 3)

                Image(systemName: "exclamationmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(accent.opacity(0.96))
            } else if isFilled {
                if status == .live {
                    Circle()
                        .stroke(accent.opacity(livePulse ? 0.52 : 0.20), lineWidth: 1.25)
                        .frame(
                            width: nodeDiameter + (livePulse ? 9 : 5),
                            height: nodeDiameter + (livePulse ? 9 : 5)
                        )

                    Circle()
                        .fill(accent.opacity(livePulse ? 0.14 : 0.06))
                        .frame(
                            width: nodeDiameter + (livePulse ? 14 : 8),
                            height: nodeDiameter + (livePulse ? 14 : 8)
                        )
                        .blur(radius: 1.5)
                }

                Circle()
                    .fill(accent.opacity(filledOpacity))
                    .frame(width: nodeDiameter, height: nodeDiameter)
                    .scaleEffect(status == .live && livePulse ? 1.14 : 1.0)
                    .shadow(
                        color: accent.opacity(filledShadowOpacity),
                        radius: status == .live ? (livePulse ? 8 : 5) : 1.5
                    )

                if status == .completed || status == .logged {
                    Image(systemName: "checkmark")
                        .font(.system(size: 5, weight: .bold))
                        .foregroundStyle(Color.black.opacity(checkmarkOpacity))
                }
            } else {
                Circle()
                    .strokeBorder(
                        accent.opacity(emptyStrokeOpacity),
                        lineWidth: emptyStrokeWidth
                    )
                    .frame(width: nodeDiameter, height: nodeDiameter)
                    .background(
                        Circle()
                            .fill(WeekFitTheme.cardSurface.opacity(0.92))
                    )
            }
        }
        .frame(width: PlanTimelineLayout.columnWidth, height: nodeDiameter + PlanTimelineLayout.nodeVerticalPadding * 2 + 1)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: status)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: emphasis)
        .onAppear {
            startLivePulseIfNeeded()
        }
        .onChange(of: status) { _, newValue in
            if newValue == .live {
                startLivePulseIfNeeded()
            } else {
                livePulse = false
            }
        }
        .accessibilityHidden(true)
    }

    private func startLivePulseIfNeeded() {
        guard status == .live else { return }
        livePulse = false
        withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
            livePulse = true
        }
    }

    private var filledOpacity: Double {
        if status == .live { return 0.95 }

        switch emphasis {
        case .past:
            return 0.82
        default:
            return 0.88
        }
    }

    private var skippedNodeFillOpacity: Double {
        switch emphasis {
        case .skipped:
            return 0.72
        case .past:
            return 0.58
        default:
            return 0.66
        }
    }

    private var filledShadowOpacity: Double {
        if status == .live { return 0.28 }

        switch emphasis {
        case .past:
            return 0.12
        case .skipped:
            return 0.06
        default:
            return 0.12
        }
    }

    private var checkmarkOpacity: Double {
        switch emphasis {
        case .past:
            return 0.76
        case .skipped:
            return 0.58
        default:
            return 0.72
        }
    }

    private var emptyStrokeOpacity: Double {
        switch emphasis {
        case .next:
            return 0.72
        case .active, .upcoming:
            return 0.56
        case .past, .skipped:
            return 0.24
        }
    }

    private var emptyStrokeWidth: CGFloat {
        emphasis == .next ? 1.55 : 1.35
    }

    private var emptyFillOpacity: Double {
        emphasis == .next ? 0.22 : 0.16
    }

    private var nodeDiameter: CGFloat {
        if status == .live { return 10 }
        if emphasis == .next && !isFilled { return 10 }
        return PlanTimelineLayout.nodeSize
    }
}

// MARK: - Icon Resolver

enum PlanTimelineIconResolver {

    static func icon(for activity: PlannedActivity) -> String {
        WeekFitActivityIconResolver.resolve(for: activity)
    }
}

// MARK: - Previews

#if DEBUG
private enum PlanTimelinePreviewFactory {

    static func row(
        title: String,
        time: String,
        status: PlanActivityStatus,
        emphasis: PlanTimelineVisualEmphasis,
        completed: Bool = false,
        category: PlanTimelineCategory = .activity,
        metadata: PlanTimelineRowMetadata? = nil
    ) -> some View {
        PlanTimelineRow(
            activity: PlannedActivity(
                date: Date(),
                type: "habit",
                title: title,
                durationMinutes: 30,
                icon: "bed.double.fill",
                colorRed: 0.66,
                colorGreen: 0.58,
                colorBlue: 0.86,
                isCompleted: completed
            ),
            displayTitle: title,
            metadata: metadata ?? PlanTimelineRowMetadata(
                primary: emphasis == .past ? "39 min" : nil,
                sourceLabel: nil,
                showsWatchIcon: false
            ),
            customMeals: [],
            time: time,
            category: category,
            status: status,
            emphasis: emphasis,
            nextEmphasis: emphasis == .past ? .next : nil,
            isFirst: false,
            isLast: false,
            connectorAbove: 0
        )
    }
}

#Preview("Plan Timeline Emphasis") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 0) {
            PlanTimelinePreviewFactory.row(
                title: "Water",
                time: "14:09",
                status: .logged,
                emphasis: .past,
                completed: true,
                category: .nutrition
            )
            PlanTimelinePreviewFactory.row(
                title: "Холодник с картошкой",
                time: "14:41",
                status: .logged,
                emphasis: .past,
                completed: true,
                category: .nutrition
            )
            PlanTimelinePreviewFactory.row(
                title: "Walk",
                time: "17:31",
                status: .logged,
                emphasis: .past,
                completed: true,
                metadata: PlanTimelineRowMetadata(
                    primary: "19 min",
                    sourceLabel: nil,
                    showsWatchIcon: true
                )
            )
            PlanTimelineNowDivider()
            PlanTimelinePreviewFactory.row(
                title: "Sleep Routine",
                time: "22:30",
                status: .upcoming,
                emphasis: .next
            )
        }
        .padding(.horizontal, 12)
    }
    .preferredColorScheme(.dark)
}
#endif
